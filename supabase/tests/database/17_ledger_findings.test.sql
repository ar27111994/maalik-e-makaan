-- Ledger findings (20261107181820_ledger_findings.sql; formal/tla/
-- LedgerPayments, formal/tla/LateFees, formal/tla/RateLimit,
-- formal/smt/overflow.py):
--   F1  charges are edited only through public.update_charge, which takes the
--       lease lock first (no client UPDATE grant or policy on charges);
--   F2  raising a manual charge's amount applies the lease's credit;
--   F3  end_lease releases and voids rent of later months even when paid,
--       and their automatic late fees (LateFees F3), and the freed money is
--       re-applied or kept as credit;
--   LateFees F1  a rent settled within grace loses its automatic fee;
--   RateLimit F5 admin_rate_limit_hit returns the database's Retry-After;
--   A1  record_payment refuses amount + tax_withheld that would overflow
--       payments.applied_amount with invalid_amount, not 22003.
begin;
\ir _helpers.psql
select plan(60);

select set_config('app.today_override', '2026-11-03', true);

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_user('accountant@example.com') as accountant \gset
select tests.create_user('viewer@example.com') as viewer \gset
select tests.create_user('stranger@example.com') as stranger \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.add_member(:'pid', :'manager', 'manager');
select tests.add_member(:'pid', :'accountant', 'accountant');
select tests.add_member(:'pid', :'viewer', 'viewer');

-- ---------------------------------------------------------------------------
-- F1: the shape of the fix
-- ---------------------------------------------------------------------------

select ok(
  not has_any_column_privilege('authenticated', 'public.charges', 'update')
  and not has_table_privilege('authenticated', 'public.charges', 'update'),
  'clients hold no UPDATE privilege on charges'
);
select is(
  (select coalesce(array_agg(p.polname::text order by p.polname), '{}')
   from pg_policy p where p.polrelid = 'public.charges'::regclass and p.polcmd in ('w', '*')),
  '{}'::text[],
  'charges have no UPDATE policy (charges_update is dropped)'
);
select ok(
  (select p.prosecdef and p.provolatile = 'v' and coalesce(p.proconfig @> array['search_path=""'], false)
   from pg_proc p where p.oid = 'public.update_charge(uuid, numeric, date, text)'::regprocedure),
  'update_charge is SECURITY DEFINER, volatile, with an empty search_path'
);
select ok(
  has_function_privilege('authenticated', 'public.update_charge(uuid, numeric, date, text)', 'execute')
  and not has_function_privilege('anon', 'public.update_charge(uuid, numeric, date, text)', 'execute')
  and not exists (
    select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a
    where p.oid = 'public.update_charge(uuid, numeric, date, text)'::regprocedure and a.grantee = 0
  ),
  'update_charge is executable by authenticated only (not PUBLIC or anon)'
);
select ok(
  (select position('private.lock_lease_for_write(' in p.prosrc) between 1
            and position('from public.charges c where c.id = p_charge_id for update' in p.prosrc)
          and position('update public.charges' in p.prosrc)
            < position('private.apply_lease_credit(v_lease_id)' in p.prosrc)
   from pg_proc p where p.oid = 'public.update_charge(uuid, numeric, date, text)'::regprocedure),
  'update_charge locks the lease (portfolio key, lease) before the charge, and applies credit after the update'
);

-- Fixture: lease from 2026-09-01 (rent 45,000): Sep, Oct and Nov rent are due.
select tests.create_rental(:'pid') as r1 \gset
select tests.create_lease(:'pid', :'r1', '2026-09-01', 45000) as lease \gset
select id as sep from public.charges where lease_id = :'lease' and period_month = '2026-09-01' \gset
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'lease', 'maintenance', '2026-11-20', 3000, 'Plumber') returning id as manual \gset
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'lease', 'damages', '2026-11-25', 800, 'Window') returning id as dmg \gset

