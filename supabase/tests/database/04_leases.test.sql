-- Lease lifecycle: generated dues (with proration), overlap protection,
-- deposit and due-day synchronisation, rent changes and ending a tenancy.
begin;
\ir _helpers.psql
select plan(34);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_rental(:'pid') as r \gset
select (:'r')::jsonb ->> 'unit_id' as unit, (:'r')::jsonb ->> 'tenant_id' as tenant,
       (:'r')::jsonb ->> 'property_id' as prop \gset

-- Creating a lease ----------------------------------------------------------
select tests.authenticate_as(:'owner');
insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, end_date, monthly_rent,
                           security_deposit, rent_due_day)
values ('01a1a2d0-0000-7000-8000-000000000001', :'pid', :'unit', :'tenant', '2026-09-15', '2027-08-14',
        45000, 90000, 5);
\set lease '01a1a2d0-0000-7000-8000-000000000001'

select results_eq(
  format($f$select kind::text, period_month, due_date, amount from public.charges
            where lease_id = %L order by due_date, kind$f$, :'lease'),
  $$values ('rent', '2026-09-01'::date, '2026-09-15'::date, 24000.00::numeric),
           ('security_deposit', null, '2026-09-15', 90000.00),
           ('rent', '2026-10-01', '2026-10-05', 45000.00),
           ('rent', '2026-11-01', '2026-11-05', 45000.00)$$,
  'dues are generated through this month; the first month is prorated (16/30) and due on move-in'
);
select results_eq(
  format($f$select effective_from, monthly_rent, reason from public.rent_changes where lease_id = %L$f$, :'lease'),
  $$values ('2026-09-01'::date, 45000.00::numeric, 'initial'::text)$$,
  'the initial rent is recorded in the rent history'
);
select is(
  (select billing_starts_on from public.leases where id = :'lease'),
  '2026-09-15'::date,
  'billing starts on the start date by default'
);

-- Overlap protection ----------------------------------------------------------
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
            values (%L, %L, %L, '2027-01-01', 40000)$f$, :'pid', :'unit', :'tenant'),
  '23P01', null, 'a second active tenancy overlapping the first is rejected'
);
select lives_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, billing_starts_on)
            values (%L, %L, %L, '2027-08-15', 50000, '2027-08-15')$f$, :'pid', :'unit', :'tenant'),
  'the next tenancy may be scheduled after the agreed end date'
);
select is(
  (select status from public.unit_occupancy where unit_id = :'unit'),
  'occupied',
  'the unit is occupied by the current tenancy'
);

-- Constraint checks -------------------------------------------------------------
select tests.create_rental(:'pid', 'sindh', 'Shop 4') as r2 \gset
select (:'r2')::jsonb ->> 'unit_id' as unit2, (:'r2')::jsonb ->> 'tenant_id' as tenant2 \gset
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, end_date, monthly_rent)
            values (%L, %L, %L, '2026-11-01', '2026-10-01', 40000)$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'an agreed end date before the start date is rejected'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, late_fee_type)
            values (%L, %L, %L, '2026-11-01', 40000, 'percent')$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'a late-fee policy needs a value'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, late_fee_type, late_fee_value)
            values (%L, %L, %L, '2026-11-01', 40000, 'percent', 120)$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'a percentage late fee cannot exceed 100%'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, late_fee_type, late_fee_value, late_fee_cap)
            values (%L, %L, %L, '2026-11-01', 40000, 'flat', 500, 1000)$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'only daily late fees may have a cap'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, rent_due_day)
            values (%L, %L, %L, '2026-11-01', 40000, 31)$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'due days are limited to 1-28 so every month has one'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
            values (%L, %L, %L, '2026-11-01', 0)$f$, :'pid', :'unit2', :'tenant2'),
  '23514', null, 'rent must be positive'
);

update public.units set archived_at = now() where id = :'unit2';
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
            values (%L, %L, %L, '2026-11-01', 40000)$f$, :'pid', :'unit2', :'tenant2'),
  '22023', 'unit_archived', 'archived units cannot be let'
);
update public.units set archived_at = null where id = :'unit2';
update public.tenants set archived_at = now() where id = :'tenant2';
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
            values (%L, %L, %L, '2026-11-01', 40000)$f$, :'pid', :'unit2', :'tenant2'),
  '22023', 'tenant_archived', 'archived tenants cannot get a new tenancy'
);
update public.tenants set archived_at = null where id = :'tenant2';

-- Onboarding an existing tenancy: bill only from the chosen month -------------
insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent, billing_starts_on, rent_due_day)
values ('01a1a2d0-0000-7000-8000-000000000002', :'pid', :'unit2', :'tenant2', '2024-03-10', 60000, '2026-11-01', 10);
select results_eq(
  $$select period_month, due_date, amount from public.charges
    where lease_id = '01a1a2d0-0000-7000-8000-000000000002' order by period_month$$,
  $$values ('2026-11-01'::date, '2026-11-10'::date, 60000.00::numeric)$$,
  'onboarded tenancies are billed from billing_starts_on only, without proration on day 1'
);

