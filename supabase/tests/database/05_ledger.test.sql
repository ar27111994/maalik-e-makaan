-- Ledger engine: allocation, idempotency, validation, withholding tax,
-- credit, voids, waivers, deposits and receipt numbering. Ends with global
-- invariant checks over every row the suite produced.
--
-- Fixture: lease from 2026-09-01, rent 45,000 due on the 5th, deposit 90,000
-- (due on the start date). "Today" is frozen at 2026-11-03, so the open dues
-- are: deposit 90,000 (09-01), Sep 45,000 (09-05), Oct 45,000, Nov 45,000.
begin;
\ir _helpers.psql
select plan(53);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_user('stranger@example.com') as stranger \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.add_member(:'pid', :'manager', 'manager');
select tests.create_rental(:'pid') as r \gset
select tests.create_lease(
  :'pid', :'r', '2026-09-01', 45000,
  '{"id": "01a1a2d1-0000-7000-8000-000000000001", "security_deposit": 90000}'
) as lease \gset
select id as sep from public.charges where lease_id = :'lease' and period_month = '2026-09-01' \gset
select id as oct from public.charges where lease_id = :'lease' and period_month = '2026-10-01' \gset
select id as nov from public.charges where lease_id = :'lease' and period_month = '2026-11-01' \gset

select tests.authenticate_as(:'manager');

-- Allocation ---------------------------------------------------------------------
select public.record_payment(:'lease', 100000, '2026-09-02', 'cash', '00000000-0000-4000-8000-0000000000a1') as p1 \gset
select is((:'p1')::jsonb -> 'payment' ->> 'receipt_number', 'MM-2026-00001', 'receipts are numbered per portfolio and year');
select set_eq(
  format($f$select c.kind::text, c.period_month, a.amount
            from public.payment_allocations a join public.charges c on c.id = a.charge_id
            where a.payment_id = %L$f$, (:'p1')::jsonb -> 'payment' ->> 'id'),
  $$values ('security_deposit', null::date, 90000.00::numeric), ('rent', '2026-09-01', 10000.00)$$,
  'payments settle the oldest dues first (the deposit is due on move-in)'
);
select is((:'p1')::jsonb ->> 'lease_outstanding', '125000.00', 'the response reports the remaining balance');

-- Explicit allocation: November first, the remainder goes to the oldest due.
select public.record_payment(
  :'lease', 50000, '2026-11-02', 'raast', '00000000-0000-4000-8000-0000000000a2', 'RAAST-778', null, 0, null,
  array[:'nov']::uuid[]
) as p2 \gset
select set_eq(
  format($f$select c.period_month, a.amount
            from public.payment_allocations a join public.charges c on c.id = a.charge_id
            where a.payment_id = %L$f$, (:'p2')::jsonb -> 'payment' ->> 'id'),
  $$values ('2026-11-01'::date, 45000.00::numeric), ('2026-09-01', 5000.00)$$,
  'chosen dues are paid first, the rest goes to the oldest'
);
select throws_ok(
  format($f$select public.record_payment(%L, 10, '2026-11-02', 'cash', gen_random_uuid(), null, null, 0, null, array[%L]::uuid[])$f$,
         :'lease', '01a1a2d1-ffff-7000-8000-000000000000'),
  '22023', 'invalid_charge_selection', 'unknown or foreign charges cannot be targeted'
);
select throws_ok(
  format($f$select public.record_payment(%L, 10, '2026-11-02', 'cash', gen_random_uuid(), null, null, 0, null, array[%L]::uuid[])$f$,
         :'lease', :'nov'),
  '22023', 'invalid_charge_selection', 'settled dues cannot be targeted'
);

-- Idempotency ----------------------------------------------------------------------
select is(
  public.record_payment(:'lease', 100000, '2026-09-02', 'cash', '00000000-0000-4000-8000-0000000000a1')
    -> 'payment' ->> 'receipt_number',
  'MM-2026-00001', 'retrying with the same idempotency key returns the original payment'
);
select is((select count(*)::integer from public.payments), 2, 'retries never create duplicate payments');
select throws_ok(
  format($f$select public.record_payment(%L, 999, '2026-09-02', 'cash', '00000000-0000-4000-8000-0000000000a1')$f$, :'lease'),
  '22023', 'idempotency_key_reused', 'a key reused for a different payment is rejected'
);
select throws_ok(
  format($f$select public.record_payment(%L, 999, '2026-09-02', 'cash', null)$f$, :'lease'),
  '22023', 'idempotency_key_required', 'an idempotency key is mandatory'
);

