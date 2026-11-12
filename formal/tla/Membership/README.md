# Membership, account deletion and portfolio deletion (TLA+)

A TLC-checked model of the code that changes who belongs to a portfolio, and
of the code that deletes portfolios and accounts. It follows the code as it
is now:

- `supabase/migrations/*.sql` in filename order, using the last definition of
  each function, trigger and policy. Most of it is in
  `20261105072426_membership_deletion_storage.sql` ("latest" below).
  `20261105170557_concurrency_findings.sql` ("findings" below) fixes finding
  M1 and the client writes that broke the lock order the same way: client
  UPDATE and DELETE row policies, and client INSERTs, take the portfolio
  key first.
- `20261112092618_residence.sql` ("residence" below): the caretaker of a
  portfolio (`set_caretaker`, the triggers `portfolios_before_caretaker_change`
  and `portfolio_members_after_caretaker_ends`, the foreign key's
  `ON DELETE SET NULL`), the owner-abroad answer (`set_owner_abroad`), a
  person's declared residence (`profile_residences` and its client trigger),
  and the last definition of `admin_delete_account_data`, which clears that
  residence last.
- `supabase/functions/delete-account/handler.ts` (`deleteAccount`).

`20261105085837_lease_delete_guard.sql` landed while this work was done. It
was read in full. It adds a `BEFORE DELETE` trigger on `leases` that reads
`charges` without locking and exempts the table owner, so portfolio and
account deletions take the same locks as before. Nothing in it changes this
model.

Files, uploads and the cleanup queue are in `../StorageCleanup`.

## What is modelled

One TLA+ step is one SQL statement, or one row lock of a statement that locks
rows one by one. A statement sees committed rows plus its own transaction's
writes (READ COMMITTED). Row locks follow PostgreSQL: `KEY SHARE` conflicts
only with `FOR UPDATE`/`DELETE`; `NO KEY UPDATE` conflicts with itself and
`FOR UPDATE`. A step that needs a lock held by another transaction is
disabled, so waits are explicit. `Need(t)` is the set of transactions `t`
waits for, which gives the wait-for graph. `Detect` is PostgreSQL's deadlock
detector: it aborts one transaction on a cycle.

