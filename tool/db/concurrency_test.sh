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
#  18. A tenancy deleted while a charge is added to it (both orders) → the
#      charge fails or the delete is refused; no money record is lost.
#  Scenarios 19 to 28 cover the findings fixed by
#  20261105170557_concurrency_findings.sql; 19 to 26 fail without it. In 19
#  to 24 and 26 to 28 PostgreSQL must detect no deadlock at all
#  (pg_stat_database).
#  19. M1: lease deposits changed while their portfolio or owner account is
#      deleted (32 rounds, four timings) → every deletion completes.
#  20. Updates whose new parent row the deletion's cascade has already taken
#      (expense property, request unit and lease, utility account unit).
#  21. Two units written in turn while their portfolio is deleted.
#  22. Two portfolios updated in turn while a co-owner's account is deleted,
#      and inserts of tenants, documents and manual charges spanning two
#      portfolios while their owner's account is deleted (once more with the
#      lock helper's query planned as a scan in on-disk order).
#  23. Notifications marked read while the account is deleted, by
#      admin_delete_account_data and by GoTrue's user delete.
#  24. S1: a file deleted while a document is attached to it, as the Storage
#      API deletes up to v1.80 (as the user; one object after a row lock) and
#      from v1.81 (row lock, rolled-back probe, delete as superuser), as the
#      probe flow would without its row lock, and as the service role, in
#      every order (also between the probe and the delete), and a two-file
#      batch → never a document without its file, no deadlock.
#  25. S2: an old file attached while the daily sweep and the cleaner run
#      (both orders) → never a document for a queued or deleted file.
#  26. On a pg_dump/restore copy of this database (foreign keys re-created by
#      name): lease deletes, rent day changes, property deletes, and inserts
#      whose first foreign-key check is a row the cascade deletes, while the
#      portfolio is deleted.
#  27. A member removed while their delete or insert waits for the portfolio
#      key → the write is authorised again and does nothing.
#  28. A SECURITY DEFINER function's manual charge while a membership change
#      holds the portfolio → it waits and succeeds (not refused).
#  29. F1 (20261107181820_ledger_findings.sql): a client edits two charges of
#      a lease (manual charge first, then rent: the scan order of the old
#      two-row UPDATE) through update_charge in one transaction, while
#      record_payment or void_payment works the same lease (8 rounds) → no
#      deadlock and no error; the direct UPDATE is refused; no credit is
#      left next to an open due.
#  30. Invitations (20261108082804_invitation_findings.sql; formal/tla/
#      Invitations): F1, two owners re-invite one e-mail at the same moment
#      (both orders, 3 rounds) and in a burst of 8 → every call succeeds, no
#      23505, one invitation stays pending; F3/F4, an inviter's auth user
#      deleted directly in Auth while an acceptance arrives, and in the
#      delete-account order (admin_delete_account_data, then the Auth
#      delete) while an acceptance holds its locks or arrives → no deadlock,
#      the acceptance lands or answers revoked, nothing stays pending.
#  31. Residence (20261112092618_residence.sql), each race in both orders
#      where both exist, the second session always waiting for the first:
#      set_caretaker against a service-role demotion or removal of that
#      manager, update_member_role and remove_member, and the naming owner
#      removed → the caretaker is a manager or nobody, a removed owner names
#      no one; set_owner_abroad asked on the next open by two members → the
#      first answer is kept and audited once, and a demoted manager's answer
#      is refused; a declared residence written while the account is
#      deleted → cleared, and every later write refused (account_deleted);
#      the caretaker's account deleted in the delete-account order while
#      named, deleted or demoted → no deadlock, no caretaker, no Auth user;
#      an operator who locks the portfolio before changing the caretaker's
#      membership, against a membership RPC holding it → no deadlock.
#  32. Invariants: paid_amount = Σ allocations, allocated_amount =
#      Σ allocations, nothing overpaid, cash conserved; no portfolio is left
#      without an owner or without members; no document outlives its entity,
#      references a missing file, or references a file queued for deletion;
#      every caretaker is a manager of their portfolio (CaretakerIsManager)
#      and named with its time; every profile has one residence row, and no
#      account being deleted keeps a declared residence.
#
# Nothing here waits without a limit. PostgreSQL ends every cycle of lock
# waits it can see, but not a wait on anything else (a session idle in its
# transaction because its client stopped, a wait inside the server, a
# statement that never ends), and a bare `wait` waits for every background
# session. So each scenario gives its sessions a lock_timeout, a
# statement_timeout and an idle_in_transaction_session_timeout well above the
# waits it causes on purpose, and runs under a watchdog: past its budget, the
# watchdog prints the scenario's sessions (what each waits for, and on whom)
# and their locks, terminates them and fails the run. Each scenario prints
# its duration.
#
# Exits non-zero on any violation. Uses the local test server (tool/db/env.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export MM_TEST_DB="${MM_TEST_DB}_concurrency"
MAIN_DB="$MM_TEST_DB"
RESTORED_DB="${MAIN_DB}_restored"
# The caller's session options; each scenario adds its timeouts to them.
BASE_PGOPTIONS="${PGOPTIONS:-}"
# A server that stops answering fails a connection instead of holding it.
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-30}"

WORK="$(mktemp -d)"
psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" "$@"; }
drop_restored() {
  PGOPTIONS="-c client_min_messages=warning -c statement_timeout=60s" \
    psql -X -q -d postgres -c "drop database if exists ${RESTORED_DB} with (force)"
}

# Scenarios and their watchdog --------------------------------------------------------
# The watchdog prints to the suite's own output (fd 3), never into the
# command substitution that starts it.
exec 3>&1
SCENARIO=""
SCENARIO_STARTED=""
SCENARIO_LOCK_WAIT=30
WATCHDOG=""
SUITE_STARTED="${EPOCHREALTIME/[.,]/}"
SCENARIOS_DONE=0
# Seconds since the microsecond timestamp $1, as "12.3 s".
elapsed() {
  local us=$((${EPOCHREALTIME/[.,]/} - $1))
  printf '%d.%d s' $((us / 1000000)) $((us % 1000000 / 100000))
}
# scenario BUDGET LOCK_WAIT TITLE: ends the scenario before it, then starts
# this one. BUDGET is how many seconds the whole scenario may take before the
# watchdog stops it; LOCK_WAIT how long one statement may wait for a lock.
# A statement may run twice that long in all, and a session may sit idle in
# a transaction that long (psql sends its statements back to back, so none
# does on purpose). The waits a scenario causes last a few seconds at most,
# and a long cascade (12, 14) under a minute on CI.
scenario() {
  local options
  scenario_done
  SCENARIO="$3"
  SCENARIO_LOCK_WAIT="$2"
  echo "▸ $3"
  options="${BASE_PGOPTIONS} -c lock_timeout=${2}s -c statement_timeout=$((2 * $2))s"
  export PGOPTIONS="${options} -c idle_in_transaction_session_timeout=${2}s"
  SCENARIO_STARTED="${EPOCHREALTIME/[.,]/}"
  # Started from a command substitution, the watchdog is not a job of this
  # shell, so a bare `wait` does not wait for it.
  WATCHDOG="$(
    watchdog "$1" >&3 2>&3 &
    echo $!
  )"
}
# Stops the watchdog of the scenario that just passed and prints its duration.
scenario_done() {
  if [[ -n "$WATCHDOG" ]]; then
    kill "$WATCHDOG" 2>/dev/null || true
    WATCHDOG=""
    SCENARIOS_DONE=$((SCENARIOS_DONE + 1))
    echo "  done in $(elapsed "$SCENARIO_STARTED")"
  fi
}
# The sessions of this run's databases, what each waits for and on whom, then
# the locks they hold or wait for (relation names from each session's own
# database).
# Runs psql with a client-side deadline of 15 s: statement_timeout needs a
# server that still answers, and PGCONNECT_TIMEOUT only bounds connecting, so
# a server that stops replying on an open connection could otherwise hold the
# report, or the watchdog, for ever. Without timeout(1) (coreutils), psql runs
# unbounded and the watchdog's own stop timer (below) still ends the run.
bounded_psql() {
  if command -v timeout >/dev/null; then
    PGOPTIONS="-c statement_timeout=10s" timeout --kill-after=5 15 psql "$@"
  else
    PGOPTIONS="-c statement_timeout=10s" psql "$@"
  fi
}
report_sessions() {
  local db
  bounded_psql -X -P pager=off -d postgres -c "
    select pid, datname, state, wait_event_type, wait_event, pg_blocking_pids(pid) as blocked_by,
           date_trunc('second', now() - xact_start) as in_transaction,
           date_trunc('second', now() - state_change) as in_state,
           left(regexp_replace(query, '\s+', ' ', 'g'), 160) as query
    from pg_stat_activity
    where datname in ('${MAIN_DB}', '${RESTORED_DB}') and pid <> pg_backend_pid()
    order by datname, pid" || true
  for db in "$MAIN_DB" "$RESTORED_DB"; do
    bounded_psql -X -P pager=off -d "$db" -c "
      select l.pid, l.granted, l.mode, l.locktype,
             coalesce(l.relation::regclass::text, '') as relation, l.page, l.tuple,
             l.transactionid, l.virtualxid, l.classid, l.objid, l.objsubid
      from pg_locks l join pg_stat_activity a on a.pid = l.pid
      where a.datname = current_database() and a.pid <> pg_backend_pid()
        and l.locktype <> 'virtualxid'
      order by l.granted, l.pid, l.locktype" 2>/dev/null || true
  done
}
# Runs in the background for one scenario: returns quietly when the suite has
# gone; after $1 seconds it reports the scenario's sessions, terminates them
# (so every psql the suite waits for returns) and stops the suite.
watchdog() {
  local deadline=$((SECONDS + $1))
  trap - EXIT USR1
  while ((SECONDS < deadline)); do
    sleep 1
    kill -0 "$$" 2>/dev/null || exit 0
  done
  # The stop does not depend on the database answering: whatever the report
  # and the terminate below do, the suite is told to stop 60 s from now. The
  # timer is a program of its own (bash -c), not a subshell: a subshell keeps
  # bash's saved copies of the suite's output, so a caller reading that output
  # through a pipe would wait for the timer; a new program drops them.
  bash -c 'sleep 60; kill -USR1 "$1" 2>/dev/null || exit 0; sleep 15; kill -TERM "$1" 2>/dev/null' \
    stop-timer "$$" </dev/null >/dev/null 2>&1 3>&- &
  echo "✗ ${SCENARIO}: still running after $1 s. Its sessions and their locks:"
  report_sessions
  echo "✗ ${SCENARIO}: terminating its sessions and stopping the run"
  bounded_psql -X -q -At -d postgres -c "
    select count(pg_terminate_backend(pid)) from pg_stat_activity
    where datname in ('${MAIN_DB}', '${RESTORED_DB}') and backend_type = 'client backend'
      and pid <> pg_backend_pid()" >/dev/null 2>&1 || true
  kill -USR1 "$$" 2>/dev/null || exit 0
  # The suite stops at once if it is in `wait`, or as soon as its current
  # command returns; if that does not happen, end it.
  for _ in $(seq 1 15); do
    sleep 1
    kill -0 "$$" 2>/dev/null || exit 0
  done
  kill -TERM "$$" 2>/dev/null || true
}
# Every exit but a passing run's says where the run stopped.
cleanup() {
  local status=$?
  if [[ -n "$WATCHDOG" ]]; then
    kill "$WATCHDOG" 2>/dev/null || true
    echo "✗ stopped in ${SCENARIO} after $(elapsed "$SCENARIO_STARTED") (status ${status})"
  fi
  rm -rf "$WORK"
  drop_restored >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 1' USR1

# Ordering sessions ------------------------------------------------------------------
# A race needs its sessions in a set order: the first holds its locks, and the
# second arrives while it does. Sleeps cannot promise that on a loaded machine
# (a session started 0.3 s earlier may not have connected yet, or may have
# finished already), so the first session holds its transaction open in
# fv.hold(gate) instead of pg_sleep, the suite waits until it is there and the
# second session is waiting for it (await_session), then opens the gate.
# await_session holding NAME: the session whose application_name is NAME
#   (PGAPPNAME) has reached fv.hold, so it holds every lock it took before.
# await_session waiting NAME HOLDER: session NAME waits for a lock (wait
#   event Lock) that session HOLDER holds (pg_blocking_pids).
# Either fails the run, with the sessions and their locks, after the
# scenario's lock wait.
await_session() {
  local condition deadline=$((SECONDS + SCENARIO_LOCK_WAIT))
  case "$1" in
    holding) condition="a.state = 'active' and a.query like '%fv.hold(%'" ;;
    waiting)
      condition="a.wait_event_type = 'Lock' and exists (
                   select 1 from pg_stat_activity h
                   where h.datname = a.datname and h.application_name = '$3'
                     and h.pid = any (pg_blocking_pids(a.pid)))"
      ;;
  esac
  local count
  # A poll that fails (the query errors, or prints nothing) is not a match: it
  # is retried until the deadline, so a dropped connection can never open the
  # gate before the session is really there.
  while true; do
    if count="$(psql_db -c "select count(*) from pg_stat_activity a
                            where a.datname = current_database() and a.application_name = '$2'
                              and ${condition}")" \
      && [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)); then
      return 0
    fi
    if ((SECONDS >= deadline)); then
      echo "✗ ${SCENARIO}: session $2 was not $1${3:+ on $3} after ${SCENARIO_LOCK_WAIT} s"
      report_sessions
      exit 1
    fi
    sleep 0.05
  done
}
# Lets the session holding gate $1 commit.
open_gate() { psql_db -c "insert into fv.gates (name) values ('$1')" >/dev/null; }

