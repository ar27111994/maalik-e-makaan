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
#   7. An owner removes another owner and holds the transaction open while
#      the removed owner changes a role → refused (authorisation is checked
#      again after the portfolio lock), and the role is unchanged.
#   8. Two co-owners delete their accounts at the same moment → their shared
#      portfolio is deleted with the second account, never left ownerless.
#   9. Portfolios deleted while payments, a billing sync and the daily job
#      work on their leases (3 rounds) → no deadlock; writes that lose the
#      race are refused as forbidden; every portfolio is gone.
#  10. Invitations accepted while their portfolio is deleted (3 rounds) → no
#      deadlock; each acceptance either lands first or finds it invalid.
#  11. A child-row insert, a lease created with a low client id and a billing
#      sync race a deletion while a payment holds a lease (3 rounds) → no
#      deadlock; the losers are refused or find their parent gone.
#  12. A document renamed (audited) during a long portfolio cascade → no
#      deadlock; the portfolio goes and its folder is queued.
#  13. A document attached while its tenant is deleted, in both orders → it
#      never outlives the tenant, and an attached file is queued with it.
#  14. An account being deleted accepts an owner invitation and replays a
#      portfolio creation on other devices → both refused (account_deleted);
#      the inviting portfolio keeps its owner.
#  15. Manual charges and payments on one lease at once (5 rounds) → no
#      deadlock (the charge locks its lease before its foreign-key checks).
#  16. A deleted portfolio's id claimed repeatedly during the deletion →
#      every claim refused, the id never comes back.
#  17. An auth user deleted (ON DELETE SET NULL cascades) while a co-owner
#      deletes the portfolio that user created → no deadlock.
#  18. Ledger invariants: paid_amount = Σ allocations, allocated_amount =
#      Σ allocations, nothing overpaid, cash conserved; no portfolio is left
#      without an owner or without members; no document outlives its entity.
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
IFS="|" read -r OWNER LEASE PORTFOLIO < <(
  psql_db <<'SQL'
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
  echo "✗ errors during parallel payments:"
  cat "$WORK"/distinct_*.err
  exit 1
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
  echo "✗ errors during idempotent retries:"
  cat "$WORK"/same_*.err
  exit 1
fi
SAME_RECEIPTS="$(cat "$WORK"/same_*.out | sort -u | grep -c .)"
[[ "$SAME_RECEIPTS" == "1" ]] || {
  echo "✗ retries returned ${SAME_RECEIPTS} different receipts"
  exit 1
}

# 3. Billing sync racing payments -----------------------------------------------------
echo "▸ 10 billing syncs racing 10 payments"
for i in $(seq 1 10); do
  as_owner "select public.sync_portfolio_billing('${PORTFOLIO}');" | psql_db >/dev/null 2>"$WORK/sync_$i.err" &
  as_owner "select public.record_payment('${LEASE}', 999.99, '2026-11-03', 'jazzcash', gen_random_uuid());" \
    | psql_db >/dev/null 2>"$WORK/race_$i.err" &
done
wait
if grep -l . "$WORK"/sync_*.err "$WORK"/race_*.err >/dev/null 2>&1; then
  echo "✗ errors while racing billing and payments:"
  cat "$WORK"/sync_*.err "$WORK"/race_*.err
  exit 1
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
  sleep "0.0$(((round % 9) + 1))"
  # Two coordinators: the second must skip at once, not queue behind the first.
  run_job "$AS_OF" 1000 | psql_db >/dev/null 2>"$WORK/job_${round}_1.err" &
  run_job "$AS_OF" 1000 | psql_db >/dev/null 2>"$WORK/job_${round}_2.err" &
  wait
done
if grep -l . "$WORK"/job_*.err "$WORK"/jsync_*.err "$WORK"/jpay_*.err >/dev/null 2>&1; then
  echo "✗ errors while racing the daily job:"
  cat "$WORK"/job_*.err "$WORK"/jsync_*.err "$WORK"/jpay_*.err
  exit 1
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
ELAPSED_MS=$((($(date +%s%N) - START) / 1000000))
wait "$HOLDER"
[[ ! -s "$WORK/holder.err" ]] || {
  echo "✗ the lock holder failed:"
  cat "$WORK/holder.err"
  exit 1
}
[[ "$BUSY" == "1" ]] || {
  echo "✗ expected 1 busy lease, got '${BUSY}'"
  exit 1
}
((ELAPSED_MS < 2500)) || {
  echo "✗ the job waited ${ELAPSED_MS} ms for a busy lease"
  exit 1
}
echo "  skipped the busy lease in ${ELAPSED_MS} ms"

# 6. One idempotency key, two leases, in parallel ---------------------------------------
reset_limits
echo "▸ 10 parallel payments sharing one key across two leases"
OTHER_LEASE="$(psql_db -c "select id from public.leases where id <> '${LEASE}' order by id limit 1")"
SHARED_KEY="22222222-3333-4444-8555-666666666666"
for i in $(seq 1 10); do
  TARGET="$LEASE"
  ((i % 2 == 0)) && TARGET="$OTHER_LEASE"
  as_owner "select public.record_payment('${TARGET}', 777, '2026-11-03', 'cash', '${SHARED_KEY}') -> 'payment' ->> 'receipt_number';" \
    | psql_db >"$WORK/key_$i.out" 2>"$WORK/key_$i.err" &
done
wait
for f in "$WORK"/key_*.err; do
  if [[ -s "$f" ]] && ! grep -q "ERROR:  idempotency_key_reused" "$f"; then
    echo "✗ unexpected error for a shared key:"
    cat "$f"
    exit 1
  fi
done
KEY_PAYMENTS="$(psql_db -c "select count(*) from public.payments where idempotency_key = '${SHARED_KEY}'")"
KEY_REPLIES="$(cat "$WORK"/key_*.out | grep -c . || true)"
KEY_RECEIPTS="$(cat "$WORK"/key_*.out | sort -u | grep -c . || true)"
[[ "$KEY_PAYMENTS" == "1" && "$KEY_REPLIES" == "5" && "$KEY_RECEIPTS" == "1" ]] || {
  echo "✗ shared key: ${KEY_PAYMENTS} payments, ${KEY_REPLIES} replies, ${KEY_RECEIPTS} receipts"
  exit 1
}

# Session helpers for the membership and deletion races.
as_user() {
  cat <<SQL
set app.today_override = '2026-11-03';
begin;
set local "request.jwt.claims" to '{"sub":"$1","role":"authenticated"}';
set local role authenticated;
$2
commit;
SQL
}
as_service() {
  cat <<SQL
set app.today_override = '2026-11-03';
begin;
set local "request.jwt.claims" to '{"role":"service_role"}';
set local role service_role;
$1
commit;
SQL
}
new_user() {
  psql_db -c "insert into auth.users (id, email, email_confirmed_at)
              values (gen_random_uuid(), '$1', now()) returning id"
}
new_portfolio() {
  psql_db -c "with p as (
                insert into public.portfolios (name, created_by) values ('$2', '$1') returning id
              ), m as (
                insert into public.portfolio_members (portfolio_id, user_id, role)
                select id, '$1', 'owner' from p
              )
              select id from p"
}
add_member() {
  psql_db -c "insert into public.portfolio_members (portfolio_id, user_id, role) values ('$1', '$2', '$3')" >/dev/null
}
# Fails unless every non-empty error file holds only the allowed error.
only_errors() {
  local allowed="$1" file
  shift
  for file in "$@"; do
    if [[ -s "$file" ]] && ! grep -q "ERROR:  ${allowed}" "$file"; then
      echo "✗ unexpected error in $(basename "$file"):"
      cat "$file"
      exit 1
    fi
  done
}

