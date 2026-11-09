-- Police tenant-registration deadlines by jurisdiction
-- (20261107172908_police_registration_rules.sql; website-facts.md §1).
begin;
\ir _helpers.psql
select plan(26);

set local app.today_override = '2026-11-10';

-- The rule ------------------------------------------------------------------------
select results_eq(
  $$select pr.province::text, r.deadline_days, r.clock, r.statutory
    from unnest(enum_range(null::public.province)) as pr (province)
    cross join lateral app.police_registration_rule(pr.province) r
    order by pr.province$$,
  $$values ('punjab', 15, 'possession', true),
           ('sindh', 2, 'possession', true),
           ('khyber_pakhtunkhwa', 7, 'agreement', true),
           ('balochistan', 3, 'agreement', true),
           ('islamabad', 1, 'possession', false),
           ('gilgit_baltistan', 1, 'possession', false),
           ('azad_kashmir', 1, 'possession', false)$$,
  'every jurisdiction has a rule: statutory where a law fixes one, an app reminder otherwise'
);

-- Deadlines: possession clocks ignore the agreement date.
select is(app.police_registration_deadline('punjab', '2026-11-01', '2026-10-20'), '2026-11-16'::date,
  'Punjab: 15 days from possession');
select is(app.police_registration_deadline('sindh', '2026-11-01', '2026-10-20'), '2026-11-03'::date,
  'Sindh: 48 hours (2 days) from possession');
select is(app.police_registration_deadline('islamabad', '2026-11-01', '2026-10-20'), '2026-11-02'::date,
  'Islamabad: the 1-day app reminder from possession');
select is(app.police_registration_deadline('gilgit_baltistan', '2026-11-01', null), '2026-11-02'::date,
  'Gilgit-Baltistan: the 1-day app reminder from possession');
select is(app.police_registration_deadline('azad_kashmir', '2026-11-01', null), '2026-11-02'::date,
  'Azad Kashmir: the 1-day app reminder from possession');

-- Agreement clocks count from the agreement, or from possession without one.
select is(app.police_registration_deadline('khyber_pakhtunkhwa', '2026-11-01', '2026-10-20'), '2026-10-27'::date,
  'KP: 7 calendar days from signing the agreement');
select is(app.police_registration_deadline('khyber_pakhtunkhwa', '2026-11-01', null), '2026-11-08'::date,
  'KP without an agreement date: 7 days from the lease start');
select is(app.police_registration_deadline('balochistan', '2026-11-01', '2026-10-20'), '2026-10-23'::date,
  'Balochistan: 3 days from signing the agreement (the stricter source)');
select is(app.police_registration_deadline('balochistan', '2026-11-01', null), '2026-11-04'::date,
  'Balochistan without an agreement date: 3 days from the lease start');
select is(app.police_registration_clock_start('khyber_pakhtunkhwa', '2026-11-01', '2026-11-05'), '2026-11-05'::date,
  'an agreement signed after possession starts the KP clock on signing');
select is(app.police_registration_clock_start('punjab', '2026-11-01', '2026-10-20'), '2026-11-01'::date,
  'a possession clock starts at the lease start');

-- One source of truth: the days-only helper is gone; the rule is callable by
-- signed-in users (the dashboard runs as the caller) and not by anon.
select hasnt_function('app', 'police_registration_deadline_days', array['public.province'],
  'the old days-only helper is dropped');
select ok(
  has_function_privilege('authenticated', 'app.police_registration_deadline(public.province, date, date)', 'execute')
  and has_function_privilege('authenticated', 'app.police_registration_rule(public.province)', 'execute')
  and not has_function_privilege('anon', 'app.police_registration_deadline(public.province, date, date)', 'execute')
  and not has_function_privilege('anon', 'app.police_registration_rule(public.province)', 'execute'),
  'the rule is executable by authenticated, not by anon'
);

-- A portfolio with a pending tenancy in every jurisdiction --------------------------
select tests.create_user('owner@example.com') as owner \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_rental(:'pid', 'punjab', 'PB') as r_pb \gset
select tests.create_rental(:'pid', 'punjab', 'PB future') as r_pb2 \gset
select tests.create_rental(:'pid', 'sindh', 'SD') as r_sd \gset
select tests.create_rental(:'pid', 'khyber_pakhtunkhwa', 'KP') as r_kp \gset
select tests.create_rental(:'pid', 'khyber_pakhtunkhwa', 'KP future') as r_kp2 \gset
select tests.create_rental(:'pid', 'balochistan', 'BL') as r_bl \gset
select tests.create_rental(:'pid', 'balochistan', 'BL no agreement') as r_bl2 \gset
select tests.create_rental(:'pid', 'islamabad', 'ICT') as r_ict \gset
select tests.create_rental(:'pid', 'gilgit_baltistan', 'GB') as r_gb \gset
select tests.create_rental(:'pid', 'azad_kashmir', 'AJK') as r_ajk \gset

