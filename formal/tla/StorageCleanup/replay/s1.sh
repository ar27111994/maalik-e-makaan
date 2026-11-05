#!/usr/bin/env bash
# S1: a document INSERT races the user's Storage DELETE of the same file
# (StorageCleanup.tla, configuration attach_vs_rmfile).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=formal/tla/StorageCleanup/replay/common.sh
source "$HERE/common.sh"

read -r OWNER PORTFOLIO TENANT FILE < <(fixture)
echo "fixture: an uploaded file without a document row"
# The Storage API's DELETE passes documents_objects_delete and stays open.
{
  as_storage_api "$OWNER" "delete from storage.objects where bucket_id = 'documents' and name = '$FILE'
                          returning 'storage delete: row deleted, not committed';"
  echo "select pg_sleep(2);"
  echo "commit;"
} | psql -X -q -At -d "$DB" >"$OUT/s1_delete.out" 2>&1 &
sleep 0.7
# Meanwhile the app attaches the file and commits.
{
  as_user "$OWNER" "$(attach_sql "$OWNER" "$PORTFOLIO" "$TENANT" "$FILE")
                    select 'document insert: AFTER checks passed';"
  echo "commit;"
} | psql -X -q -At -d "$DB" 2>&1 | grep -E "document insert|ERROR" || true
wait
grep -E "storage delete|ERROR" "$OUT/s1_delete.out" || true
echo "after both commits:"
count_rows "$FILE"
