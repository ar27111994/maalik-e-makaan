-- ============================================================================
-- Read models and report RPCs.
--
-- Aggregation happens here, next to the data, in one round trip per screen.
-- Every function is SECURITY INVOKER: row-level security of the underlying
-- tables still applies, and an explicit membership check gives a clear 403
-- instead of silently empty results. Interpretation (scores, insight rules)
-- lives in the app's pure-Dart domain layer.
-- ============================================================================

-- Latest anniversary on or before p_as_of, or null before the first one.
create or replace function app.last_anniversary(p_start date, p_as_of date, p_interval_months integer)
returns date
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  v_next date;
  v_cycles integer;
begin
  if p_as_of < (p_start + make_interval(months => p_interval_months))::date then
    return null;
  end if;
  v_next := app.next_anniversary(p_start, p_as_of, p_interval_months);
  if v_next = p_as_of then
    return v_next;
  end if;
  -- v_next = p_start + cycles * interval months exactly (month arithmetic).
  v_cycles := ((extract(year from v_next) * 12 + extract(month from v_next))
    - (extract(year from p_start) * 12 + extract(month from p_start)))::integer / p_interval_months;
  return (p_start + make_interval(months => (v_cycles - 1) * p_interval_months))::date;
end
$$;

grant execute on function app.last_anniversary(date, date, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

-- Occupancy per unit: occupied (an active tenancy has started), upcoming
-- (only a future tenancy), vacant, unavailable or archived.
create view public.unit_occupancy
with (security_invoker = true)
as
select
  u.id as unit_id,
  u.portfolio_id,
  u.property_id,
  cur.id as lease_id,
  cur.tenant_id,
  case
    when u.archived_at is not null then 'archived'
    when cur.id is not null then 'occupied'
    when nxt.id is not null then 'upcoming'
    when not u.is_available then 'unavailable'
    else 'vacant'
  end as status,
  case
    when cur.id is null then coalesce(
      (select max(pl.moved_out_on) from public.leases pl where pl.unit_id = u.id and pl.status = 'ended'),
      u.created_at::date
    )
  end as vacant_since
from public.units u
left join lateral (
  select l.id, l.tenant_id
  from public.leases l
  where l.unit_id = u.id and l.status = 'active' and l.start_date <= app.today_pkt()
  order by l.start_date
  limit 1
) cur on true
left join lateral (
  select l.id
  from public.leases l
  where l.unit_id = u.id and l.status = 'active' and l.start_date > app.today_pkt()
  order by l.start_date
  limit 1
) nxt on true;

comment on view public.unit_occupancy is 'Current occupancy status of every unit (RLS of units/leases applies).';

-- Balance per lease: what is owed, how much is overdue and since when, any
-- credit, and the last payment and reminder.
create view public.lease_balances
with (security_invoker = true)
as
select
  l.id as lease_id,
  l.portfolio_id,
  l.tenant_id,
  l.unit_id,
  l.status,
  coalesce(c.outstanding, 0) as outstanding,
  coalesce(c.overdue, 0) as overdue,
  c.oldest_overdue_due_date,
  case when c.oldest_overdue_due_date is not null
       then app.today_pkt() - c.oldest_overdue_due_date end as days_overdue,
  coalesce(p.credit, 0) as credit,
  p.last_paid_on,
  r.last_reminded_at
from public.leases l
left join lateral (
  select
    sum(ch.outstanding) as outstanding,
    sum(ch.outstanding) filter (where ch.due_date < app.today_pkt()) as overdue,
    min(ch.due_date) filter (where ch.due_date < app.today_pkt()) as oldest_overdue_due_date
  from public.charges ch
  where ch.lease_id = l.id and ch.voided_at is null and ch.outstanding > 0
) c on true
left join lateral (
  select
    sum(py.unallocated_amount) as credit,
    max(py.paid_on) filter (where py.method <> 'deposit_adjustment') as last_paid_on
  from public.payments py
  where py.lease_id = l.id and py.voided_at is null
) p on true
left join lateral (
  select max(rl.sent_at) as last_reminded_at
  from public.reminder_logs rl
  where rl.lease_id = l.id
) r on true;

comment on view public.lease_balances is 'Outstanding, overdue, credit and last activity per lease (RLS applies).';

grant select on public.unit_occupancy, public.lease_balances to authenticated;

-- ---------------------------------------------------------------------------
-- Dashboard
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
      'deadline', al.start_date + app.police_registration_deadline_days(al.province),
      'overdue', v_as_of > al.start_date + app.police_registration_deadline_days(al.province),
      'status', al.police_status
    ) order by al.start_date), '[]'::jsonb) as items
    from active_leases al
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
-- Receivables ("who owes what, since when")
-- ---------------------------------------------------------------------------

