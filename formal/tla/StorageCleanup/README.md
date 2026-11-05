# Documents, files and the storage cleanup queue (TLA+)

Two TLC-checked models of how document rows, uploaded files and the durable
cleanup queue interact, as the code implements them now:

- `StorageCleanup.tla`: uploads, document inserts and deletes, entity and
  portfolio deletion, a user's Storage delete in each way the Storage API has
  made it, re-creating a deleted portfolio's id, the cleaner and the daily
  sweep.
- `QueueFairness.tla`: how concurrent cleaners claim items (READ COMMITTED,
  `SKIP LOCKED`, the recheck), the turn order between folders, the attempts
  counter, and freedom from starvation.

Code followed ("latest" is
`supabase/migrations/20261105072426_membership_deletion_storage.sql`;
"findings" is `20261105170557_concurrency_findings.sql`, which fixes S1 and
S2): the SQL in `supabase/migrations/*.sql` (last definitions), and
`supabase/functions/_shared/storage.ts` (`drainStorageCleanup`, `cleanItem`)
driven by `supabase/functions/storage-cleanup/handler.ts` and
`supabase/functions/delete-account/handler.ts`, and the Storage API's
delete in `supabase/storage` `src/storage/object.ts` (`deleteObject`,
`deleteObjects`; tags v1.80.2 and v1.81.0 and `master` read).
`20261105085837_lease_delete_guard.sql` was read in full and touches nothing
modelled here.

## What is modelled

Same conventions as `../Membership`: one step per SQL statement (a trigger
runs inside its statement), READ COMMITTED snapshots, row locks as disabled
steps, and `Need(t)` as the wait-for edges.

