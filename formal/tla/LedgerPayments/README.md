# Ledger: payments, receipts, credit and the billing jobs (TLA+)

A TLC-checked model of the code that records and voids payments, numbers
receipts, allocates money to dues, applies credit and creates rent. It
follows the code as it is now:

- `supabase/migrations/*.sql` in filename order, using the last definition
  of each function, trigger, index and policy. Most of the ledger is in
  `20261103193658_ledger.sql` ("ledger"); `20261104143928_ledger_jobs_hardening.sql`
  ("hardening") redefines `record_payment`, `void_payment`,
  `next_receipt_number`, `sync_lease_billing` and the daily job;
  `20261105072426_membership_deletion_storage.sql` ("membership") redefines
  `lock_lease_for_write`, `sync_portfolio_billing` and the manual-charge
  triggers; `20261105170557_concurrency_findings.sql` ("findings") has the
  last `run_daily_jobs` and `before_manual_charge_insert`;
  `20261107181820_ledger_findings.sql` ("ledger findings") fixes F1 to F3
  below: it adds `update_charge`, drops the client `UPDATE` grant and the
  `charges_update` policy on charges, and redefines `end_lease` and
  `record_payment` (its new amount + tax check and late-fee voiding change
  nothing modelled here: there are no taxes or fees in these scenarios).
- `20261105085837_lease_delete_guard.sql` and
  `20261107172908_police_registration_rules.sql` were read in full. The first
  adds a lease-delete guard; the second redefines `generate_notifications`
  and `get_dashboard`. Neither touches the rows or locks modelled here.

Deletions and membership changes are in `../Membership`, documents in
`../StorageCleanup`, late fees in `../LateFees`.

## What is modelled

One TLA+ step is one SQL statement, or one row lock of a statement that
locks rows one by one. A statement sees committed rows plus its own
transaction's writes (READ COMMITTED). A step that needs a lock another
transaction holds is disabled, so waits are explicit; after the wait,
`FOR UPDATE` and `UPDATE` see the newest committed row (EvalPlanQual).
Lease rows have `FOR UPDATE` and `FOR KEY SHARE` (foreign-key checks) with
PostgreSQL's conflict rule; every other row lock used here conflicts with
every other one, so it has one holder. An INSERT that meets an uncommitted
duplicate index entry waits for its writer, then a plain INSERT raises
`unique_violation` and `ON CONFLICT` takes its conflict path. Any error
rolls the transaction back. `SpontAbort` aborts any open transaction (a
client gone, a timeout, a 429), once per behaviour. `Blockers(p)` is the set
of transactions `p` waits for, which gives the wait-for graph.