-- Due day and deposit synchronisation ------------------------------------------
update public.leases set rent_due_day = 10 where id = :'lease';
select results_eq(
  format($f$select period_month, due_date from public.charges
            where lease_id = %L and kind = 'rent' order by period_month$f$, :'lease'),
  $$values ('2026-09-01'::date, '2026-09-15'::date), ('2026-10-01', '2026-10-05'), ('2026-11-01', '2026-11-10')$$,
  'changing the due day moves only current and future unpaid dues'
);

update public.leases set security_deposit = 100000 where id = :'lease';
select is(
  (select amount from public.charges where lease_id = :'lease' and kind = 'security_deposit' and voided_at is null),
  100000.00, 'raising the deposit updates the deposit due'
);
select public.record_payment(:'lease', 124000, '2026-09-15', 'cash', gen_random_uuid()) is not null as paid \gset
select throws_ok(
  format($f$update public.leases set security_deposit = 50000 where id = %L$f$, :'lease'),
  '22023', 'deposit_below_received', 'the deposit cannot drop below what was already received'
);

-- Column grants keep rent and status behind RPCs -----------------------------------
select throws_ok(
  format($f$update public.leases set monthly_rent = 1000 where id = %L$f$, :'lease'),
  '42501', null, 'rent cannot be edited directly'
);

-- change_rent ---------------------------------------------------------------------
select is(
  (public.change_rent(:'lease', '2026-11-01', 49500, 'annual_increment', '10% after first year')).monthly_rent,
  49500.00, 'change_rent applies the new rent from the chosen month'
);
select results_eq(
  format($f$select period_month, amount from public.charges where lease_id = %L and kind = 'rent' order by period_month$f$, :'lease'),
  $$values ('2026-09-01'::date, 24000.00::numeric), ('2026-10-01', 45000.00), ('2026-11-01', 49500.00)$$,
  'untouched dues from that month are re-priced; earlier months keep their rent'
);
select throws_ok(
  format($f$select public.change_rent(%L, '2026-12-01', 50000, 'initial')$f$, :'lease'),
  '22023', 'invalid_reason', 'the initial rent cannot be rewritten through change_rent'
);
select throws_ok(
  format($f$select public.change_rent(%L, '2026-08-01', 50000)$f$, :'lease'),
  '22023', 'invalid_date', 'rent cannot change before billing started'
);
select throws_ok(
  format($f$select public.change_rent(%L, '2026-12-01', 50000.555)$f$, :'lease'),
  '22023', 'invalid_amount', 'amounts with fractions of a paisa are rejected'
);

-- Future increment: billed when its month arrives ------------------------------------
select lives_ok(
  format($f$select public.change_rent(%L, '2027-01-01', 52000, 'renegotiation')$f$, :'lease'),
  'a future rent change can be scheduled'
);
set local app.today_override = '2027-01-02';
reset role;
select private.run_daily_jobs('2027-01-02') is not null as ran \gset
select results_eq(
  format($f$select period_month, amount from public.charges where lease_id = %L and kind = 'rent'
            and period_month >= '2026-12-01' order by period_month$f$, :'lease'),
  $$values ('2026-12-01'::date, 49500.00::numeric), ('2027-01-01', 52000.00)$$,
  'the daily job bills December at the increment and January at the renegotiated rent'
);
select is(
  (select monthly_rent from public.leases where id = :'lease'), 52000.00,
  'the current rent on the lease follows the rent history'
);

-- Ending a tenancy ---------------------------------------------------------------------
select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$select public.end_lease(%L, '2027-02-01', 'tenant_moved_out')$f$, :'lease'),
  '22023', 'invalid_date', 'the move-out date cannot be in the future'
);
set local app.today_override = '2027-03-20';
reset role;
select private.sync_lease_billing(:'lease', '2027-03-20');
select tests.authenticate_as(:'owner');
select is(
  (public.end_lease(:'lease', '2027-02-10', 'tenant_moved_out')).status::text, 'ended',
  'end_lease records the move-out'
);
select results_eq(
  format($f$select period_month, voided_at is not null from public.charges
            where lease_id = %L and kind = 'rent' and period_month >= '2027-02-01' order by period_month$f$, :'lease'),
  $$values ('2027-02-01'::date, false), ('2027-03-01', true)$$,
  'rent after the move-out month is voided; the move-out month is billed in full'
);
select throws_ok(
  format($f$select public.end_lease(%L, '2027-02-10', 'tenant_moved_out')$f$, :'lease'),
  '22023', 'lease_not_active', 'an ended tenancy cannot be ended again'
);
select is(
  (select status from public.unit_occupancy where unit_id = :'unit'),
  'upcoming',
  'after move-out the unit shows the scheduled next tenancy as upcoming'
);

-- Occupants -------------------------------------------------------------------------
select throws_ok(
  format($f$insert into public.lease_occupants (portfolio_id, lease_id, full_name, cnic) values (%L, %L, 'Wife', '123')$f$,
         :'pid', :'lease'),
  '23514', null, 'occupant CNICs are validated'
);
select lives_ok(
  format($f$insert into public.lease_occupants (portfolio_id, lease_id, full_name, relation, cnic)
            values (%L, %L, 'Sana Bilal', 'wife', '3520298765432')$f$, :'pid', :'lease'),
  'adult co-occupants are recorded for police registration'
);

select * from finish();
rollback;
