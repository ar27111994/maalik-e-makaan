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

- Every safety property holds for the current code on the app's own paths.
  On one out-of-band path (an inviter deleted directly in Auth) a stale
  pending invitation is left behind (F4), but it still cannot be accepted.
- Four findings, all of low severity. Each one has a failing configuration,
  a configuration with the proposed fix that passes, and a replay on a real
  PostgreSQL 16 database (`replay_findings.sh`).
- The two old findings of the earlier model (deadlock of an accept with a
  portfolio deletion, and 40P01/23503 of a create with a deletion) are fixed
  by the current code. Their configurations now pass.

## Files

| File                 | What it is                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| `Invitations.tla`    | The model. Every action cites the SQL or TypeScript it follows.                                |
| `Invitations*.cfg`   | 56 configurations. The header of each states its expected result and its mode (`ci` or `all`). |
| `run.sh`             | Runs TLC on the configurations and compares each result with the expected one.                 |
| `trace.py`           | Shortens a TLC counterexample to one line per step.                                            |
| `replay_findings.sh` | Replays findings F1 to F4 on a real database (optional; needs the `tool/db` test server).      |

## How to run

```sh
formal/tla/Invitations/run.sh ci     # fast set, must be green (about 3.5 minutes)
formal/tla/Invitations/run.sh all    # every configuration (about TODO minutes)
formal/tla/Invitations/run.sh Invitations_current_create_race   # one or more by name
```

`run.sh` works from any directory. It needs Java (tested with OpenJDK 21) and TLC 2.19
(`tla2tools.jar`). Set `TLA2TOOLS` to the jar (the fallback is
`.cache/formal/tla2tools.jar` in the repository), `JAVA` to another `java`, `TLC_WORKERS` (default 2) and
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

To replay the findings on PostgreSQL (uses its own database,
`mm_fv_invitations`, on the server of `tool/db/env.sh`):

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
"M1" is `20261103192722_identity_portfolios.sql`, "M4" is
`20261103194402_notifications_audit.sql`.

| Model element                                  | Code                                                                                                                                                                                                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1, C2: `CBegin` .. `CCommit`                  | `supabase/functions/invite-member/handler.ts` `inviteMember` (calls the RPC as the caller; the token is returned only after commit), M5 `public.create_invitation`                                                                                    |
| `CLockP`                                       | M5 `private.lock_portfolio_for_change(P, ['owner'], false)`: role check, `for key share`, role check again                                                                                                                                            |
| `CMember`, `CSnap`, `CRevoke`                  | M5 `create_invitation`: `already_member` check, `update ... set revoked_at` of the pending invitation                                                                                                                                                 |
| `CInsert`, `CFk`                               | M5 `create_invitation` insert; M1 `portfolio_invitations_pending_email_key`; FK checks on `portfolio_id` and `invited_by`                                                                                                                             |
| R1, R2: `RBegin` .. `RCommit`                  | M5 `public.revoke_invitation`                                                                                                                                                                                                                         |
| D1, D2: `DBegin` .. `DCommit`                  | M5 `public.delete_portfolio`, `private.lock_portfolios_for_deletion`, `private.require_portfolio_name`, `private.delete_locked_portfolios`; M1 `ON DELETE CASCADE` of memberships and invitations                                                     |
| MD, MP, MR, ML: `MBegin`, `MChange`, `MCommit` | M5 `public.update_member_role` (demote, promote), `public.remove_member` (remove, leave), via `lock_portfolio_for_change(..., true)`                                                                                                                  |
| `MChange`, `XLockP`, `GTrig` with `MTRevoke`   | M5 trigger `portfolio_members_after_owner_ends`, function `private.after_owner_membership_ends`                                                                                                                                                       |
| ADU, ADO: `XBegin`, `XLockP`, `XCommit`        | M5 `public.admin_delete_account_data` (called by `supabase/functions/delete-account/handler.ts` `deleteAccount`)                                                                                                                                      |
| AU1..AU3, AX, AY: `ABegin` .. `ACommit`        | M5 `public.accept_invitation`                                                                                                                                                                                                                         |
| `AAcct`                                        | M5 `private.require_active_account` (profile `for key share`, then `account_deleted`)                                                                                                                                                                 |
| `ALockP`, `ALock`                              | M5 `accept_invitation`: portfolio key, `select ... for update`, then the status checks in code order, including the inviter check that records `revoked_at` (`AVoid`)                                                                                 |
| `AMember`, `AInsert`, `AFk`, `AUpdate`         | M5 `accept_invitation`: membership insert (M1 `portfolio_members` primary key, FKs), `accepted_at` update (M1 terminal-state CHECK)                                                                                                                   |
| `ATrigger`                                     | M4 trigger `portfolio_invitations_after_accept`, function `private.after_invitation_accepted` (notification inserts and their FK checks)                                                                                                              |
| GA, GO: `GBegin` .. `GCommit`                  | GoTrue deleting `o1`'s `auth.users` row: the M1 `ON DELETE` actions in trigger-name order, then the queued membership trigger. GA runs only after ADO succeeded (the order of `deleteAccount`); GO is a direct deletion (dashboard or Auth admin API) |
| `EnvAbort`                                     | client disconnect, `statement_timeout`, HTTP 429                                                                                                                                                                                                      |
| `DeadlockVictim`                               | PostgreSQL's deadlock detector (40P01)                                                                                                                                                                                                                |
| `Tick`                                         | time passing; expiry is `now() + interval '7 days'` against the transaction's `now()`                                                                                                                                                                 |

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
   has answered `revoked`, the invitation stays void (`RevokedResponseIsFinal`).
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
    (`AcceptReportsActualRole`).