| Model element                     | Code                                                                                                                                                                                                                           |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `RpStart`                         | `record_payment` (hardening) → `private.lock_lease_for_write` (membership): portfolio key, then the lease `FOR UPDATE`                                                                                                         |
| `RpIdem`                          | `private.replayed_payment` (hardening): `pg_advisory_xact_lock` on (portfolio, key), the lookup, the fingerprint (`payment_request_hash`) check; then `enforce_rate_limit`, the checks and `invalid_charge_selection`          |
| `RpCounter`                       | `private.next_receipt_number` (hardening): the counter upsert, its row lock held to COMMIT; `lpad(v, greatest(5, length))`                                                                                                     |
| `RpInsert`, `RpFk`                | the `payments` INSERT (`payments_receipt_number_key`, then `payments_idempotency_key`), `private.payment_requests`, the lease FK check                                                                                         |
| `AlOpen`, `AlLockPay`, `AlFetch`  | `private.allocate_payment` (ledger): payment `FOR UPDATE`, the cursor `order by array_position(p_charge_ids), due_date, id for update of c`, the allocation upsert, `paid_amount`, `allocated_amount`                          |
| `CrList`                          | `private.apply_lease_credit` (ledger): unallocated payments `order by paid_on, id`                                                                                                                                             |
| `SyStart`, `SyLock`               | `sync_portfolio_billing` (membership): the loop over active leases `order by l.id` (snapshot at the loop's start); `sync_lease_billing` (hardening): lease `FOR UPDATE`, status re-check                                       |
| `SyIns`, `SyFk`                   | `sync_lease_billing`: `max(period_month)`, the rent INSERT `on conflict (lease_id, period_month) where kind = 'rent' do nothing` (`charges_rent_period_key`), the FK check, `apply_lease_credit` when it created rent          |
| `JbStart`, `JbLock`               | `run_daily_jobs` (findings): `pg_try_advisory_xact_lock`, the loop over pending leases `order by l.id`, portfolio key and lease `for update skip locked`; `maintain_lease` (hardening); the `lease_maintenance` upsert         |
| `VoStart`, `VoPay`, `VoRev`       | `void_payment` (hardening): lease lock, payment `FOR UPDATE` (a voided payment is reported as is), the reversal in `due_date, id` order, the allocations deleted, `apply_lease_credit`                                         |
| `ElStart`, `ElVoid`               | `end_lease` (ledger findings): lease lock, `lease_not_active`, `sync_lease_billing(p_moved_out_on)`, the later live rent released (allocations reversed) and voided, `apply_lease_credit`, the lease ended                     |
| `CrStart`, `CrUpd`                | `change_rent` (ledger): lease lock, `rent_changes` upsert, untouched rent re-priced, `monthly_rent`                                                                                                                            |
| `McStart`, `McIns`                | a client's manual charge: `charges_before_insert_lock_portfolios` and `before_manual_charge_insert` (findings: portfolio key, lease `FOR UPDATE`), the INSERT, `after_manual_charge_insert` (membership: `apply_lease_credit`) |
| `CuStart`, `CuLeaseLock`, `CuRow` | a client's charge edits through `update_charge` (ledger findings): `lock_lease_for_write`, then each charge `FOR UPDATE`, `charge_voided`, `charge_not_editable`, the write, `apply_lease_credit` after an amount change       |
| `TxCommit`, `SpontAbort`          | COMMIT and the HTTP answer (PostgREST answers after COMMIT); any abort                                                                                                                                                         |
| `MUTANT`                          | one protection removed; `cu_no_lease_lock`, `cu_no_credit` and `el_no_release` are the code before the fixes of F1 to F3                                                                                                       |

Scenarios (`SCENARIO`) put two to six transactions on two leases `L1 < L2`
of one portfolio. Requests `R1a` and `R1b` are two deliveries of one
payment request; `RY` reuses its key on the same lease with the same amount
but other charges; `RX` reuses it on the other lease; `R3` chooses a later
charge; `R5` overpays. `c11` and `c21` are month-1 rent, `c13` a manual
charge due after the month-2 rent that syncs and the job create.

## Properties

| Property                    | Plain language                                                                                                        | Broken by                                                                                                                     |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `Inv1_IdemUnique`           | At most one payment per idempotency key, and never two for one request.                                               | `mut_no_idem_lock_unique`                                                                                                     |
| `Inv2_ClientContract`       | A success names the one payment of its key, created by the same request, with the receipt that was committed.         | `mut_no_request_hash`                                                                                                         |
| `Inv2_RetryNeverRejected`   | A request is refused for its key only when a different request holds the key: a retry is never refused.               | `mut_no_lease_idem_lock`, `mut_hash_per_delivery_retry`                                                                       |
| `Inv2_RejectOnlyOnConflict` | `idempotency_key_reused` only when a committed payment with the key came from a different request.                    | `mut_hash_per_delivery`                                                                                                       |
| `Inv2_DocumentedErrorsOnly` | Clients only see `app.fail` errors or a transient failure, never a raw constraint error.                              | `mut_no_idem_lock` (old finding A)                                                                                            |
| `Inv2_VoidRetrySucceeds`    | A void, and its retry, never fail except transiently.                                                                 | `mut_void_rejects_voided`                                                                                                     |
| `Inv3_ReceiptsGapless`      | Committed receipt numbers are exactly 1..N, unique, at every instant.                                                 | `mut_seq_counter`                                                                                                             |
| `Inv3_CounterMatches`       | The committed counter equals N.                                                                                       | `mut_seq_counter_counter`                                                                                                     |
| `Inv3_NoReceiptCollision`   | Issuing a receipt never collides with an earlier one.                                                                 | `mut_lpad_truncate` (old finding C)                                                                                           |
| `Inv4_ChargePaid`           | A charge's paid amount is the sum of its allocations, between 0 and its amount (never overpaid); voided means unpaid. | `mut_void_keeps_allocs_paid`                                                                                                  |
| `Inv5_PaymentAlloc`         | A payment's allocated amount is the sum of its allocations, at most amount plus tax; a voided payment has none.       | `mut_void_keeps_allocs`                                                                                                       |
| `Inv6_OneRentPerMonth`      | At most one rent charge per lease and month.                                                                          | `mut_no_sync_lock_rent_unique`                                                                                                |
| `Inv7_FIFO`                 | At every commit, a charge paid in due order is not preceded by an open charge of the same lease.                      | `mut_alloc_unordered`                                                                                                         |
| `Inv8_NoWaitCycle`          | No transaction waits, directly or through others, for itself.                                                         | `mut_sync_unordered`, `mut_mc_lock_after_fk`, `mut_job_wait_unordered`, `mut_no_sync_lock_cycle`, `mut_cu_no_lease_lock` (F1) |
| `Inv9_JobNeverWaits`        | The daily job never waits for a lock.                                                                                 | `mut_job_wait`                                                                                                                |
| `InvCreditApplied`          | Unallocated credit never sits next to an open due of the same lease.                                                  | `mut_void_no_credit`, `mut_sync_no_credit`, `mut_mc_no_credit`, `mut_no_lease_lock_voids`, `mut_cu_no_credit` (F2)            |
| `InvEndedNoUnpaidLaterRent` | An ended lease has no unpaid rent for a month after the move-out.                                                     | `mut_no_status_recheck`                                                                                                       |
| `InvEndedNoLaterRent`       | An ended lease has no live rent for a month after the move-out.                                                       | `mut_el_no_release` (F3)                                                                                                      |
| `InvRentPriced`             | Untouched rent is priced at the rent in force for its month.                                                          | `mut_cr_no_reprice`                                                                                                           |
| `TypeOK`                    | Sanity of the model's types.                                                                                          | none (no protection to remove)                                                                                                |

Some mutants are expected to pass. They show two layers, not vacuity:

- Retries on one lease: the lease lock alone (`mut_no_idem_lock_retry`) or
  the advisory key lock alone (`mut_no_lease_lock`) keeps them safe; with
  neither (`mut_no_lease_idem_lock`) a retry fails on
  `payments_idempotency_key`.
- One payment per key across leases: the advisory lock alone
  (`mut_no_idem_unique`) suffices; `mut_no_idem_lock_unique` breaks it.
- One rent per month: the index alone (`mut_no_sync_lock`) or the lease
  lock alone (`mut_no_rent_unique`) suffices; removing both breaks it.
  Without the lease lock a sync and the job can deadlock
  (`mut_no_sync_lock_cycle`), so that lock is not redundant overall.
- The daily job: `SKIP LOCKED` alone (`mut_job_unordered`) or the id order
  alone (`mut_job_wait_no_cycle`) prevents a cycle; removing both
  (`mut_job_wait_unordered`) does not. Without the try-lock two
  coordinators stay correct (`mut_job_no_try_lock`, every property).

`cfg/probe_*` (module `LedgerPaymentsProbes.tla`) show the passing runs are
not vacuous: each `Reach_*` must be violated (the model reaches a retry
returning the original, a retry after an abort, a refused reused key, waits
for the key lock and the counter, a replayed void, a void re-applying
credit, a chosen later charge, a refused choice, new rent taking credit, a
busy lease skipped, a skipped run, the job creating rent, a lease found
ended after the lock, end_lease voiding rent, end_lease releasing paid
rent, change_rent re-pricing, a manual charge taking credit, a client's
`update_charge` waiting for the lease, and a payment waiting for a lease the
job maintained earlier in its run). `Fact_NoRowLockContention` (no wait below
the lease lock, client edits included: `probe_fact_row_locks_edit`) and
`Fact_NoIdemIndexWait` (no INSERT waits on `payments_idempotency_key`) must
hold.

## The earlier findings A, B and C are fixed

The staging model of this ledger found three faults before `hardening`.
On today's code their configurations pass:

- A, a key reused on another lease failed with a raw `23505`: `keys`
  passes `Inv2_DocumentedErrorsOnly` (the advisory lock). The old code is
  `mut_no_idem_lock`, which fails it.
- B, the daily job deadlocked with the dashboard sync: `jobs` passes
  `Inv8_NoWaitCycle` and `Inv9_JobNeverWaits` (one lease at a time,
  `SKIP LOCKED`, id order). `mut_job_wait_unordered` is the old lock
  pattern.
- C, receipt 100000 rendered like 10000: `receipts` passes
  `Inv3_NoReceiptCollision` across a power of ten (the new `lpad` width).
  `mut_lpad_truncate` is the old code.

## Findings F1, F2 and F3 are fixed

The model found three faults in the code before
`20261107181820_ledger_findings.sql`. That migration fixes them; the
configurations named for each now pass, and the old code is a mutant named
for the mechanism the fix added.

### F1: a client's charge edit could deadlock a payment or a void

Severity: low. A request failed with `40P01` (no money was wrong; the retry
is idempotent).

Clients could `UPDATE` `due_date`, `amount` and `description` of charges
directly (`grant update ... to authenticated`, policy `charges_update`). The
policy took the portfolio keys first, but not the lease. A statement that
updated several charges locked them in scan order. `allocate_payment` locks
a lease's open charges in due order, and `void_payment` updates them in due
order, both under the lease lock. Two rows in opposite orders formed a cycle.

Counterexample (now `cfg/mut_cu_no_lease_lock.cfg`, 9 states, shortened):

1. `R1a`: `record_payment(L1, 2)` holds L1, reaches `allocate_payment`.
2. `CU`: `update charges set description = ... where lease_id = L1` locks
   `c13` (its scan meets it first).
3. `R1a`: the cursor locks `c11` (due first), then waits for `c13`.
4. `CU`: waits for `c11`. Cycle: `Inv8_NoWaitCycle` is violated.

On PostgreSQL 16 (`replay/run.sh`, before the fix, two runs of 4 rounds
each): `record_payment` deadlocked in 4 and 3 rounds, `void_payment` in 3
and 1. PostgreSQL chose the payment or the void as the victim in 10 of the
11 deadlocks, the client once.

Fix: clients lose the column grant and the policy; `public.update_charge`
edits one charge after `private.lock_lease_for_write` (portfolio key, then
the lease), with the rules `before_charge_update` enforced. `client_edit`
passes every property, `probe_fact_row_locks_edit` shows no wait below the
lease lock, and `probe_cu_waits` shows the edit waiting for the lease
instead. The replay now checks that a client's `UPDATE` is refused, that the
old statement's lock order (run as the table owner) still deadlocks, and
that two `update_charge` calls in one transaction never do.

### F2: raising a manual charge's amount left credit unapplied

Severity: low. The lease showed a due and an unused credit together until
the next rent was created.

Every path that opens a due applies the lease's credit (new rent, a manual
charge, a raised deposit, a void), except a client's amount edit, which had
no trigger for it. Counterexample (now `cfg/mut_cu_no_credit.cfg`, 12 states
before, shortened): `R5` overpays L1 (3 against 2 of dues: credit 1) and
commits; `CU` raises `c13` from 1 to 2 and commits. `c13` is open by 1 and
`R5` has 1 of credit: `InvCreditApplied` is violated. On PostgreSQL: open
dues 300 next to credit 500 after the edit.

