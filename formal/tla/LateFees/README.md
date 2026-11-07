# Automatic late fees and the daily job (TLA+)

A TLC-checked model of how the daily job posts late fees, as the code
implements it now, against the other writers of a lease's dues: payments
and their voids, voided charges, the end of a tenancy, late-fee policy
changes and a client's own edits of charges.

Code followed (always the last definition of each function):

- `supabase/migrations/20261105170557_concurrency_findings.sql`
  ("findings"): `private.run_daily_jobs`, the client `UPDATE` policies
  `leases_update` and `charges_update`.
- `20261104143928_ledger_jobs_hardening.sql` ("hardening"):
  `private.maintain_lease`, `private.assess_late_fees`,
  `app.late_fee_amount`, `public.record_payment`, `public.void_payment`,
  `public.void_charge`, the pg_cron schedule (`*/10 * * * *`) and
  `private.lease_maintenance`.
- `20261105072426_membership_deletion_storage.sql` ("latest"):
  `private.lock_lease_for_write`.
- `20261103193658_ledger.sql` ("ledger"): `charges_late_fee_key`,
  `private.allocate_payment`, `public.end_lease`,
  `private.before_charge_update` and the column grants.
- `20261107172908_police_registration_rules.sql` was read in full. It
  redefines `private.generate_notifications`, which the job runs only in a
  run that holds no lease lock; nothing modelled here changes.

## What is modelled

Same conventions as `../Membership`: one step per SQL statement, or per
row for a statement that locks rows one at a time. Locks are disabled
steps. `Need(t)` lists the transactions `t` waits for, and `Detect` is
PostgreSQL's deadlock detector. Writes keep a pre-image, so a rollback
restores them and other snapshots read the committed version.

| Model element                             | Code                                                                                                                                                                                                                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `J_Start`                                 | `run_daily_jobs` (findings): `v_as_of := app.today_pkt()`, then `pg_try_advisory_xact_lock`; a run that does not get it returns `skipped`                                                                                                                                            |
| `J_Scan`                                  | the loop's query: active leases not maintained for `v_as_of`, in id order, from one snapshot                                                                                                                                                                                         |
| `J_Lock`                                  | the lease `for update skip locked` (busy: next lease). The portfolio `for key share skip locked` before it conflicts with nothing modelled here                                                                                                                                      |
| `J_Maint`                                 | `maintain_lease` (hardening): status `active` under the lock, then `assess_late_fees` reads the lease's policy and selects the rent dues that are live, unpaid, past grace and owe a fee, in `due_date, id` order                                                                    |
| `J_Fee`                                   | one row of the `INSERT ... ON CONFLICT (related_charge_id) DO UPDATE ... WHERE voided_at is null and paid_amount = 0 and waived_amount = 0 and excluded.amount > amount`. The conflicting row is locked before the `WHERE` is evaluated; a fee above `numeric(14,2)` fails the lease |
| `J_Fee` (no rent left)                    | `insert into private.lease_maintenance` (`maintained_on = v_as_of`)                                                                                                                                                                                                                  |
| `JobLeaseFailed`, `Detect` (job)          | `exception when others`: rollback to the lease's subtransaction, then `maintained_on = v_as_of, failures + 1` (the lease waits for tomorrow)                                                                                                                                         |
| `J_Commit`                                | the end of the run: every lease lock taken is held until here                                                                                                                                                                                                                        |
| `LateFeeAmount`                           | `app.late_fee_amount` (hardening), exactly, in paisa: round half up to whole rupees, then the daily cap, then the clamp                                                                                                                                                              |
| `P_Wait`, `P_Lock`, `P_Alloc`, `P_Commit` | `record_payment` (hardening): `lock_lease_for_write` (latest), the payment row, `allocate_payment` (ledger): chosen charges first, then `due_date, id`, `for update of c` one row at a time                                                                                          |
| `V_Lock`, `V_Do`                          | `void_payment` (hardening): reverse the allocations, mark the payment voided                                                                                                                                                                                                         |
| `C_Lock`, `C_Do`                          | `void_charge` (hardening): the charge and, for a rent, its unpaid fee (`related_charge_id = x and paid_amount = 0`)                                                                                                                                                                  |
| `E_Lock`, `E_Do`                          | `end_lease` (ledger): void untouched rent of later months, status `ended`                                                                                                                                                                                                            |
| `Cl_Row` (policy)                         | a client `UPDATE leases SET late_fee_*` (policy `leases_update`, findings): portfolio keys, then each row in scan order                                                                                                                                                              |
| `Cl_Row` (edit)                           | a client `UPDATE charges SET description` (policy `charges_update`, findings; allowed by `before_charge_update` on any live charge): portfolio keys, then each charge row in scan order, with no lease lock                                                                          |
| `Tick`                                    | the Pakistan calendar day moves on                                                                                                                                                                                                                                                   |

