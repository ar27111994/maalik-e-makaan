#!/usr/bin/env bash
# Replays finding M1 RUNS times (default 6) per variant on disposable
# databases (connection settings from tool/db/env.sh):
#   before   the shim and every migration that sorts before the fix,
#            *_concurrency_findings.sql: the code M1 was found in;
#   current  every migration (tool/db/reset.sh), the fix included
#            (expected: no deadlock, the deletion completes).
# On the code before the fix the outcome is timing-dependent and only
# reported: one deadlock means the deletion lost once and its retry went
# through; two or three mean the retry re-formed the cycle. Exits non-zero if
# the current code shows a deadlock or a deletion fails there. Rebuilds the
# databases mm_fv_membership_before and mm_fv_membership_current.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/fv-m1.XXXXXX")"
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
status=0
for variant in before current; do
  export DB="mm_fv_membership_$variant"
  if [[ "$variant" == before ]]; then
    build_before "$DB"
  else
    MM_TEST_DB="$DB" "$ROOT/tool/db/reset.sh" >/dev/null
  fi
  echo "=== $variant"
  for i in $(seq 1 "${RUNS:-6}"); do
    line="$(bash "$HERE/m1.sh")"
    echo "run $i: $line"
    deadlocks="$(sed -E 's/^deadlocks detected: ([0-9]+);.*/\1/' <<<"$line")"
    if [[ "$variant" == current ]]; then
      [[ "$deadlocks" == "0" && "$line" == *"deletion: done"* ]] || status=1
    fi
  done
done
exit "$status"