# 7. A removed owner cannot act on a stale authorisation ----------------------------------
echo "▸ An owner removed mid-request cannot change roles"
reset_limits
OWNER_A="$(new_user "owner-a@example.com")"
OWNER_B="$(new_user "owner-b@example.com")"
MANAGER_C="$(new_user "manager-c@example.com")"
TEAM="$(new_portfolio "$OWNER_A" 'Membership race')"
add_member "$TEAM" "$OWNER_B" owner
add_member "$TEAM" "$MANAGER_C" manager
as_user "$OWNER_A" "select public.remove_member('${TEAM}', '${OWNER_B}'); select pg_sleep(2);" \
  | psql_db >/dev/null 2>"$WORK/remove.err" &
REMOVER=$!
sleep 0.7
as_user "$OWNER_B" "select public.update_member_role('${TEAM}', '${MANAGER_C}', 'viewer');" \
  | psql_db >/dev/null 2>"$WORK/stale.err" || true
wait "$REMOVER"
[[ ! -s "$WORK/remove.err" ]] || {
  echo "✗ the removal failed:"
  cat "$WORK/remove.err"
  exit 1
}
grep -q "ERROR:  forbidden" "$WORK/stale.err" || {
  echo "✗ the removed owner was not refused:"
  cat "$WORK/stale.err"
  exit 1
}
ROLE_C="$(psql_db -c "select role from public.portfolio_members where portfolio_id = '${TEAM}' and user_id = '${MANAGER_C}'")"
[[ "$ROLE_C" == "manager" ]] || {
  echo "✗ the manager's role became ${ROLE_C}"
  exit 1
}

