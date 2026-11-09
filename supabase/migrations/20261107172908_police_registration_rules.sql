-- ============================================================================
-- Police tenant-registration deadlines by jurisdiction.
--
-- app.police_registration_deadline_days(province) gave Punjab 15 days, Sindh
-- 2 and every other jurisdiction 1 (an app default), always counted from the
-- lease start (possession). The law differs in two ways
-- (.planning/research/website-facts.md §1, reviewed 2026-11-05):
--
--   Jurisdiction        Deadline   Clock starts at          Source
--   Punjab              15 days    delivery of possession   Punjab Information of Temporary
--                                                           Residents Act 2015, s.3(1)
--   Sindh               48 hours   delivery of possession   Sindh Act XXI of 2015, s.3(1)
--   Khyber Pakhtunkhwa  7 days*    signing of the agreement KP Act XIV of 2014, s.4(1)
--   Balochistan         3 days**   signing of the agreement Balochistan Restrictions of Rented
--                                                           Buildings (Security) Act 2015
--   Islamabad (ICT)     none       -                        no statute; ICT Police say registration
--                                                           is mandatory (s.144 CrPC orders)
--   Gilgit-Baltistan,   unknown    -                        not researched
--   Azad Kashmir
--
--   *  "within seven days excluding public holidays of signing of the
--      agreement". Counted here as 7 calendar days: excluding holidays only
--      moves the legal deadline later, so the app's date is never later than
--      the law's. Seen in a private copy of the Act only (research §8.5).
--   ** The Act excerpt says three days; a LUMS analysis says fifteen days for
--      both the Balochistan and KP Acts (research §8.6). Where sources
--      conflict the stricter (earlier) value is used.
--
-- Sindh's 48 hours are 2 days: the hour of possession is not recorded, so the
-- deadline is the date on which the 48 hours end.
--
-- Where no statute fixes a deadline (ICT, Gilgit-Baltistan, Azad Kashmir)
-- the app keeps its conservative 1-day reminder from possession, flagged
-- statutory = false so the UI labels it as a reminder, not the law.
--
-- One rule now decides every deadline:
--   app.police_registration_rule(province)  days, clock, statutory
--   app.police_registration_clock_start(province, start, agreement_signed_on)
--   app.police_registration_deadline(province, start, agreement_signed_on)
-- For an agreement clock the agreement date is used when recorded, otherwise
-- the lease start (the agreement is usually signed on or before possession).
-- private.generate_notifications and public.get_dashboard use them and add
-- 'statutory', 'clock' and 'clock_starts_on' to their output; every existing
-- key keeps its name and meaning. The old days-only function has no other
-- caller and is dropped.
-- ============================================================================

-- A migration waits at most 5 s for a lock instead of queueing the app's
-- traffic behind it; `set local` keeps both settings inside this migration's
-- transaction.
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- 1. The rule
-- ---------------------------------------------------------------------------

