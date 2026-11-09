#!/usr/bin/env bash
# Replays findings F1, F2 and F3 of LateFees.tla on a plain PostgreSQL server
# with the Supabase shim and every migration (tool/db/reset.sh), and checks
# that 20261107181820_ledger_findings.sql fixed them. Each case starts from a
# fresh disposable database, mm_fv_latefees, which is dropped at the end;
# connection settings come from tool/db/env.sh. Exits non-zero unless every
# check holds.
#
#   F1  a rent paid within grace but recorded after the job ran: its fee is
#       now voided
#   F2  a client's multi-row UPDATE of charges deadlocked with the daily job
#       and with record_payment. Clients can no longer UPDATE charges (the
#       statement is refused); the same statement run as the table owner
#       still deadlocks (the old lock order, so the race is real), and the
#       same edits through update_charge (two calls in one transaction) do
#       not. pg_sleep only widens the window between the two rows.
#   F3  end_lease voided a later month's rent but not its late fee: now both
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
DB=mm_fv_latefees
OUT="$(mktemp -d "${TMPDIR:-/tmp}/fv-latefees.XXXXXX")"
trap 'rm -rf "$OUT"; psql -X -q -d postgres -c "drop database if exists $DB with (force)" >/dev/null 2>&1 || true' EXIT

L1=00000000-0000-4000-8000-0000000000a1
L2=00000000-0000-4000-8000-0000000000a2
q() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

# Two leases from 2026-10-01: rent 1,000 due on the 5th, grace 5 days, a
# daily fee of 100 capped at 1,000.
fresh() {
  MM_TEST_DB="$DB" "$ROOT/tool/db/reset.sh" >/dev/null
  q >/dev/null <<SQL
set app.today_override = '2026-10-01';
with u as (
  insert into auth.users (id, email, email_confirmed_at)
  values (gen_random_uuid(), 'fv-late-fees@example.com', now()) returning id
), p as (insert into public.portfolios (name, created_by) select 'FV', id from u returning id, created_by),
m as (insert into public.portfolio_members (portfolio_id, user_id, role)
      select id, created_by, 'owner' from p returning portfolio_id),
prop as (insert into public.properties (portfolio_id, name, city, province)
         select portfolio_id, 'Tower', 'Lahore', 'punjab' from m returning id, portfolio_id),
un as (insert into public.units (portfolio_id, property_id, label)
       select portfolio_id, id, x from prop, (values ('U1'), ('U2')) v(x) returning id, portfolio_id, label),
te as (insert into public.tenants (portfolio_id, full_name)
       select portfolio_id, 'Tenant ' || label from un returning id, full_name)
insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent,
                           late_fee_type, late_fee_value, late_fee_cap)
select (case un.label when 'U1' then '$L1' else '$L2' end)::uuid, un.portfolio_id, un.id, te.id,
       '2026-10-01', 1000, 'daily', 100, 1000
from un join te on te.full_name = 'Tenant ' || un.label;
SQL
  OWNER="$(q -c "select created_by from public.portfolios limit 1")"
}

# A Data API request as the owner on day $1: statement $2 in one transaction.
as_owner() {
  printf "set app.today_override = '%s';\nbegin;\nset local \"request.jwt.claims\" to '{\"sub\":\"%s\",\"role\":\"authenticated\"}';\nset local role authenticated;\n%s\ncommit;\n" \
    "$1" "$OWNER" "$2"
}
job() { q -c "set app.today_override = '$1'; select private.run_daily_jobs('$1');"; }

status=0
check() { # name, condition result (yes/no)
  echo "--- $1: $2 (expected yes)"
  [[ "$2" == "yes" ]] || status=1
}
# The old client statement as the table owner (clients may no longer run it).
as_table_owner() {
  printf "set app.today_override = '%s';\nbegin;\n%s\ncommit;\n" "$1" "$2"
}
deadlocked() { grep -q 'deadlock detected' "$@" && echo yes || echo no; }
clean() { grep -q 'ERROR' "$@" && echo no || echo yes; }
fee_of() { q -c "select id from public.charges where lease_id = '$1' and kind = 'late_fee'"; }
rent_of() { q -c "select id from public.charges where lease_id = '$1' and kind = 'rent' order by due_date limit 1"; }

echo "=== F1: rent due 2026-10-05, last day of grace 2026-10-10"
fresh
job 2026-10-11 >/dev/null
as_owner 2026-10-11 "select public.record_payment('$L1', 1000, '2026-10-09', 'cash', gen_random_uuid())
                       -> 'payment' ->> 'allocated_amount';" | psql -X -q -At -d "$DB" >/dev/null
job 2026-10-12 >/dev/null
q -c "select kind, due_date, amount, paid_amount, outstanding, voided_at is not null as voided
      from public.charges where lease_id = '$L1' order by due_date"
check "no fee is left on the rent paid on 2026-10-09 (F1 fixed)" \
  "$(q -c "select case when exists (select 1 from public.charges f join public.charges r on r.id = f.related_charge_id
                                  where f.lease_id = '$L1' and f.voided_at is null and r.outstanding = 0)
               then 'no' else 'yes' end")"
check "the fee was voided by the payment" \
  "$(q -c "select case when exists (select 1 from public.charges f where f.lease_id = '$L1' and f.kind = 'late_fee'
                                  and f.void_reason = 'Rent paid within the grace period')
               then 'yes' else 'no' end")"

echo "=== F2: the daily job and a client's multi-row UPDATE of charges"
fresh
# L1's rent due on the 10th; L2's fee capped at 200, so the job stops
# rewriting it and its row stays first in the heap.
q -c "update public.leases set rent_due_day = 10 where id = '$L1';
      update public.leases set late_fee_cap = 200 where id = '$L2';
      update public.charges set due_date = '2026-10-10' where lease_id = '$L1' and kind = 'rent';" >/dev/null