| Model element                          | Code                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `A_Live`                               | `deleteAccount` → `liveAccount`: an account already gone is a success                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `A_Prof`, `A_Frz`                      | `admin_delete_account_data`: profile `FOR UPDATE`; `insert into private.account_deletions ... on conflict do nothing` (its FK check takes `KEY SHARE` on `auth.users`)                                                                                                                                                                                                                                                                                                                                                                                                                |
| `A_Mem`, `A_Lock`                      | the loop body: `v_memberships`; `private.lock_portfolios_for_deletion` (`order by p.id for update`, one row per step)                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `A_Lock` (last step)                   | `admin_account_deletion_scope` read after the locks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `A_Purge`                              | `private.delete_locked_portfolios` with `ON DELETE CASCADE` (members, invitation, lease), the user's other memberships, `private.after_portfolios_delete` (retire id), `after_owner_membership_ends`; COMMIT                                                                                                                                                                                                                                                                                                                                                                          |
| `Detect` + `SubRelease`                | `exception when deadlock_detected`: roll back to the savepoint, retry, raise on the third deadlock                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `G_*`                                  | `auth.admin.deleteUser`: `DELETE FROM auth.users`, then its FK actions in the order `GOTRUE_ORDER` names: profiles (cascade), `portfolios.created_by` (set null), `portfolio_members.user_id` (cascade), `portfolio_members.invited_by` (set null, `G_Inv`: a row lock on each row the user invited), `leases.created_by` (set null), `notifications.user_id` (cascade, `G_Note`, one row per step), `account_deletions` (cascade), residence's `portfolios.caretaker_user_id` (set null, `G_Care`); `G_Commit` also waits for the residence row (the profile's second-level cascade) |
| `A_Failed`                             | the POST fails or its response is lost; the client retries (`MAX_POSTS`) or gives up                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `M_Auth`, `M_Lock`, `M_Do`, `M_Write`  | `remove_member` and `update_member_role` (latest): `private.lock_portfolio_for_change` (authorise, `for update`, authorise again), `member_not_found`, `last_owner`, the write with trigger `portfolio_members_after_owner_ends`                                                                                                                                                                                                                                                                                                                                                      |
| `X_Act`, `X_PLock`, `X_Inv`, `X_Ins`   | `accept_invitation` (latest): `private.require_active_account`, portfolio `KEY SHARE`, invitation `FOR UPDATE`, the inviter-is-owner check, the member insert and its FK checks                                                                                                                                                                                                                                                                                                                                                                                                       |
| `K_Act`, `K_Check`, `K_Ins`            | `create_portfolio` (latest): `require_active_account`, existing id, `private.portfolio_ids` lookup, the insert and trigger `portfolios_after_insert_register_id`                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `D_Auth`, `D_Lock`, `D_Purge`          | `delete_portfolio` (latest), with the same retry loop                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `Y_*`                                  | `record_payment` via `private.lock_lease_for_write`: an in-order lease writer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `L_Set`, `L_PKS`                       | findings: the row policy `leases_update` gets its portfolios from `app.lock_my_portfolio_ids` in an initplan, which runs before the statement locks a row: the caller's owner/manager portfolios, `FOR KEY SHARE` in id order (one row per step), then authorised again                                                                                                                                                                                                                                                                                                               |
| `L_Upd`, `L_FK`                        | a client's plain `update leases set security_deposit` (granted in `20261103193403_leases.sql`): the policy lets through only rows of portfolios both locked and still authorised; the lease row lock; its trigger `private.after_lease_deposit_update` (`20261104143928`) inserts a charge, whose FK check takes the portfolio key (already held)                                                                                                                                                                                                                                     |
| `I_Set`, `I_PKS`, `I_Chk`              | findings: a client INSERT (`occB`/`occBr` a lease occupant, `tenB` tenants of two portfolios): the policy's WITH CHECK gets its portfolios from `app.lock_my_portfolio_ids`, whose initplan runs at the first row's check, before any row is inserted or any foreign key checked; every row's portfolio must be locked and still authorised                                                                                                                                                                                                                                           |
| `I_FK`                                 | the rows' foreign-key checks, one AFTER ROW trigger per step in trigger-name order (`KEY SHARE` on the parent), then COMMIT. Migration order checks `portfolio_id` first (`occB`); a restored database checks `lease_occupants_lease_fkey` first (`occBr`); rows are checked in row order (`tenB`)                                                                                                                                                                                                                                                                                    |
| `C_Auth`, `C_Lock`, `C_Do`             | residence: `set_caretaker`: authorise, the portfolio `FOR NO KEY UPDATE`, authorise again, the named person's role (`member_not_found`, `caretaker_not_manager`); naming the caretaker again updates no row                                                                                                                                                                                                                                                                                                                                                                           |
| `C_Trig`, `C_FK`                       | the UPDATE's trigger `private.before_portfolio_caretaker_change`: the membership `FOR SHARE` (waits for a writer of the row, reads its newest version, `caretaker_not_manager`); then the foreign-key check of `caretaker_user_id` (`KEY SHARE` on `auth.users`) and COMMIT                                                                                                                                                                                                                                                                                                           |
| `O_Auth`, `O_Lock`, `O_Do`             | residence: `set_owner_abroad(q, r, p_if_unanswered => true)`, as the app asks on the next open: authorise (owner or manager), the answer read `FOR NO KEY UPDATE` in one statement, authorise again, an answer already given returned and kept, else written; COMMIT                                                                                                                                                                                                                                                                                                                  |
| `R_Upd`, `R_Commit`                    | residence: the person's `update profile_residences` (policy `profile_residences_update_own`): the row lock, then the BEFORE trigger `before_profile_residence_client_update`, which refuses once the account's deletion has committed (`account_deleted`)                                                                                                                                                                                                                                                                                                                             |
| `A_Res`                                | residence: `admin_delete_account_data`'s last statement, the unfiltered `update profile_residences ... where user_id = u`, after the retry loop; merged into `A_Purge`'s COMMIT in scenarios where nobody else writes that row                                                                                                                                                                                                                                                                                                                                                        |
| `S_Row`, `S_Trig`                      | a service-role `UPDATE` or `DELETE` of a membership without a portfolio lock (an operator): the row lock, then `portfolio_members_after_caretaker_ends` at the end of the statement, which locks the portfolio row only if that person is its committed caretaker; COMMIT                                                                                                                                                                                                                                                                                                             |
| `mSh`, `BMW`                           | `FOR SHARE` on member rows: every `UPDATE` or `DELETE` of a member row (the RPCs, the deletions' cascades, GoTrue, the service role) waits for its holders                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `M_Write`, `A_Purge` (residence)       | `portfolio_members_after_caretaker_ends` on the RPCs' and the account deletion's manager rows: it clears the caretaker under the portfolio lock they hold                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `N_Prof`, `N_PKS`, `N_Upd`, `N_Commit` | findings: `noteB` marks two notifications read (`n2`, then `n1`) under `notifications_update_own`, whose `app.lock_my_notification_portfolios` takes the account key (`profiles`, `KEY SHARE`), then the portfolios of the caller's notifications where they are a member, before the first row; each UPDATE locks its row (`NO KEY UPDATE`)                                                                                                                                                                                                                                          |

`SCENARIO` picks the processes and the initial rows (`ScenarioProcs`,
`Members`, `Inv`, `InitCare`, `InitInvitedBy`). `MUTANT` removes one
mechanism; `no_client_key` is the code M1 was found in (the lease row first,
then the portfolio key), and `no_insert_key` the INSERT policies before this
fix. `WAKE_FIRST` and `GOTRUE_ORDER` are scheduling and environment
assumptions (see below). `GOTRUE_ORDER` is `portfolios_first` (a migrated
database: the constraints' creation order), `leases_first`,
`caretaker_first` (the caretaker's `SET NULL` first, which its trigger name
gets if its OID has one more digit than the others) or `restored` (a
`pg_dump` restore: by constraint name). A foreign-key action on a column that
no process of a scenario can set (no caretaker is ever named, nobody invited
anyone) is left out of that scenario's sequence (`GUsed`): it would take no
lock in any state.

## Properties

| Property                      | Plain language                                                                                                                                 | Broken by                                                                                                                                                                                                                                                                                                                       |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AtLeastOneOwner`             | Every portfolio that exists has an owner (TEAM-04).                                                                                            | `mut_scope_before_lock`, `mut_no_member_lock`, `mut_no_last_owner`, `mut_no_freeze_orphan`                                                                                                                                                                                                                                      |
| `NoMemberless`                | Every portfolio that exists has a member.                                                                                                      | `mut_scope_before_lock_memberless`                                                                                                                                                                                                                                                                                              |
| `NoActivityAfterDeletion`     | Once `admin_delete_account_data(u)` has committed, `u` has no membership, and nothing commits a membership or portfolio for `u`.               | `mut_no_freeze`                                                                                                                                                                                                                                                                                                                 |
| `IdsNeverReused`              | A deleted portfolio's id never comes back.                                                                                                     | `mut_no_id_registry`                                                                                                                                                                                                                                                                                                            |
| `NoWaitCycle`                 | No transaction waits, directly or through others, for itself.                                                                                  | `mut_unordered_locks`, `mut_no_client_key_cycle`, `mut_no_insert_key_cycle`, `mut_no_note_account_key`, `mut_care_member_first`; documented behaviours `assume_gotrue_leases_first`, `assume_direct_auth_care*`, `assume_direct_auth_member`, `assume_service_member_write`, `assume_restored_notes`, `assume_restored_inviter` |
| `DeletionNotDefeated`         | A deletion transaction never fails with `deadlock_detected`.                                                                                   | `mut_no_client_key`, `mut_no_client_key_acct` (finding M1); `mut_no_insert_key`, `mut_no_insert_key_rows` (client inserts); `mut_no_deadlock_retry`, `mut_no_deadlock_retry_acct` (GoTrue in the restored order, under `WAKE_FIRST`); documented behaviour `assume_direct_auth_dport`                                           |
| `AuthorisedAtCommit`          | Every committed membership change was authorised at commit time.                                                                               | `mut_no_recheck`                                                                                                                                                                                                                                                                                                                |
| `DeletesOnlySoleOwned`        | An account deletion deletes a portfolio only while the user is its only owner.                                                                 | `mut_scope_before_lock_sole`                                                                                                                                                                                                                                                                                                    |
| `InviterAuthority`            | A member joins through an invitation only while its inviter is an owner.                                                                       | `mut_no_inviter_auth`                                                                                                                                                                                                                                                                                                           |
| `CompletedDeletionsClean`     | After a successful delete-account POST the account is gone, without memberships, and what it deleted stays deleted.                            | `mut_no_id_registry_acct`                                                                                                                                                                                                                                                                                                       |
| `CaretakerIsManager`          | residence: a portfolio's caretaker is, in committed state, a member of it with the manager role.                                               | `mut_no_care_share` (a service-role demotion in flight), `mut_no_care_trigger`                                                                                                                                                                                                                                                  |
| `CaretakerAuthorisedAtCommit` | residence: `set_caretaker` commits only while its caller is an owner.                                                                          | `mut_no_care_recheck`                                                                                                                                                                                                                                                                                                           |
| `AnswerAuthorisedAtCommit`    | residence: an answer is written only while its caller may give it: an owner or a manager while it is unanswered, an owner once it is answered. | `mut_no_abroad_recheck`                                                                                                                                                                                                                                                                                                         |
| `FirstAnswerKept`             | residence: the question asked on the next open never overwrites an answer already given.                                                       | `mut_abroad_unlocked_read`                                                                                                                                                                                                                                                                                                      |
| `ResidenceGoneAfterDeletion`  | residence: once an account's deletion has committed, the person's declared residence is cleared and stays so while the row exists.             | `mut_residence_filtered`, `mut_no_residence_refusal`                                                                                                                                                                                                                                                                            |
| `AllFinish` (liveness)        | Every request finishes: waits end and deadlocks are resolved.                                                                                  | `mut_unbounded_retry`                                                                                                                                                                                                                                                                                                           |
| `TypeOK`, `RefIntegrity`      | Sanity of the model (types; foreign keys hold in committed rows).                                                                              | none: `RefIntegrity` is enforced by PostgreSQL's foreign keys, which the model reproduces rather than the app code                                                                                                                                                                                                              |

Seven mutants are expected to pass, and say so in their headers. They show
redundancy or an assumption, not vacuity:

- `mut_no_inviter_check` and `mut_no_revoke_trigger`: either the
  accept-time check or the revoking trigger alone keeps `InviterAuthority`.
  Removing both (`mut_no_inviter_auth`) breaks it.
- `mut_no_id_precheck` and `mut_no_id_trigger`: on the `create_portfolio`
  path either the registry lookup or the insert trigger alone keeps ids
  single-use. The trigger also guards other insert paths, which are not
  modelled.
- `mut_no_client_key_wake` and `mut_no_client_key_acct_wake`: without the
  portfolio key first, the deletion's retry alone succeeds only under
  `WAKE_FIRST`. That timing assumption is what a backoff before the retry
  would have relied on, which is why the fix does not use one.
- `mut_no_insert_key_mig`: without the key in the WITH CHECK, a one-row
  insert is safe in migration order, where the portfolio key is checked
  first. Only a restored database (`mut_no_insert_key`) or a statement
  spanning portfolios (`mut_no_insert_key_rows`) shows the cycle, which is
  why no test found it.

## Finding M1: the deadlock retry is not a guarantee (fixed)

Severity: low to medium. A deletion could fail with `40P01` against a single
client write. Fixed by `20261105170557_concurrency_findings.sql`.

`delete_portfolio` and `admin_delete_account_data` catch `deadlock_detected`
and retry their lock-and-delete step, up to three attempts. The retry
re-locks the portfolio at once. The client write that caused the cycle is
still open and still holds its lease row. Woken by the rollback, it races
the retry for the portfolio key. If the retry wins, the same cycle forms
again. If PostgreSQL picks the deletion three times, the deletion fails.

Counterexample on the code before the fix (`cfg/mut_no_client_key.cfg`, 9
states, shortened):

1. `D_Auth`, `D_Lock`: `delete_portfolio(P1)` holds P1 `FOR UPDATE`.
2. `L_Upd`: B's `update leases set security_deposit` locks the lease. Its
   trigger now waits for P1's key; the deletion's cascade waits for the
   lease. This is a cycle.
3. `Detect`: the deletion is the victim; savepoint rollback, attempt 2.
4. `D_Lock`: the deletion re-locks P1 before B's statement moves. Cycle again.
5. `Detect`, `D_Lock`, `Detect`: the third deadlock is raised:
   `DeletionNotDefeated` is violated.

In the model the detector may pick any transaction on a cycle. PostgreSQL
picks the waiter whose `deadlock_timeout` fires first after the cycle forms,
so the deletion usually loses once and the client loses the next cycle.
That made M1 rare: 2 failed deletions in 83 runs of the replay before the
fix.

### The fix

Every client UPDATE and DELETE row policy on a portfolio's rows (26
policies, M1's `leases_update` among them) now gets its set of writable
portfolios from `app.lock_my_portfolio_ids(roles)`, wrapped in a scalar
subquery. That is one initplan per statement; it runs when the scan
evaluates its first row, before the statement locks any row. It locks the
caller's portfolios with those roles `FOR KEY SHARE` in id order (the order
deletions use), then authorises again with a fresh snapshot and returns
only portfolios both locked and still authorised. A deletion that holds a
portfolio makes the client wait before it locks anything, and a client that
holds the key makes the deletion wait. No cycle can form, so the retry is
never needed for these writes.

The proposal was a `BEFORE UPDATE ... FOR EACH STATEMENT` trigger. The
policy form was chosen instead because the trigger reads the caller's
memberships with a newer snapshot than the row policy: a membership removed
between the two would let the statement write rows of a portfolio it did
not lock. In the policy, the set it locks is the set it filters by. Policies
apply only to the `authenticated` role, so SECURITY DEFINER functions, the
daily job and the service role (all bypass row security) keep their own lock
order. An `INSERT ... ON CONFLICT DO UPDATE` would lock the conflicting row
before the UPDATE policy runs; no client can run one (the Data API's upsert
sets every inserted column, `portfolio_id` is required, and no client may
update it; `supabase/tests/database/15_concurrency_findings.test.sql`
checks both).

The same pattern broke the lock order in other client writes, each run
against PostgreSQL in `tool/db/concurrency_test.sh` (see the cross-check
below). The UPDATE and DELETE policies fix: an UPDATE whose foreign-key
check needs a new parent row the cascade took first, a multi-row UPDATE or
DELETE, a multi-row UPDATE of portfolios, notifications written while the
account is deleted (their helper takes the account key first, then only
portfolios the caller still belongs to), and cascading deletes under
another foreign-key order.

The account key matters for GoTrue's own user delete (an operator deleting
the user in the dashboard, without `delete-account`): on a migrated database
its cascade deletes the profile, then the user's notifications in its scan
order. Without the key, a client marking two notifications read in the other
order holds one and waits for the other, which the cascade holds while it
waits for the first (`notes`, `mut_no_note_account_key`; scenario 23's
`gotrue_backward` deadlocks on PostgreSQL with the key removed). A database
restored from a dump deletes the profile last, so the key cannot help there
(`assume_restored_notes`, below).
`admin_delete_account_data` needs no key there: it locks every portfolio
the user belongs to before it deletes the notifications, and the client
takes those portfolios' keys before its first notification.

Client INSERTs needed their own change. A row's foreign keys are checked by
AFTER ROW triggers in trigger-name order, which is the constraints'
creation order. The migrations created every `portfolio_id` key first, but
`pg_dump` re-creates foreign keys by constraint name, so a restored
database checks a parent the cascade deletes before the portfolio:
`lease_occupants`, `maintenance_requests` and `reminder_logs` their lease,
`meter_readings` its utility account and lease, `expenses` its
maintenance request, `utility_bills` its utility account (a real
`pg_dump | psql` restore, listed with `pg_trigger`). And an INSERT of rows
of two portfolios checked them in row order, against the id order of
`admin_delete_account_data`, in any database. Both deadlocked on
PostgreSQL. Now:

- the INSERT policies of the twelve tables without a locking BEFORE ROW
  trigger take their portfolios from `app.lock_my_portfolio_ids` in the
  WITH CHECK, whose initplan runs at the first row's check, after that
  row's BEFORE ROW triggers (only `leases` has one, and it locks nothing)
  and before any row is inserted or any foreign key checked;
- documents and manual charges lock the row's portfolio and then its entity
  or lease in BEFORE ROW triggers, which run before any WITH CHECK. A
  `BEFORE INSERT ... FOR EACH STATEMENT` trigger
  (`private.before_client_insert_lock_portfolios`) takes the caller's keys
  first. It runs as the caller and acts only when `current_user` is
  `authenticated`, so an insert by a SECURITY DEFINER function (which runs
  as its owner and locks its portfolio itself) is unchanged. The row
  triggers then re-take their row's key with `SKIP LOCKED`: they already
  hold it, so they never wait. A portfolio joined after the statement
  trigger ran is the only one they can miss; if a deletion or membership
  change holds it, the row is refused rather than locked out of order.

This model has both writers: `deposit*` (M1) and `insert*` (a restored
database's occupant insert, and an insert spanning two portfolios).

The price of taking every key before any row: `lock_my_portfolio_ids` locks
every portfolio where the caller has the role, not only those the
statement writes, because the initplan runs before any row is known. A
client write therefore waits while any such portfolio is being deleted or
its members changed. Measured on PostgreSQL 16: an owner of portfolios A
and B updated a tenant in A, and inserted one there, while another session
held B `FOR UPDATE` for 2 s; each took 1.77 s (0.09 s before the findings
migration). Nothing else waits on these keys, and every key is taken
before any row, so the wait cannot be part of a deadlock. Locking lazily
per row would break the order for statements that span portfolios, so this
is kept as a deliberate trade-off.

Results on PostgreSQL 16:

- `replay/run.sh` (`RUNS=20`): before the fix, 20 of 20 runs detected 1 to
  3 deadlocks (28 in all; the client was refused in 5); with the fix, 0
  deadlocks in 20 runs, the charge inserted and the deletion done every
  time.
- `tool/db/concurrency_test.sh` scenario 19 (32 rounds, four timings, the
  real deposit UPDATE): before the fix every round deadlocked (35 deadlocks);
  with the fix none did.
- Scenario 22's inserts spanning two portfolios (tenants, documents, manual
  charges) and scenario 26's six inserts on a `pg_dump`/restore copy each
  deadlocked once on the code before the findings migration and on the
  findings migration without its INSERT part (the client was the victim
  every time), and never with it.
- `cfg/deposit.cfg`, `cfg/deposit_acct.cfg`, `cfg/insert.cfg` and
  `cfg/insert_rows.cfg` pass `NoWaitCycle`, `DeletionNotDefeated`, the
  other invariants and `AllFinish`.

## Residence: the caretaker, the owner-abroad answer and a declared residence

`20261112092618_residence.sql` adds three writers to the paths this model
covers, and one more row to every account deletion (the residence, last).
The model checks each against the membership changes and deletions above,
in the scenarios `caretaker`, `caretaker_svc`, `caretaker_acct`, `answer`,
`residence`, `residence_team` and `inviter`. On the app's own paths (the
RPCs, a person's own residence write, `delete-account`'s order on a migrated
database) every interleaving keeps the five properties below, no wait-for
cycle forms and every request finishes. No change to the SQL was needed.

| Property                      | Kept by (code)                                                                                                                                                                                                                                                                                                                                                            | Assumption                                                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `CaretakerIsManager`          | the trigger's `FOR SHARE` read of the membership after the portfolio row (a role change in flight, even by the service role, is waited for and its result read); `portfolio_members_after_caretaker_ends` on every end of a manager membership; `set_caretaker`'s portfolio lock against the RPCs' `FOR UPDATE`; the foreign key's `SET NULL` in GoTrue's own transaction | none: it holds against the service role and direct Auth deletes too (`caretaker_svc`, `caretaker_direct_rpc`, `caretaker_svc_rpc`)             |
| `CaretakerAuthorisedAtCommit` | the second `require_portfolio_role` after `FOR NO KEY UPDATE`, against `lock_portfolio_for_change`'s `FOR UPDATE`                                                                                                                                                                                                                                                         | whoever ends an owner's role holds the portfolio: the RPCs and the deletions do; the service role is out of scope, as for `AuthorisedAtCommit` |
| `AnswerAuthorisedAtCommit`    | the portfolio lock between two authorisations in `set_owner_abroad`                                                                                                                                                                                                                                                                                                       | the same, and `O_Do`'s merge (bounds, below)                                                                                                   |
| `FirstAnswerKept`             | the answer read `FOR NO KEY UPDATE` in the statement that takes the lock, and the early return of an answer already given                                                                                                                                                                                                                                                 | none                                                                                                                                           |
| `ResidenceGoneAfterDeletion`  | the deletion's residence `UPDATE` without a filter on the values (it waits for a write in flight and clears what it committed); the client trigger's `account_deleted` check, which runs after the row lock and so sees the committed deletion; the freeze row committed with the clear                                                                                   | a client writes the row in one statement (PostgREST)                                                                                           |

The lock order of each new path, and why it keeps `NoWaitCycle`:

- `set_caretaker` and `set_owner_abroad` take the portfolio first
  (`FOR NO KEY UPDATE`), then (the caretaker) the membership `FOR SHARE`
  and the named person's `auth.users` key last. Taking the membership first
  would form a cycle with `update_member_role` (`mut_care_member_first`).
- The membership RPCs and `admin_delete_account_data` already hold the
  portfolio when their trigger clears the caretaker.
- A person's residence `UPDATE` holds that row only; the deletion writes it
  last, after every portfolio and membership.

Outside the app's own paths the model finds four lock-order behaviours.
They are documented as operator rules in `docs/operations.md`, "Deleting a
user account", and replayed on PostgreSQL 16 by `replay/residence.sh`. The
delete-account order (`admin_delete_account_data` first) and an operator who
locks the portfolio first avoid all of them on a migrated database, so no
SQL was changed for them:

- **D1** (new): a direct Auth delete of a caretaker against
  `update_member_role`, `remove_member` or leaving. The RPC holds the
  portfolio; the delete's cascade takes the membership, then the caretaker's
  `SET NULL` needs the portfolio; the RPC's write needs the membership
  (`assume_direct_auth_member`; R2: a deadlock in every round, and none when
  the manager is not the caretaker). With the caretaker's `SET NULL` first
  (`caretaker_first`) there is no cycle (`caretaker_direct_rpc_first`).
  `set_caretaker` against a direct Auth delete of the person it names forms
  a cycle in any order: it needs that person's `auth.users` key last
  (`assume_direct_auth_care*`, R1). A `BEFORE DELETE` trigger on
  `auth.users` that cleared the caretaker first (its portfolios in id order)
  would take the portfolio before the membership and so remove D1 (the
  replay checks it) and, by the same order, D3, but not R1: PostgreSQL locks
  the `auth.users` row before the trigger runs (checked too). Like the trigger
  evaluated for the Invitations track's F3, it would also run inside GoTrue's
  transaction, where an error fails the Auth delete; it is not adopted, and
  the choice is the owner's.
- **D2** (new): a service-role `UPDATE` or `DELETE` of the caretaker's
  membership against those RPCs: the row, then the portfolio in its trigger
  (`assume_service_member_write`; R3). A row trigger cannot take the
  portfolio earlier: PostgreSQL locks the row before any row trigger runs.
  Locking the portfolio first in the operator's transaction avoids it (R3
  with the rule; scenario 31's `operator_locks_portfolio_first_*`).
- **D3** (new): `delete_portfolio`, or the account deletion of the
  portfolio's only owner, against a direct Auth delete of its caretaker: the
  same cycle, which the deletion's retry absorbs when PostgreSQL picks the
  deletion (R4: one deadlock, and both succeed). Without `WAKE_FIRST` three
  cycles in a row can fail the deletion (`assume_direct_auth_dport`); with it
  they cannot (`caretaker_direct_dport_wake`).
- **P1** (not new; the residence paths join it): a restored database runs
  GoTrue's foreign-key actions by constraint name, so
  `portfolio_members.invited_by` comes before `portfolios.created_by` and the
  notifications before the profile. There even the delete-account order of a
  user who created a portfolio and invited a member deadlocks with
  `set_caretaker` or `update_member_role` of that member
  (`assume_restored_inviter`, against `inviter` on a migrated database; R6),
  and a direct Auth delete with marking notifications read
  (`assume_restored_notes`; R7). `docs/operations.md` restores the schema from
  the migrations, which keeps their order. A follow-up could close it for
  dumps too: `admin_delete_account_data` would set the user's
  `portfolios.created_by` and `portfolio_members.invited_by` to NULL under
  the portfolio locks it takes, so that GoTrue's `SET NULL` finds nothing.

The delete-account order itself (`admin_delete_account_data`, then GoTrue)
has none of these on a migrated database (`caretaker_acct`,
`caretaker_acct_first`, `inviter`; R5, and scenario 31's `naming_holds`,
`deletion_holds` and `demote_holds`: no deadlock).

## Documented behaviours (expected violations that are not bugs)

- `assume_gotrue_leases_first`: GoTrue's FK actions run in trigger-name
  order (`RI_ConstraintTrigger_a_<oid>`, compared as text). With
  `portfolios.created_by` before `leases.created_by` (creation order, the
  case `concurrency_test.sh` scenario 17 exercises) no cycle forms. A
  restored database orders them the other way: `pg_dump` re-creates foreign
  keys by constraint name (checked with `pg_dump --section=post-data` and
  `pg_trigger` on a copy; `replay/residence.sh` prints both orders), so
  `leases` comes before `portfolios`. Scenario 17 would then form a cycle;
  the retry absorbs it under `WAKE_FIRST`
  (`assume_gotrue_leases_first_wake`). This is the cycle the retry still
  exists for, so the retry's mutants (`mut_no_deadlock_retry*`,
  `mut_unbounded_retry`) run against it. `leases_first` moves only `leases`;
  the whole restored order is `restored` (`assume_restored_setnull` passes
  under `WAKE_FIRST`).
- `assume_direct_auth_care`, `assume_direct_auth_care_first`,
  `assume_direct_auth_member`, `assume_direct_auth_dport`: a direct Auth
  delete of a caretaker or of the manager being named (D1, D3 above).
  `caretaker_direct_rpc` and `caretaker_direct_dport_wake` check that the
  cycles are resolved and the other properties kept.
- `assume_service_member_write`: a service-role change of the caretaker's
  membership (D2); `caretaker_svc_rpc` checks the rest.
- `assume_restored_notes`, `assume_restored_inviter`: a restored database's
  foreign-key order (P1).

## Bounds, abstractions and why they are adequate

- Three users, three portfolio ids, one invitation and one lease per
  portfolio. Every rule in this code relates one user, one portfolio and
  one other row (a co-owner, an invitation, a lease). Each scenario puts two
  to four requests on the same rows, which is where the races are. Any
  interleaving of more requests on more rows is made of these pairwise
  conflicts, because there is one global lock order (account → portfolio →
  lease → other rows), and the only order breakers are covered explicitly
  (the deposit trigger and GoTrue's FK actions).
- Statements under a lock that excludes every other writer of the same rows
  are merged into one step. Each merge is commented. Where a mutant removes
  that lock, the steps are split (`M_Do`/`M_Write`), so the mutant's race is
  visible.
- Waiters for an exclusive row lock are not queued among themselves. With
  one global order a queue cannot close a cycle, and the out-of-order
  writers wait for a holder.
- E-mail matching, verification, rate limits, the 20-portfolio limit,
  confirmation names and expiry always pass. They only refuse more requests.
- Documents and files are in `../StorageCleanup`. The drain after
  `deleteUser` is not modelled here, nor is `admin_delete_account_data`'s
  own notification delete (see the notifications paragraph above; scenario
  23 runs it against PostgreSQL).
- `CAN_ABORT` lets any open transaction fail (timeouts, lost connections).
  `MAX_POSTS = 2` lets the client retry a POST once.
- The client's key-first lock is modelled for two writers, which lock
  every portfolio where they have a lease role: the deposit UPDATE and an
  INSERT (one lease occupant, or tenants in two portfolios). The other
  client UPDATEs and DELETEs the findings migration fixed are not modelled
  here (see the cross-check); they share the deposit writer's policy
  shape, and the INSERTs of other tables share the insert writer's.
- Residence: `set_owner_abroad`'s statements after the lock are merged into
  one step (`O_Do`). While it holds the portfolio, no membership change by
  an RPC or a deletion and no other answer can commit. A service-role or
  GoTrue membership write could (they take no portfolio lock), so no
  `answer` scenario has one: the merge would hide the stale authorisation
  such a write can cause, which is out of scope as for `AuthorisedAtCommit`.
- The audit row's foreign-key check of `actor_id` (`KEY SHARE` on the
  caller's `auth.users` row) in `set_caretaker` and `set_owner_abroad` is
  not modelled, as for every audited write here. It can only meet a direct
  Auth delete of the caller.
- An owner changing a given answer (`p_if_unanswered => false`,
  `owner_abroad_answered`) is not scripted: it takes the same lock and
  authorises again like the first answer. `create_portfolio`'s
  `p_owner_abroad` and the empty residence row that `profiles`' AFTER INSERT
  trigger adds are inserts nobody else sees until they commit.
- `portfolio_members.invited_by` is derived rather than stored
  (`InvitedBy`): the initial rows of `inviter`, and the rows
  `accept_invitation` inserts (an `ASSUME` checks no other process inserts
  them). GoTrue's `SET NULL` of it is a row lock on each row (`G_Inv`).
- The service role changes one membership per statement and commits
  (`S_*`), as an operator in the SQL editor does.
- `ReleaseAll` and `CommitDB` take the state through `Once`, a bound
  variable: TLC evaluates an operator's argument again at each use, and they
  use it dozens of times. The result is the same; `two_deletions` went from
  8.9 s to 6.4 s.

## How to run

```sh
formal/tla/Membership/run.sh ci     # 53 configurations, about 1 minute
formal/tla/Membership/run.sh all    # 79 configurations, about 2 minutes
formal/tla/Membership/run.sh all deposit   # only names containing "deposit"
```

It works from any directory. `TLA2TOOLS` points to `tla2tools.jar` (TLC
2.19; default from `.cache/formal/env.sh`, which `tool/formal/install.sh` writes, else
`.cache/formal/tla2tools.jar` in the repository, which git ignores); `java` must be on `PATH`. `TLC_JOBS` (default 2) configurations run
at once with `TLC_WORKERS` (default 1) workers each. Scratch goes under
`${TMPDIR:-/tmp}` and is kept when a configuration does not match its
expectation (`KEEP_LOGS=1` keeps it always). Each `cfg/*.cfg` states its
expected outcome (`\* EXPECT:`) and mode (`\* MODE:`). A result that differs
in either direction fails the run.

`replay/run.sh` replays M1 on a local PostgreSQL (`tool/db/env.sh`): the
code before the fix (every migration that sorts before
`*_concurrency_findings.sql`) and the current code. It rebuilds the
disposable databases `mm_fv_membership_{before,current}`. It fails if the
current code deadlocks or a deletion fails there. Results before the fix
depend on timing and are only reported. `RUNS` sets the runs per variant
(default 6).

`replay/residence.sh` replays the residence behaviours above (R1 to R7) on
`mm_fv_residence`, built with `tool/db/reset.sh`, and on
`mm_fv_residence_restored`, a `pg_dump | psql` copy of it, and prints
GoTrue's foreign-key order in each. Each race is ordered with `fv.hold`
gates, so its cycle forms every time; which session PostgreSQL aborts is
only reported. It fails if a documented cycle does not form, or if the
delete-account order (R5), the R2 control, R3 with the operator's rule, or
R6 and R7 on the migrated database deadlock. `ROUNDS` repeats R1 to R4.

## Expected results

Measured on 2026-11-12 after the residence migration, on a 4-CPU machine
with little else running:

- `run.sh ci`: 53/53 as expected in 49 to 58 s wall over four runs (2 jobs
  × 1 worker, as CI runs it; 56 s inside `make verify`). The 36
  configurations before the residence work took 42 s. The largest is
  `two_deletions` (8,902 distinct states).
- `run.sh all`: 79/79 as expected in 101 s wall with 3 jobs × 1 worker, and
  111 s with 2. The largest are `team` (214,447 distinct states, 45 s) and
  `residence_team` (11,052, 29 s, most of it the liveness check).
- Expected violations: the documented behaviours (every `assume_*`
  configuration except the three that pass under `WAKE_FIRST`), and every
  `mut_*` configuration except the seven named above (`mut_no_client_key*`
  reproduce finding M1 with the fix removed, `mut_no_insert_key*` the client
  inserts).
- `replay/residence.sh` on PostgreSQL 16.15: every outcome as expected (R1,
  R2, R3 without the rule, R4, and R6 and R7 backward on the copy: one
  deadlock each; the R2 control, R3 with the rule, R5, and R6 and R7 on the
  migrated database: none).

## Cross-check with `tool/db/concurrency_test.sh`

| Scenario there                                                                                            | Here                                                                                                             |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| 7 removed owner changes a role                                                                            | `stale_owner`; `mut_no_recheck`                                                                                  |
| 8 co-owners delete their accounts at once                                                                 | `two_deletions`, `double_post`; `mut_scope_before_lock`, `mut_unordered_locks`                                   |
| 9 portfolios deleted while leases are written                                                             | in part: `payA` (an in-order lease writer) in `gotrue_setnull`; the daily job is not modelled                    |
| 10 invitation accepted while the portfolio is deleted                                                     | `accept_delete`                                                                                                  |
| 11 child rows and a billing sync racing a deletion                                                        | in part: the in-order writers follow the same pattern as `payA` and `depoB` (M1, now in order)                   |
| 14 joining or creating while the account is deleted                                                       | `freeze`, `freeze_orphan`; `mut_no_freeze*`                                                                      |
| 16 a deleted portfolio's id claimed during the deletion                                                   | `id_reuse`, `acct_reuse`; `mut_no_id_registry*`                                                                  |
| 17 auth user deleted while a co-owner deletes the portfolio                                               | `gotrue_setnull`; `assume_gotrue_leases_first*`, `assume_restored_setnull`                                       |
| The invariants step: no portfolio without an owner or members                                             | `AtLeastOneOwner`, `NoMemberless` in every configuration                                                         |
| 19 M1: deposits changed while the portfolio or the owner's account is deleted                             | `deposit`, `deposit_acct`; `mut_no_client_key*`                                                                  |
| 22 (inserts) and 26 (inserts): rows of two portfolios; a restored database                                | `insert_rows`, `insert`; `mut_no_insert_key*`                                                                    |
| 23 notifications marked read while GoTrue deletes the user                                                | `notes`; `mut_no_note_account_key`; on a restored database `assume_restored_notes` (`replay/residence.sh`, R7)   |
| 20, 21, 22 (updates), 23 (by `admin_delete_account_data`), 26 (updates, deletes), 27: other client writes | not modelled here (one lease per portfolio, no FK parents); 27 is the helper's re-authorisation, `DepoAuth` here |
| 31 `owner_demotes`, `owner_removes`, `namer_removed` and their `naming_then_` cases                       | `caretaker`; `mut_no_care_recheck`, `mut_no_care_trigger`, `mut_care_member_first`                               |
| 31 `service_demotes`, `service_removes` and their `naming_then_` cases                                    | `caretaker_svc`; `mut_no_care_share`                                                                             |
| 31 `owner_answers_first`, `manager_answers_first`, `answerer_demoted`                                     | `answer`; `mut_no_abroad_recheck`, `mut_abroad_unlocked_read`                                                    |
| 31 `residence_then_deletion`, `deletion_then_residence` and the later write                               | `residence`; `mut_residence_filtered`, `mut_no_residence_refusal`                                                |
| 31 `naming_holds`, `deletion_holds`, `demote_holds` (the caretaker's account deleted)                     | `caretaker_acct`, `caretaker_acct_first` (`replay/residence.sh`, R5)                                             |
| 31 `operator_locks_portfolio_first_*`                                                                     | the rule that avoids `assume_service_member_write` (`replay/residence.sh`, R3)                                   |

Scenarios 12, 13, 24 and 25 (documents) are in `../StorageCleanup`.
Scenarios 1 to 6, 15, 18 and 29 are ledger races, outside this track, and 30
is in `../Invitations`. Before scenario 19, no scenario exercised the deposit
trigger against a deletion, which is why M1 was not seen.

## Not covered

- Invitation creation, revocation and expiry in depth (another track,
  `formal/tla/Invitations`).
- The daily job, billing sync and other ledger writers except the lease
  writers above.
- A raw `auth.users` delete by an operator, outside `delete-account`, of an
  owner: GoTrue then cascades memberships without the last-owner rule. The
  model's `goB` is a user who is no member, or (`notes`) only a manager, and
  `goC` a manager and caretaker (D1 to D3).
- `admin_delete_account_data`'s notification delete (run against
  PostgreSQL by `concurrency_test.sh` scenario 23), the preview (`GET`),
  rate limits, re-authentication and MFA checks of `delete-account`.
- Timing: the model has no clocks; `WAKE_FIRST` stands in for a scheduling
  assumption such as a backoff before the retry.