-- The police-registration rule of a jurisdiction: the deadline in days, what
-- starts the clock ('possession' = the lease start, 'agreement' = the
-- agreement's signing) and whether a statute fixes it. See the header for
-- sources. Keep the table in the header and docs in step with this.
create or replace function app.police_registration_rule(
  p_province public.province,
  out deadline_days integer,
  out clock text,
  out statutory boolean
)
language sql
immutable
parallel safe
set search_path = ''
as $$
  select r.deadline_days, r.clock, r.statutory
  from (values
    ('punjab'::public.province, 15, 'possession', true),
    ('sindh'::public.province, 2, 'possession', true),
    ('khyber_pakhtunkhwa'::public.province, 7, 'agreement', true),
    ('balochistan'::public.province, 3, 'agreement', true)
  ) as r (province, deadline_days, clock, statutory)
  where r.province = p_province
  union all
  -- No statutory deadline (Islamabad) or not researched (Gilgit-Baltistan,
  -- Azad Kashmir): the app's own conservative reminder.
  select 1, 'possession', false
  where p_province not in ('punjab', 'sindh', 'khyber_pakhtunkhwa', 'balochistan')
$$;

comment on function app.police_registration_rule(public.province) is
  'Police tenant-registration rule of a jurisdiction: deadline_days, clock (possession | agreement) '
  'and statutory (false = an app reminder where no statute fixes a deadline). Sources: '
  '.planning/research/website-facts.md §1.';

-- The date the registration clock starts: the agreement date for an
-- agreement clock when it is recorded, otherwise the lease start (possession).
create or replace function app.police_registration_clock_start(
  p_province public.province,
  p_start_date date,
  p_agreement_signed_on date
)
returns date
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when (select r.clock from app.police_registration_rule(p_province) r) = 'agreement'
    then coalesce(p_agreement_signed_on, p_start_date)
    else p_start_date
  end
$$;

comment on function app.police_registration_clock_start(public.province, date, date) is
  'Date the police-registration clock starts: agreement_signed_on (falling back to start_date) where the '
  'law counts from the agreement, start_date (possession) otherwise.';

-- The last day for police registration of a tenancy.
create or replace function app.police_registration_deadline(
  p_province public.province,
  p_start_date date,
  p_agreement_signed_on date
)
returns date
language sql
immutable
parallel safe
set search_path = ''
as $$
  select app.police_registration_clock_start(p_province, p_start_date, p_agreement_signed_on)
         + (select r.deadline_days from app.police_registration_rule(p_province) r)
$$;

comment on function app.police_registration_deadline(public.province, date, date) is
  'Last day for police tenant registration: the clock start plus the jurisdiction''s deadline_days.';

revoke all on function app.police_registration_rule(public.province) from public, anon;
revoke all on function app.police_registration_clock_start(public.province, date, date) from public, anon;
revoke all on function app.police_registration_deadline(public.province, date, date) from public, anon;
grant execute on function app.police_registration_rule(public.province) to authenticated, service_role;
grant execute on function app.police_registration_clock_start(public.province, date, date)
  to authenticated, service_role;
grant execute on function app.police_registration_deadline(public.province, date, date)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Notifications (base: 20261103194402_notifications_audit.sql; only the
--    police block changes)
-- ---------------------------------------------------------------------------

-- Creates every due notification for p_as_of. Recipients: owners & managers.
create or replace function private.generate_notifications(p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_rows integer;
  v_total integer := 0;
begin
  -- Rent due within 3 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select c.portfolio_id, m.user_id, 'rent_due_soon',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'property_name', p.name, 'amount', c.outstanding, 'due_date', c.due_date
         ),
         'charge', c.id, 'rent_due_soon:' || c.id
  from public.charges c
  join public.leases l on l.id = c.lease_id and l.status = 'active'
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  join public.portfolio_members m on m.portfolio_id = c.portfolio_id and m.role in ('owner', 'manager')
  where c.kind = 'rent' and c.voided_at is null and c.outstanding > 0
    and c.due_date between v_as_of and v_as_of + 3
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Rent overdue past the grace period (recent dues only, to avoid flooding
  -- a landlord who onboards months of history), and again at 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select c.portfolio_id, m.user_id, 'rent_overdue',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'property_name', p.name, 'amount', c.outstanding, 'due_date', c.due_date,
           'days_overdue', v_as_of - c.due_date
         ),
         'charge', c.id,
         case when v_as_of - c.due_date >= 30 then 'rent_overdue_30:' else 'rent_overdue:' end || c.id
  from public.charges c
  join public.leases l on l.id = c.lease_id and l.status = 'active'
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  join public.portfolio_members m on m.portfolio_id = c.portfolio_id and m.role in ('owner', 'manager')
  where c.kind = 'rent' and c.voided_at is null and c.outstanding > 0
    and v_as_of > c.due_date + l.grace_days
    and c.due_date >= v_as_of - 45
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Agreements ending within 90 and within 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id, 'lease_expiring',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'end_date', l.end_date, 'days_left', l.end_date - v_as_of
         ),
         'lease', l.id,
         'lease_expiring_' || horizon.days || ':' || l.id || ':' || l.end_date
  from public.leases l
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  cross join (values (90), (30)) as horizon (days)
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active' and l.end_date between v_as_of and v_as_of + horizon.days
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Increment due within 30 days and not yet applied for that anniversary.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id, 'increment_due',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'anniversary', a.anniversary, 'current_rent', l.monthly_rent,
           'increment_percent', l.increment_percent
         ),
         'lease', l.id, 'increment_due:' || l.id || ':' || a.anniversary
  from public.leases l
  cross join lateral (
    select app.next_anniversary(l.start_date, v_as_of, l.increment_interval_months) as anniversary
  ) a
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active'
    and l.increment_percent > 0
    and a.anniversary <= v_as_of + 30
    and not exists (
      select 1 from public.rent_changes rc
      where rc.lease_id = l.id
        and rc.reason <> 'initial'
        and rc.effective_from >= date_trunc('month', a.anniversary)::date
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Police registration: a nudge once the tenancy starts or the registration
  -- clock starts (an agreement signed before possession, in KP and
  -- Balochistan), and once overdue. 'statutory' = false marks the app's own
  -- reminder where no statute fixes a deadline; 'clock' says what starts it.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id,
         case when overdue then 'police_registration_overdue'::public.notification_kind
              else 'police_registration_pending'::public.notification_kind end,
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'province', p.province, 'deadline', d.deadline,
           'deadline_days', r.deadline_days, 'statutory', r.statutory,
           'clock', r.clock, 'clock_starts_on', d.clock_starts_on
         ),
         'lease', l.id,
         case when overdue then 'police_overdue:' else 'police_pending:' end || l.id
  from public.leases l
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  cross join lateral app.police_registration_rule(p.province) r
  cross join lateral (
    select app.police_registration_clock_start(p.province, l.start_date, l.agreement_signed_on) as clock_starts_on,
           app.police_registration_deadline(p.province, l.start_date, l.agreement_signed_on) as deadline
  ) d
  cross join lateral (select v_as_of > d.deadline as overdue) o
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active' and l.police_status = 'pending'
    and v_as_of >= least(l.start_date, d.clock_starts_on)
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Tenant CNIC expiring within 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select distinct on (m.user_id, t.id)
         t.portfolio_id, m.user_id, 'cnic_expiring',
         jsonb_build_object('tenant_id', t.id, 'tenant_name', t.full_name, 'cnic_expiry', t.cnic_expiry),
         'tenant', t.id, 'cnic_expiring:' || t.id || ':' || t.cnic_expiry
  from public.tenants t
  join public.leases l on l.tenant_id = t.id and l.status = 'active'
  join public.portfolio_members m on m.portfolio_id = t.portfolio_id and m.role in ('owner', 'manager')
  where t.cnic_expiry between v_as_of and v_as_of + 30
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Unpaid utility bills due within 2 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select b.portfolio_id, m.user_id, 'utility_bill_due',
         jsonb_build_object(
           'bill_id', b.id, 'utility_type', a.type, 'property_name', p.name,
           'amount', b.amount, 'due_date', b.due_date, 'in_landlord_name', a.in_landlord_name
         ),
         'utility_bill', b.id, 'utility_due:' || b.id
  from public.utility_bills b
  join public.utility_accounts a on a.id = b.utility_account_id
  join public.properties p on p.id = a.property_id
  join public.portfolio_members m on m.portfolio_id = b.portfolio_id and m.role in ('owner', 'manager')
  where b.status = 'unpaid' and b.due_date between v_as_of and v_as_of + 2
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  return v_total;
end
$$;


