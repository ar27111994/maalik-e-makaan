#!/usr/bin/env bash
# S2: a document INSERT for a file older than a day races the daily sweep;
# the cleaner lists the file before the INSERT commits and deletes it
# (StorageCleanup.tla, configurations attach_vs_sweep_queued and attach_vs_sweep).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=formal/tla/StorageCleanup/replay/common.sh
source "$HERE/common.sh"

read -r OWNER PORTFOLIO TENANT FILE < <(fixture)
echo "fixture: a file uploaded two days ago without a document row"
# 1. The app attaches the file; its transaction stays open.
{
  as_user "$OWNER" "$(attach_sql "$OWNER" "$PORTFOLIO" "$TENANT" "$FILE")
                    select 'document insert: AFTER checks passed, not committed';"
  echo "select pg_sleep(3);"
  echo "commit;"
} | psql -X -q -At -d "$DB" >"$OUT/s2_attach.out" 2>&1 &
sleep 0.7
# 2. The daily sweep (private.cleanup -> enqueue_orphaned_storage) commits.
q -c "select 'sweep: queued ' || private.enqueue_orphaned_storage(now()) || ' item(s)'"
# 3. The cleaner claims the item and lists what it may delete.
ITEM="$(printf "begin;\nset local role service_role;\nselect id from public.admin_claim_storage_cleanup(20, 120, array['%s']);\ncommit;\n" "$FILE" \
  | psql -X -q -At -d "$DB")"
: >"$OUT/s2_listed.txt"
if [[ -z "$ITEM" ]]; then
  echo "cleaner: nothing to claim"
else
  printf "begin;\nset local role service_role;\nselect name from public.admin_storage_cleanup_objects(%s);\ncommit;\n" "$ITEM" \
    | psql -X -q -At -d "$DB" >"$OUT/s2_listed.txt"
  echo "cleaner: claimed the item and listed $(wc -l <"$OUT/s2_listed.txt") object(s)"
fi
wait
grep -E "document insert|ERROR" "$OUT/s2_attach.out" || true
echo "after the INSERT committed:"
q -c "select 'queue items for the file: ' || count(*) from private.storage_cleanup_queue where path = '$FILE'"
count_rows "$FILE"
# 4. The cleaner deletes what it listed (Storage API, secret key) and completes.
if [[ -s "$OUT/s2_listed.txt" ]]; then
  LISTED="$(paste -sd, "$OUT/s2_listed.txt" | sed "s/[^,]*/'&'/g")"
  printf "begin;\nset local role service_role;\nset local storage.allow_delete_query = 'true';\ndelete from storage.objects where bucket_id = 'documents' and name in (%s);\ncommit;\n" "$LISTED" \
    | psql -X -q -At -d "$DB"
  printf "begin;\nset local role service_role;\nselect 'cleaner: removed the listed objects; complete -> ' || public.admin_complete_storage_cleanup(%s, true);\ncommit;\n" "$ITEM" \
    | psql -X -q -At -d "$DB"
  echo "after the cleaner:"
  count_rows "$FILE"
fi
