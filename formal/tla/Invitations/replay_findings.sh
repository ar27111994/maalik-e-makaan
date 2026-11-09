#!/usr/bin/env bash
# Replays the interleavings of the four findings of the TLA+ model (F1-F4,
# see README.md) on a real PostgreSQL (16 or 17) database built from
# supabase/migrations. F1, F2 and F4 are fixed by
# supabase/migrations/20261108082804_invitation_findings.sql: their replays
# check the fixed outcome. F3 is not changed in code (operational rule in
# docs/operations.md): its replay still shows the deadlock of a direct Auth
# deletion, and checks that the documented order (admin_delete_account_data
# first) has none.
#
# Each replay forces the interleaving of the TLC counterexample with
# pg_sleep: one session holds its transaction open at the point the trace
# says, the other runs into it.
#
#   F1  two concurrent create_invitation calls for one e-mail: before the
#       fix the second failed with 23505 (portfolio_invitations_pending_
#       email_key); now it waits for the first and replaces its invitation.
#   F2  a re-invite racing an acceptance; a retried accept_invitation
#       reported the second invitation's role; now the member's role. A
#       retry after the member was removed answers revoked.
#   F3  the inviter's auth user deleted directly while an acceptance holds
#       the invitation row: one of them is aborted with 40P01. To reach the
#       trace's interleaving deterministically, the accepting session takes
#       accept_invitation's locks first (the portfolio key, then the
#       invitation row) and calls accept_invitation after the deletion has
#       started. The same interleaving with admin_delete_account_data before
#       the deletion (the delete-account order) must not deadlock; with a
#       BEFORE DELETE trigger on auth.users doing that work instead (the
#       rejected alternative) it still deadlocks.
#   F4  the inviter's auth user deleted directly: the membership trigger
#       fires after invited_by was set to NULL; before the fix the
#       invitation stayed pending, now it is revoked.
#
# Needs the local test server of tool/db (PGHOST/PGPORT/PGUSER from
# tool/db/env.sh). Uses its own database (MM_FV_DB, default
# mm_fv_invitations), recreated by tool/db/reset.sh. Prints what happened and
# exits non-zero if an outcome differs from the expected one.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tool/db/env.sh"
export MM_TEST_DB="${MM_FV_DB:-mm_fv_invitations}"
"$ROOT/tool/db/reset.sh" >/dev/null

