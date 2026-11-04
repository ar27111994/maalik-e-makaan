-- ============================================================================
-- Membership and account-deletion concurrency, single-use portfolio ids, and
-- durable storage cleanup.
--
-- One lock order for every writer, so concurrent writers wait for each other
-- instead of deadlocking:
--
--   1. the account    (profiles row) account deletion: for update; creating
--                     a portfolio or accepting an invitation: key share, and
--                     both refuse an account whose deletion has started;
--   2. the portfolio  deletions and membership changes: for update; every
--                     other writer: key share, which is also what an insert's
--                     foreign-key check takes (it is the first check on every
--                     table);
--   3. the lease      write RPCs, billing and the daily job: for update;
--   4. other rows     charges, payments, documents, invitations ...
--
-- A client's plain UPDATE or DELETE locks its own row before anything else,
-- so it cannot follow this order. Two measures keep that safe: audit rows no
-- longer take the portfolio key (they had a foreign key to it), and the
-- deletions retry their lock-and-delete step when the deadlock detector
-- picks them.
--
-- Also:
--   * Membership RPCs authorise again after the portfolio lock (time of
--     check vs time of use), and an invitation is void once its inviter is no
--     longer an owner of the portfolio.
--   * Portfolio ids are single-use (private.portfolio_ids): a deleted
--     portfolio's id can never be claimed again, so nobody can re-create it
--     to reach, or pin, files that are still waiting to be deleted.
--   * Files are deleted durably. Deleting a document row, a portfolio, or an
--     entity with documents queues its storage objects; the storage-cleanup
--     Edge Function drains the queue through the Storage API (deleting rows
--     of storage.objects would leave the files behind). pg_cron asks it to
--     run every 10 minutes through pg_net once the operator has stored the
--     project URL and the cleanup token in Vault (docs/operations.md). A
--     daily sweep queues what no trigger saw.
--   * A document row records an uploaded file of a live entity: the insert
--     locks the entity, needs the file to exist, and is refused while that
--     file is queued for deletion. A file a live document references can no
--     longer be deleted through the Storage API.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Accounts being deleted
-- ---------------------------------------------------------------------------

-- Accounts whose deletion has started (admin_delete_account_data). The row
-- goes away with the auth user.
create table private.account_deletions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  requested_at timestamptz not null default now()
);

comment on table private.account_deletions is
  'Accounts whose deletion has started: they may no longer join or create portfolios.';

revoke all on private.account_deletions from public, anon, authenticated;

