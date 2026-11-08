-- ============================================================================
-- Invitation findings of the formal model formal/tla/Invitations (F1-F4).
--
-- The global lock order (20261105072426_membership_deletion_storage.sql):
--
--   1. the account      2. the portfolio      3. the lease      4. other rows
--
-- create_invitation, revoke_invitation and accept_invitation take the
-- portfolio key (FOR KEY SHARE) before any invitation row; membership changes
-- and deletions take the portfolio FOR UPDATE. Each function below is based
-- on its last definition, in 20261105072426_membership_deletion_storage.sql.
--
-- Findings:
--   F1  (low) Two concurrent re-invites of one e-mail to one portfolio (two
--       owners, or one owner's double submit) both passed the portfolio key
--       (key share does not exclude key share) and both found no pending
--       invitation to revoke; the second INSERT then met the first's
--       committed row in portfolio_invitations_pending_email_key and failed
--       with an unmapped 23505 (invite-member: HTTP 409 "This already
--       exists"), although a re-invite normally replaces the pending one.
--   F2  (low) accept_invitation's "already accepted by me" branch (a retry
--       after a lost response) reported the invitation's role. A member who
--       had joined through another invitation, with another role, was told
--       a role they do not have; one removed from the portfolio since (or
--       who had left it) was told they were a member.
--   F3  (low) Deleting an inviter directly in Auth (dashboard, Auth admin
--       API) while their invitation is being accepted can deadlock: GoTrue's
--       DELETE holds the auth.users row and its ON DELETE SET NULL of
--       portfolio_invitations.invited_by waits for the invitation the accept
--       holds, while the accept's membership INSERT waits for key share on
--       that auth.users row (its foreign-key check on invited_by).
--   F4  (low) Deleting an inviter directly in Auth left their pending
--       invitations pending: the CASCADE of the owner's membership queues
--       portfolio_members_after_owner_ends, which fires only after the next
--       ON DELETE action has set invited_by to NULL, so its
--       "invited_by = old.user_id" matched nothing. accept_invitation still
--       refused such an invitation (it revokes one without an inviter), but
--       it was listed to the owners as pending.
--
-- Fixes:
--   F1  create_invitation takes a transaction advisory lock on (portfolio,
--       e-mail) right after the portfolio key and the input checks. A second
--       re-invite of the same e-mail waits there; when it goes on, its next
--       statement sees the first one's committed invitation and revokes it,
--       as a re-invite one after the other does. Both calls succeed and one
--       invitation stays pending (the later one). The lock is "other rows"
--       in the global order (after the portfolio), only creates take it, and
--       a create holds no other lock a create of another (portfolio, e-mail)
--       waits for. The key is the first 64 bits of the SHA-256 of
--       'invitation:<portfolio>:<e-mail>' (one-key form), not a
--       hashtextextended() value: the inviting owner chooses the e-mail, and
--       PostgreSQL's text hash is not built to resist chosen collisions, so
--       an owner could otherwise aim at another portfolio's key or at
--       run_daily_jobs' key in the same lock space. A collision now needs
--       about 2^64 tries for a given key, so it is accidental only, and
--       makes at worst two unrelated creates wait for each other for one
--       statement's time.
--   F2  The retry branch answers the role the caller holds in the portfolio
--       now (the caller holds the portfolio key, so no membership change
--       commits meanwhile). A caller who is no longer a member (removed, or
--       left, since accepting) is answered 'revoked', an existing status the
--       app shows as "This invitation was cancelled. Ask an owner of the
--       portfolio for a new one."; nothing is written, and the accepted row
--       stays accepted (its terminal-state CHECK forbids revoked_at on it).
--   F4  private.after_owner_membership_ends also revokes the portfolio's
--       pending invitations whose inviter is NULL (accept_invitation refuses
--       them anyway, so nothing that could be accepted is lost). Pending
--       invitations left behind earlier, with no inviter or one who is no
--       longer an owner, are revoked once below: accept_invitation would
--       refuse every one of them.
--   F3  is not changed in code; the rule is in docs/operations.md: delete an
--       account through the delete-account Edge Function, or run
--       public.admin_delete_account_data(<user id>) before deleting the user
--       in the dashboard or through the Auth admin API. That function takes
--       the account and then the portfolios FOR UPDATE, so in-flight accepts
--       finish first and later ones find the inviter gone; GoTrue's delete
--       then has nothing left to wait for. A BEFORE DELETE trigger on
--       auth.users running the same work was evaluated and rejected:
--       PostgreSQL locks the auth.users row before a BEFORE ROW trigger runs
--       (on 16.15 and 17.11 a test trigger's body started only after a
--       concurrent FOR KEY SHARE of the row had committed), so the trigger
--       would take the account and the portfolio after the auth row. Every
--       insert that references the user takes key share on that row at the
--       end of its statement, after the portfolio key, so the trigger
--       reverses their order: on PostgreSQL 16.15 and 17.11 (the hosted
--       major version) the F3 interleaving with such a trigger still
--       deadlocked (twice per run: the trigger's retry, then the accept
--       failed with 40P01). Privileges were not the obstacle
--       (on_auth_user_change of
--       20261103192722_identity_portfolios.sql is already a trigger on
--       auth.users), nor the delete-account Edge Function's double run (a
--       second admin_delete_account_data returns no portfolios and changes
--       nothing); but the trigger would also run inside GoTrue's
--       transaction, so any error it raised would fail the Auth deletion.
--       The model keeps F3 as an open finding with the operational remedy
--       (Invitations_gotrue_via_delete_account.cfg passes).
--
-- No new refusal codes: F1's second call now succeeds instead of failing;
-- F2 changes the reported role, and answers 'revoked' (already returned for
-- an invitation that can no longer be used) to a retry by a former member
-- instead of 'accepted'; F4 turns invitations that accept_invitation
-- answered with 'revoked' into revoked rows, which it answers with 'revoked'
-- as before.
-- ============================================================================