13. Cross-checks with `tool/db/concurrency_test.sh`, which passes on the
    current code (run on 2026-11-05: exit 0 in 98 s): scenario 10 (an accept
    racing a portfolio deletion ends `accepted` or `invalid`) and scenario 14
    (an accept racing the account's deletion ends `accepted` or
    `account_deleted`) (`AcceptOutcomesVsDeletion`,
    `AcceptOutcomesVsAccountDeletion`).

Deadlocks between modelled calls fall under property 11. TLC's own deadlock
check stays on, so a call stuck forever would also be reported.

## Results

Timings are from the runs on 2026-11-05 with 2 TLC workers, on a 4-CPU machine
shared with another workload. TODO

## Findings

All four are of low severity: no safety property is broken.

### F1. Concurrent re-invites of one e-mail: the second fails with 23505

Configuration: `Invitations_current_create_race.cfg` (fails
`CreateNeverFailsUnexpectedly`). Shortened counterexample (13 states):

1. C1 (o1) and C2 (o2) both pass `lock_portfolio_for_change`. Key share on P
   does not exclude another key share.
2. Both pass `already_member`. Both take their `update ... set revoked_at`
   snapshot: no pending invitation yet.
3. C1 inserts invitation 1 and commits.
4. C2 inserts: `portfolio_invitations_pending_email_key` finds invitation 1
   committed and pending. 23505. `invite-member` answers HTTP 409 "This
   already exists", although a create normally replaces the pending
   invitation.

Replay: reproduced on PostgreSQL 16.15 (the second call fails with
`duplicate key value violates unique constraint
"portfolio_invitations_pending_email_key"`).

Proposed fix (`FIX_CREATE_SERIALISE`): in `create_invitation`, right after
`lock_portfolio_for_change`, take a transaction advisory lock on the pair:

```sql
perform pg_advisory_xact_lock(hashtextextended('invitation:' || p_portfolio_id::text || ':' || v_email, 0));
```

It sits after the portfolio in the global lock order and only creates take
it. `Invitations_fix_create_only.cfg` and `Invitations.cfg` pass with it.

### F2. A retried accept can report a role the member does not have

Configuration: `Invitations_current_response_role.cfg` (fails
`AcceptReportsActualRole`). Shortened counterexample (30 states):

1. Invitation 1 (manager, by o1) is pending. C2 (o2) re-invites the e-mail as
   viewer and passes `already_member`: u is not a member yet.
2. AU1 (u) accepts invitation 1 and commits: u is a manager.
3. C2 skips invitation 1 (accepted) and inserts invitation 2 (viewer).
4. AU2 (u) accepts invitation 2: u is already a member, so no insert; the
   answer is `manager`, which is right.
5. AU3 (u) retries invitation 2: the "already accepted by me" branch answers
   `accepted` with `v_invitation.role` = `viewer`. u is a manager.

Replay: reproduced (the retry returns `{"role": "viewer", "status":
"accepted", ...}` while `portfolio_members.role` is `manager`).

