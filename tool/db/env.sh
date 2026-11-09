# shellcheck shell=bash
# Shared connection defaults for the local database tooling (sourced).
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-54329}"
export PGUSER="${PGUSER:-postgres}"
export MM_TEST_DB="${MM_TEST_DB:-mm_test}"

# The psql flag that applies migration $1 in one transaction, as the Supabase
# CLI does (it sends a file as one implicit transaction). A file that opens
# its own (a line "begin;", required around LOCK TABLE: see
# tool/db/check_migration_transactions.py) runs as it is, so its begin and
# commit do not nest in psql's.
migration_tx_flag() {
  if grep -qx 'begin;' "$1"; then echo --no-psqlrc; else echo --single-transaction; fi
}