# 8. Co-owners deleting their accounts at once ----------------------------------------------
echo "▸ Co-owners deleting their accounts at once never orphan their portfolio"
OWNER_X="$(new_user "owner-x@example.com")"
OWNER_Y="$(new_user "owner-y@example.com")"
ESTATE="$(new_portfolio "$OWNER_X" 'Shared estate')"
add_member "$ESTATE" "$OWNER_Y" owner
as_service "select public.admin_delete_account_data('${OWNER_X}'); select pg_sleep(2);" \
  | psql_db >/dev/null 2>"$WORK/delete_x.err" &
FIRST=$!
sleep 0.7
as_service "select public.admin_delete_account_data('${OWNER_Y}');" | psql_db >/dev/null 2>"$WORK/delete_y.err"
wait "$FIRST"
only_errors "never-allowed" "$WORK/delete_x.err" "$WORK/delete_y.err"
[[ "$(psql_db -c "select count(*) from public.portfolios where id = '${ESTATE}'")" == "0" ]] || {
  echo "✗ the shared portfolio outlived both owners"
  exit 1
}

# 9. Deleting portfolios while their leases are written ---------------------------------
echo "▸ Portfolios deleted while payments, a billing sync and the daily job run"
for round in 1 2 3; do
  reset_limits
  DOOMED_OWNER="$(new_user "doomed-${round}@example.com")"
  DOOMED="$(new_portfolio "$DOOMED_OWNER" "Doomed ${round}")"
  psql_db -v portfolio="$DOOMED" >/dev/null <<'SQL'
set app.today_override = '2026-11-03';
select set_config('mm.portfolio', :'portfolio', false);
do $$
declare
  v_portfolio uuid := current_setting('mm.portfolio')::uuid;
  v_property uuid;
  v_unit uuid;
  v_tenant uuid;
begin
  for i in 1..8 loop
    insert into public.properties (portfolio_id, name, city, province)
    values (v_portfolio, 'Doomed block ' || i, 'Multan', 'punjab') returning id into v_property;
    insert into public.units (portfolio_id, property_id, label)
    values (v_portfolio, v_property, 'Unit ' || i) returning id into v_unit;
    insert into public.tenants (portfolio_id, full_name)
    values (v_portfolio, 'Tenant ' || i) returning id into v_tenant;
    insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
    values (gen_random_uuid(), v_portfolio, v_unit, v_tenant, '2026-08-01', 20000 + i);
  end loop;
end
$$;
SQL
  mapfile -t DOOMED_LEASES < <(psql_db -c "select id from public.leases where portfolio_id = '${DOOMED}'")
  for lease in "${DOOMED_LEASES[@]}"; do
    as_user "$DOOMED_OWNER" "select public.record_payment('${lease}', 1000, '2026-11-03', 'cash', gen_random_uuid());" \
      | psql_db >/dev/null 2>"$WORK/doomed_pay_${round}_${lease}.err" &
  done
  as_user "$DOOMED_OWNER" "select public.sync_portfolio_billing('${DOOMED}');" \
    | psql_db >/dev/null 2>"$WORK/doomed_sync_${round}.err" &
  run_job "2026-11-2${round}" 1000 | psql_db >/dev/null 2>"$WORK/doomed_job_${round}.err" &
  sleep "0.0$((round * 3))"
  as_user "$DOOMED_OWNER" "select public.delete_portfolio('${DOOMED}', 'Doomed ${round}');" \
    | psql_db >/dev/null 2>"$WORK/doomed_delete_${round}.err" &
  wait
done
only_errors "forbidden" "$WORK"/doomed_pay_*.err "$WORK"/doomed_sync_*.err
only_errors "never-allowed" "$WORK"/doomed_job_*.err "$WORK"/doomed_delete_*.err
[[ "$(psql_db -c "select count(*) from public.portfolios where name like 'Doomed %'")" == "0" ]] || {
  echo "✗ a doomed portfolio survived its deletion"
  exit 1
}

# 10. Accepting an invitation while the portfolio is deleted ----------------------------
echo "▸ Invitations accepted while their portfolio is deleted"
for round in 1 2 3; do
  reset_limits
  HOST="$(new_user "host-${round}@example.com")"
  GUEST="$(new_user "guest-${round}@example.com")"
  VENUE="$(new_portfolio "$HOST" "Venue ${round}")"
  TOKEN="$(as_user "$HOST" "select public.create_invitation('${VENUE}', 'guest-${round}@example.com', 'viewer') ->> 'token';" | psql_db)"
  as_user "$GUEST" "select public.accept_invitation('${TOKEN}') ->> 'status';" \
    | psql_db >"$WORK/accept_${round}.out" 2>"$WORK/accept_${round}.err" &
  as_user "$HOST" "select public.delete_portfolio('${VENUE}', 'Venue ${round}');" \
    | psql_db >/dev/null 2>"$WORK/venue_delete_${round}.err" &
  wait