-- Takes the first lock of the global order (the account) and refuses an
-- account whose deletion has started. Key share waits for a deletion in
-- progress but not for ordinary profile updates.
create or replace function private.require_active_account(p_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform 1 from public.profiles p where p.id = p_user_id for key share;
  if exists (select 1 from private.account_deletions d where d.user_id = p_user_id) then
    perform app.fail('account_deleted');
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. The portfolio, then the lease
-- ---------------------------------------------------------------------------

-- Locks a portfolio row for a change after a cheap authorisation check (so
-- outsiders cannot queue on other people's portfolios), then authorises
-- again: the statement after the lock sees every membership change that
-- committed while this one waited. Exclusive for membership changes; key
-- share (which still waits for them) for invitations.
create or replace function private.lock_portfolio_for_change(
  p_portfolio_id uuid,
  p_roles public.member_role[],
  p_exclusive boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform app.require_portfolio_role(p_portfolio_id, p_roles);
  if p_exclusive then
    perform 1 from public.portfolios p where p.id = p_portfolio_id for update;
  else
    perform 1 from public.portfolios p where p.id = p_portfolio_id for key share;
  end if;
  perform app.require_portfolio_role(p_portfolio_id, p_roles);
end
$$;

-- Loads a lease for a write RPC: authorises the caller, takes the portfolio
-- key and then the lease (the global order), and authorises again. A lease
-- deleted while the request waited is reported like a missing one; a member
-- removed while it waited is refused, and a removal or deletion starting
-- now waits for this request.
create or replace function private.lock_lease_for_write(
  p_lease_id uuid,
  p_roles public.member_role[]
)
returns public.leases
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
  v_lease public.leases;
begin
  select l.portfolio_id into v_portfolio_id from public.leases l where l.id = p_lease_id;
  -- Same error for "missing" and "not yours": never confirm existence.
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_portfolio_id, p_roles);

  perform 1 from public.portfolios p where p.id = v_portfolio_id for key share;
  select l.* into v_lease from public.leases l where l.id = p_lease_id for update;
  if not found or v_lease.portfolio_id is distinct from v_portfolio_id then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_portfolio_id, p_roles);
  return v_lease;
end
$$;

-- Locks portfolios for deletion, in id order. Their rows are the second lock
-- of the global order, so every writer that follows the order waits here.
create or replace function private.lock_portfolios_for_deletion(p_portfolio_ids uuid[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform 1
  from public.portfolios p
  where p.id = any (p_portfolio_ids)
  order by p.id
  for update;
end
$$;

-- Generates any missing rent dues for a portfolio's active leases. The app
-- calls this when the dashboard opens, so dues stay correct even if a
-- scheduled run was missed (e.g. a paused free-tier project). The portfolio
-- key is held before the leases are locked one by one in id order.
create or replace function public.sync_portfolio_billing(p_portfolio_id uuid)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_roles public.member_role[] := array['owner', 'manager', 'accountant']::public.member_role[];
  v_lease_id uuid;
  v_created integer := 0;
begin
  perform app.require_portfolio_role(p_portfolio_id, v_roles);
  perform private.enforce_rate_limit('sync_portfolio_billing', 30, interval '1 minute');
  perform 1 from public.portfolios p where p.id = p_portfolio_id for key share;
  perform app.require_portfolio_role(p_portfolio_id, v_roles);

  for v_lease_id in
    select l.id from public.leases l
    where l.portfolio_id = p_portfolio_id and l.status = 'active'
    order by l.id
  loop
    v_created := v_created + private.sync_lease_billing(v_lease_id, app.today_pkt());
  end loop;
  return v_created;
end
$$;

-- Maintains up to p_batch_size active leases not yet maintained for p_as_of
-- (Pakistan date), one at a time in id order, each in its own subtransaction:
--   * a lease whose portfolio is being deleted or changing members, or that a
--     user's write holds, is skipped (SKIP LOCKED, portfolio key first, then
--     the lease) and picked up by the next run, so the job never waits on a
--     lock while holding others;
--   * a failing lease is rolled back alone, recorded with its error and
--     retried the next day; the rest of the batch carries on;
--   * once no lease is pending for the day, a run that maintained no lease
--     (so holds no lease locks) runs notifications and cleanup, once a day.
-- pg_cron runs it every 10 minutes, so a day's work spreads over short
-- transactions and a missed or failed run catches up by itself.
create or replace function private.run_daily_jobs(p_as_of date default null, p_batch_size integer default 500)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_lease record;
  v_step jsonb;
  v_processed integer := 0;
  v_busy integer := 0;
  v_failed integer := 0;
  v_charges integer := 0;
  v_fees integer := 0;
  v_pending integer;
  v_notifications integer;
  v_state text;
  v_message text;
begin
  if p_batch_size is null or p_batch_size not between 1 and 10000 then
    perform app.fail('invalid_batch_size');
  end if;
  -- One coordinator at a time; an overlapping run simply skips.
  if not pg_try_advisory_xact_lock(hashtext('maalik_e_makaan.run_daily_jobs')) then
    return jsonb_build_object('skipped', true);
  end if;

  for v_lease in
    select l.id, l.portfolio_id
    from public.leases l
    left join private.lease_maintenance m on m.lease_id = l.id
    where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of)
    order by l.id
    limit p_batch_size
  loop
    begin
      perform 1 from public.portfolios p where p.id = v_lease.portfolio_id for key share skip locked;
      if not found then
        v_busy := v_busy + 1;
        continue;
      end if;
      perform 1 from public.leases l where l.id = v_lease.id for update skip locked;
      if not found then
        v_busy := v_busy + 1;
        continue;
      end if;

      v_step := private.maintain_lease(v_lease.id, v_as_of);
      insert into private.lease_maintenance as m (lease_id, maintained_on)
      values (v_lease.id, v_as_of)
      on conflict (lease_id) do update
        set maintained_on = excluded.maintained_on, failures = 0, last_error = null, updated_at = now();

      v_charges := v_charges + (v_step ->> 'charges_created')::integer;
      v_fees := v_fees + (v_step ->> 'late_fees')::integer;
      v_processed := v_processed + 1;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_message = message_text;
      v_failed := v_failed + 1;
      raise warning 'run_daily_jobs: lease % failed (%): %', v_lease.id, v_state, v_message;
      begin
        insert into private.lease_maintenance as m (lease_id, maintained_on, failures, last_error)
        values (v_lease.id, v_as_of, 1, v_state || ': ' || left(v_message, 500))
        on conflict (lease_id) do update
          set maintained_on = excluded.maintained_on,
              failures = m.failures + 1,
              last_error = excluded.last_error,
              updated_at = now();
      exception when foreign_key_violation then
        null; -- the lease was deleted in the meantime
      end;
    end;
  end loop;

  select count(*)::integer into v_pending
  from public.leases l
  left join private.lease_maintenance m on m.lease_id = l.id
  where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of);

  -- The portfolio-wide work runs once a day after every lease is done, and
  -- only in a run that maintained no lease itself, so it never holds lease
  -- locks while it fans out notifications (the next run, 10 minutes later).
  if v_pending = 0 and v_processed = 0 then
    insert into private.job_runs (job_name, run_on) values ('daily_notifications', v_as_of)
    on conflict (job_name, run_on) do nothing;
    if found then
      v_notifications := private.generate_notifications(v_as_of);
      perform private.cleanup(now());
      update private.job_runs
      set finished_at = now(), result = jsonb_build_object('notifications', v_notifications)
      where job_name = 'daily_notifications' and run_on = v_as_of;
    end if;
  end if;

  return jsonb_build_object(
    'as_of', v_as_of,
    'leases_processed', v_processed,
    'leases_busy', v_busy,
    'leases_failed', v_failed,
    'leases_pending', v_pending,
    'charges_created', v_charges,
    'late_fees', v_fees,
    'notifications', v_notifications
  );
end
$$;

-- A manual charge locks its lease before it is inserted (portfolio key, then
-- the lease). Taking the lease only after the insert's foreign-key check had
-- taken it for key share was a lock upgrade: two manual charges, or a charge
-- and a payment, on the same lease could deadlock. Authorises first, so a
-- non-member's insert never locks another landlord's rows before the row
-- policy refuses it.
create or replace function private.before_manual_charge_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not app.has_portfolio_role(
    new.portfolio_id, array['owner', 'manager', 'accountant']::public.member_role[]
  ) then
    perform app.forbid();
  end if;
  perform 1 from public.portfolios p where p.id = new.portfolio_id for key share;
  perform 1 from public.leases l
  where l.id = new.lease_id and l.portfolio_id = new.portfolio_id
  for update;
  return new;
end
$$;

create trigger charges_before_manual_insert
  before insert on public.charges
  for each row
  when (new.source = 'manual')
  execute function private.before_manual_charge_insert();

-- Manual charges pick up any unallocated credit immediately (the lease is
-- already locked by charges_before_manual_insert).
create or replace function private.after_manual_charge_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.apply_lease_credit(new.lease_id);
  return null;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Single-use portfolio ids
-- ---------------------------------------------------------------------------

-- Every portfolio id ever used. A portfolio's files can outlive its row for
-- a while (they wait in the cleanup queue), and storage access follows the
-- id in the file path, so an id must never be handed out twice.
create table private.portfolio_ids (
  id uuid primary key,
  registered_at timestamptz not null default now(),
  retired_at timestamptz
);