for day in 2026-10-11 2026-10-16 2026-10-17; do job "$day" >/dev/null; done
q -c "select ctid, lease_id, amount from public.charges where kind = 'late_fee' order by ctid"
q -c "create table fv_f2_start as select * from public.charges; create table fv_f2_maint as select * from private.lease_maintenance;" >/dev/null
EDIT="update public.charges set description = 'Edited'
        || case when pg_sleep(2) is null then '' else '' end where kind = 'late_fee';"
as_owner 2026-10-18 "$EDIT" | psql -X -q -At -d "$DB" >"$OUT/refused.out" 2>&1 || true
check "a client's UPDATE of charges is refused" \
  "$(grep -q 'permission denied for table charges' "$OUT/refused.out" && echo yes || echo no)"
as_table_owner 2026-10-18 "$EDIT" | psql -X -q -At -d "$DB" >"$OUT/client.out" 2>&1 &
sleep 3
job 2026-10-18 >"$OUT/job.out" 2>&1 || true
wait || true
cat "$OUT/client.out" "$OUT/job.out"
check "the old statement's lock order still deadlocks with the job" "$(deadlocked "$OUT/client.out" "$OUT/job.out")"
q -c "select lease_id, maintained_on, failures, last_error from private.lease_maintenance order by lease_id"
# The same edits through update_charge, from the same starting rows.
q -c "delete from private.lease_maintenance; insert into private.lease_maintenance select * from fv_f2_maint;
      update public.charges c set amount = s.amount, description = s.description from fv_f2_start s where s.id = c.id;" >/dev/null
as_owner 2026-10-18 "select public.update_charge('$(fee_of "$L2")', null, null, 'Edited') is not null;
                     select pg_sleep(2);
                     select public.update_charge('$(fee_of "$L1")', null, null, 'Edited') is not null;" \
  | psql -X -q -At -d "$DB" >"$OUT/rpc.out" 2>&1 &
sleep 1
job 2026-10-18 >"$OUT/job2.out" 2>&1 || true
wait || true
check "update_charge and the job: no deadlock, no error (F2 fixed)" "$(clean "$OUT/rpc.out" "$OUT/job2.out")"
check "and no lease failed in the job" \
  "$(q -c "select case when exists (select 1 from private.lease_maintenance where failures > 0) then 'no' else 'yes' end")"
q -c "select lease_id, maintained_on, failures, last_error from private.lease_maintenance order by lease_id"

echo "=== F2: record_payment and a client's multi-row UPDATE of charges"
fresh
job 2026-10-11 >/dev/null
# The rent's description edited: its new version goes after the fee in the
# heap, so a sequential scan (a filter on kind has no index) meets the fee
# first, while allocate_payment locks the rent first (due-date order).
q -c "update public.charges set description = 'October' where kind = 'rent' and lease_id = '$L1';" >/dev/null
as_table_owner 2026-10-12 "update public.charges set description = 'Edited'
                       || case when pg_sleep(2) is null then '' else '' end where kind in ('rent', 'late_fee');" \
  | psql -X -q -At -d "$DB" >"$OUT/client.out" 2>&1 &
sleep 5
as_owner 2026-10-12 "select public.record_payment('$L1', 1500, '2026-10-12', 'cash', gen_random_uuid())
                       -> 'payment' ->> 'allocated_amount';" | psql -X -q -At -d "$DB" >"$OUT/pay.out" 2>&1 || true
wait || true
cat "$OUT/client.out" "$OUT/pay.out"
check "the old statement's lock order still deadlocks with record_payment" "$(deadlocked "$OUT/client.out" "$OUT/pay.out")"
fresh
job 2026-10-11 >/dev/null
as_owner 2026-10-12 "select public.update_charge('$(fee_of "$L1")', null, null, 'Edited') is not null;
                     select pg_sleep(2);
                     select public.update_charge('$(rent_of "$L1")', null, null, 'Edited') is not null;" \
  | psql -X -q -At -d "$DB" >"$OUT/rpc.out" 2>&1 &
sleep 1
as_owner 2026-10-12 "select public.record_payment('$L1', 1500, '2026-10-12', 'cash', gen_random_uuid())
                       -> 'payment' ->> 'allocated_amount';" | psql -X -q -At -d "$DB" >"$OUT/pay2.out" 2>&1 || true
wait || true
check "update_charge and record_payment: no deadlock, no error (F2 fixed)" "$(clean "$OUT/rpc.out" "$OUT/pay2.out")"

echo "=== F3: end_lease on 2026-11-12, moved out on 2026-10-31"
fresh
job 2026-11-12 >/dev/null
as_owner 2026-11-12 "select (public.end_lease('$L1', '2026-10-31', 'tenant_moved_out')).status;" \
  | psql -X -q -At -d "$DB" >/dev/null
q -c "select c.kind, c.period_month, c.amount, c.voided_at is not null as voided
      from public.charges c where c.lease_id = '$L1' order by c.kind desc, c.period_month"
check "no live late fee on a voided rent (F3 fixed)" \
  "$(q -c "select case when exists (select 1 from public.charges f join public.charges r on r.id = f.related_charge_id
                                  where f.lease_id = '$L1' and f.voided_at is null and r.voided_at is not null)
               then 'no' else 'yes' end")"
check "November's fee is voided with its rent" \
  "$(q -c "select case when exists (select 1 from public.charges f where f.lease_id = '$L1' and f.kind = 'late_fee'
                                  and f.period_month = '2026-11-01' and f.void_reason = 'Lease ended')
               then 'yes' else 'no' end")"
[[ "$status" -eq 0 ]]
