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
# A migration that refuses to run on some rows may also have
# <version>.race.sql: a write, on the rows of <version>.before.sql, that the
# migration must refuse when another session commits it while the migration
# runs (it starts uncommitted and commits once the migration waits for a
# lock). The migration must fail with every "-- expect: <text>" line.
#
# A migration that refuses to run on some rows (it raises instead of changing
# user data) also has <version>.refused.sql: on another disposable database,
# migrated up to (not including) the migration, it seeds rows the migration
# must refuse. Applying the migration must then fail, its error must contain
# every "-- expect: <text>" line of the file, and a pg_dump taken after the
# attempt must equal the one taken before it (nothing applied, nothing lost).
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

# Applies, each in its own transaction, the migrations that sort before $1.
migrate_before() {
  local migration name
  for migration in "$ROOT"/supabase/migrations/*.sql; do
    name="$(basename "$migration")"
    [[ "$name" < "$1" ]] || break
    psql_q -d "$DB_NAME" --single-transaction -f "$migration" >/dev/null
  done
}

# The refusal check of <version>.refused.sql (see above) for migration $2.
check_refusal() {
  local refused="$1" target="$2" output expected dump_before dump_after
  # pg_dump (16.10 and later) brackets its output with a random \restrict key.
  dump() { pg_dump --no-owner -d "$DB_NAME" | grep -v '^\\\(un\)\?restrict '; }
  echo "▸ Refusal check of ${target}"
  drop_db
  psql_q -d postgres -c "create database ${DB_NAME}"
  psql_q -d "$DB_NAME" -f "$ROOT/supabase/local/supabase_shim.sql" >/dev/null
  migrate_before "$target"
  psql_q -d "$DB_NAME" --single-transaction -f "$refused" >/dev/null
  dump_before="$(dump)"
  if output="$(psql_q -d "$DB_NAME" --single-transaction \
    -f "$ROOT/supabase/migrations/${target}" 2>&1)"; then
    echo "${target} applied over the rows of $(basename "$refused")" >&2
    exit 1
  fi
  while IFS= read -r expected; do
    if [[ "$output" != *"$expected"* ]]; then
      printf 'the refusal does not say "%s":\n%s\n' "$expected" "$output" >&2
      exit 1
    fi
  done < <(sed -n 's/^-- expect: //p' "$refused")
  dump_after="$(dump)"
  if [[ "$dump_before" != "$dump_after" ]]; then
    echo "the refused ${target} changed the database" >&2
    diff <(echo "$dump_before") <(echo "$dump_after") | head -40 >&2
    exit 1
  fi
  echo "  · refused, nothing changed"
}

# Waits up to 10 s until the query $1 returns a count above 0.
wait_for() {
  local tries=0
  until [[ "$(psql_q -At -d "$DB_NAME" -c "$1")" -gt 0 ]]; do
    tries=$((tries + 1))
    if ((tries > 100)); then
      echo "timed out waiting for: $1" >&2
      exit 1
    fi
    sleep 0.1
  done
}

# The race check of <version>.race.sql (see above) for migration $3, on the
# rows of $2: another session runs the file's write and keeps it uncommitted
# while the migration starts, and commits once the migration waits for a lock.
# The migration must still see the write: it fails with each "-- expect:" line
# and leaves its functions and CHECKs unapplied.
check_race() {
  local race="$1" before="$2" target="$3" dir writer_pid migration_pid expected
  echo "▸ Race check of ${target}"
  drop_db
  psql_q -d postgres -c "create database ${DB_NAME}"
  psql_q -d "$DB_NAME" -f "$ROOT/supabase/local/supabase_shim.sql" >/dev/null
  migrate_before "$target"
  psql_q -d "$DB_NAME" --single-transaction -f "$before" >/dev/null
  dir="$(mktemp -d)"
  mkfifo "$dir/writer"
  PGAPPNAME=mm_race_writer psql_q -d "$DB_NAME" <"$dir/writer" >"$dir/writer.log" 2>&1 &
  writer_pid=$!
  exec 3>"$dir/writer"
  {
    echo 'begin;'
    cat "$race"
  } >&3
  wait_for "select count(*) from pg_stat_activity
            where application_name = 'mm_race_writer' and state = 'idle in transaction'"
  PGAPPNAME=mm_race_migration psql_q -d "$DB_NAME" --single-transaction \
    -f "$ROOT/supabase/migrations/${target}" >"$dir/migration.log" 2>&1 &
  migration_pid=$!
  wait_for "select count(*) from pg_stat_activity
            where application_name = 'mm_race_migration' and wait_event_type = 'Lock'"
  echo 'commit;' >&3
  exec 3>&-
  wait "$writer_pid" || {
    cat "$dir/writer.log" >&2
    exit 1
  }
  if wait "$migration_pid"; then
    echo "${target} applied although $(basename "$race") committed while it ran" >&2
    exit 1
  fi
  while IFS= read -r expected; do
    if ! grep -qF -- "$expected" "$dir/migration.log"; then
      printf 'the refusal does not say "%s":\n' "$expected" >&2
      cat "$dir/migration.log" >&2
      exit 1
    fi
  done < <(sed -n 's/^-- expect: //p' "$race")
  rm -rf "$dir"
  echo "  · refused, the racing write was counted"
}

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

  refused="$ROOT/tool/db/upgrade/${version}.refused.sql"
  if [[ -f "$refused" ]]; then
    check_refusal "$refused" "$target"
  fi
  race="$ROOT/tool/db/upgrade/${version}.race.sql"
  if [[ -f "$race" ]]; then
    check_race "$race" "$before" "$target"
  fi
done
