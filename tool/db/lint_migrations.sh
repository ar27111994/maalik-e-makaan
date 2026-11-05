#!/usr/bin/env bash
# Lints the migrations added after squawk's baseline (.squawk.toml) for
# operations that lock or rewrite live tables. The baseline was reviewed and
# applied before squawk was adopted, and applied migrations are never edited.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

mapfile -t BASELINE < <(grep -oE 'supabase/migrations/[^"]+\.sql' .squawk.toml)
NEW=()
for migration in supabase/migrations/*.sql; do
  if ! printf '%s\n' "${BASELINE[@]}" | grep -qxF "$migration"; then
    NEW+=("$migration")
  fi
done

if ((${#NEW[@]} == 0)); then
  echo "squawk: no migrations after the baseline"
  exit 0
fi
squawk --config .squawk.toml "${NEW[@]}"
