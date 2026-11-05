# shellcheck shell=bash
# Shared connection defaults for the local database tooling (sourced).
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-54329}"
export PGUSER="${PGUSER:-postgres}"
export MM_TEST_DB="${MM_TEST_DB:-mm_test}"
