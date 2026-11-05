#!/usr/bin/env bash
# Finding M1 on PostgreSQL: a client transaction locks a lease row and then
# needs the portfolio key (the order of a plain lease UPDATE whose trigger
# inserts a charge) while delete_portfolio holds the portfolio and its
# cascade needs the lease. Prints how many deadlocks PostgreSQL detected,
# whether the client's charge went in, and whether the deletion completed.
# Needs DB (a database built by tool/db/reset.sh) and OUT (a scratch dir).
set -euo pipefail

q() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

OWNER="$(q -c "insert into auth.users (id, email, email_confirmed_at)
               values (gen_random_uuid(), 'm1-' || gen_random_uuid() || '@example.com', now()) returning id")"
NAME="M1 $(q -c "select substr(gen_random_uuid()::text, 1, 8)")"
P="$(q -c "with p as (insert into public.portfolios (name, created_by) values ('$NAME', '$OWNER') returning id),
               m as (insert into public.portfolio_members (portfolio_id, user_id, role)
                     select id, '$OWNER', 'owner' from p)
           select id from p")"
L="$(q -c "with pr as (insert into public.properties (portfolio_id, name, city, province)
                       values ('$P', 'Block', 'Lahore', 'punjab') returning id),
               u as (insert into public.units (portfolio_id, property_id, label)
                     select '$P', id, 'Unit 1' from pr returning id),
               t as (insert into public.tenants (portfolio_id, full_name) values ('$P', 'Tenant') returning id)
           insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
           select gen_random_uuid(), '$P', u.id, t.id, '2026-08-01', 20000 from u, t returning id")"
CLAIMS="'{\"sub\":\"$OWNER\",\"role\":\"authenticated\"}'"
deadlocks() { q -c "select pg_stat_clear_snapshot(); select deadlocks from pg_stat_database where datname = current_database()" | tail -1; }
BEFORE="$(deadlocks)"

# The client: the lease row first, then (a second later) the portfolio key.
{
  printf 'begin;\nset local "request.jwt.claims" to %s;\nset local role authenticated;\n' "$CLAIMS"
  echo "update public.leases set notes = 'edited' where id = '$L';"
  echo "select pg_sleep(1);"
  echo "insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
        values ('$P', '$L', 'maintenance', '2026-11-03', 500, 'Repair');"
  echo "select 'client: charge inserted';"
  echo "commit;"
} | psql -X -q -At -d "$DB" >"$OUT/m1_client.out" 2>&1 &
sleep 0.4
# The owner deletes the portfolio meanwhile.
{
  printf 'begin;\nset local "request.jwt.claims" to %s;\nset local role authenticated;\n' "$CLAIMS"
  echo "select public.delete_portfolio('$P', '$NAME');"
  echo "select 'deletion: done';"
  echo "commit;"
} | psql -X -q -At -d "$DB" >"$OUT/m1_delete.out" 2>&1 &
wait
sleep 0.6 # statistics are reported when a session ends
AFTER="$(deadlocks)"

client="refused (deadlock detected)"
grep -q "client: charge inserted" "$OUT/m1_client.out" && client="charge inserted"
deletion="FAILED ($(grep -m1 -oE 'ERROR: .*' "$OUT/m1_delete.out" || echo 'no error text'))"
grep -q "deletion: done" "$OUT/m1_delete.out" && deletion="done"
echo "deadlocks detected: $((AFTER - BEFORE)); client: $client; deletion: $deletion;" \
  "portfolio rows left: $(q -c "select count(*) from public.portfolios where id = '$P'")"
