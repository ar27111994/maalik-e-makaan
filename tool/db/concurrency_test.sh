#!/usr/bin/env bash
# Concurrency test for the ledger: runs many genuinely parallel sessions
# against one lease and checks the invariants afterwards.
#
#   1. 40 parallel record_payment calls with distinct idempotency keys
#      → 40 payments, receipt numbers 1..40 with no gaps or duplicates.
#   2. 25 parallel retries of ONE payment (same idempotency key)
#      → exactly one payment is created; every caller gets the same receipt.
#   3. 10 parallel sync_portfolio_billing calls racing 10 payments
#      → no duplicate rent charges, no errors, no deadlocks.
#   4. The daily job started mid-way through id-ordered billing syncs and
#      payments over 121 leases whose stored rents are stale (the race that
#      deadlocked the pre-fix job), 12 rounds → no errors or deadlocks; a
#      second coordinator skips; the day finishes and its once-a-day work
#      runs exactly once.
#   5. A lease held by a long user transaction → the job skips it at once
#      (SKIP LOCKED) instead of waiting, and reports it as busy.
#   6. 10 parallel payments sharing ONE idempotency key across two leases
#      → exactly one payment; the rest replay it or are refused with
#      idempotency_key_reused, never a unique-constraint error.
#   7. Ledger invariants: paid_amount = Σ allocations, allocated_amount =
#      Σ allocations, nothing overpaid, cash conserved.
#
# Exits non-zero on any violation. Uses the local test server (tool/db/env.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export MM_TEST_DB="${MM_TEST_DB}_concurrency"
"$ROOT/tool/db/reset.sh" >/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" "$@"; }

# Fixture: one owner, one lease with 24 months of unpaid rent (so payments
# always have dues to settle).
IFS="|" read -r OWNER LEASE PORTFOLIO < <(psql_db <<'SQL'
set app.today_override = '2026-11-03';
with u as (
  insert into auth.users (id, email, email_confirmed_at)
  values ('00000000-0000-4000-8000-00000000c0de', 'owner@example.com', now())
  returning id
), p as (
  insert into public.portfolios (name, created_by) select 'Concurrency', id from u returning id
), m as (
  insert into public.portfolio_members (portfolio_id, user_id, role)
  select p.id, u.id, 'owner' from p, u returning portfolio_id
), prop as (
  insert into public.properties (portfolio_id, name, city, province)
  select portfolio_id, 'Tower', 'Karachi', 'sindh' from m returning id, portfolio_id
), unit as (
  insert into public.units (portfolio_id, property_id, label)
  select portfolio_id, id, 'Flat 1' from prop returning id, portfolio_id
), tenant as (
  insert into public.tenants (portfolio_id, full_name) select portfolio_id, 'Busy Tenant' from unit
  returning id, portfolio_id
)
insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
select unit.portfolio_id, unit.id, tenant.id, '2024-12-01', 50000 from unit, tenant
returning '00000000-0000-4000-8000-00000000c0de', id, portfolio_id;
SQL
)
echo "▸ Fixture ready (lease ${LEASE})"

as_owner() {
  cat <<SQL
set app.today_override = '2026-11-03';
begin;
set local "request.jwt.claims" to '{"sub":"${OWNER}","role":"authenticated"}';
set local role authenticated;
$1
commit;
SQL
}

# Each scenario starts with fresh per-user rate limits (record_payment allows
# 60 a minute per user, and this harness makes more than that as one owner).
reset_limits() { psql_db -c "delete from private.rate_limit_buckets" >/dev/null; }

# 1. Distinct payments in parallel ------------------------------------------------
echo "▸ 40 parallel payments with distinct keys"
for i in $(seq 1 40); do
  as_owner "select public.record_payment('${LEASE}', 1234.56, '2026-11-03', 'cash', gen_random_uuid()) -> 'payment' ->> 'receipt_number';" \
    | psql_db >"$WORK/distinct_$i.out" 2>"$WORK/distinct_$i.err" &
