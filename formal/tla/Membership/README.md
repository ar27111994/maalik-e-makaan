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

| Model element                          | Code                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `A_Live`                               | `deleteAccount` → `liveAccount`: an account already gone is a success                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `A_Prof`, `A_Frz`                      | `admin_delete_account_data`: profile `FOR UPDATE`; `insert into private.account_deletions ... on conflict do nothing` (its FK check takes `KEY SHARE` on `auth.users`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `A_Mem`, `A_Lock`                      | the loop body: `v_memberships`; `private.lock_portfolios_for_deletion` (`order by p.id for update`, one row per step)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `A_Lock` (last step)                   | `admin_account_deletion_scope` read after the locks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `A_Purge`                              | `private.delete_locked_portfolios` after its audit-trail `DELETE` (`a_aud`), with `ON DELETE CASCADE` (members, invitation, lease), the user's other memberships, `private.after_portfolios_delete` (retire id), `after_owner_membership_ends`; COMMIT                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `a_aud`, `d_aud`                       | `delete_locked_portfolios`' first statement, `delete from audit_logs where portfolio_id = any (...)`: one audit row per step in any order (`RowStep`), before the portfolios' `DELETE`; a step of its own only where another transaction can hold one of its rows (a GoTrue delete of their actor)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `Detect` + `SubRelease`                | `exception when deadlock_detected`: roll back to the savepoint, retry, raise on the third deadlock; the profile lock, the `account_deletions` row and its `KEY SHARE` on `auth.users`, all taken before the loop, stay                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `G_*`, `RowStep`                       | `auth.admin.deleteUser`: `DELETE FROM auth.users` (`G_User`), then its FK actions in the order `GOTRUE_ORDER` names: profiles (cascade, `G_Prof`), `portfolios.created_by` (set null, `g_port`), `portfolio_members.user_id` (cascade, `g_mem`; an owner row queues `after_owner_membership_ends`), `portfolio_members.invited_by` (set null, `g_inv`), `leases.created_by` (set null, `g_lease`, standing for every child table's `created_by` and the like), `notifications.user_id` (cascade, `G_Note`, n1 then n2), `audit_logs.actor_id` (set null, `g_audit`), residence's `portfolios.caretaker_user_id` (set null, `g_care`). Each `SET NULL` or cascade locks its rows one by one in any order (`RowStep`: the plan and the heap decide it). `G_Commit` runs the second-level triggers (the revoke of `after_owner_membership_ends`, the residence row of the profile's cascade) and the `account_deletions` cascade, then COMMIT |
| `A_Failed`                             | the POST fails or its response is lost; the client retries (`MAX_POSTS`) or gives up                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `M_Auth`, `M_Lock`, `M_Do`, `M_Write`  | `remove_member` and `update_member_role` (latest): `private.lock_portfolio_for_change` (authorise, `for update`, authorise again), `member_not_found`, `last_owner`, the write with its triggers `portfolio_members_after_caretaker_ends`, `_after_owner_ends` and `_audit`, whose insert checks `actor_id`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `X_Act`, `X_PLock`, `X_Inv`, `X_Ins`   | `accept_invitation` (latest): `private.require_active_account`, portfolio `KEY SHARE`, invitation `FOR UPDATE`, the inviter-is-owner check, the member insert and its FK checks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `K_Act`, `K_Check`, `K_Ins`            | `create_portfolio` (latest): `require_active_account`, existing id, `private.portfolio_ids` lookup, the insert and trigger `portfolios_after_insert_register_id`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `D_Auth`, `D_Lock`, `D_Purge`          | `delete_portfolio` (latest), with the same retry loop                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `Y_*`                                  | `record_payment` via `private.lock_lease_for_write`: an in-order lease writer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `L_Set`, `L_PKS`                       | findings: the row policy `leases_update` gets its portfolios from `app.lock_my_portfolio_ids` in an initplan, which runs before the statement locks a row: the caller's owner/manager portfolios, `FOR KEY SHARE` in id order (one row per step), then authorised again                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `L_Upd`, `L_FK`                        | a client's plain `update leases set security_deposit` (granted in `20261103193403_leases.sql`): the policy lets through only rows of portfolios both locked and still authorised; the lease row lock; its trigger `private.after_lease_deposit_update` (`20261104143928`) inserts a charge, whose FK check takes the portfolio key (already held)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `I_Set`, `I_PKS`, `I_Chk`              | findings: a client INSERT (`occB`/`occBr` a lease occupant, `tenB` tenants of two portfolios): the policy's WITH CHECK gets its portfolios from `app.lock_my_portfolio_ids`, whose initplan runs at the first row's check, before any row is inserted or any foreign key checked; every row's portfolio must be locked and still authorised                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `I_FK`                                 | the rows' foreign-key checks, one AFTER ROW trigger per step in trigger-name order (`KEY SHARE` on the parent), then COMMIT. Migration order checks `portfolio_id` first (`occB`); a restored database checks `lease_occupants_lease_fkey` first (`occBr`); rows are checked in row order (`tenB`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `C_Auth`, `C_Lock`, `C_Do`             | residence: `set_caretaker`: authorise, the portfolio `FOR NO KEY UPDATE`, then the second authorisation and the named person's role (`member_not_found`, `caretaker_not_manager`), two statements merged (see the action); naming the caretaker again updates no row                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `C_Pre`, `C_Upd`                       | mutants only: `care_member_first` takes the named person's membership `FOR SHARE` before the portfolio (`C_Pre`); `no_care_lock` takes no portfolio lock first, so the UPDATE locks the row itself (`C_Upd`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `C_Trig`, `C_FK`                       | the UPDATE's trigger `private.before_portfolio_caretaker_change`: the membership `FOR SHARE`, which locks only a row whose version in its snapshot is a manager's (it then waits for a writer of the row and reads its newest version; `caretaker_not_manager`); then the foreign-key check of `caretaker_user_id` (`KEY SHARE` on `auth.users`), the audit row and COMMIT                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `O_Auth`, `O_Lock`, `O_Do`             | residence: `set_owner_abroad(q, r, p_if_unanswered)`, `true` as the app asks on the next open (`ansA`, `ansC`), `false` for a change on purpose (`chgA`, `chgC`): authorise (owner or manager), the answer read `FOR NO KEY UPDATE` in one statement, authorise again; the same answer, or with `p_if_unanswered` an answer already given, is returned and kept; `owner_abroad_answered` for a given answer unless the caller is an owner; else the write, its audit row and COMMIT (merged: Bounds)                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `R_Upd`, `R_Commit`                    | residence: the person's `update profile_residences` (policy `profile_residences_update_own`): the row lock, then the BEFORE trigger `before_profile_residence_client_update`, which refuses once the account's deletion has committed (`account_deleted`). Mutant `residence_check_before_lock`: `R_Chk` reads `account_deletions` before the row lock instead                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `A_Res`                                | residence: `admin_delete_account_data`'s last statement, the unfiltered `update profile_residences ... where user_id = u`, after the retry loop; merged into `A_Purge`'s COMMIT in scenarios where nobody else writes that row                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `S_Lock`, `S_Row`, `S_Trig`            | a service-role `UPDATE` or `DELETE` of a membership without a portfolio lock (an operator): the row lock, then `portfolio_members_after_caretaker_ends` at the end of the statement, which locks the portfolio row only if that person is its committed caretaker; COMMIT. `S_Lock` (`svcLockDemC`) is the operator's rule of `docs/operations.md`: the portfolio `FOR UPDATE` first                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `mSh`, `BMW`                           | `FOR SHARE` on member rows: every `UPDATE` or `DELETE` of a member row (the RPCs, the deletions' cascades, GoTrue, the service role) waits for its holders                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `aud`, `audX`, `InitAud`               | `public.audit_logs`: one row per portfolio and actor for each member (`create_portfolio`, `accept_invitation` and every audited write record `auth.uid()`) and each former member in `FormerAud`, kept where a GoTrue delete of the actor can meet a deletion of the portfolio; its writers there are GoTrue's `SET NULL` of `actor_id` and the deletions' audit-trail `DELETE`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `AuditCommit`                          | the audit row of `remove_member`, `update_member_role`, `set_caretaker` and `set_owner_abroad`: its `actor_id` check takes `KEY SHARE` on the caller's `auth.users` row, which only a GoTrue delete of the caller holds; a step of its own where one runs, merged into the write otherwise                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `M_Write`, `A_Purge` (residence)       | `portfolio_members_after_caretaker_ends` on the RPCs' and the account deletion's manager rows: it clears the caretaker under the portfolio lock they hold                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `N_Prof`, `N_PKS`, `N_Upd`, `N_Commit` | findings: `noteB` marks two notifications read (`n2`, then `n1`) under `notifications_update_own`, whose `app.lock_my_notification_portfolios` takes the account key (`profiles`, `KEY SHARE`), then the portfolios of the caller's notifications where they are a member, before the first row; each UPDATE locks its row (`NO KEY UPDATE`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

`SCENARIO` picks the processes and the initial rows (`ScenarioProcs`,
`Members`, `Inv`, `InitCare`, `InitInvitedBy`, `InitAud`). `MUTANT` removes one
mechanism; `no_client_key` is the code M1 was found in (the lease row first,
then the portfolio key), and `no_insert_key` the INSERT policies before this
fix. `WAKE_FIRST` and `GOTRUE_ORDER` are scheduling and environment
assumptions (see below). `GOTRUE_ORDER` is `portfolios_first` (a migrated
database: the constraints' creation order), `leases_first`,
`caretaker_first` (the caretaker's `SET NULL` first) or `restored` (a
`pg_dump` restore: by constraint name). The caretaker's constraint is the
newest, so its trigger name, `RI_ConstraintTrigger_a_<oid>` compared as
text, sorts last while the OIDs have as many digits as the others; once its
OID has one more, it can sort anywhere, depending on the leading digits. Its
position matters only relative to the membership cascade (`g_mem`): after
it, the delete holds the caretaker's membership when it needs the
portfolio, whatever else comes in between (D1 below); before it, it does
not. The steps before `g_mem` (`G_Prof`, `g_port`) lock nothing that the
other processes of the caretaker scenarios need (the caretaker created no
portfolio), so every position before `g_mem` acts like `caretaker_first` and
every position after it like `portfolios_first`. `docs/operations.md`
(After every migration) lists the hosted project's order with a read-only
`pg_trigger` query. A foreign-key action on a column that no process of a
scenario can set (no caretaker is ever named, nobody invited anyone, no
audit row a deletion can meet) is left out of that scenario's sequence
(`GUsed`): it would take no lock in any state.

## Properties

| Property                      | Plain language                                                                                                                                 | Broken by                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AtLeastOneOwner`             | Every portfolio that exists has an owner (TEAM-04).                                                                                            | `mut_scope_before_lock`, `mut_no_member_lock`, `mut_no_last_owner`, `mut_no_freeze_orphan`                                                                                                                                                                                                                                                                                                                                                                                                           |
| `NoMemberless`                | Every portfolio that exists has a member.                                                                                                      | `mut_scope_before_lock_memberless`                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `NoActivityAfterDeletion`     | Once `admin_delete_account_data(u)` has committed, `u` has no membership, and nothing commits a membership or portfolio for `u`.               | `mut_no_freeze`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `IdsNeverReused`              | A deleted portfolio's id never comes back.                                                                                                     | `mut_no_id_registry`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `NoWaitCycle`                 | No transaction waits, directly or through others, for itself.                                                                                  | `mut_unordered_locks`, `mut_no_client_key_cycle`, `mut_no_insert_key_cycle`, `mut_no_note_account_key`, `mut_care_member_first`; finding M2 (open): `finding_m2_dport_former`, `finding_m2_two_deletions`; documented behaviours `assume_gotrue_leases_first`, `assume_direct_auth_care*`, `assume_direct_auth_member`, `assume_direct_auth_demote`, `assume_direct_auth_leave`, `assume_direct_auth_dport_audit`, `assume_service_member_write`, `assume_restored_notes`, `assume_restored_inviter` |
| `DeletionNotDefeated`         | A deletion transaction never fails with `deadlock_detected`.                                                                                   | `mut_no_client_key`, `mut_no_client_key_acct` (finding M1); `mut_no_insert_key`, `mut_no_insert_key_rows` (client inserts); `mut_no_deadlock_retry`, `mut_no_deadlock_retry_acct` (GoTrue in the restored order, under `WAKE_FIRST`); finding M2 (open): `finding_m2_two_deletions_retry`; documented behaviour `assume_direct_auth_dport`                                                                                                                                                           |
| `AuthorisedAtCommit`          | Every committed membership change was authorised at commit time.                                                                               | `mut_no_recheck`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `DeletesOnlySoleOwned`        | An account deletion deletes a portfolio only while the user is its only owner.                                                                 | `mut_scope_before_lock_sole`                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `InviterAuthority`            | A member joins through an invitation only while its inviter is an owner.                                                                       | `mut_no_inviter_auth`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `CompletedDeletionsClean`     | After a successful delete-account POST the account is gone, without memberships, and what it deleted stays deleted.                            | `mut_no_id_registry_acct`                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `CaretakerIsManager`          | residence: a portfolio's caretaker is, in committed state, a member of it with the manager role.                                               | `mut_no_care_share` (a service-role demotion in flight), `mut_no_care_trigger` (demotion), `mut_no_care_trigger_remove` (removal), `mut_no_care_before_trigger` (the service role)                                                                                                                                                                                                                                                                                                                   |
| `CaretakerAuthorisedAtCommit` | residence: `set_caretaker` commits only while its caller is an owner.                                                                          | `mut_no_care_recheck`, `mut_no_care_lock`                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `AnswerAuthorisedAtCommit`    | residence: an answer is written only while its caller may give it: an owner or a manager while it is unanswered, an owner once it is answered. | `mut_no_abroad_recheck`, `mut_no_answered_guard` (`answer_change`)                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `FirstAnswerKept`             | residence: the question asked on the next open never overwrites an answer already given.                                                       | `mut_abroad_unlocked_read`, `mut_abroad_answered_overwritten`                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `ResidenceGoneAfterDeletion`  | residence: once an account's deletion has committed, the person's declared residence is cleared and stays so while the row exists.             | `mut_residence_filtered`, `mut_no_residence_refusal`, `mut_residence_check_before_lock`                                                                                                                                                                                                                                                                                                                                                                                                              |
| `AllFinish` (liveness)        | Every request finishes: waits end and deadlocks are resolved.                                                                                  | `mut_unbounded_retry`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `TypeOK`, `RefIntegrity`      | Sanity of the model (types; foreign keys hold in committed rows).                                                                              | none: `RefIntegrity` is enforced by PostgreSQL's foreign keys, which the model reproduces rather than the app code                                                                                                                                                                                                                                                                                                                                                                                   |

Nine mutants are expected to pass, and say so in their headers. They show
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
- `mut_no_care_rpc_role_check`: `set_caretaker`'s own read of the named
  person's role is redundant; the trigger reads it again, `FOR SHARE`, for
  every writer. The read gives the clearer error first.
- `mut_residence_first`: the deletion could clear the residence at its start
  instead of last. A person's residence `UPDATE` holds that row only, so
  taking it last follows the global order's convention but no cycle needs
  it.

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
in the scenarios `caretaker`, `caretaker_remove`, `caretaker_svc`,
`caretaker_svc_rule`, `caretaker_acct`, `caretaker_direct*`, `answer`,
`answer_change`, `residence`, `residence_team` and `inviter`. On the app's
own paths (the RPCs, a person's own residence write, `delete-account`'s
order on a migrated database) every interleaving keeps the five properties
below, the residence paths form no wait-for cycle and every request
finishes. No change to the SQL was needed for them. Finding M2 (below), on
the `delete-account` path, is older than this migration and does not depend
on it.

| Property                      | Kept by (code)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Assumption                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CaretakerIsManager`          | the trigger's `FOR SHARE` read of the membership after the portfolio row (a role change in flight, even by the service role, is waited for and its result read; on the app's paths `set_caretaker`'s own role read already refuses, so the trigger is needed only against the service role: `mut_no_care_before_trigger` fails `caretaker_svc` alone); `portfolio_members_after_caretaker_ends` on every end of a manager membership; the foreign key's `SET NULL` in GoTrue's own transaction | none: it holds against the service role and direct Auth deletes too (`caretaker_svc`, `caretaker_direct`, `caretaker_direct_rpc`, `caretaker_svc_rpc`)                                                                                                                                                                                                            |
| `CaretakerAuthorisedAtCommit` | the portfolio lock (`FOR NO KEY UPDATE`) and the second `require_portfolio_role` after it, against `lock_portfolio_for_change`'s `FOR UPDATE` (`mut_no_care_lock`, `mut_no_care_recheck`)                                                                                                                                                                                                                                                                                                      | whoever ends an owner's role holds the portfolio: the RPCs and the deletions do; the service role is out of scope, as for `AuthorisedAtCommit`                                                                                                                                                                                                                    |
| `AnswerAuthorisedAtCommit`    | the portfolio lock between two authorisations in `set_owner_abroad`; `owner_abroad_answered` once an answer is given (`answer_change`, `mut_no_answered_guard`)                                                                                                                                                                                                                                                                                                                                | the same, and `O_Do`'s merge (Bounds, below)                                                                                                                                                                                                                                                                                                                      |
| `FirstAnswerKept`             | the answer read `FOR NO KEY UPDATE` in the statement that takes the lock, and the early return of an answer already given (`mut_abroad_unlocked_read`, `mut_abroad_answered_overwritten`)                                                                                                                                                                                                                                                                                                      | none                                                                                                                                                                                                                                                                                                                                                              |
| `ResidenceGoneAfterDeletion`  | the deletion's residence `UPDATE` without a filter on the values (it waits for a write in flight and clears what it committed); the client trigger's `account_deleted` check, which runs after the row lock and so sees the committed deletion (`mut_residence_check_before_lock`); the freeze row committed with the clear                                                                                                                                                                    | the only writers of `profile_residences` are the person's own client `UPDATE` (one statement through PostgREST; the column grants, and the trigger's `when (current_user = 'authenticated')`) and `admin_delete_account_data`; the service role and other `SECURITY DEFINER` code, which the trigger never refuses, are out of scope, as for `AuthorisedAtCommit` |

The lock order of each new path, and why it keeps `NoWaitCycle`:

- `set_caretaker` and `set_owner_abroad` take the portfolio first
  (`FOR NO KEY UPDATE`), then (the caretaker) the membership `FOR SHARE`,
  the named person's `auth.users` key and the caller's (the audit row)
  last. Taking the membership first would form a cycle with
  `update_member_role` (`mut_care_member_first`).
- The membership RPCs and `admin_delete_account_data` already hold the
  portfolio when their trigger clears the caretaker.
- A person's residence `UPDATE` holds that row only; the deletion writes it
  last, after every portfolio and membership. Last is the global order's
  convention; no cycle needs it (`mut_residence_first` passes).
- `set_caretaker`'s own role read is redundant with the trigger's
  (`mut_no_care_rpc_role_check` passes); it gives the clearer error first.

Outside the app's own paths the model finds four lock-order behaviours.
They are documented as operator rules in `docs/operations.md`, "Deleting a
user account", and replayed on PostgreSQL 16 by `replay/residence.sh`. The
delete-account order (`admin_delete_account_data` first) and an operator who
locks the portfolio first avoid all of them on a migrated database, so no
SQL was changed for them:

- **D1**: a direct Auth delete of a manager against a change of that
  person's membership. Leaving (`remove_member` by that person) deadlocks
  whether or not they are the caretaker: the RPC holds the membership, and
  its audit row's `actor_id` check needs the person's `auth.users` key,
  which the delete holds while its cascade waits for that membership
  (`assume_direct_auth_leave`, R8; the caretaker leaving:
  `assume_direct_auth_care_leave`, R2 leave). The caretaker adds the cases
  where someone else calls the RPC: an owner's `update_member_role` or
  `remove_member` holds the portfolio; the delete's cascade takes the
  membership, then the caretaker's `SET NULL` needs the portfolio
  (`assume_direct_auth_member`, `assume_direct_auth_demote`; R2). Without
  the caretaker an owner's RPC forms no cycle (`direct_demote`, the R2 and
  R8 controls). With the caretaker's `SET NULL` first (`caretaker_first`)
  the owner's RPCs form none either (`caretaker_direct_rpc_first`).
  `set_caretaker` against a direct Auth delete of the person it names forms
  a cycle in any order: it needs that person's `auth.users` key last
  (`assume_direct_auth_care*`, R1). `caretaker_direct`,
  `caretaker_direct_first`, `caretaker_direct_rpc` and `direct_leave` check
  that once PostgreSQL breaks these cycles every other property holds.
- **D2**: a service-role `UPDATE` or `DELETE` of the caretaker's membership
  against those RPCs: the row, then the portfolio in its trigger
  (`assume_service_member_write`; R3). A row trigger cannot take the
  portfolio earlier: PostgreSQL locks the row before any row trigger runs.
  Locking the portfolio first in the operator's transaction avoids it
  (`caretaker_svc_rule`; R3 with the rule; scenario 31's
  `operator_locks_portfolio_first_*`); `caretaker_svc_rpc` checks the rest.
- **D3** (not new; the caretaker widens it): `delete_portfolio`, or the
  account deletion of the portfolio's only owner, against a direct Auth
  delete of a member. Every member has an audit row with themselves as
  actor (`create_portfolio` and `accept_invitation` record the caller). The
  deletion deletes the portfolio's audit trail before its cascade reaches
  the membership; the Auth delete takes the membership, then needs that
  audit row (`actor_id` `SET NULL`): `assume_direct_auth_dport_audit`, R4
  audit. For the caretaker, its `SET NULL` also needs the portfolio
  (`assume_direct_auth_dport`, R4 caretaker). The deletion's retry absorbs
  the cycle when PostgreSQL picks the deletion; when it picks the Auth
  delete, that fails (R4 shows both). Without `WAKE_FIRST` three cycles in a
  row can fail the deletion (`assume_direct_auth_dport`); with it they
  cannot (`caretaker_direct_dport_wake`, `direct_dport_wake`);
  `direct_dport` checks the rest.
- **P1** (not new; the residence paths join it): a restored database runs
  GoTrue's foreign-key actions by constraint name, so
  `portfolio_members.invited_by` comes before `portfolios.created_by` and the
  notifications before the profile. There even the delete-account order of a
  user who created a portfolio and invited a member deadlocks with
  `set_caretaker` or `update_member_role` of that member
  (`assume_restored_inviter`, against `inviter` on a migrated database; R6),
  and a direct Auth delete with marking notifications read
  (`assume_restored_notes`; R7). `docs/operations.md` restores the schema from
  the migrations, which keeps their order. The remedy of finding M2 would
  close its delete-account case for dumps too.

A `BEFORE DELETE` trigger on `auth.users` that cleared the caretaker first
(its portfolios in id order) was evaluated and not adopted. It runs the
caretaker's clearing before the membership cascade, as `caretaker_first`
does: it removes the owner's-RPC part of D1 (R2 with the trigger;
`caretaker_direct_rpc_first`) and the caretaker's part of D3
(`caretaker_direct_dport_first`), but not R1 (PostgreSQL locks the
`auth.users` row before the trigger runs; R1 with the trigger), not leaving
(the audit row's check) and not D3's audit row
(`assume_direct_auth_dport_audit`, which has no caretaker). Like the trigger
evaluated for the Invitations track's F3, it would also run inside GoTrue's
transaction, where an error fails the Auth delete. The choice is the
owner's.

The delete-account order itself (`admin_delete_account_data`, then GoTrue)
has none of D1 to D3 and P1 on a migrated database (`caretaker_acct`,
`inviter`; R5, and scenario 31's `naming_holds`, `deletion_holds` and
`demote_holds`: no deadlock). In `caretaker_acct` GoTrue finds no
membership and no caretaker of C left, in any order of its actions; the
caretaker-first order is checked where it finds them
(`caretaker_direct_rpc_first`, `caretaker_direct_first`).

## Finding M2: GoTrue's foreign-key actions after delete-account (open)

Severity: low. Older than the residence migration; found in its review. On
the app's own `delete-account` path, the Auth delete that follows
`admin_delete_account_data` can form a wait-for cycle with a deletion of a
portfolio the user once worked in. PostgreSQL aborts one side with 40P01.

By the time GoTrue deletes the user, `admin_delete_account_data` has
removed their memberships, but rows that name them stay: the portfolios
they created (`portfolios.created_by`), the members they invited
(`portfolio_members.invited_by`) and the invitations they sent or accepted,
the child rows they created, voided, received or uploaded (24 columns) and
their audit rows (`audit_logs.actor_id`): 30 foreign keys with
`ON DELETE SET NULL` in all, the caretaker's among them. GoTrue's `DELETE FROM auth.users` sets each to
NULL, one constraint after another in creation order (`replay/residence.sh`
prints it), and each statement locks its rows one by one in the order its
scan returns them, without the portfolio's lock first. A deletion of one of
those portfolios at the same moment (`delete_portfolio`, or a co-owner's
account deletion) locks the portfolio, deletes its audit trail, then
cascades to the child rows. Two shapes, each a failing configuration and a
replay:

- `finding_m2_dport_former` (R9): former manager C created a row of P1 (the
  lease in the model, a tenant in R9) and has an audit row there. GoTrue
  holds the row (`created_by` `SET NULL`) and needs C's audit row
  (`actor_id` `SET NULL`); `delete_portfolio(P1)` holds P1's audit trail
  and needs the row. Control: the owner created the row, no cycle.
- `finding_m2_two_deletions` (R10): A created P1 and P2 and co-owns them
  with B. GoTrue's `SET NULL` of `portfolios.created_by` locks them in heap
  order, B's `admin_delete_account_data` in id order. They differ once a
  non-HOT update has moved P1: `set_caretaker` changes an indexed column, so
  R10 finds P1 behind P2 after it. Control: no caretaker named, P1 before
  P2, no cycle.

When PostgreSQL picks GoTrue, the Auth user stays and `delete-account`
answers with an error; the app's retry runs both steps again
(`admin_delete_account_data` is idempotent) and they succeed. When it picks
the deletion, its retry runs; without `WAKE_FIRST` three cycles in a row
can fail it (`finding_m2_two_deletions_retry`), with it they cannot
(`two_deletions_wake`, `dport_former_wake`). Every other property holds
(`two_deletions`, `team`, `dport_former`), and every request finishes
(`two_deletions` and `dport_former` check `AllFinish`).

Why it was not seen before: the model took GoTrue's foreign-key actions as
profiles, `created_by`, the membership cascade, `invited_by`, one lease,
the notifications and the caretaker, each in one step for all its rows,
and had no audit rows. Now each action locks one row per step in any order
(`RowStep`), and the audit rows and the deletions' audit-trail `DELETE` are
modelled (`g_audit`, `a_aud`, `d_aud`). Other shapes of the same kind are
not modelled or replayed: the model has one child row per portfolio, and a
deletion's cascade is one step. Two rows of one table, or rows of two
tables, that the user created in portfolios one deletion removes may be
locked in a different order by GoTrue and by the cascade.

The remedy is the owner's decision, recorded in `docs/operations.md` and
`.planning/STATE.md`: `admin_delete_account_data` sets every column that
names the user to NULL under portfolio locks taken in id order (the
portfolios they belong to, and those they created or acted in and no longer
belong to), so that GoTrue's actions find nothing to lock. That covers
every shape above and P1's delete-account case, but it writes 29 columns in
20 tables (each write audited) and takes more portfolio locks, so it is not
part of this change. Moving the audit-trail `DELETE` after the cascade in
`delete_locked_portfolios` would remove the first shape only, on a
migrated database, and add it on a restored one (GoTrue's order by name
sets `audit_logs.actor_id` first); it was not done alone. Until then the
detector and the retries resolve it as above.

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
  (`assume_gotrue_leases_first_wake`). This is one of the cycles the retry
  still exists for (finding M2 is the other), so the retry's mutants (`mut_no_deadlock_retry*`,
  `mut_unbounded_retry`) run against it. `leases_first` moves only `leases`;
  the whole restored order is `restored` (`assume_restored_setnull` passes
  under `WAKE_FIRST`).