create or replace function public.get_receivables(p_portfolio_id uuid)
returns table (
  lease_id uuid,
  lease_status public.lease_status,
  tenant_id uuid,
  tenant_name text,
  tenant_phone text,
  unit_id uuid,
  unit_label text,
  property_id uuid,
  property_name text,
  monthly_rent numeric,
  outstanding numeric,
  overdue numeric,
  oldest_overdue_due_date date,
  days_overdue integer,
  credit numeric,
  last_paid_on date,
  last_reminded_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform app.require_portfolio_role(p_portfolio_id);
  return query
  select
    lb.lease_id, lb.status, t.id, t.full_name, t.phone, u.id, u.label, p.id, p.name, l.monthly_rent,
    lb.outstanding, lb.overdue, lb.oldest_overdue_due_date, lb.days_overdue, lb.credit,
    lb.last_paid_on, lb.last_reminded_at
  from public.lease_balances lb
  join public.leases l on l.id = lb.lease_id
  join public.tenants t on t.id = lb.tenant_id
  join public.units u on u.id = lb.unit_id
  join public.properties p on p.id = u.property_id
  where lb.portfolio_id = p_portfolio_id
    and (lb.status = 'active' or lb.outstanding > 0 or lb.credit > 0)
  order by lb.overdue desc, lb.days_overdue desc nulls last, t.full_name;
end
$$;

-- Per rent due facts for payment-behaviour scoring (mm_core computes the
-- explainable score from these).
create or replace function public.get_payment_facts(p_portfolio_id uuid, p_since date default null)
returns table (
  lease_id uuid,
  tenant_id uuid,
  charge_id uuid,
  due_date date,
  amount numeric,
  waived numeric,
  outstanding numeric,
  settled_on date,
  grace_days integer,
  monthly_rent numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform app.require_portfolio_role(p_portfolio_id);
  return query
  select
    c.lease_id, l.tenant_id, c.id, c.due_date, c.amount, c.waived_amount, c.outstanding,
    case when c.outstanding = 0 then (
      select max(p.paid_on)
      from public.payment_allocations a
      join public.payments p on p.id = a.payment_id
      where a.charge_id = c.id and p.voided_at is null
    ) end,
    l.grace_days::integer,
    l.monthly_rent
  from public.charges c
  join public.leases l on l.id = c.lease_id
  where c.portfolio_id = p_portfolio_id
    and c.kind = 'rent'
    and c.voided_at is null
    and c.due_date >= coalesce(p_since, (app.today_pkt() - interval '12 months')::date)
    and c.due_date <= app.today_pkt()
  order by c.lease_id, c.due_date;
end
$$;

-- ---------------------------------------------------------------------------
-- Cash flow, property performance, tax year, cash positions
-- ---------------------------------------------------------------------------

create or replace function public.get_cashflow(p_portfolio_id uuid, p_from date, p_to date)
returns table (
  month date,
  cash_received numeric,
  rent_collected numeric,
  deposits_collected numeric,
  other_collected numeric,
  tax_withheld numeric,
  expenses numeric,
  deposit_refunds numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform app.require_portfolio_role(p_portfolio_id);
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 3660 then
    perform app.fail('invalid_date');
  end if;
  return query
  with months as (
    select generate_series(date_trunc('month', p_from), date_trunc('month', p_to), interval '1 month')::date as m
  ),
  pay as (
    select date_trunc('month', p.paid_on)::date as m, sum(p.amount) as cash, sum(p.tax_withheld) as tax
    from public.payments p
    where p.portfolio_id = p_portfolio_id and p.voided_at is null and p.method <> 'deposit_adjustment'
      and p.paid_on between p_from and p_to
    group by 1
  ),
  alloc as (
    select
      date_trunc('month', p.paid_on)::date as m,
      sum(a.amount) filter (where c.kind in ('rent', 'late_fee')) as rent,
      sum(a.amount) filter (where c.kind = 'security_deposit') as deposits,
      sum(a.amount) filter (where c.kind not in ('rent', 'late_fee', 'security_deposit')) as other
    from public.payment_allocations a
    join public.payments p on p.id = a.payment_id
    join public.charges c on c.id = a.charge_id
    where a.portfolio_id = p_portfolio_id and p.voided_at is null and p.method <> 'deposit_adjustment'
      and p.paid_on between p_from and p_to
    group by 1
  ),
  exp as (
    select date_trunc('month', e.spent_on)::date as m, sum(e.amount) as total
    from public.expenses e
    where e.portfolio_id = p_portfolio_id and e.spent_on between p_from and p_to
    group by 1
  ),
  ref as (
    select date_trunc('month', r.refunded_on)::date as m, sum(r.amount) as total
    from public.deposit_refunds r
    where r.portfolio_id = p_portfolio_id and r.voided_at is null and r.refunded_on between p_from and p_to
    group by 1
  )
  select
    months.m,
    coalesce(pay.cash, 0), coalesce(alloc.rent, 0), coalesce(alloc.deposits, 0), coalesce(alloc.other, 0),
    coalesce(pay.tax, 0), coalesce(exp.total, 0), coalesce(ref.total, 0)
  from months
  left join pay on pay.m = months.m
  left join alloc on alloc.m = months.m
  left join exp on exp.m = months.m
  left join ref on ref.m = months.m
  order by months.m;
end
$$;

create or replace function public.get_property_performance(p_portfolio_id uuid, p_from date, p_to date)
returns table (
  property_id uuid,
  property_name text,
  units integer,
  occupied_units integer,
  rent_income numeric,
  other_income numeric,
  expenses numeric,
  net_operating_income numeric,
  estimated_value numeric,
  gross_yield numeric,
  net_yield numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_years numeric;
begin
  perform app.require_portfolio_role(p_portfolio_id);
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 3660 then
    perform app.fail('invalid_date');
  end if;
  v_years := greatest((p_to - p_from + 1)::numeric / 365.25, 1.0 / 365.25);

  return query
  with income as (
    select
      u.property_id,
      sum(a.amount) filter (where c.kind in ('rent', 'late_fee')) as rent,
      sum(a.amount) filter (where c.kind not in ('rent', 'late_fee', 'security_deposit')) as other
    from public.payment_allocations a
    join public.payments p on p.id = a.payment_id
    join public.charges c on c.id = a.charge_id
    join public.leases l on l.id = c.lease_id
    join public.units u on u.id = l.unit_id
    where a.portfolio_id = p_portfolio_id and p.voided_at is null and p.paid_on between p_from and p_to
    group by u.property_id
  ),
  spend as (
    select e.property_id, sum(e.amount) as total
    from public.expenses e
    where e.portfolio_id = p_portfolio_id and e.property_id is not null and e.spent_on between p_from and p_to
    group by e.property_id
  ),
  occ as (
    select
      u.property_id,
      count(*)::integer as units,
      count(*) filter (where exists (
        select 1 from public.leases l
        where l.unit_id = u.id and l.status = 'active' and l.start_date <= app.today_pkt()
      ))::integer as occupied
    from public.units u
    where u.portfolio_id = p_portfolio_id and u.archived_at is null
    group by u.property_id
  )
  select
    pr.id, pr.name, coalesce(occ.units, 0), coalesce(occ.occupied, 0),
    coalesce(income.rent, 0), coalesce(income.other, 0), coalesce(spend.total, 0),
    coalesce(income.rent, 0) + coalesce(income.other, 0) - coalesce(spend.total, 0),
    pr.estimated_value,
    case when pr.estimated_value > 0
         then round(coalesce(income.rent, 0) / v_years / pr.estimated_value, 4) end,
    case when pr.estimated_value > 0
         then round((coalesce(income.rent, 0) + coalesce(income.other, 0) - coalesce(spend.total, 0))
                    / v_years / pr.estimated_value, 4) end
  from public.properties pr
  left join income on income.property_id = pr.id
  left join spend on spend.property_id = pr.id
  left join occ on occ.property_id = pr.id
  where pr.portfolio_id = p_portfolio_id and pr.archived_at is null
  order by pr.name;
end
$$;

-- Tax-year (1 July – 30 June) rental statement per property, for the
-- landlord's accountant. Not tax advice: the app labels it as such.
-- gross_rent counts rent and late fees settled during the year (cash plus
-- tax withheld at source); repairs_allowance is the s.15A one-fifth.
create or replace function public.get_tax_year_statement(p_portfolio_id uuid, p_tax_year integer)
returns table (
  property_id uuid,
  property_name text,
  gross_rent numeric,
  tax_withheld numeric,
  repairs_allowance numeric,
  expenses_by_category jsonb,
  expenses_total numeric,
  net_after_repairs_allowance numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_start date;
  v_end date;
begin
  perform app.require_portfolio_role(p_portfolio_id);
  if p_tax_year is null or p_tax_year < 2000 or p_tax_year > 2100 then
    perform app.fail('invalid_tax_year');
  end if;
  v_start := make_date(p_tax_year - 1, 7, 1);
  v_end := make_date(p_tax_year, 6, 30);

  return query
  with rent as (
    select u.property_id, sum(a.amount) as gross
    from public.payment_allocations a
    join public.payments p on p.id = a.payment_id
    join public.charges c on c.id = a.charge_id
    join public.leases l on l.id = c.lease_id
    join public.units u on u.id = l.unit_id
    where a.portfolio_id = p_portfolio_id and p.voided_at is null
      and c.kind in ('rent', 'late_fee')
      and p.paid_on between v_start and v_end
    group by u.property_id
  ),
  wht as (
    select u.property_id, sum(p.tax_withheld) as withheld
    from public.payments p
    join public.leases l on l.id = p.lease_id
    join public.units u on u.id = l.unit_id
    where p.portfolio_id = p_portfolio_id and p.voided_at is null and p.paid_on between v_start and v_end
    group by u.property_id
  ),
  exp as (
    select e.property_id, jsonb_object_agg(e.category, e.total) as by_category, sum(e.total) as total
    from (
      select x.property_id, x.category, sum(x.amount) as total
      from public.expenses x
      where x.portfolio_id = p_portfolio_id and x.property_id is not null
        and x.spent_on between v_start and v_end
      group by x.property_id, x.category
    ) e
    group by e.property_id
  )
  select
    pr.id, pr.name,
    coalesce(rent.gross, 0),
    coalesce(wht.withheld, 0),
    round(coalesce(rent.gross, 0) / 5, 2),
    coalesce(exp.by_category, '{}'::jsonb),
    coalesce(exp.total, 0),
    coalesce(rent.gross, 0) - round(coalesce(rent.gross, 0) / 5, 2)
  from public.properties pr
  left join rent on rent.property_id = pr.id
  left join wht on wht.property_id = pr.id
  left join exp on exp.property_id = pr.id
  where pr.portfolio_id = p_portfolio_id
    and (pr.archived_at is null or rent.gross is not null or exp.total is not null)
  order by pr.name;
end
$$;

-- Cash in hand per member: cash rent they received, minus cash they handed
-- over, minus cash expenses they paid. Lets an overseas owner see what a
-- caretaker currently holds.
create or replace function public.get_cash_positions(p_portfolio_id uuid)
returns table (
  user_id uuid,
  full_name text,
  role public.member_role,
  cash_collected numeric,
  handed_over numeric,
  cash_expenses numeric,
  cash_in_hand numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform app.require_portfolio_role(p_portfolio_id);
  return query
  select
    m.user_id, pf.full_name, m.role,
    coalesce(col.total, 0), coalesce(ho.total, 0), coalesce(ex.total, 0),
    coalesce(col.total, 0) - coalesce(ho.total, 0) - coalesce(ex.total, 0)
  from public.portfolio_members m
  left join public.profiles pf on pf.id = m.user_id
  left join lateral (
    select sum(p.amount) as total
    from public.payments p
    where p.portfolio_id = p_portfolio_id and p.received_by = m.user_id
      and p.method = 'cash' and p.voided_at is null
  ) col on true
  left join lateral (
    select sum(h.amount) as total
    from public.cash_handovers h
    where h.portfolio_id = p_portfolio_id and h.from_user_id = m.user_id and h.voided_at is null
  ) ho on true
  left join lateral (
    select sum(e.amount) as total
    from public.expenses e
    where e.portfolio_id = p_portfolio_id and e.paid_by = m.user_id and e.method = 'cash'
  ) ex on true
  where m.portfolio_id = p_portfolio_id
  order by (coalesce(col.total, 0) - coalesce(ho.total, 0) - coalesce(ex.total, 0)) desc;
end
$$;

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------

-- Fuzzy search across properties, units and tenants (names, city/locality,
-- phone digits, CNIC). LIKE wildcards in the query are escaped.
create or replace function public.search_portfolio(p_portfolio_id uuid, p_query text, p_limit integer default 20)
returns table (
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  score real
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_like text;
  v_digits text;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  perform app.require_portfolio_role(p_portfolio_id);
  if char_length(v_query) < 2 or char_length(v_query) > 100 then
    return;
  end if;
  v_like := '%' || replace(replace(replace(lower(v_query), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits := regexp_replace(v_query, '[^0-9]', '', 'g');

  return query
  select * from (
    select 'property'::text, p.id, p.name,
           concat_ws(', ', p.locality, p.city),
           greatest(extensions.similarity(lower(p.name), lower(v_query)),
                    case when lower(p.name) like v_like then 0.6 else 0 end)::real
    from public.properties p
    where p.portfolio_id = p_portfolio_id and p.archived_at is null
      and (lower(p.name) like v_like or lower(coalesce(p.locality, '')) like v_like
           or lower(p.city) like v_like or extensions.similarity(lower(p.name), lower(v_query)) > 0.3)
    union all
    select 'unit'::text, u.id, u.label, p.name,
           greatest(extensions.similarity(lower(u.label), lower(v_query)),
                    case when lower(u.label) like v_like then 0.6 else 0 end)::real
    from public.units u
    join public.properties p on p.id = u.property_id
    where u.portfolio_id = p_portfolio_id and u.archived_at is null
      and (lower(u.label) like v_like or extensions.similarity(lower(u.label), lower(v_query)) > 0.3)
    union all
    select 'tenant'::text, t.id, t.full_name, t.phone,
           greatest(extensions.similarity(lower(t.full_name), lower(v_query)),
                    case when lower(t.full_name) like v_like then 0.6 else 0 end,
                    case when char_length(v_digits) >= 4
                          and (t.phone like '%' || v_digits || '%' or t.cnic like '%' || v_digits || '%')
                         then 0.9 else 0 end)::real
    from public.tenants t
    where t.portfolio_id = p_portfolio_id and t.archived_at is null
      and (lower(t.full_name) like v_like
           or extensions.similarity(lower(t.full_name), lower(v_query)) > 0.3
           or (char_length(v_digits) >= 4
               and (t.phone like '%' || v_digits || '%' or t.cnic like '%' || v_digits || '%')))
  ) results (entity_type, entity_id, title, subtitle, score)
  order by results.score desc, results.title
  limit v_limit;
end
$$;

grant execute on function public.get_dashboard(uuid, date) to authenticated;
grant execute on function public.get_receivables(uuid) to authenticated;
grant execute on function public.get_payment_facts(uuid, date) to authenticated;
grant execute on function public.get_cashflow(uuid, date, date) to authenticated;
grant execute on function public.get_property_performance(uuid, date, date) to authenticated;
grant execute on function public.get_tax_year_statement(uuid, integer) to authenticated;
grant execute on function public.get_cash_positions(uuid) to authenticated;
grant execute on function public.search_portfolio(uuid, text, integer) to authenticated;
