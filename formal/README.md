# Formal verification

Machine-checked models and proofs of the parts of Maalik-e-Makaan where a
test can miss a bug: concurrent database transactions, and money
arithmetic shared by Dart and SQL. Every track follows the code as it is
now. For SQL that is the last definition of each function across
`supabase/migrations`. Each track's README cites the code, states its
bounds and says what it does not cover.

Every check states the outcome it expects, and a mismatch in either
direction fails the run. So a mutant (the code with one mechanism removed)
that is not caught fails it too. That is how the tracks show they are not
vacuous.

## The tracks

| Track                                                | Tool             | What it models                                                                                                                  |
| ---------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`tla/Invitations`](tla/Invitations/README.md)       | TLA+ (TLC 2.19)  | Creating, revoking, accepting and voiding invitations while portfolios, memberships and accounts change.                        |
| [`tla/Membership`](tla/Membership/README.md)         | TLA+             | Membership changes against portfolio and account deletion: lock order, deadlock retries, freezes.                               |
| [`tla/StorageCleanup`](tla/StorageCleanup/README.md) | TLA+             | Document rows, uploaded files, every Storage delete path, the cleanup queue and the daily sweep.                                |
| [`tla/LedgerPayments`](tla/LedgerPayments/README.md) | TLA+             | Payments, idempotency keys, receipts, FIFO allocation, voids, credit and the billing jobs.                                      |
| [`tla/LateFees`](tla/LateFees/README.md)             | TLA+             | The daily late-fee job against payments, voids, policy changes, charge edits and the end of a tenancy.                          |
| [`tla/RateLimit`](tla/RateLimit/README.md)           | TLA+             | The fixed-window rate limiter, for requests inside a transaction and for Edge Functions.                                        |
| [`lean`](lean/README.md)                             | Lean 4.35.0      | Rounding, `Money.allocate`, due dates, proration, billed rent, late fees and FIFO allocation, each equal to the SQL it mirrors. |
| [`smt`](smt/README.md) (run by `lean/run.sh`)        | Z3 (`z3-solver`) | No overflow in Dart (64-bit and 2^53), `numeric(14,2)` or JSON; PostgreSQL's inexact division never changes a result.           |
| [`bend`](bend/README.md)                             | Bend 2.0.39      | 35 laws of allocation, splits, rounding, proration, billed rent and daily fees, plus differential runs against Dart and SQL.    |

### What each track proves

- **Invitations.** An invitation is accepted at most once, only by its
  invitee, never after revocation or expiry, and never beyond the
  inviter's authority at commit time. At most one pending invitation per
  e-mail, and none left by an inviter who is no longer an owner. A retried
  accept reports the member's actual role. No call fails with an unexpected
  database error (23505, 23503, 23514, 40P01) on the app's own paths.
- **Membership.** Every portfolio keeps an owner and a member. Nothing
  commits for an account once its deletion has. Ids are never reused. A
  caretaker is always a manager of their portfolio; the caretaker and the
  owner-abroad answer are set only by those allowed at commit, and the
  answer asked on the next open never overwrites one already given. A
  deleted account's declared residence is cleared. No wait-for cycle, no
  deletion defeated by `deadlock_detected`, and every request finishes
  (liveness).
- **StorageCleanup.** No document references a missing or queued file. No
  referenced file is deleted. No document outlives its entity. Deleted
  portfolios' files are queued and eventually cleaned. Cleaners never
  claim an item twice and never starve a folder.
- **LedgerPayments.** One payment per idempotency key, and a retry is never
  refused. Receipts are gapless. No charge is overpaid. FIFO order. One
  rent per lease and month. No credit next to an open due. The daily job
  never waits and nothing deadlocks.
- **LateFees.** At most one automatic fee per rent due, within its cap,
  only when overdue, never on rent paid within grace, never on voided rent.
  Re-running the job changes nothing. The job and the payment path never
  deadlock.
- **RateLimit.** The admitted requests per key and window never exceed the
  limit. No lost update, no false refusal. Retry-After is positive and
  points at the end of the right window.