-- Today is 2026-11-10.
select tests.create_lease(:'pid', :'r_pb', '2026-11-01') as l_pb \gset
select tests.create_lease(:'pid', :'r_pb2', '2026-11-20', 45000, '{"agreement_signed_on": "2026-11-02"}') as l_pb2 \gset
select tests.create_lease(:'pid', :'r_sd', '2026-11-01') as l_sd \gset
-- KP without an agreement date: 7 days from 11-05 (the old 1-day default said overdue).
select tests.create_lease(:'pid', :'r_kp', '2026-11-05') as l_kp \gset
-- KP agreement signed 11-02 for possession on 11-20: due 11-09, already overdue.
select tests.create_lease(:'pid', :'r_kp2', '2026-11-20', 45000, '{"agreement_signed_on": "2026-11-02"}') as l_kp2 \gset
select tests.create_lease(:'pid', :'r_bl', '2026-11-01', 45000, '{"agreement_signed_on": "2026-10-30"}') as l_bl \gset
select tests.create_lease(:'pid', :'r_bl2', '2026-11-08') as l_bl2 \gset
select tests.create_lease(:'pid', :'r_ict', '2026-11-08') as l_ict \gset
select tests.create_lease(:'pid', :'r_gb', '2026-11-10') as l_gb \gset
select tests.create_lease(:'pid', :'r_ajk', '2026-11-10') as l_ajk \gset

-- Notifications -------------------------------------------------------------------
select is(private.generate_notifications('2026-11-10') > 0, true, 'notifications are generated');

select results_eq(
  format($f$
    select n.entity_id, n.kind::text, n.params ->> 'province', (n.params ->> 'deadline')::date,
           (n.params ->> 'deadline_days')::integer, (n.params ->> 'statutory')::boolean,
           n.params ->> 'clock', (n.params ->> 'clock_starts_on')::date
    from public.notifications n
    where n.portfolio_id = %L and n.kind in ('police_registration_pending', 'police_registration_overdue')
    order by (n.params ->> 'province')::public.province, (n.params ->> 'deadline')::date
  $f$, :'pid'),
  format($f$values
    (%L::uuid, 'police_registration_pending', 'punjab', '2026-11-16'::date, 15, true, 'possession', '2026-11-01'::date),
    (%L::uuid, 'police_registration_overdue', 'sindh', '2026-11-03'::date, 2, true, 'possession', '2026-11-01'::date),
    (%L::uuid, 'police_registration_overdue', 'khyber_pakhtunkhwa', '2026-11-09'::date, 7, true, 'agreement', '2026-11-02'::date),
    (%L::uuid, 'police_registration_pending', 'khyber_pakhtunkhwa', '2026-11-12'::date, 7, true, 'agreement', '2026-11-05'::date),
    (%L::uuid, 'police_registration_overdue', 'balochistan', '2026-11-02'::date, 3, true, 'agreement', '2026-10-30'::date),
    (%L::uuid, 'police_registration_pending', 'balochistan', '2026-11-11'::date, 3, true, 'agreement', '2026-11-08'::date),
    (%L::uuid, 'police_registration_overdue', 'islamabad', '2026-11-09'::date, 1, false, 'possession', '2026-11-08'::date),
    (%L::uuid, 'police_registration_pending', 'gilgit_baltistan', '2026-11-11'::date, 1, false, 'possession', '2026-11-10'::date),
    (%L::uuid, 'police_registration_pending', 'azad_kashmir', '2026-11-11'::date, 1, false, 'possession', '2026-11-10'::date)
  $f$, :'l_pb', :'l_sd', :'l_kp2', :'l_kp', :'l_bl', :'l_bl2', :'l_ict', :'l_gb', :'l_ajk'),
  'police notifications follow each jurisdiction''s rule and carry deadline, statutory and clock'
);

select is_empty(
  format($f$select 1 from public.notifications where entity_id = %L$f$, :'l_pb2'),
  'a possession clock does not start before possession, whatever the agreement date'
);

select ok(
  (select bool_and(n.params ?& array['lease_id', 'tenant_name', 'unit_label', 'province', 'deadline'])
   from public.notifications n
   where n.portfolio_id = :'pid' and n.kind in ('police_registration_pending', 'police_registration_overdue')),
  'the existing notification params are kept'
);