-- ---------------------------------------------------------------------------
-- F1: who may edit
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'owner');
select is((public.update_charge(:'manual', null, null, 'Plumber, kitchen')).description, 'Plumber, kitchen',
  'an owner edits a charge''s note');
select tests.authenticate_as(:'manager');
select is((public.update_charge(:'manual', null, '2026-11-22')).due_date, '2026-11-22'::date,
  'a manager edits a charge''s due date');
select tests.authenticate_as(:'accountant');
select is((public.update_charge(:'manual', 3500)).amount, 3500.00::numeric,
  'an accountant edits a manual charge''s amount');
select throws_ok(
  format($f$update public.charges set description = 'Direct' where id = %L$f$, :'manual'),
  '42501', null, 'a direct UPDATE of charges is refused'
);
select tests.authenticate_as(:'viewer');
select throws_ok(
  format($f$select public.update_charge(%L, 4000)$f$, :'manual'),
  '42501', 'forbidden', 'a viewer cannot edit charges'
);
select tests.authenticate_as(:'stranger');
select throws_ok(
  format($f$select public.update_charge(%L, null, null, 'Mine')$f$, :'manual'),
  '42501', 'forbidden', 'a non-member cannot edit another landlord''s charge'
);
select throws_ok(
  $$select public.update_charge(gen_random_uuid(), 100)$$,
  '42501', 'forbidden', 'a missing charge is reported like a foreign one'
);
select tests.authenticate_as_anon();
select throws_ok(
  format($f$select public.update_charge(%L, 4000)$f$, :'manual'),
  '42501', null, 'anon cannot call update_charge'
);
select tests.clear_authentication();
select is(
  (select row(amount, due_date, description)::text from public.charges where id = :'manual'),
  row(3500.00::numeric, '2026-11-22'::date, 'Plumber, kitchen'::text)::text,
  'only the authorised edits were applied'
);

-- ---------------------------------------------------------------------------
-- F1: the rules client edits had, now in the RPC
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'manager');
select throws_ok(
  format($f$select public.update_charge(%L, 1)$f$, :'sep'),
  '22023', 'charge_not_editable', 'automatic rent cannot be re-priced by hand'
);
select is(
  (select row(c.amount, c.due_date, c.description)::text
   from public.update_charge(:'sep', 45000, '2026-09-07', 'September') c),
  row(45000.00::numeric, '2026-09-07'::date, 'September'::text)::text,
  'rent keeps its amount, but its due date and note can change'
);
select is((public.update_charge(:'manual')).amount, 3500.00::numeric,
  'null arguments keep every value');
select is((public.update_charge(:'manual', null, null, '   ')).description, null,
  'a blank note clears it');
select throws_ok(
  format($f$select public.update_charge(%L, 0)$f$, :'manual'),
  '22023', 'invalid_amount', 'the amount must be positive'
);
select throws_ok(
  format($f$select public.update_charge(%L, 10.005)$f$, :'manual'),
  '22023', 'invalid_amount', 'the amount has at most two decimals'
);
select throws_ok(
  format($f$select public.update_charge(%L, 1000000000000)$f$, :'manual'),
  '22023', 'invalid_amount', 'the amount fits numeric(14,2)'
);
select throws_ok(
  format($f$select public.update_charge(%L, null, null, repeat('x', 201))$f$, :'manual'),
  '23514', null, 'the note keeps its length check'
);
select public.void_charge(:'dmg', 'Repaired by tenant') is not null as voided \gset
select throws_ok(
  format($f$select public.update_charge(%L, 1)$f$, :'dmg'),
  '22023', 'charge_voided', 'a voided charge is frozen'
);
select throws_ok(
  format($f$select public.update_charge(%L, null, null, 'Later')$f$, :'dmg'),
  '22023', 'charge_voided', 'also its note'
);
-- Pay part of the manual charge, waive some more: the amount cannot fall
-- below what was settled.
select public.record_payment(:'lease', 1000, '2026-11-03', 'cash', gen_random_uuid(), null, null, 0, null,
  array[:'manual']::uuid[]) is not null as paid \gset
