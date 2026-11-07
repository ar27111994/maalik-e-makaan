#!/usr/bin/env bash
# Replays findings F1, F2 and F3 of the LedgerPayments model on a disposable
# database (every migration, through tool/db/reset.sh; connection settings
# from tool/db/env.sh; database mm_fv_ledger, rebuilt on every run).
#
#   F1  a client's two-row UPDATE of charges (rows in scan order, no lease
#       lock) against record_payment and void_payment (rows in due order):
#       PostgreSQL detects a deadlock. The client's WHERE sleeps 0.4 s per
#       row (pg_sleep), only to hold the race window open: the model shows
#       the interleaving needs no sleep. Then the same race against an
#       emulation of the proposed fix (an RPC that takes the lease first).
#   F2  a client raises a manual charge's amount while the lease has
#       credit: the charge stays open next to the credit. Then the fix's
#       emulation (the same RPC applies the credit).
#   F3  credit applied to next month's rent by the billing sync, then
#       end_lease backdated to the month before: the ended lease keeps a
#       live, half-unpaid rent for the month after the move-out. Then the
#       fix's emulation (release later rent's allocations first).
#
# The emulations are created in the disposable database only (functions
# named fv_*); nothing in supabase/migrations changes. Exits 0 when every
# finding reproduces on today's code (F1: at least once in RUNS rounds,
# default 4) and none does under its emulated fix.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export MM_TEST_DB=mm_fv_ledger
OUT="$(mktemp -d "${TMPDIR:-/tmp}/fv-ledger.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" "$@"; }
OWNER=00000000-0000-4000-8000-0000000fe1d1

# The owner's request transaction on day $1 (as PostgREST runs it).
as_owner() {
  cat <<SQL
set app.today_override = '$1';
begin;
set local "request.jwt.claims" to '{"sub":"${OWNER}","role":"authenticated"}';
set local role authenticated;
$2
commit;
SQL
}

"$ROOT/tool/db/reset.sh" >/dev/null
psql_db <<SQL >/dev/null
insert into auth.users (id, email, email_confirmed_at) values ('${OWNER}', 'fv-ledger@example.com', now());
with p as (
  insert into public.portfolios (name, created_by) values ('FV ledger', '${OWNER}') returning id
)
insert into public.portfolio_members (portfolio_id, user_id, role) select id, '${OWNER}', 'owner' from p;

-- A lease starting on p_start (rent 1000, due on the 5th), created on day
-- p_today; with p_manual_due, a manual charge of 500 due then, created
-- before any rent of a later month.
create function public.fv_lease(p_start date, p_today date, p_manual_due date default null)
returns uuid language plpgsql as \$\$
declare
  v_portfolio uuid := (select id from public.portfolios where name = 'FV ledger');
  v_property uuid; v_unit uuid; v_tenant uuid; v_lease uuid;
begin
  perform set_config('app.today_override', p_today::text, true);
  insert into public.properties (portfolio_id, name, city, province)
  values (v_portfolio, 'House ' || gen_random_uuid(), 'Lahore', 'punjab') returning id into v_property;
  insert into public.units (portfolio_id, property_id, label)
  values (v_portfolio, v_property, 'Flat') returning id into v_unit;
  insert into public.tenants (portfolio_id, full_name)
  values (v_portfolio, 'Tenant') returning id into v_tenant;
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
  values (v_portfolio, v_unit, v_tenant, p_start, 1000) returning id into v_lease;
  if p_manual_due is not null then
    insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
    values (v_portfolio, v_lease, 'maintenance', p_manual_due, 500, 'Repair');
  end if;
  return v_lease;
end \$\$;

-- Emulations of the proposed fix (README.md): client charge edits through
-- an RPC that takes the portfolio key and the lease first (the global
-- order), then the rows, then applies the lease's credit.
create function public.fv_edit_charges(p_lease uuid, p_description text)
returns void language plpgsql security definer set search_path = '' as \$\$
begin
  perform private.lock_lease_for_write(p_lease, '{owner,manager,accountant}');
  update public.charges set description = p_description
  where lease_id = p_lease and pg_sleep(0.4) is not null;
end \$\$;
create function public.fv_set_charge_amount(p_charge uuid, p_amount numeric)
returns void language plpgsql security definer set search_path = '' as \$\$
declare v_lease uuid := (select lease_id from public.charges where id = p_charge);
begin
  perform private.lock_lease_for_write(v_lease, '{owner,manager,accountant}');
  update public.charges set amount = p_amount where id = p_charge;
  perform private.apply_lease_credit(v_lease);