-- Validation ------------------------------------------------------------------------
select throws_ok(format($f$select public.record_payment(%L, 0, '2026-11-02', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_amount', 'zero amounts are rejected');
select throws_ok(format($f$select public.record_payment(%L, -5, '2026-11-02', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_amount', 'negative amounts are rejected');
select throws_ok(format($f$select public.record_payment(%L, 10.005, '2026-11-02', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_amount', 'fractions of a paisa are rejected');
select throws_ok(format($f$select public.record_payment(%L, 1e13, '2026-11-02', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_amount', 'amounts beyond numeric(14,2) are rejected');
select throws_ok(format($f$select public.record_payment(%L, 100, '2026-11-05', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_date', 'payments cannot be dated more than a day ahead');
select throws_ok(format($f$select public.record_payment(%L, 100, '2024-01-01', 'cash', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_date', 'payments long before the tenancy are rejected');
select throws_ok(format($f$select public.record_payment(%L, 100, '2026-11-02', 'deposit_adjustment', gen_random_uuid())$f$, :'lease'),
  '22023', 'invalid_method', 'deposit adjustments go through apply_deposit');
select throws_ok(format($f$select public.record_payment(%L, 100, '2026-11-02', 'cash', gen_random_uuid(), null, null, 101)$f$, :'lease'),
  '22023', 'invalid_tax_withheld', 'tax withheld cannot exceed the cash received');
select throws_ok(
  format($f$select public.record_payment(%L, 100, '2026-11-02', 'cash', gen_random_uuid(), 'ref' || chr(8238))$f$, :'lease'),
  '23514', null, 'references with bidi overrides are rejected'
);

-- Withholding tax (s.155): cash + tax settle the gross due -----------------------------
select public.record_payment(
  :'lease', 28500, '2026-11-03', 'bank_transfer', '00000000-0000-4000-8000-0000000000a3',
  'IBFT-1', null, 1500, 'CPR-2026-11'
) as p3 \gset
select is((:'p3')::jsonb -> 'payment' ->> 'applied_amount', '30000.00', 'cash plus tax withheld is applied to dues');
select is(
  (select outstanding from public.charges where id = :'sep'), 0.00,
  'the withholding payment settles September in full'
);
select is(
  (select outstanding from public.charges where id = :'oct'), 45000.00,
  'October is still open'
);

-- Credit ------------------------------------------------------------------------------
select public.record_payment(:'lease', 60000, '2026-11-03', 'jazzcash', '00000000-0000-4000-8000-0000000000a4') as p4 \gset
select is((:'p4')::jsonb ->> 'lease_credit', '15000.00', 'overpayments become credit');
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'lease', 'electricity', '2026-11-10', 6200, 'LESCO Oct') returning id as elec \gset
select is(
  (select outstanding from public.charges where id = :'elec'), 0.00,
  'credit is applied to a new manual charge immediately'
);
set local app.today_override = '2026-12-01';
reset role;
select private.sync_lease_billing(:'lease') as created \gset
select tests.authenticate_as(:'manager');
select id as dec from public.charges where lease_id = :'lease' and period_month = '2026-12-01' \gset
select is(
  (select paid_amount from public.charges where id = :'dec'), 8800.00,
  'remaining credit is applied to the next generated rent'
);
set local app.today_override = '2026-11-03';

-- Voiding -------------------------------------------------------------------------------
select throws_ok(
  format($f$select public.void_payment(%L, '   ')$f$, (:'p4')::jsonb -> 'payment' ->> 'id'),
  '22023', 'reason_required', 'voiding requires a reason'
);
select public.void_payment(((:'p4')::jsonb -> 'payment' ->> 'id')::uuid, 'Entered twice') as v4 \gset
select ok((:'v4')::jsonb -> 'payment' ->> 'voided_at' is not null, 'payments are voided, not deleted');
select is(
  (select count(*)::integer from public.payment_allocations where payment_id = ((:'p4')::jsonb -> 'payment' ->> 'id')::uuid),
  0, 'voiding removes the allocations'
);
select results_eq(
  format($f$select outstanding from public.charges where id in (%L, %L, %L) order by due_date$f$, :'oct', :'elec', :'dec'),
  $$values (45000.00::numeric), (6200.00), (45000.00)$$,
  'dues paid by the voided payment are open again'
);
select throws_ok(
  format($f$select public.void_payment(%L, 'Again')$f$, (:'p4')::jsonb -> 'payment' ->> 'id'),
  '22023', 'already_voided', 'a payment can be voided once'
);

-- Waiving and voiding charges --------------------------------------------------------------
select is((public.waive_charge(:'elec', 'Meter fault', 1200)).outstanding, 5000.00, 'part of a charge can be waived');
select throws_ok(
  format($f$select public.waive_charge(%L, 'Too much', 99999)$f$, :'elec'),
  '22023', 'amount_exceeds_outstanding', 'cannot waive more than is owed'
);
select is((public.waive_charge(:'elec', 'Settled verbally')).outstanding, 0.00, 'the remainder can be waived in full');
select throws_ok(
  format($f$select public.void_charge(%L, 'Mistake')$f$, :'sep'),
  '22023', 'charge_has_payments', 'charges with payments cannot be voided'
);
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount)
values (:'pid', :'lease', 'damages', '2026-11-20', 3000) returning id as dmg \gset
select ok((public.void_charge(:'dmg', 'Repaired by tenant')).voided_at is not null, 'unpaid charges can be voided');
select throws_ok(
  format($f$update public.charges set amount = 1 where id = %L$f$, :'dmg'),
  '22023', 'charge_voided', 'voided charges are frozen'
);

-- Deposits ---------------------------------------------------------------------------------
-- Open non-deposit dues now: Oct 45,000 and Dec 45,000.
select is((public.get_deposit_position(:'lease') ->> 'held')::numeric, 90000.00, 'the full deposit is held');
select throws_ok(
  format($f$select public.apply_deposit(%L, 90001, '2026-11-03', gen_random_uuid())$f$, :'lease'),
  '22023', 'insufficient_deposit', 'cannot apply more than the deposit held'
);
select public.apply_deposit(:'lease', 10000, '2026-11-03', '00000000-0000-4000-8000-0000000000b1', 'Settle October') as dep \gset
select is((:'dep')::jsonb -> 'payment' ->> 'method', 'deposit_adjustment', 'deposit use is recorded as an adjustment');
select is((public.get_deposit_position(:'lease') ->> 'held')::numeric, 80000.00, 'applying the deposit reduces what is held');
select ok((public.waive_charge(:'dec', 'Waived by agreement')).outstanding = 0, 'December waived');
select throws_ok(
  format($f$select public.apply_deposit(%L, 40000, '2026-11-03', gen_random_uuid())$f$, :'lease'),
  '22023', 'amount_exceeds_outstanding', 'cannot apply more of the deposit than is owed'
);
select throws_ok(
  format($f$select public.refund_deposit(%L, 80001, '2026-11-03', 'cash')$f$, :'lease'),
  '22023', 'insufficient_deposit', 'cannot refund more than is held'
);
select is((public.refund_deposit(:'lease', 30000, '2026-11-03', 'bank_transfer', 'IBFT-9')).amount, 30000.00,
  'part of the deposit is refunded');
select is((public.get_deposit_position(:'lease') ->> 'held')::numeric, 50000.00, 'held = received - applied - refunded');
select tests.authenticate_as(:'stranger');
select throws_ok(
  format($f$select public.get_deposit_position(%L)$f$, :'lease'),
  '42501', 'forbidden', 'outsiders cannot read a deposit position'
);
select throws_ok(
  $$select public.get_deposit_position('00000000-0000-4000-8000-00000000dead')$$,
  '42501', 'forbidden', 'a missing lease looks exactly like someone else''s'
);
select tests.authenticate_as(:'manager');
select throws_ok(
  format($f$select public.void_payment(%L, 'Bounced cheque')$f$, (:'p1')::jsonb -> 'payment' ->> 'id'),
  '22023', 'deposit_already_used', 'cannot void the money that funded a deposit already used'
);
select throws_ok(
  $$select public.void_deposit_refund((select id from public.deposit_refunds limit 1), 'Bounced')$$,
  '42501', 'forbidden', 'only owners void refunds'
);

-- Receipt numbering is gapless even when a payment fails ------------------------------------
select public.record_payment(:'lease', 100, '2026-11-03', 'cash', gen_random_uuid()) -> 'payment' ->> 'receipt_number' as rn \gset
select is(:'rn'::text, 'MM-2026-00006', 'the next receipt continues the sequence without gaps');

-- Global invariants --------------------------------------------------------------------------
select tests.clear_authentication();
select is_empty(
  $$select c.id from public.charges c
    left join (select charge_id, sum(amount) total from public.payment_allocations group by charge_id) a
      on a.charge_id = c.id
    where c.paid_amount <> coalesce(a.total, 0)$$,
  'every charge''s paid_amount equals the sum of its allocations'
);
select is_empty(
  $$select p.id from public.payments p
    left join (select payment_id, sum(amount) total from public.payment_allocations group by payment_id) a
      on a.payment_id = p.id
    where p.allocated_amount <> coalesce(a.total, 0)$$,
  'every payment''s allocated_amount equals the sum of its allocations'
);
select is_empty(
  $$select id from public.charges where paid_amount + waived_amount > amount$$,
  'no charge is ever overpaid'
);

select * from finish();
rollback;
