#!/usr/bin/env bash
# Replays on PostgreSQL 16 the lock-order behaviours that the Membership
# model documents (README.md, "Residence" and "Finding M2"): an operator's
# writes (a direct Auth delete, a service-role membership change), a restored
# database's foreign-key order, and finding M2, where GoTrue's foreign-key
# actions after admin_delete_account_data meet another deletion on the app's
# own delete-account path.
#
#   R1  set_caretaker(P, M) against a direct Auth delete of M
#       (assume_direct_auth_care): M's membership FOR SHARE, then M's
#       auth.users key last.
#   R2  update_member_role, remove_member and leaving of the caretaker M
#       against a direct Auth delete of M (D1, assume_direct_auth_member):
#       the delete takes the membership, then P for the caretaker's SET NULL.
#       Control: M a manager but not the caretaker, a co-owner's RPC: no
#       wait, no deadlock (leaving is R8).
#       The alternative evaluated, not adopted: a BEFORE DELETE trigger on
#       auth.users that clears the caretaker first (its portfolios in id
#       order) removes R2's deadlock but not R1's, and runs in GoTrue's
#       transaction (README.md, Residence).
#   R3  a service-role demotion or removal of the caretaker M against those
#       RPCs (D2, assume_service_member_write): the membership row, then P in
#       its trigger. With docs/operations.md's rule (the operator locks P
#       first): no deadlock.
#   R4  delete_portfolio(P) against a direct Auth delete of manager M (D3,
#       assume_direct_auth_dport, assume_direct_auth_dport_audit): M has an
#       audit row in P, as everyone who accepted an invitation does. The
#       deletion deletes P's audit trail before the cascade reaches M's
#       membership; the Auth delete takes the membership, then needs M's
#       audit row (actor_id SET NULL) and, for the caretaker, P. A cycle
#       with or without the caretaker; control: no audit row and no
#       caretaker, no cycle.
#   R5  the delete-account order (admin_delete_account_data, then the Auth
#       delete) of M against set_caretaker and update_member_role
#       (caretaker_acct): no deadlock and no error (scenario 31 runs three of
#       these four in CI).
#   R6  the delete-account order of V, who created P and invited M, while a
#       co-owner's set_caretaker(P, M) or update_member_role(P, M) holds P
#       (inviter, assume_restored_inviter): none on a migrated database; a
#       deadlock on a pg_dump | psql copy, whose foreign keys come back in
#       constraint-name order (P1).
#   R7  scenario 23's direct Auth delete while the person marks two
#       notifications read (notes, assume_restored_notes): none on the
#       migrated database, a deadlock in the backward order on the copy (P1).
#   R8  manager M leaves P (remove_member by M) against a direct Auth delete
#       of M, M not the caretaker (assume_direct_auth_leave): the RPC holds
#       M's membership, and its audit row's actor_id check needs M's
#       auth.users key, which the delete holds while it waits for that
#       membership. A key-share holder of M's profile (M's own
#       create_portfolio on another device) stands in for any slower first
#       step of the delete. Control: a co-owner removes M, no deadlock.
#   R9  finding M2 (finding_m2_dport_former): the delete-account order of
#       former manager M, who created a tenant of P (and so has an audit row
#       there), against the owner's delete_portfolio(P): GoTrue holds the
#       tenant (created_by SET NULL) and needs M's audit row; the deletion
#       holds P's audit trail and needs the tenant. A cycle, the current
#       code. Control: the owner created the tenant, no cycle.
#   R10 finding M2 (finding_m2_two_deletions): co-owners A and B of P1 and P2,
#       which A created; set_caretaker on P1 (a non-HOT update: an indexed
#       column changes) moves P1's index entry behind P2's. A's
#       delete-account (GoTrue: created_by SET NULL in that order, P2 then
#       P1) against B's admin_delete_account_data (P1 then P2): a cycle, the
#       current code. Control: no caretaker named, no cycle.
#
# Each race is ordered with a gate (fv.hold), not with sleeps: the first
# session holds its locks at the gate, the second is seen waiting for it
# (pg_blocking_pids), then the gate opens. Which session PostgreSQL aborts on
# a cycle depends on timing and is only reported.
#
# Needs the local test server of tool/db (PGHOST/PGPORT/PGUSER from
# tool/db/env.sh). Rebuilds its own databases: MM_FV_DB (default
# mm_fv_residence) with tool/db/reset.sh, and ${MM_FV_DB}_restored from a
# pg_dump of it. Exits non-zero when a deterministic outcome differs: R1
# (with the trigger too), R2, R3, R4, R6 and R7 on the copy, R8, R9 and R10
# must deadlock; the R2 control, R2 with the trigger, R3 with the rule, the
# R4, R8, R9 and R10 controls, R5, and R6 and R7 on the migrated database
# must not. ROUNDS (default 1) repeats R1 to R4.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
MAIN_DB="${MM_FV_DB:-mm_fv_residence}"
RESTORED_DB="${MAIN_DB}_restored"
ROUNDS="${ROUNDS:-1}"
export PGOPTIONS="-c client_min_messages=warning -c lock_timeout=30s -c statement_timeout=60s"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/residence-replay.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DB="$MAIN_DB"
STATUS=0

psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
fail() {
  echo "  ✗ $*"
  STATUS=1
}
# A session as user $1 running $2; $3, if given, runs first as the superuser
# (the locks an RPC would take, which a client may not take itself).
as_user() {
  cat <<SQL
begin;
${3:-}
set local "request.jwt.claims" to '{"sub":"$1","role":"authenticated"}';
set local role authenticated;
$2
commit;
SQL
}
as_service() {
  cat <<SQL
begin;
set local "request.jwt.claims" to '{"role":"service_role"}';
set local role service_role;
$1
commit;
SQL
}
new_user() {
  psql_db -c "insert into auth.users (id, email, email_confirmed_at)
              values (gen_random_uuid(), '$1-' || gen_random_uuid() || '@example.com', now()) returning id"
}
new_portfolio() {
  psql_db -c "with p as (insert into public.portfolios (name, created_by) values ('$2', '$1') returning id),
                   m as (insert into public.portfolio_members (portfolio_id, user_id, role)
                         select id, '$1', 'owner' from p)
              select id from p"
}
add_member() {
  psql_db -c "insert into public.portfolio_members (portfolio_id, user_id, role, invited_by)
              values ('$1', '$2', '$3', ${4:-null})" >/dev/null
}
# The same, audited with the member as actor, as accept_invitation's insert is.
add_member_audited() {
  psql_db -c "begin" -c "set local \"request.jwt.claims\" to '{\"sub\":\"$2\"}'" \
    -c "insert into public.portfolio_members (portfolio_id, user_id, role) values ('$1', '$2', '$3')" \
    -c "commit" >/dev/null
}
# An estate: owner O, co-owner K, manager M of portfolio P (named $1).
estate() {
  O="$(new_user o)"
  K="$(new_user k)"
  M="$(new_user m)"
  P="$(new_portfolio "$O" "$1")"
  add_member "$P" "$K" owner
  add_member "$P" "$M" manager
}
name_caretaker() { as_user "$O" "select public.set_caretaker('$P', '$M');" | psql_db >/dev/null; }
caretaker() { psql_db -c "select coalesce(caretaker_user_id::text, 'none') from public.portfolios where id = '$P'"; }
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
# await holding NAME | await waiting NAME HOLDERS (as tool/db/concurrency_test.sh;
# HOLDERS is one session name or several, separated by commas)
await() {
  local condition deadline=$((SECONDS + 30)) count
  case "$1" in
    holding) condition="a.state = 'active' and a.query like '%fv.hold(%'" ;;
    waiting)
      condition="a.wait_event_type = 'Lock' and exists (
                   select 1 from pg_stat_activity h
                   where h.datname = a.datname
                     and h.application_name = any (string_to_array('$3', ','))
                     and h.pid = any (pg_blocking_pids(a.pid)))"
      ;;
  esac
  while true; do
    if count="$(psql_db -c "select count(*) from pg_stat_activity a
                            where a.datname = current_database() and a.application_name = '$2'
                              and ${condition}")" && [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)); then
      return 0
    fi
    ((SECONDS < deadline)) || {
      echo "  ✗ session $2 was not $1${3:+ on $3} after 30 s"
      exit 1
    }
    sleep 0.05
  done
}
open_gate() { psql_db -c "insert into fv.gates (name) values ('$1')" >/dev/null; }
# The first error of each file, or "ok".
errors() {
  local file out=""
  for file in "$@"; do
    out+="$(basename "$file" .err)=$(grep -m1 -oE 'ERROR:  [a-z_ ]+' "$file" | cut -c9- || true) "
  done
  sed -E 's/=( |$)/=ok\1/g' <<<"$out"
}
# race FIRST_SQL SECOND_SQL: FIRST (a session script ending at gate $GATE)
# holds; SECOND starts, and must wait for it; then the gate opens. Sets
# FOUND to the deadlocks PostgreSQL detected meanwhile.
race() {
  local before
  before="$(deadlocks)"
  PGAPPNAME=first psql_db <<<"$1" >/dev/null 2>"$WORK/first.err" &
  await holding first
  PGAPPNAME=second psql_db <<<"$2" >/dev/null 2>"$WORK/second.err" &
  await waiting second first
  open_gate "$GATE"
  wait || true
  FOUND=$(($(deadlocks) - before))
}
gate() { GATE="g_$(psql_db -c "select replace(gen_random_uuid()::text, '-', '')")"; }