Fix: `update_charge` calls `private.apply_lease_credit` after an amount
change. `client_amount` passes; the replay leaves open dues 0 and credit 200.

### F3: end_lease kept later rent that had any allocation

Severity: low to medium. An ended lease kept a live rent due for a month
after the move-out; it could stay half unpaid.

`end_lease` voided rent after the move-out month only when
`paid_amount = 0`. Rent the tenant paid in advance, or that the billing sync
paid from credit on the first of the month, survived the end. Counterexample
(now `cfg/mut_el_no_release.cfg`, 20 states, shortened): the job creates
L2's month-2 rent; `R2` pays `c21` and that rent; `EL` ends L2 with move-out
in month 1 and voids nothing: `InvEndedNoLaterRent` is violated. On
PostgreSQL: a payment of 1500 against October's 1000 left 500 credit; the
November sync applied it to November's rent; `end_lease(..., '2026-10-31')`
left the lease `ended` with November's rent live, 500 paid and 500
outstanding.

Fix: `end_lease` reverses the allocations of rent after the move-out month
(as `void_payment` does: `paid_amount`, `payment_allocations`,
`payments.allocated_amount`), voids that rent (and, from `../LateFees` F3,
its automatic late fees), then calls `apply_lease_credit`, so the money pays
the lease's other open dues or stays as credit. `lifecycle` passes every
property and `probe_end_releases` shows paid rent being released; the
replay voids November's rent and leaves its 500 as credit.