scenario 300 60 "0. A fresh database and the fixture"
# The migrations run as tool/db/reset.sh runs them for everyone, under the
# watchdog only.
PGOPTIONS="${BASE_PGOPTIONS:--c client_min_messages=warning}" "$ROOT/tool/db/reset.sh" >/dev/null
# The gates, in this test database only. fv.hold waits for its gate as long as
# the scenario's statement_timeout allows; it holds no lock of its own.
psql_db >/dev/null <<'SQL'
create schema fv;
create table fv.gates (name text primary key);
create function fv.hold(p_gate text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  while not exists (select 1 from fv.gates g where g.name = p_gate) loop
    perform pg_sleep(0.02);
  end loop;
end
$$;
grant usage on schema fv to authenticated, service_role;
grant execute on function fv.hold(text) to authenticated, service_role;
SQL

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
echo "  fixture ready (lease ${LEASE})"

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
scenario 60 30 "1. 40 parallel payments with distinct keys"
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
scenario 60 30 "2. 25 parallel retries with one idempotency key"
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
scenario 60 30 "3. 10 billing syncs racing 10 payments"
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
scenario 180 30 "4. The daily job racing billing syncs and payments over 121 leases (${JOB_ROUNDS} rounds)"
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
scenario 60 30 "5. The daily job skips a lease that a user transaction holds"
PGAPPNAME=mm_holder psql_db >/dev/null 2>"$WORK/holder.err" <<SQL &
begin;
select 1 from public.leases where id = '${LEASE}' for update;
select fv.hold('busy_lease');
commit;
SQL
HOLDER=$!
await_session holding mm_holder
START="$(date +%s%N)"
BUSY="$(run_job 2026-11-20 1000 "->> 'leases_busy'" | psql_db)"
ELAPSED_MS=$((($(date +%s%N) - START) / 1000000))
# The lease stays held until the job has returned, so a job that waited for
# it would have run into its lock_timeout and counted it failed, not busy.
open_gate busy_lease
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
echo "  skipped the busy lease in ${ELAPSED_MS} ms"

# 6. One idempotency key, two leases, in parallel ---------------------------------------
scenario 60 30 "6. 10 parallel payments sharing one key across two leases"
reset_limits
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
scenario 60 30 "7. An owner removed mid-request cannot change roles"
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
scenario 60 30 "8. Co-owners deleting their accounts at once never orphan their portfolio"
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
scenario 120 30 "9. Portfolios deleted while payments, a billing sync and the daily job run"
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
scenario 60 30 "10. Invitations accepted while their portfolio is deleted"
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
scenario 120 30 "11. Child rows, a new lease and a billing sync racing a portfolio deletion"
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
scenario 480 180 "12. A document renamed while its portfolio's long cascade runs"
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
scenario 60 30 "13. Documents attached while their tenant is deleted (both orders)"
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
scenario 240 90 "14. An account being deleted can neither join nor create portfolios"
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
scenario 120 30 "15. Manual charges and payments on one lease at once (5 rounds)"
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
scenario 60 30 "16. Claiming a portfolio's id while it is deleted"
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
scenario 60 30 "17. An auth user deleted while a co-owner deletes the portfolio they created"
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
# charge first; the first holds its transaction open until the other waits for it.
scenario 120 30 "18. A tenancy deleted while a charge is added to it (both orders, 6 rounds)"
reset_limits
CLERK="$(new_user "clerk@example.com")"
for round in 1 2 3 4 5 6; do
  ESTATE="$(new_estate "$CLERK" "Mistake ${round}" 1)"
  MISTAKE="$(psql_db -c "select id from public.leases where portfolio_id = '${ESTATE}'")"
  ADD_CHARGE="insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description) values ('${ESTATE}', '${MISTAKE}', 'damages', '2026-11-03', 700, 'Round ${round}');"
  DELETE_LEASE="delete from public.leases where id = '${MISTAKE}';"
  if ((round % 2)); then
    FIRST="$DELETE_LEASE" FIRST_ERR=mistake_del SECOND="$ADD_CHARGE" SECOND_ERR=mistake_chg
  else
    FIRST="$ADD_CHARGE" FIRST_ERR=mistake_chg SECOND="$DELETE_LEASE" SECOND_ERR=mistake_del
  fi
  as_user "$CLERK" "${FIRST} select fv.hold('mistake_${round}');" \
    | PGAPPNAME=mm_first psql_db >/dev/null 2>"$WORK/${FIRST_ERR}_${round}.err" &
  await_session holding mm_first
  as_user "$CLERK" "$SECOND" | PGAPPNAME=mm_second psql_db >/dev/null 2>"$WORK/${SECOND_ERR}_${round}.err" &
  await_session waiting mm_second mm_first
  open_gate "mistake_${round}"
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

# Helpers for scenarios 19 to 29 ---------------------------------------------------------
# PostgreSQL counts the deadlocks it detects in each database; a deletion that
# retries hides its deadlocks from its caller, so this is the only reliable
# count. A session adds to it as it exits, just after it leaves
# pg_stat_activity, so this waits for the other sessions to go, then a moment.
deadlocks() {
  local _
  for _ in $(seq 1 100); do
    [[ "$(psql_db -c "select count(*) from pg_stat_activity
                       where datname = current_database() and backend_type = 'client backend'
                         and pid <> pg_backend_pid()")" == "0" ]] && break
    sleep 0.05
  done
  sleep 0.3
  psql_db -c "select deadlocks from pg_stat_database where datname = current_database()"
}
# These scenarios run every case, print each failing one, and stop at the end
# of the scenario, so one run shows every case a change breaks.
FAILURES=()
fail_case() {
  FAILURES+=("$1")
  echo "  ✗ $1"
}
end_scenario() {
  if ((${#FAILURES[@]} > 0)); then
    echo "✗ $1: ${#FAILURES[@]} failing case(s)"
    exit 1
  fi
}
# Records a failing case $1 unless every error in the files matches ERE $2.
check_errors() {
  local label="$1" allowed="$2" file
  shift 2
  for file in "$@"; do
    if [[ -s "$file" ]] && grep "ERROR:" "$file" | grep -qvE "ERROR:  (${allowed})"; then
      fail_case "${label}: $(basename "$file"): $(grep -m1 'ERROR:' "$file")"
    fi
  done
}
# Records a failing case $1 if PostgreSQL detected a deadlock since count $2.
check_deadlocks() {
  local found
  found=$(($(deadlocks) - $2))
  ((found == 0)) || fail_case "$1: ${found} deadlock(s) detected"
  return 0
}
# Holds the tenants of portfolio $1 (key share) for a second: a deletion that
# starts meanwhile holds the portfolio and waits at its tenants, before its
# cascade reaches the leases, as a large cascade takes that long. It takes
# no part in any cycle.
hold_tenants() {
  psql_db >/dev/null 2>&1 <<SQL
begin;
select 1 from public.tenants where portfolio_id = '$1' for key share;
select pg_sleep(1);
commit;
SQL
}
# Records a failing case $1 unless portfolio $2 is gone.
check_deleted() {
  [[ "$(psql_db -c "select count(*) from public.portfolios where id = '$2'")" == "0" ]] \
    || fail_case "$1: the portfolio survived its deletion"
}
# The Storage API deleting as user $1: row security applies, and it allows
# deletes on storage tables (storage.allow_delete_query) like the real API.
as_storage_user() {
  cat <<SQL
begin;
set local "request.jwt.claims" to '{"sub":"$1","role":"authenticated"}';
set local role authenticated;
set local storage.allow_delete_query = 'true';
$2
commit;
SQL
}

# 19. M1: a lease's deposit changed while its portfolio is deleted -----------------------
# The deposit trigger inserts a charge and allocates credit; their foreign keys
# take the portfolio key after the UPDATE locked the lease, while a deletion
# holds the portfolio and its cascade waits for the lease. Four kinds of round:
#   client_first  the manager's transaction locks the lease, the deletion starts,
#                 then the deposit changes (the trigger's insert, a moment later);
#   plain         the deletion starts first and is held up before its cascade
#                 reaches the lease (hold_tenants); the app's single UPDATE
#                 arrives meanwhile;
#   account       as plain, but the owner's account is deleted instead;
#   forced_late   as plain, but the client's transaction locks the lease first.
# Every deletion must complete, every client write commit (possibly finding
# nothing left) or fail with a loser's error, and no deadlock may occur.
M1_ROUNDS=32
M1_KINDS=(forced_late client_first plain account)
scenario 600 30 "19. M1: lease deposits changed while their portfolio or owner is deleted (${M1_ROUNDS} rounds)"
FAILURES=()
declare -A M1_DEADLOCKS=([client_first]=0 [plain]=0 [account]=0 [forced_late]=0)
for round in $(seq 1 "$M1_ROUNDS"); do
  reset_limits
  kind="${M1_KINDS[$((round % 4))]}"
  M1_OWNER="$(new_user "m1-owner-${round}@example.com")"
  M1_MANAGER="$(new_user "m1-manager-${round}@example.com")"
  M1_ESTATE="$(new_estate "$M1_OWNER" "Deposit ${round}" 1)"
  add_member "$M1_ESTATE" "$M1_MANAGER" manager
  M1_LEASE="$(psql_db -c "select id from public.leases where portfolio_id = '${M1_ESTATE}'")"
  HOLD="update public.leases set notes = 'Deposit under review' where id = '${M1_LEASE}'; select pg_sleep(0.8);"
  CHANGE="update public.leases set security_deposit = $((50000 + round)) where id = '${M1_LEASE}';"
  if [[ "$kind" == account ]]; then
    REMOVE="$(as_service "select public.admin_delete_account_data('${M1_OWNER}');")"
  else
    REMOVE="$(as_user "$M1_OWNER" "select public.delete_portfolio('${M1_ESTATE}', 'Deposit ${round}');")"
  fi
  BEFORE="$(deadlocks)"
  if [[ "$kind" == client_first ]]; then
    as_user "$M1_MANAGER" "${HOLD} ${CHANGE}" | psql_db >/dev/null 2>"$WORK/m1_client_${round}.err" &
    sleep 0.3
    psql_db <<<"$REMOVE" >/dev/null 2>"$WORK/m1_delete_${round}.err" &
  else
    hold_tenants "$M1_ESTATE" &
    sleep 0.1
    psql_db <<<"$REMOVE" >/dev/null 2>"$WORK/m1_delete_${round}.err" &
    sleep 0.3
    WRITE="$CHANGE"
    [[ "$kind" == forced_late ]] && WRITE="${HOLD} ${CHANGE}"
    as_user "$M1_MANAGER" "$WRITE" | psql_db >/dev/null 2>"$WORK/m1_client_${round}.err" &
  fi
  wait
  FOUND=$(($(deadlocks) - BEFORE))
  M1_DEADLOCKS[$kind]=$((${M1_DEADLOCKS[$kind]} + FOUND))
  ((FOUND == 0)) || fail_case "round ${round} (${kind}): ${FOUND} deadlock(s) detected"
  check_errors "round ${round} (${kind}) deletion" "never-allowed" "$WORK/m1_delete_${round}.err"
  check_errors "round ${round} (${kind}) client" "$LOSER_ERRORS" "$WORK/m1_client_${round}.err"
  check_deleted "round ${round} (${kind})" "$M1_ESTATE"
done
echo "  deadlocks detected: client_first ${M1_DEADLOCKS[client_first]}, plain ${M1_DEADLOCKS[plain]}," \
  "account ${M1_DEADLOCKS[account]}, forced_late ${M1_DEADLOCKS[forced_late]}"
end_scenario "M1"

# 20. An UPDATE whose new parent the deletion's cascade took first -------------------------
# Changing a foreign key column checks the new parent row (key share) after
# the row itself is locked. The deletion deletes properties, units and leases
# before maintenance requests, expenses and utility accounts, so it can hold
# the new parent while it waits for the row.
scenario 180 30 "20. Updates whose new parent the deletion's cascade has already taken"
FAILURES=()
for case in expense_property request_unit request_lease account_unit; do
  reset_limits
  FK_OWNER="$(new_user "fk-owner-${case}@example.com")"
  FK_MANAGER="$(new_user "fk-manager-${case}@example.com")"
  FK_ESTATE="$(new_estate "$FK_OWNER" "Parents ${case}" 2)"
  add_member "$FK_ESTATE" "$FK_MANAGER" manager
  read -r FK_P1 FK_U1 FK_P2 FK_L2 < <(psql_db -F ' ' -c "
    select string_agg(u.property_id || ' ' || u.id, ' ' order by l.id) filter (where l.n = 1),
           string_agg(u.property_id || ' ' || l.id, ' ' order by l.id) filter (where l.n = 2)
    from (select x.*, row_number() over (order by x.id) as n
          from public.leases x where x.portfolio_id = '${FK_ESTATE}') l
    join public.units u on u.id = l.unit_id")
  FK_SPARE="$(psql_db -c "insert into public.units (portfolio_id, property_id, label)
                          values ('${FK_ESTATE}', '${FK_P1}', 'Spare') returning id")"
  case "$case" in
    expense_property)
      FK_TABLE=expenses HOLD_SET="notes = 'Checking'" CHANGE_SET="property_id = '${FK_P2}'"
      FK_ROW="$(psql_db -c "insert into public.expenses (portfolio_id, property_id, category, amount, spent_on)
                            values ('${FK_ESTATE}', '${FK_P1}', 'repairs_maintenance', 1500, '2026-11-01') returning id")"
      ;;
    request_unit | request_lease)
      FK_TABLE=maintenance_requests HOLD_SET="description = 'Checking'" CHANGE_SET="unit_id = '${FK_SPARE}'"
      [[ "$case" == request_lease ]] && CHANGE_SET="lease_id = '${FK_L2}'"
      FK_ROW="$(psql_db -c "insert into public.maintenance_requests (portfolio_id, property_id, unit_id, title)
                            values ('${FK_ESTATE}', '${FK_P1}', '${FK_U1}', 'Leaking tap') returning id")"
      ;;
    account_unit)
      FK_TABLE=utility_accounts HOLD_SET="notes = 'Checking'" CHANGE_SET="unit_id = '${FK_SPARE}'"
      FK_ROW="$(psql_db -c "insert into public.utility_accounts (portfolio_id, property_id, unit_id, type)
                            values ('${FK_ESTATE}', '${FK_P1}', '${FK_U1}', 'electricity') returning id")"
      ;;
  esac
  BEFORE="$(deadlocks)"
  as_user "$FK_MANAGER" "update public.${FK_TABLE} set ${HOLD_SET} where id = '${FK_ROW}'; select pg_sleep(0.8);
                         update public.${FK_TABLE} set ${CHANGE_SET} where id = '${FK_ROW}';" \
    | psql_db >/dev/null 2>"$WORK/fk_${case}_client.err" &
  sleep 0.3
  as_user "$FK_OWNER" "select public.delete_portfolio('${FK_ESTATE}', 'Parents ${case}');" \
    | psql_db >/dev/null 2>"$WORK/fk_${case}_delete.err" &
  wait
  check_deadlocks "$case" "$BEFORE"
  check_errors "${case} deletion" "never-allowed" "$WORK/fk_${case}_delete.err"
  check_errors "${case} client" "$LOSER_ERRORS" "$WORK/fk_${case}_client.err"
  check_deleted "$case" "$FK_ESTATE"
done
end_scenario "new parents taken by the cascade"

# 21. Rows of one write locked in another order than the cascade's ------------------------
# A multi-row UPDATE locks its rows in scan order, the deletion's cascade in
# its own. The client's transaction locks two units one after the other, in
# both orders: one of them is the opposite of the cascade's.
scenario 120 30 "21. Two units written in turn while their portfolio is deleted (both orders)"
FAILURES=()
for order in forward backward; do
  reset_limits
  MR_OWNER="$(new_user "rows-owner-${order}@example.com")"
  MR_MANAGER="$(new_user "rows-manager-${order}@example.com")"
  MR_ESTATE="$(new_estate "$MR_OWNER" "Rows ${order}" 2)"
  add_member "$MR_ESTATE" "$MR_MANAGER" manager
  mapfile -t MR_UNITS < <(psql_db -c "select id from public.units where portfolio_id = '${MR_ESTATE}' order by created_at, id")
  [[ "$order" == backward ]] && MR_UNITS=("${MR_UNITS[1]}" "${MR_UNITS[0]}")
  BEFORE="$(deadlocks)"
  as_user "$MR_MANAGER" "update public.units set notes = 'Repainted' where id = '${MR_UNITS[0]}'; select pg_sleep(0.8);
                         update public.units set notes = 'Repainted' where id = '${MR_UNITS[1]}';" \
    | psql_db >/dev/null 2>"$WORK/rows_${order}_client.err" &
  sleep 0.3
  as_user "$MR_OWNER" "select public.delete_portfolio('${MR_ESTATE}', 'Rows ${order}');" \
    | psql_db >/dev/null 2>"$WORK/rows_${order}_delete.err" &
  wait
  check_deadlocks "$order" "$BEFORE"
  check_errors "${order} deletion" "never-allowed" "$WORK/rows_${order}_delete.err"
  check_errors "${order} client" "$LOSER_ERRORS" "$WORK/rows_${order}_client.err"
  check_deleted "$order" "$MR_ESTATE"
done
end_scenario "multi-row writes"

# 22. Portfolios updated in turn while a co-owner's account is deleted ---------------------
# admin_delete_account_data locks all of the account's portfolios in id order;
# an owner updating two of them locked them in scan order.
scenario 300 30 "22. Two portfolios updated in turn (both orders), and inserts spanning two, while an owner's account is deleted"
FAILURES=()
for order in forward backward; do
  reset_limits
  PF_STAYER="$(new_user "pf-stayer-${order}@example.com")"
  PF_LEAVER="$(new_user "pf-leaver-${order}@example.com")"
  PF_FIRST="$(new_portfolio "$PF_STAYER" "Pair A ${order}")"
  PF_SECOND="$(new_portfolio "$PF_STAYER" "Pair B ${order}")"
  add_member "$PF_FIRST" "$PF_LEAVER" owner
  add_member "$PF_SECOND" "$PF_LEAVER" owner
  mapfile -t PF_IDS < <(psql_db -c "select id from public.portfolios where id in ('${PF_FIRST}', '${PF_SECOND}') order by id")
  [[ "$order" == backward ]] && PF_IDS=("${PF_IDS[1]}" "${PF_IDS[0]}")
  BEFORE="$(deadlocks)"
  as_user "$PF_STAYER" "update public.portfolios set landlord_name = 'Stayer' where id = '${PF_IDS[0]}'; select pg_sleep(0.8);
                        update public.portfolios set landlord_name = 'Stayer' where id = '${PF_IDS[1]}';" \
    | psql_db >/dev/null 2>"$WORK/pf_${order}_client.err" &
  sleep 0.3
  as_service "select public.admin_delete_account_data('${PF_LEAVER}');" \
    | psql_db >/dev/null 2>"$WORK/pf_${order}_delete.err" &
  wait
  check_deadlocks "$order" "$BEFORE"
  check_errors "${order} account deletion" "never-allowed" "$WORK/pf_${order}_delete.err"
  check_errors "${order} client" "$LOSER_ERRORS" "$WORK/pf_${order}_client.err"
  [[ "$(psql_db -c "select count(*) from public.portfolio_members where user_id = '${PF_LEAVER}'")" == "0" ]] \
    || fail_case "${order}: the deleted account kept its memberships"
done
# One INSERT of rows of both portfolios, the higher id first: its rows took
# the portfolio keys in row order (foreign-key checks, or the BEFORE ROW
# triggers of documents and manual charges). A session holds the higher one's
# key for a second, so the deletion of their sole owner's account holds the
# lower one and waits; the manager's insert arrives meanwhile.
hold_portfolio_key() {
  psql_db >/dev/null 2>&1 <<SQL
begin;
select 1 from public.portfolios where id = '$1' for key share;
select pg_sleep(1);
commit;
SQL
}
# tenants_physical: the tenants insert again, but its session plans the lock
# helper's query as a sequential scan (as a large portfolios table could),
# and the lower id's row is moved after the higher one's on disk: only the
# helper's ORDER BY then keeps the keys in id order.
for table in tenants documents charges tenants_physical; do
  reset_limits
  SP_OWNER="$(new_user "spread-owner-${table}@example.com")"
  SP_MANAGER="$(new_user "spread-manager-${table}@example.com")"
  SP_FIRST="$(new_estate "$SP_OWNER" "Spread A ${table}" 1)"
  SP_SECOND="$(new_estate "$SP_OWNER" "Spread B ${table}" 1)"
  add_member "$SP_FIRST" "$SP_MANAGER" manager
  add_member "$SP_SECOND" "$SP_MANAGER" manager
  # One row per portfolio, the higher id first: portfolio, lease, tenant, a new file.
  mapfile -t SP_ROWS < <(psql_db -F ' ' -c "
    select l.portfolio_id, l.id, l.tenant_id, l.portfolio_id || '/tenant/' || l.tenant_id || '/' || gen_random_uuid() || '.jpg'
    from public.leases l where l.portfolio_id in ('${SP_FIRST}', '${SP_SECOND}') order by l.portfolio_id desc")
  read -r SP_HIGH SP_HIGH_LEASE SP_HIGH_TENANT SP_HIGH_FILE <<<"${SP_ROWS[0]}"
  read -r SP_LOW SP_LOW_LEASE SP_LOW_TENANT SP_LOW_FILE <<<"${SP_ROWS[1]}"
  case "$table" in
    tenants | tenants_physical)
      SP_INSERT="insert into public.tenants (portfolio_id, full_name)
                 values ('${SP_HIGH}', 'Applicant'), ('${SP_LOW}', 'Applicant');"
      if [[ "$table" == tenants_physical ]]; then
        # The table is rewritten in descending id order (CLUSTER on a scratch
        # index). Updating the lower id's row until it moved did not always
        # work: a HOT update takes the page's lowest free line pointer, and
        # once vacuum or pruning has freed those of deleted portfolios below
        # the higher id's, every new version lands there again.
        psql_db >/dev/null <<'SQL'
create index fv_portfolios_id_desc on public.portfolios (id desc);
cluster public.portfolios using fv_portfolios_id_desc;
drop index fv_portfolios_id_desc;
SQL
        [[ "$(psql_db -c "select (select ctid from public.portfolios where id = '${SP_LOW}')
                                 > (select ctid from public.portfolios where id = '${SP_HIGH}')")" == "t" ]] \
          || fail_case "tenants_physical: could not store the lower id after the higher one"
        SP_INSERT="set local enable_indexscan = off; set local enable_indexonlyscan = off;
                   set local enable_bitmapscan = off; ${SP_INSERT}"
      fi
      ;;
    documents)
      psql_db -c "insert into storage.objects (bucket_id, name)
                  values ('documents', '${SP_HIGH_FILE}'), ('documents', '${SP_LOW_FILE}')" >/dev/null
      SP_INSERT="insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
                 values ('${SP_HIGH}', 'tenant', '${SP_HIGH_TENANT}', '${SP_HIGH_FILE}', 'cnic.jpg', 'image/jpeg', 1000),
                        ('${SP_LOW}', 'tenant', '${SP_LOW_TENANT}', '${SP_LOW_FILE}', 'cnic.jpg', 'image/jpeg', 1000);"
      ;;
    charges)
      SP_INSERT="insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
                 values ('${SP_HIGH}', '${SP_HIGH_LEASE}', 'other', '2026-11-10', 1500, 'Plumber'),
                        ('${SP_LOW}', '${SP_LOW_LEASE}', 'other', '2026-11-10', 1500, 'Plumber');"
      ;;
  esac
  BEFORE="$(deadlocks)"
  hold_portfolio_key "$SP_HIGH" &
  sleep 0.1
  as_service "select public.admin_delete_account_data('${SP_OWNER}');" \
    | psql_db >/dev/null 2>"$WORK/sp_${table}_delete.err" &
  sleep 0.3
  as_user "$SP_MANAGER" "$SP_INSERT" | psql_db >/dev/null 2>"$WORK/sp_${table}_client.err" &
  wait
  check_deadlocks "${table} insert" "$BEFORE"
  check_errors "${table} account deletion" "never-allowed" "$WORK/sp_${table}_delete.err"
  check_errors "${table} insert" "$LOSER_ERRORS" "$WORK/sp_${table}_client.err"
  check_deleted "${table} insert (higher id)" "$SP_HIGH"
  check_deleted "${table} insert (lower id)" "$SP_LOW"