Proposed fix (`FIX_RESPONSE_ROLE`): in that branch, return
`coalesce(<the caller's current role in the portfolio>, v_invitation.role)`.
`Invitations_response_role.cfg` and `Invitations.cfg` pass with it.

### F3. Deleting an inviter directly in Auth can deadlock with an accept

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

Replay: reproduced (forcing step 2 before step 4 by taking the row lock
first). The server aborted the user deletion in the statement
`UPDATE ONLY "public"."portfolio_invitations" SET "invited_by" = NULL ...`.

`Invitations_gotrue_direct_safety.cfg` shows that every safety property still
holds on this path, apart from F4. The app's own path does not have the
problem: `Invitations_gotrue_via_delete_account.cfg` (GoTrue's deletion only
after `admin_delete_account_data` succeeded, as `deleteAccount` does) passes
with no unexpected error.

Proposed remedy: delete users only through the `delete-account` flow, or run
`admin_delete_account_data` before deleting a user by hand (document it in
`docs/operations.md`). The model checks this remedy (configuration GA). It
does not check a code change that would make direct deletions safe.

### F4. Deleting an inviter directly in Auth leaves their invitation pending

Configuration: `Invitations_gotrue_direct_pending.cfg` (fails
`NoPendingInvitationFromNonOwner`). Shortened counterexample (8 states):

1. GO deletes o1's `auth.users` row. The cascade deletes o1's owner
   membership and queues `portfolio_members_after_owner_ends`.
2. The next `ON DELETE` action sets `invited_by` to NULL on o1's invitations.
3. The queued trigger fires only now. Its `invited_by = old.user_id` matches
   nothing. The invitation stays pending, with no inviter, and is still
   listed to the owners.

`accept_invitation` still refuses it: its `invited_by is null` branch revokes
it and answers `revoked` (`Invitations_gotrue_direct_safety.cfg` passes; the
mutant `no_inviter_check_gotrue` shows that this branch is the only
protection here).

Replay: reproduced. After the deletion the invitation has `invited_by` NULL
and no `revoked_at`; `accept_invitation` then answers `revoked` and records
it.

Proposed fix (`FIX_NULL_INVITER`): in `private.after_owner_membership_ends`,
revoke also the pending invitations whose inviter is NULL:

```sql
and (i.invited_by = old.user_id or i.invited_by is null)
```

`accept_invitation` refuses such invitations anyway, so nothing valid is lost.
`Invitations_fix_null_inviter.cfg` passes with it. The `delete-account` flow
also avoids it (configuration GA).

## Mutants (non-vacuity)

Each mutant removes one mechanism of the current code (or two, where each
alone is backed up by the other). Each row is a configuration that must fail
with the named invariant, or pass where it says "backstop".

