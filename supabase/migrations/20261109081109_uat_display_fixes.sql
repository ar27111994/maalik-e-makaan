-- ============================================================================
-- Two display faults the browser UAT found (docs/uat.md):
--
--   D5  "Vacant since" was the UTC date of the unit's creation
--       (u.created_at::date, the database runs in UTC): a unit added at
--       01:30 on 9 November in Pakistan read "vacant since 8 November" and
--       counted a day of vacancy too many. Every other date in the schema is
--       a Pakistan date (app.today_pkt()). The view public.unit_occupancy and
--       public.get_dashboard now take the creation date in Asia/Karachi.
--   D6  Automatic late fees carried the English note 'Late fee', which the
--       ledger printed after the fee's own (translated) kind, in English in
--       the Urdu app too. private.assess_late_fees now writes no note, and the
--       automatic fees already written lose theirs.
--
-- Each definition below is the current one (unit_occupancy from
-- 20261103194625_reports.sql, get_dashboard from
-- 20261107172908_police_registration_rules.sql, assess_late_fees from
-- 20261104143928_ledger_jobs_hardening.sql) with only that change. CREATE OR
-- REPLACE keeps their grants, owners and comments. pgTAP:
-- supabase/tests/database/21_uat_display_fixes.test.sql.
-- ============================================================================

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- D5: vacant since, as a Pakistan date
-- ---------------------------------------------------------------------------

create or replace view public.unit_occupancy
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
      (u.created_at at time zone 'Asia/Karachi')::date
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

-- ---------------------------------------------------------------------------
-- D5: the dashboard's vacant units, the same way (base: get_dashboard in
-- 20261107172908_police_registration_rules.sql; only vacant_since changes)
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
        (u.created_at at time zone 'Asia/Karachi')::date
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
-- D6: automatic late fees without an English note
-- ---------------------------------------------------------------------------

create or replace function private.assess_late_fees(p_lease_id uuid, p_as_of date)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_rows integer;
begin
  select l.* into v_lease from public.leases l where l.id = p_lease_id;
  if not found or v_lease.status <> 'active' or v_lease.late_fee_type = 'none' then
    return 0;
  end if;

  -- No description: the kind already says "late fee", in the reader's
  -- language; a note is what a person adds.
  insert into public.charges (
    portfolio_id, lease_id, kind, period_month, due_date, amount, source, related_charge_id, description
  )
  select
    c.portfolio_id, c.lease_id, 'late_fee', c.period_month, p_as_of, f.fee, 'auto_late_fee', c.id,
    null
  from public.charges c
  cross join lateral (
    select app.late_fee_amount(
      v_lease.late_fee_type, v_lease.late_fee_value, v_lease.late_fee_cap, c.outstanding,
      p_as_of - c.due_date, v_lease.grace_days
    ) as fee
  ) f
  where c.lease_id = p_lease_id
    and c.kind = 'rent'
    and c.voided_at is null
    and c.outstanding > 0
    and p_as_of - c.due_date > v_lease.grace_days
    and f.fee > 0
  order by c.due_date, c.id
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

-- The automatic fees written so far, whose note is still the literal the job
-- wrote (a member may have replaced it through update_charge: such a note is
-- kept). A note that a member typed as exactly 'Late fee' would also go, and
-- says no more than the kind. Voided fees keep theirs: a voided row is
-- history.
update public.charges
set description = null
where kind = 'late_fee'
  and source = 'auto_late_fee'
  and description = 'Late fee'
  and voided_at is null;
