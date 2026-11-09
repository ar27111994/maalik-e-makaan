-- Deleting a lease never deletes money records with it (PROJECT.md D-06).
begin;
\ir _helpers.psql
select plan(12);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.add_member(:'pid', :'manager', 'manager');
select tests.create_rental(:'pid', 'punjab', 'Flat') as r1 \gset
select tests.create_rental(:'pid', 'punjab', 'Shop') as r2 \gset
select tests.create_rental(:'pid', 'punjab', 'Room') as r3 \gset
select tests.create_rental(:'pid', 'punjab', 'Annexe') as r4 \gset
select tests.create_rental(:'pid', 'punjab', 'Basement') as r5 \gset

-- Five tenancies with dues generated from their terms (rent and deposit).
select tests.create_lease(:'pid', :'r1', '2026-10-01', 40000, '{"security_deposit": 80000}') as l_mistake \gset
select tests.create_lease(:'pid', :'r2', '2026-10-01', 40000) as l_manual \gset
select tests.create_lease(:'pid', :'r3', '2026-10-01', 40000) as l_voided \gset
select tests.create_lease(:'pid', :'r4', '2026-10-01', 40000) as l_paid \gset
select tests.create_lease(:'pid', :'r5', '2026-10-01', 40000) as l_waived \gset
select ok(
  (select count(*) from public.charges where lease_id = :'l_mistake') >= 2,
  'a new tenancy has generated dues'
);

-- A tenancy entered by mistake can be removed, with the dues its terms made.
select tests.authenticate_as(:'owner');
select lives_ok(
  format($f$delete from public.leases where id = %L$f$, :'l_mistake'),
  'a tenancy with only generated, untouched dues can be deleted'
);
select tests.clear_authentication();
select is_empty(
  format($f$select 1 from public.charges where lease_id = %L$f$, :'l_mistake'),
  'its generated dues go with it'
);

-- A charge someone entered is a money record.
select tests.authenticate_as(:'manager');
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'l_manual', 'damages', '2026-11-10', 5000, 'Broken window');
select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$delete from public.leases where id = %L$f$, :'l_manual'),
  '22023', 'lease_has_records',
  'a tenancy with a charge someone entered cannot be deleted'
);

-- So is a void or a waiver, with its reason.
select public.void_charge(
  (select id from public.charges where lease_id = :'l_voided' and kind = 'rent' order by due_date limit 1),
  'Billed twice'
);
select throws_ok(
  format($f$delete from public.leases where id = %L$f$, :'l_voided'),
  '22023', 'lease_has_records',
  'a tenancy with a voided charge cannot be deleted'
);
select public.waive_charge(
  (select id from public.charges where lease_id = :'l_waived' and kind = 'rent' order by due_date limit 1),
  'Goodwill', 1000
);
select throws_ok(
  format($f$delete from public.leases where id = %L$f$, :'l_waived'),
  '22023', 'lease_has_records',
  'a tenancy with a waived charge cannot be deleted'
);

-- A payment marks its charges paid, so the guard refuses before the
-- payment's own foreign key would.
select public.record_payment(:'l_paid', 40000, '2026-10-05', 'cash', gen_random_uuid());
select throws_ok(
  format($f$delete from public.leases where id = %L$f$, :'l_paid'),
  '22023', 'lease_has_records',
  'a tenancy with a payment cannot be deleted'
);

select tests.clear_authentication();
select is(
  (select count(*)::integer from public.leases where id in (:'l_manual', :'l_voided', :'l_waived', :'l_paid')),
  4, 'every refused tenancy is still there'
);
select is(
  (select count(*)::integer from public.charges where lease_id = :'l_manual' and source = 'manual'),
  1, 'with its records'
);

-- Deleting the portfolio (a system function) still removes everything.
select tests.authenticate_as(:'owner');
select lives_ok(
  format($f$select public.delete_portfolio(%L, 'Test Portfolio')$f$, :'pid'),
  'the owner can still delete the whole portfolio'
);
select tests.clear_authentication();
select is_empty(
  format($f$select 1 from public.leases where portfolio_id = %L$f$, :'pid'),
  'its tenancies are gone'
);
select is_empty(
  format($f$select 1 from public.charges where portfolio_id = %L$f$, :'pid'),
  'and so are their charges'
);

select * from finish();
rollback;