| Mutant (`MUTANT`)          | Mechanism removed                                                                    | Configuration                                                          | Expected                                                                                                                       |
| -------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `no_for_update`            | `for update` in `accept_invitation`                                                  | `mutant_no_for_update`                                                 | `AcceptedAtMostOnce`                                                                                                           |
| `no_used_check`            | `accepted_at` check                                                                  | `mutant_no_used_check`                                                 | `AcceptedAtMostOnce`                                                                                                           |
| `no_verified_check`        | `email_confirmed_at` check                                                           | `mutant_no_verified_check`                                             | `AcceptedOnlyByInvitee`                                                                                                        |
| `no_email_check`           | e-mail equality check                                                                | `mutant_no_email_check`, `mutant_no_email_check_join`                  | `AcceptedOnlyByInvitee`, `OnlyInviteesJoin`                                                                                    |
| `no_expiry_check`          | `expires_at <= now()` check                                                          | `mutant_no_expiry_check`                                               | `NeverAcceptedAfterExpiry`                                                                                                     |
| `no_revoked_check`         | `revoked_at` check                                                                   | `mutant_no_revoked_check` / `_backstop`                                | `AcceptNeverFailsUnexpectedly` (23514) / backstop: still never accepted                                                        |
| `no_revoked_protection`    | `revoked_at` check and terminal-state CHECK                                          | `mutant_no_revoked_protection`                                         | `NeverAcceptedAfterRevoke`                                                                                                     |
| `no_inviter_protection`    | membership trigger and accept-time inviter check                                     | `mutant_no_inviter_protection`                                         | `RoleWithinInviterAuthority`                                                                                                   |
| `no_inviter_check`         | accept-time inviter check                                                            | `mutant_no_inviter_check_backstop` / `mutant_no_inviter_check_gotrue`  | backstop: the trigger covers it / `RoleWithinInviterAuthority` on the direct-deletion path                                     |
| `no_owner_trigger`         | trigger `portfolio_members_after_owner_ends`                                         | `mutant_no_owner_trigger`, `_pending`, `_backstop`, `_record_backstop` | `InviterLossVoidsInvitations`, `NoPendingInvitationFromNonOwner`; backstops: the accept-time check and its recorded revocation |
| `no_trigger_no_record`     | trigger, and the recording of `revoked_at` at accept time                            | `mutant_no_trigger_no_record`                                          | `RevokedResponseIsFinal`                                                                                                       |
| `no_recheck`               | the second role check of `lock_portfolio_for_change`                                 | `mutant_no_recheck`                                                    | `NoPendingInvitationFromNonOwner`                                                                                              |
| `member_change_key_share`  | `for update` of membership changes (key share instead)                               | `mutant_member_change_key_share`                                       | `NoPendingInvitationFromNonOwner`                                                                                              |
| `no_pending_index`         | `portfolio_invitations_pending_email_key`                                            | `mutant_no_pending_index`, `_live`                                     | `AtMostOnePendingInvitation`, `AtMostOneLiveInvitation`                                                                        |
| `no_account_freeze`        | `private.require_active_account` in `accept_invitation`                              | `mutant_no_account_freeze`                                             | `NoMembershipForDeletedAccount`                                                                                                |
| `no_portfolio_guard`       | portfolio key in create/revoke/accept and the FKs to portfolios                      | `mutant_no_portfolio_guard`                                            | `DeletedPortfolioIsEmpty`                                                                                                      |
| `no_accept_portfolio_lock` | portfolio key in `accept_invitation` (the code before M5)                            | `mutant_no_accept_portfolio_lock`, `_scenario10`, `_backstop`          | `AcceptNeverFailsUnexpectedly` (40P01), `AcceptOutcomesVsDeletion`; backstop: the FK keeps a deleted portfolio empty           |
| `no_create_portfolio_lock` | key share of `lock_portfolio_for_change` in `create_invitation` (the code before M5) | `mutant_no_create_portfolio_lock`                                      | `NoRpcFailsUnexpectedly`                                                                                                       |
| `upsert_role`              | plain insert of the membership (an upsert instead)                                   | `mutant_upsert_role`                                                   | `AcceptNeverChangesRole`                                                                                                       |
| `wrong_role`               | the invitation's role in the membership insert                                       | `mutant_wrong_role`                                                    | `GrantedRoleIsInvitationRole`                                                                                                  |
| `no_notify_trigger`        | trigger `portfolio_invitations_after_accept`                                         | `mutant_no_notify_trigger`                                             | `OwnersNotifiedOncePerAcceptance`                                                                                              |

Properties with no single-mechanism mutant: `RoleWithinInviterAuthority` and
`DeletedPortfolioIsEmpty` are each protected twice (trigger plus accept-time
check; portfolio key plus FK). Removing one mechanism leaves them intact
(the backstop configurations pass); removing both breaks them. On the
direct-deletion path the accept-time check alone protects
`RoleWithinInviterAuthority` (F4), and removing it breaks it. The findings'
properties (`CreateNeverFailsUnexpectedly`, `AcceptReportsActualRole`,
`NoRpcFailsUnexpectedly` with GO, `NoPendingInvitationFromNonOwner` with GO)
are broken by the current code itself.

## Bounds, abstractions and why they are adequate

Bounds: one portfolio, one e-mail, five users, up to three invitation rows,
up to nine concurrent calls in exhaustive runs (eighteen in the random
simulations), time 0..1 with a lifetime of 1 tick (0..2 in simulations), at
most one environmental abort (two in simulations).

Small-scope argument:

- Other portfolios and other e-mails use other rows, other unique-index keys
  and other membership keys. They can only interact through the portfolio
  and profile row locks, which are modelled.
- Two owners are enough: one inviter, and one other owner who changes the
  inviter's membership or deletes the portfolio. A third owner takes the
  same locks as `o2`.
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

Random simulations (`Invitations_sim_current.cfg`, `Invitations_sim_large.cfg`)
run every process at once on 15,000 random behaviours each. They are a
supplement, not a proof.

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
  `Invitations_current_response_role.cfg` still fail: F1 and F2 are still in
  the code.
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