select public.waive_charge(:'manual', 'Discount', 500) is not null as waived \gset
select throws_ok(
  format($f$select public.update_charge(%L, 1499.99)$f$, :'manual'),
  '22023', 'invalid_amount', 'the amount cannot fall below what was paid and waived'
);
select is((public.update_charge(:'manual', 1500)).outstanding, 0.00::numeric,
  'it can fall to exactly what was paid and waived');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- F2: raising a manual charge's amount applies the lease's credit
-- ---------------------------------------------------------------------------

-- Lease from 2026-11-01 (rent 1,000), a manual charge of 500; a payment of
-- 2,000 pays both and leaves 500 of credit.
select tests.create_rental(:'pid') as r2 \gset
select tests.create_lease(:'pid', :'r2', '2026-11-01', 1000) as credit_lease \gset
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'credit_lease', 'maintenance', '2026-11-10', 500, 'Repair') returning id as repair \gset
select tests.authenticate_as(:'accountant');
select (public.record_payment(:'credit_lease', 2000, '2026-11-03', 'cash', gen_random_uuid())
        -> 'payment' ->> 'id') as credit_payment \gset
select is(
  (select unallocated_amount from public.payments where id = :'credit_payment'), 500.00::numeric,
  'the overpayment leaves 500 of credit'
);
select is((public.update_charge(:'repair', 800)).outstanding, 0.00::numeric,
  'raising the charge to 800 settles it from the credit at once (F2)');
select is(
  (select unallocated_amount from public.payments where id = :'credit_payment'), 200.00::numeric,
  'and the credit falls to 200'
);
select is((public.update_charge(:'repair', 1100)).outstanding, 100.00::numeric,
  'raising it beyond the credit uses all of it and leaves the rest open');
select is(
  (select unallocated_amount from public.payments where id = :'credit_payment'), 0.00::numeric,
  'no credit is left next to the open due'
);
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- F3: end_lease releases and voids later rent, paid or not
-- ---------------------------------------------------------------------------

-- The replayed counterexample: lease from 2026-10-01 (rent 1,000); 1,500 paid
-- on 15 October; the November sync spends the 500 credit on November's rent;
-- the tenant moved out on 31 October.
select set_config('app.today_override', '2026-10-15', true);
select tests.create_rental(:'pid') as r3 \gset
select tests.create_lease(:'pid', :'r3', '2026-10-01', 1000) as moved \gset
select tests.authenticate_as(:'owner');
select (public.record_payment(:'moved', 1500, '2026-10-15', 'cash', gen_random_uuid())
        -> 'payment' ->> 'id') as moved_payment \gset
select set_config('app.today_override', '2026-11-03', true);
select public.sync_portfolio_billing(:'pid') >= 0 as synced \gset
select is(
  (select paid_amount from public.charges where lease_id = :'moved' and period_month = '2026-11-01'),
  500.00::numeric,
  'the sync paid half of November''s rent from the credit'
);
select is((public.end_lease(:'moved', '2026-10-31', 'tenant_moved_out')).status, 'ended'::public.lease_status,
  'the lease ends');
select is(
  (select row(voided_at is not null, paid_amount, void_reason)::text
   from public.charges where lease_id = :'moved' and period_month = '2026-11-01'),
  row(true, 0.00::numeric, 'Lease ended'::text)::text,
  'November''s rent is released and voided although it had been paid (F3)'
);
select is(
  (select count(*)::integer from public.payment_allocations a
   join public.charges c on c.id = a.charge_id
   where c.lease_id = :'moved' and c.period_month = '2026-11-01'),
  0, 'its allocations are gone'
);
select is(
  (select row(allocated_amount, unallocated_amount)::text from public.payments where id = :'moved_payment'),
  row(1000.00::numeric, 500.00::numeric)::text,
  'the 500 stays on the lease as credit (only October is paid)'
);
select is(
  (select count(*)::integer from public.charges
   where lease_id = :'moved' and voided_at is null and period_month > '2026-10-01'),
  0, 'the ended lease has no live rent after the move-out month'
);

