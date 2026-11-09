# Portfolio invitations: TLA+ model

A TLC model of how portfolio invitations are created, revoked, accepted and
voided while portfolios, memberships and accounts change at the same time.
It follows the code as it is now: the last definition of every function,
trigger and index in `supabase/migrations/*.sql`, and the `invite-member` and
`delete-account` Edge Functions.

The model checks that no interleaving of the modelled calls breaks the
invitation rules. It also checks that no call fails with an unexpected
database error. Every safety rule has at least one mutant: the code with a
mechanism removed, which TLC must catch.

Results in short:

- Every property holds for the current code on the app's own paths, the
  error and response properties included.
- Four findings, all of low severity. F1, F2 and F4 are fixed in
  `supabase/migrations/20261108082804_invitation_findings.sql`: their
  configurations now pass, and a mutant that restores the old code fails
  each one. F3 (a deadlock when an inviter is deleted directly in Auth) is
  open, with an operational rule (`docs/operations.md`, "Deleting a user
  account") whose order the model checks. `replay_findings.sh` checks all
  four on a real database; it passes on PostgreSQL 16.15 and 17.11.
- The two old findings of the earlier model (deadlock of an accept with a
  portfolio deletion, and 40P01/23503 of a create with a deletion) are fixed
  by the current code. Their configurations pass.

## Files

| File                 | What it is                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| `Invitations.tla`    | The model. Every action cites the SQL or TypeScript it follows.                                |
| `Invitations*.cfg`   | 60 configurations. The header of each states its expected result and its mode (`ci` or `all`). |
| `run.sh`             | Runs TLC on the configurations and compares each result with the expected one.                 |
| `trace.py`           | Shortens a TLC counterexample to one line per step.                                            |
| `replay_findings.sh` | Checks findings F1 to F4 on a real database (optional; needs the `tool/db` test server).       |

## How to run

```sh
formal/tla/Invitations/run.sh ci     # fast set, must be green (about 3 minutes)
formal/tla/Invitations/run.sh all    # every configuration (about 20 minutes)
formal/tla/Invitations/run.sh Invitations_current_create_race   # one or more by name
```

`run.sh` works from any directory. It needs Java (tested with OpenJDK 21) and TLC 2.19
(`tla2tools.jar`), which `tool/formal/install.sh` installs. Set `TLA2TOOLS` to another jar
(the default comes from `.cache/formal/env.sh`), `JAVA` to another `java`, `TLC_WORKERS` (default 2) and
`TLC_HEAP` (default `2g`). Scratch files go to a fresh directory under
`${TMPDIR:-/tmp}`; nothing is written next to the model.

A configuration matches when TLC exits 0 with "No error has been found" (for
`Expected result: PASS`), or exits 12 with exactly the named invariant violated
(for `Expected result: FAIL -- Invariant X is violated.`). Anything else is a
mismatch: another invariant, a deadlock, a parse error or a crash. One mismatch
fails the run.

To read a counterexample:

```sh
python3 formal/tla/Invitations/trace.py < <log printed by run.sh>
```

To check the findings on PostgreSQL (uses its own database,
`mm_fv_invitations` or `MM_FV_DB`, on the server of `tool/db/env.sh`):

```sh
formal/tla/Invitations/replay_findings.sh
```

## What is modelled

One portfolio P and one invited e-mail `e`. Users: `o1` and `o2` own P (with
`SoleOwner`, `o2` is a manager); `u` is the invitee with the verified e-mail
`e`; `x` is verified with another e-mail; `y` claims `e` but is not verified.
Attackers hold a valid token (the worst case). Each process is one RPC call,
that is one PostgreSQL transaction.

"M5" is `supabase/migrations/20261105072426_membership_deletion_storage.sql`,
"M6" is `20261108082804_invitation_findings.sql` (the last definitions of
`create_invitation`, `accept_invitation` and
`private.after_owner_membership_ends`), "M1" is
`20261103192722_identity_portfolios.sql`, "M4" is
`20261103194402_notifications_audit.sql`.

| Model element                                      | Code                                                                                                                                                                                                                                                  |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1, C2: `CBegin` .. `CCommit`                      | `supabase/functions/invite-member/handler.ts` `inviteMember` (calls the RPC as the caller; the token is returned only after commit), M6 `public.create_invitation`                                                                                    |
| `CLockP`                                           | M5 `private.lock_portfolio_for_change(P, ['owner'], false)`: role check, `for key share`, role check again                                                                                                                                            |
| `CLockE`                                           | M6 `create_invitation`: `pg_advisory_xact_lock` on (portfolio, e-mail) (F1)                                                                                                                                                                           |
| `CMember`, `CSnap`, `CRevoke`                      | M6 `create_invitation`: `already_member` check, `update ... set revoked_at` of the pending invitation                                                                                                                                                 |
| `CInsert`, `CFk`                                   | M6 `create_invitation` insert; M1 `portfolio_invitations_pending_email_key`; FK checks on `portfolio_id` and `invited_by`                                                                                                                             |
| R1, R2: `RBegin` .. `RCommit`                      | M5 `public.revoke_invitation`                                                                                                                                                                                                                         |
| D1, D2: `DBegin` .. `DCommit`                      | M5 `public.delete_portfolio`, `private.lock_portfolios_for_deletion`, `private.require_portfolio_name`, `private.delete_locked_portfolios`; M1 `ON DELETE CASCADE` of memberships and invitations                                                     |
| MD, MP, MR, ML, MU: `MBegin`, `MChange`, `MCommit` | M5 `public.update_member_role` (demote, promote), `public.remove_member` (remove, leave; MU removes the invitee `u`), via `lock_portfolio_for_change(..., true)`                                                                                      |
| `MChange`, `XLockP`, `GTrig` with `MTRevoke`       | M5 trigger `portfolio_members_after_owner_ends`, M6 function `private.after_owner_membership_ends` (also revokes pending invitations whose inviter is NULL)                                                                                           |
| ADU, ADO: `XBegin`, `XLockP`, `XCommit`            | M5 `public.admin_delete_account_data` (called by `supabase/functions/delete-account/handler.ts` `deleteAccount`)                                                                                                                                      |
| AU1..AU3, AX, AY: `ABegin` .. `ACommit`            | M6 `public.accept_invitation`                                                                                                                                                                                                                         |
| `AAcct`                                            | M5 `private.require_active_account` (profile `for key share`, then `account_deleted`)                                                                                                                                                                 |
| `ALockP`, `ALock`                                  | M6 `accept_invitation`: portfolio key, `select ... for update`, then the status checks in code order, including the inviter check that records `revoked_at` (`AVoid`)                                                                                 |
| `AMember`, `AInsert`, `AFk`, `AUpdate`             | M6 `accept_invitation`: membership insert (M1 `portfolio_members` primary key, FKs), `accepted_at` update (M1 terminal-state CHECK)                                                                                                                   |
| `ATrigger`                                         | M4 trigger `portfolio_invitations_after_accept`, function `private.after_invitation_accepted` (notification inserts and their FK checks)                                                                                                              |
| GA, GO: `GBegin` .. `GCommit`                      | GoTrue deleting `o1`'s `auth.users` row: the M1 `ON DELETE` actions in trigger-name order, then the queued membership trigger. GA runs only after ADO succeeded (the order of `deleteAccount`); GO is a direct deletion (dashboard or Auth admin API) |
| `EnvAbort`                                         | client disconnect, `statement_timeout`, HTTP 429                                                                                                                                                                                                      |
| `DeadlockVictim`                                   | PostgreSQL's deadlock detector (40P01)                                                                                                                                                                                                                |
| `Tick`                                             | time passing; expiry is `now() + interval '7 days'` against the transaction's `now()`                                                                                                                                                                 |

PostgreSQL semantics in the model: READ COMMITTED with one snapshot per
statement; row locks held to the end of the transaction; the lock-mode table
for `FOR KEY SHARE`, `FOR NO KEY UPDATE` and `FOR UPDATE`; a blocked
`UPDATE`/`DELETE` re-reads the newest committed row (EvalPlanQual) but scans
only the rows of its snapshot; unique checks wait for in-progress inserters;
FK checks run at the end of the statement and take key share on the parent
row; any raised error aborts the whole transaction, while `accept_invitation`
returns its statuses and commits.

## Properties

Invariant names are in brackets.

1. An invitation is accepted at most once (`AcceptedAtMostOnce`).
2. Only a user whose verified e-mail is the invited e-mail accepts it, and
   nobody else ever becomes a member (`AcceptedOnlyByInvitee`,
   `OnlyInviteesJoin`).
3. It is never accepted once revoked, nor at or after its expiry
   (`NeverAcceptedAfterRevoke`, `NeverAcceptedAfterExpiry`).
4. The role granted never exceeds what the inviter could grant at the moment
   the acceptance commits. Owners may grant every role; nobody else may grant
   any (`RoleWithinInviterAuthority`).
5. Once the inviter stops being an owner, none of their invitations that was
   not yet accepted is ever accepted, even if they become an owner again
   (`InviterLossVoidsInvitations`). No pending invitation of a non-owner is
   left behind (`NoPendingInvitationFromNonOwner`). Once `accept_invitation`
   has answered `revoked` for an invitation not yet accepted, it stays void
   (`RevokedResponseIsFinal`). A retry of an accepted invitation by a former
   member is answered `revoked` too (F2); that answer is about the
   membership, so it does not count here.
6. At most one pending invitation per (portfolio, e-mail)
   (`AtMostOnePendingInvitation`, and the weaker `AtMostOneLiveInvitation`).
7. No membership exists for an account whose deletion has committed
   (`NoMembershipForDeletedAccount`).
8. A deleted portfolio keeps no invitation and no membership
   (`DeletedPortfolioIsEmpty`).
9. Accepting never changes an existing member's role, and a new membership
   has exactly the invitation's role (`AcceptNeverChangesRole`,
   `GrantedRoleIsInvitationRole`).
