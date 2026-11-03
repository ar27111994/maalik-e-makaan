-- ============================================================================
-- Identity & portfolios
--
-- A portfolio is a landlord's workspace (one family's properties, a plaza, an
-- overseas owner's estate). Users join portfolios with a role:
--
--   owner       full control, including team management and deletion
--   manager     the caretaker/munshi who runs day-to-day operations
--   accountant  records money (payments, expenses) and reads everything
--   viewer      read-only (co-owner abroad, family member)
--
-- Authorisation helpers are SECURITY DEFINER functions in the non-exposed
-- `app` schema so RLS policies can call them without recursive policy
-- evaluation, wrapped as `(select …)` so Postgres evaluates them once per
-- statement (initPlan) instead of once per row.
-- ============================================================================

create type public.member_role as enum ('owner', 'manager', 'accountant', 'viewer');

comment on type public.member_role is
  'owner: full control; manager: day-to-day operations (caretaker); accountant: money + read; viewer: read-only.';

-- Removes characters rejected by app.is_clean_text, collapses whitespace and
-- trims. Used where data arrives from outside our forms (auth metadata).
create or replace function app.clean_text(p_value text, p_max_length integer default null)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when p_value is null then null
    else left(
      btrim(regexp_replace(
        regexp_replace(p_value, '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]', '', 'g'),
        '\s+', ' ', 'g'
      )),
      coalesce(p_max_length, 2147483647)
    )
  end
$$;