- **Lean.** 44 theorems, each for every input: half-up division equals
  SQL `round`, allocations sum to the amount, proration and fees are
  bounded and equal the SQL, the Dart FIFO plan is exactly
  `private.allocate_payment`. Only the standard axioms. `check-vectors`
  runs the 71 shared contract vectors.
- **SMT.** 34 overflow checks and 14 rounding checks (`overflow.py`,
  `dart_sql.py`) on the bounds the CHECK constraints admit.
- **Bend.** 35 laws proven for all naturals and all lists, checked again by
  the BendTT kernel. 41 mutants are rejected. The models match the real
  Dart and SQL on over 600,000 cases.

## Findings and the migrations that fixed them

Each finding is kept as a failing configuration or mutant, and most have a
replay on a real PostgreSQL 16 database (the track's `replay/`).

| Track          | Finding                                                                                     | Status                                                                                                                                                                                                                                   |
| -------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bend (audit)   | Prorated rent above the rent for a paisa rent; a daily fee above its cap; preview ≠ ledger. | Fixed in `20261104143928_ledger_jobs_hardening.sql` (`least`, round before cap) and in `mm_core` (`RentMath.billedRent`).                                                                                                                |
| LedgerPayments | A: a key reused on another lease failed with a raw 23505.                                   | Fixed in `20261104143928_ledger_jobs_hardening.sql` (advisory lock on the key).                                                                                                                                                          |
| LedgerPayments | B: the daily job deadlocked with the dashboard's billing sync.                              | Fixed in `20261104143928_ledger_jobs_hardening.sql` (one lease at a time, `SKIP LOCKED`, id order).                                                                                                                                      |
| LedgerPayments | C: receipt 100000 rendered like 10000.                                                      | Fixed in `20261104143928_ledger_jobs_hardening.sql` (wider `lpad`).                                                                                                                                                                      |
| Invitations    | Accept or create against `delete_portfolio`: deadlock, 40P01 or 23503 (earlier model).      | Fixed in `20261105072426_membership_deletion_storage.sql` (portfolio key first).                                                                                                                                                         |
| Membership     | M1: a deletion could fail with 40P01 against one client write; the retry was no guarantee.  | Fixed in `20261105170557_concurrency_findings.sql` (client policies take the portfolio key first).                                                                                                                                       |
| StorageCleanup | S1: a document could reference a file deleted at the same moment (three review rounds).     | Fixed in `20261105170557_concurrency_findings.sql` (row lock on insert, `BEFORE DELETE` trigger on `storage.objects`).                                                                                                                   |
| StorageCleanup | S2: a document could attach to a file the daily sweep was deleting.                         | Fixed in `20261105170557_concurrency_findings.sql` (shared/exclusive sweep gate).                                                                                                                                                        |
| LedgerPayments | F1: a client's charge edit could deadlock a payment or a void (also LateFees F2).           | Fixed in `20261107181820_ledger_findings.sql` (`update_charge`; no client `UPDATE` on charges).                                                                                                                                          |
| LedgerPayments | F2: raising a manual charge left credit unapplied.                                          | Fixed in `20261107181820_ledger_findings.sql`.                                                                                                                                                                                           |
| LedgerPayments | F3: `end_lease` kept later rent that had any allocation (also LateFees F3, its late fees).  | Fixed in `20261107181820_ledger_findings.sql` (release, void, re-apply credit).                                                                                                                                                          |
| LateFees       | F1: a fee stayed on rent paid within grace but recorded after the job ran.                  | Fixed in `20261107181820_ledger_findings.sql` (`record_payment` voids that fee).                                                                                                                                                         |
| RateLimit      | F5: an Edge Function's Retry-After could point to the wrong window.                         | Fixed in `20261107181820_ledger_findings.sql` (`admin_rate_limit_hit` returns the database's wait).                                                                                                                                      |
| SMT            | A1: `payments.applied_amount` (amount + tax) overflowed `numeric(14,2)`.                    | Fixed in `20261107181820_ledger_findings.sql` (`invalid_amount`).                                                                                                                                                                        |
| Invitations    | F1: concurrent re-invites of one e-mail: the second failed with 23505 (HTTP 409).           | Fixed in `20261108082804_invitation_findings.sql` (advisory lock per portfolio and e-mail; the second re-invite replaces the first).                                                                                                     |
| Invitations    | F2: a retried accept could report a role the member does not have.                          | Fixed in `20261108082804_invitation_findings.sql` (the retry reports the member's current role; a former member's retry answers `revoked`).                                                                                              |
| Invitations    | F4: deleting an inviter directly in Auth left their invitation pending (still refused).     | Fixed in `20261108082804_invitation_findings.sql` (the membership trigger also revokes invitations without an inviter).                                                                                                                  |
| RateLimit      | F4: requests that fail after the limiter roll back their hit, so they are never limited.    | Accepted, not fixed: see `docs/architecture/permissions.md`, "Rate limits and failing requests".                                                                                                                                         |
| Invitations    | F3: deleting an inviter directly in Auth can deadlock with an accept.                       | Open, low. Operational rule in `docs/operations.md`: run `admin_delete_account_data` before an Auth deletion (`Invitations_gotrue_via_delete_account.cfg`); a `BEFORE DELETE` trigger on `auth.users` was evaluated and still deadlocks. |
| Membership     | D1-D3: a caretaker deleted in Auth, or its membership changed by an operator, can deadlock. | Open, low, outside the app's paths. Operational rules in `docs/operations.md` (`assume_direct_auth_*`, `assume_service_member_write`; `replay/residence.sh`).                                                                            |
| Membership     | P1: a schema restored from a dump runs GoTrue's FK actions by name, which can deadlock.     | Open, low. `docs/operations.md` restores the schema from the migrations, never from a dump (`assume_restored_*`; `replay/residence.sh`).                                                                                                 |