Two leases of one portfolio. Rent dues `r1` (L1) and `r2` (L2) are due on
day 0; `r3` is L1's next month, due on day 1. Every lease's grace is one
day, so a fee is first owed on day 2. The policies are a daily fee of 100
rupees capped at 250 (or 249.50, or uncapped at 400 a day), 10 % and a flat
50 rupees.

## Properties

| Property                                 | Plain language                                                                                                               | Broken by                                                                   |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `AtMostOneFee`                           | A rent due has at most one automatic late fee, ever: a daily fee grows in place, a flat or percentage fee is posted once.    | `mut_no_unique_index`                                                       |
| `FeeWithinCap`                           | A fee never exceeds the daily cap of the policy it was computed with.                                                        | `mut_no_cap`, `mut_round_after_cap` (the code before hardening)             |
| `FeeFitsCharge`                          | A fee always fits a charge (`numeric(14,2)`), so no lease fails on it.                                                       | `mut_no_clamp`                                                              |
| `FeeOnlyWhenOverdue`                     | The job writes a fee only for a live rent due that is unpaid in the ledger and past its grace period on the day it runs for. | `mut_no_grace_check`, `mut_no_outstanding_check`                            |
| `NoFeeWhenPaidInGrace`                   | No fee is left on a rent due that payments dated within grace (`paid_on <= due_date + grace_days`) settle in full.           | the current code: finding F1 (`backdated`)                                  |
| `IdempotentRerun`                        | Running the job again for a day, with nothing changed, changes no fee.                                                       | `mut_rerun_accumulate` (two mechanisms removed: see below)                  |
| `FeeNotAboveFormula`                     | The job never sets a fee above what the policy defines for a day it assessed (a flat fee is never charged twice).            | `mut_accumulate`                                                            |
| `FeeOnlyGrows`                           | The job only raises a fee, and never touches one that is voided, paid or waived (even in part).                              | `mut_no_growth_guard`, `mut_no_paid_guard`, `mut_no_void_guard`             |
| `VoidedFeeStaysVoid`                     | A voided fee is never posted again.                                                                                          | `mut_index_live_only`                                                       |
| `NoFeeOnVoidedRent`                      | No live, unpaid fee belongs to a voided rent due.                                                                            | `mut_no_void_related`; the current code: finding F3 (`end_lease`)           |
| `FeeOnlyOnActiveLease`                   | Fees are written only while the lease is active.                                                                             | `mut_no_status_check`                                                       |
| `FeeUsesPolicyInForce`                   | Fees are computed with the policy in force when the lease is locked.                                                         | `mut_stale_policy`                                                          |
| `NoWaitCycle`                            | No transaction waits, directly or through others, for itself: the job and the payment path never deadlock.                   | `mut_no_skip_locked`; the current code: finding F2 (`edit_job`, `edit_pay`) |
| `TypeOK`, `NotOverpaid`, `NoLeakedLocks` | Sanity of the model: types; `paid + waived <= amount`; a finished process holds nothing.                                     | none: model sanity                                                          |

`IdempotentRerun` has two independent guards. The scan skips a lease
already maintained for the day, and the upsert only raises a fee to what
the policy defines. `mut_no_maint_check` removes the first and passes on
purpose. Removing the second alone (`mut_accumulate`) leaves no same-day
rerun to observe, but it breaks `FeeNotAboveFormula` the next day. So only
the double mutant `mut_rerun_accumulate` breaks `IdempotentRerun`.

`mut_no_advisory_lock` passes on purpose: two overlapping runs are kept
apart by the lease lock and the unique index. The coordinator lock saves
work; it protects no property modelled here.