done
only_errors "never-allowed" "$WORK"/accept_*.err "$WORK"/venue_delete_*.err
if grep -hv -e '^accepted$' -e '^invalid$' "$WORK"/accept_*.out | grep -q .; then
  echo "✗ unexpected acceptance status:"
  cat "$WORK"/accept_*.out
  exit 1
fi
[[ "$(psql_db -c "select count(*) from public.portfolios where name like 'Venue %'")" == "0" ]] || {
  echo "✗ an invited portfolio survived its deletion"
  exit 1
}

# A portfolio named $2, owned by $1, with $3 tenancies; prints its id.
new_estate() {
  local portfolio
  portfolio="$(new_portfolio "$1" "$2")"
  psql_db -v portfolio="$portfolio" -v leases="$3" >/dev/null <<'SQL'
set app.today_override = '2026-11-03';
select set_config('mm.portfolio', :'portfolio', false), set_config('mm.leases', :'leases', false);
do $$
declare
  v_portfolio uuid := current_setting('mm.portfolio')::uuid;
  v_property uuid;
  v_unit uuid;
  v_tenant uuid;
begin
  for i in 1..current_setting('mm.leases')::integer loop
    insert into public.properties (portfolio_id, name, city, province)
    values (v_portfolio, 'Block ' || i, 'Lahore', 'punjab') returning id into v_property;
    insert into public.units (portfolio_id, property_id, label)
    values (v_portfolio, v_property, 'Unit ' || i) returning id into v_unit;
    insert into public.tenants (portfolio_id, full_name)
    values (v_portfolio, 'Tenant ' || i) returning id into v_tenant;
    insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
    values (gen_random_uuid(), v_portfolio, v_unit, v_tenant, '2026-08-01', 20000 + i);
  end loop;
end
$$;
SQL
  echo "$portfolio"
}
# $3 extra ledger rows on lease $2 of portfolio $1, bulk-loaded with triggers
# off, so deleting the portfolio cascades for a while.
bulk_charges() {
  psql_db >/dev/null <<SQL
set session_replication_role = replica;
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, source)
select '$1', '$2', 'other', date '2020-01-01' + (g % 2000), 100, 'manual' from generate_series(1, $3) g;
set session_replication_role = origin;
analyze public.charges;
SQL
}
# Uploads a file for entity $3 (type $2) of portfolio $1 and registers it as a
# document (file first, as the app does); prints the storage path.
new_document() {
  local path
  path="$1/$2/$3/$(psql_db -c "select gen_random_uuid()").pdf"
  psql_db >/dev/null <<SQL
insert into storage.objects (bucket_id, name) values ('documents', '$path');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values ('$1', '$2', '$3', '$path', 'deed.pdf', 'application/pdf', 2000);
SQL
  echo "$path"
}
# Errors a write may meet when it loses a race with a deletion: refused by
# authorisation or by a row policy, or its parent row is gone.
LOSER_ERRORS='forbidden|new row violates row-level security policy|insert or update on table "[a-z_]+" violates foreign key constraint'
# Fails unless every error line in the files matches the allowed ERE.
only_errors_matching() {
  local allowed="$1" file
  shift
  for file in "$@"; do
    if [[ -s "$file" ]] && grep "ERROR:" "$file" | grep -qvE "ERROR:  (${allowed})"; then
      echo "✗ unexpected error in $(basename "$file"):"
      cat "$file"
      exit 1
    fi
  done
}
no_deadlocks() {
  if cat "$@" 2>/dev/null | grep -q "deadlock detected"; then
    echo "✗ deadlock:"
    grep -l "deadlock detected" "$@"
    exit 1
  fi
}

