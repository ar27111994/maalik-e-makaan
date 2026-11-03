-- ============================================================================
-- Scheduled jobs, Data API write limits and account-deletion support.
--
-- Daily job (00:05 Pakistan time): refresh current rents, generate rent dues,
-- assess late fees, create notifications and clean up. Every step is
-- idempotent, and the app also calls sync_portfolio_billing, so a missed
-- run (e.g. a paused free-tier project) self-heals.
-- ============================================================================

-- Keeps leases.monthly_rent equal to the rent in force this month.
create or replace function private.refresh_current_rents(p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  update public.leases l
  set monthly_rent = x.rent
  from (
    select distinct on (rc.lease_id) rc.lease_id, rc.monthly_rent as rent
    from public.rent_changes rc
    where rc.effective_from <= date_trunc('month', coalesce(p_as_of, app.today_pkt()))::date
    order by rc.lease_id, rc.effective_from desc
  ) x
  where x.lease_id = l.id and l.status = 'active' and l.monthly_rent is distinct from x.rent;
  get diagnostics v_rows = row_count;
  return v_rows;
end
$$;

create or replace function private.sync_all_billing(p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_total integer := 0;
begin
  for v_lease_id in select l.id from public.leases l where l.status = 'active' order by l.id loop
    v_total := v_total + private.sync_lease_billing(v_lease_id, coalesce(p_as_of, app.today_pkt()));
  end loop;
  return v_total;
end
$$;

-- One automatic late fee per overdue rent due once the grace period has
-- passed. Daily fees grow each day (up to their cap) until the rent or the
-- fee is paid, waived or voided; voided fees are never recreated.
-- Formulas mirror mm_core's LateFeePolicy (rounded half-up to rupees).
create or replace function private.assess_late_fees(p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_rows integer;
begin
  insert into public.charges (
    portfolio_id, lease_id, kind, period_month, due_date, amount, source, related_charge_id, description
  )
  select
    c.portfolio_id, c.lease_id, 'late_fee', c.period_month, v_as_of, f.fee, 'auto_late_fee', c.id,
    'Late fee'
  from public.charges c
  join public.leases l on l.id = c.lease_id
  cross join lateral (
    select app.late_fee_amount(
      l.late_fee_type, l.late_fee_value, l.late_fee_cap, c.outstanding,
      v_as_of - c.due_date, l.grace_days
    ) as fee
  ) f
  where c.kind = 'rent'
    and c.voided_at is null
    and c.outstanding > 0
    and l.status = 'active'
    and l.late_fee_type <> 'none'
    and v_as_of - c.due_date > l.grace_days
    and f.fee > 0
  on conflict (related_charge_id) where kind = 'late_fee' and related_charge_id is not null
  do update set amount = excluded.amount
    where public.charges.voided_at is null
      and public.charges.paid_amount = 0
      and public.charges.waived_amount = 0
      and excluded.amount > public.charges.amount;
  get diagnostics v_rows = row_count;
  return v_rows;
end
$$;

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
end
$$;

create or replace function private.run_daily_jobs(p_as_of date default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_result jsonb;
begin
  -- Never run two instances concurrently.
  if not pg_try_advisory_xact_lock(hashtext('maalik_e_makaan.run_daily_jobs')) then
    return jsonb_build_object('skipped', true);
  end if;
  perform private.refresh_current_rents(v_as_of);
  v_result := jsonb_build_object(
    'as_of', v_as_of,
    'charges_created', private.sync_all_billing(v_as_of),
    'late_fees', private.assess_late_fees(v_as_of),
    'notifications', private.generate_notifications(v_as_of)
  );
  perform private.cleanup(now());
  return v_result;
end
$$;

-- ---------------------------------------------------------------------------
-- Data API write limiter (PostgREST pre-request hook)
--
-- Runs before every Data API request. Mutating requests (POST/PATCH/PUT/
-- DELETE, which includes RPC calls) are limited to 120/min per user and
-- 300/min per client IP. GET/HEAD requests and read-only transactions cannot
-- write counters and are skipped; the service role is exempt.
-- ---------------------------------------------------------------------------

create or replace function app.check_request()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_method text := current_setting('request.method', true);
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_headers jsonb := nullif(current_setting('request.headers', true), '')::jsonb;
  v_sub text;
  v_ip text;
begin
  if v_method is null
     or v_method in ('GET', 'HEAD', 'OPTIONS')
     or coalesce(v_claims ->> 'role', '') = 'service_role'
     or current_setting('transaction_read_only', true) = 'on' then
    return;
  end if;

  v_sub := v_claims ->> 'sub';
  v_ip := nullif(btrim(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)), '');

  if v_sub is not null and not private.hit_rate_limit('api_write:user:' || v_sub, 120, interval '1 minute') then
    perform private.raise_rate_limited(60, 'api_write');
  end if;
  if v_ip is not null and not private.hit_rate_limit('api_write:ip:' || left(v_ip, 64), 300, interval '1 minute') then
    perform private.raise_rate_limited(60, 'api_write');
  end if;
end
$$;

grant execute on function app.check_request() to anon, authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'app.check_request';
notify pgrst, 'reload config';

-- ---------------------------------------------------------------------------
-- Account deletion (called by the delete-account Edge Function with the
-- secret key; never callable by end users)
-- ---------------------------------------------------------------------------

-- Portfolios that will be deleted with the account: those where the user is
-- the only owner.
create or replace function public.admin_account_deletion_scope(p_user_id uuid)
returns table (portfolio_id uuid, portfolio_name text, other_members integer)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name,
         (select count(*)::integer from public.portfolio_members o
          where o.portfolio_id = p.id and o.user_id <> p_user_id)
  from public.portfolios p
  join public.portfolio_members m on m.portfolio_id = p.id and m.user_id = p_user_id and m.role = 'owner'
  where not exists (
    select 1 from public.portfolio_members o
    where o.portfolio_id = p.id and o.role = 'owner' and o.user_id <> p_user_id
  )
$$;

-- Deletes the user's sole-owned portfolios (cascading to all their data) and
-- removes the user from every other portfolio. Returns the deleted ids.
create or replace function public.admin_delete_account_data(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_deleted uuid[];
begin
  select coalesce(array_agg(s.portfolio_id), '{}'::uuid[]) into v_deleted
  from public.admin_account_deletion_scope(p_user_id) s;

  delete from public.portfolios where id = any (v_deleted);
  delete from public.portfolio_members where user_id = p_user_id;
  delete from public.notifications where user_id = p_user_id;

  return jsonb_build_object('deleted_portfolio_ids', to_jsonb(v_deleted));
end
$$;

revoke all on function public.admin_account_deletion_scope(uuid) from public, anon, authenticated;
revoke all on function public.admin_delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.admin_account_deletion_scope(uuid) to service_role;
grant execute on function public.admin_delete_account_data(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Scheduling (pg_cron). Only where pg_cron runs in this database (hosted
-- projects and `supabase start`); plain test databases skip it.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_catalog.pg_available_extensions where name = 'pg_cron')
     and current_database() = coalesce(current_setting('cron.database_name', true), 'postgres') then
    create extension if not exists pg_cron with schema pg_catalog;
    grant usage on schema cron to postgres;
    grant all privileges on all tables in schema cron to postgres;

    perform cron.schedule('mm-daily-jobs', '5 19 * * *', 'select private.run_daily_jobs()');
    perform cron.schedule(
      'mm-rate-limit-cleanup', '17 * * * *',
      $cmd$delete from private.rate_limit_buckets where window_start < now() - interval '2 hours'$cmd$
    );
  else
    raise notice 'pg_cron is not available in database %; scheduling skipped', current_database();
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Final hardening sweep: no function in our schemas is executable through
-- PUBLIC. Every intended caller holds an explicit grant made above.
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public, app, private from public;