Witnesses show the scenarios reach what the properties speak about. Each
is expected to be violated: `w_fee_posted` (fees are posted),
`w_fee_raised` (a daily fee grows), `w_paid_in_grace` (a payment settles a
rent within grace, so `NoFeeWhenPaidInGrace` is not vacuous),
`w_fee_raised_fix` (with F2's fix the job still raises the edited fee) and
`w_deadlock_job` (F2's deadlock is detected).

## Finding F1: a fee stays on a rent paid within grace but recorded late

Severity: low to medium (a tenant who paid on time is charged a late fee
until the landlord voids it by hand). Current code; `backdated` reproduces
it, `backdated_fix` passes with the proposed fix.

`assess_late_fees` decides "late" from the ledger on the day it runs. A
payment is dated by `p_paid_on`, which may lie in the past. The job runs
every 10 minutes, so it maintains a lease minutes after midnight. Any
payment recorded after that, dated on or before the last day of grace,
leaves the fee in place. Nothing removes it, and the payment settles the
rent first (oldest due first). Counterexample (20 states, shortened):

1. `Tick`, `Tick`: day 2. Rent `r1` was due on day 0; grace ended on day 1.
2. `J_Start` ... `J_Fee`, `J_Commit`: the job posts a 200-rupee fee on
   `r1`.
3. `P_Wait` ... `P_Commit`: the landlord records the tenant's cash, paid on
   day 1, for the full rent. `NoFeeWhenPaidInGrace` is violated.

Replayed on PostgreSQL by `replay/run.sh` (F1): job for 2026-10-11, then a
payment recorded on 2026-10-11 with `paid_on` 2026-10-09 (grace ended
2026-10-10). The rent is paid and the 600-rupee fee stays outstanding.

Proposed fix (`FIX = "backdated_void"`): when `record_payment` settles a
rent due in full with a payment dated within its grace period, it voids
that rent's unpaid automatic fee (`source = 'auto_late_fee'`,
`paid_amount = 0`), as `void_charge` does, before allocating further. A
fee that was already paid in part stays, as everywhere else.

## Finding F2: a client's multi-row edit of charges deadlocks with the job and with payments

Severity: low (PostgreSQL detects the deadlock and aborts one side; no data
is corrupted). Current code; `edit_job` and `edit_pay` reproduce it,
`edit_job_fix` and `edit_pay_fix` pass with the proposed fix.

`charges_update` (findings) lets an owner, manager or accountant
`UPDATE` the description, due date or (manual) amount of charges directly
through the Data API. The policy takes the portfolio keys first, but not
the lease: the statement locks charge rows in its scan order. Every other
writer of a lease's charges locks the lease first. The job holds the
charge rows it touched on earlier leases until it commits, and the upsert
locks the conflicting fee row even when its `WHERE` keeps the amount. Two
cycles follow (the global order is lease, then other rows; this statement
takes other rows without the lease):

- `edit_job` (10 states): the job locks L1, raises L1's fee (row locked)
  and locks L2. The client's statement locks L2's fee, then waits for
  L1's. The job's upsert waits for L2's fee.
- `edit_pay` (5 states): `record_payment` locks L1 and its rent row
  (oldest due first). The client's statement locks L1's fee, then waits
  for the rent. `allocate_payment` waits for the fee.

On PostgreSQL (`replay/run.sh`, F2), with a single `UPDATE` statement whose
plan is a sequential scan, both deadlocks are detected. When the job is
the victim, the error is caught per lease, and that lease is recorded as
failed for the whole day (`maintained_on` = today, `failures` 1). Its rent
and fees then wait for tomorrow. When the payment is the victim, the
client gets `40P01`, and a retry with the same idempotency key is safe. A sleep in the `SET` list widens the
gap between the statement's rows; PostgREST would send a literal, so the
real race needs the two to meet within a few milliseconds.

Proposed fix (`FIX = "charge_edit_rpc"`): edit charges through an RPC that
calls `lock_lease_for_write` and then updates the one charge (or the
charges of one lease), and revoke the client's `UPDATE` on `charges`. The
job then skips the lease (`SKIP LOCKED`), and a payment waits for it.

## Finding F3: ending a tenancy leaves the late fees of the rent it voids

Severity: low to medium (the tenant's ledger shows late fees for months
after they left). Current code; `end_lease` reproduces it,
`end_lease_fix` passes with the proposed fix.

`end_lease` voids untouched rent for months after the move-out month. A
move-out date in the past (allowed: `p_moved_out_on <= today`) means those
months may already be overdue, with fees posted. `void_charge` voids a
rent's unpaid fee with it; `end_lease` does not. Counterexample
(19 states, shortened):

1. `Tick` x3: day 3; `r3` (L1's next month, due on day 1) is overdue.
2. `J_Start` ... `J_Commit`: the job posts fees on `r1` and `r3`.
3. `E_Lock`, `E_Do`: `end_lease` with move-out in month 1 voids `r3`; its
   fee stays live. `NoFeeOnVoidedRent` is violated.

Replayed on PostgreSQL (`replay/run.sh`, F3): a lease from 2026-10-01,
job for 2026-11-12, `end_lease` moving out on 2026-10-31. November's rent
is voided ("Lease ended"); its 700-rupee fee stays live.

Proposed fix (`FIX = "end_lease_fees"`): in the same `UPDATE` (or right
after it), void the unpaid automatic fees whose `related_charge_id` is one
of the voided rents, as `void_charge` does.

## Bounds, abstractions and why they are adequate

- Two leases in one portfolio, at most three rent dues, two fee slots per
  due (the second only reachable without the unique index), days 0 to 3.
  Every property relates one rent due to its fee, its lease's lock and the
  writers of that lease. Two leases are needed for the job's lease order
  (it holds earlier leases while it works on later ones) and for the
  out-of-order client statements; more leases only repeat the pattern.
- Day 2 is the first day a fee is owed and day 3 the first day it grows or
  meets the cap, so `MAX_DAY = 3` covers posting, growth, the cap and every
  writer arriving before, between or after the job's runs. The cap and
  the rounding are exercised with values chosen to hit their edges (249.50
  rupees; 300 rupees against a 250 cap).
- Money is integer paisa. `app.late_fee_amount` is computed exactly as a
  fraction and rounded half up, so the arithmetic is the SQL's. The
  `numeric(14,2)` bound (999,999,999,999.99 rupees) is scaled to 999.99;
  the clamp is the same expression at that scale.
- Rent dues exist from the start. Generating them and applying credit
  (`sync_lease_billing`, `apply_lease_credit`) belong to
  `../LedgerPayments`; every path that runs them holds the lease lock, as
  the job does, so they add no interleaving the job's lock does not
  already serialise.
- The portfolio key (`KEY SHARE`) conflicts only with deletions and
  membership changes, which `../Membership` covers. The job takes it with
  `SKIP LOCKED` before the lease, so it never waits for it.
- A client's description edit changes no value the properties read; only
  its row locks matter.
- `void_payment`'s `apply_lease_credit` allocates nothing here: no
  scenario has a second payment on the same lease.

## How to run

```sh
formal/tla/LateFees/run.sh ci          # 32 configurations
formal/tla/LateFees/run.sh all         # 44 configurations
formal/tla/LateFees/replay/run.sh      # F1, F2, F3 on PostgreSQL (tool/db/env.sh)
```

The runner is `../StorageCleanup/run.sh` with two changes: when
`TLA2TOOLS` is unset and `.cache/formal/tla2tools.jar` is missing it falls
back to the formal-verification scratch copy, and a configuration that
ends in a TLC error is reported as `error` instead of stopping the runner.
`TLC_JOBS` (default 2), `TLC_WORKERS` (default 1), `TMPDIR` and
`KEEP_LOGS` work as there. Each `cfg/*.cfg` names its expected outcome
(`\* EXPECT:`) and mode (`\* MODE:`). The replay builds the disposable
database `mm_fv_latefees` with `tool/db/reset.sh` and drops it. It exits
non-zero unless F1, F2 (both cycles) and F3 all show. F2 depends on timing
(sleeps of 2 to 5 seconds); on a heavily loaded machine run it again.

## Expected results

Measured on this machine (4 CPUs shared with other work; 1 job x 1
worker):

- `run.sh ci`: 32/32 as expected in 78 s wall.
- `run.sh all`: 44/44 as expected in 305 s wall. The largest are
  `part_paid` (298,324 distinct states) and `mut_no_advisory_lock`
  (369,299).
- `replay/run.sh`: all four checks "yes" in about 70 s.
- Expected violations: `backdated` (F1), `end_lease` (F3), `edit_job` and
  `edit_pay` (F2), every `mut_*` except `mut_no_maint_check` and
  `mut_no_advisory_lock`, and every `w_*` witness.

## Cross-check with the executable tests

| Test                                                                                                                                                                 | Here                                                                                         |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `09_jobs_guards.test.sql`: no fee within grace; a daily fee after 15 days and at its cap; one flat fee; a voided fee is never recreated; a failing lease is isolated | `FeeOnlyWhenOverdue`, `FeeWithinCap`, `AtMostOneFee`, `VoidedFeeStaysVoid`, `JobLeaseFailed` |
| `10_contract_vectors.test.sql`: `app.late_fee_amount` against the shared rent-maths vectors                                                                          | `LateFeeAmount` follows the same SQL                                                         |
| `concurrency_test.sh` 4: the job racing id-ordered billing syncs and payments over 121 leases; a second coordinator skips                                            | `pay_mid_run`, `bulk_policy`, `rerun`; `mut_no_skip_locked`                                  |
| `concurrency_test.sh` 5: a lease held by a user's transaction is skipped at once                                                                                     | `J_Lock` (busy: next lease)                                                                  |

None of these runs a client's own multi-row `UPDATE` of charges against the
job or a payment (F2), records a payment dated within grace after the job
ran (F1), or ends a tenancy whose later months already carry fees (F3).

## Not covered

- Rent generation, credit application and receipt numbers
  (`../LedgerPayments`); portfolio deletion and membership changes
  (`../Membership`).
- `waive_charge`: a waiver changes `waived_amount`, which the model treats
  like a payment in the guards; no scenario waives.
- The job's notifications and cleanup, which run only in a run that holds
  no lease lock.
- Changes of the rent's due day (`after_lease_due_day_update`), which move
  untouched current and future dues only.
- Time zones: the model's day is `app.today_pkt()`; that the cron schedule
  in UTC maps to Pakistan days is not modelled.