10. Owners are notified exactly once per accepted invitation
    (`OwnersNotifiedOncePerAcceptance`).
11. No call fails with an unexpected database error: 23505, 23503, 23514 or
    40P01 (`AcceptNeverFailsUnexpectedly`, `CreateNeverFailsUnexpectedly`,
    `NoRpcFailsUnexpectedly`). The app's own errors (`forbidden`,
    `already_member`, `account_deleted`, ...) and environmental aborts are
    expected.
12. A successful accept reports the role the caller really has
    (`AcceptReportsActualRole`); a caller who is no longer a member is never
    answered `accepted`.
13. Cross-checks with `tool/db/concurrency_test.sh`, which passes on the
    current code (run on 2026-11-05: exit 0 in 98 s): scenario 10 (an accept
    racing a portfolio deletion ends `accepted` or `invalid`) and scenario 14
    (an accept racing the account's deletion ends `accepted` or
    `account_deleted`) (`AcceptOutcomesVsDeletion`,
    `AcceptOutcomesVsAccountDeletion`).

Deadlocks between modelled calls fall under property 11. TLC's own deadlock
check stays on, so a call stuck forever would also be reported.

## Results

Measured on 2026-11-08, after the fixes of M6 and the review's F2 change,
with 2 TLC workers on a 4-CPU machine (load average about 3):