- `assume_direct_auth_care`, `assume_direct_auth_care_first`: a direct Auth
  delete of the manager being named (R1); `caretaker_direct` and
  `caretaker_direct_first` check that the cycle is resolved and the other
  properties kept.
- `assume_direct_auth_member`, `assume_direct_auth_demote`,
  `assume_direct_auth_care_leave`, `assume_direct_auth_leave`: a direct Auth
  delete of a manager whose membership changes (D1); `caretaker_direct_rpc`
  and `direct_leave` check the rest, `direct_demote` and
  `caretaker_direct_rpc_first` that no cycle forms without the caretaker or
  with its `SET NULL` first.
- `assume_direct_auth_dport`, `assume_direct_auth_dport_audit`: a direct
  Auth delete of a member while the portfolio is deleted (D3);
  `caretaker_direct_dport_wake`, `direct_dport` and `direct_dport_wake`
  check the rest, `caretaker_direct_dport_first` that the caretaker's part
  goes with its `SET NULL` first.
- `assume_service_member_write`: a service-role change of the caretaker's
  membership (D2); `caretaker_svc_rpc` checks the rest, `caretaker_svc_rule`
  the operator's rule.
- `assume_restored_notes`, `assume_restored_inviter`: a restored database's
  foreign-key order (P1).