-- Freed money pays the lease's other open dues first: lease from 2026-09-01
-- (rent 1,000), November paid in advance by choice, September and October
-- open; moved out in September.
select tests.create_rental(:'pid') as r4 \gset
select tests.create_lease(:'pid', :'r4', '2026-09-01', 1000) as early \gset
select id as early_nov from public.charges where lease_id = :'early' and period_month = '2026-11-01' \gset
select (public.record_payment(:'early', 1000, '2026-11-03', 'cash', gen_random_uuid(), null, null, 0, null,
        array[:'early_nov']::uuid[]) -> 'payment' ->> 'id') as early_payment \gset
select is((public.end_lease(:'early', '2026-09-20', 'tenant_moved_out')).status, 'ended'::public.lease_status,
  'a lease with later rent paid in advance ends');
select results_eq(
  format($f$select period_month, voided_at is not null, paid_amount from public.charges
            where lease_id = %L and kind = 'rent' order by period_month$f$, :'early'),
  $$values ('2026-09-01'::date, false, 1000.00::numeric), ('2026-10-01', true, 0.00), ('2026-11-01', true, 0.00)$$,
  'unpaid October and paid November are voided; the released 1,000 pays September'
);
select is(
  (select row(allocated_amount, unallocated_amount)::text from public.payments where id = :'early_payment'),
  row(1000.00::numeric, 0.00::numeric)::text,
  'the payment is fully allocated again, to September'
);
select tests.clear_authentication();

select is(
  (select count(*)::integer from public.charges c
   left join (select charge_id, sum(amount) t from public.payment_allocations group by charge_id) a
     on a.charge_id = c.id
   where c.portfolio_id = :'pid' and c.paid_amount <> coalesce(a.t, 0)),
  0, 'every charge''s paid amount is the sum of its allocations'
);
select is(
  (select count(*)::integer from public.payments p
   left join (select payment_id, sum(amount) t from public.payment_allocations group by payment_id) a
     on a.payment_id = p.id
   where p.portfolio_id = :'pid' and p.allocated_amount <> coalesce(a.t, 0)),
  0, 'every payment''s allocated amount is the sum of its allocations'
);
select ok(
  (select obj_description('public.end_lease(uuid, date, public.lease_end_reason)'::regprocedure, 'pg_proc')
     ~ 'releases and voids later rent'),
  'end_lease''s comment states the new behaviour'
);

-- ---------------------------------------------------------------------------
-- LateFees F3: end_lease also releases and voids the late fees of later rent
-- ---------------------------------------------------------------------------

-- Lease from 2026-10-01 (rent 1,000 due on the 5th, 5 days' grace, 100 a day
-- late); on 12 November both October and November are overdue and carry
-- fees. 50 is paid on November's fee by choice; the tenant moved out on
-- 31 October.
select set_config('app.today_override', '2026-11-12', true);
select tests.create_rental(:'pid') as r5 \gset
select tests.create_lease(:'pid', :'r5', '2026-10-01', 1000,
  '{"late_fee_type": "daily", "late_fee_value": 100}') as fees_lease \gset
select private.assess_late_fees(:'fees_lease', '2026-11-12') as fees_posted \gset
select id as oct_rent from public.charges where lease_id = :'fees_lease' and kind = 'rent' and period_month = '2026-10-01' \gset
select id as nov_fee from public.charges where lease_id = :'fees_lease' and kind = 'late_fee' and period_month = '2026-11-01' \gset
select is(:fees_posted, 2, 'the job posted a fee on October''s and on November''s rent');
select tests.authenticate_as(:'manager');
select (public.record_payment(:'fees_lease', 50, '2026-11-12', 'cash', gen_random_uuid(), null, null, 0, null,
        array[:'nov_fee']::uuid[]) -> 'payment' ->> 'id') as fee_payment \gset