WORK="$(mktemp -d "${TMPDIR:-/tmp}/invitations-replay.XXXXXX")"
psql_db() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" "$@"; }
as_user() {
  cat <<SQL
begin;
set local "request.jwt.claims" to '{"sub":"$1","role":"authenticated"}';
set local role authenticated;
$2
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
add_owner() {
  psql_db -c "insert into public.portfolio_members (portfolio_id, user_id, role) values ('$1', '$2', 'owner')" >/dev/null
}
reset_limits() { psql_db -c "delete from private.rate_limit_buckets" >/dev/null; }
fail() {
  echo "✗ $*"
  exit 1
}

# F1 -------------------------------------------------------------------------
echo "▸ F1 (fixed): two owners re-invite one e-mail at the same time"
reset_limits
O1="$(new_user "f1-owner1@example.com")"
O2="$(new_user "f1-owner2@example.com")"
P="$(new_portfolio "$O1" "F1")"
add_owner "$P" "$O2"
as_user "$O1" "select public.create_invitation('$P', 'f1-guest@example.com', 'manager') ->> 'role'; select pg_sleep(1.5);" \
  | psql_db >"$WORK/f1_a.out" 2>"$WORK/f1_a.err" &
sleep 0.5
as_user "$O2" "select public.create_invitation('$P', 'f1-guest@example.com', 'viewer') ->> 'role';" \
  | psql_db >"$WORK/f1_b.out" 2>"$WORK/f1_b.err" || true
wait
echo "  first create:  $(cat "$WORK/f1_a.out" "$WORK/f1_a.err" | tr '\n' ' ')"
echo "  second create: $(cat "$WORK/f1_b.out" "$WORK/f1_b.err" | tr '\n' ' ')"
[[ ! -s "$WORK/f1_a.err" && ! -s "$WORK/f1_b.err" ]] || fail "F1: a create failed"
[[ "$(cat "$WORK/f1_b.out")" == viewer ]] || fail "F1: the second create did not succeed"
PENDING="$(psql_db -c "select string_agg(role::text, ',') from public.portfolio_invitations
                       where portfolio_id = '$P' and accepted_at is null and revoked_at is null")"
echo "  pending afterwards: $PENDING"
[[ "$PENDING" == viewer ]] || fail "F1: expected only the second invitation pending, got $PENDING"
echo "  ✓ fixed: no 23505; the second create waited and replaced the first invitation"

# F2 -------------------------------------------------------------------------
echo "▸ F2 (fixed): a retried acceptance reports the member's role"
reset_limits
O1="$(new_user "f2-owner1@example.com")"
O2="$(new_user "f2-owner2@example.com")"
U="$(new_user "f2-guest@example.com")"
P="$(new_portfolio "$O1" "F2")"
add_owner "$P" "$O2"
T1="$(as_user "$O1" "select public.create_invitation('$P', 'f2-guest@example.com', 'manager') ->> 'token';" | psql_db)"
# u accepts invitation 1 and keeps the transaction open ...
as_user "$U" "select public.accept_invitation('$T1') ->> 'role'; select pg_sleep(1.5);" \
  | psql_db >"$WORK/f2_a.out" 2>"$WORK/f2_a.err" &
sleep 0.5
# ... while o2 re-invites the same e-mail as viewer: its already_member check
# passes (the membership is not committed yet) and its UPDATE waits for the
# invitation row, which is accepted when it may go on.
T2="$(as_user "$O2" "select public.create_invitation('$P', 'f2-guest@example.com', 'viewer') ->> 'token';" | psql_db)"
wait
R2="$(as_user "$U" "select (public.accept_invitation('$T2'))::text;" | psql_db)"
R3="$(as_user "$U" "select (public.accept_invitation('$T2'))::text;" | psql_db)"
ACTUAL="$(psql_db -c "select role from public.portfolio_members where portfolio_id = '$P' and user_id = '$U'")"
echo "  accept #1: $(cat "$WORK/f2_a.out" "$WORK/f2_a.err" | head -1)"
echo "  accept #2: $R2"
echo "  retry #2:  $R3"
echo "  member role in portfolio_members: $ACTUAL"
[[ "$ACTUAL" == manager ]] || fail "F2: unexpected member role $ACTUAL"
if ! { grep -q '"role": "manager"' <<<"$R3" && grep -q '"status": "accepted"' <<<"$R3"; }; then
  fail "F2: the retry did not report manager"
fi
echo "  ✓ fixed: the retry reports 'manager', the role the member has"
# The former-member case (Invitations_current_response_role_removed.cfg): an
# owner removes u, then u retries the accepted token once more.
as_user "$O1" "select public.remove_member('$P', '$U');" | psql_db >/dev/null
R4="$(as_user "$U" "select (public.accept_invitation('$T2'))::text;" | psql_db)"
echo "  retry #2 after u was removed: $R4"
[[ "$R4" == '{"status": "revoked"}' ]] || fail "F2: a former member's retry did not answer revoked"
[[ -z "$(psql_db -c "select 1 from public.portfolio_members where portfolio_id = '$P' and user_id = '$U'")" ]] \
  || fail "F2: the retry added the former member back"
echo "  ✓ fixed: a former member's retry answers revoked, not a role they no longer hold"

# F3 -------------------------------------------------------------------------
# $1: "direct" (GoTrue's delete alone) or "delete_account" (the order of the
# delete-account Edge Function: admin_delete_account_data, then the delete).
# Prints the deadlocks PostgreSQL detected and the outcomes.
f3_race() {
  local o1 o2 u p t j before
  reset_limits
  o1="$(new_user "f3-$1-owner1@example.com")"
  o2="$(new_user "f3-$1-owner2@example.com")"
  u="$(new_user "f3-$1-guest@example.com")"
  p="$(new_portfolio "$o2" "F3 $1")"
  add_owner "$p" "$o1"
  t="$(as_user "$o1" "select public.create_invitation('$p', 'f3-$1-guest@example.com', 'manager') ->> 'token';" | psql_db)"
  j="${t%%.*}"
  before="$(psql_db -c "select deadlocks from pg_stat_database where datname = current_database()")"
  # The accepting session: takes accept_invitation's locks in its order (its
  # profile and the portfolio key, then the invitation row), waits, then runs
  # accept_invitation in the same transaction; its membership INSERT's FK
  # check needs key share on o1's auth.users row. (The locks are taken before
  # switching to the caller's role: clients may not lock these rows.)
  psql_db >"$WORK/f3_$1_a.out" 2>"$WORK/f3_$1_a.err" <<SQL &
begin;
select 1 from public.profiles where id = '$u' for key share;
select 1 from public.portfolios where id = '$p' for key share;
select 1 from public.portfolio_invitations where id = '$j' for update;
set local "request.jwt.claims" to '{"sub":"$u","role":"authenticated"}';
set local role authenticated;
select pg_sleep(1);
select public.accept_invitation('$t') ->> 'status';
commit;
SQL
  sleep 0.4
  if [[ "$1" == delete_account ]]; then
    psql_db -c "select public.admin_delete_account_data('$o1') is not null" >"$WORK/f3_$1_b.out" 2>"$WORK/f3_$1_b.err" || true
  fi
  # GoTrue's deletion: locks o1's auth.users row; its cascade deletes o1's
  # membership, whose trigger must revoke the invitation the session holds.
  psql_db -c "delete from auth.users where id = '$o1'" >>"$WORK/f3_$1_b.out" 2>>"$WORK/f3_$1_b.err" || true
  wait || true
  sleep 0.5
  echo "  $1: accept:      $(cat "$WORK/f3_$1_a.out" "$WORK/f3_$1_a.err" | tr '\n' ' ' | cut -c1-160)"
  echo "  $1: user delete: $(cat "$WORK/f3_$1_b.out" "$WORK/f3_$1_b.err" | tr '\n' ' ' | cut -c1-160)"
  F3_DEADLOCKS=$(($(psql_db -c "select deadlocks from pg_stat_database where datname = current_database()") - before))
  F3_PENDING="$(psql_db -c "select count(*) from public.portfolio_invitations
                            where id = '$j' and accepted_at is null and revoked_at is null")"
  echo "  $1: deadlocks detected: $F3_DEADLOCKS; invitation still pending: $F3_PENDING"
}
echo "▸ F3 (open, operational rule): the inviter's auth user deleted during an acceptance"
f3_race direct
((F3_DEADLOCKS > 0)) || fail "F3 not reproduced: no 40P01 on the direct deletion"
echo "  ✓ reproduced on the direct path: 40P01 (docs/operations.md: delete accounts through delete-account)"
f3_race delete_account
((F3_DEADLOCKS == 0)) || fail "F3: the delete-account order deadlocked"
[[ "$F3_PENDING" == 0 ]] || fail "F3: the delete-account order left the invitation pending"
[[ ! -s "$WORK/f3_delete_account_a.err" && ! -s "$WORK/f3_delete_account_b.err" ]] \
  || fail "F3: an error on the delete-account order"
echo "  ✓ the delete-account order (admin_delete_account_data first): no deadlock, no error"
# The rejected alternative: a BEFORE DELETE trigger on auth.users running
# admin_delete_account_data. PostgreSQL locks the auth.users row before a
# BEFORE ROW trigger runs, so the trigger takes the portfolio after the auth
# row, the reverse of the accept's FK check: it still deadlocks.
psql_db >/dev/null <<'SQL'
create function private.replay_before_auth_user_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.admin_delete_account_data(old.id);
  return old;
end
$$;
create trigger replay_auth_users_before_delete before delete on auth.users
  for each row execute function private.replay_before_auth_user_delete();
SQL
f3_race with_trigger
psql_db >/dev/null <<'SQL'
drop trigger replay_auth_users_before_delete on auth.users;
drop function private.replay_before_auth_user_delete();
SQL
((F3_DEADLOCKS > 0)) || fail "F3: the BEFORE DELETE trigger alternative did not deadlock (re-evaluate it)"
echo "  ✓ a BEFORE DELETE trigger on auth.users would not help: still 40P01"

# F4 -------------------------------------------------------------------------
echo "▸ F4 (fixed): the inviter's auth user deleted directly leaves nothing pending"
reset_limits
O1="$(new_user "f4-owner1@example.com")"
O2="$(new_user "f4-owner2@example.com")"
U="$(new_user "f4-guest@example.com")"
P="$(new_portfolio "$O2" "F4")"
add_owner "$P" "$O1"
T="$(as_user "$O1" "select public.create_invitation('$P', 'f4-guest@example.com', 'viewer') ->> 'token';" | psql_db)"
J="${T%%.*}"
psql_db -c "delete from auth.users where id = '$O1'" >/dev/null
STATE="$(psql_db -c "select coalesce(invited_by::text, 'NULL') || ' revoked=' || (revoked_at is not null) from public.portfolio_invitations where id = '$J'")"
echo "  after the deletion: invited_by=$STATE"
[[ "$STATE" == "NULL revoked=true" ]] || fail "F4: the invitation was not revoked: $STATE"
echo "  ✓ fixed: revoked by the membership trigger although invited_by is already NULL"
R="$(as_user "$U" "select public.accept_invitation('$T') ->> 'status';" | psql_db)"
echo "  accept_invitation: $R"
[[ "$R" == revoked ]] || fail "accept_invitation did not refuse the revoked invitation"
echo "  ✓ and accept_invitation answers revoked"

rm -rf "${WORK:?}"
echo "F1, F2 and F4 fixed and F3's remedy checked on PostgreSQL ($(psql_db -c 'show server_version'))."
