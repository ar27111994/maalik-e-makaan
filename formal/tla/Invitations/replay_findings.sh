#!/usr/bin/env bash
# Replays the four findings of the TLA+ model (F1-F4, see README.md) on a
# real PostgreSQL 16 database built from supabase/migrations, to cross-check
# that the counterexamples are not artefacts of the model.
#
# Each replay forces the interleaving of the TLC counterexample with
# pg_sleep: one session holds its transaction open at the point the trace
# says, the other runs into it.
#
#   F1  two concurrent create_invitation calls for one e-mail: the second
#       fails with 23505 (portfolio_invitations_pending_email_key).
#   F2  a re-invite racing an acceptance; a retried accept_invitation then
#       reports the second invitation's role, not the member's role.
#   F3  the inviter's auth user deleted directly while an acceptance holds
#       the invitation row: one of them is aborted with 40P01. To reach the
#       trace's interleaving deterministically, the accepting session takes
#       the invitation's row lock first (as accept_invitation's own
#       SELECT ... FOR UPDATE does) and calls accept_invitation after the
#       deletion has started.
#   F4  the inviter's auth user deleted directly: the membership trigger
#       fires after invited_by was set to NULL, so the inviter's pending
#       invitation stays pending (and accept_invitation still refuses it).
#
# Needs the local test server of tool/db (PGHOST/PGPORT/PGUSER from
# tool/db/env.sh). Uses its own database (MM_FV_DB, default
# mm_fv_invitations), recreated by tool/db/reset.sh. Prints what happened and
# exits non-zero if an outcome differs from the model's counterexample.
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
echo "▸ F1: two owners re-invite one e-mail at the same time"
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
grep -q 'portfolio_invitations_pending_email_key' "$WORK/f1_b.err" \
  || fail "F1 not reproduced: the second create did not fail with 23505"
echo "  ✓ reproduced: 23505 on portfolio_invitations_pending_email_key"

# F2 -------------------------------------------------------------------------
echo "▸ F2: a retried acceptance reports a role the member does not have"
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
[[ "$ACTUAL" == manager ]] || fail "F2 not reproduced: unexpected member role $ACTUAL"
if ! { grep -q '"role": "viewer"' <<<"$R3" && grep -q '"status": "accepted"' <<<"$R3"; }; then
  fail "F2 not reproduced: the retry did not report viewer"
fi
echo "  ✓ reproduced: the retry reports 'viewer' for a 'manager'"

# F3 -------------------------------------------------------------------------
echo "▸ F3: the inviter's auth user deleted directly during an acceptance"
reset_limits
O1="$(new_user "f3-owner1@example.com")"
O2="$(new_user "f3-owner2@example.com")"
U="$(new_user "f3-guest@example.com")"
P="$(new_portfolio "$O2" "F3")"
add_owner "$P" "$O1"
T="$(as_user "$O1" "select public.create_invitation('$P', 'f3-guest@example.com', 'manager') ->> 'token';" | psql_db)"
J="${T%%.*}"
# The accepting session: holds the invitation row (the FOR UPDATE that
# accept_invitation takes), waits, then runs accept_invitation in the same
# transaction; its membership INSERT's FK check needs key share on o1's
# auth.users row.
# (The row lock is taken before switching to the caller's role: clients may
# not lock invitation rows themselves.)
psql_db >"$WORK/f3_a.out" 2>"$WORK/f3_a.err" <<SQL &
begin;
select 1 from public.portfolio_invitations where id = '$J' for update;
set local "request.jwt.claims" to '{"sub":"$U","role":"authenticated"}';
set local role authenticated;
select pg_sleep(1);
select public.accept_invitation('$T') ->> 'status';
commit;
SQL
sleep 0.4
# GoTrue's deletion: locks o1's auth.users row; its cascade deletes o1's
# membership, whose trigger must revoke the invitation the session holds.
psql_db -c "delete from auth.users where id = '$O1'" >"$WORK/f3_b.out" 2>"$WORK/f3_b.err" || true
wait || true
echo "  accept:      $(cat "$WORK/f3_a.out" "$WORK/f3_a.err" | tr '\n' ' ')"
echo "  user delete: $(cat "$WORK/f3_b.out" "$WORK/f3_b.err" | tr '\n' ' ')"
cat "$WORK/f3_a.err" "$WORK/f3_b.err" | grep -q 'deadlock detected' \
  || fail "F3 not reproduced: no 40P01"
echo "  ✓ reproduced: 40P01 deadlock detected"

# F4 -------------------------------------------------------------------------
echo "▸ F4: the inviter's auth user deleted directly leaves a pending invitation"
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
[[ "$STATE" == "NULL revoked=false" ]] || fail "F4 not reproduced: $STATE"
echo "  ✓ reproduced: still pending, with invited_by NULL (the membership trigger matched nothing)"
R="$(as_user "$U" "select public.accept_invitation('$T') ->> 'status';" | psql_db)"
STATE="$(psql_db -c "select (revoked_at is not null) from public.portfolio_invitations where id = '$J'")"
echo "  accept_invitation: $R, revocation recorded: $STATE"
[[ "$R" == revoked && "$STATE" == t ]] || fail "accept_invitation did not refuse the orphaned invitation"
echo "  ✓ and accept_invitation refuses and revokes it (safety holds)"

rm -rf "${WORK:?}"
echo "All four findings reproduced on PostgreSQL ($(psql_db -c 'show server_version'))."