- `run.sh ci`: 55/55 configurations as expected in 106 s.
- `run.sh all`: 60/60 configurations as expected in 1,051 s. The largest are
  `Invitations` (2,580,967 distinct states, 249 s; it now includes what
  `Invitations_current_safety` checked), `Invitations_pairs` (1,652,480,
  141 s), `Invitations_current_members_large` (1,483,096, 178 s) and
  `Invitations_gotrue_direct_large` (995,391, 92 s). The random simulation
  `Invitations_sim_large` takes 280 s.
- With `num=`, TLC 2.19 ends a simulation with "Finished in" and no "No
  error has been found"; `run.sh` takes exit 0, "Finished in" and no `Error`
  line as a simulation's pass.

## Findings

All four are of low severity: no safety property is broken. F1, F2 and F4
are fixed in `supabase/migrations/20261108082804_invitation_findings.sql`
(M6); F3 is open, with an operational rule.

### F1. Concurrent re-invites of one e-mail: the second fails with 23505

Fixed in `20261108082804_invitation_findings.sql`.

Configuration before the fix: `Invitations_mutant_no_create_serialise.cfg`
(fails `CreateNeverFailsUnexpectedly`). Shortened counterexample (13 states):

1. C1 (o1) and C2 (o2) both pass `lock_portfolio_for_change`. Key share on P
   does not exclude another key share.
