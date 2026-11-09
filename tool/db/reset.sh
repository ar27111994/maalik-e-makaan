#!/usr/bin/env bash
# Recreates a disposable database on a plain PostgreSQL server with the
# Supabase platform shim and the full migration chain (optionally the seed).
#
#   tool/db/reset.sh [--seed]
#
# Uses the standard libpq variables (PGHOST, PGPORT, PGUSER); the database
# name comes from MM_TEST_DB (default mm_test).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export PGOPTIONS="${PGOPTIONS:--c client_min_messages=warning}"
DB_NAME="$MM_TEST_DB"
SEED=0
[[ "${1:-}" == "--seed" ]] && SEED=1

psql_q() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

echo "▸ Recreating database ${DB_NAME} on ${PGHOST}:${PGPORT}"
psql_q -d postgres -c "drop database if exists ${DB_NAME} with (force)"
psql_q -d postgres -c "create database ${DB_NAME}"
psql_q -d "$DB_NAME" -f "$ROOT/supabase/local/supabase_shim.sql" >/dev/null

echo "▸ Applying migrations"
shopt -s nullglob
for migration in "$ROOT"/supabase/migrations/*.sql; do
  echo "  · $(basename "$migration")"
  # Each migration runs in one transaction, as the Supabase CLI applies it.
  # The CLI's transaction is implicit, not a block, so statements that need
  # a block (LOCK TABLE) fail there although they pass here:
  # tool/db/lint_migrations.sh rejects them outside begin; ... commit;.
  psql_q -d "$DB_NAME" "$(migration_tx_flag "$migration")" -f "$migration" >/dev/null
done

if [[ "$SEED" == "1" && -f "$ROOT/supabase/seed.sql" ]]; then
  echo "▸ Loading seed data"
  psql_q -d "$DB_NAME" --single-transaction -f "$ROOT/supabase/seed.sql" >/dev/null
fi