done
end_scenario "writes spanning two portfolios"

# 23. Notifications marked read while the account is deleted -----------------------------
# admin_delete_account_data deletes the user's notifications in one statement,
# outside its deadlock retry; GoTrue's deleteUser (an operator deleting the
# user in the dashboard, without the delete-account function) deletes the
# profile and then, by ON DELETE CASCADE, the notifications in its own scan
# order. Marking two of them read locked them in turn. The notification
# helper takes the account key (the profile) first, so the cascade waits at
# the profile instead of at a notification the client holds.
scenario 180 30 "23. Notifications marked read while the account is deleted (by the function and by GoTrue, both orders)"
FAILURES=()
for remover in account gotrue; do
  for order in forward backward; do
    reset_limits
    label="${remover}_${order}"
    NT_HOST="$(new_user "nt-host-${label}@example.com")"
    NT_USER="$(new_user "nt-user-${label}@example.com")"
    NT_PORTFOLIO="$(new_portfolio "$NT_HOST" "Notified ${label}")"
    add_member "$NT_PORTFOLIO" "$NT_USER" manager
    mapfile -t NT_IDS < <(psql_db -c "insert into public.notifications (portfolio_id, user_id, kind, dedupe_key)
                                      select '${NT_PORTFOLIO}', '${NT_USER}', 'rent_due_soon', 'fv-' || g
                                      from generate_series(1, 2) g returning id")
    [[ "$order" == backward ]] && NT_IDS=("${NT_IDS[1]}" "${NT_IDS[0]}")
    if [[ "$remover" == account ]]; then
      REMOVE="$(as_service "select public.admin_delete_account_data('${NT_USER}');")"
    else
      REMOVE="delete from auth.users where id = '${NT_USER}';"
    fi
    BEFORE="$(deadlocks)"
    as_user "$NT_USER" "update public.notifications set read_at = now() where id = '${NT_IDS[0]}'; select pg_sleep(0.8);
                        update public.notifications set read_at = now() where id = '${NT_IDS[1]}';" \
      | psql_db >/dev/null 2>"$WORK/nt_${label}_client.err" &
    sleep 0.3
    psql_db <<<"$REMOVE" >/dev/null 2>"$WORK/nt_${label}_delete.err" &
    wait
    check_deadlocks "$label" "$BEFORE"
    check_errors "${label} account deletion" "never-allowed" "$WORK/nt_${label}_delete.err"
    check_errors "${label} client" "$LOSER_ERRORS" "$WORK/nt_${label}_client.err"
    [[ "$(psql_db -c "select count(*) from public.notifications where user_id = '${NT_USER}'")" == "0" ]] \
      || fail_case "${label}: the deleted account kept its notifications"
  done
done
end_scenario "notifications"

# 24. S1: a file deleted through Storage while a document is attached to it ---------------
# The Storage API has deleted a user's files in two ways (supabase/storage,
# src/storage/object.ts), and each is run here as it issues its statements:
#   user     up to v1.80, a batch remove: one DELETE as the user, under the
#            row policy (as_storage_user);
#   single   up to v1.80, one object: the row FOR UPDATE as superuser, then
#            the DELETE as the user;
#   probe    from v1.81 (the hosted project runs v1.86 or later): the rows FOR
#            UPDATE as superuser (ordered by name COLLATE "C"), the user's
#            DELETE in a savepoint that is always rolled back (the "probe"),
#            then the DELETE as superuser of what the probe could delete. The
#            rollback ends every lock the probe took, and the superuser's
#            DELETE does not consult row security.
# and two deletes no policy sees:
#   unlocked the probe flow without the row lock first (no Storage API version
#            does this): nothing holds the file between the probe and the
#            delete, so only the trigger on storage.objects can keep it;
#   service  a service-role DELETE (the cleaner, an admin with the secret key).
# Each runs against a document insert in every order, each side holding its
# transaction open while the other runs: delete_first pauses after the
# delete, lock_first between the row lock and the probe or delete (the insert
# is already queued on the row when the policy runs), between after the probe
# and before the superuser's delete (the insert would commit in between if
# nothing held the row), insert_first after the insert. Then a batch: two
# files deleted at once while one INSERT attaches both, its rows in the
# opposite order to the Storage API's; a third session holds a key-share
# lock on the second file, so the Storage API locks the first and waits
# while the insert arrives.
# storage_delete <user> <SQL list of quoted paths> <flow> <pause after the lock>
#                <pause after the delete> [pause after the probe]
storage_delete() {
  local claims="set local \"request.jwt.claims\" to '{\"sub\":\"$1\",\"role\":\"authenticated\"}';"
  local where="bucket_id = 'documents' and name in ($2)"
  local lock="select count(*) from (select 1 from storage.objects where ${where}
                                    order by name collate \"C\" for update) l;"
  local probe
  probe="savepoint probe;
${claims}
set local role authenticated;
set local storage.allow_delete_query = 'true';
with d as (delete from storage.objects where ${where} returning name)
select coalesce(string_agg(quote_literal(d.name), ','), 'null') as allowed from d \\gset
rollback to savepoint probe;
${6:-}
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'documents' and name in (:allowed);"
  case "$3" in
    user) as_storage_user "$1" "delete from storage.objects where ${where}; $5" ;;
    single)
      cat <<SQL