## Bounds, abstractions and why they are adequate

- Three users, three portfolio ids, one invitation and one lease per
  portfolio, and one audit row per portfolio and actor. Every rule in this
  code relates one user, one portfolio and one other row (a co-owner, an
  invitation, a lease). Each scenario puts two to four requests on the same
  rows, which is where the races are. Any interleaving of more requests on
  more rows is made of these pairwise conflicts, because there is one global
  lock order (account → portfolio → lease → other rows), and the order
  breakers are covered explicitly: the deposit trigger, and GoTrue's FK
  actions, whose 24 child-table columns the lease's `created_by` stands for.
  That is why finding M2's shapes with several child rows are not shown.
- A deletion's cascade (the members, the invitation and the lease of every
  portfolio it deletes) is one step: it waits until no other transaction
  holds any of those rows. Only GoTrue locks such rows without the
  portfolio's lock first; the order this hides between them is part of
  finding M2.
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
  one step (`O_Do`), and so are `set_caretaker`'s second authorisation and
  its read of the named person's role (`C_Do`). While the caller holds the
  portfolio, no membership change by an RPC or a deletion and no other
  answer can commit. A service-role or GoTrue write of the caller's
  membership could (they take no portfolio lock); an `ASSUME` checks that no
  scenario has one, since the merge would hide the stale authorisation such
  a write can cause, which is out of scope as for `AuthorisedAtCommit`. The
  role read in `C_Do` is a plain read, which the trigger repeats `FOR SHARE`
  before anything is written.
