#!/usr/bin/env bash
# Stress & performance test for the database layer.
#
# Seeds a large portfolio ("Plaza": 300 units/tenants/leases with 24 months of
# billing ≈ 7.5k charges and 6k payments) plus 30 small portfolios, then:
#   * times the hot read RPCs as an authenticated member (RLS active) against
#     latency budgets;
#   * checks the planner uses indexes for the hottest access paths;
#   * runs pgbench: parallel record_payment calls from 200 distinct members.
#
#   tool/db/stress_test.sh            # seed + measure
#   STRESS_SECONDS=30 tool/db/stress_test.sh
#
# Budgets are deliberately generous so CI runners pass; regressions of an
# order of magnitude (e.g. a lost index or a per-row RLS function) fail.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export MM_TEST_DB="${MM_TEST_DB}_stress"
SECONDS_TO_RUN="${STRESS_SECONDS:-10}"
"$ROOT/tool/db/reset.sh" >/dev/null

psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" "$@"; }

echo "▸ Seeding (this takes a little while)"
SEED_START=$(date +%s)
psql_db <<'SQL'
set app.today_override = '2026-11-03';
create schema bench;
grant usage on schema bench to authenticated;

-- 1 owner + 200 managers for the big portfolio.
insert into auth.users (id, email, email_confirmed_at)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'user' || n || '@example.com', now()
from generate_series(0, 230) n;

create table bench.users (n integer primary key, id uuid not null);
insert into bench.users select n, ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(1, 200) n;

insert into public.portfolios (id, name, created_by)
values ('01a1a2e0-0000-7000-8000-000000000000', 'Plaza', '00000000-0000-4000-8000-000000000000');
insert into public.portfolio_members (portfolio_id, user_id, role)
values ('01a1a2e0-0000-7000-8000-000000000000', '00000000-0000-4000-8000-000000000000', 'owner');
insert into public.portfolio_members (portfolio_id, user_id, role)
select '01a1a2e0-0000-7000-8000-000000000000', id, 'manager' from bench.users;

insert into public.properties (id, portfolio_id, name, city, province)
values ('01a1a2e1-0000-7000-8000-000000000000', '01a1a2e0-0000-7000-8000-000000000000', 'Plaza Tower', 'Karachi', 'sindh');
insert into public.units (portfolio_id, property_id, label, asking_rent)
select '01a1a2e0-0000-7000-8000-000000000000', '01a1a2e1-0000-7000-8000-000000000000', 'Unit ' || n, 30000 + n * 100
from generate_series(1, 320) n;
insert into public.tenants (portfolio_id, full_name, phone)
select '01a1a2e0-0000-7000-8000-000000000000', 'Tenant ' || n, '+92300' || lpad(n::text, 7, '0')
from generate_series(1, 300) n;

-- 300 leases since 2024-11-01: each insert generates 25 rent charges.
insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, security_deposit)
select u.portfolio_id, u.id, t.id, '2024-11-01', 30000 + u.rn * 100, 60000
from (select id, portfolio_id, row_number() over (order by label) rn from public.units) u
join (select id, row_number() over (order by full_name) rn from public.tenants) t on t.rn = u.rn
where u.rn <= 300;

create table bench.leases (n integer primary key, id uuid not null);
insert into bench.leases select row_number() over (order by id), id from public.leases;
grant select on bench.users, bench.leases to authenticated;

-- 30 small portfolios with 10 leases each (RLS selectivity).
do $$
declare
  v_owner uuid;
  v_pid uuid;
  v_prop uuid;
begin
  for i in 1 .. 30 loop
    v_owner := ('00000000-0000-4000-8000-' || lpad((200 + i)::text, 12, '0'))::uuid;
    insert into public.portfolios (name, created_by) values ('Small ' || i, v_owner) returning id into v_pid;
    insert into public.portfolio_members (portfolio_id, user_id, role) values (v_pid, v_owner, 'owner');
    insert into public.properties (portfolio_id, name, city, province)
    values (v_pid, 'House ' || i, 'Lahore', 'punjab') returning id into v_prop;
    with u as (
      insert into public.units (portfolio_id, property_id, label)
      select v_pid, v_prop, 'Portion ' || n from generate_series(1, 10) n returning id, portfolio_id
    ), t as (
      insert into public.tenants (portfolio_id, full_name)
      select v_pid, 'T' || i || '-' || n from generate_series(1, 10) n returning id
    )
    insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
    select uu.portfolio_id, uu.id, tt.id, '2025-11-01', 25000
    from (select id, portfolio_id, row_number() over () rn from u) uu
    join (select id, row_number() over () rn from t) tt using (rn);
  end loop;