echo "▸ Building ${MAIN_DB} (tool/db/reset.sh) and ${RESTORED_DB} (pg_dump | psql)"
MM_TEST_DB="$MAIN_DB" "$ROOT/tool/db/reset.sh" >/dev/null
psql_db >/dev/null <<'SQL'
create schema fv;
create table fv.gates (name text primary key);
create function fv.hold(p_gate text) returns void language plpgsql volatile security definer
set search_path = '' as $$
begin
  while not exists (select 1 from fv.gates g where g.name = p_gate) loop
    perform pg_sleep(0.02);
  end loop;
end
$$;
grant usage on schema fv to authenticated, service_role;
grant execute on function fv.hold(text) to authenticated, service_role;
SQL
psql -X -q -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists ${RESTORED_DB} with (force)" \
  -c "create database ${RESTORED_DB}"
pg_dump --no-owner -d "$MAIN_DB" >"$WORK/dump.sql"
psql -X -q -v ON_ERROR_STOP=1 -d "$RESTORED_DB" -f "$WORK/dump.sql" >/dev/null
for db in "$MAIN_DB" "$RESTORED_DB"; do
  echo "  ${db}: GoTrue's foreign-key actions on auth.users, in the order they run:"
  echo "    $(psql -X -q -At -d "$db" -c "
    select string_agg(c.conrelid::regclass || '.' || a.attname, ', ' order by t.tgname collate \"C\")
    from pg_trigger t
    join pg_constraint c on c.oid = t.tgconstraint
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where t.tgrelid = 'auth.users'::regclass and t.tgname like 'RI_ConstraintTrigger_a_%'
      and t.tgtype & 8 = 8")"
done

echo "▸ R1 (assume_direct_auth_care): set_caretaker against a direct Auth delete of the manager"
for round in $(seq 1 "$ROUNDS"); do
  estate "R1 $round"
  gate
  race "$(as_user "$O" "select public.set_caretaker('$P', '$M');" \
    "select from public.portfolios where id = '$P' for no key update;
     select from public.portfolio_members where portfolio_id = '$P' and user_id = '$M' for share;
     select fv.hold('$GATE');")" \
    "delete from auth.users where id = '$M';"
  echo "  round ${round}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")"
  ((FOUND > 0)) || fail "R1 not reproduced"
done

