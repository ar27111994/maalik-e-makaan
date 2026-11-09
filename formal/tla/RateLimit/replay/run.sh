#!/usr/bin/env bash
# Replays finding F4 of RateLimit.tla on a plain PostgreSQL server with the
# Supabase shim and every migration (tool/db/reset.sh), in the disposable
# database mm_fv_ratelimit (dropped at the end; connection settings from
# tool/db/env.sh). Also measures how one user's writes queue on the
# api_write bucket row. Exits non-zero unless F4 shows on the current code.
#
#   F4  a hit counted inside the request's transaction is rolled back with
#       it: writes that fail after the limiter (here record_payment with an
#       invalid amount) are never limited, and do not use up the quota
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
DB=mm_fv_ratelimit
trap 'psql -X -q -d postgres -c "drop database if exists $DB with (force)" >/dev/null 2>&1 || true' EXIT
q() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

MM_TEST_DB="$DB" "$ROOT/tool/db/reset.sh" >/dev/null
read -r OWNER PORTFOLIO LEASE < <(
  q -F ' ' <<'SQL'
set app.today_override = '2026-10-12';
with u as (
  insert into auth.users (id, email, email_confirmed_at)
  values (gen_random_uuid(), 'fv-rate-limit@example.com', now()) returning id
), p as (insert into public.portfolios (name, created_by) select 'FV', id from u returning id, created_by),
m as (insert into public.portfolio_members (portfolio_id, user_id, role)
      select id, created_by, 'owner' from p returning portfolio_id),
prop as (insert into public.properties (portfolio_id, name, city, province)
         select portfolio_id, 'Tower', 'Lahore', 'punjab' from m returning id, portfolio_id),
un as (insert into public.units (portfolio_id, property_id, label)
       select portfolio_id, id, 'U1' from prop returning id, portfolio_id),
te as (insert into public.tenants (portfolio_id, full_name) select portfolio_id, 'Tenant' from un returning id),
l as (insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
      select un.portfolio_id, un.id, te.id, '2026-10-01', 1000 from un, te returning id, portfolio_id)
select p.created_by, l.portfolio_id, l.id from p, l;
SQL
)

# One Data API write as the owner: PostgREST runs the pre-request hook
# app.check_request() and the request in one transaction.
request() {
  printf "set app.today_override = '2026-10-12';\nbegin;\nset local \"request.jwt.claims\" to '{\"sub\":\"%s\",\"role\":\"authenticated\"}';\nset local request.method to 'POST';\nset local role authenticated;\nselect app.check_request();\n%s\ncommit;\n" \
    "$OWNER" "$1"
}
run() { request "$1" | psql -X -q -At -d "$DB" 2>&1 || true; }

status=0
echo "=== F4: 150 failing writes (record_payment, amount -1); app.check_request allows 120 a minute, record_payment 60"
start=$(date +%s)
invalid=0
limited=0
for _ in $(seq 1 150); do
  out="$(run "select public.record_payment('$LEASE', -1, '2026-10-12', 'cash', gen_random_uuid());")"
  if grep -q rate_limited <<<"$out"; then
    limited=$((limited + 1))
  elif grep -q invalid_amount <<<"$out"; then invalid=$((invalid + 1)); fi
done
echo "refused as invalid_amount: $invalid, refused by the limiter: $limited ($(($(date +%s) - start)) s)"
echo "bucket rows afterwards: $(q -c "select count(*) from private.rate_limit_buckets")"
echo "--- failing writes never limited: $([[ "$limited" == "0" && "$invalid" == "150" ]] && echo yes || echo no) (expected yes)"
[[ "$limited" == "0" && "$invalid" == "150" ]] || status=1

echo "=== Contrast: 35 valid sync_portfolio_billing calls (limit 30 a minute)"
ok=0
limited=0
for _ in $(seq 1 35); do
  out="$(run "select public.sync_portfolio_billing('$PORTFOLIO');")"
  if grep -q rate_limited <<<"$out"; then limited=$((limited + 1)); else ok=$((ok + 1)); fi
done
echo "admitted: $ok, refused: $limited"
q -c "select regexp_replace(bucket_key, ':.*', '') || ': ' || hits from private.rate_limit_buckets order by 1"

echo "=== Observation: a user's second write waits for the first one's api_write bucket row"
q -c "delete from private.rate_limit_buckets" >/dev/null
request "select pg_sleep(2);" | psql -X -q -At -d "$DB" >/dev/null &
sleep 0.5
start=$(date +%s%N)
request "select 1;" | psql -X -q -At -d "$DB" >/dev/null
echo "the second write took $((($(date +%s%N) - start) / 1000000)) ms while the first was open"
wait
[[ "$status" -eq 0 ]]