comment on table private.portfolio_ids is
  'Every portfolio id ever used; retired ids (deleted portfolios) are never accepted again.';

create index portfolio_ids_retired_idx on private.portfolio_ids (retired_at) where retired_at is not null;

revoke all on private.portfolio_ids from public, anon, authenticated;

-- Registers each new portfolio id. The primary key refuses an id that was
-- ever used, on every insert path (an insert racing the deletion of the same
-- id included).
create or replace function private.after_portfolio_insert_register_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.portfolio_ids (id) values (new.id) on conflict (id) do nothing;
  if not found then
    perform app.forbid();
  end if;
  return null;
end
$$;

create trigger portfolios_after_insert_register_id
  after insert on public.portfolios
  for each row execute function private.after_portfolio_insert_register_id();

-- Creates a portfolio with the caller as owner. Idempotent for a
-- client-supplied id: the creator's offline retry gets the portfolio back,
-- but only while the creator still belongs to it. A deleted portfolio's id
-- is refused like another user's. At most 20 owned portfolios per user.
create or replace function public.create_portfolio(p_name text, p_id uuid default null)
returns public.portfolios
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_portfolio public.portfolios;
begin
  if v_uid is null then
    perform app.forbid();
  end if;
  perform private.require_active_account(v_uid);

  if p_id is not null then
    select p.* into v_portfolio from public.portfolios p where p.id = p_id;
    if found then
      if v_portfolio.created_by is distinct from v_uid or not app.has_portfolio_role(p_id, null) then
        perform app.forbid();
      end if;
      return v_portfolio;
    end if;
    -- Refused before the rate limit: probing costs the caller nothing, but
    -- tells them nothing either (the same error as another user's id).
    if exists (select 1 from private.portfolio_ids r where r.id = p_id) then
      perform app.forbid();
    end if;
  end if;

  perform private.enforce_rate_limit('create_portfolio', 10, interval '1 hour');

  if (
    select count(*) from public.portfolio_members m
    where m.user_id = v_uid and m.role = 'owner'
  ) >= 20 then
    perform app.fail('portfolio_limit_reached');
  end if;

  insert into public.portfolios (id, name, created_by)
  values (coalesce(p_id, app.uuid_generate_v7()), btrim(p_name), v_uid)
  returning * into v_portfolio;

  insert into public.portfolio_members (portfolio_id, user_id, role)
  values (v_portfolio.id, v_uid, 'owner');

  return v_portfolio;
end
$$;

-- ---------------------------------------------------------------------------
-- 4. Membership and invitations
-- ---------------------------------------------------------------------------

-- An invitation carries its inviter's authority, so it must not outlive it:
-- when an owner stops being one (demoted, removed, leaving, or the account
-- deleted, whichever path deletes the membership), their pending invitations
-- to that portfolio are revoked. A portfolio being deleted takes its
-- invitations with it, so there is nothing to do then.
create or replace function private.after_owner_membership_ends()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.role = 'owner' then
    return null;
  end if;
  if not exists (select 1 from public.portfolios p where p.id = old.portfolio_id) then
    return null;
  end if;
  update public.portfolio_invitations i
  set revoked_at = now()
  where i.portfolio_id = old.portfolio_id
    and i.invited_by = old.user_id
    and i.accepted_at is null
    and i.revoked_at is null;
  return null;
end
$$;

create trigger portfolio_members_after_owner_ends
  after update of role or delete on public.portfolio_members
  for each row
  when (old.role = 'owner')
  execute function private.after_owner_membership_ends();

-- Changes a member's role. Owners only; the last owner cannot be demoted.
create or replace function public.update_member_role(
  p_portfolio_id uuid,
  p_user_id uuid,
  p_role public.member_role
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_current public.member_role;
begin
  if p_role is null then
    perform app.fail('invalid_role');
  end if;
  perform private.lock_portfolio_for_change(p_portfolio_id, array['owner']::public.member_role[], true);

  select m.role into v_current
  from public.portfolio_members m
  where m.portfolio_id = p_portfolio_id and m.user_id = p_user_id;
  if not found then
    perform app.fail('member_not_found');
  end if;

  if v_current = 'owner' and p_role <> 'owner' and (
    select count(*) from public.portfolio_members m
    where m.portfolio_id = p_portfolio_id and m.role = 'owner'
  ) = 1 then
    perform app.fail('last_owner');
  end if;

  update public.portfolio_members
  set role = p_role
  where portfolio_id = p_portfolio_id and user_id = p_user_id;
end
$$;

-- Removes a member. Owners may remove anyone; every member may remove
-- themselves (leave). The last owner can never be removed.
create or replace function public.remove_member(p_portfolio_id uuid, p_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role public.member_role;
begin
  if v_uid is null then
    perform app.forbid();
  end if;
  perform private.lock_portfolio_for_change(
    p_portfolio_id,
    case when p_user_id = v_uid then null else array['owner']::public.member_role[] end,
    true
  );

  select m.role into v_role
  from public.portfolio_members m
  where m.portfolio_id = p_portfolio_id and m.user_id = p_user_id;
  if not found then
    perform app.fail('member_not_found');
  end if;

  if v_role = 'owner' and (
    select count(*) from public.portfolio_members m
    where m.portfolio_id = p_portfolio_id and m.role = 'owner'
  ) = 1 then
    perform app.fail('last_owner');
  end if;

  delete from public.portfolio_members
  where portfolio_id = p_portfolio_id and user_id = p_user_id;
end
$$;

-- Creates (or replaces) a pending invitation and returns the one-time token
-- `<invitation-id>.<base64url verifier>`. The token is shown once; only its
-- SHA-256 is stored.
create or replace function public.create_invitation(
  p_portfolio_id uuid,
  p_email text,
  p_role public.member_role
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_verifier bytea := extensions.gen_random_bytes(32);
  v_invitation public.portfolio_invitations;
begin
  perform private.lock_portfolio_for_change(p_portfolio_id, array['owner']::public.member_role[], false);
  perform private.enforce_rate_limit('create_invitation', 20, interval '1 hour');

  if p_role is null then
    perform app.fail('invalid_role');
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,63}$' or char_length(v_email) > 254 then
    perform app.fail('invalid_email');
  end if;

  if exists (
    select 1
    from public.portfolio_members m
    join public.profiles p on p.id = m.user_id
    where m.portfolio_id = p_portfolio_id and p.email = v_email
  ) then
    perform app.fail('already_member');
  end if;

  update public.portfolio_invitations
  set revoked_at = now()
  where portfolio_id = p_portfolio_id
    and email = v_email
    and accepted_at is null
    and revoked_at is null;

  insert into public.portfolio_invitations
    (portfolio_id, email, role, verifier_hash, invited_by, expires_at)
  values
    (p_portfolio_id, v_email, p_role, sha256(v_verifier), (select auth.uid()), now() + interval '7 days')
  returning * into v_invitation;

  return jsonb_build_object(
    'invitation_id', v_invitation.id,
    'email', v_invitation.email,
    'role', v_invitation.role,
    'expires_at', v_invitation.expires_at,
    'token', v_invitation.id::text || '.' || private.base64url_encode(v_verifier)
  );
end
$$;

create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
begin
  select i.portfolio_id into v_portfolio_id
  from public.portfolio_invitations i
  where i.id = p_invitation_id;
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_portfolio_for_change(v_portfolio_id, array['owner']::public.member_role[], false);

  update public.portfolio_invitations
  set revoked_at = now()
  where id = p_invitation_id and accepted_at is null and revoked_at is null;
end
$$;

-- Accepts an invitation for the signed-in, e-mail-verified user whose e-mail
-- matches the invitation. Failures are returned as a status (not raised) so
-- the attempt is committed and counts towards the rate limit. Locks follow
-- the global order: the caller's account (refused while it is being
-- deleted), the portfolio key, then the invitation row. An invitation whose
-- inviter is no longer an owner of the portfolio (removed, demoted, or the
-- account deleted) is revoked, and reported so; the check comes after the
-- verifier and the accepted check, so it reveals nothing to a guessed
-- selector and an accepted invitation's retry still succeeds.
create or replace function public.accept_invitation(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_selector uuid;
  v_verifier bytea;
  v_portfolio_id uuid;
  v_invitation public.portfolio_invitations;
  v_user_email text;
  v_confirmed timestamptz;
  v_existing_role public.member_role;
begin
  if v_uid is null then
    perform app.forbid();
  end if;
  perform private.enforce_rate_limit('accept_invitation', 10, interval '10 minutes');

  if p_token is null or p_token !~ '^[0-9a-f-]{36}\.[A-Za-z0-9_-]{43}$' then
    return jsonb_build_object('status', 'invalid');
  end if;
  if split_part(p_token, '.', 1) !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return jsonb_build_object('status', 'invalid');
  end if;
  v_selector := split_part(p_token, '.', 1)::uuid;
  v_verifier := private.base64url_decode(split_part(p_token, '.', 2));
  if v_verifier is null or length(v_verifier) <> 32 then
    return jsonb_build_object('status', 'invalid');
  end if;

  perform private.require_active_account(v_uid);

  select i.portfolio_id into v_portfolio_id from public.portfolio_invitations i where i.id = v_selector;
  if found then
    perform 1 from public.portfolios p where p.id = v_portfolio_id for key share;
  end if;

  select i.* into v_invitation
  from public.portfolio_invitations i
  where i.id = v_selector
  for update;

  if not found or not private.timing_safe_equal(sha256(v_verifier), v_invitation.verifier_hash) then
    return jsonb_build_object('status', 'invalid');
  end if;
  if v_invitation.revoked_at is not null then
    return jsonb_build_object('status', 'revoked');
  end if;
  if v_invitation.accepted_at is not null then
    if v_invitation.accepted_by = v_uid then
      return jsonb_build_object(
        'status', 'accepted',
        'portfolio_id', v_invitation.portfolio_id,
        'role', v_invitation.role
      );
    end if;
    return jsonb_build_object('status', 'already_used');
  end if;
  if v_invitation.expires_at <= now() then
    return jsonb_build_object('status', 'expired');
  end if;
  if v_invitation.invited_by is null or not exists (
    select 1
    from public.portfolio_members m
    where m.portfolio_id = v_invitation.portfolio_id
      and m.user_id = v_invitation.invited_by
      and m.role = 'owner'
  ) then
    update public.portfolio_invitations set revoked_at = now() where id = v_invitation.id;
    return jsonb_build_object('status', 'revoked');
  end if;

  select lower(u.email), u.email_confirmed_at into v_user_email, v_confirmed
  from auth.users u
  where u.id = v_uid;
  if v_confirmed is null then
    return jsonb_build_object('status', 'email_not_verified');
  end if;
  if v_user_email is distinct from v_invitation.email then
    return jsonb_build_object('status', 'email_mismatch');
  end if;

  select m.role into v_existing_role
  from public.portfolio_members m
  where m.portfolio_id = v_invitation.portfolio_id and m.user_id = v_uid;

  if not found then
    insert into public.portfolio_members (portfolio_id, user_id, role, invited_by)
    values (v_invitation.portfolio_id, v_uid, v_invitation.role, v_invitation.invited_by);
  end if;

  update public.portfolio_invitations
  set accepted_at = now(), accepted_by = v_uid
  where id = v_invitation.id;

  return jsonb_build_object(
    'status', 'accepted',
    'portfolio_id', v_invitation.portfolio_id,
    'role', coalesce(v_existing_role, v_invitation.role)
  );
end
$$;

-- ---------------------------------------------------------------------------
-- 5. Deleting portfolios and accounts
-- ---------------------------------------------------------------------------

-- Audit rows no longer reference the portfolio: the foreign-key check made
-- every audited UPDATE or DELETE take the portfolio key after its own row,
-- the reverse of the global order, and a deletion's cascade deadlocked
-- against it. Deletions remove a portfolio's audit trail explicitly, and the
-- daily cleanup removes rows a transaction racing the deletion wrote after it.
alter table public.audit_logs drop constraint audit_logs_portfolio_id_fkey;

-- Deletes portfolios the caller has locked, with their audit trail; the rest
-- cascades.
create or replace function private.delete_locked_portfolios(p_portfolio_ids uuid[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  delete from public.audit_logs a where a.portfolio_id = any (p_portfolio_ids);
  delete from public.portfolios p where p.id = any (p_portfolio_ids);
end
$$;

-- Fails unless the typed confirmation matches the portfolio's name
-- (case-insensitive, surrounding spaces ignored).
create or replace function private.require_portfolio_name(p_portfolio_id uuid, p_confirmation text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  select p.name into v_name from public.portfolios p where p.id = p_portfolio_id;
  if not found then
    perform app.forbid();
  end if;
  if lower(btrim(coalesce(p_confirmation, ''))) <> lower(btrim(v_name)) then
    perform app.fail('confirmation_mismatch');
  end if;
end
$$;

-- Deletes a portfolio and everything in it. The caller must be an owner and
-- must type the portfolio name to confirm (case-insensitive). A mistyped
-- name fails before any lock is taken. The lock-and-delete step runs in a
-- subtransaction and is retried (up to three times) if the deadlock detector
-- picks it against a client write that locked a row before the portfolio.
create or replace function public.delete_portfolio(p_portfolio_id uuid, p_confirmation text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_roles public.member_role[] := array['owner']::public.member_role[];
  v_attempt integer := 0;
begin
  perform app.require_portfolio_role(p_portfolio_id, v_roles);
  perform private.require_portfolio_name(p_portfolio_id, p_confirmation);

  loop
    v_attempt := v_attempt + 1;
    begin
      perform private.lock_portfolios_for_deletion(array[p_portfolio_id]);
      perform app.require_portfolio_role(p_portfolio_id, v_roles);
      perform private.require_portfolio_name(p_portfolio_id, p_confirmation);
      perform private.delete_locked_portfolios(array[p_portfolio_id]);
      return;
    exception when deadlock_detected then
      if v_attempt >= 3 then
        raise;
      end if;
    end;
  end loop;
end
$$;

-- Deletes the user's sole-owned portfolios (cascading to all their data) and
-- removes the user from every other portfolio. Returns the deleted ids.
-- First the account is frozen: its profile is locked and the deletion
-- recorded, so the user's other devices can neither create a portfolio nor
-- accept an invitation from now on. Then every portfolio the user belongs to
-- is locked, and only then is it decided which portfolios die with the
-- account: a co-owner deleting their account at the same moment waits, then
-- sees this user gone and deletes the portfolio they now own alone, instead
-- of both leaving and orphaning it. Retried like delete_portfolio.
create or replace function public.admin_delete_account_data(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_memberships uuid[];
  v_deleted uuid[];
  v_attempt integer := 0;
begin
  if p_user_id is null then
    perform app.fail('invalid_user');
  end if;

  perform 1 from public.profiles p where p.id = p_user_id for update;
  insert into private.account_deletions (user_id)
  select p_user_id
  where exists (select 1 from auth.users u where u.id = p_user_id)
  on conflict (user_id) do nothing;

  loop
    v_attempt := v_attempt + 1;
    begin
      select coalesce(array_agg(m.portfolio_id order by m.portfolio_id), '{}'::uuid[]) into v_memberships
      from public.portfolio_members m
      where m.user_id = p_user_id;
      perform private.lock_portfolios_for_deletion(v_memberships);

      select coalesce(array_agg(s.portfolio_id order by s.portfolio_id), '{}'::uuid[]) into v_deleted
      from public.admin_account_deletion_scope(p_user_id) s
      where s.portfolio_id = any (v_memberships);

      perform private.delete_locked_portfolios(v_deleted);
      delete from public.portfolio_members m
      where m.user_id = p_user_id and m.portfolio_id = any (v_memberships);
      exit;
    exception when deadlock_detected then
      if v_attempt >= 3 then
        raise;
      end if;
    end;
  end loop;

  delete from public.notifications n where n.user_id = p_user_id;
  return jsonb_build_object('deleted_portfolio_ids', to_jsonb(v_deleted));
end
$$;

-- ---------------------------------------------------------------------------
-- 6. Storage cleanup queue
-- ---------------------------------------------------------------------------

-- Storage objects (one file, or every file under a folder prefix ending in
-- '/') waiting to be deleted through the Storage API.
create table private.storage_cleanup_queue (
  id bigint generated always as identity primary key,
  bucket_id text not null,
  path text not null
    constraint storage_cleanup_queue_path_check check (char_length(path) between 1 and 1024),
  is_prefix boolean not null,
  reason text not null
    constraint storage_cleanup_queue_reason_check
      check (reason in ('document_deleted', 'portfolio_deleted', 'orphaned')),
  enqueued_at timestamptz not null default now(),
  not_before timestamptz not null default now(),
  claimed_until timestamptz,
  attempts integer not null default 0
    constraint storage_cleanup_queue_attempts_check check (attempts >= 0),
  last_error text,
  -- The portfolio folder an item belongs to: claims take turns between them.
  folder text not null generated always as (split_part(path, '/', 1)) stored,
  constraint storage_cleanup_queue_item_key unique (bucket_id, path),
  constraint storage_cleanup_queue_prefix_check check (is_prefix = (right(path, 1) = '/'))
);

comment on table private.storage_cleanup_queue is
  'Storage objects or folder prefixes to delete through the Storage API (drained by storage-cleanup).';

create index storage_cleanup_queue_due_idx on private.storage_cleanup_queue (not_before, id);

revoke all on private.storage_cleanup_queue from public, anon, authenticated;

-- Queues the files of deleted document rows (row deletes and cascades). Only
-- files that exist are queued: rows can no longer be written without their
-- file, and older rows without one have nothing to delete.
create or replace function private.after_documents_delete_queue_files()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', d.storage_path, false, 'document_deleted'
  from deleted_documents d
  where exists (
    select 1 from storage.objects o where o.bucket_id = 'documents' and o.name = d.storage_path
  )
  on conflict (bucket_id, path) do nothing;
  return null;
end
$$;

create trigger documents_after_delete_queue_files
  after delete on public.documents
  referencing old table as deleted_documents
  for each statement execute function private.after_documents_delete_queue_files();

-- Retires the ids of deleted portfolios and queues their whole folders: the
-- folder item also catches files whose document row was never written or
-- whose upload finished after the delete.
create or replace function private.after_portfolios_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.portfolio_ids r
  set retired_at = now()
  from deleted_portfolios p
  where r.id = p.id and r.retired_at is null;

  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', p.id::text || '/', true, 'portfolio_deleted'
  from deleted_portfolios p
  on conflict (bucket_id, path) do nothing;
  return null;
end
$$;

create trigger portfolios_after_delete
  after delete on public.portfolios
  referencing old table as deleted_portfolios
  for each statement execute function private.after_portfolios_delete();

-- The table that holds the entities of a document entity type.
create or replace function private.document_entity_table(p_entity_type public.document_entity)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_entity_type
    when 'property' then 'properties'
    when 'unit' then 'units'
    when 'tenant' then 'tenants'
    when 'lease' then 'leases'
    when 'payment' then 'payments'
    when 'expense' then 'expenses'
    when 'maintenance_request' then 'maintenance_requests'
    when 'utility_bill' then 'utility_bills'
    when 'meter_reading' then 'meter_readings'
  end
$$;

-- Documents belong to an entity through (entity_type, entity_id) without a
-- foreign key, so deleting the entity deletes its documents here (which
-- queues their files).
create or replace function private.after_entity_delete_documents()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.documents d
  using deleted_entities e
  where d.portfolio_id = e.portfolio_id
    and d.entity_type = tg_argv[0]::public.document_entity
    and d.entity_id = e.id;
  return null;
end
$$;

create trigger properties_after_delete_documents
  after delete on public.properties referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('property');
create trigger units_after_delete_documents
  after delete on public.units referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('unit');
create trigger tenants_after_delete_documents
  after delete on public.tenants referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('tenant');
create trigger leases_after_delete_documents
  after delete on public.leases referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('lease');
create trigger payments_after_delete_documents
  after delete on public.payments referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('payment');
create trigger expenses_after_delete_documents
  after delete on public.expenses referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('expense');
create trigger maintenance_requests_after_delete_documents
  after delete on public.maintenance_requests referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('maintenance_request');
create trigger utility_bills_after_delete_documents
  after delete on public.utility_bills referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('utility_bill');
create trigger meter_readings_after_delete_documents
  after delete on public.meter_readings referencing old table as deleted_entities
  for each statement execute function private.after_entity_delete_documents('meter_reading');

-- ---------------------------------------------------------------------------
-- 7. Document rows record uploaded files of live entities
-- ---------------------------------------------------------------------------

-- Checks a new document row before it is written:
--   * the caller may write documents in the portfolio (checked first, so a
--     non-member's insert never locks or probes another landlord's rows
--     before the row policy refuses it);
--   * the entity exists and is locked for key share, after the portfolio key
--     (the global order): an entity delete then waits for this insert, and
--     its trigger deletes this row too, or the insert finds the entity gone.
create or replace function private.before_document_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_found boolean;
begin
  if (select auth.uid()) is not null and not app.has_portfolio_role(
    new.portfolio_id, array['owner', 'manager', 'accountant']::public.member_role[]
  ) then
    perform app.forbid();
  end if;

  perform 1 from public.portfolios p where p.id = new.portfolio_id for key share;
  execute format(
    'select true from public.%I e where e.id = $1 and e.portfolio_id = $2 for key share',
    private.document_entity_table(new.entity_type)
  ) into v_found using new.entity_id, new.portfolio_id;
  if v_found is null then
    perform app.fail('document_entity_not_found');
  end if;
  return new;
end
$$;

-- Checks the file of a new document row, after the row's own constraints:
--   * it has been uploaded (upload first, then the row);
--   * it is not queued for deletion: the cleaner lists a file and deletes it
--     later, and a row written in between would be left pointing at nothing.
--     This runs AFTER the insert on purpose: the insert first waits for a
--     concurrent delete of a row with the same path (unique index), so the
--     check sees the file that delete queued. Re-adding a deleted file means
--     uploading it again under a new name.
create or replace function private.after_document_insert_check_file()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from storage.objects o where o.bucket_id = 'documents' and o.name = new.storage_path
  ) then
    perform app.fail('document_file_missing');
  end if;
  if exists (
    select 1
    from private.storage_cleanup_queue q
    where q.bucket_id = 'documents'
      and q.path in (new.storage_path, split_part(new.storage_path, '/', 1) || '/')
  ) then
    perform app.fail('document_file_pending_deletion');
  end if;
  return null;
end
$$;

create trigger documents_after_insert_check_file
  after insert on public.documents
  for each row execute function private.after_document_insert_check_file();

-- Deletes document rows whose entity no longer exists (rows written before
-- inserts locked their entity). Their files are queued by the documents
-- delete trigger. Returns how many rows it deleted.
create or replace function private.delete_orphaned_documents()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_type public.document_entity;
  v_rows integer;
  v_total integer := 0;
begin
  foreach v_type in array enum_range(null::public.document_entity) loop
    execute format(
      'delete from public.documents d
       where d.entity_type = $1
         and not exists (
           select 1 from public.%I e where e.id = d.entity_id and e.portfolio_id = d.portfolio_id
         )',
      private.document_entity_table(v_type)
    ) using v_type;
    get diagnostics v_rows = row_count;
    v_total := v_total + v_rows;
  end loop;
  return v_total;
end
$$;

-- Owners and managers may delete an uploaded file only while no document row
-- references it (an upload whose row was never written). A referenced file
-- is deleted by deleting its row, which queues the file for the cleaner.
drop policy documents_objects_delete on storage.objects;
create policy documents_objects_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and app.document_object_portfolio(name) = any ((select app.my_portfolio_ids(
      array['owner', 'manager']::public.member_role[]))::text[])
    and not exists (select 1 from public.documents d where d.storage_path = objects.name)
  );

-- ---------------------------------------------------------------------------
-- 8. Draining the queue
-- ---------------------------------------------------------------------------

-- Queues files that no trigger saw, after deleting document rows whose
-- entity is gone: the folders of portfolios that no longer exist (their ids
-- are registered as retired, so they can never be claimed), and files
-- without a document row for a day (an upload whose row was never written).
-- Run once a day by private.cleanup(). Returns how many items it queued.
create or replace function private.enqueue_orphaned_storage(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
  v_total integer := 0;
begin
  perform private.delete_orphaned_documents();

  -- The CASE guards the cast: AND does not fix an evaluation order.
  with folders as (
    select distinct f.portfolio_id
    from (
      select case
               when split_part(o.name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
               then split_part(o.name, '/', 1)::uuid
             end as portfolio_id
      from storage.objects o
      where o.bucket_id = 'documents'
    ) f
    where f.portfolio_id is not null
      and not exists (select 1 from public.portfolios p where p.id = f.portfolio_id)
  ), retired as (
    insert into private.portfolio_ids (id, retired_at)
    select f.portfolio_id, p_now from folders f
    on conflict (id) do nothing
  )
  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', f.portfolio_id::text || '/', true, 'orphaned'
  from folders f
  on conflict (bucket_id, path) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', o.name, false, 'orphaned'
  from storage.objects o
  where o.bucket_id = 'documents'
    and o.created_at < p_now - interval '1 day'
    and right(o.name, 1) <> '/'
    and not exists (select 1 from public.documents d where d.storage_path = o.name)
  on conflict (bucket_id, path) do nothing;
  get diagnostics v_rows = row_count;
  return v_total + v_rows;
end
$$;

-- Claims up to p_limit due items for p_lease_seconds; an item whose cleaner
-- died is claimable again once its lease expires. Folders take turns (each
-- folder's oldest item first, then each folder's second ...), so one
-- portfolio's backlog cannot hold up everyone else's deletions. The due
-- conditions are checked again where the rows are locked (SKIP LOCKED):
-- under READ COMMITTED that recheck is what keeps concurrent cleaners from
-- taking the same item. p_paths restricts the claim to those items
-- (delete-account cleans the folders it just deleted). Secret key only.
create or replace function public.admin_claim_storage_cleanup(
  p_limit integer default 20,
  p_lease_seconds integer default 120,
  p_paths text[] default null
)
returns table (id bigint, bucket_id text, path text, is_prefix boolean, attempts integer)
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit not between 1 and 100
     or p_lease_seconds is null or p_lease_seconds not between 30 and 900 then
    perform app.fail('invalid_claim');
  end if;

  return query
  update private.storage_cleanup_queue q
  set claimed_until = now() + make_interval(secs => p_lease_seconds),
      attempts = q.attempts + 1
  where q.id in (
    select l.id
    from private.storage_cleanup_queue l
    where l.id in (
        select r.id
        from (
          select c.id, c.not_before,
                 row_number() over (partition by c.folder order by c.not_before, c.id) as turn
          from private.storage_cleanup_queue c
          where c.not_before <= now()
            and (c.claimed_until is null or c.claimed_until < now())
            and (p_paths is null or c.path = any (p_paths))
        ) r
        order by r.turn, r.not_before, r.id
        limit p_limit
      )
      and l.not_before <= now()
      and (l.claimed_until is null or l.claimed_until < now())
      and (p_paths is null or l.path = any (p_paths))
    for update skip locked
  )
  returning q.id, q.bucket_id, q.path, q.is_prefix, q.attempts;
end
$$;

-- Up to p_limit object names of a claimed item that may be deleted: the
-- object itself, or every object under the prefix (a C-collation range, the
-- order of storage's own index). An object a live document row still
-- references is never returned, whatever was queued. Secret key only.
create or replace function public.admin_storage_cleanup_objects(p_item_id bigint, p_limit integer default 1000)
returns table (name text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item private.storage_cleanup_queue;
  v_limit integer := least(greatest(coalesce(p_limit, 1000), 1), 1000);
begin
  select q.* into v_item from private.storage_cleanup_queue q where q.id = p_item_id;
  if not found then
    return;
  end if;

  if v_item.is_prefix then
    return query
    select distinct o.name
    from storage.objects o
    where o.bucket_id = v_item.bucket_id
      and o.name collate "C" >= v_item.path collate "C"
      and o.name collate "C" < (left(v_item.path, -1) || chr(ascii(right(v_item.path, 1)) + 1)) collate "C"
      and starts_with(o.name, v_item.path)
      and not exists (select 1 from public.documents d where d.storage_path = o.name)
    order by o.name
    limit v_limit;
  else
    return query
    select distinct o.name
    from storage.objects o
    where o.bucket_id = v_item.bucket_id
      and o.name = v_item.path
      and not exists (select 1 from public.documents d where d.storage_path = o.name);
  end if;
end
$$;

-- Reports a claimed item. With p_error: retried with exponential backoff
-- (1 minute doubling to 6 hours) over consecutive failed claims. With
-- p_finished (no object left): a file is done; a folder is swept once more
-- 15 minutes after it was queued, for uploads that were in flight when it
-- was deleted, and then done. Otherwise (time ran out mid-item) it is due
-- again at once. A claim that ends without an error resets the failure count,
-- so items handed back unfinished never inherit a long backoff. Returns
-- 'done', 'rescheduled', 'retry' or 'missing'. Secret key only.
create or replace function public.admin_complete_storage_cleanup(
  p_item_id bigint,
  p_finished boolean,
  p_error text default null
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_item private.storage_cleanup_queue;
begin
  select q.* into v_item from private.storage_cleanup_queue q where q.id = p_item_id for update;
  if not found then
    return 'missing';
  end if;

  if p_error is not null then
    update private.storage_cleanup_queue
    set claimed_until = null,
        last_error = left(p_error, 500),
        not_before = now() + least(
          interval '6 hours',
          interval '1 minute' * power(2, least(greatest(v_item.attempts - 1, 0), 9))
        )
    where id = p_item_id;
    return 'retry';
  end if;

  if coalesce(p_finished, false)
     and (not v_item.is_prefix or now() >= v_item.enqueued_at + interval '15 minutes') then
    delete from private.storage_cleanup_queue where id = p_item_id;
    return 'done';
  end if;

  update private.storage_cleanup_queue
  set claimed_until = null,
      attempts = 0,
      last_error = null,
      not_before = case
        when coalesce(p_finished, false) then v_item.enqueued_at + interval '15 minutes'
        else now()
      end
  where id = p_item_id;
  return 'rescheduled';
end
$$;

revoke all on function
  public.admin_claim_storage_cleanup(integer, integer, text[]),
  public.admin_storage_cleanup_objects(bigint, integer),
  public.admin_complete_storage_cleanup(bigint, boolean, text)
from public, anon, authenticated;
grant execute on function
  public.admin_claim_storage_cleanup(integer, integer, text[]),
  public.admin_storage_cleanup_objects(bigint, integer),
  public.admin_complete_storage_cleanup(bigint, boolean, text)
to service_role;

-- Asks the storage-cleanup Edge Function to drain the queue when something
-- is due. Needs pg_net and two Vault secrets set by the operator:
-- mm_project_url (https://<ref>.supabase.co) and mm_storage_cleanup_token
-- (the function's STORAGE_CLEANUP_TOKEN). Returns what it did.
create or replace function private.request_storage_cleanup()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_token text;
begin
  if to_regnamespace('net') is null or to_regclass('vault.decrypted_secrets') is null then
    return 'unavailable';
  end if;
  if not exists (
    select 1
    from private.storage_cleanup_queue q
    where q.not_before <= now() and (q.claimed_until is null or q.claimed_until < now())
  ) then
    return 'idle';
  end if;

  execute $sql$
    select max(s.decrypted_secret) filter (where s.name = 'mm_project_url'),
           max(s.decrypted_secret) filter (where s.name = 'mm_storage_cleanup_token')
    from vault.decrypted_secrets s
    where s.name in ('mm_project_url', 'mm_storage_cleanup_token')
  $sql$ into v_url, v_token;
  if v_url is null or v_token is null then
    return 'not_configured';
  end if;

  execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := $4)'
    using rtrim(v_url, '/') || '/functions/v1/storage-cleanup',
          '{}'::jsonb,
          jsonb_build_object('content-type', 'application/json', 'x-cleanup-token', v_token),
          60000;
  return 'requested';
end
$$;

-- Daily housekeeping, now also queueing orphaned files and removing audit
-- rows that a transaction racing a portfolio deletion wrote after it.
create or replace function private.cleanup(p_now timestamptz default now())
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  delete from private.rate_limit_buckets where window_start < p_now - interval '2 hours';
  delete from public.notifications where created_at < p_now - interval '180 days';
  delete from public.portfolio_invitations
  where accepted_at is null and expires_at < p_now - interval '90 days';
  delete from private.job_runs where run_on < (p_now - interval '400 days')::date;
  delete from private.lease_maintenance m
  using public.leases l
  where l.id = m.lease_id and l.status <> 'active';
  delete from public.audit_logs a
  using private.portfolio_ids r
  where r.retired_at >= p_now - interval '7 days'
    and a.portfolio_id = r.id;
  perform private.enqueue_orphaned_storage(p_now);
  -- pg_cron keeps a row per run; keep two weeks of history where it runs.
  if to_regclass('cron.job_run_details') is not null then
    execute 'delete from cron.job_run_details where end_time < $1' using p_now - interval '14 days';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 9. Privileges, backfills and schedules
-- ---------------------------------------------------------------------------

revoke all on function
  private.require_active_account(uuid),
  private.lock_portfolio_for_change(uuid, public.member_role[], boolean),
  private.lock_portfolios_for_deletion(uuid[]),
  private.before_manual_charge_insert(),
  private.after_portfolio_insert_register_id(),
  private.after_owner_membership_ends(),
  private.delete_locked_portfolios(uuid[]),
  private.require_portfolio_name(uuid, text),
  private.after_documents_delete_queue_files(),
  private.after_portfolios_delete(),
  private.document_entity_table(public.document_entity),
  private.after_entity_delete_documents(),
  private.after_document_insert_check_file(),
  private.delete_orphaned_documents(),
  private.enqueue_orphaned_storage(timestamptz),
  private.request_storage_cleanup()
from public, anon, authenticated;

-- Every live portfolio id, and the folder of every portfolio deleted before
-- this migration (its files were left behind), is registered.
insert into private.portfolio_ids (id, registered_at)
select p.id, p.created_at from public.portfolios p
on conflict (id) do nothing;

insert into private.portfolio_ids (id, retired_at)
select distinct f.portfolio_id, now()
from (
  select case
           when split_part(o.name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           then split_part(o.name, '/', 1)::uuid
         end as portfolio_id
  from storage.objects o
  where o.bucket_id = 'documents'
) f
where f.portfolio_id is not null
  and not exists (select 1 from public.portfolios p where p.id = f.portfolio_id)
on conflict (id) do nothing;

-- Document rows orphaned before this migration go now (queueing their files).
select private.delete_orphaned_documents();

-- pg_net (where available) and a 10-minute schedule (where pg_cron runs).
do $$
begin
  if exists (select 1 from pg_catalog.pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_catalog.pg_extension where extname = 'pg_cron') then
    perform cron.schedule('mm-storage-cleanup', '*/10 * * * *', 'select private.request_storage_cleanup()');
  end if;
end
$$;