done
wait
if grep -l . "$WORK"/distinct_*.err >/dev/null 2>&1; then
  echo "✗ errors during parallel payments:"; cat "$WORK"/distinct_*.err; exit 1
fi

# 2. Same idempotency key in parallel ---------------------------------------------
echo "▸ 25 parallel retries with one idempotency key"
KEY="11111111-2222-4333-8444-555555555555"
for i in $(seq 1 25); do
  as_owner "select public.record_payment('${LEASE}', 5000, '2026-11-03', 'raast', '${KEY}') -> 'payment' ->> 'receipt_number';" \
    | psql_db >"$WORK/same_$i.out" 2>"$WORK/same_$i.err" &
done
wait
if grep -l . "$WORK"/same_*.err >/dev/null 2>&1; then
  echo "✗ errors during idempotent retries:"; cat "$WORK"/same_*.err; exit 1
fi
SAME_RECEIPTS="$(cat "$WORK"/same_*.out | sort -u | grep -c .)"
[[ "$SAME_RECEIPTS" == "1" ]] || { echo "✗ retries returned ${SAME_RECEIPTS} different receipts"; exit 1; }

# 3. Billing sync racing payments -----------------------------------------------------
echo "▸ 10 billing syncs racing 10 payments"
for i in $(seq 1 10); do
  as_owner "select public.sync_portfolio_billing('${PORTFOLIO}');" | psql_db >/dev/null 2>"$WORK/sync_$i.err" &
  as_owner "select public.record_payment('${LEASE}', 999.99, '2026-11-03', 'jazzcash', gen_random_uuid());" \
    | psql_db >/dev/null 2>"$WORK/race_$i.err" &
done
wait
if grep -l . "$WORK"/sync_*.err "$WORK"/race_*.err >/dev/null 2>&1; then
  echo "✗ errors while racing billing and payments:"; cat "$WORK"/sync_*.err "$WORK"/race_*.err; exit 1
fi

# 4. Daily job racing syncs and payments ------------------------------------------------
# Each round makes every stored rent stale (so the job must rewrite lease
# rows), starts six id-ordered billing syncs and two payments, and starts the
# job a few milliseconds later, while the syncs hold some leases and want
# others. The pre-fix job (one bulk rent refresh in physical order) deadlocked
# in this race on real PostgreSQL in 4 of 20 rounds; random lease ids make
# physical order differ from id order, as offline-created ids do.
JOB_ROUNDS=12
echo "▸ Daily job racing billing syncs and payments over 121 leases (${JOB_ROUNDS} rounds)"
psql_db -v portfolio="$PORTFOLIO" >/dev/null <<'SQL'
set app.today_override = '2026-11-03';
select set_config('mm.portfolio', :'portfolio', false);
do $$
declare
  v_portfolio uuid := current_setting('mm.portfolio')::uuid;
  v_property uuid;
  v_unit uuid;
  v_tenant uuid;
begin
  for i in 1..120 loop
    insert into public.properties (portfolio_id, name, city, province)
    values (v_portfolio, 'Block ' || i, 'Lahore', 'punjab') returning id into v_property;
    insert into public.units (portfolio_id, property_id, label)
    values (v_portfolio, v_property, 'Unit ' || i) returning id into v_unit;
    insert into public.tenants (portfolio_id, full_name)
    values (v_portfolio, 'Tenant ' || i) returning id into v_tenant;
    insert into public.leases (
      id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent, late_fee_type, late_fee_value, late_fee_cap
    )
    values (gen_random_uuid(), v_portfolio, v_unit, v_tenant, '2026-06-01', 30000 + i, 'daily', 100, 5000);
  end loop;