echo "▸ R2 (D1, assume_direct_auth_member): the caretaker's membership changed against a direct Auth delete"
for kind in demote remove leave control; do
  for round in $(seq 1 "$ROUNDS"); do
    estate "R2 $kind $round"
    [[ "$kind" == control ]] || name_caretaker
    case "$kind" in
      demote | control) who="$K" rpc="select public.update_member_role('$P', '$M', 'viewer');" ;;
      remove) who="$K" rpc="select public.remove_member('$P', '$M');" ;;
      leave) who="$M" rpc="select public.remove_member('$P', '$M');" ;;
    esac
    gate
    first="$(as_user "$who" "$rpc" "select from public.portfolios where id = '$P' for update;
                                    select fv.hold('$GATE');")"
    if [[ "$kind" == control ]]; then
      # M is no caretaker: the Auth delete needs nothing the RPC holds.
      before="$(deadlocks)"
      PGAPPNAME=first psql_db <<<"$first" >/dev/null 2>"$WORK/first.err" &
      held=$!
      await holding first
      psql_db -c "delete from auth.users where id = '$M'" >/dev/null 2>"$WORK/second.err" || true
      open_gate "$GATE"
      wait "$held" || true
      FOUND=$(($(deadlocks) - before))
      echo "  control (a manager, not the caretaker) round ${round}: deadlocks ${FOUND};" \
        "$(errors "$WORK/first.err" "$WORK/second.err")"
      ((FOUND == 0)) || fail "R2 control deadlocked"
      grep -q 'member_not_found' "$WORK/first.err" || fail "R2 control: the RPC did not answer member_not_found"
    else
      race "$first" "delete from auth.users where id = '$M';"
      echo "  ${kind} round ${round}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")"
      ((FOUND > 0)) || fail "R2 ${kind} not reproduced"
    fi
  done
done

echo "▸ R1 and R2 with the alternative: a BEFORE DELETE trigger on auth.users clearing the caretaker first"
psql_db >/dev/null <<'SQL'
create function private.replay_before_auth_user_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.portfolios p where p.caretaker_user_id = old.id order by p.id for no key update;
  update public.portfolios p set caretaker_user_id = null where p.caretaker_user_id = old.id;
  return old;
end
$$;
create trigger replay_auth_users_before_delete before delete on auth.users
  for each row execute function private.replay_before_auth_user_delete();
SQL
for kind in demote remove name; do
  estate "R2 trigger $kind"
  gate
  case "$kind" in
    demote | remove)
      name_caretaker
      if [[ "$kind" == demote ]]; then
        rpc="select public.update_member_role('$P', '$M', 'viewer');"
      else
        rpc="select public.remove_member('$P', '$M');"
      fi
      first="$(as_user "$K" "$rpc" "select from public.portfolios where id = '$P' for update;
                                    select fv.hold('$GATE');")"
      ;;
    name)
      first="$(as_user "$O" "select public.set_caretaker('$P', '$M');" \
        "select from public.portfolios where id = '$P' for no key update;
         select from public.portfolio_members where portfolio_id = '$P' and user_id = '$M' for share;
         select fv.hold('$GATE');")"
      ;;
  esac
  race "$first" "delete from auth.users where id = '$M';"
  echo "  ${kind}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")"
  if [[ "$kind" == name ]]; then
    ((FOUND > 0)) || fail "R1 with the trigger: no deadlock (re-evaluate the trigger)"
  else
    ((FOUND == 0)) || fail "R2 ${kind} with the trigger deadlocked"
  fi
done
psql_db >/dev/null <<'SQL'
drop trigger replay_auth_users_before_delete on auth.users;
drop function private.replay_before_auth_user_delete();
SQL

