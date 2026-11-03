#!/usr/bin/env bash
# Runs the migration chain and the pgTAP suite against a disposable database
# on a plain PostgreSQL server (Supabase objects are emulated by
# supabase/local/supabase_shim.sql). In CI the same suites also run on the
# real stack via `supabase test db`.
#
#   tool/db/test.sh                 # all suites
#   tool/db/test.sh path/to/x.sql   # selected suites
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/db/env.sh
source "$ROOT/tool/db/env.sh"
"$ROOT/tool/db/reset.sh"

echo "▸ Running pgTAP suites"
TESTS=("$@")
if [[ ${#TESTS[@]} -eq 0 ]]; then
  TESTS=("$ROOT/supabase/tests/database")
fi
PGOPTIONS="--search_path=public,extensions -c client_min_messages=warning" \
  pg_prove -d "$MM_TEST_DB" --ext .sql -r "${TESTS[@]}"