2. Both pass `already_member`. Both take their `update ... set revoked_at`
   snapshot: no pending invitation yet.
3. C1 inserts invitation 1 and commits.
4. C2 inserts: `portfolio_invitations_pending_email_key` finds invitation 1
   committed and pending. 23505. `invite-member` answered HTTP 409 "This
   already exists", although a create normally replaces the pending
   invitation.

Fix (`CLockE`): in `create_invitation`, after `lock_portfolio_for_change` and
the input checks, a transaction advisory lock on the pair:

```sql
perform pg_advisory_xact_lock(
  ('x' || encode(substr(sha256(convert_to('invitation:' || p_portfolio_id::text || ':' || v_email, 'UTF8')), 1, 8), 'hex'))::bit(64)::bigint
);
```

The key is the first 64 bits of a SHA-256, not `hashtextextended()`: the
owner chooses the e-mail, and PostgreSQL's text hash is not built to resist
chosen collisions, so an owner could otherwise aim at another portfolio's key
or at `run_daily_jobs`' key, which share the one-bigint lock space. It sits
after the portfolio in the global lock order and only creates take it. The second create waits there, then sees the first one's invitation and
replaces it: both calls succeed and no new refusal code is needed.
`Invitations_current_create_race.cfg`, `Invitations_current_create_race_accept.cfg`
and `Invitations.cfg` pass. `replay_findings.sh` and scenario 30 of
`tool/db/concurrency_test.sh` check it on PostgreSQL 16.15 (both creates
succeed, one invitation stays pending, no 23505).

### F2. A retried accept can report a role the member does not have

Fixed in `20261108082804_invitation_findings.sql`.

Configuration before the fix: `Invitations_mutant_stale_response_role.cfg`
(fails `AcceptReportsActualRole`). Shortened counterexample (30 states):

1. Invitation 1 (manager, by o1) is pending. C2 (o2) re-invites the e-mail as
   viewer and passes `already_member`: u is not a member yet.
2. AU1 (u) accepts invitation 1 and commits: u is a manager.
3. C2 skips invitation 1 (accepted) and inserts invitation 2 (viewer).
4. AU2 (u) accepts invitation 2: u is already a member, so no insert; the
   answer is `manager`, which is right.
5. AU3 (u) retries invitation 2: the "already accepted by me" branch answered
   `accepted` with `v_invitation.role` = `viewer`. u is a manager.