end
$$;
SQL
run_job() {
  printf "set app.today_override = '2026-11-03';\nselect private.run_daily_jobs('%s', %s) %s;\n" "$1" "$2" "${3:-}"
}
random_payment() {
  as_owner "select public.record_payment(
      (select id from public.leases where portfolio_id = '${PORTFOLIO}' order by random() limit 1),
      2500, '2026-11-03', 'easypaisa', gen_random_uuid());"
}
for round in $(seq 1 "$JOB_ROUNDS"); do
  reset_limits
  psql_db -c "update public.leases set monthly_rent = monthly_rent + 1 where status = 'active'" >/dev/null
  AS_OF="$(psql_db -c "select '2026-11-03'::date + $((round - 1))")"
  for i in $(seq 1 6); do
    as_owner "select public.sync_portfolio_billing('${PORTFOLIO}');" \
      | psql_db >/dev/null 2>"$WORK/jsync_${round}_$i.err" &
  done
  random_payment | psql_db >/dev/null 2>"$WORK/jpay_${round}_1.err" &
  random_payment | psql_db >/dev/null 2>"$WORK/jpay_${round}_2.err" &
  sleep "0.0$(( (round % 9) + 1 ))"
  # Two coordinators: the second must skip at once, not queue behind the first.
  run_job "$AS_OF" 1000 | psql_db >/dev/null 2>"$WORK/job_${round}_1.err" &
  run_job "$AS_OF" 1000 | psql_db >/dev/null 2>"$WORK/job_${round}_2.err" &
  wait
done
if grep -l . "$WORK"/job_*.err "$WORK"/jsync_*.err "$WORK"/jpay_*.err >/dev/null 2>&1; then
  echo "✗ errors while racing the daily job:"; cat "$WORK"/job_*.err "$WORK"/jsync_*.err "$WORK"/jpay_*.err; exit 1
fi
# Runs until one maintains nothing: that run finds the day done and does the
# once-a-day work (notifications never run while lease locks are held).
for _ in $(seq 1 20); do
  [[ "$(run_job "$AS_OF" 1000 "->> 'leases_processed'" | psql_db)" == "0" ]] && break
done
DAY="$(psql_db -c "select json_build_object(
  'pending', (select count(*) from public.leases l left join private.lease_maintenance m on m.lease_id = l.id
              where l.status = 'active' and (m.maintained_on is null or m.maintained_on < '${AS_OF}')),
  'failed', (select count(*) from private.lease_maintenance where failures > 0),
  'daily_runs', (select count(*) from private.job_runs where run_on = '${AS_OF}'),
  'stale_rents', (select count(*) from public.leases l where l.status = 'active' and l.monthly_rent <> (
                   select rc.monthly_rent from public.rent_changes rc
                   where rc.lease_id = l.id and rc.effective_from <= '2026-11-01'
                   order by rc.effective_from desc limit 1))
)")"
echo "  $DAY"
python3 - "$DAY" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
want = {"pending": 0, "failed": 0, "daily_runs": 1, "stale_rents": 0}
bad = {k: r[k] for k in want if r[k] != want[k]}
if bad:
    print(f"✗ the daily job did not finish the day cleanly: {bad}"); sys.exit(1)
PY

# 5. A busy lease is skipped, not waited for --------------------------------------------
echo "▸ The daily job skips a lease that a user transaction holds"
psql_db >/dev/null 2>"$WORK/holder.err" <<SQL &
begin;
select 1 from public.leases where id = '${LEASE}' for update;
select pg_sleep(4);
commit;
SQL
HOLDER=$!
sleep 1
START="$(date +%s%N)"
BUSY="$(run_job 2026-11-20 1000 "->> 'leases_busy'" | psql_db)"
ELAPSED_MS=$(( ($(date +%s%N) - START) / 1000000 ))
wait "$HOLDER"
[[ ! -s "$WORK/holder.err" ]] || { echo "✗ the lock holder failed:"; cat "$WORK/holder.err"; exit 1; }
[[ "$BUSY" == "1" ]] || { echo "✗ expected 1 busy lease, got '${BUSY}'"; exit 1; }
(( ELAPSED_MS < 2500 )) || { echo "✗ the job waited ${ELAPSED_MS} ms for a busy lease"; exit 1; }
echo "  skipped the busy lease in ${ELAPSED_MS} ms"