-- ---------------------------------------------------------------------------
-- 3. Dashboard compliance (base: 20261103194625_reports.sql; only the police
--    CTE changes: the deadline follows the rule, and each item adds
--    deadline_days, statutory, clock and clock_starts_on)
-- ---------------------------------------------------------------------------

create or replace function public.get_dashboard(p_portfolio_id uuid, p_as_of date default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_month date := date_trunc('month', coalesce(p_as_of, app.today_pkt()))::date;
  v_next_month date;
  v_result jsonb;
begin
  perform app.require_portfolio_role(p_portfolio_id);
  v_next_month := (v_month + interval '1 month')::date;

  with
  open_charges as (
    select c.lease_id, c.kind, c.due_date, c.outstanding
    from public.charges c
    where c.portfolio_id = p_portfolio_id and c.voided_at is null and c.outstanding > 0
  ),
  month_dues as (
    select
      coalesce(sum(c.amount - c.waived_amount), 0) as expected,
      coalesce(sum(c.paid_amount), 0) as paid
    from public.charges c
    where c.portfolio_id = p_portfolio_id
      and c.voided_at is null
      and c.kind <> 'security_deposit'
      and c.due_date >= v_month and c.due_date < v_next_month
  ),
  month_cash as (
    select
      coalesce(sum(p.amount), 0) as received,
      coalesce(sum(p.tax_withheld), 0) as tax_withheld,
      coalesce(
        (select jsonb_object_agg(x.method, x.total)
         from (
           select p2.method, sum(p2.amount) as total
           from public.payments p2
           where p2.portfolio_id = p_portfolio_id and p2.voided_at is null
             and p2.method <> 'deposit_adjustment'
             and p2.paid_on >= v_month and p2.paid_on < v_next_month
           group by p2.method
         ) x),
        '{}'::jsonb
      ) as by_method
    from public.payments p
    where p.portfolio_id = p_portfolio_id and p.voided_at is null
      and p.method <> 'deposit_adjustment'
      and p.paid_on >= v_month and p.paid_on < v_next_month
  ),
  aging as (
    select
      coalesce(sum(outstanding), 0) as total,
      coalesce(sum(outstanding) filter (where due_date < v_as_of), 0) as overdue,
      coalesce(sum(outstanding) filter (where due_date >= v_as_of), 0) as not_due,
      coalesce(sum(outstanding) filter (where v_as_of - due_date between 1 and 30), 0) as d1_30,
      coalesce(sum(outstanding) filter (where v_as_of - due_date between 31 and 60), 0) as d31_60,
      coalesce(sum(outstanding) filter (where v_as_of - due_date between 61 and 90), 0) as d61_90,
      coalesce(sum(outstanding) filter (where v_as_of - due_date > 90), 0) as d90_plus
    from open_charges
  ),
  units_status as (
    select u.id, u.label, u.asking_rent, u.is_available, u.property_id,
      exists (
        select 1 from public.leases l
        where l.unit_id = u.id and l.status = 'active' and l.start_date <= v_as_of
      ) as occupied,
      coalesce(
        (select max(pl.moved_out_on) from public.leases pl where pl.unit_id = u.id and pl.status = 'ended'),
        u.created_at::date
      ) as vacant_since
    from public.units u
    where u.portfolio_id = p_portfolio_id and u.archived_at is null
  ),
  occupancy as (
    select
      count(*) as units,
      count(*) filter (where occupied) as occupied,
      count(*) filter (where not occupied and is_available) as vacant,
      count(*) filter (where not occupied and not is_available) as unavailable,
      coalesce(sum(asking_rent) filter (where not occupied and is_available), 0) as vacant_asking_rent
    from units_status
  ),
  vacant_units as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'unit_id', us.id, 'unit_label', us.label, 'property_id', us.property_id,
      'property_name', p.name, 'asking_rent', us.asking_rent, 'vacant_since', us.vacant_since,
      'vacant_days', greatest(v_as_of - us.vacant_since, 0)
    ) order by us.vacant_since), '[]'::jsonb) as items
    from units_status us
    join public.properties p on p.id = us.property_id
    where not us.occupied and us.is_available
  ),
  arrears as (
    select
      oc.lease_id,
      sum(oc.outstanding) as outstanding,
      sum(oc.outstanding) filter (where oc.due_date < v_as_of) as overdue,
      min(oc.due_date) filter (where oc.due_date < v_as_of) as oldest_overdue
    from open_charges oc
    group by oc.lease_id
  ),
  top_arrears as (
    select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.overdue desc, t.days_overdue desc), '[]'::jsonb) as items
    from (
      select
        l.id as lease_id, tn.id as tenant_id, tn.full_name as tenant_name, tn.phone as tenant_phone,
        u.label as unit_label, p.name as property_name, l.monthly_rent,
        a.outstanding, a.overdue, a.oldest_overdue as oldest_overdue_due_date,
        v_as_of - a.oldest_overdue as days_overdue,
        (select max(py.paid_on) from public.payments py
          where py.lease_id = l.id and py.voided_at is null and py.method <> 'deposit_adjustment') as last_paid_on,
        (select max(rl.sent_at) from public.reminder_logs rl where rl.lease_id = l.id) as last_reminded_at
      from arrears a
      join public.leases l on l.id = a.lease_id
      join public.tenants tn on tn.id = l.tenant_id
      join public.units u on u.id = l.unit_id
      join public.properties p on p.id = u.property_id
      where a.overdue > 0
      order by a.overdue desc
      limit 10
    ) t
  ),
  active_leases as (
    select l.*, p.province, t.full_name as tenant_name, u.label as unit_label
    from public.leases l
    join public.units u on u.id = l.unit_id
    join public.properties p on p.id = u.property_id
    join public.tenants t on t.id = l.tenant_id
    where l.portfolio_id = p_portfolio_id and l.status = 'active'
  ),
  expiring as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'lease_id', al.id, 'tenant_name', al.tenant_name, 'unit_label', al.unit_label,
      'end_date', al.end_date, 'days_left', al.end_date - v_as_of
    ) order by al.end_date), '[]'::jsonb) as items
    from active_leases al
    where al.end_date between v_as_of and v_as_of + 90
  ),
  increments as (
    select
      al.id, al.tenant_name, al.unit_label, al.monthly_rent, al.increment_percent,
      app.next_anniversary(al.start_date, v_as_of, al.increment_interval_months) as next_anniversary,
      app.last_anniversary(al.start_date, v_as_of, al.increment_interval_months) as last_anniversary
    from active_leases al
    where al.increment_percent > 0
  ),
  increments_due as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'lease_id', i.id, 'tenant_name', i.tenant_name, 'unit_label', i.unit_label,
      'current_rent', i.monthly_rent, 'increment_percent', i.increment_percent,
      'anniversary', i.next_anniversary, 'status', 'upcoming'
    ) order by i.next_anniversary), '[]'::jsonb) as upcoming,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'lease_id', i2.id, 'tenant_name', i2.tenant_name, 'unit_label', i2.unit_label,
        'current_rent', i2.monthly_rent, 'increment_percent', i2.increment_percent,
        'anniversary', i2.last_anniversary, 'status', 'missed'
      ) order by i2.last_anniversary)
      from increments i2
      where i2.last_anniversary is not null
        and not exists (
          select 1 from public.rent_changes rc
          where rc.lease_id = i2.id and rc.reason <> 'initial'
            and rc.effective_from >= date_trunc('month', i2.last_anniversary)::date
        )
    ), '[]'::jsonb) as missed
    from increments i
    where i.next_anniversary <= v_as_of + 30
      and not exists (
        select 1 from public.rent_changes rc
        where rc.lease_id = i.id and rc.reason <> 'initial'
          and rc.effective_from >= date_trunc('month', i.next_anniversary)::date
      )
  ),
  police as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'lease_id', al.id, 'tenant_name', al.tenant_name, 'unit_label', al.unit_label,
      'province', al.province, 'start_date', al.start_date,
      'deadline', d.deadline,
      'overdue', v_as_of > d.deadline,
      'status', al.police_status,
      'deadline_days', r.deadline_days, 'statutory', r.statutory,
      'clock', r.clock, 'clock_starts_on', d.clock_starts_on
    ) order by al.start_date), '[]'::jsonb) as items
    from active_leases al
    cross join lateral app.police_registration_rule(al.province) r
    cross join lateral (
      select app.police_registration_clock_start(al.province, al.start_date, al.agreement_signed_on)
               as clock_starts_on,
             app.police_registration_deadline(al.province, al.start_date, al.agreement_signed_on) as deadline
    ) d
    where al.police_status in ('pending', 'submitted')
  ),
  cnic as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tenant_id', t.id, 'tenant_name', t.full_name, 'cnic_expiry', t.cnic_expiry,
      'expired', t.cnic_expiry < v_as_of
    ) order by t.cnic_expiry), '[]'::jsonb) as items
    from public.tenants t
    where t.portfolio_id = p_portfolio_id
      and t.archived_at is null
      and t.cnic_expiry <= v_as_of + 30
      and exists (select 1 from public.leases l where l.tenant_id = t.id and l.status = 'active')
  ),
  deposits as (
    select
      coalesce(sum(al.security_deposit), 0) as agreed,
      coalesce(sum((
        select coalesce(sum(a.amount), 0)
        from public.payment_allocations a
        join public.charges c on c.id = a.charge_id
        join public.payments p on p.id = a.payment_id
        where c.lease_id = al.id and c.kind = 'security_deposit' and p.voided_at is null
      ) - (
        select coalesce(sum(p.amount), 0)
        from public.payments p
        where p.lease_id = al.id and p.method = 'deposit_adjustment' and p.voided_at is null
      ) - (
        select coalesce(sum(r.amount), 0)
        from public.deposit_refunds r
        where r.lease_id = al.id and r.voided_at is null
      )), 0) as held
    from active_leases al
  ),
  utilities as (
    select
      coalesce(sum(b.amount) filter (where b.status = 'unpaid' and a.in_landlord_name), 0)
        as unpaid_landlord_name_total,
      count(*) filter (where b.status = 'unpaid' and a.in_landlord_name) as unpaid_landlord_name_count,
      count(*) filter (where b.status = 'unpaid' and b.due_date < v_as_of) as overdue_count
    from public.utility_bills b
    join public.utility_accounts a on a.id = b.utility_account_id
    where b.portfolio_id = p_portfolio_id
  ),
  high_usage as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'utility_account_id', x.account_id, 'property_name', x.property_name, 'unit_label', x.unit_label,
      'billing_month', x.billing_month, 'units_consumed', x.units_consumed,
      'crossed', x.units_consumed > 200
    ) order by x.units_consumed desc), '[]'::jsonb) as items
    from (
      select distinct on (a.id)
        a.id as account_id, p.name as property_name, u.label as unit_label,
        b.billing_month, b.units_consumed
      from public.utility_accounts a
      join public.utility_bills b on b.utility_account_id = a.id
      join public.properties p on p.id = a.property_id
      left join public.units u on u.id = a.unit_id
      where a.portfolio_id = p_portfolio_id
        and a.archived_at is null
        and a.type = 'electricity'
        and a.is_protected_consumer
        and b.units_consumed is not null
      order by a.id, b.billing_month desc
    ) x
    where x.units_consumed >= 180
  ),
  expenses as (
    select
      coalesce(sum(e.amount) filter (where e.spent_on >= v_month and e.spent_on < v_next_month), 0) as this_month,
      coalesce(sum(e.amount) filter (
        where e.spent_on >= (v_month - interval '3 months')::date and e.spent_on < v_month
      ), 0) / 3.0 as trailing_3m_avg
    from public.expenses e
    where e.portfolio_id = p_portfolio_id
  ),
  counts as (
    select
      (select count(*) from public.properties p where p.portfolio_id = p_portfolio_id and p.archived_at is null) as properties,
      (select count(*) from public.tenants t where t.portfolio_id = p_portfolio_id and t.archived_at is null) as tenants,
      (select count(*) from active_leases) as active_leases,
      (select count(*) from public.maintenance_requests m
        where m.portfolio_id = p_portfolio_id and m.status in ('open', 'in_progress', 'on_hold')) as open_maintenance,
      (select count(*) from public.maintenance_requests m
        where m.portfolio_id = p_portfolio_id and m.status in ('open', 'in_progress', 'on_hold')
          and m.priority = 'urgent') as urgent_maintenance
  )
  select jsonb_build_object(
    'as_of', v_as_of,
    'month', jsonb_build_object(
      'period', v_month,
      'expected', md.expected,
      'paid', md.paid,
      'collection_rate', case when md.expected > 0 then round(md.paid / md.expected, 4) end,
      'cash_received', mc.received,
      'tax_withheld', mc.tax_withheld,
      'by_method', mc.by_method
    ),
    'outstanding', jsonb_build_object(
      'total', ag.total, 'overdue', ag.overdue,
      'aging', jsonb_build_object(
        'not_due', ag.not_due, 'd1_30', ag.d1_30, 'd31_60', ag.d31_60,
        'd61_90', ag.d61_90, 'd90_plus', ag.d90_plus
      )
    ),
    'occupancy', jsonb_build_object(
      'units', oc.units, 'occupied', oc.occupied, 'vacant', oc.vacant, 'unavailable', oc.unavailable,
      'rate', case when oc.units - oc.unavailable > 0
                   then round(oc.occupied::numeric / (oc.units - oc.unavailable), 4) end,
      'vacant_asking_rent', oc.vacant_asking_rent
    ),
    'vacant_units', vu.items,
    'top_arrears', ta.items,
    'leases_expiring', ex.items,
    'increments_upcoming', inc.upcoming,
    'increments_missed', inc.missed,
    'police_pending', po.items,
    'cnic_expiring', cn.items,
    'deposits', jsonb_build_object('agreed', de.agreed, 'held', de.held),
    'utilities', jsonb_build_object(
      'unpaid_landlord_name_total', ut.unpaid_landlord_name_total,
      'unpaid_landlord_name_count', ut.unpaid_landlord_name_count,
      'overdue_count', ut.overdue_count,
      'high_usage', hu.items
    ),
    'expenses', jsonb_build_object('this_month', ex2.this_month, 'trailing_3m_avg', round(ex2.trailing_3m_avg, 2)),
    'counts', to_jsonb(ct)
  )
  into v_result
  from month_dues md, month_cash mc, aging ag, occupancy oc, vacant_units vu, top_arrears ta,
       expiring ex, increments_due inc, police po, cnic cn, deposits de, utilities ut, high_usage hu,
       expenses ex2, counts ct;

  return v_result;
end
$$;


-- ---------------------------------------------------------------------------
-- 4. The days-only helper has no caller left
-- ---------------------------------------------------------------------------

-- The app schema is not exposed through the API (supabase/config.toml), so no
-- client can call it; the only callers were the two functions redefined above.
-- squawk-ignore ban-drop-function
drop function app.police_registration_deadline_days(public.province);