end \$\$;
-- F3's fix: release the allocations of rent after the move-out month, then
-- end_lease (which voids it, now unpaid), then re-apply the freed credit.
create function public.fv_end_lease(p_lease uuid, p_moved_out_on date)
returns void language plpgsql security definer set search_path = '' as \$\$
declare a record;
begin
  perform private.lock_lease_for_write(p_lease, '{owner,manager}');
  for a in
    select pa.id, pa.payment_id, pa.charge_id, pa.amount
    from public.payment_allocations pa join public.charges c on c.id = pa.charge_id
    where c.lease_id = p_lease and c.kind = 'rent' and c.voided_at is null
      and c.period_month > date_trunc('month', p_moved_out_on)::date
    order by c.due_date, c.id
  loop
    update public.charges set paid_amount = paid_amount - a.amount where id = a.charge_id;
    update public.payments set allocated_amount = allocated_amount - a.amount where id = a.payment_id;
    delete from public.payment_allocations where id = a.id;
  end loop;
  perform public.end_lease(p_lease, p_moved_out_on, 'tenant_moved_out');
  perform private.apply_lease_credit(p_lease);
end \$\$;
grant execute on function public.fv_edit_charges(uuid, text), public.fv_set_charge_amount(uuid, numeric),
  public.fv_end_lease(uuid, date) to authenticated;
SQL

deadlocks() { psql_db -c "select deadlocks from pg_stat_database where datname = current_database()"; }
reset_limits() { psql_db -c "delete from private.rate_limit_buckets" >/dev/null; }
status=0
expect() { # label, condition (0 = as expected)
  if [[ "$2" == 0 ]]; then echo "ok   $1"; else
    echo "FAIL $1"
    status=1
  fi
}

# F1 ------------------------------------------------------------------------
# A lease starting in December with a manual charge (due 20 December) created
# in November, before December's rent (due 5 December): the charge is first
# in the table, the rent first in due order.
f1_lease() {
  local lease
  lease="$(psql_db -c "select public.fv_lease('2026-12-01', '2026-11-20', '2026-12-20')")"
  psql_db -c "set app.today_override = '2026-12-03'; select private.sync_lease_billing('${lease}')" >/dev/null
  echo "$lease"
}
# $1 tag, $2 the client's statement, $3 the ledger call; the ledger call
# starts 0.5 s after the client's, between its two row locks.
f1_race() {
  local before after
  reset_limits
  before="$(deadlocks)"
  as_owner 2026-12-03 "$2" | psql_db >"$OUT/$1.client" 2>&1 &
  sleep 0.5
  as_owner 2026-12-03 "$3" | psql_db >"$OUT/$1.ledger" 2>&1 || true
  wait || true
  after="$(deadlocks)"
  echo "$((after - before))"
}
echo "F1: client two-row charge UPDATE vs allocate_payment / void_payment"
pay_hits=0
void_hits=0
for round in $(seq 1 "${RUNS:-4}"); do
  lease="$(f1_lease)"
  n="$(f1_race "pay$round" "update public.charges set description = 'Edited' where lease_id = '${lease}' and pg_sleep(0.4) is not null;" \
    "select public.record_payment('${lease}', 1500, '2026-12-03', 'cash', gen_random_uuid()) is not null;")"
  echo "  record_payment round $round: deadlocks detected $n; ledger: $(tr '\n' ' ' <"$OUT/pay$round.ledger" | cut -c1-90); client: $(tr '\n' ' ' <"$OUT/pay$round.client" | cut -c1-60)"
  [[ "$n" -ge 1 ]] && pay_hits=$((pay_hits + 1))

  lease="$(f1_lease)"
  pay="$(as_owner 2026-12-03 "select public.record_payment('${lease}', 1500, '2026-12-03', 'cash', gen_random_uuid()) -> 'payment' ->> 'id';" | psql_db)"
  # The payment rewrote both rows, rent first, so the client's scan (table
  # and index order) now meets the rent first. Rewrite the rent once more
  # (due a day later, still before the manual charge; a changed indexed
  # column, so a new index entry) to put the manual charge first again.
  psql_db -c "update public.charges set due_date = due_date + 1 where lease_id = '${lease}' and kind = 'rent'" >/dev/null
  n="$(f1_race "void$round" "update public.charges set description = 'Edited' where lease_id = '${lease}' and pg_sleep(0.4) is not null;" \
    "select public.void_payment('${pay}', 'Bounced') is not null;")"
  echo "  void_payment round $round: deadlocks detected $n; ledger: $(tr '\n' ' ' <"$OUT/void$round.ledger" | cut -c1-90); client: $(tr '\n' ' ' <"$OUT/void$round.client" | cut -c1-60)"
  [[ "$n" -ge 1 ]] && void_hits=$((void_hits + 1))

  lease="$(f1_lease)"
  n="$(f1_race "fix$round" "select public.fv_edit_charges('${lease}', 'Edited');" \
    "select public.record_payment('${lease}', 1500, '2026-12-03', 'cash', gen_random_uuid()) is not null;")"
  errs="$(cat "$OUT/fix$round.client" "$OUT/fix$round.ledger" | grep -c ERROR || true)"
  echo "  emulated fix round $round: deadlocks detected $n, errors $errs"
  expect "F1 gone under the emulated fix (round $round)" "$([[ "$n" == 0 && "$errs" == 0 ]] && echo 0 || echo 1)"
