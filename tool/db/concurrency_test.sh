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
#   4. Ledger invariants: paid_amount = Σ allocations, allocated_amount =
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

# 4. Invariants --------------------------------------------------------------------------
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
python3 - "$RESULT" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
errors = []
if r["payments"] != 51: errors.append(f"expected 51 payments, got {r['payments']}")
if r["receipts_distinct"] != r["payments"]: errors.append("duplicate receipt numbers")
if r["receipt_gaps"] != 0: errors.append("gaps in receipt numbers")
for key in ("duplicate_rent_months", "charge_mismatch", "payment_mismatch", "overpaid"):
    if r[key] != 0: errors.append(f"{key} = {r[key]}")
if abs(float(r["cash_in"]) - float(r["cash_accounted"])) > 0.001: errors.append("cash not conserved")
if errors:
    print("✗ " + "; ".join(errors)); sys.exit(1)
print("✓ concurrency invariants hold")
PY
