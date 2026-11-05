#!/usr/bin/env bash
# S1 with the Storage API's delete from v1.81 (src/storage/object.ts,
# deleteObject): the row FOR UPDATE as superuser, the user's DELETE in a
# savepoint that is always rolled back (the "probe", which asks
# documents_objects_delete), then the DELETE as superuser. A document INSERT
# for the same file arrives between the probe and the superuser's DELETE
# (StorageCleanup.tla, configuration attach_vs_rmprobe; the second review's
# issue 1: the probe's rollback ended the advisory path lock of the first fix).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=formal/tla/StorageCleanup/replay/common.sh
source "$HERE/common.sh"

read -r OWNER PORTFOLIO TENANT FILE < <(fixture)
echo "fixture: an uploaded file without a document row"
{
  echo "begin;"
  echo "select 'storage delete: row locked' from storage.objects
        where bucket_id = 'documents' and name = '$FILE' for update;"
  echo "savepoint probe;"
  printf 'set local "request.jwt.claims" to %s;\n' "'{\"sub\":\"$OWNER\",\"role\":\"authenticated\"}'"
  echo "set local role authenticated;"
  echo "set local storage.allow_delete_query = 'true';"
  echo "with d as (delete from storage.objects where bucket_id = 'documents' and name = '$FILE' returning 1)
        select 'storage delete: the probe may delete ' || count(*) || ' row(s); rolled back' from d;"
  echo "rollback to savepoint probe;"
  echo "select pg_sleep(2);"
  echo "set local storage.allow_delete_query = 'true';"
  echo "delete from storage.objects where bucket_id = 'documents' and name = '$FILE'
        returning 'storage delete: superuser deleted the row';"
  echo "commit;"
} | psql -X -q -At -d "$DB" >"$OUT/s1p_delete.out" 2>&1 &
sleep 0.7
# Meanwhile the app attaches the file and commits.
{
  as_user "$OWNER" "$(attach_sql "$OWNER" "$PORTFOLIO" "$TENANT" "$FILE")
                    select 'document insert: AFTER checks passed';"
  echo "commit;"
} | psql -X -q -At -d "$DB" 2>&1 | grep -E "document insert|ERROR" || true
wait
grep -E "storage delete|ERROR" "$OUT/s1p_delete.out" || true
echo "after both commits:"
count_rows "$FILE"