grant execute on function app.clean_text(text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text not null default ''
    constraint profiles_full_name_check
      check (char_length(full_name) <= 120 and app.is_clean_text(full_name)),
  phone text
    constraint profiles_phone_check check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  locale text not null default 'en'
    constraint profiles_locale_check check (locale in ('en', 'ur')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Public profile of an auth user (name, contact, UI language).';

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function private.touch_updated_at();

-- Keeps profiles in step with auth.users. Metadata is user-controlled, so it
-- is cleaned before it can reach constrained columns.
create or replace function private.handle_auth_user_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  if tg_op = 'INSERT' then
    v_name := app.clean_text(new.raw_user_meta_data ->> 'full_name', 120);
    -- Strip bidi/invisible characters that clean_text keeps (it only drops controls).
    if not app.is_clean_text(v_name) then
      v_name := '';
    end if;
    insert into public.profiles (id, email, full_name, locale)
    values (
      new.id,
      lower(new.email),
      coalesce(v_name, ''),
      case when new.raw_user_meta_data ->> 'locale' = 'ur' then 'ur' else 'en' end
    )
    on conflict (id) do nothing;
  elsif new.email is distinct from old.email then
    update public.profiles set email = lower(new.email) where id = new.id;
  end if;
  return new;
end
$$;

create trigger on_auth_user_change
  after insert or update of email on auth.users
  for each row execute function private.handle_auth_user_change();

-- ---------------------------------------------------------------------------
-- Portfolios
-- ---------------------------------------------------------------------------

create table public.portfolios (
  id uuid primary key default app.uuid_generate_v7(),
  name text not null
    constraint portfolios_name_check
      check (char_length(btrim(name)) between 1 and 80 and app.is_clean_text(name)),
  default_due_day smallint not null default 5
    constraint portfolios_default_due_day_check check (default_due_day between 1 and 28),
  default_grace_days smallint not null default 5
    constraint portfolios_default_grace_days_check check (default_grace_days between 0 and 60),
  default_increment_percent numeric(5, 2) not null default 10
    constraint portfolios_default_increment_check
      check (default_increment_percent between 0 and 100),
  receipt_prefix text not null default 'MM'
    constraint portfolios_receipt_prefix_check check (receipt_prefix ~ '^[A-Z0-9]{1,6}$'),
  landlord_name text
    constraint portfolios_landlord_name_check
      check (char_length(landlord_name) <= 120 and app.is_clean_text(landlord_name)),
  landlord_phone text
    constraint portfolios_landlord_phone_check check (landlord_phone ~ '^\+[1-9][0-9]{7,14}$'),
  raast_id text
    constraint portfolios_raast_id_check check (raast_id ~ '^\+923[0-9]{9}$'),
  bank_account_title text
    constraint portfolios_bank_account_title_check
      check (char_length(bank_account_title) <= 120 and app.is_clean_text(bank_account_title)),
  bank_iban text
    constraint portfolios_bank_iban_check
      check (bank_iban ~ '^PK[0-9]{2}[A-Z]{4}[A-Z0-9]{16}$' and app.is_valid_iban(bank_iban)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

comment on table public.portfolios is
  'A landlord workspace. Receipt/payment details are printed on receipts and reminders.';
comment on column public.portfolios.raast_id is 'Raast ID (the registered mobile number) shown to tenants.';

create index portfolios_created_by_idx on public.portfolios (created_by);

create trigger portfolios_touch_updated_at
  before update on public.portfolios
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Memberships
-- ---------------------------------------------------------------------------

create table public.portfolio_members (
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.member_role not null,
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (portfolio_id, user_id)
);

comment on table public.portfolio_members is 'Who can access a portfolio, and with which role.';

create index portfolio_members_user_id_idx on public.portfolio_members (user_id);
create index portfolio_members_invited_by_idx on public.portfolio_members (invited_by);

create trigger portfolio_members_touch_updated_at
  before update on public.portfolio_members
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Authorisation helpers (used by every portfolio-scoped policy)
-- ---------------------------------------------------------------------------

-- Ids of the caller's portfolios, optionally restricted to some roles.
create or replace function app.my_portfolio_ids(p_roles public.member_role[] default null)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(m.portfolio_id), '{}'::uuid[])
  from public.portfolio_members m
  where m.user_id = (select auth.uid())
    and (p_roles is null or m.role = any (p_roles))
$$;

-- Whether the caller holds one of p_roles (any role when null) in a portfolio.
create or replace function app.has_portfolio_role(
  p_portfolio_id uuid,
  p_roles public.member_role[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.portfolio_members m
    where m.portfolio_id = p_portfolio_id
      and m.user_id = (select auth.uid())
      and (p_roles is null or m.role = any (p_roles))
  )
$$;

-- Users who share at least one portfolio with the caller (for profile reads).
create or replace function app.my_teammate_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct other.user_id), '{}'::uuid[])
  from public.portfolio_members mine
  join public.portfolio_members other on other.portfolio_id = mine.portfolio_id
  where mine.user_id = (select auth.uid())
$$;

-- Raises 42501 unless the caller holds one of p_roles in p_portfolio_id.
create or replace function app.require_portfolio_role(
  p_portfolio_id uuid,
  p_roles public.member_role[] default null
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not app.has_portfolio_role(p_portfolio_id, p_roles) then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;
end
$$;

grant execute on function app.my_portfolio_ids(public.member_role[]) to authenticated, service_role;
grant execute on function app.has_portfolio_role(uuid, public.member_role[]) to authenticated, service_role;
grant execute on function app.my_teammate_ids() to authenticated, service_role;
grant execute on function app.require_portfolio_role(uuid, public.member_role[]) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Invitations (split-token: selector = invitation id, verifier = 32 random
-- bytes of which only the SHA-256 is stored and compared in constant time)
-- ---------------------------------------------------------------------------

create table public.portfolio_invitations (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  email text not null
    constraint portfolio_invitations_email_check
      check (
        email = lower(btrim(email))
        and char_length(email) <= 254
        and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,63}$'
      ),
  role public.member_role not null,
  verifier_hash bytea not null
    constraint portfolio_invitations_verifier_hash_check check (length(verifier_hash) = 32),
  invited_by uuid references auth.users (id) on delete set null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint portfolio_invitations_terminal_state_check
    check (accepted_at is null or revoked_at is null)
);

comment on table public.portfolio_invitations is
  'E-mail-bound, single-use, expiring invitations. Only the SHA-256 of the secret is stored.';

create unique index portfolio_invitations_pending_email_key
  on public.portfolio_invitations (portfolio_id, email)
  where accepted_at is null and revoked_at is null;
create index portfolio_invitations_portfolio_id_idx on public.portfolio_invitations (portfolio_id);
create index portfolio_invitations_invited_by_idx on public.portfolio_invitations (invited_by);
create index portfolio_invitations_accepted_by_idx on public.portfolio_invitations (accepted_by);

create or replace function private.base64url_encode(p_bytes bytea)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select rtrim(translate(encode(p_bytes, 'base64'), E'+/\n', '-_'), '=')
$$;

create or replace function private.base64url_decode(p_text text)
returns bytea
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_b64 text := translate(p_text, '-_', '+/');
begin
  if p_text !~ '^[A-Za-z0-9_-]+$' then
    return null;
  end if;
  v_b64 := v_b64 || repeat('=', (4 - length(v_b64) % 4) % 4);
  return decode(v_b64, 'base64');
exception
  when others then
    return null;
end
$$;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Creates a portfolio with the caller as owner. Idempotent for a
-- client-supplied id. At most 20 owned portfolios per user.
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

  if p_id is not null then
    select p.* into v_portfolio from public.portfolios p where p.id = p_id;
    if found then
      if v_portfolio.created_by is distinct from v_uid then
        perform app.forbid();
      end if;
      return v_portfolio;
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

-- Deletes a portfolio and everything in it. The caller must be an owner and
-- must type the portfolio name to confirm (case-insensitive).
create or replace function public.delete_portfolio(p_portfolio_id uuid, p_confirmation text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  perform app.require_portfolio_role(p_portfolio_id, array['owner']::public.member_role[]);
  select p.name into v_name from public.portfolios p where p.id = p_portfolio_id for update;
  if lower(btrim(coalesce(p_confirmation, ''))) <> lower(btrim(v_name)) then
    perform app.fail('confirmation_mismatch');
  end if;
  delete from public.portfolios where id = p_portfolio_id;
end
$$;

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
  perform app.require_portfolio_role(p_portfolio_id, array['owner']::public.member_role[]);

  -- Serialise membership changes per portfolio to keep the owner invariant.
  perform 1 from public.portfolios where id = p_portfolio_id for update;

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
  if p_user_id = v_uid then
    perform app.require_portfolio_role(p_portfolio_id);
  else
    perform app.require_portfolio_role(p_portfolio_id, array['owner']::public.member_role[]);
  end if;

  perform 1 from public.portfolios where id = p_portfolio_id for update;

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
  perform app.require_portfolio_role(p_portfolio_id, array['owner']::public.member_role[]);
  perform private.enforce_rate_limit('create_invitation', 20, interval '1 hour');

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
  perform app.require_portfolio_role(v_portfolio_id, array['owner']::public.member_role[]);

  update public.portfolio_invitations
  set revoked_at = now()
  where id = p_invitation_id and accepted_at is null and revoked_at is null;
end
$$;

-- Accepts an invitation for the signed-in, e-mail-verified user whose e-mail
-- matches the invitation. Failures are returned as a status (not raised) so
-- the attempt is committed and counts towards the rate limit.
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
  v_selector := split_part(p_token, '.', 1)::uuid;
  v_verifier := private.base64url_decode(split_part(p_token, '.', 2));
  if v_verifier is null or length(v_verifier) <> 32 then
    return jsonb_build_object('status', 'invalid');
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
-- Row Level Security & grants
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.portfolios enable row level security;
alter table public.portfolio_members enable row level security;
alter table public.portfolio_invitations enable row level security;

create policy profiles_select_self_and_teammates on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or id = any ((select app.my_teammate_ids())::uuid[]));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy portfolios_select_members on public.portfolios
  for select to authenticated
  using (id = any ((select app.my_portfolio_ids())::uuid[]));

create policy portfolios_update_owners on public.portfolios
  for update to authenticated
  using (id = any ((select app.my_portfolio_ids(array['owner']::public.member_role[]))::uuid[]))
  with check (id = any ((select app.my_portfolio_ids(array['owner']::public.member_role[]))::uuid[]));

create policy portfolio_members_select_members on public.portfolio_members
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));