# 6. One idempotency key, two leases, in parallel ---------------------------------------
reset_limits
echo "▸ 10 parallel payments sharing one key across two leases"
OTHER_LEASE="$(psql_db -c "select id from public.leases where id <> '${LEASE}' order by id limit 1")"
SHARED_KEY="22222222-3333-4444-8555-666666666666"
for i in $(seq 1 10); do
  TARGET="$LEASE"
  (( i % 2 == 0 )) && TARGET="$OTHER_LEASE"
  as_owner "select public.record_payment('${TARGET}', 777, '2026-11-03', 'cash', '${SHARED_KEY}') -> 'payment' ->> 'receipt_number';" \
    | psql_db >"$WORK/key_$i.out" 2>"$WORK/key_$i.err" &
done
wait
for f in "$WORK"/key_*.err; do
  if [[ -s "$f" ]] && ! grep -q "ERROR:  idempotency_key_reused" "$f"; then
    echo "✗ unexpected error for a shared key:"; cat "$f"; exit 1
  fi
done
KEY_PAYMENTS="$(psql_db -c "select count(*) from public.payments where idempotency_key = '${SHARED_KEY}'")"
KEY_REPLIES="$(cat "$WORK"/key_*.out | grep -c . || true)"
KEY_RECEIPTS="$(cat "$WORK"/key_*.out | sort -u | grep -c . || true)"
[[ "$KEY_PAYMENTS" == "1" && "$KEY_REPLIES" == "5" && "$KEY_RECEIPTS" == "1" ]] || {
  echo "✗ shared key: ${KEY_PAYMENTS} payments, ${KEY_REPLIES} replies, ${KEY_RECEIPTS} receipts"; exit 1
}

# 7. Invariants --------------------------------------------------------------------------
echo "▸ Checking invariants"
RESULT="$(psql_db <<SQL
select json_build_object(
  'payments', (select count(*) from public.payments),
  'receipts_distinct', (select count(distinct receipt_number) from public.payments),
  'receipt_gaps', (
    select count(*) from generate_series(1, (select count(*) from public.payments)) n
    where not exists (
      select 1 from public.payments
      where split_part(receipt_number, '-', 3)::integer = n
    )
  ),
  'duplicate_rent_months', (
    select count(*) from (
      select period_month from public.charges where kind = 'rent'
      group by lease_id, period_month having count(*) > 1
    ) d
  ),
  'charge_mismatch', (
    select count(*) from public.charges c
    left join (select charge_id, sum(amount) t from public.payment_allocations group by charge_id) a
      on a.charge_id = c.id
    where c.paid_amount <> coalesce(a.t, 0)
  ),
  'payment_mismatch', (
    select count(*) from public.payments p
    left join (select payment_id, sum(amount) t from public.payment_allocations group by payment_id) a
      on a.payment_id = p.id
    where p.allocated_amount <> coalesce(a.t, 0)
  ),
  'overpaid', (select count(*) from public.charges where paid_amount + waived_amount > amount),
  'cash_in', (select sum(amount) from public.payments),
  'cash_accounted', (select sum(allocated_amount) + sum(unallocated_amount) from public.payments)
);
SQL
)"
echo "  $RESULT"
python3 - "$RESULT" "$JOB_ROUNDS" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
errors = []
expected = 40 + 1 + 10 + 2 * int(sys.argv[2]) + 1
if r["payments"] != expected: errors.append(f"expected {expected} payments, got {r['payments']}")
if r["receipts_distinct"] != r["payments"]: errors.append("duplicate receipt numbers")
if r["receipt_gaps"] != 0: errors.append("gaps in receipt numbers")
for key in ("duplicate_rent_months", "charge_mismatch", "payment_mismatch", "overpaid"):
    if r[key] != 0: errors.append(f"{key} = {r[key]}")
if abs(float(r["cash_in"]) - float(r["cash_accounted"])) > 0.001: errors.append("cash not conserved")
if errors:
    print("✗ " + "; ".join(errors)); sys.exit(1)
print("✓ concurrency invariants hold")
PY