## Bounds, abstractions and why they are adequate

- One portfolio, two leases, one receipt year, the current month is month 2. Every rule here relates one lease's rows, plus two portfolio-wide
  rows: the receipt counter and an idempotency key. Two leases are enough
  for every cross-lease interaction (a key on two leases, two leases locked
  in opposite orders, a job holding one lease while it works on another).
  Each scenario puts two to six transactions on these rows.
- Amounts are small integers and each cursor has at most five rows, under
  the PL/pgSQL FOR loop's prefetch of ten, so a cursor locks all its rows
  before the first iteration, as on PostgreSQL.
- The portfolio key is never contended here: only deletions and membership
  changes take it `FOR UPDATE` (`../Membership`).
- Rate-limit buckets (`enforce_rate_limit`, the `app.check_request` hook)
  are not locks here. A bucket is one row per key and window, so requests
  in different windows never share one, and leaving a lock out only adds
  interleavings. A bucket cannot close a cycle: each transaction takes at
  most one per action, before the counter, and none waits for a later
  bucket. A 429 is a `SpontAbort`.
- Statements under a lock that excludes every other writer of the same rows
  are merged into one step; each merge is commented. The charge-selection
  check is merged with the key lookup: a client edit can only raise an
  amount, which keeps a charge open.
- `CU` makes its two `update_charge` calls in one transaction, holding the
  lease across both. Through PostgREST each call is its own transaction, which
  only releases the lease in between; each call alone takes the lease before
  its charge, so neither form can wait for a row while holding one out of
  order. The mutant `cu_no_lease_lock` keeps the two rows in one statement,
  as the old client `UPDATE` did.