select is((public.end_lease(:'fees_lease', '2026-10-31', 'tenant_moved_out')).status, 'ended'::public.lease_status,
  'the lease with fees ends');
select tests.clear_authentication();
select results_eq(
  format($f$select kind::text, period_month, voided_at is not null, paid_amount from public.charges
            where lease_id = %L order by period_month, kind$f$, :'fees_lease'),
  $$values ('late_fee', '2026-10-01'::date, false, 0.00::numeric), ('rent', '2026-10-01', false, 50.00),
           ('late_fee', '2026-11-01', true, 0.00), ('rent', '2026-11-01', true, 0.00)$$,
  'November''s rent and its partly paid fee are released and voided; the 50 pays October; October''s fee stays'
);
select is(
  (select row(allocated_amount, unallocated_amount)::text from public.payments where id = :'fee_payment'),
  row(50.00::numeric, 0.00::numeric)::text,
  'the released 50 is allocated again'
);

-- ---------------------------------------------------------------------------
-- LateFees F1: a rent paid within grace, recorded after the fee was posted
-- ---------------------------------------------------------------------------

-- Leases from 2026-10-01 (rent 1,000 due on 5 October, grace to 10 October,
-- 100 a day late); on 12 October the job has posted a 700 fee on each.
select set_config('app.today_override', '2026-10-12', true);
create temporary table grace_case (label text primary key, lease uuid, rent uuid, fee uuid) on commit drop;
grant select on grace_case to authenticated;
do $$
declare
  v_label text;
  v_lease uuid;
begin
  foreach v_label in array array['in_grace', 'overpaid', 'after_grace', 'fee_paid'] loop
    v_lease := tests.create_lease(
      (select portfolio_id from public.leases limit 1),
      tests.create_rental((select portfolio_id from public.leases limit 1)),
      '2026-10-01', 1000, '{"late_fee_type": "daily", "late_fee_value": 100}'
    );
    perform private.assess_late_fees(v_lease, '2026-10-12');
    insert into grace_case
    select v_label, v_lease,
           (select id from public.charges where lease_id = v_lease and kind = 'rent'),
           (select id from public.charges where lease_id = v_lease and kind = 'late_fee');
  end loop;
end
$$;
select is(
  (select array_agg(c.amount order by g.label) from grace_case g join public.charges c on c.id = g.fee),
  array[700.00, 700.00, 700.00, 700.00]::numeric[],
  'each lease carries a 700 fee for October'
);
select tests.authenticate_as(:'accountant');
-- Paid on 9 October (within grace), in full.
select public.record_payment((select lease from grace_case where label = 'in_grace'), 1000, '2026-10-09', 'cash',
  gen_random_uuid()) is not null as paid_in_grace \gset
-- Paid on 10 October (the last day of grace), 1,500: the rest first went to the fee.
select (public.record_payment((select lease from grace_case where label = 'overpaid'), 1500, '2026-10-10', 'cash',
  gen_random_uuid()) -> 'payment' ->> 'id') as overpaid_payment \gset
-- Paid on 11 October: after the grace period.
select public.record_payment((select lease from grace_case where label = 'after_grace'), 1000, '2026-10-11', 'cash',
  gen_random_uuid()) is not null as paid_late \gset
-- 100 of the fee paid first (by choice, on 12 October), then the rent within grace.
select public.record_payment((select lease from grace_case where label = 'fee_paid'), 100, '2026-10-12', 'cash',
  gen_random_uuid(), null, null, 0, null, array[(select fee from grace_case where label = 'fee_paid')]) is not null
  as fee_part \gset
select public.record_payment((select lease from grace_case where label = 'fee_paid'), 1000, '2026-10-09', 'cash',
  gen_random_uuid()) is not null as paid_in_grace_after_fee \gset