select is(private.generate_notifications('2026-11-10'), 0, 'regeneration is idempotent');

-- KP becomes overdue after its 7 days, not after 1.
select is(
  (select count(*)::integer from public.notifications
   where entity_id = :'l_kp' and kind = 'police_registration_overdue'),
  0, 'KP is not overdue the day after possession'
);
select is(private.generate_notifications('2026-11-13') > 0, true, 'a later run generates more');
select is(
  (select count(*)::integer from public.notifications
   where entity_id = :'l_kp' and kind = 'police_registration_overdue'),
  1, 'KP is overdue once its 7 days have passed'
);

-- Dashboard compliance --------------------------------------------------------------
select tests.authenticate_as(:'owner');
select public.get_dashboard(:'pid', '2026-11-10') as d \gset
select tests.clear_authentication();

select results_eq(
  format($f$
    select (i ->> 'lease_id')::uuid, i ->> 'province', (i ->> 'start_date')::date, (i ->> 'deadline')::date,
           (i ->> 'overdue')::boolean, i ->> 'status', (i ->> 'deadline_days')::integer,
           (i ->> 'statutory')::boolean, i ->> 'clock', (i ->> 'clock_starts_on')::date
    from jsonb_array_elements(%L::jsonb -> 'police_pending') i
    order by (i ->> 'province')::public.province, (i ->> 'deadline')::date
  $f$, :'d'),
  format($f$values
    (%L::uuid, 'punjab', '2026-11-01'::date, '2026-11-16'::date, false, 'pending', 15, true, 'possession', '2026-11-01'::date),
    (%L::uuid, 'punjab', '2026-11-20'::date, '2026-12-05'::date, false, 'pending', 15, true, 'possession', '2026-11-20'::date),
    (%L::uuid, 'sindh', '2026-11-01'::date, '2026-11-03'::date, true, 'pending', 2, true, 'possession', '2026-11-01'::date),
    (%L::uuid, 'khyber_pakhtunkhwa', '2026-11-20'::date, '2026-11-09'::date, true, 'pending', 7, true, 'agreement', '2026-11-02'::date),
    (%L::uuid, 'khyber_pakhtunkhwa', '2026-11-05'::date, '2026-11-12'::date, false, 'pending', 7, true, 'agreement', '2026-11-05'::date),
    (%L::uuid, 'balochistan', '2026-11-01'::date, '2026-11-02'::date, true, 'pending', 3, true, 'agreement', '2026-10-30'::date),
    (%L::uuid, 'balochistan', '2026-11-08'::date, '2026-11-11'::date, false, 'pending', 3, true, 'agreement', '2026-11-08'::date),
    (%L::uuid, 'islamabad', '2026-11-08'::date, '2026-11-09'::date, true, 'pending', 1, false, 'possession', '2026-11-08'::date),
    (%L::uuid, 'gilgit_baltistan', '2026-11-10'::date, '2026-11-11'::date, false, 'pending', 1, false, 'possession', '2026-11-10'::date),
    (%L::uuid, 'azad_kashmir', '2026-11-10'::date, '2026-11-11'::date, false, 'pending', 1, false, 'possession', '2026-11-10'::date)
  $f$, :'l_pb', :'l_pb2', :'l_sd', :'l_kp2', :'l_kp', :'l_bl', :'l_bl2', :'l_ict', :'l_gb', :'l_ajk'),
  'the dashboard lists each pending registration with its rule'
);

select ok(
  (select bool_and(i ?& array['lease_id', 'tenant_name', 'unit_label', 'province', 'start_date',
                               'deadline', 'overdue', 'status'])
   from jsonb_array_elements((:'d')::jsonb -> 'police_pending') i),
  'the existing dashboard keys are kept'
);

-- Submitted registrations stay listed; registered ones leave the list.
update public.leases set police_status = 'submitted' where id = :'l_sd';
update public.leases set police_status = 'registered', police_registered_on = '2026-11-09' where id = :'l_ict';
select tests.authenticate_as(:'owner');
select public.get_dashboard(:'pid', '2026-11-10') as d2 \gset
select tests.clear_authentication();
select is(
  (select i ->> 'status' from jsonb_array_elements((:'d2')::jsonb -> 'police_pending') i
   where i ->> 'lease_id' = :'l_sd'),
  'submitted', 'submitted registrations stay on the dashboard'
);
select is(
  (select count(*)::integer from jsonb_array_elements((:'d2')::jsonb -> 'police_pending') i
   where i ->> 'lease_id' = :'l_ict'),
  0, 'registered tenancies leave the dashboard'
);

select * from finish();
rollback;