- GoTrue's `SET NULL` of the caretaker (`g_care`) is merged with
  `portfolio_members_after_caretaker_ends` of the cascaded membership, which
  runs after every first-level action and finds the column already NULL.
  Between the two nobody can name the person again: `set_caretaker`'s
  foreign-key check needs `KEY SHARE` on their `auth.users` row, which the
  `DELETE` holds until it commits.
- The audit rows' foreign-key check of `actor_id` (`KEY SHARE` on the
  caller's `auth.users` row) is a step of its own (`AuditCommit`) only where
  a GoTrue delete of the caller runs, the only transaction that holds that
  row against it. `create_portfolio`'s `p_owner_abroad` and the empty
  residence row that `profiles`' AFTER INSERT trigger adds are inserts
  nobody else sees until they commit.
- `portfolio_members.invited_by` is derived rather than stored
  (`InvitedBy`): the initial rows of `inviter`, and the rows
  `accept_invitation` inserts (an `ASSUME` checks no other process inserts
  them). GoTrue's `SET NULL` of it is a row lock on each row (`g_inv`).
- The service role changes one membership per statement and commits
  (`S_*`), as an operator in the SQL editor does.
- `ReleaseAll` and `CommitDB` take the state through `Once`, a bound
  variable: TLC evaluates an operator's argument again at each use, and they
  use it dozens of times. The result is the same; `two_deletions` went from
  8.9 s to 6.4 s.

