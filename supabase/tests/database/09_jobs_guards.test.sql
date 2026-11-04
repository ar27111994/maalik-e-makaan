-- Daily jobs (late fees, billing), the Data API write limiter, rate-limit
-- primitives and account deletion (including cascades through payments).
begin;
\ir _helpers.psql
select plan(30);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('member@example.com') as member \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_portfolio(:'owner', 'Shared') as shared \gset
select tests.add_member(:'shared', :'member', 'owner');
select tests.create_rental(:'pid', 'punjab', 'Flat') as r1 \gset
select tests.create_rental(:'pid', 'punjab', 'Shop') as r2 \gset
select tests.create_rental(:'pid', 'punjab', 'Room') as r3 \gset

-- Three tenancies (rent 40,000 due on the 5th, grace 5 days) with different
-- late-fee policies. October and November are unpaid.
select tests.create_lease(:'pid', :'r1', '2026-10-01', 40000,
  '{"late_fee_type": "flat", "late_fee_value": 1000}') as l_flat \gset
select tests.create_lease(:'pid', :'r2', '2026-10-01', 40000,
  '{"late_fee_type": "percent", "late_fee_value": 2.5}') as l_pct \gset
select tests.create_lease(:'pid', :'r3', '2026-10-01', 40000,
  '{"late_fee_type": "daily", "late_fee_value": 100, "late_fee_cap": 2500}') as l_daily \gset
select id as daily_oct from public.charges where lease_id = :'l_daily' and period_month = '2026-10-01' \gset
select id as flat_oct from public.charges where lease_id = :'l_flat' and period_month = '2026-10-01' \gset

-- Late fees -----------------------------------------------------------------------
select is(private.assess_late_fees('2026-10-10'), 0, 'no fees within the grace period (5 days late, grace 5)');
select is(private.assess_late_fees('2026-10-11'), 3, 'fees start once the grace period is over');
select set_eq(
  $$select lease_id, amount from public.charges where kind = 'late_fee'$$,
  format($f$values (%L::uuid, 600.00::numeric), (%L, 1000.00), (%L, 1000.00)$f$, :'l_daily', :'l_flat', :'l_pct'),
  'flat 1,000; 2.5 percent of 40,000 = 1,000; daily 100 x 6 days = 600'
);
select is(private.assess_late_fees('2026-10-11'), 0, 'reassessing the same day changes nothing');
select is(private.assess_late_fees('2026-10-20'), 1, 'daily fees grow while unpaid');
select is((select amount from public.charges where related_charge_id = :'daily_oct'), 1500.00, 'daily fee after 15 days');
select is(private.assess_late_fees('2026-11-30'), 4, 'October''s daily fee grows and November''s fees are assessed');
select is((select amount from public.charges where related_charge_id = :'daily_oct'), 2500.00, 'daily fees stop at their cap');
select is(
  (select count(*)::integer from public.charges where related_charge_id = :'flat_oct'), 1,
  'flat fees are charged once per overdue due'
);
update public.charges set voided_at = now(), void_reason = 'Waived'
where kind = 'late_fee' and lease_id = :'l_pct';
select is(private.assess_late_fees('2026-12-31') >= 0, true, 'reassessment after a void runs');
select is(
  (select count(*)::integer from public.charges where kind = 'late_fee' and lease_id = :'l_pct' and voided_at is null), 0,
  'a voided late fee is never recreated'
);

-- Daily job ------------------------------------------------------------------------------
select ok((private.run_daily_jobs('2026-11-03') ->> 'skipped') is null, 'the daily job runs');
select is((private.run_daily_jobs('2026-11-03') ->> 'charges_created')::integer, 0, 'rerunning creates nothing new');

-- Rate-limit primitives -------------------------------------------------------------------
select is(
  (select bool_and(private.hit_rate_limit('test:key', 3, interval '1 minute')) from generate_series(1, 3)),
  true, 'calls within the limit are allowed'
);
select is(private.hit_rate_limit('test:key', 3, interval '1 minute'), false, 'the next call is refused');
select is(private.hit_rate_limit('test:other', 3, interval '1 minute'), true, 'limits are per key');

-- Data API write limiter (pgrst.db_pre_request) ------------------------------------------
select set_config('request.method', 'GET', true);
select set_config('request.jwt.claims', json_build_object('sub', :'owner', 'role', 'authenticated')::text, true);
select lives_ok($$select app.check_request() from generate_series(1, 200)$$, 'reads are never limited');
select set_config('request.method', 'POST', true);
select set_config('request.headers', '{"x-forwarded-for": "203.0.113.7, 10.0.0.1"}', true);
select lives_ok($$select app.check_request() from generate_series(1, 120)$$, '120 writes per minute are allowed');
select throws_ok($$select app.check_request()$$, 'PGRST', null, 'the 121st write in a minute gets HTTP 429');
select set_config('request.jwt.claims', '{"role": "service_role"}', true);
select lives_ok($$select app.check_request() from generate_series(1, 500)$$, 'the service role is exempt');
select is(
  (select hits from private.rate_limit_buckets where bucket_key = 'api_write:ip:203.0.113.7'),
  120, 'writes are also counted per client IP (first X-Forwarded-For hop)'
);
select set_config('request.method', '', true);
select set_config('request.headers', '', true);

-- Account deletion (with money in the portfolio) -----------------------------------------
select tests.authenticate_as(:'owner');
select public.record_payment(:'l_flat', 41000, '2026-11-03', 'cash', gen_random_uuid()) is not null as paid \gset
select tests.authenticate_as_service_role();
select set_eq(
  format('select portfolio_id from public.admin_account_deletion_scope(%L)', :'owner'),
  format('values (%L::uuid)', :'pid'),
  'only portfolios where the user is the sole owner are in scope'
);
select public.admin_delete_account_data(:'owner') as deleted \gset
select tests.clear_authentication();
select is(
  (select count(*)::integer from public.portfolios where id = :'pid'), 0,
  'sole-owned portfolios are deleted with all their data, payments included'
);
select is(
  (select count(*)::integer from public.portfolio_members where portfolio_id = :'shared'), 1,
  'shared portfolios survive; the user''s membership is removed'
);

-- Edge Function rate limits (secret key only) -----------------------------------------
select tests.authenticate_as_service_role();
select is(
  (select bool_and(public.admin_hit_rate_limit('invite_email:u1', 2, 3600)) from generate_series(1, 2)),
  true, 'functions may count hits within their limit'
);
select is(public.admin_hit_rate_limit('invite_email:u1', 2, 3600), false, 'the next hit is refused');
select throws_ok(
  $$select public.admin_hit_rate_limit('k', 1, 7200)$$,
  '22023', 'invalid_rate_limit', 'windows over an hour are rejected (cleanup keeps two hours)'
);
select throws_ok(
  $$select public.admin_hit_rate_limit('', 1, 60)$$,
  '22023', 'invalid_rate_limit', 'empty keys are rejected'
);
select tests.authenticate_as(:'member');
select throws_ok(
  $$select public.admin_hit_rate_limit('k', 1, 60)$$,
  '42501', null, 'signed-in users cannot touch function limits'
);
select tests.clear_authentication();
select is(
  (select hits from private.rate_limit_buckets where bucket_key = 'fn:invite_email:u1'), 3,
  'function limits are namespaced with fn: and count every hit'
);

select * from finish();
rollback;