echo "▸ R3 (D2, assume_service_member_write): a service-role write of the caretaker's membership"
for svc in demote remove; do
  for rpc_kind in demote remove; do
    for rule in without with; do
      for round in $(seq 1 "$ROUNDS"); do
        estate "R3 $svc $rpc_kind $rule $round"
        name_caretaker
        case "$rpc_kind" in
          demote) rpc="select public.update_member_role('$P', '$M', 'viewer');" ;;
          remove) rpc="select public.remove_member('$P', '$M');" ;;
        esac
        case "$svc" in
          demote) op="update public.portfolio_members set role = 'viewer' where portfolio_id = '$P' and user_id = '$M';" ;;
          remove) op="delete from public.portfolio_members where portfolio_id = '$P' and user_id = '$M';" ;;
        esac
        [[ "$rule" == with ]] && op="select 1 from public.portfolios where id = '$P' for update; $op"
        gate
        race "$(as_user "$K" "$rpc" "select from public.portfolios where id = '$P' for update;
                                     select fv.hold('$GATE');")" "$(as_service "$op")"
        echo "  service ${svc} vs ${rpc_kind}, ${rule} the rule, round ${round}: deadlocks ${FOUND};" \
          "$(errors "$WORK/first.err" "$WORK/second.err") caretaker: $(caretaker)"
        if [[ "$rule" == without ]]; then
          ((FOUND > 0)) || fail "R3 ${svc} vs ${rpc_kind} not reproduced"
        else
          ((FOUND == 0)) || fail "R3 ${svc} vs ${rpc_kind}: the operator's rule did not avoid the deadlock"
        fi
      done
    done
  done
done

echo "▸ R4 (D3, assume_direct_auth_dport*): delete_portfolio against a direct Auth delete of a manager"
for kind in caretaker audit control; do
  for round in $(seq 1 "$ROUNDS"); do
    O="$(new_user o)"
    M="$(new_user m)"
    P="$(new_portfolio "$O" "R4 $kind $round")"
    if [[ "$kind" == control ]]; then add_member "$P" "$M" manager; else add_member_audited "$P" "$M" manager; fi
    [[ "$kind" != caretaker ]] || name_caretaker
    gate
    before="$(deadlocks)"
    # A key-share holder of M's membership: the Auth delete's cascade queues
    # on it first and the deletion (holding P) behind it; when it commits, the
    # Auth delete takes the membership and needs P.
    PGAPPNAME=hold psql_db -c "begin" \
      -c "select from public.portfolio_members where portfolio_id = '$P' and user_id = '$M' for key share" \
      -c "select fv.hold('$GATE')" -c "commit" >/dev/null 2>"$WORK/hold.err" &
    await holding hold
    PGAPPNAME=go psql_db -c "delete from auth.users where id = '$M'" >/dev/null 2>"$WORK/go.err" &
    await waiting go hold
    as_user "$O" "select public.delete_portfolio('$P', 'R4 $kind $round');" \
      | PGAPPNAME=del psql_db >/dev/null 2>"$WORK/del.err" &
    # It queues behind the Auth delete on the membership's tuple lock, or
    # behind the holder itself.
    await waiting del go,hold
    open_gate "$GATE"
    wait || true
    FOUND=$(($(deadlocks) - before))
    echo "  ${kind} round ${round}: deadlocks ${FOUND}; $(errors "$WORK/del.err" "$WORK/go.err")" \
      "portfolio left: $(psql_db -c "select count(*) from public.portfolios where id = '$P'")," \
      "auth user left: $(psql_db -c "select count(*) from auth.users where id = '$M'")"
    if [[ "$kind" == control ]]; then
      ((FOUND == 0)) || fail "R4 control deadlocked"
    else
      ((FOUND > 0)) || fail "R4 ${kind}: no cycle formed"
    fi
  done
done

echo "▸ R5 (caretaker_acct): the delete-account order of the manager"
for c in naming_holds deletion_holds demote_holds abroad_holds; do
  estate "R5 $c"
  delete_account="$(as_service "select public.admin_delete_account_data('$M') is not null;")