begin;
${lock}
$4
${claims}
set local role authenticated;
set local storage.allow_delete_query = 'true';
delete from storage.objects where ${where};
$5
commit;
SQL
      ;;
    probe | unlocked)
      cat <<SQL
begin;
$([[ "$3" == probe ]] && echo "${lock}" || true)
$4
${probe}
$5
commit;
SQL
      ;;
    service)
      cat <<SQL
begin;
set local role service_role;
set local storage.allow_delete_query = 'true';
delete from storage.objects where ${where};
$5
commit;
SQL
      ;;
  esac
}
scenario 360 30 "24. S1: a file deleted (three Storage API versions, a probe without its lock, the service role) while a document is attached to it"
FAILURES=()
S1_OWNER="$(new_user "s1-owner@example.com")"
S1_ESTATE="$(new_portfolio "$S1_OWNER" 'Attachments')"
# A tenant and $1 uploaded files of it, as "tenant path ..." (paths in name order).
s1_files() {
  local tenant
  tenant="$(psql_db -c "insert into public.tenants (portfolio_id, full_name) values ('${S1_ESTATE}', 'Applicant') returning id")"
  echo "${tenant} $(psql_db -c "with f as (select '${S1_ESTATE}/tenant/${tenant}/' || gen_random_uuid() || '.jpg' as name
                                         from generate_series(1, $1))
                              insert into storage.objects (bucket_id, name) select 'documents', name from f
                              returning name" | LC_ALL=C sort | tr '\n' ' ')"
}
s1_attach() { # tenant path...
  local tenant="$1" values="" path
  shift
  for path in "$@"; do
    values+="${values:+, }('${S1_ESTATE}', 'tenant', '${tenant}', '${path}', 'cnic.jpg', 'image/jpeg', 1000)"
  done
  echo "insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
        values ${values};"
}
s1_check() { # case path...
  local label="$1" path state
  shift
  check_errors "${label} storage delete" "never-allowed" "$WORK/s1_${label}_rm.err"
  check_errors "${label} attach" "document_file_missing" "$WORK/s1_${label}_attach.err"
  for path in "$@"; do
    state="$(psql_db -c "select (select count(*) from public.documents where storage_path = '${path}') || ' document(s), '
                               || (select count(*) from storage.objects where bucket_id = 'documents' and name = '${path}')
                               || ' file(s)'")"
    echo "  ${label}: ${state}"
    [[ "$state" != "1 document(s), 0 file(s)" ]] || fail_case "${label}: the document references a deleted file"
  done
}
for flow in user single probe unlocked service; do
  for order in delete_first lock_first between insert_first; do
    case "${flow}:${order}" in
      user:lock_first | user:between | single:between | unlocked:lock_first | service:lock_first | service:between) continue ;;
    esac
    reset_limits
    read -r S1_TENANT S1_FILE < <(s1_files 1)
    ATTACH="$(s1_attach "$S1_TENANT" "$S1_FILE")"
    label="${flow}_${order}"
    BEFORE="$(deadlocks)"
    case "$order" in
      delete_first | lock_first | between)
        case "$order" in
          lock_first) RM="$(storage_delete "$S1_OWNER" "'${S1_FILE}'" "$flow" "select pg_sleep(0.8);" "")" ;;
          between) RM="$(storage_delete "$S1_OWNER" "'${S1_FILE}'" "$flow" "" "" "select pg_sleep(0.8);")" ;;
          *) RM="$(storage_delete "$S1_OWNER" "'${S1_FILE}'" "$flow" "" "select pg_sleep(0.8);")" ;;
        esac
        psql_db <<<"$RM" >/dev/null 2>"$WORK/s1_${label}_rm.err" &
        sleep 0.3
        as_user "$S1_OWNER" "$ATTACH" | psql_db >/dev/null 2>"$WORK/s1_${label}_attach.err" &
        ;;
      insert_first)
        as_user "$S1_OWNER" "${ATTACH} select pg_sleep(0.8);" | psql_db >/dev/null 2>"$WORK/s1_${label}_attach.err" &
        sleep 0.3
        storage_delete "$S1_OWNER" "'${S1_FILE}'" "$flow" "" "" | psql_db >/dev/null 2>"$WORK/s1_${label}_rm.err" &
        ;;
    esac
    wait
    check_deadlocks "$label" "$BEFORE"
    s1_check "$label" "$S1_FILE"
  done
done
for flow in user probe service; do
  reset_limits
  read -r S1_TENANT S1_FIRST S1_SECOND < <(s1_files 2)
  label="${flow}_batch"
  BEFORE="$(deadlocks)"
  psql_db >/dev/null 2>&1 <<SQL &