# 11. Writers in both lock orders racing a deletion -------------------------------------
# A child-row insert (foreign keys: portfolio key, then the lease), a lease
# created with a low client id, and a billing sync, while a slow payment holds
# the highest lease: the cycles that deadlocked the leases-first deletion.
echo "▸ Child rows, a new lease and a billing sync racing a portfolio deletion"
for round in 1 2 3; do
  reset_limits
  RACER="$(new_user "racer-${round}@example.com")"
  RACER_MANAGER="$(new_user "racer-manager-${round}@example.com")"
  TRACK="$(new_estate "$RACER" "Racing ${round}" 4)"
  add_member "$TRACK" "$RACER_MANAGER" manager
  mapfile -t TRACK_LEASES < <(psql_db -c "select id from public.leases where portfolio_id = '${TRACK}' order by id")
  read -r ANNEX_UNIT ANNEX_TENANT < <(psql_db -F ' ' -c "
    with pr as (insert into public.properties (portfolio_id, name, city, province)
                values ('${TRACK}', 'Annex', 'Lahore', 'punjab') returning id),
         u as (insert into public.units (portfolio_id, property_id, label)
               select '${TRACK}', id, 'Annex 1' from pr returning id),
         t as (insert into public.tenants (portfolio_id, full_name) values ('${TRACK}', 'Newcomer') returning id)
    select u.id, t.id from u, t")
  as_user "$RACER" "select public.record_payment('${TRACK_LEASES[-1]}', 1000, '2026-11-03', 'cash', gen_random_uuid()) is not null; select pg_sleep(1.5);" \
    | psql_db >/dev/null 2>"$WORK/track_pay_${round}.err" &
  sleep 0.3
  as_user "$RACER" "select public.delete_portfolio('${TRACK}', 'Racing ${round}');" \
    | psql_db >/dev/null 2>"$WORK/track_delete_${round}.err" &
  sleep 0.3
  as_user "$RACER_MANAGER" "insert into public.reminder_logs (portfolio_id, lease_id, channel, template, language) values ('${TRACK}', '${TRACK_LEASES[0]}', 'whatsapp', 'rent_due', 'en');" \
    | psql_db >/dev/null 2>"$WORK/track_reminder_${round}.err" &
  as_user "$RACER_MANAGER" "insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent) values ('00000000-0000-4000-8000-0000000000${round}0', '${TRACK}', '${ANNEX_UNIT}', '${ANNEX_TENANT}', '2026-09-01', 25000);" \
    | psql_db >/dev/null 2>"$WORK/track_lease_${round}.err" &
  as_user "$RACER_MANAGER" "select public.sync_portfolio_billing('${TRACK}');" \
    | psql_db >/dev/null 2>"$WORK/track_sync_${round}.err" &
  wait
done
no_deadlocks "$WORK"/track_*.err
only_errors "never-allowed" "$WORK"/track_pay_*.err "$WORK"/track_delete_*.err
only_errors_matching "$LOSER_ERRORS" "$WORK"/track_reminder_*.err "$WORK"/track_lease_*.err "$WORK"/track_sync_*.err
[[ "$(psql_db -c "select count(*) from public.portfolios where name like 'Racing %'")" == "0" ]] || {
  echo "✗ a racing portfolio survived its deletion"
  exit 1
}

# 12. An audited client UPDATE during a long cascade -------------------------------------
# The rename locks the document row and then wrote an audit row whose foreign
# key needed the portfolio key, which the deletion held while its cascade
# waited for the document row.
echo "▸ A document renamed while its portfolio's long cascade runs"
reset_limits
LONG_OWNER="$(new_user "long-owner@example.com")"
LONG_MANAGER="$(new_user "long-manager@example.com")"
LONG="$(new_estate "$LONG_OWNER" 'Long cascade' 1)"
add_member "$LONG" "$LONG_MANAGER" manager
LONG_LEASE="$(psql_db -c "select id from public.leases where portfolio_id = '${LONG}'")"
LONG_PROPERTY="$(psql_db -c "select id from public.properties where portfolio_id = '${LONG}'")"
LONG_DOC="$(new_document "$LONG" property "$LONG_PROPERTY")"
bulk_charges "$LONG" "$LONG_LEASE" 400000
as_user "$LONG_OWNER" "select public.delete_portfolio('${LONG}', 'Long cascade');" \
  | psql_db >/dev/null 2>"$WORK/long_delete.err" &
sleep 0.2
as_user "$LONG_MANAGER" "update public.documents set file_name = 'title-deed.pdf' where storage_path = '${LONG_DOC}';" \
  | psql_db >/dev/null 2>"$WORK/long_rename.err" &
wait
no_deadlocks "$WORK"/long_*.err
only_errors "never-allowed" "$WORK"/long_delete.err "$WORK"/long_rename.err
[[ "$(psql_db -c "select count(*) from public.portfolios where id = '${LONG}'")" == "0" ]] || {
  echo "✗ the long portfolio survived its deletion"
  exit 1
}
[[ "$(psql_db -c "select count(*) from private.storage_cleanup_queue where path = '${LONG}/'")" == "1" ]] || {
  echo "✗ the long portfolio's folder was not queued"
  exit 1
}

# 13. A document attached while its entity is deleted ------------------------------------
echo "▸ Documents attached while their tenant is deleted (both orders)"
reset_limits
DOC_OWNER="$(new_user "doc-owner@example.com")"
DOC_MANAGER="$(new_user "doc-manager@example.com")"
FILES="$(new_portfolio "$DOC_OWNER" 'Files')"
add_member "$FILES" "$DOC_MANAGER" manager
for order in insert_first delete_first; do
  SHORT_STAY="$(psql_db -c "insert into public.tenants (portfolio_id, full_name) values ('${FILES}', 'Short stay') returning id")"
  CNIC_FILE="${FILES}/tenant/${SHORT_STAY}/$(psql_db -c "select gen_random_uuid()").jpg"
  psql_db -c "insert into storage.objects (bucket_id, name) values ('documents', '${CNIC_FILE}')" >/dev/null
  ATTACH="insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes) values ('${FILES}', 'tenant', '${SHORT_STAY}', '${CNIC_FILE}', 'cnic.jpg', 'image/jpeg', 1000);"
  REMOVE="delete from public.tenants where id = '${SHORT_STAY}';"
  if [[ "$order" == insert_first ]]; then
    as_user "$DOC_MANAGER" "${ATTACH} select pg_sleep(1);" | psql_db >/dev/null 2>"$WORK/doc_${order}_attach.err" &
    sleep 0.3
    as_user "$DOC_OWNER" "$REMOVE" | psql_db >/dev/null 2>"$WORK/doc_${order}_remove.err" || true
  else
    as_user "$DOC_OWNER" "${REMOVE} select pg_sleep(1);" | psql_db >/dev/null 2>"$WORK/doc_${order}_remove.err" &
    sleep 0.3
    as_user "$DOC_MANAGER" "$ATTACH" | psql_db >/dev/null 2>"$WORK/doc_${order}_attach.err" || true
  fi
  wait
  only_errors "never-allowed" "$WORK/doc_${order}_remove.err"
  only_errors_matching "document_entity_not_found" "$WORK/doc_${order}_attach.err"
  [[ "$(psql_db -c "select count(*) from public.documents where entity_id = '${SHORT_STAY}'")" == "0" ]] || {
    echo "✗ ${order}: a document outlived its tenant"
    exit 1
  }
  if [[ ! -s "$WORK/doc_${order}_attach.err" ]] \
    && [[ "$(psql_db -c "select count(*) from private.storage_cleanup_queue where path = '${CNIC_FILE}'")" != "1" ]]; then
    echo "✗ ${order}: the attached file was not queued with its tenant"
    exit 1
  fi
done

# 14. Joining or creating portfolios while the account is being deleted -------------------
echo "▸ An account being deleted can neither join nor create portfolios"
reset_limits
LEAVER="$(new_user "leaver@example.com")"
HOST_O="$(new_user "hall-owner@example.com")"
LEAVING="$(new_estate "$LEAVER" 'Leaving' 1)"
bulk_charges "$LEAVING" "$(psql_db -c "select id from public.leases where portfolio_id = '${LEAVING}'")" 150000
HALL="$(new_portfolio "$HOST_O" 'Shared hall')"
HALL_TOKEN="$(as_user "$HOST_O" "select public.create_invitation('${HALL}', 'leaver@example.com', 'owner') ->> 'token';" | psql_db)"
as_service "select public.admin_delete_account_data('${LEAVER}');" | psql_db >/dev/null 2>"$WORK/leaver_delete.err" &
sleep 0.3
as_user "$LEAVER" "select public.accept_invitation('${HALL_TOKEN}') ->> 'status';" \
  | psql_db >"$WORK/leaver_accept.out" 2>"$WORK/leaver_accept.err" &
as_user "$LEAVER" "select (public.create_portfolio('Replayed offline', '01a1a2ff-0000-7000-8000-00000000beef')).id;" \
  | psql_db >"$WORK/leaver_create.out" 2>"$WORK/leaver_create.err" &
wait
only_errors "never-allowed" "$WORK/leaver_delete.err"
grep -q "ERROR:  account_deleted" "$WORK/leaver_accept.err" || {
  echo "✗ the acceptance was not refused:"
  cat "$WORK"/leaver_accept.*
  exit 1
}
grep -q "ERROR:  account_deleted" "$WORK/leaver_create.err" || {
  echo "✗ the replayed create was not refused:"
  cat "$WORK"/leaver_create.*
  exit 1
}
as_user "$HOST_O" "select public.remove_member('${HALL}', '${HOST_O}');" | psql_db >/dev/null 2>"$WORK/hall_leave.err" || true
grep -q "ERROR:  last_owner" "$WORK/hall_leave.err" || {
  echo "✗ the hall's only owner could leave"
  exit 1
}

# 15. Manual charges and payments on one lease -------------------------------------------
# A manual charge took its lease only after the insert's foreign-key check had
# taken it for key share: a lock upgrade that deadlocked with other writers.
echo "▸ Manual charges and payments on one lease at once (5 rounds)"
reset_limits
BILLER="$(new_user "biller@example.com")"
BILLED="$(new_estate "$BILLER" 'Billed' 1)"
BILLED_LEASE="$(psql_db -c "select id from public.leases where portfolio_id = '${BILLED}'")"
for round in 1 2 3 4 5; do
  for i in 1 2 3 4 5 6; do
    as_user "$BILLER" "insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description) values ('${BILLED}', '${BILLED_LEASE}', 'maintenance', '2026-11-03', 500, 'Repair ${round}.${i}');" \
      | psql_db >/dev/null 2>"$WORK/manual_${round}_${i}.err" &
  done
  for i in 1 2 3; do
    as_user "$BILLER" "select public.record_payment('${BILLED_LEASE}', 300, '2026-11-03', 'cash', gen_random_uuid()) is not null;" \
      | psql_db >/dev/null 2>"$WORK/manual_pay_${round}_${i}.err" &
  done
  wait
done
no_deadlocks "$WORK"/manual_*.err
only_errors "never-allowed" "$WORK"/manual_*.err
[[ "$(psql_db -c "select count(*) from public.charges where lease_id = '${BILLED_LEASE}' and kind = 'maintenance'")" == "30" ]] || {
  echo "✗ manual charges went missing"
  exit 1
}

# 16. Claiming a portfolio's id while it is deleted ---------------------------------------
echo "▸ Claiming a portfolio's id while it is deleted"
reset_limits
VICTIM="$(new_user "victim@example.com")"
CLAIMER="$(new_user "claimer@example.com")"
CLAIMED="$(new_portfolio "$VICTIM" 'Claimed')"
as_user "$VICTIM" "select public.delete_portfolio('${CLAIMED}', 'Claimed'); select pg_sleep(1);" \
  | psql_db >/dev/null 2>"$WORK/claim_delete.err" &
for i in $(seq 1 10); do
  as_user "$CLAIMER" "select public.create_portfolio('Mine', '${CLAIMED}');" \
    | psql_db >/dev/null 2>"$WORK/claim_${i}.err" &
  sleep 0.15
done
wait
only_errors "never-allowed" "$WORK/claim_delete.err"
for i in $(seq 1 10); do
  grep -q "ERROR:  forbidden" "$WORK/claim_${i}.err" || {
    echo "✗ claim ${i} was not refused"
    exit 1
  }
done
[[ "$(psql_db -c "select count(*) from public.portfolios where id = '${CLAIMED}'")" == "0" ]] || {
  echo "✗ a deleted portfolio's id was claimed"
  exit 1
}

# 17. An auth user deleted while a co-owner deletes their portfolio --------------------------
# GoTrue's deleteUser clears created_by on the user's portfolios, leases and
# other rows (ON DELETE SET NULL) in its own order.
echo "▸ An auth user deleted while a co-owner deletes the portfolio they created"
reset_limits
STAYER="$(new_user "stayer@example.com")"
DEPARTED="$(new_user "departed@example.com")"
HANDED="$(new_estate "$STAYER" 'Handed over' 3)"
psql_db >/dev/null <<SQL
update public.portfolios set created_by = '${DEPARTED}' where id = '${HANDED}';
update public.leases set created_by = '${DEPARTED}' where portfolio_id = '${HANDED}';
update public.properties set created_by = '${DEPARTED}' where portfolio_id = '${HANDED}';
SQL
HANDED_LEASE="$(psql_db -c "select id from public.leases where portfolio_id = '${HANDED}' order by id desc limit 1")"
as_user "$STAYER" "select public.record_payment('${HANDED_LEASE}', 1000, '2026-11-03', 'cash', gen_random_uuid()) is not null; select pg_sleep(1);" \
  | psql_db >/dev/null 2>"$WORK/handed_pay.err" &
sleep 0.3
as_user "$STAYER" "select public.delete_portfolio('${HANDED}', 'Handed over');" \
  | psql_db >/dev/null 2>"$WORK/handed_delete.err" &
sleep 0.2
printf "delete from auth.users where id = '%s';\n" "$DEPARTED" | psql_db >/dev/null 2>"$WORK/handed_gotrue.err" &
wait
no_deadlocks "$WORK"/handed_*.err
only_errors "never-allowed" "$WORK"/handed_*.err
[[ "$(psql_db -c "select count(*) from public.portfolios where id = '${HANDED}'")" == "0" ]] || {
  echo "✗ the handed-over portfolio survived"
  exit 1
}

# 18. A tenancy deleted while a charge is added to it (both orders) -------------------------
# Deleting a lease must never take a charge someone entered with it: either the
# charge commits first and the delete is refused, or the delete commits first
# and the charge's foreign key fails. Odd rounds delete first, even rounds
# charge first; each holds its transaction open so the other has to wait.
echo "▸ A tenancy deleted while a charge is added to it (both orders, 6 rounds)"
reset_limits
CLERK="$(new_user "clerk@example.com")"
for round in 1 2 3 4 5 6; do
  ESTATE="$(new_estate "$CLERK" "Mistake ${round}" 1)"
  MISTAKE="$(psql_db -c "select id from public.leases where portfolio_id = '${ESTATE}'")"
  ADD_CHARGE="insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description) values ('${ESTATE}', '${MISTAKE}', 'damages', '2026-11-03', 700, 'Round ${round}');"
  DELETE_LEASE="delete from public.leases where id = '${MISTAKE}';"
  if ((round % 2)); then
    as_user "$CLERK" "${DELETE_LEASE} select pg_sleep(0.5);" | psql_db >/dev/null 2>"$WORK/mistake_del_${round}.err" &
    sleep 0.2
    as_user "$CLERK" "${ADD_CHARGE}" | psql_db >/dev/null 2>"$WORK/mistake_chg_${round}.err" &
  else
    as_user "$CLERK" "${ADD_CHARGE} select pg_sleep(0.5);" | psql_db >/dev/null 2>"$WORK/mistake_chg_${round}.err" &
    sleep 0.2
    as_user "$CLERK" "${DELETE_LEASE}" | psql_db >/dev/null 2>"$WORK/mistake_del_${round}.err" &
  fi
  wait
  LEASE_LEFT="$(psql_db -c "select count(*) from public.leases where id = '${MISTAKE}'")"
  ENTERED_LEFT="$(psql_db -c "select count(*) from public.charges where lease_id = '${MISTAKE}' and source = 'manual'")"
  if ((round % 2)); then
    if [[ "$LEASE_LEFT" != "0" || "$ENTERED_LEFT" != "0" ]] \
      || ! grep -q 'violates foreign key constraint' "$WORK/mistake_chg_${round}.err"; then
      echo "✗ round ${round}: the delete came first, so the charge must fail"
      exit 1
    fi
  else
    if [[ "$LEASE_LEFT" != "1" || "$ENTERED_LEFT" != "1" ]] \
      || ! grep -q "ERROR:  lease_has_records" "$WORK/mistake_del_${round}.err"; then
      echo "✗ round ${round}: the charge came first, so the delete must be refused"
      exit 1
    fi
  fi
done
no_deadlocks "$WORK"/mistake_*.err
only_errors_matching 'lease_has_records|insert or update on table "charges" violates foreign key constraint' \
  "$WORK"/mistake_*.err

# 19. Invariants --------------------------------------------------------------------------
echo "▸ Checking invariants"
RESULT="$(
  psql_db <<SQL
select json_build_object(
  'payments', (select count(*) from public.payments where portfolio_id = '${PORTFOLIO}'),
  'receipts_distinct', (select count(distinct receipt_number) from public.payments where portfolio_id = '${PORTFOLIO}'),
  'receipt_gaps', (
    select count(*) from generate_series(1, (select count(*) from public.payments where portfolio_id = '${PORTFOLIO}')) n
    where not exists (
      select 1 from public.payments
      where portfolio_id = '${PORTFOLIO}' and split_part(receipt_number, '-', 3)::integer = n
    )
  ),
  'ownerless_portfolios', (
    select count(*) from public.portfolios p
    where not exists (
      select 1 from public.portfolio_members m where m.portfolio_id = p.id and m.role = 'owner'
    )
  ),
  'memberless_portfolios', (
    select count(*) from public.portfolios p
    where not exists (select 1 from public.portfolio_members m where m.portfolio_id = p.id)
  ),
  'orphan_documents', (
    select count(*) from public.documents d
    where not exists (
      select 1 from public.properties e where d.entity_type = 'property' and e.id = d.entity_id
      union all select 1 from public.units e where d.entity_type = 'unit' and e.id = d.entity_id
      union all select 1 from public.tenants e where d.entity_type = 'tenant' and e.id = d.entity_id
      union all select 1 from public.leases e where d.entity_type = 'lease' and e.id = d.entity_id
      union all select 1 from public.payments e where d.entity_type = 'payment' and e.id = d.entity_id
      union all select 1 from public.expenses e where d.entity_type = 'expense' and e.id = d.entity_id
      union all select 1 from public.maintenance_requests e
                where d.entity_type = 'maintenance_request' and e.id = d.entity_id
      union all select 1 from public.utility_bills e where d.entity_type = 'utility_bill' and e.id = d.entity_id
      union all select 1 from public.meter_readings e where d.entity_type = 'meter_reading' and e.id = d.entity_id
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
for key in ("duplicate_rent_months", "charge_mismatch", "payment_mismatch", "overpaid",
            "ownerless_portfolios", "memberless_portfolios", "orphan_documents"):
    if r[key] != 0: errors.append(f"{key} = {r[key]}")
if abs(float(r["cash_in"]) - float(r["cash_accounted"])) > 0.001: errors.append("cash not conserved")
if errors:
    print("✗ " + "; ".join(errors)); sys.exit(1)
print("✓ concurrency invariants hold")
PY