end
$$;

-- Pay the deposit and the first 20 months of every Plaza lease.
do $$
declare
  v_lease record;
  v_payment uuid;
begin
  for v_lease in
    select id, portfolio_id, monthly_rent from public.leases
    where portfolio_id = '01a1a2e0-0000-7000-8000-000000000000'
  loop
    for m in 1 .. 20 loop
      insert into public.payments (portfolio_id, lease_id, amount, paid_on, method, receipt_number, idempotency_key, received_by)
      values (v_lease.portfolio_id, v_lease.id,
              v_lease.monthly_rent + case when m = 1 then 60000 else 0 end,
              ('2024-11-03'::date + make_interval(months => m - 1))::date,
              (case when m % 3 = 0 then 'raast' else 'cash' end)::public.payment_method,
              private.next_receipt_number(v_lease.portfolio_id), gen_random_uuid(),
              '00000000-0000-4000-8000-000000000000')
      returning id into v_payment;
      perform private.allocate_payment(v_payment);
    end loop;
  end loop;
end
$$;
analyze;
SQL
echo "  seeded in $(($(date +%s) - SEED_START))s: $(psql_db -c "select count(*) || ' charges, ' || (select count(*) from public.payments) || ' payments' from public.charges")"

# Latency budgets (milliseconds, server execution time under RLS) -----------------
measure() {
  local label="$1" budget="$2" sql="$3"
  local ms
  ms="$(
    psql_db <<SQL | grep -m1 -oE 'Execution Time: [0-9.]+' | grep -oE '[0-9.]+'
set app.today_override = '2026-11-03';
begin;
set local "request.jwt.claims" to '{"sub":"00000000-0000-4000-8000-000000000000","role":"authenticated"}';
set local role authenticated;
explain (analyze, format text) ${sql};
rollback;
SQL
  )"
  # Second run (warm cache) is the one we judge.
  ms="$(
    psql_db <<SQL | grep -m1 -oE 'Execution Time: [0-9.]+' | grep -oE '[0-9.]+'
set app.today_override = '2026-11-03';
begin;
set local "request.jwt.claims" to '{"sub":"00000000-0000-4000-8000-000000000000","role":"authenticated"}';
set local role authenticated;
explain (analyze, format text) ${sql};
rollback;
SQL
  )"
  if python3 -c "import sys; sys.exit(0 if float('$ms') <= $budget else 1)"; then
    printf '  ✓ %-28s %8.1f ms (budget %s ms)\n' "$label" "$ms" "$budget"
  else
    printf '  ✗ %-28s %8.1f ms (budget %s ms)\n' "$label" "$ms" "$budget"
    FAILED=1
  fi
}

FAILED=0
echo "▸ Latency (Plaza: 300 leases, RLS on)"
measure "get_dashboard" 750 "select public.get_dashboard('01a1a2e0-0000-7000-8000-000000000000')"
measure "get_receivables" 600 "select * from public.get_receivables('01a1a2e0-0000-7000-8000-000000000000')"
measure "get_payment_facts (12 mo)" 400 "select * from public.get_payment_facts('01a1a2e0-0000-7000-8000-000000000000')"
measure "get_cashflow (24 mo)" 400 "select * from public.get_cashflow('01a1a2e0-0000-7000-8000-000000000000', '2024-11-01', '2026-10-31')"
measure "get_tax_year_statement" 400 "select * from public.get_tax_year_statement('01a1a2e0-0000-7000-8000-000000000000', 2026)"
measure "search_portfolio" 150 "select * from public.search_portfolio('01a1a2e0-0000-7000-8000-000000000000', 'tenant 12')"
measure "lease ledger (1 lease)" 50 "select * from public.charges where lease_id = (select id from bench.leases where n = 7) order by due_date"
measure "unit occupancy list" 400 "select * from public.unit_occupancy where portfolio_id = '01a1a2e0-0000-7000-8000-000000000000'"