begin;
select 1 from storage.objects where bucket_id = 'documents' and name = '${S1_SECOND}' for key share;
select pg_sleep(1);
commit;
SQL
  sleep 0.2
  storage_delete "$S1_OWNER" "'${S1_FIRST}', '${S1_SECOND}'" "$flow" "" "" \
    | psql_db >/dev/null 2>"$WORK/s1_${label}_rm.err" &
  sleep 0.3
  as_user "$S1_OWNER" "$(s1_attach "$S1_TENANT" "$S1_SECOND" "$S1_FIRST")" \
    | psql_db >/dev/null 2>"$WORK/s1_${label}_attach.err" &
  wait
  check_deadlocks "$label" "$BEFORE"
  s1_check "$label" "$S1_FIRST" "$S1_SECOND"
done
end_scenario "S1"

# 25. S2: a document attached to an old file while the daily sweep runs -------------------
# The sweep queues files older than a day without a document row; the cleaner
# then claims the item, lists what it may delete, deletes it through the
# Storage API (as the service role) and completes the item. Both orders.
scenario 120 30 "25. S2: an old file attached while the daily sweep and the cleaner run (both orders)"
FAILURES=()
S2_OWNER="$(new_user "s2-owner@example.com")"
S2_ESTATE="$(new_portfolio "$S2_OWNER" 'Old files')"
# The cleaner's three calls for the file's item, as the storage-cleanup function makes them.
clean_file() {
  local item listed
  item="$(as_service "select id from public.admin_claim_storage_cleanup(20, 120, array['$1']);" | psql_db)"
  [[ -n "$item" ]] || return 0
  listed="$(as_service "select name from public.admin_storage_cleanup_objects(${item});" | psql_db)"
  if [[ -n "$listed" ]]; then
    as_service "set local storage.allow_delete_query = 'true';
                delete from storage.objects where bucket_id = 'documents' and name = '${listed}';" | psql_db >/dev/null
  fi
  as_service "select public.admin_complete_storage_cleanup(${item}, true);" | psql_db >/dev/null
}
for order in insert_first sweep_first; do
  reset_limits
  S2_TENANT="$(psql_db -c "insert into public.tenants (portfolio_id, full_name) values ('${S2_ESTATE}', 'Former') returning id")"
  S2_FILE="${S2_ESTATE}/tenant/${S2_TENANT}/$(psql_db -c "select gen_random_uuid()").jpg"
  psql_db -c "insert into storage.objects (bucket_id, name, created_at)
              values ('documents', '${S2_FILE}', now() - interval '2 days')" >/dev/null
  ATTACH="insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
          values ('${S2_ESTATE}', 'tenant', '${S2_TENANT}', '${S2_FILE}', 'lease.jpg', 'image/jpeg', 1000);"
  if [[ "$order" == insert_first ]]; then
    # The sweep finds the gate busy: it records no sweep for the day, so the
    # next run of the daily job sweeps again (private.run_daily_jobs).
    psql_db -c "delete from private.job_runs where job_name = 'orphaned_file_sweep'" >/dev/null
    as_user "$S2_OWNER" "${ATTACH} select fv.hold('s2_${order}');" \
      | PGAPPNAME=mm_attach psql_db >/dev/null 2>"$WORK/s2_${order}_attach.err" &
    await_session holding mm_attach
    psql_db -c "select private.enqueue_orphaned_storage(now())" >/dev/null 2>"$WORK/s2_${order}_sweep.err"
    [[ "$(psql_db -c "select count(*) from private.job_runs where job_name = 'orphaned_file_sweep'")" == "0" ]] \
      || fail_case "${order}: a sweep that found the gate busy was recorded as done"
    clean_file "$S2_FILE" 2>"$WORK/s2_${order}_clean.err"
    open_gate "s2_${order}"
    wait
    psql_db -c "select private.sweep_orphaned_files(now())" >/dev/null 2>>"$WORK/s2_${order}_sweep.err"
    [[ "$(psql_db -c "select count(*) from private.job_runs where job_name = 'orphaned_file_sweep'")" == "1" ]] \
      || fail_case "${order}: the sweep after the insert was not recorded"
  else
    PGAPPNAME=mm_sweep psql_db >/dev/null 2>"$WORK/s2_${order}_sweep.err" <<SQL &
begin;
select private.enqueue_orphaned_storage(now());
select fv.hold('s2_${order}');
commit;
SQL
    await_session holding mm_sweep
    as_user "$S2_OWNER" "$ATTACH" | PGAPPNAME=mm_attach psql_db >/dev/null 2>"$WORK/s2_${order}_attach.err" &
    await_session waiting mm_attach mm_sweep
    open_gate "s2_${order}"
    wait
  fi
  # A document row must never reference a file waiting for deletion ...
  [[ "$(psql_db -c "select count(*) from public.documents d join private.storage_cleanup_queue q
                    on q.bucket_id = 'documents' and q.path = d.storage_path
                    where d.storage_path = '${S2_FILE}'")" == "0" ]] \
    || fail_case "${order}: a document references a file queued for deletion"
  [[ "$order" == sweep_first ]] && clean_file "$S2_FILE" 2>"$WORK/s2_${order}_clean.err"
  check_errors "${order} sweep" "never-allowed" "$WORK/s2_${order}_sweep.err" "$WORK/s2_${order}_clean.err"
  check_errors "${order} attach" "document_file_pending_deletion" "$WORK/s2_${order}_attach.err"
  # ... or one the cleaner deleted.
  S2_STATE="$(psql_db -c "select (select count(*) from public.documents where storage_path = '${S2_FILE}') || ' document(s), '
                                 || (select count(*) from storage.objects where bucket_id = 'documents' and name = '${S2_FILE}')
                                 || ' file(s)'")"
  echo "  ${order}: ${S2_STATE}"
  [[ "$S2_STATE" != "1 document(s), 0 file(s)" ]] || fail_case "${order}: the cleaner deleted a referenced file"
done
end_scenario "S2"

# 26. Writes under a restored database's foreign-key order ---------------------------------
# A deletion cascades, and an INSERT checks its foreign keys, in the order of
# the foreign-key triggers, which is the constraints' creation order. A dump
# and restore re-creates them by constraint name (pg_dump's post-data
# section), so a restored database cascades a portfolio's charges and
# expenses before its leases, and an insert into lease_occupants checks the
# lease before the portfolio. This scenario dumps this database, restores it
# into a scratch copy, and runs each case there: a lease delete, a rent day
# change and a property delete that hold their row while the deletion's
# cascade takes rows they need (charges, maintenance requests), and inserts
# whose first foreign-key check is a row the cascade deletes later (a session
# holds an expense for a second, so the cascade, which deletes expenses
# before those rows, waits meanwhile).
scenario 360 30 "26. Writes under a restored database's foreign-key order (pg_dump and restore)"
FAILURES=()
drop_restored
psql -X -q -v ON_ERROR_STOP=1 -d postgres -c "create database ${RESTORED_DB}"
pg_dump --no-owner --lock-wait-timeout="${SCENARIO_LOCK_WAIT}s" -d "$MAIN_DB" >"$WORK/dump.sql"
psql -X -q -v ON_ERROR_STOP=1 -d "$RESTORED_DB" -f "$WORK/dump.sql" >/dev/null
MM_TEST_DB="$RESTORED_DB"
trigger_order() {
  psql_db -c "select string_agg(c.conrelid::regclass::text, ' ' order by t.tgname collate \"C\")
              from pg_trigger t join pg_constraint c on c.oid = t.tgconstraint
              where t.tgrelid = '$1'::regclass and t.tgisinternal and (t.tgtype & $2) = $2"
}
check_order() {
  local found
  found="$(psql_db -c "select string_agg(c.confrelid::regclass::text, ' ' order by t.tgname collate \"C\")
                       from pg_trigger t join pg_constraint c on c.oid = t.tgconstraint
                       where t.tgrelid = 'public.$1'::regclass and t.tgisinternal and (t.tgtype & 4) = 4")"
  echo "  $1 checks: ${found}"
  [[ "${found%% *}" != "portfolios" ]] || fail_case "$1: the restored copy checks the portfolio first"
}
echo "  cascade order: $(trigger_order public.portfolios 8)"
check_order lease_occupants
check_order utility_bills
for case in lease_delete due_day property_delete; do
  reset_limits
  RO_OWNER="$(new_user "order-owner-${case}@example.com")"
  RO_ESTATE="$(new_estate "$RO_OWNER" "Order ${case}" 1)"
  read -r RO_LEASE RO_PROPERTY < <(psql_db -F ' ' -c "
    select l.id, u.property_id from public.leases l join public.units u on u.id = l.unit_id
    where l.portfolio_id = '${RO_ESTATE}'")
  case "$case" in
    lease_delete)
      HOLD="update public.leases set notes = 'Entered by mistake' where id = '${RO_LEASE}';"
      WRITE="delete from public.leases where id = '${RO_LEASE}';"
      ;;
    due_day)
      HOLD="update public.leases set notes = 'Rent day moves' where id = '${RO_LEASE}';"
      WRITE="update public.leases set rent_due_day = 10 where id = '${RO_LEASE}';"
      ;;
    property_delete)
      RO_PROPERTY="$(psql_db -c "with p as (insert into public.properties (portfolio_id, name, city, province)
                                           values ('${RO_ESTATE}', 'Plot', 'Lahore', 'punjab') returning id),
                                     u as (insert into public.units (portfolio_id, property_id, label)
                                           select '${RO_ESTATE}', id, 'Plot unit' from p returning property_id)
                                select property_id from u")"
      # The property delete cascades to this request, which the deletion's
      # cascade (maintenance_requests before properties) takes first.
      psql_db -c "insert into public.maintenance_requests (portfolio_id, property_id, title)
                  values ('${RO_ESTATE}', '${RO_PROPERTY}', 'Boundary wall')" >/dev/null
      HOLD="update public.properties set notes = 'Sold' where id = '${RO_PROPERTY}';"
      WRITE="delete from public.properties where id = '${RO_PROPERTY}';"
      ;;
  esac
  BEFORE="$(deadlocks)"
  as_user "$RO_OWNER" "${HOLD} select pg_sleep(0.8); ${WRITE}" | psql_db >/dev/null 2>"$WORK/ro_${case}_client.err" &
  sleep 0.3
  as_user "$RO_OWNER" "select public.delete_portfolio('${RO_ESTATE}', 'Order ${case}');" \
    | psql_db >/dev/null 2>"$WORK/ro_${case}_delete.err" &
  wait
  check_deadlocks "$case" "$BEFORE"
  check_errors "${case} deletion" "never-allowed" "$WORK/ro_${case}_delete.err"
  check_errors "${case} client" "$LOSER_ERRORS" "$WORK/ro_${case}_client.err"
  check_deleted "$case" "$RO_ESTATE"
done
for table in lease_occupants maintenance_requests meter_readings reminder_logs expenses utility_bills; do
  reset_limits
  RI_OWNER="$(new_user "restored-owner-${table}@example.com")"
  RI_MANAGER="$(new_user "restored-manager-${table}@example.com")"
  RI_ESTATE="$(new_estate "$RI_OWNER" "Restored ${table}" 1)"
  add_member "$RI_ESTATE" "$RI_MANAGER" manager
  read -r RI_LEASE RI_PROPERTY RI_UNIT RI_EXPENSE RI_REQUEST RI_ACCOUNT < <(
    psql_db -F ' ' <<SQL
with l as (select l.id, u.property_id, l.unit_id from public.leases l join public.units u on u.id = l.unit_id
           where l.portfolio_id = '${RI_ESTATE}'),
     e as (insert into public.expenses (portfolio_id, property_id, category, amount, spent_on)
           select '${RI_ESTATE}', property_id, 'repairs_maintenance', 900, '2026-11-01' from l returning id),
     r as (insert into public.maintenance_requests (portfolio_id, property_id, unit_id, title)
           select '${RI_ESTATE}', property_id, unit_id, 'Leaking tap' from l returning id),
     a as (insert into public.utility_accounts (portfolio_id, property_id, unit_id, type)
           select '${RI_ESTATE}', property_id, unit_id, 'electricity' from l returning id)
select l.id, l.property_id, l.unit_id, e.id, r.id, a.id from l, e, r, a;
SQL
  )
  case "$table" in
    lease_occupants)
      RI_INSERT="insert into public.lease_occupants (portfolio_id, lease_id, full_name)
                 values ('${RI_ESTATE}', '${RI_LEASE}', 'Cousin');"
      ;;
    maintenance_requests)
      RI_INSERT="insert into public.maintenance_requests (portfolio_id, property_id, unit_id, lease_id, title)
                 values ('${RI_ESTATE}', '${RI_PROPERTY}', '${RI_UNIT}', '${RI_LEASE}', 'Broken window');"
      ;;
    meter_readings)
      RI_INSERT="insert into public.meter_readings (portfolio_id, utility_account_id, lease_id, reading, read_on)
                 values ('${RI_ESTATE}', '${RI_ACCOUNT}', '${RI_LEASE}', 1234, '2026-11-01');"
      ;;
    reminder_logs)
      RI_INSERT="insert into public.reminder_logs (portfolio_id, lease_id, channel, template, language)
                 values ('${RI_ESTATE}', '${RI_LEASE}', 'whatsapp', 'rent_due', 'en');"
      ;;
    expenses)
      RI_INSERT="insert into public.expenses (portfolio_id, property_id, maintenance_request_id, category, amount, spent_on)
                 values ('${RI_ESTATE}', '${RI_PROPERTY}', '${RI_REQUEST}', 'repairs_maintenance', 400, '2026-11-02');"
      ;;
    utility_bills)
      RI_INSERT="insert into public.utility_bills (portfolio_id, utility_account_id, billing_month, amount)
                 values ('${RI_ESTATE}', '${RI_ACCOUNT}', '2026-10-01', 3100);"
      ;;
  esac
  BEFORE="$(deadlocks)"
  psql_db >/dev/null 2>&1 <<SQL &