## How to run

```sh
formal/tla/Membership/run.sh ci     # 71 configurations, under 2 minutes
formal/tla/Membership/run.sh all    # 106 configurations, about 6 minutes
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

`replay/residence.sh` replays the behaviours above (R1 to R8, and finding
M2 as R9 and R10) on `mm_fv_residence`, built with `tool/db/reset.sh`, and
on `mm_fv_residence_restored`, a `pg_dump | psql` copy of it, and prints
GoTrue's foreign-key order in each. Each race is ordered with `fv.hold`
gates, so its cycle forms every time; which session PostgreSQL aborts is
only reported. It fails if a documented cycle does not form (R1, also with
the alternative trigger; R2; R3 without the rule; R4 with the caretaker and
with the audit row; R6 and R7 on the copy; R8, R9 and R10), or if the
delete-account order (R5), R2 with the alternative trigger, R3 with the
operator's rule, R6 and R7 on the migrated database, or the controls of
R2, R4, R8, R9 and R10 deadlock. `ROUNDS` repeats R1 to R4.

## Expected results

Measured on 2026-11-13 after the residence migration's review round, on a
4-CPU machine with little else running, 2 jobs × 1 worker (as CI runs it):

- `run.sh ci`: 71/71 as expected in 84 and 100 s wall (two runs). The
  largest is `two_deletions` (60,078 distinct states, 29 to 34 s); it had
  8,902 before GoTrue's actions locked one row per step.
- `run.sh all`: 106/106 as expected in 367 s wall. The largest are `team`
  (1,113,305 distinct states, 261 s), `two_deletions` and `residence_team`
  (9,120, 30 s, most of it the liveness check).
- Expected violations: the documented behaviours (every `assume_*`
  configuration except the two that pass under `WAKE_FIRST`,
  `assume_gotrue_leases_first_wake` and `assume_restored_setnull`), finding
  M2 (`finding_m2_*`), and every `mut_*` configuration except the nine named
  above (`mut_no_client_key*` reproduce finding M1 with the fix removed,
  `mut_no_insert_key*` the client inserts).
- `replay/residence.sh` on PostgreSQL 16.15: every outcome as expected in
  76 s. A deadlock in R1 (also with the alternative trigger), R2, R3 without
  the rule, R4 (with the caretaker, and with the audit row only), R6 and R7
  backward on the copy, R8, R9 and R10; none in R2 with the trigger, R3
  with the rule, R5, R6 and R7 on the migrated database, and the controls
  of R2, R4, R8, R9 and R10.

## Cross-check with `tool/db/concurrency_test.sh`

| Scenario there                                                                                            | Here                                                                                                                                       |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 7 removed owner changes a role                                                                            | `stale_owner`; `mut_no_recheck`                                                                                                            |
| 8 co-owners delete their accounts at once                                                                 | `two_deletions`, `double_post`; `mut_scope_before_lock`, `mut_unordered_locks`                                                             |
| 9 portfolios deleted while leases are written                                                             | in part: `payA` (an in-order lease writer) in `gotrue_setnull`; the daily job is not modelled                                              |
| 10 invitation accepted while the portfolio is deleted                                                     | `accept_delete`                                                                                                                            |
| 11 child rows and a billing sync racing a deletion                                                        | in part: the in-order writers follow the same pattern as `payA` and `depoB` (M1, now in order)                                             |
| 14 joining or creating while the account is deleted                                                       | `freeze`, `freeze_orphan`; `mut_no_freeze*`                                                                                                |
| 16 a deleted portfolio's id claimed during the deletion                                                   | `id_reuse`, `acct_reuse`; `mut_no_id_registry*`                                                                                            |
| 17 auth user deleted while a co-owner deletes the portfolio                                               | `gotrue_setnull`; `assume_gotrue_leases_first*`, `assume_restored_setnull`                                                                 |
| The invariants step: no portfolio without an owner or members                                             | `AtLeastOneOwner`, `NoMemberless` in every configuration                                                                                   |
| 19 M1: deposits changed while the portfolio or the owner's account is deleted                             | `deposit`, `deposit_acct`; `mut_no_client_key*`                                                                                            |
| 22 (inserts) and 26 (inserts): rows of two portfolios; a restored database                                | `insert_rows`, `insert`; `mut_no_insert_key*`                                                                                              |
| 23 notifications marked read while GoTrue deletes the user                                                | `notes`; `mut_no_note_account_key`; on a restored database `assume_restored_notes` (`replay/residence.sh`, R7)                             |
| 20, 21, 22 (updates), 23 (by `admin_delete_account_data`), 26 (updates, deletes), 27: other client writes | not modelled here (one lease per portfolio, no FK parents); 27 is the helper's re-authorisation, `DepoAuth` here                           |
| 31 `owner_demotes`, `naming_then_owner_demotes`, `namer_removed`                                          | `caretaker`; `mut_no_care_recheck`, `mut_no_care_trigger`, `mut_care_member_first`, `mut_no_care_lock`                                     |
| 31 `owner_removes`, `naming_then_owner_removes`                                                           | `caretaker_remove`; `mut_no_care_trigger_remove`                                                                                           |
| 31 `service_demotes`, `service_removes` and their `naming_then_` cases                                    | `caretaker_svc`; `mut_no_care_share`, `mut_no_care_before_trigger`                                                                         |
| 31 `owner_answers_first`, `manager_answers_first`, `answerer_demoted`                                     | `answer`, `answer_change`; `mut_no_abroad_recheck`, `mut_abroad_unlocked_read`, `mut_abroad_answered_overwritten`, `mut_no_answered_guard` |
| 31 `residence_then_deletion`, `deletion_then_residence` and the later write                               | `residence`, `residence_team`; `mut_residence_filtered`, `mut_no_residence_refusal`, `mut_residence_check_before_lock`                     |
| 31 `naming_holds`, `deletion_holds`, `demote_holds` (the caretaker's account deleted)                     | `caretaker_acct` (`replay/residence.sh`, R5)                                                                                               |
| 31 `operator_locks_portfolio_first_*`                                                                     | `caretaker_svc_rule`, the rule that avoids `assume_service_member_write` (`replay/residence.sh`, R3)                                       |

Scenario 31 fails on five mutants of the migration, and each has a model
mutant that fails too: the caretaker trigger without `FOR SHARE`
(`mut_no_care_share`), `set_caretaker` without its second role check
(`mut_no_care_recheck`), `set_owner_abroad` without its second
(`mut_no_abroad_recheck`), the answer read without its lock
(`mut_abroad_unlocked_read`) and the residence clear filtered on its values
(`mut_residence_filtered`). `answer_change` follows pgTAP suite 22's
`owner_abroad_answered` cases, and finding M2 has no scenario there, only
the replays R9 and R10.

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
  `goC` a manager, in some scenarios the caretaker (D1, D3).
- Finding M2's shapes with several child rows (see there), and GoTrue's
  `SET NULL` of `portfolio_invitations.invited_by` and `.accepted_by`: by the
  time GoTrue runs, `admin_delete_account_data` has revoked the user's
  pending invitations (`../Invitations` models them).
- `admin_delete_account_data`'s notification delete (run against
  PostgreSQL by `concurrency_test.sh` scenario 23), the preview (`GET`),
  rate limits, re-authentication and MFA checks of `delete-account`.
- Timing: the model has no clocks; `WAKE_FIRST` stands in for a scheduling
  assumption such as a backoff before the retry.