-- A migration waits at most 5 s for a lock (replacing a trigger function
-- and revoking stale invitations lock only a few rows and catalogue entries)
-- instead of queueing the app's traffic behind it; `set local` keeps both
-- settings inside this migration's transaction.
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- F1: re-invites of one e-mail are serialised
-- ---------------------------------------------------------------------------

-- Creates (or replaces) a pending invitation and returns the one-time token
-- `<invitation-id>.<base64url verifier>`. The token is shown once; only its
-- SHA-256 is stored. Locks: the portfolio key (lock_portfolio_for_change,
-- which authorises again after it), then the advisory lock of the
-- (portfolio, e-mail) pair, then the pending invitation it replaces.
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

  -- F1: one create per (portfolio, e-mail) at a time. The statements below
  -- run after the wait, each with a fresh snapshot, so they see an
  -- invitation a concurrent create committed and replace it.
  perform pg_advisory_xact_lock(
    ('x' || encode(substr(sha256(convert_to('invitation:' || p_portfolio_id::text || ':' || v_email, 'UTF8')), 1, 8), 'hex'))::bit(64)::bigint
  );

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

comment on function public.create_invitation(uuid, text, public.member_role) is
  'Creates or replaces the pending invitation of an e-mail (owners only); concurrent re-invites of one e-mail are serialised by an advisory lock, so the later one replaces the earlier.';

revoke all on function public.create_invitation(uuid, text, public.member_role) from public, anon;
grant execute on function public.create_invitation(uuid, text, public.member_role) to authenticated;

-- ---------------------------------------------------------------------------
-- F2: a retried acceptance reports the member's role
-- ---------------------------------------------------------------------------

-- Accepts an invitation for the signed-in, e-mail-verified user whose e-mail
-- matches the invitation. Failures are returned as a status (not raised) so
-- the attempt is committed and counts towards the rate limit. Locks follow
-- the global order: the caller's account (refused while it is being
-- deleted), the portfolio key, then the invitation row. An invitation whose
-- inviter is no longer an owner of the portfolio (removed, demoted, or the
-- account deleted) is revoked, and reported so; the check comes after the
-- verifier and the accepted check, so it reveals nothing to a guessed
-- selector and an accepted invitation's retry still succeeds. A success
-- (first or retried) reports the role the caller holds in the portfolio,
-- which differs from the invitation's when they had joined another way; a
-- retry by a caller who is no longer a member is answered 'revoked'.
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
      -- F2: the role the caller holds now (the portfolio key keeps it
      -- stable), not the invitation's; a former member (removed or left
      -- since) holds none, and the invitation no longer gives them access.
      select m.role into v_existing_role
      from public.portfolio_members m
      where m.portfolio_id = v_invitation.portfolio_id and m.user_id = v_uid;
      if v_existing_role is null then
        return jsonb_build_object('status', 'revoked');
      end if;
      return jsonb_build_object(
        'status', 'accepted',
        'portfolio_id', v_invitation.portfolio_id,
        'role', v_existing_role
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

comment on function public.accept_invitation(text) is
  'Accepts an invitation for the verified invitee; returns a status, and on success (also on a retry) the role the caller holds in the portfolio; a retry by a former member answers revoked.';

revoke all on function public.accept_invitation(text) from public, anon;
grant execute on function public.accept_invitation(text) to authenticated;

-- ---------------------------------------------------------------------------
-- F4: an inviter deleted directly in Auth leaves nothing pending
-- ---------------------------------------------------------------------------

-- An invitation carries its inviter's authority, so it must not outlive it:
-- when an owner stops being one (demoted, removed, leaving, or the account
-- deleted, whichever path deletes the membership), their pending invitations
-- to that portfolio are revoked. A portfolio being deleted takes its
-- invitations with it, so there is nothing to do then.
--
-- When GoTrue deletes the auth user, this trigger (queued by the CASCADE of
-- the membership) fires only after the ON DELETE SET NULL of
-- portfolio_invitations.invited_by, so the inviter's invitations no longer
-- name them. Pending invitations without an inviter are therefore revoked
-- too: accept_invitation refuses them anyway (F4).
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
    and (i.invited_by = old.user_id or i.invited_by is null)
    and i.accepted_at is null
    and i.revoked_at is null;
  return null;
end
$$;

comment on function private.after_owner_membership_ends() is
  'Revokes the pending invitations of an owner whose ownership ended, and those whose inviter was deleted (invited_by NULL).';

revoke all on function private.after_owner_membership_ends() from public, anon, authenticated;

-- Pending invitations accept_invitation would refuse (no inviter, or an
-- inviter who is no longer an owner of the portfolio: left behind by direct
-- deletions in Auth, F4) are revoked now, so the owners' list matches.
-- Checked on a database migrated up to the previous migration by
-- tool/db/upgrade_test.sh (tool/db/upgrade/20261108082804.*.sql, run by
-- `make test-db`); on the hosted project, after the push,
-- docs/operations.md ("Deleting a user account") gives the count query that
-- must answer 0.
update public.portfolio_invitations i
set revoked_at = now()
where i.accepted_at is null
  and i.revoked_at is null
  and (
    i.invited_by is null
    or not exists (
      select 1
      from public.portfolio_members m
      where m.portfolio_id = i.portfolio_id
        and m.user_id = i.invited_by
        and m.role = 'owner'
    )
  );