| Model element                                   | Code                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `U_Ins`, `U_Commit`                             | Storage upload: `INSERT INTO storage.objects` as the user under policy `documents_objects_insert` (`20261103194240`); it takes no portfolio lock, so an upload authorised before a deletion can commit after it                                                                                                                                                                                                                                             |
| `A_PKS`, `A_EKS`                                | `private.before_document_insert` (latest): authorise, portfolio `KEY SHARE`, entity `KEY SHARE`, `document_entity_not_found`                                                                                                                                                                                                                                                                                                                                |
| `A_Ins`                                         | the row and `documents_storage_path_key` (waits for a concurrent insert or delete of the same path)                                                                                                                                                                                                                                                                                                                                                         |
| `A_Gate`, `A_FKS`, `A_After`                    | `private.after_document_insert_check_file` (findings, once per statement): waits for the sweep gate, shared (`private.lock_document_sweep_gate(false)`), then locks the file's `storage.objects` row `FOR KEY SHARE` (waits while a Storage request holds it `FOR UPDATE` or deletes it; a deleted row is not found), then `document_file_missing` (the row was not locked), `document_file_pending_deletion` (file or folder queued) with a fresh snapshot |
| `X_Del`                                         | a client `DELETE` on `documents` and `private.after_documents_delete_queue_files` (only existing files are queued)                                                                                                                                                                                                                                                                                                                                          |
| `R_Lock`, `R_Del` (`rm1`)                       | Storage API up to v1.80, a batch: `DELETE` as the user under `documents_objects_delete` (findings): `app.document_object_deletable` authorises, locks the row `FOR UPDATE SKIP LOCKED` (held by another transaction: the object is refused), then refuses an object a document row references, reading with a fresh snapshot; the `DELETE` then runs the trigger (`Kept`)                                                                                   |
| `R1_Lock` (`rms1`)                              | Storage API up to v1.80, one object: the row `FOR UPDATE` as superuser first (`findObject(..., { forUpdate: true })`), then the same `DELETE` as the user                                                                                                                                                                                                                                                                                                   |
| `RP_Lock`, `RP_Probe`, `RP_Del` (`rmp1`)        | Storage API from v1.81: the row `FOR UPDATE` as superuser (`lockObjectForDelete`), the user's `DELETE` in a savepoint that is always rolled back (`testPermission`: `AccessDenied` unless the policy lets it delete), then the `DELETE` as superuser, which row security does not see (a row the trigger keeps is not deleted: `AccessDenied`, rolled back); the rollback ends every lock the probe took and keeps the one taken before it                  |
| `R_Pol`, `R_RowDel`                             | mutant `no_delete_row_lock`: the policy with the statement's snapshot, then the `DELETE`'s row lock, which waits for a key-share holder and then deletes without asking the policy again (only the trigger looks again)                                                                                                                                                                                                                                     |
| `RN_Probe`, `RN_Del` (`rmn1`)                   | the v1.81 flow without its row lock first (no Storage API version does this): the probe (the policy's own lock ends with the savepoint), then the `DELETE` as superuser with nothing held in between; that `DELETE`'s row lock waits for a key-share holder, then the trigger looks                                                                                                                                                                         |
| `SV_Del` (`rmsv1`)                              | one `DELETE` as the service role (row security bypassed), as an admin with the secret key issues it; its row lock waits for a key-share holder, then the trigger looks                                                                                                                                                                                                                                                                                      |
| `Kept`                                          | `private.before_document_object_delete`, the `BEFORE DELETE` row trigger `documents_objects_keep_referenced` on `storage.objects` (findings): in every step that deletes a row, after the `DELETE` holds the row, it reads `documents` with a fresh snapshot and skips (keeps) a referenced row                                                                                                                                                             |
| `E_Del`, `E_Docs`                               | an entity delete and `private.after_entity_delete_documents`                                                                                                                                                                                                                                                                                                                                                                                                |
| `P_Lock`, `P_Del`                               | `lock_portfolios_for_deletion` + `delete_locked_portfolios`: cascade, `private.after_portfolios_delete` (retire the id, queue `<id>/`)                                                                                                                                                                                                                                                                                                                      |
| `K_Check`, `K_Ins`                              | `create_portfolio` with a deleted portfolio's id: registry lookup and `portfolios_after_insert_register_id`                                                                                                                                                                                                                                                                                                                                                 |
| `C_Idle`                                        | pg_cron → `private.request_storage_cleanup`: start a run when an item is due and unclaimed                                                                                                                                                                                                                                                                                                                                                                  |
| `C_Claim`, `C_List`, `C_RemoveOk`, `C_Complete` | `admin_claim_storage_cleanup`, `admin_storage_cleanup_objects` (never lists a referenced object), the Storage API `remove` as the service role (it waits for a document insert's key share on the row, and the trigger keeps a referenced file), `admin_complete_storage_cleanup`                                                                                                                                                                           |
| `C_RemoveErr`, `C_Deadline`, `C_Crash`, `Lapse` | a Storage error (backoff), a spent time budget (due again now), a crashed run (its claim lapses after `claimed_until`)                                                                                                                                                                                                                                                                                                                                      |
| `Ripen`, `Due`                                  | time: a folder item's `enqueued_at + 15 minutes`; a backoff ending                                                                                                                                                                                                                                                                                                                                                                                          |
| `S_Docs`, `S_Folders`, `S_Gate`, `S_Files`      | `private.cleanup` → `enqueue_orphaned_storage` (findings): `delete_orphaned_documents`; folders of portfolios that no longer exist (retired and queued); files older than a day without a document row, only after trying the sweep gate exclusively (busy: the files wait a day) and reading again                                                                                                                                                         |
| `QueueFairness`: `Snap`, `Lock`, `Commit`       | `admin_claim_storage_cleanup` split where READ COMMITTED splits it: the candidates from the statement snapshot (`row_number() over (partition by folder ...)`, `order by turn, not_before, id limit p_limit`), then `for update skip locked` with the due recheck, then COMMIT                                                                                                                                                                              |
| `QueueFairness`: `Complete`, `Tick`, `Produce`  | `admin_complete_storage_cleanup` (error → backoff, attempts kept; otherwise attempts 0, done or due again now); a backoff ending; new work arriving in another folder                                                                                                                                                                                                                                                                                       |

## Properties

| Property                                | Plain language                                                                                                                                | Broken by                                                                                                                                                                                                                                                                                                                                                      |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NoDanglingDocument`                    | No document row references a file that does not exist.                                                                                        | `mut_no_insert_row_lock`, `mut_no_insert_row_lock_probe`, `mut_no_delete_row_lock` (finding S1, and the second review's issue 1), `mut_no_delete_trigger_nolock`, `mut_no_delete_trigger_service` (deletes that hold nothing between check and delete, or that no policy sees), `mut_no_sweep_gate_dangling` (S2); `mut_no_file_check`, `mut_no_pending_check` |
| `NoDocForQueuedFile`                    | No document row references a file queued for deletion, as a file or under its folder.                                                         | `mut_no_sweep_gate`, `mut_no_insert_gate` (finding S2)                                                                                                                                                                                                                                                                                                         |
| `NoLiveFileDeleted`                     | No file is deleted while a committed document row references it.                                                                              | `mut_no_delete_trigger_guard`; `mut_no_delete_doc_check`, `mut_listing_includes_referenced`                                                                                                                                                                                                                                                                    |
| `NoOrphanDocument`                      | No document row outlives its entity.                                                                                                          | `mut_no_entity_lock`                                                                                                                                                                                                                                                                                                                                           |
| `DeletedFoldersQueued`                  | Every file of a portfolio that no longer exists waits in the queue under its folder.                                                          | `mut_no_prefix_queue`, `mut_no_final_sweep`; assumption flip `late_upload_unbounded`                                                                                                                                                                                                                                                                           |
| `NoLiveFolderQueued`                    | A queued folder never belongs to a live portfolio, and a deleted id never comes back.                                                         | `mut_no_id_registry`                                                                                                                                                                                                                                                                                                                                           |
| `NoWaitCycle`                           | No wait-for cycle.                                                                                                                            | `mut_entity_lock_first`                                                                                                                                                                                                                                                                                                                                        |
| `EventuallyClean` (liveness)            | Once deletions are done and the queue drains, no file is left in a deleted portfolio's folder.                                                | `mut_live_no_sweep`                                                                                                                                                                                                                                                                                                                                            |
| `EventuallyDrained` (liveness)          | With finitely many failures, the queue empties.                                                                                               | none found: the drain has no single guard to remove; see below                                                                                                                                                                                                                                                                                                 |
| `EventuallyNoOrphanDocument` (liveness) | An orphaned document row is eventually removed.                                                                                               | `mut_live_orphan_no_sweep`                                                                                                                                                                                                                                                                                                                                     |
| `ExclusiveClaims`                       | No item is claimed by two cleaners at once.                                                                                                   | `mut_qf_no_lock_recheck`                                                                                                                                                                                                                                                                                                                                       |
| `TurnsWithinClaim`                      | Within one claim, folders take turns: no folder gets a second item while another folder with due work gets none.                              | `mut_qf_no_turn`                                                                                                                                                                                                                                                                                                                                               |
| `AttemptsCountFailures`                 | `attempts` counts the claims since the last error-free completion, so an item handed back unfinished never inherits a long backoff.           | `mut_qf_no_attempts_reset`                                                                                                                                                                                                                                                                                                                                     |
| `NoStarvation` (liveness)               | Every due item is eventually claimed, even when another folder's older items are rescheduled unfinished for ever and new work keeps arriving. | `mut_qf_order_by_id`                                                                                                                                                                                                                                                                                                                                           |
| `TypeOK`, `NoLeakedLocks`               | Sanity of the model: types; a finished or idle process holds nothing.                                                                         | none: model sanity, not app code                                                                                                                                                                                                                                                                                                                               |

`EventuallyDrained` holds in every configuration that checks it. Each item
leaves the queue through the same completion path, so no single mechanism
can be removed to break it; it depends on the finite failure budget, which
is an assumption, not code. `mut_qf_no_turn_live` passes on purpose: the
`not_before` order alone prevents starvation; the turns give fairness within
one claim (`TurnsWithinClaim`). `mut_no_delete_row_lock_probe` passes on
purpose too: from v1.81 the Storage API locks the row before it asks the
policy, which is all that flow needs. The policy's own row lock is for the
v1.80 batch, which deletes as the user without locking first
(`mut_no_delete_row_lock`). `mut_no_delete_trigger_probe` passes on purpose
as well: the Storage API holds the row from before the probe to the delete,
so the insert's key share alone serialises that flow; the trigger is for
deletes that hold nothing in between (`mut_no_delete_trigger_nolock`) and
deletes no policy sees (`mut_no_delete_trigger_service`,
`mut_no_delete_trigger_guard`).

With the trigger in place, the older guards against deleting a referenced
file become a second line of defence for these invariants. So
`mut_no_delete_row_lock`, `mut_no_delete_doc_check`,
`mut_listing_includes_referenced`, `mut_no_pending_check` and
`mut_no_sweep_gate_dangling` remove the trigger too (their `MUTANT` ends in
`+no_trigger`), and each has a `*_trigger` twin with only its own guard
removed, which passes on purpose: the trigger keeps the file.

## Finding S1: a document can reference a file the user deleted at the same moment (fixed)

Severity: medium (a document row whose file is gone; the app shows a broken
attachment). Fixed by `20261105170557_concurrency_findings.sql`; the
counterexample below is the code before it (`mut_no_insert_row_lock` and
`mut_no_delete_row_lock` reproduce it with either half of the fix removed).

The Storage delete policy checks "no document row references the object"
with its statement snapshot. The document insert's AFTER check reads
`storage.objects` without a lock. Neither sees the other's uncommitted
work. Counterexample (before the fix, 8 states):

1. `R_Del`: the user's Storage DELETE passes the policy (no document row
   yet) and deletes the object row, uncommitted.
2. `A_PKS`, `A_EKS`, `A_Ins`: the app inserts the document row.
3. `A_After`: the file is still visible (the delete is uncommitted), so the
   check passes.
4. `A_Commit`, `R_Commit`: both commit. `NoDanglingDocument` is violated.

## S1 again under the Storage API's v1.81 delete (second review, fixed)

The first version of the fix serialised the two on an advisory lock per
storage path: the insert's check waited for it, the delete policy tried it.
The second review read the Storage API (`supabase/storage`,
`src/storage/object.ts`). Up to v1.80.2 it deletes as the user. From v1.81.0
it locks the rows `FOR UPDATE` as superuser, runs the user's `DELETE` in a
savepoint that `testPermission` always rolls back (the "probe": does the
policy let the user delete?), then deletes as superuser. The rollback ends
the advisory lock the policy took, so between the probe and the delete
nothing stopped a document insert. `mut_no_insert_row_lock_probe` is that
code (the insert's check locks nothing the probe leaves behind); 11 states:

1. `A_PKS` … `A_Gate`, `A_After`: the app inserts the document row; the file
   is there, so the check passes (the row is uncommitted).
2. `RP_Lock`: the Storage API locks the object row `FOR UPDATE`.
3. `RP_Probe`: the probe's policy sees no committed document row: allowed.
4. `A_Commit`: the document row commits.
5. `RP_Del`, `R_Commit`: the superuser `DELETE` removes the object.
   `NoDanglingDocument` is violated.

The fix locks the object row itself: the insert's check takes it `FOR KEY
SHARE`, which conflicts with the Storage API's `FOR UPDATE`, so the insert
waits until the delete has committed and then finds no row. Replayed on
PostgreSQL by `replay/s1p.sh` and by scenario 24 of
`tool/db/concurrency_test.sh` (`probe_*` cases), which fail on the first
version of the fix.

## S1 a third time: a delete that holds nothing between check and delete (third review, fixed)

The second review's fix (the insert locks the row `FOR KEY SHARE`) is
enough for every Storage API version, because each one holds the row from
its permission check to its `DELETE`. It is not enough for a delete that
checks and then deletes without holding the row in between, nor for one no
policy checks at all: the superuser's `DELETE` after a probe and the service
role's `DELETE` do not consult row security, so a document committed after
the check, or before a service-role delete, does not stop them.
`mut_no_delete_trigger_nolock` is that gap with the probe flow minus its row
lock (`rmn1`); 11 states:

1. `A_PKS` … `A_Gate`: the app inserts the document row and takes the gate.
2. `RN_Probe`: the probe's policy sees no committed document row and the
   row unlocked: allowed. The savepoint's rollback ends its lock.
3. `A_FKS`, `A_After`, `A_Commit`: the insert locks the row, passes its
   checks and commits.
4. `RN_Del`, `R_Commit`: the superuser `DELETE` removes the object.
   `NoDanglingDocument` is violated.

`mut_no_delete_trigger_service` is the same with a service-role `DELETE`
that waits for the insert's key share and then deletes anyway, and
`mut_no_delete_trigger_guard` a service-role `DELETE` of a file a committed
document references (`NoLiveFileDeleted`). The fix is a `BEFORE DELETE` row
trigger on `storage.objects`: PostgreSQL locks the row for the `DELETE`
before a row trigger runs (waiting for a key-share holder), and the
trigger's query takes a fresh snapshot, so it sees the committed document
and skips the row. The same race on PostgreSQL, with each design in place
(`tool/db/concurrency_test.sh` scenario 24 run alone on each):

| Design                                                                       | Failing cases of scenario 24                                                                                        |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Advisory path lock (first fix)                                               | 8: `probe_delete_first`, `probe_between`, `unlocked_*` (2), `service_*` (4)                                         |
| Path lock plus the insert's per-row key share (the second review's proposal) | 6: `unlocked_between`, `service_insert_first`, and a deadlock in each of `probe_batch` and `service_batch` (2 each) |
| Row lock on both sides, no trigger                                           | 2: `unlocked_between`, `service_insert_first`                                                                       |
| Row lock on both sides and the trigger (current)                             | none                                                                                                                |
| The trigger and the insert's row lock, without the delete policy's row lock  | none                                                                                                                |

## Finding S2: a document can be attached to a file the daily sweep is deleting (fixed)

Severity: low to medium (needs a document insert for a file more than a day
old at the moment the daily sweep runs). Fixed by the same migration;
`mut_no_sweep_gate` and `mut_no_sweep_gate_dangling` reproduce it on the
current model with the sweep's gate removed, and `mut_no_insert_gate` with
the insert's.

The sweep queues files older than a day "without a document row" with its
statement snapshot. The document insert checks "not queued" with its own.
This is write skew. Counterexample (before the fix, 15 states, shortened):

1. `A_PKS` … `A_Ins`: the app inserts a document row for an old file.
2. `S_Docs`, `S_Folders`, `S_Files`: the sweep sees no document row and
   queues the file.
3. `A_After`: the queue item is uncommitted, so the check passes.
4. `S_Commit`: the item is queued. (`mut_no_sweep_gate` stops here:
   `NoDocForQueuedFile` is violated once the insert commits.)
5. `C_Claim`, `C_List`: the cleaner claims the item and lists the file (the
   row is still uncommitted).
6. `A_Commit`, then `C_RemoveOk`: the file is deleted under a committed
   document row. `NoDanglingDocument` is violated.

## Both replayed on PostgreSQL 16, before and after the fix

`replay/run.sh` builds disposable databases with the Supabase shim: one with
every migration that sorts before `*_concurrency_findings.sql` (the code the
findings were made on), one with every migration (`tool/db/reset.sh`), and
replays each counterexample with real sessions: `s1.sh` (a Storage delete
as the user, v1.80), `s1p.sh` (the v1.81 probe) and `s2.sh`. Excerpt of the
last run (the fixture and intermediate lines omitted; this run used scratch
copies of the two databases, named here as `run.sh` names them):

```text
=== s1 on mm_fv_storage_before
document rows for the file: 1
storage objects for the file: 0
--- dangling document row: yes (expected yes)
=== s1p on mm_fv_storage_before
document insert: AFTER checks passed
storage delete: row locked
storage delete: the probe may delete 1 row(s); rolled back
storage delete: superuser deleted the row
document rows for the file: 1
storage objects for the file: 0
--- dangling document row: yes (expected yes)
=== s2 on mm_fv_storage_before
sweep: queued 1 item(s)
cleaner: claimed the item and listed 1 object(s)
cleaner: removed the listed objects; complete -> done
document rows for the file: 1
storage objects for the file: 0
--- dangling document row: yes (expected yes)
=== s1 on mm_fv_storage
ERROR:  document_file_missing
document rows for the file: 0
storage objects for the file: 0
--- dangling document row: no (expected no)
=== s1p on mm_fv_storage
ERROR:  document_file_missing
storage delete: the probe may delete 1 row(s); rolled back
storage delete: superuser deleted the row
document rows for the file: 0
storage objects for the file: 0
--- dangling document row: no (expected no)
=== s2 on mm_fv_storage
WARNING:  sweep_orphaned_files: document inserts kept the sweep gate busy; the next daily-job run tries again
sweep: queued 0 item(s)
cleaner: nothing to claim
document rows for the file: 1
storage objects for the file: 1
--- dangling document row: no (expected no)
```

`s1p.sh` on the first version of the fix (the advisory path lock) leaves the
dangling row too: the insert's check passes before the probe, and nothing
the probe leaves behind stops its commit.

`tool/db/concurrency_test.sh` scenarios 24 (S1, with the three ways the
Storage API deletes, in both orders, and a two-file batch) and 25 (S2, with
the cleaner's claim, listing, Storage delete and completion) run each race
in both orders; both fail on the code before the fix, and 24's `probe_*`
cases fail on the first version of the fix. Its final step also checks that
no document references a missing or a queued file after the whole run.

## The fix (20261105170557_concurrency_findings.sql)

S1 — the file's `storage.objects` row:

- `after_document_insert_check_file`, now once per statement over all the
  new rows (`REFERENCING NEW TABLE`), locks the files' rows `FOR KEY SHARE`
  in one statement, ordered by `name COLLATE "C"`, after the sweep gate. A
  row a Storage request holds `FOR UPDATE` (or is deleting) makes it wait;
  once that request commits a deleted row is not found
  (`document_file_missing`). While the insert holds the row, no delete can
  remove it.
- The delete policy calls `app.document_object_deletable(name)`, which
  authorises first (owner or manager of the folder's portfolio, so nobody
  locks a file they may not delete), then locks the row `FOR UPDATE SKIP
LOCKED`: a row an insert holds is refused (it stays; if the insert rolls
  back, the daily sweep queues it after a day), a row the request itself
  locked first is returned at once. Then it reads `documents` afresh.
- Every way the Storage API deletes takes `FOR UPDATE` on the row before
  the row goes: v1.80's single delete and v1.81's `lockObjectForDelete` /
  `lockDeleteTargets` as superuser, v1.80's batch through the policy, the
  cleaner's removal through its own `DELETE`. So the probe's rollback no
  longer matters: the lock the insert waits for is taken before the
  savepoint.
- Every `DELETE` of a documents-bucket row, whoever issues it, runs the
  `BEFORE DELETE` row trigger `documents_objects_keep_referenced`
  (`private.before_document_object_delete`). PostgreSQL locks the row for
  the `DELETE` before the trigger runs, waiting for an insert's key share;
  the trigger then reads `documents` with a fresh snapshot and returns null
  for a referenced row, so the `DELETE` neither removes nor returns it and
  the Storage API keeps the bytes (one object: `AccessDenied`; a batch: left
  out of the result). This covers what the row locks alone do not: a delete
  that holds nothing between its check and its `DELETE`, and deletes no
  policy sees (the superuser's after the probe, the service role's). The
  cleaner's files and an unattached upload have no document row, so they
  still go; portfolio and account deletion delete the document rows before
  their files are queued.
- A row lock lives in the row, so neither side takes a lock-table entry
  per file. (The first version took an advisory lock per object in every
  user delete, 1,000 for a 1,000-object delete, held to the commit.)
- No cycle: the insert waits only for the gate and for rows a Storage
  request holds; a Storage request takes its rows in `name COLLATE "C"`
  order (`findObjectTargets`), the order the insert locks them in, and the
  policy never waits. `tool/db/concurrency_test.sh` scenario 24's
  `probe_batch` deadlocks if the insert locks its rows in row order
  instead (measured).
- Locking another schema's rows and adding a trigger to its table needs
  `UPDATE` and `TRIGGER` on `storage.objects` and row security out of the
  way for the functions' owner. On Supabase that is `postgres`: storage's
  migrations grant it every privilege on the storage tables
  (`buckets-objects-grants-postgres`), and it has `BYPASSRLS`. The
  migration checks these and stops otherwise; pgTAP suite 15 checks them
  too, so `supabase test db` on the real stack would show a difference.
- The hosted project's `storage.migrations` has 80 rows. storage-api's
  migration list has 75 entries in v1.81.0 to v1.84.0, 76 in v1.85.0 and
  80 from v1.86.0, so the hosted Storage API is v1.86 or later and deletes
  the v1.81 way.

S2 — one sweep gate, `private.lock_document_sweep_gate(sweep)`:
`pg_advisory_xact_lock_shared(1701080943, 0)` for a document insert,
`pg_try_advisory_xact_lock(1701080943, 0)` for the sweep. It uses the
two-key form, which PostgreSQL never confuses with the app's one-key
advisory locks (the daily job's, and payment idempotency keys).

- `after_document_insert_check_file` takes the gate shared before the
  rows, so a waiter for the gate holds no row. It is the only wait for the
  gate.
- `enqueue_orphaned_storage` queues the folders of deleted portfolios as
  before (no document can be inserted into a portfolio that does not
  exist), then calls `private.sweep_orphaned_files`, which tries the gate
  up to 20 times, 50 ms apart. While a document insert is between its
  check and its commit the gate is busy. With the gate it queues every old
  file without a document row in one statement, reading `documents` after
  the gate was granted, and records the day in `private.job_runs`
  (`orphaned_file_sweep`). The gate lasts until the daily job commits a few
  statements later; a document insert meanwhile waits and then sees its
  file queued (`document_file_pending_deletion`).
- If the gate stays busy, nothing is recorded, and every later run of
  `private.run_daily_jobs` that day (every 10 minutes, in a run that holds
  no lease lock) tries the sweep again until one is recorded. The first
  version left the files for the next day's sweep.

Why a gate and not a lock per file for the sweep (an earlier version of
this fix): the sweep then held one advisory lock per queued file until the
daily job committed. PostgreSQL's shared lock table holds
`max_locks_per_transaction × (max_connections + background workers +
max_prepared_transactions)` entries (14,208 on this machine), so enough
orphaned files made the sweep fail with `out of shared memory`, and with
it the whole daily run (notifications, cleanup) on every retry. Any member
who may upload can create orphaned files. Measured with 100,000 orphaned
files older than a day (on PostgreSQL 16, built from the migrations):

| Version                   | `enqueue_orphaned_storage`       | `run_daily_jobs` for the day    |
| ------------------------- | -------------------------------- | ------------------------------- |
| a lock per file           | `ERROR: out of shared memory`    | fails; no `job_runs` row        |
| the gate (this migration) | queues all of them, holds 1 lock | finishes; `daily_notifications` |

The gate's exclusive holder is the daily job, which never waits for it (it
only tries) and, after the sweep, only finishes its own rows and commits.

The cleaner deletes as the service role (row security bypassed) and
removes only what `admin_storage_cleanup_objects` listed for a claimed
item; its `DELETE` waits for a document insert holding the row, and a
document insert for that path is refused while the item exists. The other
writers of file items (a document or entity delete) delete the document
row in the same transaction, and the unique index on `storage_path` makes
a new insert for the same path wait for them.
`supabase/tests/database/15_concurrency_findings.test.sql` checks the
policies, the helpers' privileges and order of work, the owner's
privileges on `storage.objects`, and what one session can observe (the
file's row is locked by an insert and an authorised delete, never by a
refused one; the gate is held shared after an insert and exclusively after
a sweep, which takes one lock for 51 queued files; a later daily-job run
sweeps again until a sweep is recorded).

## The 15-minute final sweep relies on an assumption

`admin_complete_storage_cleanup` marks a folder done when the COMPLETION
happens 15 minutes or more after `enqueued_at`. The cleaner's last (empty)
listing comes a moment earlier. TLC found that an upload authorised before
the deletion can commit between that listing and the completion, once the
15-minute mark passes in that gap. `UPLOAD_BOUND` states the assumption the
code needs: an upload authorised before the folder was queued commits at
least δ before the mark, where δ is one RPC round trip. Under it,
`DeletedFoldersQueued` holds. Without it (`late_upload_unbounded`) a file
can be left after its folder item is done. The daily sweep then queues the
folder again, and `live_late_upload_sweep` proves the folder still ends up
empty. A Storage upload's own database transaction is short, so the
assumption is reasonable. The sweep is the backstop when it fails.

## Bounds, abstractions and why they are adequate

- Two portfolios, one entity each, three files (two in P1). Every rule
  relates one file to its document row, its folder, its entity and its
  queue items. Each scenario puts the two to four requests that touch one
  file or folder in conflict; other files only add independent
  interleavings.
- Membership is reduced to "the portfolio exists". Role rules are checked
  in `../Membership`.
- A cleaner claims one item per claim in `StorageCleanup.tla`. The claim's
  ordering and exclusion are checked in `QueueFairness.tla` with claims of 1
  or 2 and two concurrent cleaners (the code claims 20).
- Time has no clock. Waiting items become due through `Tick`/`Due`. The
  order of `not_before` is a sequence (a new or rescheduled item goes to the
  back; a lapsed claim keeps its place). A file "older than a day" is fixed
  per scenario. `attempts` is compared up to 2.
- Failures (Storage errors, spent budgets, crashes) are finitely many
  (`FAILURES`, `CRASHES`), so liveness means "failures are transient".
- A cleaner's claim lease (120 s) outlasts its time budget (25 s), so only a
  crashed cleaner's claim lapses.
- `listing_guard` starts in the state S2 reached (a committed document row
  and an `orphaned` item for the same file). `mut_no_sweep_gate` shows
  the code before the fix reaches it; the guard is still checked on its own.
- Locks are sets of holders, without a capacity: the model cannot show the
  shared lock table filling (the reason the sweep takes one gate rather
  than a lock per file). That limit is measured on PostgreSQL instead (see
  the fix). The sweep's 20 tries of the gate are one step: a failed try
  changes nothing, so a later success is the same step taken later, and
  "still busy" leaves the files for the next sweep (the daily job's next
  run, `S_Commit` back to `s_idle`).
- A document insert attaches one file here. A statement attaching several
  locks their rows in one statement in `name COLLATE "C"` order, the order
  the Storage API locks a batch in; that ordering is checked on PostgreSQL
  (scenario 24's `probe_batch` deadlocks with the rows locked in row order)
  rather than here.
- Each delete deletes one file. The three ways the Storage API deletes,
  the probe flow without its row lock and a service-role delete are
  separate processes (`rm1`, `rms1`, `rmp1`, `rmn1`, `rmsv1`); the Storage
  API's own advisory lock per object key (`waitObjectLock`) is not
  modelled, as no app code takes it.

## How to run

```sh
formal/tla/StorageCleanup/run.sh ci    # 49 configurations, about 1.5 minutes
formal/tla/StorageCleanup/run.sh all   # 62 configurations, about 3.5 minutes
formal/tla/StorageCleanup/replay/run.sh   # S1, S2 on PostgreSQL (tool/db/env.sh)
```

The runner is the same file as `../Membership/run.sh`; each configuration
names its module with `\* SPEC:`. `TLA2TOOLS`, `TLC_JOBS` (default 2),
`TLC_WORKERS` (default 1), `TMPDIR` and `KEEP_LOGS` work as described there.
The replay rebuilds the disposable databases `mm_fv_storage_before` and
`mm_fv_storage`. It exits non-zero unless the code before the fix shows
the three races (`s1`, `s1p`, `s2`) and the current code shows none.

## Expected results

Measured on this machine after the findings migration (4 CPUs; 3 jobs × 1
worker, run one after the other):

- `run.sh ci`: 49/49 as expected in 95 s wall.
- `run.sh all`: 62/62 as expected in 195 s wall. The largest is
  `qf_safety_two_full` (1,060,086 distinct states, 85 s).
- Expected violations: `late_upload_unbounded` (assumption flip), and every
  `mut_*` configuration except `mut_qf_no_turn_live`,
  `mut_no_delete_row_lock_probe`, `mut_no_delete_trigger_probe` and the five
  `*_trigger` twins (see "Properties"). `mut_no_insert_row_lock*` and
  `mut_no_delete_row_lock` reproduce finding S1 with one side of the fix
  removed (the latter with the trigger removed too),
  `mut_no_delete_trigger_*` the deletes the third review found the row
  locks alone miss, and `mut_no_*_gate*` finding S2 with one use of the
  sweep gate removed.

## Cross-check with the executable tests

| Test                                                                                                                                                                                                                                                                                                                                                                           | Here                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `concurrency_test.sh` 12: a document renamed during a long cascade; the folder is queued                                                                                                                                                                                                                                                                                       | `port_delete` (the folder is queued). The rename's lock order is not modelled: it no longer needs the portfolio key after its row (the audit FK was dropped), and since the findings migration its row policy takes the key first |
| `concurrency_test.sh` 13: a document attached while its tenant is deleted                                                                                                                                                                                                                                                                                                      | `entity_race`; `mut_no_entity_lock`                                                                                                                                                                                               |
| `concurrency_test.sh` 16: a deleted portfolio's id claimed during the deletion                                                                                                                                                                                                                                                                                                 | `reuse`; `mut_no_id_registry`                                                                                                                                                                                                     |
| `concurrency_test.sh` 24: S1 with the three Storage API deletes, the probe flow without its row lock and a service-role delete, in every order, and a two-file batch                                                                                                                                                                                                           | `attach_vs_rmfile`, `attach_vs_rmsingle`, `attach_vs_rmprobe`, `attach_vs_rmnolock`, `attach_vs_rmservice`; `mut_no_insert_row_lock*`, `mut_no_delete_row_lock*`, `mut_no_delete_trigger_*`                                       |
| `concurrency_test.sh` 25: S2 in both orders, with the cleaner; a sweep that found the gate busy is not recorded                                                                                                                                                                                                                                                                | `attach_vs_sweep`, `attach_vs_rm_clean`; `mut_no_sweep_gate*`, `mut_no_insert_gate`                                                                                                                                               |
| `concurrency_test.sh` 29 (invariants): no document outlives its entity, references a missing file or a queued one                                                                                                                                                                                                                                                              | `NoOrphanDocument`, `NoDanglingDocument`, `NoDocForQueuedFile`                                                                                                                                                                    |
| `15_concurrency_findings.test.sql`: the file's row is locked by an insert and an authorised delete, never by a refused delete; superuser, service-role and batch deletes keep a referenced file; the gate is held shared after an insert and exclusively after a sweep, which takes one lock for 51 queued files; a later daily-job run sweeps again until a sweep is recorded | `A_Gate`, `A_FKS`, `R_Lock`, `Kept`, `S_Gate`; `service_guard`                                                                                                                                                                    |
| `11_storage_cleanup.test.sql`: what is queued, the listing never offers referenced objects, claims are not handed out twice, finished folders are swept once more, folders take turns, failures back off, attempts reset                                                                                                                                                       | `reattach`, `listing_guard`, `mut_qf_no_lock_recheck`, `mut_no_final_sweep`, `TurnsWithinClaim`, `AttemptsCountFailures`                                                                                                          |

Both test suites run their races one way at a time with fixed sleeps.
Before scenarios 24 and 25, none of them ran a document insert against a
user's file delete or against the daily sweep, which is why S1 and S2 were
not seen. Until the second review, scenario 24 and this model only knew the
Storage API's delete as the user, which is why the probe was not seen; and
until the third review, neither had a delete that holds nothing between its
check and its `DELETE`, or a delete no policy sees.

## Not covered

- The Storage API's object storage itself (S3), resumable uploads and
  upserts; the model follows the `storage.objects` rows.
- `request_storage_cleanup`'s Vault and pg_net plumbing; the cron start is
  modelled as "a run starts when work is due".
- `delete-account`'s own drain restricted to its folders (`p_paths`) is a
  second cleaner in `two_cleaners`; the restriction is not modelled.
- Audit-row cleanup for retired ids (`private.cleanup`) and the backoff
  durations; only the order of events is modelled.