select tests.clear_authentication();
select results_eq(
  $$select g.label, f.voided_at is not null, f.paid_amount, r.outstanding
    from grace_case g join public.charges f on f.id = g.fee join public.charges r on r.id = g.rent
    order by g.label$$,
  $$values ('after_grace', false, 0.00::numeric, 0.00::numeric),
           ('fee_paid', false, 100.00, 0.00),
           ('in_grace', true, 0.00, 0.00),
           ('overpaid', true, 0.00, 0.00)$$,
  'the fee of a rent settled within grace is voided; after grace, or once partly paid, it stays'
);
select is(
  (select f.void_reason from grace_case g join public.charges f on f.id = g.fee where g.label = 'in_grace'),
  'Rent paid within the grace period',
  'the voided fee says why'
);
select is(
  (select row(allocated_amount, unallocated_amount)::text from public.payments where id = :'overpaid_payment'),
  row(1000.00::numeric, 500.00::numeric)::text,
  'what the payment had put on the fee is released and stays as credit'
);
select is(
  (select count(*)::integer from public.payment_allocations a join grace_case g on g.fee = a.charge_id
   where g.label in ('in_grace', 'overpaid')),
  0, 'no allocation is left on a voided fee'
);

-- ---------------------------------------------------------------------------
-- RateLimit F5: the database's Retry-After for Edge Functions
-- ---------------------------------------------------------------------------

select ok(
  has_function_privilege('service_role', 'public.admin_rate_limit_hit(text, integer, integer)', 'execute')
  and not has_function_privilege('authenticated', 'public.admin_rate_limit_hit(text, integer, integer)', 'execute')
  and not has_function_privilege('anon', 'public.admin_rate_limit_hit(text, integer, integer)', 'execute'),
  'admin_rate_limit_hit is for the service role only'
);
-- now() is fixed for the transaction, so this is the wait the function sees.
select private.rate_limit_retry_after(interval '600 seconds') as db_wait \gset
select tests.authenticate_as_service_role();
select is(
  public.admin_rate_limit_hit('delete_account:user:f5', 1, 600),
  jsonb_build_object('allowed', true, 'retry_after_seconds', :db_wait),
  'an admitted hit reports the wait to the end of its window, from the database''s now()'
);
select is(
  public.admin_rate_limit_hit('delete_account:user:f5', 1, 600),
  jsonb_build_object('allowed', false, 'retry_after_seconds', :db_wait),
  'a refused hit reports the same wait'
);
select tests.clear_authentication();
select ok(
  (select hits = 2 from private.rate_limit_buckets where bucket_key = 'fn:delete_account:user:f5'),
  'the hits are counted under the fn: prefix, like admin_hit_rate_limit'
);
select throws_ok(
  $$select public.admin_rate_limit_hit('k', 1, 3601)$$,
  '22023', 'invalid_rate_limit', 'windows over an hour are refused'
);
select set_config('app.today_override', '2026-11-03', true);

-- ---------------------------------------------------------------------------
-- A1: amount + tax withheld must fit payments.applied_amount
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$select public.record_payment(%L, 999999999999.99, '2026-11-03', 'cash', gen_random_uuid(),
            null, null, 999999999999.99)$f$, :'lease'),
  '22023', 'invalid_amount', 'the largest amount and tax together are refused with invalid_amount (A1)'
);
select throws_ok(
  format($f$select public.record_payment(%L, 500000000000, '2026-11-03', 'cash', gen_random_uuid(),
            null, null, 500000000000)$f$, :'lease'),
  '22023', 'invalid_amount', 'the Z3 counterexample (500,000,000,000 + 500,000,000,000) is refused'
);
select is(
  (public.record_payment(:'lease', 500000000000, '2026-11-03', 'cash', gen_random_uuid(),
     null, null, 499999999999.99) -> 'payment' ->> 'applied_amount')::numeric,
  999999999999.99::numeric,
  'amount + tax of exactly 999,999,999,999.99 is accepted'
);
select tests.clear_authentication();

select * from finish();
rollback;