echo "▸ Daily job (every lease of every portfolio, then the once-a-day work)"
job_run() {
  psql_db <<SQL
set app.today_override = '2026-11-04';
select json_build_object(
  'ms', round(extract(epoch from (clock_timestamp() - s.started)) * 1000),
  'result', r.result
)
from (select clock_timestamp() as started) s
cross join lateral (select private.run_daily_jobs('2026-11-04', 10000) as result) r;
SQL
}
MAINTAIN="$(job_run)"
NOTIFY="$(job_run)"
if python3 - "$MAINTAIN" "$NOTIFY" <<'PY'
import json, sys
maintain, notify = (json.loads(arg) for arg in sys.argv[1:3])
m, n = maintain["result"], notify["result"]
ok_m = maintain["ms"] <= 5000 and m["leases_failed"] == 0 and m["leases_pending"] == 0
ok_n = notify["ms"] <= 15000 and n["leases_processed"] == 0 and n["notifications"] is not None
print(f"  {'✓' if ok_m else '✗'} {m['leases_processed']} leases maintained in {maintain['ms']} ms "
      f"(budget 5000 ms), {m['leases_failed']} failed, {m['leases_pending']} pending")
# The Plaza has 200 managers, so each reminder fans out 200-fold.
print(f"  {'✓' if ok_n else '✗'} once-a-day notifications in {notify['ms']} ms (budget 15000 ms, "
      f"200 managers x 300 leases)")
sys.exit(0 if ok_m and ok_n else 1)
PY
then :; else FAILED=1; fi

echo "▸ Index usage"
PLAN="$(
  psql_db <<'SQL'
begin;
set local "request.jwt.claims" to '{"sub":"00000000-0000-4000-8000-000000000000","role":"authenticated"}';
set local role authenticated;
explain select * from public.charges where lease_id = (select id from bench.leases where n = 7) and voided_at is null and outstanding > 0 order by due_date;
rollback;
SQL
)"
if grep -qE "Index (Only )?Scan|Bitmap Index Scan" <<<"$PLAN"; then
  echo "  ✓ open-charge lookup uses an index"
else
  echo "  ✗ open-charge lookup does not use an index:"
  echo "$PLAN"
  FAILED=1
fi

# Throughput ------------------------------------------------------------------------
echo "▸ pgbench: record_payment from 200 members, 8 clients, ${SECONDS_TO_RUN}s"
cat >"/tmp/mm_bench_$$.sql" <<'SQL'
\set u random(1, 200)
\set l random(1, 300)
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select id from bench.users where n = :u), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.record_payment((select id from bench.leases where n = :l), 100, '2026-11-03', 'cash', gen_random_uuid());
commit;
SQL
BENCH="$(PGOPTIONS='-c app.today_override=2026-11-03' pgbench -n -c 8 -j 4 -T "$SECONDS_TO_RUN" -f "/tmp/mm_bench_$$.sql" "$MM_TEST_DB" 2>&1)"
rm -f "/tmp/mm_bench_$$.sql"
TPS="$(grep -oE 'tps = [0-9.]+' <<<"$BENCH" | head -1 | grep -oE '[0-9.]+')"
FAILED_TX="$(grep -oE 'number of failed transactions: [0-9]+' <<<"$BENCH" | grep -oE '[0-9]+$' || echo 0)"
echo "  throughput: ${TPS} payments/s, failed transactions: ${FAILED_TX}"
[[ "${FAILED_TX:-0}" == "0" ]] || {
  echo "  ✗ pgbench reported failures"
  echo "$BENCH"
  FAILED=1
}
python3 -c "import sys; sys.exit(0 if float('${TPS:-0}') >= 50 else 1)" || {
  echo "  ✗ throughput below 50 tps"
  FAILED=1
}

INVARIANTS="$(psql_db -c "select count(*) from public.charges c left join (select charge_id, sum(amount) t from public.payment_allocations group by charge_id) a on a.charge_id = c.id where c.paid_amount <> coalesce(a.t, 0)")"
if [[ "$INVARIANTS" == "0" ]]; then
  echo "  ✓ ledger invariants hold after the load test"
else
  echo "  ✗ ledger invariants broken"
  FAILED=1
fi

exit "$FAILED"