delete from auth.users where id = '$M';"
  gate
  case "$c" in
    naming_holds)
      first="$(as_user "$O" "select public.set_caretaker('$P', '$M'); select fv.hold('$GATE');")"
      second="$delete_account"
      ;;
    deletion_holds)
      first="$(as_service "select public.admin_delete_account_data('$M') is not null; select fv.hold('$GATE');")"
      second="$(as_user "$O" "select public.set_caretaker('$P', '$M');")"
      ;;
    demote_holds)
      name_caretaker
      first="$(as_user "$K" "select public.update_member_role('$P', '$M', 'viewer');" \
        "select from public.portfolios where id = '$P' for update; select fv.hold('$GATE');")"
      second="$delete_account"
      ;;
    abroad_holds)
      name_caretaker
      first="$(as_user "$O" "select public.set_owner_abroad('$P', true);" \
        "select from public.portfolios where id = '$P' for no key update; select fv.hold('$GATE');")"
      second="$delete_account"
      ;;
  esac
  race "$first" "$second"
  [[ "$c" == deletion_holds ]] && psql_db -c "delete from auth.users where id = '$M'" >/dev/null
  left="$(psql_db -c "select count(*) from auth.users where id = '$M'")"
  echo "  ${c}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")" \
    "caretaker: $(caretaker), auth user left: ${left}"
  ((FOUND == 0)) || fail "R5 ${c}: the delete-account order deadlocked"
  [[ "$(caretaker)" == none && "$left" == 0 ]] || fail "R5 ${c}: the caretaker or the auth user is left"
  if [[ "$c" == deletion_holds ]]; then
    grep -q 'member_not_found' "$WORK/second.err" || fail "R5 ${c}: set_caretaker did not answer member_not_found"
    [[ ! -s "$WORK/first.err" ]] || fail "R5 ${c}: an error in the deletion"
  else
    [[ ! -s "$WORK/first.err" && ! -s "$WORK/second.err" ]] || fail "R5 ${c}: an error"
  fi
done

echo "▸ R6 (inviter, assume_restored_inviter): the delete-account order of the creator who invited the manager"
for db in "$MAIN_DB" "$RESTORED_DB"; do
  DB="$db"
  for rpc_kind in caretaker demote; do
    V="$(new_user v)"
    K="$(new_user k)"
    M="$(new_user m)"
    P="$(new_portfolio "$V" "R6")"
    add_member "$P" "$K" owner
    add_member "$P" "$M" manager "'$V'"
    as_service "select public.admin_delete_account_data('$V') is not null;" | psql_db >/dev/null
    case "$rpc_kind" in
      caretaker) rpc="select public.set_caretaker('$P', '$M');" lock="for no key update" ;;
      demote) rpc="select public.update_member_role('$P', '$M', 'viewer');" lock="for update" ;;
    esac
    gate
    race "$(as_user "$K" "$rpc" "select from public.portfolios where id = '$P' $lock;
                                 select fv.hold('$GATE');")" "delete from auth.users where id = '$V';"
    echo "  ${db} ${rpc_kind}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")"
    if [[ "$db" == "$MAIN_DB" ]]; then
      ((FOUND == 0)) || fail "R6 ${rpc_kind}: the migrated database deadlocked"
    else
      ((FOUND > 0)) || fail "R6 ${rpc_kind}: not reproduced on the restored copy"
    fi
  done
done

