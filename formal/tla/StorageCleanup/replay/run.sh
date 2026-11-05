#!/usr/bin/env bash
# Replays findings S1 and S2 on a plain PostgreSQL server with the Supabase
# shim and the migration chain: first on the code before their fix (every
# migration that sorts before *_concurrency_findings.sql), then on the
# current code (tool/db/reset.sh, every migration). Creates (and drops) the
# disposable databases mm_fv_storage_before and mm_fv_storage; connection
# settings come from tool/db/env.sh. Exits non-zero unless the code before
# the fix shows both races and the current code shows neither.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/fv-replay.XXXXXX")"
export OUT
trap 'rm -rf "$OUT"' EXIT

FIX="$(basename "$(compgen -G "$ROOT/supabase/migrations/*_concurrency_findings.sql")")"

# A database with the shim and every migration before the fix.
build_before() {
  local migration
  psql -X -q -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists $1 with (force)" -c "create database $1"
  psql -X -q -v ON_ERROR_STOP=1 -d "$1" -f "$ROOT/supabase/local/supabase_shim.sql" >/dev/null
  for migration in "$ROOT"/supabase/migrations/*.sql; do
    [[ "$(basename "$migration")" < "$FIX" ]] || continue
    PGOPTIONS="-c client_min_messages=warning" \
      psql -X -q -v ON_ERROR_STOP=1 -d "$1" --single-transaction -f "$migration" >/dev/null
  done
}

echo "fix: supabase/migrations/$FIX"
build_before mm_fv_storage_before
MM_TEST_DB=mm_fv_storage "$ROOT/tool/db/reset.sh" >/dev/null

status=0
for db in mm_fv_storage_before mm_fv_storage; do
  for scenario in s1 s1p s2; do
    echo "=== $scenario on $db"
    DB="$db" bash "$HERE/$scenario.sh" | tee "$OUT/$db.$scenario.log"
    last="$(grep 'document rows' "$OUT/$db.$scenario.log" | tail -1 | awk '{print $NF}')"
    objects="$(grep 'storage objects' "$OUT/$db.$scenario.log" | tail -1 | awk '{print $NF}')"
    dangling=$([[ "$last" == "1" && "$objects" == "0" ]] && echo yes || echo no)
    expected=$([[ "$db" == "mm_fv_storage_before" ]] && echo yes || echo no)
    echo "--- dangling document row: $dangling (expected $expected)"
    [[ "$dangling" == "$expected" ]] || status=1
  done
done
exit "$status"