begin;
select 1 from public.expenses where id = '${RI_EXPENSE}' for key share;
select pg_sleep(1.2);
commit;
SQL
  sleep 0.1
  as_user "$RI_OWNER" "select public.delete_portfolio('${RI_ESTATE}', 'Restored ${table}');" \
    | psql_db >/dev/null 2>"$WORK/ri_${table}_delete.err" &
  sleep 0.3
  as_user "$RI_MANAGER" "$RI_INSERT" | psql_db >/dev/null 2>"$WORK/ri_${table}_client.err" &
  wait
  check_deadlocks "${table} insert" "$BEFORE"
  check_errors "${table} deletion" "never-allowed" "$WORK/ri_${table}_delete.err"
  check_errors "${table} insert" "$LOSER_ERRORS" "$WORK/ri_${table}_client.err"
  check_deleted "${table} insert" "$RI_ESTATE"
done
MM_TEST_DB="$MAIN_DB"
drop_restored
end_scenario "restored foreign-key order"

# 27. A member removed while their write waits for the portfolio key -------------------------
# remove_member holds the portfolio FOR UPDATE until it commits; the removed
# member's write meanwhile waits in the lock helper, which then authorises
# again with a fresh snapshot: the portfolio is dropped, so the DELETE finds
# nothing it may delete and the INSERT is refused.
scenario 120 30 "27. A member removed while their delete or insert waits for the portfolio key"
FAILURES=()
for write in delete insert; do
  reset_limits
  RA_OWNER="$(new_user "ra-owner-${write}@example.com")"
  RA_LEAVER="$(new_user "ra-leaver-${write}@example.com")"
  RA_ESTATE="$(new_portfolio "$RA_OWNER" "Reauthorised ${write}")"
  add_member "$RA_ESTATE" "$RA_LEAVER" owner
  RA_TENANT="$(psql_db -c "insert into public.tenants (portfolio_id, full_name) values ('${RA_ESTATE}', 'Kept') returning id")"
  if [[ "$write" == delete ]]; then
    RA_WRITE="delete from public.tenants where id = '${RA_TENANT}';"
  else
    RA_WRITE="insert into public.tenants (portfolio_id, full_name) values ('${RA_ESTATE}', 'Late');"
  fi
  BEFORE="$(deadlocks)"
  as_user "$RA_OWNER" "select public.remove_member('${RA_ESTATE}', '${RA_LEAVER}'); select pg_sleep(0.8);" \
    | psql_db >/dev/null 2>"$WORK/ra_${write}_remove.err" &
  sleep 0.3
  as_user "$RA_LEAVER" "$RA_WRITE" | psql_db >/dev/null 2>"$WORK/ra_${write}_client.err" &
  wait
  check_deadlocks "$write" "$BEFORE"
  check_errors "${write} removal" "never-allowed" "$WORK/ra_${write}_remove.err"
  check_errors "${write} client" "new row violates row-level security policy" "$WORK/ra_${write}_client.err"
  [[ "$(psql_db -c "select count(*) from public.tenants where portfolio_id = '${RA_ESTATE}'")" == "1" ]] \
    || fail_case "${write}: the removed member's ${write} was applied"
done
end_scenario "re-authorisation after the key"

# 28. A SECURITY DEFINER function's insert waits for the portfolio key ---------------------
# The row triggers of documents and manual charges take the key without
# waiting only in a client's own statement, for a portfolio its statement
# trigger did not lock. A definer function's insert (none inserts manual
# charges yet; this one stands for a future one) runs as the function's
# owner and waits for the key, as jobs do, even with a signed-in caller.
scenario 60 30 "28. A definer function's manual charge waits while a membership change holds the portfolio"
FAILURES=()
reset_limits
DF_OWNER="$(new_user "df-owner@example.com")"
DF_ESTATE="$(new_estate "$DF_OWNER" "Definer" 1)"
DF_LEASE="$(psql_db -c "select id from public.leases where portfolio_id = '${DF_ESTATE}'")"
psql_db >/dev/null <<'SQL'
create or replace function public.fv_add_manual_charge(p_portfolio uuid, p_lease uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
  values (p_portfolio, p_lease, 'other', '2026-11-10', 700, 'Added by a definer function');
$$;
revoke all on function public.fv_add_manual_charge(uuid, uuid) from public, anon;
grant execute on function public.fv_add_manual_charge(uuid, uuid) to authenticated;
SQL
BEFORE="$(deadlocks)"
psql_db >/dev/null 2>&1 <<SQL &
begin;
select 1 from public.portfolios where id = '${DF_ESTATE}' for update;
select pg_sleep(0.8);
commit;
SQL
sleep 0.3
as_user "$DF_OWNER" "select public.fv_add_manual_charge('${DF_ESTATE}', '${DF_LEASE}');" \
  | psql_db >/dev/null 2>"$WORK/df_client.err" &
wait
check_deadlocks "definer insert" "$BEFORE"
check_errors "definer insert" "never-allowed" "$WORK/df_client.err"
[[ "$(psql_db -c "select count(*) from public.charges where lease_id = '${DF_LEASE}' and description = 'Added by a definer function'")" == "1" ]] \
  || fail_case "the definer function's charge was refused instead of waiting"
psql_db -c "drop function public.fv_add_manual_charge(uuid, uuid)" >/dev/null
end_scenario "definer inserts"

# 29. F1: charge edits under the lease lock ------------------------------------------------
# A client's two-row UPDATE of charges locked the manual charge (first in the
# table), then the rent, without the lease lock, while allocate_payment and
# void_payment lock the lease and then the rent before the manual charge (due
# order): PostgreSQL detected a deadlock (formal/tla/LedgerPayments, F1). Now
# a client can only call update_charge, which takes the portfolio key and the
# lease first. Two calls in one transaction stand for the old statement's two
# rows; the sleep between them holds the lease while the ledger call arrives,
# the window in which the old statement deadlocked.
scenario 360 30 "29. F1: charge edits (update_charge) racing payments and voids on one lease (8 rounds)"
FAILURES=()
reset_limits
CE_OWNER="$(new_user "ce-owner@example.com")"
CE_ESTATE="$(new_portfolio "$CE_OWNER" "Edits")"
as_user "$CE_OWNER" "update public.charges set description = 'Direct' where portfolio_id = '${CE_ESTATE}';" \
  | psql_db >/dev/null 2>"$WORK/ce_direct.err" || true
grep -q "ERROR:  permission denied for table charges" "$WORK/ce_direct.err" \
  || fail_case "a client's direct UPDATE of charges was not refused: $(cat "$WORK/ce_direct.err")"
# A lease starting in December with a manual charge (due 20 December) created
# before December's rent (due 5 December): first in the table, last in due order.
ce_lease() {
  local lease
  lease="$(
    psql_db -v portfolio="$CE_ESTATE" <<'SQL'
set app.today_override = '2026-11-20';
with prop as (
  insert into public.properties (portfolio_id, name, city, province)
  values (:'portfolio', 'House ' || gen_random_uuid(), 'Lahore', 'punjab')
  returning id, portfolio_id
), unit as (
  insert into public.units (portfolio_id, property_id, label) select portfolio_id, id, 'Flat' from prop
  returning id, portfolio_id
), tenant as (
  insert into public.tenants (portfolio_id, full_name) select portfolio_id, 'Tenant' from unit
  returning id, portfolio_id
), lease as (
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
  select unit.portfolio_id, unit.id, tenant.id, '2026-12-01', 1000 from unit, tenant
  returning id, portfolio_id
)
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
select portfolio_id, id, 'maintenance', '2026-12-20', 500, 'Repair' from lease
returning lease_id;
SQL
  )"
  psql_db -c "set app.today_override = '2026-12-03'; select private.sync_lease_billing('${lease}')" >/dev/null
  echo "$lease"
}
# $1 tag, $2 lease, $3 the ledger call, started 0.2 s into the client's
# transaction (after its first edit, before its second).
ce_race() {
  local before manual rent
  manual="$(psql_db -c "select id from public.charges where lease_id = '$2' and source = 'manual'")"
  rent="$(psql_db -c "select id from public.charges where lease_id = '$2' and kind = 'rent'")"
  before="$(deadlocks)"
  as_user "$CE_OWNER" "select public.update_charge('${manual}', 700, null, 'Edited') is not null;
    select pg_sleep(0.4);
    select public.update_charge('${rent}', null, null, 'Edited') is not null;" \
    | psql_db >/dev/null 2>"$WORK/ce_$1_client.err" &
  sleep 0.2
  as_user "$CE_OWNER" "$3" | psql_db >/dev/null 2>"$WORK/ce_$1_ledger.err" &
  wait
  check_deadlocks "$1" "$before"
  check_errors "$1" "never-allowed" "$WORK/ce_$1_client.err" "$WORK/ce_$1_ledger.err"
}
for round in $(seq 1 8); do
  reset_limits
  lease="$(ce_lease)"
  ce_race "pay${round}" "$lease" \
    "select public.record_payment('${lease}', 1500, '2026-11-03', 'cash', gen_random_uuid()) is not null;"
  lease="$(ce_lease)"
  pay="$(as_user "$CE_OWNER" "select public.record_payment('${lease}', 1500, '2026-11-03', 'cash', gen_random_uuid()) -> 'payment' ->> 'id';" | psql_db)"
  ce_race "void${round}" "$lease" "select public.void_payment('${pay}', 'Bounced') is not null;"
done
[[ "$(psql_db -c "select count(*) from public.charges where portfolio_id = '${CE_ESTATE}' and description = 'Edited'")" == "32" ]] \
  || fail_case "not every edit was applied"
[[ "$(psql_db -c "select count(*) from public.charges c
                  where c.portfolio_id = '${CE_ESTATE}' and c.voided_at is null and c.outstanding > 0
                    and exists (select 1 from public.payments p
                                where p.lease_id = c.lease_id and p.voided_at is null and p.unallocated_amount > 0)")" == "0" ]] \
  || fail_case "credit was left next to an open due"
end_scenario "charge edits under the lease lock"