echo "▸ R7 (notes, assume_restored_notes): two notifications marked read during a direct Auth delete"
for db in "$MAIN_DB" "$RESTORED_DB"; do
  DB="$db"
  for order in forward backward; do
    H="$(new_user h)"
    U="$(new_user u)"
    P="$(new_portfolio "$H" "R7")"
    add_member "$P" "$U" manager
    mapfile -t IDS < <(psql_db -c "insert into public.notifications (portfolio_id, user_id, kind, dedupe_key)
                                   select '$P', '$U', 'rent_due_soon', 'r7-' || g || '-' || gen_random_uuid()
                                   from generate_series(1, 2) g returning id")
    [[ "$order" == backward ]] && IDS=("${IDS[1]}" "${IDS[0]}")
    gate
    race "$(as_user "$U" "update public.notifications set read_at = now() where id = '${IDS[0]}';
                          select fv.hold('$GATE');
                          update public.notifications set read_at = now() where id = '${IDS[1]}';")" \
      "delete from auth.users where id = '$U';"
    echo "  ${db} ${order}: deadlocks ${FOUND}; $(errors "$WORK/first.err" "$WORK/second.err")"
    if [[ "$db" == "$MAIN_DB" || "$order" == forward ]]; then
      ((FOUND == 0)) || fail "R7 ${order}: deadlocked on ${db}"
    else
      ((FOUND > 0)) || fail "R7 backward: not reproduced on the restored copy"
    fi
  done
done

DB="$MAIN_DB"
echo "▸ R8 (assume_direct_auth_leave): a manager leaves during a direct Auth delete of them"
for who in self coowner; do
  estate "R8 $who"
  [[ "$who" == self ]] && caller="$M" || caller="$K"
  gate
  before="$(deadlocks)"
  # M's own create_portfolio on another device (require_active_account)
  # holds M's profile key: the Auth delete, holding M's auth.users row,
  # waits for it at its first foreign-key action.
  PGAPPNAME=hold psql_db -c "begin" -c "select from public.profiles where id = '$M' for key share" \
    -c "select fv.hold('$GATE')" -c "commit" >/dev/null 2>"$WORK/hold.err" &
  await holding hold
  PGAPPNAME=go psql_db -c "delete from auth.users where id = '$M'" >/dev/null 2>"$WORK/go.err" &
  await waiting go hold
  as_user "$caller" "select public.remove_member('$P', '$M');" \
    | PGAPPNAME=rpc psql_db >/dev/null 2>"$WORK/rpc.err" &
  rpc=$!
  if [[ "$who" == self ]]; then
    await waiting rpc go
  else
    wait "$rpc" || true
  fi
  open_gate "$GATE"
  wait || true
  FOUND=$(($(deadlocks) - before))
  echo "  remove_member(P, M) by ${who}: deadlocks ${FOUND}; $(errors "$WORK/rpc.err" "$WORK/go.err")" \
    "auth user left: $(psql_db -c "select count(*) from auth.users where id = '$M'")"
  if [[ "$who" == self ]]; then
    ((FOUND > 0)) || fail "R8: leaving did not deadlock"
  else
    ((FOUND == 0)) || fail "R8 control: a co-owner's removal deadlocked"
  fi
done

echo "▸ R9 (finding M2, finding_m2_dport_former): a former manager's delete-account against delete_portfolio"
for creator in manager owner; do
  O="$(new_user o)"
  M="$(new_user m)"
  P="$(new_portfolio "$O" "R9 $creator")"
  add_member "$P" "$M" manager
  R="$(psql_db -c "insert into public.properties (portfolio_id, name, city, province, created_by)
                   values ('$P', 'R9', 'Lahore', 'punjab', '$O') returning id")"
  [[ "$creator" == manager ]] && sub="$M" || sub="$O"
  # The tenant's insert is audited with its creator as actor.
  psql_db -c "begin" -c "set local \"request.jwt.claims\" to '{\"sub\":\"$sub\"}'" \
    -c "insert into public.tenants (portfolio_id, full_name) values ('$P', 'R9')" -c "commit" >/dev/null
  # M's delete-account: admin_delete_account_data first (M leaves P) ...
  as_service "select public.admin_delete_account_data('$M') is not null;" | psql_db >/dev/null
  rows="$(psql_db -c "select (select count(*) from public.tenants where portfolio_id = '$P' and created_by = '$M')
                             || ' tenant, ' || (select count(*) from public.audit_logs
                                                where portfolio_id = '$P' and actor_id = '$M') || ' audit row'")"
  gate
  before="$(deadlocks)"
  # A key-share holder of the property: the deletion's cascade waits for it
  # after it has deleted P's audit trail, before it reaches the tenants.
  PGAPPNAME=hold psql_db -c "begin" -c "select from public.properties where id = '$R' for key share" \
    -c "select fv.hold('$GATE')" -c "commit" >/dev/null 2>"$WORK/hold.err" &
  await holding hold
  as_user "$O" "select public.delete_portfolio('$P', 'R9 $creator');" \
    | PGAPPNAME=del psql_db >/dev/null 2>"$WORK/del.err" &
  await waiting del hold
  # ... then GoTrue's delete.
  PGAPPNAME=go psql_db -c "delete from auth.users where id = '$M'" >/dev/null 2>"$WORK/go.err" &
  if [[ "$creator" == manager ]]; then await waiting go del; fi
  open_gate "$GATE"
  wait || true
  FOUND=$(($(deadlocks) - before))
  echo "  the tenant created by the ${creator} (M's rows in P: ${rows}): deadlocks ${FOUND};" \
    "$(errors "$WORK/del.err" "$WORK/go.err") auth user left: $(psql_db -c "select count(*) from auth.users where id = '$M'")"
  if [[ "$creator" == manager ]]; then
    ((FOUND > 0)) || fail "R9: finding M2 not reproduced (if a fix landed, flip this case)"
  else
    ((FOUND == 0)) || fail "R9 control deadlocked"
  fi
done

echo "▸ R10 (finding M2, finding_m2_two_deletions): two co-owners' delete-account, GoTrue's SET NULL in heap order"
for named in yes no; do
  A="$(new_user a)"
  B="$(new_user b)"
  C="$(new_user c)"
  P1="$(psql_db -c "with p as (insert into public.portfolios (id, name, created_by)
                                values (app.uuid_generate_v7(), 'R10 one', '$A') returning id),
                         m as (insert into public.portfolio_members (portfolio_id, user_id, role)
                               select id, '$A', 'owner' from p)
                    select id from p")"
  P2="$(psql_db -c "with p as (insert into public.portfolios (id, name, created_by)
                                values (app.uuid_generate_v7(), 'R10 two', '$A') returning id),
                         m as (insert into public.portfolio_members (portfolio_id, user_id, role)
                               select id, '$A', 'owner' from p)
                    select id from p")"
  psql_db -c "insert into public.portfolio_members (portfolio_id, user_id, role)
              values ('$P1', '$B', 'owner'), ('$P2', '$B', 'owner'), ('$P1', '$C', 'manager')" >/dev/null
  if [[ "$named" == yes ]]; then
    as_user "$A" "select public.set_caretaker('$P1', '$C');" | psql_db >/dev/null
  fi
  as_service "select public.admin_delete_account_data('$A') is not null;" | psql_db >/dev/null
  scan="$(psql_db -c "select string_agg(case id when '$P1' then 'P1' else 'P2' end, ' ' order by ctid)
                      from public.portfolios where created_by = '$A'")"
  gate
  before="$(deadlocks)"
  # A key-share holder of P2 stops B's deletion between its two locks.
  PGAPPNAME=hold psql_db -c "begin" -c "select from public.portfolios where id = '$P2' for key share" \
    -c "select fv.hold('$GATE')" -c "commit" >/dev/null 2>"$WORK/hold.err" &
  await holding hold
  as_service "select public.admin_delete_account_data('$B') is not null;" \
    | PGAPPNAME=delB psql_db >/dev/null 2>"$WORK/delB.err" &
  await waiting delB hold
  PGAPPNAME=goA psql_db -c "delete from auth.users where id = '$A'" >/dev/null 2>"$WORK/goA.err" &
  if [[ "$named" == yes ]]; then await waiting goA delB; fi
  open_gate "$GATE"
  wait || true
  FOUND=$(($(deadlocks) - before))
  echo "  caretaker named: ${named}, heap order of A's portfolios: ${scan}: deadlocks ${FOUND};" \
    "$(errors "$WORK/delB.err" "$WORK/goA.err") auth user A left: $(psql_db -c "select count(*) from auth.users where id = '$A'")"
  if [[ "$named" == yes ]]; then
    [[ "$scan" == "P2 P1" ]] || fail "R10: set_caretaker did not move P1 behind P2 (${scan})"
    ((FOUND > 0)) || fail "R10: finding M2 not reproduced (if a fix landed, flip this case)"
  else
    ((FOUND == 0)) || fail "R10 control deadlocked"
  fi
done

if ((STATUS == 0)); then
  echo "Every outcome as expected on PostgreSQL $(psql_db -c 'show server_version')."
else
  echo "✗ Some outcomes differ (above)."
fi
exit "$STATUS"
