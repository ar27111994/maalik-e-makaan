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

# The migrations change rows every database shares (ALTER ROLE ... SET), so
# two resets on one server at the same moment can fail with "tuple
# concurrently updated". Resets on this machine take turns (flock, where it
# exists), each waiting at most 10 minutes for the one before it.
if command -v flock >/dev/null; then
  exec {reset_lock}>"${TMPDIR:-/tmp}/mm-db-reset-${PGPORT}.lock"
  flock -w 600 "$reset_lock" || {
    echo "✗ another tool/db/reset.sh for port ${PGPORT} held its lock for 10 minutes" >&2
    exit 1
  }
fi

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