# 30. Invitations: concurrent re-invites and inviters deleted in Auth ---------------------
# F1: create_invitation serialises creates of one (portfolio, e-mail) with an
# advisory lock, so a re-invite waits for a concurrent one and replaces its
# invitation instead of failing with 23505 on
# portfolio_invitations_pending_email_key. F3/F4: a direct Auth deletion
# (GoTrue's DELETE, here held open like its transaction) revokes the
# inviter's pending invitations; an acceptance arriving meanwhile waits for
# the invitation row and answers revoked. The interleaving where the
# acceptance already holds the invitation when the direct deletion starts
# still deadlocks (F3, formal/tla/Invitations/replay_findings.sh): the rule
# in docs/operations.md is to delete accounts through delete-account, whose
# order is checked here with the acceptance holding its locks.
scenario 360 30 "30. Invitations: concurrent re-invites of one e-mail; inviters deleted in Auth during acceptances"
FAILURES=()
iv_owner1="$(new_user "iv-owner1@example.com")"
iv_owner2="$(new_user "iv-owner2@example.com")"
IV_ESTATE="$(new_portfolio "$iv_owner1" "Invites")"
add_member "$IV_ESTATE" "$iv_owner2" owner
# $1 tag, $2 e-mail: the two owners re-invite $2, the first holding its
# transaction open after its create until the second waits for it (the
# window of F1).
iv_reinvite() {
  local first="$iv_owner1" second="$iv_owner2" before pending
  [[ "$1" == *b ]] && first="$iv_owner2" second="$iv_owner1"
  before="$(deadlocks)"
  as_user "$first" "select public.create_invitation('${IV_ESTATE}', '$2', 'manager') ->> 'role';
                     select fv.hold('iv_$1');" \
    | PGAPPNAME=mm_first psql_db >"$WORK/iv_$1_first.out" 2>"$WORK/iv_$1_first.err" &
  await_session holding mm_first
  as_user "$second" "select public.create_invitation('${IV_ESTATE}', '$2', 'viewer') ->> 'role';" \
    | PGAPPNAME=mm_second psql_db >"$WORK/iv_$1_second.out" 2>"$WORK/iv_$1_second.err" &
  await_session waiting mm_second mm_first
  open_gate "iv_$1"
  wait
  check_deadlocks "re-invite $1" "$before"
  check_errors "re-invite $1" "never-allowed" "$WORK/iv_$1_first.err" "$WORK/iv_$1_second.err"
  [[ "$(cat "$WORK/iv_$1_second.out")" == viewer ]] || fail_case "re-invite $1: the second create did not succeed"
  pending="$(psql_db -c "select string_agg(role::text, ',') from public.portfolio_invitations
                         where portfolio_id = '${IV_ESTATE}' and email = '$2'
                           and accepted_at is null and revoked_at is null")"
  [[ "$pending" == viewer ]] || fail_case "re-invite $1: pending afterwards: '${pending}' (expected the later one only)"
}
reset_limits
for round in 1 2 3; do
  iv_reinvite "${round}a" "iv-guest-${round}a@example.com"
  iv_reinvite "${round}b" "iv-guest-${round}b@example.com"
done
# A burst: 8 creates of one e-mail by both owners at once.
reset_limits
before="$(deadlocks)"
for i in $(seq 1 8); do
  owner="$iv_owner1"
  ((i % 2 == 0)) && owner="$iv_owner2"
  as_user "$owner" "select public.create_invitation('${IV_ESTATE}', 'iv-burst@example.com', 'viewer') ->> 'role';" \
    | psql_db >"$WORK/iv_burst_$i.out" 2>"$WORK/iv_burst_$i.err" &
done
wait
check_deadlocks "re-invite burst" "$before"
check_errors "re-invite burst" "never-allowed" "$WORK"/iv_burst_*.err
[[ "$(cat "$WORK"/iv_burst_*.out | grep -c '^viewer$')" == 8 ]] || fail_case "re-invite burst: not every create succeeded"
[[ "$(psql_db -c "select count(*) filter (where accepted_at is null and revoked_at is null) || '/' || count(*)
                  from public.portfolio_invitations
                  where portfolio_id = '${IV_ESTATE}' and email = 'iv-burst@example.com'")" == "1/8" ]] \
  || fail_case "re-invite burst: expected 8 invitations with exactly one pending"
# $1 tag, $2 order: "direct" (GoTrue's DELETE alone, held open until the
# acceptance waits for it), "account_arriving" (admin_delete_account_data
# held open likewise, then the DELETE),
# "account_holding" (the acceptance holds its locks, as accept_invitation
# takes them, when admin_delete_account_data and the DELETE start).
iv_inviter_deleted() {
  local inviter cohost guest estate token id other before status pending
  reset_limits
  inviter="$(new_user "iv-inviter-$1@example.com")"
  cohost="$(new_user "iv-cohost-$1@example.com")"
  guest="$(new_user "iv-joiner-$1@example.com")"
  estate="$(new_portfolio "$cohost" "Inviter $1")"
  add_member "$estate" "$inviter" owner
  token="$(as_user "$inviter" "select public.create_invitation('${estate}', 'iv-joiner-$1@example.com', 'manager') ->> 'token';" | psql_db)"
  id="${token%%.*}"
  # A second invitation of the inviter that nobody accepts (F4: it must not
  # stay pending either).
  other="$(as_user "$inviter" "select public.create_invitation('${estate}', 'iv-bystander-$1@example.com', 'viewer') ->> 'invitation_id';" | psql_db)"
  before="$(deadlocks)"
  case "$2" in
    direct)
      PGAPPNAME=mm_deleter psql_db -c "begin" -c "delete from auth.users where id = '${inviter}'" \
        -c "select fv.hold('iv_$1')" -c "commit" >/dev/null 2>"$WORK/iv_$1_delete.err" &
      await_session holding mm_deleter
      as_user "$guest" "select public.accept_invitation('${token}') ->> 'status';" \
        | PGAPPNAME=mm_accept psql_db >"$WORK/iv_$1_accept.out" 2>"$WORK/iv_$1_accept.err" &
      await_session waiting mm_accept mm_deleter
      open_gate "iv_$1"
      ;;
    account_arriving)
      {
        as_service "select public.admin_delete_account_data('${inviter}') is not null;
                    select fv.hold('iv_$1');" | PGAPPNAME=mm_deleter psql_db
        psql_db -c "delete from auth.users where id = '${inviter}'"
      } >/dev/null 2>"$WORK/iv_$1_delete.err" &
      await_session holding mm_deleter
      as_user "$guest" "select public.accept_invitation('${token}') ->> 'status';" \
        | PGAPPNAME=mm_accept psql_db >"$WORK/iv_$1_accept.out" 2>"$WORK/iv_$1_accept.err" &
      await_session waiting mm_accept mm_deleter
      open_gate "iv_$1"
      ;;
    account_holding)
      PGAPPNAME=mm_accept psql_db >"$WORK/iv_$1_accept.out" 2>"$WORK/iv_$1_accept.err" <<SQL &
set app.today_override = '2026-11-03';
begin;
select from public.profiles where id = '${guest}' for key share;
select from public.portfolios where id = '${estate}' for key share;
select from public.portfolio_invitations where id = '${id}' for update;
set local "request.jwt.claims" to '{"sub":"${guest}","role":"authenticated"}';
set local role authenticated;
select fv.hold('iv_$1');
select public.accept_invitation('${token}') ->> 'status';
commit;
SQL
      await_session holding mm_accept
      {
        as_service "select public.admin_delete_account_data('${inviter}') is not null;" \
          | PGAPPNAME=mm_deleter psql_db
        psql_db -c "delete from auth.users where id = '${inviter}'"
      } >/dev/null 2>"$WORK/iv_$1_delete.err" &
      await_session waiting mm_deleter mm_accept
      open_gate "iv_$1"
      ;;
  esac
  wait
  check_deadlocks "inviter deleted, $1" "$before"
  check_errors "inviter deleted, $1" "never-allowed" "$WORK/iv_$1_delete.err" "$WORK/iv_$1_accept.err"
  status="$(grep -E '^[a-z_]+$' "$WORK/iv_$1_accept.out" | tail -1)"
  case "$2:$status" in
    direct:revoked | account_arriving:revoked | account_holding:accepted) ;;
    *) fail_case "inviter deleted, $1: the acceptance answered '${status}'" ;;
  esac
  pending="$(psql_db -c "select count(*) from public.portfolio_invitations
                         where id in ('${id}', '${other}') and accepted_at is null and revoked_at is null")"
  [[ "$pending" == 0 ]] || fail_case "inviter deleted, $1: ${pending} invitation(s) left pending"
  [[ "$(psql_db -c "select count(*) from auth.users where id = '${inviter}'")" == 0 ]] \
    || fail_case "inviter deleted, $1: the auth user was not deleted"
}
for round in 1 2; do
  iv_inviter_deleted "direct${round}" direct
  iv_inviter_deleted "arriving${round}" account_arriving
  iv_inviter_deleted "holding${round}" account_holding
done
end_scenario "invitations"

# 31. Residence: the caretaker, the owner-abroad answer, a declared residence --------------
# Each race runs a first session that takes its locks and holds its
# transaction open in fv.hold, and a second that must wait for one of them:
# the gate opens only once await_session sees the second waiting on the
# first, so the order holds on a loaded machine. Without the caretaker
# trigger's FOR SHARE read of the membership, a service-role role change or
# removal in flight lets a non-manager become the caretaker; with a filter on
# the values in admin_delete_account_data's residence clear, a person's UPDATE
# in flight survives the deletion; without the second authorisation after the
# portfolio lock, a removed owner names a caretaker and a demoted manager
# answers the question.
scenario 60 30 "31. Residence: the caretaker, the owner-abroad answer and a declared residence in races"
FAILURES=()
reset_limits
BEFORE="$(deadlocks)"
# rs_race LABEL WHO FIRST SECOND ERROR: the first session runs the statements
# FIRST as WHO (a user's id, or service for the service role) and holds its
# transaction open at gate rs_LABEL; SECOND (a whole session script) arrives
# and must wait for it. SECOND must end with the error code ERROR, or with
# none when ERROR is empty, and the first session with none.
rs_race() {
  local label="$1" first second_error
  first="$3
select fv.hold('rs_${label}');"
  if [[ "$2" == service ]]; then
    first="$(as_service "$first")"
  else
    first="$(as_user "$2" "$first")"
  fi
  PGAPPNAME="rs_${label}_first" psql_db <<<"$first" >"$WORK/rs_${label}_first.out" \
    2>"$WORK/rs_${label}_first.err" &
  await_session holding "rs_${label}_first"
  PGAPPNAME="rs_${label}_second" psql_db <<<"$4" >"$WORK/rs_${label}_second.out" \
    2>"$WORK/rs_${label}_second.err" &
  await_session waiting "rs_${label}_second" "rs_${label}_first"
  open_gate "rs_${label}"
  wait
  check_errors "${label} (first)" "never-allowed" "$WORK/rs_${label}_first.err"
  second_error="$(grep -m1 -oE 'ERROR:  [a-z_]+' "$WORK/rs_${label}_second.err" | cut -c9- || true)"
  [[ "$second_error" == "$5" ]] \
    || fail_case "${label}: the second session ended with '${second_error:-no error}', expected '${5:-no error}'"
}

# A portfolio with owner RS_O, co-owner RS_C and manager RS_M.
rs_estate() {
  RS_O="$(new_user "rs-$1-owner@example.com")"
  RS_C="$(new_user "rs-$1-coowner@example.com")"
  RS_M="$(new_user "rs-$1-manager@example.com")"
  RS_P="$(new_portfolio "$RS_O" "Residence race $1")"
  add_member "$RS_P" "$RS_C" owner
  add_member "$RS_P" "$RS_M" manager
}
# The caretaker (or none), whether it has a time, and the manager's role.
rs_caretaker() {
  psql_db -c "select coalesce(p.caretaker_user_id::text, 'none') || ':' || (p.caretaker_since is not null)
                     || ':' || coalesce((select m.role::text from public.portfolio_members m
                                         where m.portfolio_id = p.id and m.user_id = '${RS_M}'), 'gone')
              from public.portfolios p where p.id = '${RS_P}'"
}