done
# Whether the client's scan meets the manual charge first in the void round
# depends on where PostgreSQL put the rewritten rent row, so the void race
# is reported per round and must deadlock at least once.
expect "F1 reproduces against record_payment ($pay_hits of ${RUNS:-4} rounds)" "$([[ "$pay_hits" -ge 1 ]] && echo 0 || echo 1)"
expect "F1 reproduces against void_payment ($void_hits of ${RUNS:-4} rounds)" "$([[ "$void_hits" -ge 1 ]] && echo 0 || echo 1)"

# F2 ------------------------------------------------------------------------
echo "F2: a client raises a manual charge's amount while the lease has credit"
f2() { # $1: client statement template (%C = charge id); prints open|credit
  local lease charge
  lease="$(psql_db -c "select public.fv_lease('2026-11-01', '2026-11-03', '2026-11-10')")"
  charge="$(psql_db -c "select id from public.charges where lease_id = '${lease}' and source = 'manual'")"
  as_owner 2026-11-03 "select public.record_payment('${lease}', 2000, '2026-11-03', 'cash', gen_random_uuid()) is not null;" | psql_db >/dev/null
  as_owner 2026-11-03 "${1//%C/$charge}" | psql_db >/dev/null
  psql_db -c "select (select sum(outstanding) from public.charges where lease_id = '${lease}' and voided_at is null)::int
                || '|' || (select sum(unallocated_amount) from public.payments where lease_id = '${lease}' and voided_at is null)::int"
}
reset_limits
got="$(f2 "update public.charges set amount = 800 where id = '%C';")"
echo "  today's code: open dues|credit = $got"
expect "F2 reproduces (open dues next to credit)" "$([[ "${got%|*}" -gt 0 && "${got#*|}" -gt 0 ]] && echo 0 || echo 1)"
got="$(f2 "select public.fv_set_charge_amount('%C', 800);")"
echo "  emulated fix: open dues|credit = $got"
expect "F2 gone under the emulated fix" "$([[ "${got%|*}" == 0 ]] && echo 0 || echo 1)"

# F3 ------------------------------------------------------------------------
echo "F3: end_lease backdated after the sync applied credit to the next month"
f3() { # $1: the end-lease statement template (%L = lease id); prints the November rent
  local lease
  lease="$(psql_db -c "select public.fv_lease('2026-10-01', '2026-10-15')")"
  as_owner 2026-10-15 "select public.record_payment('${lease}', 1500, '2026-10-15', 'cash', gen_random_uuid()) is not null;" | psql_db >/dev/null
  as_owner 2026-11-03 "select public.sync_portfolio_billing((select portfolio_id from public.leases where id = '${lease}')) >= 0;" | psql_db >/dev/null
  as_owner 2026-11-03 "${1//%L/$lease}" | psql_db >/dev/null
  psql_db -c "select l.status || '|' || coalesce(c.voided_at is null, true) || '|' || coalesce(c.paid_amount, 0)::int
                     || '|' || coalesce(c.outstanding, 0)::int
              from public.leases l
              left join public.charges c on c.lease_id = l.id and c.kind = 'rent' and c.period_month = '2026-11-01'
              where l.id = '${lease}'"
}
reset_limits
got="$(f3 "select public.end_lease('%L', '2026-10-31', 'tenant_moved_out') is not null;")"
echo "  today's code: lease status|November rent live|paid|outstanding = $got"
expect "F3 reproduces (ended lease keeps November rent)" "$([[ "$got" == ended\|true\|* ]] && echo 0 || echo 1)"
got="$(f3 "select public.fv_end_lease('%L', '2026-10-31');")"
echo "  emulated fix: lease status|November rent live|paid|outstanding = $got"
expect "F3 gone under the emulated fix" "$([[ "$got" == ended\|false\|* ]] && echo 0 || echo 1)"

exit "$status"
