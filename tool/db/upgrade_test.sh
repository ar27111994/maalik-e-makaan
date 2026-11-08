#!/usr/bin/env bash
# Checks the one-off data changes of migrations: what a migration does to
# rows that already exist when it is applied, which the pgTAP suites (run on
# a freshly migrated, empty database) cannot see.
#
# For each tool/db/upgrade/<version>.before.sql, a disposable database is
# migrated up to (not including) the migration whose name starts with
# <version>; the .before.sql file seeds the rows the migration must change
# (and checks that they are in the state it fixes); the remaining migrations
# are applied, each in its own transaction like `supabase db push`; then
# <version>.after.sql runs and raises if a row is not as expected.
#
#   tool/db/upgrade_test.sh
#
# Uses the server of tool/db/env.sh and the database ${MM_TEST_DB}_upgrade,
# which it drops at the end.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
export PGOPTIONS="${PGOPTIONS:--c client_min_messages=warning}"
DB_NAME="${MM_TEST_DB}_upgrade"

psql_q() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }
drop_db() { psql_q -d postgres -c "drop database if exists ${DB_NAME} with (force)"; }
trap 'drop_db >/dev/null 2>&1 || true' EXIT

shopt -s nullglob
checks=("$ROOT"/tool/db/upgrade/*.before.sql)
if ((${#checks[@]} == 0)); then
  echo "▸ No upgrade checks"
  exit 0
fi

for before in "${checks[@]}"; do
  version="$(basename "$before" .before.sql)"
  after="$ROOT/tool/db/upgrade/${version}.after.sql"
  [[ -f "$after" ]] || {
    echo "missing ${after}" >&2
    exit 1
  }
  migrations=("$ROOT"/supabase/migrations/"${version}"_*.sql)
  ((${#migrations[@]} == 1)) || {
    echo "no single migration ${version}_*.sql" >&2
    exit 1
  }
  target="$(basename "${migrations[0]}")"

  echo "▸ Upgrade check of ${target}"
  drop_db
  psql_q -d postgres -c "create database ${DB_NAME}"
  psql_q -d "$DB_NAME" -f "$ROOT/supabase/local/supabase_shim.sql" >/dev/null
  seeded=0
  for migration in "$ROOT"/supabase/migrations/*.sql; do
    name="$(basename "$migration")"
    if [[ "$seeded" == 0 && ! "$name" < "$target" ]]; then
      echo "  · seeding before ${name}"
      psql_q -d "$DB_NAME" --single-transaction -f "$before" >/dev/null
      seeded=1
    fi
    psql_q -d "$DB_NAME" --single-transaction -f "$migration" >/dev/null
  done
  psql_q -d "$DB_NAME" --single-transaction -f "$after"
  echo "  · ok"
done