- Waiters are not queued among themselves. With one global order a queue
  cannot close a cycle; the old manual-charge upgrade
  (`mut_mc_lock_after_fk`) breaks the order and is caught without queues.
- A failed lease in the daily job rolls back its subtransaction; the job
  writes only that lease's rows there, so the state is that of a skipped
  lease, which the model covers.
- Payments are paid on the same day; `apply_lease_credit`'s order is then
  the id order, a fixed rank here.

## How to run

```sh
formal/tla/LedgerPayments/run.sh ci     # 28 configurations, about 1 to 2 minutes
formal/tla/LedgerPayments/run.sh all    # 72 configurations, about 5 to 10 minutes
formal/tla/LedgerPayments/run.sh all mut_job   # only names containing "mut_job"
formal/tla/LedgerPayments/replay/run.sh       # F1-F3 fixed, on PostgreSQL 16
```

It works from any directory. `TLA2TOOLS` points to `tla2tools.jar` (TLC
2.19; default from `.cache/formal/env.sh`, which `tool/formal/install.sh`
writes, else `.cache/formal/tla2tools.jar` in the repository); `java` must
be on `PATH`. `TLC_JOBS` (default 2) configurations run at once with
`TLC_WORKERS` (default 1) workers each. Scratch goes under `${TMPDIR:-/tmp}`
and is kept when a configuration does not match (`KEEP_LOGS=1` keeps it
always). Each `cfg/*.cfg` states its expected outcome (`\* EXPECT:`), mode
(`\* MODE:`) and, for probes, module (`\* SPEC:`). A result that differs in
either direction fails the run.