create policy portfolio_invitations_select_owners on public.portfolio_invitations
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids(array['owner']::public.member_role[]))::uuid[]));

grant select on public.profiles to authenticated;
grant update (full_name, phone, locale) on public.profiles to authenticated;

grant select on public.portfolios to authenticated;
grant update (
  name, default_due_day, default_grace_days, default_increment_percent, receipt_prefix,
  landlord_name, landlord_phone, raast_id, bank_account_title, bank_iban, archived_at
) on public.portfolios to authenticated;

grant select on public.portfolio_members to authenticated;

-- verifier_hash is deliberately not readable by clients.
grant select (
  id, portfolio_id, email, role, invited_by, expires_at, accepted_at, accepted_by,
  revoked_at, created_at
) on public.portfolio_invitations to authenticated;

grant select, insert, update, delete on
  public.profiles, public.portfolios, public.portfolio_members, public.portfolio_invitations
  to service_role;

grant execute on function public.create_portfolio(text, uuid) to authenticated;
grant execute on function public.delete_portfolio(uuid, text) to authenticated;
grant execute on function public.update_member_role(uuid, uuid, public.member_role) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
grant execute on function public.create_invitation(uuid, text, public.member_role) to authenticated;
grant execute on function public.revoke_invitation(uuid) to authenticated;
grant execute on function public.accept_invitation(text) to authenticated;