The models take the fixed code as their baseline. The code before each fix
is a mutant named for the mechanism the fix added, and it must still fail.

## Install the tools

```sh
make formal-install     # tool/formal/install.sh: every tool, about 1.3 GB to download
```

[`tool/formal/install.sh`](../tool/formal/install.sh) puts exactly pinned
tools in `.cache/formal` (git ignores it) and checks each download against
its sha256. A file that does not match is refused and nothing is moved
into place. It is idempotent: a second run downloads nothing. It writes
`.cache/formal/env.sh`, which every `run.sh` reads. A variable you set
yourself wins over it.

| Tool        | Pin                                                                             | Variable       |
| ----------- | ------------------------------------------------------------------------------- | -------------- |
| TLC 2.19    | `tla2tools.jar` of tlaplus v1.7.4, sha256 `936a2620…0e88`                       | `TLA2TOOLS`    |
| Lean 4.35.0 | `lean-4.35.0-linux.tar.zst`, sha256 `7289597a…8f6d`                             | `LEAN_HOME`    |
| Lean 4.34.0 | `lean-4.34.0-linux.tar.zst`, sha256 `caaa9835…646b` (Bend's kernel needs it)    | `LEAN434_HOME` |
| z3-solver   | 5.3.3.0, hash-pinned in `tool/formal/requirements.txt`, in `.cache/formal/venv` | `Z3_PYTHON`    |
| Bend 2.0.39 | `bend-2.0.39-linux-x64.tar.gz`, sha256 `6cf462fd…c7ab`                          | `BEND`         |

It needs Linux x86_64, `curl`, `sha256sum`, `tar` and `zstd`, and Python
3.13 for the Z3 environment (`PYTHON`). TLC also needs Java 11 or later on
`PATH`. Install part of the set by name (`tla`, `lean`, `lean434`, `z3`, `bend`):
`tool/formal/install.sh tla z3`.
Unpacked, the two Lean toolchains take about 6.4 GB.

Without network access to GitHub, put the release files in a directory
under their upstream names and point `FORMAL_MIRROR` at it. They are
checked against the same sha256:

```sh
FORMAL_MIRROR=/path/to/files tool/formal/install.sh
```

## Run

```sh
make verify             # every track's ci set: what CI runs
make verify-all         # every configuration, mutant and cross-check
tool/formal/verify.sh ci tla/RateLimit lean   # some tracks only
formal/tla/LateFees/run.sh ci                 # one track by hand
```

`tool/formal/verify.sh` runs every track, even after one fails, and ends
with one line per track. Each `run.sh` works from any directory and writes
below a fresh directory in `${TMPDIR:-/tmp}`. The exceptions are Lean's
build in `formal/lean/.lake` (git ignores it) and Bend's kernel, built once
into `~/.bend/bendtt`. `formal/bend/run.sh all`
also needs Dart (`make bootstrap`) and a PostgreSQL 16 server
(`tool/db/env.sh`). The PostgreSQL replays of the findings are separate:
each track's `replay/run.sh`, `tla/Invitations/replay_findings.sh` and
`tla/Membership/replay/residence.sh`.

### Timings

Measured on 2026-11-07 with `make verify` and `make verify-all` on a 4-CPU
machine shared with other work (load average 6 to 15). Expect a dedicated
runner to be faster. TLA+ tracks run 2 configurations at a time
(`TLC_JOBS`), Invitations with 2 TLC workers.

| Track              | `ci`                        | `all`                      |
| ------------------ | --------------------------- | -------------------------- |
| tla/Invitations    | 55 configurations, 106 s    | 60 configurations, 1,051 s |
| tla/Membership     | 53 configurations, 56 s     | 79 configurations, 101 s   |
| tla/StorageCleanup | 49 configurations, 117 s    | 62 configurations, 151 s   |
| tla/LedgerPayments | 28 configurations, 63 s     | 72 configurations, 179 s   |
| tla/LateFees       | 36 configurations, 98 s     | 48 configurations, 193 s   |
| tla/RateLimit      | 22 configurations, 27 s     | 24 configurations, 21 s    |
| lean (and smt)     | 7 steps, 15 s (clean build) | 23 steps, 150 s            |
| bend               | 1 step, 57 s (kernel built) | 114 steps, 133 s           |
| **Total**          | **667 s (11 minutes)**      | **3,752 s (63 minutes)**   |

`ci` for Lean includes `lake build` from an empty `formal/lean/.lake`
(11 s). `ci` for Bend includes building BendTT's kernel with Lean 4.34.0
into an empty `~/.bend`; with the kernel built, the verdict takes 6 to
15 s. A second `make verify`, with both built and lighter load, took
409 s. The Invitations row was measured again on 2026-11-08 with its
`run.sh` alone, after `20261108082804_invitation_findings.sql` merged the
configurations that differed only by the fix switches, and the Membership
row on 2026-11-12 (`ci` in `make verify`, `all` with its `run.sh` alone and
3 jobs), after the residence extension and a change that makes every
configuration faster (the totals are from 2026-11-07). In `all`,
Invitations spends most of its time in four exhaustive configurations
(`Invitations`, `_pairs`, `_members_large`, `_gotrue_direct_large`: 90 to
250 s each) and one random simulation (280 s). TLC 2.19 ends a simulation
with `num=` without "No error has been found"; the runner takes exit 0,
"Finished in" and no error as a pass.

The installer took 12 s to download and unpack TLC, z3-solver and Bend,
and about 7 s to unpack each Lean toolchain.

## Add a track

1. Make a directory under `formal/` with a `README.md` in the shape of the
   others: the code it follows (file and migration), what is modelled,
   the properties, the findings, bounds and abstractions, how to run,
   expected results, and what is not covered.
2. Give it a `run.sh [ci|all]`. It checks every step against an expected
   outcome stated next to the step, prints one row per step and a last
   line with `as expected` (or `Total: … mismatches`), and exits non-zero
   on any mismatch. Read tools from `.cache/formal/env.sh` and fail with a
   message that names `tool/formal/install.sh`. A TLA+ track can copy
   `tla/LateFees/run.sh` unchanged and put its configurations in `cfg/`
   with `\* EXPECT:` and `\* MODE:` headers.
3. Keep `ci` under a few minutes. It runs on every push.
4. Add the directory to `TRACKS` in `tool/formal/verify.sh`.
5. A new tool goes into `tool/formal/install.sh` with its upstream URL and
   sha256, and into `env.sh`. Changing the installer changes CI's cache
   key, so the new tool is fetched once and then cached.
6. Record each finding as a failing configuration or mutant and, where
   it can be, a replay on PostgreSQL. When a migration fixes it, flip the
   baseline and keep the old code as a mutant.