`replay/run.sh` rebuilds the disposable database `mm_fv_ledger` with every
migration (`tool/db/reset.sh`, connection from `tool/db/env.sh`), adds a test
helper named `fv_lease` there only, and fails unless a client's `UPDATE` of
charges is refused, the old statement's lock order (run as the table owner)
deadlocks at least once against each ledger call while `update_charge` never
does, and F2 and F3 no longer show. `RUNS` sets F1's rounds (default 4).

## Expected results

Measured on this machine (4 CPUs shared with other jobs; 2 jobs × 1
worker), after `20261107181820_ledger_findings.sql`:

- `run.sh ci`: 28/28 as expected in 34 s wall. The largest is `jobs`
  (36,478 distinct states).
- `run.sh all`: 72/72 as expected in 162 s wall. The largest are `core` and
  `probe_fact_row_locks` (71,950 distinct states).
- Expected violations: every `mut_*` except the eight named above (among
  them `mut_cu_no_lease_lock`, `mut_cu_no_credit` and `mut_el_no_release`,
  the code before F1 to F3 were fixed), and every `probe_*` except the four
  `Fact_*` ones.
- `replay/run.sh`: exit 0 in 45 s; the old lock order deadlocked in 3 of 4
  rounds against `record_payment` and against `void_payment`, `update_charge`
  in none of 8.

## Cross-check with the executable tests

| Executable test                                                           | Here                                                                        |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `concurrency_test.sh` 1: 40 payments, receipts 1..40                      | `Inv3_*` in every configuration; `receipts`, `mut_seq_counter*`             |
| 29: `update_charge` racing payments and voids on one lease                | `client_edit`, `probe_fact_row_locks_edit`; `mut_cu_no_lease_lock`          |
| 2: 25 retries of one key, one receipt                                     | `retry`; `probe_retry_*`; `mut_no_lease_idem_lock`                          |
| 3: billing syncs racing payments                                          | `core`, `syncs`; `mut_sync_unordered`, `mut_no_sync_lock_rent_unique`       |
| 4, 5: the daily job racing syncs and payments; a busy lease skipped       | `jobs`, `lifecycle`; `probe_job_busy`, `probe_job_try_lock`; `mut_job_*`    |
| 6: one key on two leases                                                  | `keys`; `mut_no_idem_lock`, `mut_no_idem_lock_unique`                       |
| 15: manual charges and payments on one lease                              | `manual`; `mut_mc_lock_after_fk`                                            |
| 30: paid = Σ allocations, allocated = Σ allocations, nothing overpaid     | `Inv4_ChargePaid`, `Inv5_PaymentAlloc` in every configuration               |
| `05_ledger.test.sql`: key reuse, void retry, receipt 100000, credit paths | `Inv2_*`, `Inv2_VoidRetrySucceeds`, `mut_lpad_truncate`, `InvCreditApplied` |
| `13_ledger_contract.test.sql`: allocation order and credit                | `Inv7_FIFO`, `InvCreditApplied`; `mut_alloc_unordered`                      |

No executable test exercised a client's charge UPDATE against the ledger,
an amount edit next to credit, or `end_lease` after credit paid later rent,
which is why F1 to F3 were not seen. Now `17_ledger_findings.test.sql`
covers `update_charge` (roles, rules, credit) and `end_lease` releasing paid
rent, and `concurrency_test.sh` 29 races two `update_charge` calls against
payments and voids on one lease (8 rounds, no deadlock).

## Not covered

- Late fees (`assess_late_fees`, `../LateFees`), deposits (`apply_deposit`,
  refunds, the deposit trigger, `deposit_already_used`), `waive_charge`,
  `void_charge`, utility bills. They take the lease lock first, like the
  writers here; their arithmetic is in the pgTAP suites.
- More months, leases or portfolios; receipt numbering across a year
  boundary (each year has its own counter row).
- Edits of `due_date` (`update_charge`), which re-order dues after they were
  paid; `Inv7_FIFO` judges each allocation when it commits.
- Deletions and membership changes (`../Membership`), the notification and
  cleanup part of the daily job, and timing (the job's batches, the pg_cron
  schedule).
- How long a user's write waits for a lease the job maintained earlier in
  the same run (`probe_user_waits_for_job`): the job holds every lease of
  its batch (up to 500) until it commits.