# The caretaker against changes of the manager's membership, and the naming
# owner's own removal.
for c in service_demotes naming_then_service_demotes service_removes naming_then_service_removes \
  owner_demotes naming_then_owner_demotes owner_removes naming_then_owner_removes namer_removed; do
  rs_estate "$c"
  NAME_IT="select public.set_caretaker('${RS_P}', '${RS_M}');"
  DEMOTE="update public.portfolio_members set role = 'viewer'
          where portfolio_id = '${RS_P}' and user_id = '${RS_M}';"
  REMOVE="delete from public.portfolio_members where portfolio_id = '${RS_P}' and user_id = '${RS_M}';"
  WANT="none:false:viewer"
  case "$c" in
    service_demotes)
      rs_race "$c" service "$DEMOTE" "$(as_user "$RS_O" "$NAME_IT")" caretaker_not_manager
      ;;
    naming_then_service_demotes)
      rs_race "$c" "$RS_O" "$NAME_IT" "$(as_service "$DEMOTE")" ""
      ;;
    service_removes)
      rs_race "$c" service "$REMOVE" "$(as_user "$RS_O" "$NAME_IT")" caretaker_not_manager
      WANT="none:false:gone"
      ;;
    naming_then_service_removes)
      rs_race "$c" "$RS_O" "$NAME_IT" "$(as_service "$REMOVE")" ""
      WANT="none:false:gone"
      ;;
    owner_demotes)
      rs_race "$c" "$RS_C" "select public.update_member_role('${RS_P}', '${RS_M}', 'viewer');" \
        "$(as_user "$RS_O" "$NAME_IT")" caretaker_not_manager
      ;;
    naming_then_owner_demotes)
      rs_race "$c" "$RS_O" "$NAME_IT" \
        "$(as_user "$RS_C" "select public.update_member_role('${RS_P}', '${RS_M}', 'viewer');")" ""
      ;;
    owner_removes)
      rs_race "$c" "$RS_C" "select public.remove_member('${RS_P}', '${RS_M}');" \
        "$(as_user "$RS_O" "$NAME_IT")" member_not_found
      WANT="none:false:gone"
      ;;
    naming_then_owner_removes)
      rs_race "$c" "$RS_O" "$NAME_IT" \
        "$(as_user "$RS_C" "select public.remove_member('${RS_P}', '${RS_M}');")" ""
      WANT="none:false:gone"
      ;;
    namer_removed)
      rs_race "$c" "$RS_C" "select public.remove_member('${RS_P}', '${RS_O}');" \
        "$(as_user "$RS_O" "$NAME_IT")" forbidden
      WANT="none:false:manager"
      ;;
  esac
  GOT="$(rs_caretaker)"
  [[ "$GOT" == "$WANT" ]] || fail_case "${c}: caretaker:named:manager's role is ${GOT}, expected ${WANT}"
done

# The owner-abroad answer asked on the next open (p_if_unanswered) by two
# members at once, and by a manager demoted meanwhile.
rs_answer() {
  psql_db -c "select coalesce(p.owner_abroad::text, 'null') || ':' || coalesce((
                select string_agg(format('%s by %s', a.changes -> 'owner_abroad', a.actor_id), ', ' order by a.id)
                from public.audit_logs a
                where a.portfolio_id = p.id and a.table_name = 'portfolios' and a.action = 'update'), 'none')
              from public.portfolios p where p.id = '${RS_P}'"
}
for c in owner_answers_first manager_answers_first answerer_demoted; do
  rs_estate "$c"
  case "$c" in
    owner_answers_first)
      rs_race "$c" "$RS_O" "select public.set_owner_abroad('${RS_P}', true, p_if_unanswered => true);" \
        "$(as_user "$RS_M" "select public.set_owner_abroad('${RS_P}', false, p_if_unanswered => true);")" ""
      RETURNED=t
      WANT="true:[null, true] by ${RS_O}"
      ;;
    manager_answers_first)
      rs_race "$c" "$RS_M" "select public.set_owner_abroad('${RS_P}', false, p_if_unanswered => true);" \
        "$(as_user "$RS_O" "select public.set_owner_abroad('${RS_P}', true, p_if_unanswered => true);")" ""
      RETURNED=f
      WANT="false:[null, false] by ${RS_M}"
      ;;
    answerer_demoted)
      rs_race "$c" "$RS_O" "select public.update_member_role('${RS_P}', '${RS_M}', 'viewer');" \
        "$(as_user "$RS_M" "select public.set_owner_abroad('${RS_P}', true, p_if_unanswered => true);")" forbidden
      RETURNED=""
      WANT="null:none"
      ;;
  esac
  [[ "$(cat "$WORK/rs_${c}_second.out")" == "$RETURNED" ]] \
    || fail_case "${c}: the second answer returned '$(cat "$WORK/rs_${c}_second.out")', expected '${RETURNED}'"
  GOT="$(rs_answer)"
  [[ "$GOT" == "$WANT" ]] || fail_case "${c}: answer:audit is ${GOT}, expected ${WANT}"
done

# A declared residence written while the account's deletion runs, in both
# orders: the residence ends cleared, and the person's writes after the
# deletion started are refused.
for c in residence_then_deletion deletion_then_residence; do
  RS_U="$(new_user "rs-${c}@example.com")"
  STATE="update public.profile_residences set residence_country = 'AE', time_zone = 'Asia/Dubai'
         where user_id = '${RS_U}';"
  DELETE_ACCOUNT="select public.admin_delete_account_data('${RS_U}') is not null;"
  if [[ "$c" == residence_then_deletion ]]; then
    rs_race "$c" "$RS_U" "$STATE" "$(as_service "$DELETE_ACCOUNT")" ""
  else
    rs_race "$c" service "$DELETE_ACCOUNT" "$(as_user "$RS_U" "$STATE")" account_deleted
  fi
  GOT="$(psql_db -c "select coalesce(r.residence_country, '-') || ':' || coalesce(r.time_zone, '-') || ':'
                            || (r.stated_at is not null)
                     from public.profile_residences r where r.user_id = '${RS_U}'")"
  [[ "$GOT" == "-:-:false" ]] || fail_case "${c}: the residence after the deletion is ${GOT}, expected -:-:false"
  as_user "$RS_U" "$STATE" | psql_db >/dev/null 2>"$WORK/rs_${c}_later.err" || true
  grep -q 'ERROR:  account_deleted' "$WORK/rs_${c}_later.err" \
    || fail_case "${c}: a later write was not refused with account_deleted: $(head -1 "$WORK/rs_${c}_later.err")"
done

# The caretaker's account deleted in the delete-account order
# (admin_delete_account_data, then the Auth delete) while the caretaker is
# named, and while the manager is demoted (Membership model, caretaker_acct).
# A direct Auth delete without the first step is the operator's rule in
# docs/operations.md (formal/tla/Membership/replay/residence.sh, R1 and R2).
for c in naming_holds deletion_holds demote_holds; do
  rs_estate "$c"
  NAME_IT="select public.set_caretaker('${RS_P}', '${RS_M}');"
  DELETE_ACCOUNT="$(as_service "select public.admin_delete_account_data('${RS_M}') is not null;")
delete from auth.users where id = '${RS_M}';"
  case "$c" in
    naming_holds)
      rs_race "$c" "$RS_O" "$NAME_IT" "$DELETE_ACCOUNT" ""
      ;;
    deletion_holds)
      rs_race "$c" service "select public.admin_delete_account_data('${RS_M}') is not null;" \
        "$(as_user "$RS_O" "$NAME_IT")" member_not_found
      psql_db -c "delete from auth.users where id = '${RS_M}'" >/dev/null
      ;;
    demote_holds)
      as_user "$RS_O" "$NAME_IT" | psql_db >/dev/null
      rs_race "$c" "$RS_C" "select public.update_member_role('${RS_P}', '${RS_M}', 'viewer');" \
        "$DELETE_ACCOUNT" ""
      ;;
  esac
  GOT="$(rs_caretaker):$(psql_db -c "select count(*) from auth.users where id = '${RS_M}'")"
  [[ "$GOT" == "none:false:gone:0" ]] \
    || fail_case "${c}: caretaker:named:manager's role:auth users is ${GOT}, expected none:false:gone:0"
done

# An operator (the service role) who changes the caretaker's membership locks
# the portfolio first, as docs/operations.md says; then a membership RPC that
# holds the portfolio (lock_portfolio_for_change) before its write cannot
# form a cycle with the operator's trigger (Membership model,
# assume_service_member_write).
for c in operator_locks_portfolio_first_demote operator_locks_portfolio_first_remove; do
  rs_estate "$c"
  as_user "$RS_O" "select public.set_caretaker('${RS_P}', '${RS_M}');" | psql_db >/dev/null
  if [[ "$c" == *_demote ]]; then
    RPC="select public.update_member_role('${RS_P}', '${RS_M}', 'viewer');"
    OPERATOR="delete from public.portfolio_members where portfolio_id = '${RS_P}' and user_id = '${RS_M}';"
  else
    RPC="select public.remove_member('${RS_P}', '${RS_M}');"
    OPERATOR="update public.portfolio_members set role = 'viewer'
              where portfolio_id = '${RS_P}' and user_id = '${RS_M}';"
  fi
  # The RPC's session holds the portfolio as lock_portfolio_for_change does,
  # and waits at its gate before the RPC writes the membership.
  PGAPPNAME="rs_${c}_first" psql_db >/dev/null 2>"$WORK/rs_${c}_first.err" <<SQL &
set app.today_override = '2026-11-03';
begin;
select 1 from public.portfolios where id = '${RS_P}' for update;
set local "request.jwt.claims" to '{"sub":"${RS_C}","role":"authenticated"}';
set local role authenticated;
select fv.hold('rs_${c}');
${RPC}
commit;
SQL
  await_session holding "rs_${c}_first"
  as_service "select 1 from public.portfolios where id = '${RS_P}' for update;
              ${OPERATOR}" | PGAPPNAME="rs_${c}_second" psql_db >/dev/null 2>"$WORK/rs_${c}_second.err" &
  await_session waiting "rs_${c}_second" "rs_${c}_first"
  open_gate "rs_${c}"
  wait
  check_errors "${c}" "never-allowed" "$WORK/rs_${c}_first.err" "$WORK/rs_${c}_second.err"
  GOT="$(rs_caretaker)"
  [[ "$GOT" == "none:false:gone" ]] || fail_case "${c}: caretaker:named:manager's role is ${GOT}, expected none:false:gone"
done
check_deadlocks "residence races" "$BEFORE"
end_scenario "residence races"

# 32. Invariants --------------------------------------------------------------------------
scenario 60 30 "32. Invariants"
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
  'dangling_documents', (
    select count(*) from public.documents d
    where not exists (
      select 1 from storage.objects o where o.bucket_id = 'documents' and o.name = d.storage_path
    )
  ),
  'documents_of_queued_files', (
    select count(*) from public.documents d
    where exists (
      select 1 from private.storage_cleanup_queue q
      where q.bucket_id = 'documents' and q.path in (d.storage_path, split_part(d.storage_path, '/', 1) || '/')
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
  'caretakers_not_managers', (
    select count(*) from public.portfolios p
    where p.caretaker_user_id is not null
      and not exists (
        select 1 from public.portfolio_members m
        where m.portfolio_id = p.id and m.user_id = p.caretaker_user_id and m.role = 'manager'
      )
  ),
  'caretaker_since_mismatch', (
    select count(*) from public.portfolios p where (p.caretaker_user_id is null) <> (p.caretaker_since is null)
  ),
  'profiles_without_one_residence', (
    select count(*) from public.profiles p
    where (select count(*) from public.profile_residences r where r.user_id = p.id) <> 1
  ),
  'residences_of_deleted_accounts', (
    select count(*) from public.profile_residences r
    join private.account_deletions d on d.user_id = r.user_id
    where r.residence_country is not null or r.time_zone is not null or r.stated_at is not null
  ),
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
            "ownerless_portfolios", "memberless_portfolios", "orphan_documents",
            "dangling_documents", "documents_of_queued_files", "caretakers_not_managers",
            "caretaker_since_mismatch", "profiles_without_one_residence",
            "residences_of_deleted_accounts"):
    if r[key] != 0: errors.append(f"{key} = {r[key]}")
if abs(float(r["cash_in"]) - float(r["cash_accounted"])) > 0.001: errors.append("cash not conserved")
if errors:
    print("✗ " + "; ".join(errors)); sys.exit(1)
print("✓ concurrency invariants hold")
PY
scenario_done
echo "✓ ${SCENARIOS_DONE} scenarios in $(elapsed "$SUITE_STARTED")"