Fix: that branch returns the caller's current role in the portfolio. A
caller who is no longer a member (removed, or left, since accepting) holds
no role, so the branch answers `revoked`, an existing status (the app shows
"This invitation was cancelled. Ask an owner of the portfolio for a new
one."); it writes nothing, and the invitation stays accepted.
`Invitations_current_response_role.cfg`, `Invitations.cfg` and
`Invitations_current_response_role_removed.cfg` (the invitee accepts, `MU`
removes them, retries arrive) pass. The first version of the fix fell back
to the invitation's role for a former member; the mutant
`removed_response_role` restores that and fails `AcceptReportsActualRole`
in 18 states. `replay_findings.sh` and
`supabase/tests/database/18_invitation_findings.test.sql` check both cases
on PostgreSQL.

### F3. Deleting an inviter directly in Auth can deadlock with an accept

Open. Rule: delete accounts through `delete-account`, or run
`admin_delete_account_data` before deleting a user by hand
(`docs/operations.md`, "Deleting a user account").

Configuration: `Invitations_gotrue_direct.cfg` (fails
`NoRpcFailsUnexpectedly`). This is the path where an operator deletes the
user in the Supabase dashboard or through the Auth admin API, without
`admin_delete_account_data` first. Shortened counterexample (12 states):

1. GO deletes o1's `auth.users` row (row lock), then its `ON DELETE CASCADE`
   removes o1's membership. The membership trigger is queued.
2. AU1 (u) takes the profile and portfolio keys and `for update` on o1's
   invitation. The inviter check still sees o1's committed owner row.
3. AU1 inserts the membership. The FK check on `invited_by` needs key share on
   o1's `auth.users` row: it waits for GO.
4. GO's `ON DELETE SET NULL` of `portfolio_invitations.invited_by` needs the
   invitation row: it waits for AU1.
5. Cycle: 40P01. A create by o1 can likewise fail with 23503 or 40P01.

`replay_findings.sh` still reproduces it on PostgreSQL 16.15 (the user
deletion is aborted with 40P01 while it updates the invitation row). `Invitations_gotrue_direct_safety.cfg` and
`Invitations_gotrue_direct_large.cfg` show that every safety property holds
on this path. The app's own path does not have the problem:
`Invitations_gotrue_via_delete_account.cfg` (GoTrue's deletion only after
`admin_delete_account_data` succeeded, as `deleteAccount` does) passes with no
unexpected error, and so does the replay of the same interleaving in that
order.

Rejected alternative: a `BEFORE DELETE` trigger on `auth.users` that runs
`admin_delete_account_data`. PostgreSQL locks the row before a `BEFORE ROW`
trigger runs (checked: the trigger body started only after a concurrent
`for key share` on the row ended), so the trigger would lock the account and
the portfolio after the `auth.users` row, the reverse of every insert whose
FK check takes that row last. With such a trigger the replay's interleaving
still deadlocked (two deadlocks per run: the trigger's retry, then the
accept failed with 40P01); `replay_findings.sh` keeps that check. Running it
twice (delete-account, then GoTrue's delete) was harmless, so the trigger
failed only on the lock order.

### F4. Deleting an inviter directly in Auth leaves their invitation pending

Fixed in `20261108082804_invitation_findings.sql`.

Configuration before the fix: `Invitations_mutant_no_null_inviter_revoke.cfg`
(fails `NoPendingInvitationFromNonOwner`). Shortened counterexample (8 states):

1. GO deletes o1's `auth.users` row. The cascade deletes o1's owner
   membership and queues `portfolio_members_after_owner_ends`.
2. The next `ON DELETE` action sets `invited_by` to NULL on o1's invitations.
3. The queued trigger fires only now. Its `invited_by = old.user_id` matches
   nothing. The invitation stayed pending, with no inviter, and was still
   listed to the owners.

`accept_invitation` refused it anyway: its `invited_by is null` branch
revokes it and answers `revoked`.

Fix: `private.after_owner_membership_ends` also revokes the portfolio's
pending invitations whose inviter is NULL:

```sql
and (i.invited_by = old.user_id or i.invited_by is null)
```

`accept_invitation` refuses such invitations anyway, so nothing valid is lost.
The migration also revokes, once, the pending invitations that
`accept_invitation` would refuse (no inviter, or one who is no longer an
owner). `Invitations_gotrue_direct_pending.cfg`,
`Invitations_gotrue_direct_safety.cfg`, `Invitations_gotrue_direct_revoke.cfg`
and `Invitations_gotrue_direct_large.cfg` now check
`NoPendingInvitationFromNonOwner` and pass. With the fix, the trigger is a
second protection on the direct-deletion path:
`Invitations_mutant_no_inviter_check_gotrue_backstop.cfg` passes, and only
removing both (`no_inviter_check_no_null_revoke`) lets the invitation be
accepted.

## Mutants (non-vacuity)

Each mutant removes one mechanism of the current code (or two, where each
alone is backed up by the other). Each row is a configuration that must fail
with the named invariant, or pass where it says "backstop".

| Mutant (`MUTANT`)                 | Mechanism removed                                                                    | Configuration                                                                  | Expected                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `no_for_update`                   | `for update` in `accept_invitation`                                                  | `mutant_no_for_update`                                                         | `AcceptedAtMostOnce`                                                                                                           |
| `no_used_check`                   | `accepted_at` check                                                                  | `mutant_no_used_check`                                                         | `AcceptedAtMostOnce`                                                                                                           |
| `no_verified_check`               | `email_confirmed_at` check                                                           | `mutant_no_verified_check`                                                     | `AcceptedOnlyByInvitee`                                                                                                        |
| `no_email_check`                  | e-mail equality check                                                                | `mutant_no_email_check`, `mutant_no_email_check_join`                          | `AcceptedOnlyByInvitee`, `OnlyInviteesJoin`                                                                                    |
| `no_expiry_check`                 | `expires_at <= now()` check                                                          | `mutant_no_expiry_check`                                                       | `NeverAcceptedAfterExpiry`                                                                                                     |
| `no_revoked_check`                | `revoked_at` check                                                                   | `mutant_no_revoked_check` / `_backstop`                                        | `AcceptNeverFailsUnexpectedly` (23514) / backstop: still never accepted                                                        |
| `no_revoked_protection`           | `revoked_at` check and terminal-state CHECK                                          | `mutant_no_revoked_protection`                                                 | `NeverAcceptedAfterRevoke`                                                                                                     |
| `no_inviter_protection`           | membership trigger and accept-time inviter check                                     | `mutant_no_inviter_protection`                                                 | `RoleWithinInviterAuthority`                                                                                                   |
| `no_inviter_check`                | accept-time inviter check                                                            | `mutant_no_inviter_check_backstop` / `mutant_no_inviter_check_gotrue_backstop` | backstop: the trigger covers it, also on the direct-deletion path (F4 fix)                                                     |
| `no_owner_trigger`                | trigger `portfolio_members_after_owner_ends`                                         | `mutant_no_owner_trigger`, `_pending`, `_backstop`, `_record_backstop`         | `InviterLossVoidsInvitations`, `NoPendingInvitationFromNonOwner`; backstops: the accept-time check and its recorded revocation |
| `no_trigger_no_record`            | trigger, and the recording of `revoked_at` at accept time                            | `mutant_no_trigger_no_record`                                                  | `RevokedResponseIsFinal`                                                                                                       |
| `no_recheck`                      | the second role check of `lock_portfolio_for_change`                                 | `mutant_no_recheck`                                                            | `NoPendingInvitationFromNonOwner`                                                                                              |
| `member_change_key_share`         | `for update` of membership changes (key share instead)                               | `mutant_member_change_key_share`                                               | `NoPendingInvitationFromNonOwner`                                                                                              |
| `no_pending_index`                | `portfolio_invitations_pending_email_key`                                            | `mutant_no_pending_index_backstop`                                             | backstop: the advisory lock of `create_invitation` (F1 fix) serialises creates                                                 |
| `no_account_freeze`               | `private.require_active_account` in `accept_invitation`                              | `mutant_no_account_freeze`                                                     | `NoMembershipForDeletedAccount`                                                                                                |
| `no_portfolio_guard`              | portfolio key in create/revoke/accept and the FKs to portfolios                      | `mutant_no_portfolio_guard`                                                    | `DeletedPortfolioIsEmpty`                                                                                                      |
| `no_accept_portfolio_lock`        | portfolio key in `accept_invitation` (the code before M5)                            | `mutant_no_accept_portfolio_lock`, `_scenario10`, `_backstop`                  | `AcceptNeverFailsUnexpectedly` (40P01), `AcceptOutcomesVsDeletion`; backstop: the FK keeps a deleted portfolio empty           |
| `no_create_portfolio_lock`        | key share of `lock_portfolio_for_change` in `create_invitation` (the code before M5) | `mutant_no_create_portfolio_lock`                                              | `NoRpcFailsUnexpectedly`                                                                                                       |
| `upsert_role`                     | plain insert of the membership (an upsert instead)                                   | `mutant_upsert_role`                                                           | `AcceptNeverChangesRole`                                                                                                       |
| `wrong_role`                      | the invitation's role in the membership insert                                       | `mutant_wrong_role`                                                            | `GrantedRoleIsInvitationRole`                                                                                                  |
| `no_notify_trigger`               | trigger `portfolio_invitations_after_accept`                                         | `mutant_no_notify_trigger`                                                     | `OwnersNotifiedOncePerAcceptance`                                                                                              |
| `no_create_serialise`             | the advisory lock of `create_invitation` (F1; the code before M6)                    | `mutant_no_create_serialise`                                                   | `CreateNeverFailsUnexpectedly` (23505)                                                                                         |
| `stale_response_role`             | the member's role in the retry answer (F2; the code before M6)                       | `mutant_stale_response_role`                                                   | `AcceptReportsActualRole`                                                                                                      |
| `removed_response_role`           | the `revoked` answer to a former member's retry (F2; the first version of M6)        | `mutant_removed_response_role`                                                 | `AcceptReportsActualRole`                                                                                                      |
| `no_null_inviter_revoke`          | `or i.invited_by is null` in the membership trigger (F4; the code before M6)         | `mutant_no_null_inviter_revoke`                                                | `NoPendingInvitationFromNonOwner`                                                                                              |
| `no_pending_index_no_serialise`   | the unique index and the advisory lock                                               | `mutant_no_pending_index_no_serialise`, `_live`                                | `AtMostOnePendingInvitation`, `AtMostOneLiveInvitation`                                                                        |
| `no_inviter_check_no_null_revoke` | accept-time inviter check and `or i.invited_by is null`                              | `mutant_no_inviter_check_no_null_revoke`                                       | `RoleWithinInviterAuthority` on the direct-deletion path                                                                       |

Properties with no single-mechanism mutant: `RoleWithinInviterAuthority`,
`DeletedPortfolioIsEmpty` and `AtMostOnePendingInvitation` are each protected
twice (trigger plus accept-time check, also on the direct-deletion path since
the F4 fix; portfolio key plus FK; unique index plus the advisory lock of the
F1 fix). Removing one mechanism leaves them intact (the backstop
configurations pass); removing both breaks them. The fixed findings'
properties (`CreateNeverFailsUnexpectedly`, `AcceptReportsActualRole`,
`NoPendingInvitationFromNonOwner` with GO) are broken by the mutants that
restore the code before M6. `NoRpcFailsUnexpectedly` with GO is broken by the
current code itself (F3, open).

## Bounds, abstractions and why they are adequate

Bounds: one portfolio, one e-mail, five users, up to three invitation rows,
up to nine concurrent calls in exhaustive runs (eighteen in the random
simulation), time 0..1 with a lifetime of 1 tick (0..2 in the simulation), at
most one environmental abort (two in the simulation).

Small-scope argument:

- Other portfolios and other e-mails use other rows, other unique-index keys
  and other membership keys. They can only interact through the portfolio
  and profile row locks, which are modelled.
- Two owners are enough: one inviter, and one other owner who changes the
  inviter's membership (or removes the invitee, `MU`) or deletes the
  portfolio. A third owner takes the same locks as `o2`.
- Every conflict in the code is between two transactions on one row (the
  portfolio, a profile, an auth user, an invitation or a membership). The
  seven call kinds are create, revoke, delete, accept, membership change,
  account deletion and GoTrue deletion. Every pair of different kinds, and
  two calls of the same kind (except the GoTrue deletion: one user is
  deleted once), runs together in at least one exhaustive configuration
  with the current code. This was checked by listing the kinds in each
  configuration.
- Three accept calls by the invitee cover a first accept, a concurrent one and
  a retry. One accept each by `x` and `y` covers the two kinds of impostor.
- Three invitation rows cover a pending invitation, its replacement and a
  concurrent second replacement.
- Time 0..1 with TTL 1 lets an invitation expire between a transaction's
  start and its checks.

Abstractions (each one is explained at its action in `Invitations.tla`):

- Rate limits only serialise or refuse requests. Dropping the serialisation
  allows more interleavings; a refusal is an environmental abort.
- Tokens are well formed and their verifier matches (worst case for the
  attackers). The selector check, `invalid`, comes from a deleted row.
- E-mail addresses and verification are static during a run.
- Steps that run back to back while the call holds a lock that excludes every
  other writer are merged into one step. Each merge says why at the action.
- The deletions' retry on `deadlock_detected` is not modelled. Instead the
  model checks that no deadlock happens at all.
- Tuple-lock queues are not ordered: any waiter may go first.
- Notifications and audit rows are not stored. The notification trigger is
  modelled by its locks and by counting firings. Since M5 the audit trigger
  no longer locks the portfolio (its FK to portfolios was dropped). Its FK
  on `actor_id` locks the actor's `auth.users` row, which matters only
  against GoTrue's deletion of that user; no configuration with GO or GA
  runs an audited write by `o1` at the same time.
- The FK checks on `auth.users` are modelled only for `o1`, the only user
  whose auth row is deleted.

The random simulation (`Invitations_sim_large.cfg`) runs every process but
GO at once on 15,000 random behaviours. It is a supplement, not a proof.

## What is not covered

- GoTrue deleting the invitee's or `o2`'s auth user. Only `o1`'s deletion is
  modelled.
- The daily cleanup (`private.cleanup`), which deletes invitations still
  unaccepted 90 days after their expiry.
- Plain client updates of the portfolio row (allowed to owners by RLS).
- E-mail delivery in `invite-member` and its rate limits (no database effect
  besides rate-limit rows).
- Liveness: the model checks that nothing is stuck forever, not that calls
  finish quickly.
- PostgreSQL itself, the PostgREST pre-request hook, and the Edge Function
  runtime are trusted.
- The firing order of the `ON DELETE` triggers on `auth.users` follows their
  names (`RI_ConstraintTrigger_a_<oid>`). On the test database that is
  creation order. If oids crossed a digit boundary the order could differ;
  the model assumes creation order.

## Changes from the earlier model

The earlier model (written before M5) found that `accept_invitation` and
`create_invitation` could deadlock with `delete_portfolio`, that concurrent
creates could fail with 23505, and that a retried accept could report a stale
role. M5 fixed the first two kinds by taking the portfolio key first.

- `Invitations_current.cfg` and `Invitations_current_create_delete.cfg` used
  to expect a violation. They now pass.
- `Invitations_current_create_race.cfg` and
  `Invitations_current_response_role.cfg` failed until M6 fixed F1 and F2
  (see below).
- `FIX_ACCEPT_LOCK_ORDER` is gone: it is now the code. Its opposite is the
  mutant `no_accept_portfolio_lock`. `Invitations_fix_accept_only.cfg` was
  dropped for that reason.
- New: membership changes, the membership trigger, the inviter check at
  accept time, the account deletion freeze, account deletions, GoTrue user
  deletions, and their properties and mutants.
- The mutant `no_trigger` is now called `no_notify_trigger`, to tell it apart
  from the membership trigger.
- `Invitations_current_no_delete.cfg` was folded into the other current-code
  configurations.

## Changes for the fixes of F1, F2 and F4 (M6)

`20261108082804_invitation_findings.sql` made the proposed fixes the code,
so the model takes them as its baseline and the code before them is a set
of mutants:

- `FIX_CREATE_SERIALISE`, `FIX_RESPONSE_ROLE` and `FIX_NULL_INVITER` are gone.
  Their opposites are the mutants `no_create_serialise`,
  `stale_response_role` and `no_null_inviter_revoke`, each with the old
  failing configuration (`Invitations_mutant_no_create_serialise.cfg`,
  `_stale_response_role`, `_no_null_inviter_revoke`).
- `Invitations_current_create_race.cfg`, `Invitations_current_response_role.cfg`
  and `Invitations_gotrue_direct_pending.cfg` now pass.
  `Invitations_gotrue_direct_safety.cfg`, `_revoke` and `_large` now also
  check `NoPendingInvitationFromNonOwner`.
- Configurations that only differed by the fix switches were merged:
  `Invitations_current_safety.cfg` into `Invitations.cfg`,
  `Invitations_pairs_current.cfg` into `Invitations_pairs.cfg`,
  `Invitations_sim_current.cfg` into `Invitations_sim_large.cfg`,
  `Invitations_response_role.cfg` into `Invitations_current_response_role.cfg`
  and `Invitations_fix_null_inviter.cfg` into
  `Invitations_gotrue_direct_safety.cfg`. `Invitations_fix_create_only.cfg` is
  now `Invitations_current_create_race_accept.cfg`.
- Two mechanisms are now backed up by a fix, so their single mutants became
  backstops (`Invitations_mutant_no_pending_index_backstop.cfg`: the advisory
  lock; `Invitations_mutant_no_inviter_check_gotrue_backstop.cfg`: the
  trigger's NULL branch) and the double mutants `no_pending_index_no_serialise`
  and `no_inviter_check_no_null_revoke` keep their teeth.
- After review, a retry by a former member answers `revoked` instead of the
  invitation's role. New: process `MU` (an owner removes the invitee),
  `Invitations_current_response_role_removed.cfg` and the mutant
  `removed_response_role`. `RevokedResponseIsFinal` now records only
  `revoked` answers for invitations not yet accepted (without that, the new
  configuration fails it on the former member's retry, which concerns the
  membership, not the invitation).
- F3 is unchanged in code. `replay_findings.sh` now checks the fixed
  behaviour of F1, F2 and F4, still reproduces F3 on the direct path, and
  checks that the delete-account order has no deadlock and that the rejected
  `BEFORE DELETE` trigger would still deadlock.
