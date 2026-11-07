# Bend proofs: the ledger's money algorithms

Machine-checked proofs, in [Bend 2](https://bend-lang.com), of the arithmetic
behind payment allocation, even splits, half-up rounding, proration, the rent
the ledger bills and daily late fees. The algorithms are modelled as Bend
functions over `Nat` (amounts in whole paisa). Each model follows the current
Dart and SQL code step by step and cites it.

Results in short:

- `bend PROOF.bend --verdict` prints `ALL PROOFS CHECK` for all 35 laws.
- The soundness checks pass: every law has exactly one proof, the kernel
  checks each law exactly as written, and nothing uses `@unsafe`, a partial
  def or a hole. 31 model mutants and 10 gate mutants are all rejected.
- The models match the real code on every case tried: 360 Bend evaluations,
  113,601 runs of the real Dart and 412,032 result rows of the real SQL.
- No finding against the current code. The three findings of the earlier
  audit are fixed in the code, and the laws now prove the fixed behaviour
  (see "Findings").

## Files

| File                           | What it is                                                                                         |
| ------------------------------ | -------------------------------------------------------------------------------------------------- |
| `SPEC.bend`                    | Executable models of the algorithms. Each cites the code it follows.                               |
| `LAWS.bend`                    | The 35 laws (claims) about the models, in plain language.                                          |
| `PROOF.bend`                   | The proofs: an arithmetic and division library, then one `def Laws.<name>` per law.                |
| `run.sh`                       | Runs every check and compares each with its expected outcome.                                      |
| `soundness/check_soundness.py` | Compares each law with the statement the kernel checks; looks for escape hatches.                  |
| `soundness/USE.bend`           | Every law applied to concrete inputs: no law has hypotheses that cannot hold together.             |
| `soundness/NEG.bend`           | For every hypothesis, an input where it fails and the conclusion is false: no hypothesis is spare. |
| `soundness/mutants.py`         | Writes the model mutants (with counterexamples) and the gate mutants.                              |
| `fidelity/spec.py`             | A line-by-line Python transliteration of `SPEC.bend`.                                              |
| `fidelity/gen_cases.py`        | Writes the inputs of the differential checks (Bend, Dart, SQL).                                    |
| `fidelity/dart_cases.dart`     | Runs the real `mm_core` code on those inputs.                                                      |
| `fidelity/compare.py`          | Compares Bend's, Dart's and PostgreSQL's results with `spec.py`.                                   |
| `fidelity/spec_mutants.py`     | Mutants of `spec.py` that the differential checks must catch.                                      |

## How to run

```sh
formal/bend/run.sh ci     # the verdict only: must be green (about 10-15 s)
formal/bend/run.sh all    # verdict, soundness, mutants and fidelity (about 5 minutes)
```

`run.sh` works from any directory and writes only below a fresh directory in
`${TMPDIR:-/tmp}`. It needs:

- Bend 2.0.39 (`BEND`) and Lean 4.34.0 (`LEAN434_HOME`): `--verdict`
  builds BendTT's kernel with that Lean, once, into `~/.bend/bendtt`.
  `tool/formal/install.sh` (`make formal-install`) installs both, pinned
  and checksum-verified, and writes `.cache/formal/env.sh`, which `run.sh`
  reads. Without it, `run.sh` takes `bend` and `lean` from `PATH` and
  checks their versions.
- For `all` only: Dart with the resolved pub workspace (`DART`, default
  `dart` on `PATH`, then `/opt/flutter/bin/dart`; run `make bootstrap`
  first), and a PostgreSQL 16 server (`PGHOST`, `PGPORT`, `PGUSER`, defaults
  from `tool/db/env.sh`). The run creates the database `fvbend_<pid>` (or
  `FVBEND_DB`) with `tool/db/reset.sh` and drops it at the end.

Each step prints one row: `OK` when the outcome is the expected one,
`MISMATCH` otherwise. A mismatch in either direction fails the run, so a
mutant that is not caught fails it too.

| Step                     | Expected outcome                                                                                    |
| ------------------------ | --------------------------------------------------------------------------------------------------- |
| `verdict`                | `ALL PROOFS CHECK`, exit 0                                                                          |
| `soundness`              | `SOUNDNESS CHECKS PASS`                                                                             |
| `use`, `neg`             | `ALL PROOFS CHECK` (with `--verdict`)                                                               |
| `mutant:<name>`          | `SOME PROOFS FAIL`, exit 1, with the named location or reason                                       |
| `cex on mutant`          | `ALL PROOFS CHECK`: the counterexample holds for the mutated model                                  |
| `cex on the real model`  | `SOME PROOFS FAIL`: the counterexample does not hold for the real model                             |
| `fidelity:bend/dart/sql` | `FIDELITY: all parts match` (0 mismatches)                                                          |
| `fidelity mutant:<name>` | `MUTANT CAUGHT`: each part the mutant should break reports mismatches against the real Dart and SQL |

Timings on the shared 4-CPU machine (other agents running): `ci` 10-11 s.
`all` runs 114 steps in 189 s (303 s under heavier load): verdict 13 s,
`use` 16 s, `neg` 5 s, each of the 41 mutants 0-4 s, and the fidelity
checks about 20 s (Bend evaluation 5 s, Dart 3 s, scratch database and SQL
7 s, comparisons and fidelity mutants 1-2 s each).

## What is modelled

Each SQL function is modelled from its last definition across
`supabase/migrations/*.sql` (checked up to `20261107172908`).

| Model (`SPEC.bend`)                      | Code                                                                                                                                                                                                                                                    |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `alloc`, `unallocated`                   | SQL `private.allocate_payment` (`20261103193658_ledger.sql`); Dart `planFifoAllocation` (`packages/mm_core/lib/src/ledger/allocation.dart`)                                                                                                             |
| `settle`, `paid_to`, `outstanding`       | `charges.paid_amount` update and generated `outstanding`; `private.apply_lease_credit` (`20261103193658_ledger.sql`)                                                                                                                                    |
| `split_evenly`, `split.bump`             | Dart `Money.splitEvenly` = `allocate(List.filled(count, 1))` (`packages/mm_core/lib/src/money/money.dart`)                                                                                                                                              |
| `half_up`                                | Dart `divideRounded(n, d, RoundingMode.halfUp)` for n >= 0, d > 0                                                                                                                                                                                       |
| `round_half`                             | SQL `round(n / d, 0)`, which is (2n + d) div 2d                                                                                                                                                                                                         |
| `multiply_to_rupee`, `prorated_rent`     | Dart `Money.multiplyToStep` and `RentMath.proratedRent` (`packages/mm_core/lib/src/rent/rent_math.dart`), now capped with `Money.min(monthlyRent, ...)`                                                                                                 |
| `billed_rent`                            | Dart `RentMath.billedRent` (new): nothing before the billing-start month, the full rent after it or with `prorateFirstMonth` off                                                                                                                        |
| `prorated_rent_sql`                      | SQL `app.prorated_rent` (`20261104143928_ledger_jobs_hardening.sql`), now `least(p_rent, round(...))`                                                                                                                                                   |
| `billed_rent_sql`                        | `private.sync_lease_billing` (`20261104143928_ledger_jobs_hardening.sql`): `case when prorate_first_month then app.prorated_rent(...) else v_rent end`; the same `case` in `public.change_rent`; `public.end_lease` bills the move-out month through it |
| `daily_fee`, `cap_fee`, `daily_late_fee` | Dart `DailyLateFee.computeFee` (clamped at `LateFeePolicy.maxFee`), `DailyLateFee.capFee`, `Money.roundToRupee`, `LateFeePolicy.feeFor` (`packages/mm_core/lib/src/rent/late_fee_policy.dart`)                                                          |
| `daily_late_fee_sql`                     | SQL `app.late_fee_amount`, `p_type = 'daily'` (`20261104143928_ledger_jobs_hardening.sql`): `least(round(p_value * p_days_late, 0), coalesce(p_cap, 999999999999), 999999999999)`                                                                       |

`maxFee` (Rs 999,999,999,999, the SQL literal) is a parameter `top` of the
fee models, not a literal: Base's `Nat` is unary. The laws hold for every
`top`, or every whole-rupee `top` where that matters, so for the real one.
The fidelity checks run the real value.

## What is proven (all 35 laws)

- **Vocabulary**: `Spec.LE` is exactly Base's `Nat.is_le` (`le_is_base_le`,
  `base_le_is_le`).
- **FIFO allocation** (SQL and Dart; for every list of charges, so every
  order and selection)
  - Allocated + unallocated = payment (`fifo_conserves`).
  - Allocated <= payment (`fifo_allocated_le_payment`, i.e.
    `payments_allocation_check`).
  - No charge gets more than it owes (`fifo_bounded`, i.e.
    `charges_not_overpaid_check`).
  - A leftover means every charge was paid in full
    (`fifo_leftover_settles_all`).
  - A charge receives money only after every earlier charge is settled
    (`fifo_order`).
  - Every allocation row is positive (`fifo_rows_positive`, i.e.
    `payment_allocations_amount_check`).
  - Payments applied one after another never overpay: for two
    (`fifo_two_payments`) and for any number, with paid + still outstanding
    = owed for every charge (`fifo_payments_conserve`,
    `fifo_payments_never_overpay`).
- **Even split**: `count` parts (`split_count`) that sum to the amount
  (`split_sum`), any part at most 1 paisa above any other (`split_fair`).
- **Half-up division**
  - q = (2a + b) div 2b satisfies 2bq <= 2a + b (`round_half_lower`) and,
    for b > 0, 2a + b < 2b(q + 1) (`round_half_upper`).
  - Dart's `divideRounded(halfUp)` equals SQL's `round(n / d, 0)` for every
    n >= 0, d > 0 (`half_up_agrees`).
- **Proration** (Dart `proratedRent`)
  - A full month bills the rent (`prorate_full_month`); no day bills 0
    (`prorate_no_days`).
  - The bill never exceeds the rent, for any rent (paisa included) and any
    number of days (`prorate_le_rent`).
  - The bill is within 50 paisa of the exact share rent x days / len:
    at most 50 paisa above it (`prorate_near_exact_upper`) and, for days <=
    len, at most 50 paisa below it (`prorate_near_exact_lower`).
  - Regression vector: Rs 1.99 for 30 of 31 days is billed Rs 1.99, not
    Rs 2.00 (`prorate_paisa_rent_capped`).
  - SQL `app.prorated_rent` prices the billing-start month exactly as Dart
    prices the days from `billing_starts_on` to the month's end
    (`prorate_sql_matches_dart`).
- **The rent the ledger bills**
  - Dart's `RentMath.billedRent` equals the ledger's rule for every month
    from the billing-start month on, both values of `prorate_first_month`
    and every start day; this includes the move-out month, which both bill
    in full (`billed_rent_matches_ledger`).
  - Dart bills nothing before the billing-start month
    (`billed_rent_before_start`).
  - With `prorate_first_month` set, the ledger bills the first month as
    `proratedRent` prices an open-ended occupancy
    (`billed_first_month_matches_dart`), and every later month in full,
    whatever part of it is occupied (`billed_later_month_full`).
- **Daily late fee**
  - No fee when nothing is overdue (`late_fee_nothing_overdue`) or within
    the grace period (`late_fee_in_grace`).
  - The fee is monotone in the days late (`late_fee_monotone`).
  - The fee never exceeds its cap, for any cap (paisa included)
    (`late_fee_le_cap`), and never exceeds `maxFee` (`late_fee_le_max`).
  - Regression vector: Rs 1.00 a day capped at Rs 2.50, 8 days late after
    5 days of grace, is charged Rs 2.50, not Rs 3.00
    (`late_fee_paisa_cap_capped`).
  - SQL and Dart compute the same fee whenever `maxFee` is a whole number
    of rupees, as it is (`late_fee_sql_matches_dart`).

## Soundness and non-vacuity

- **The kernel.** `--verdict` checks every proof, then checks it again with
  BendTT, Bend's kernel, which has a correctness proof in Lean. An open law,
  a wrong proof, `@unsafe` or a partial def makes it print
  `SOME PROOFS FAIL` and exit 1.
- **The statements.** `check_soundness.py` exports the kernel program
  (`bend PROOF.bend -o PROOF.bendtt`), translates each law of `LAWS.bend`
  to BendTT's notation and compares the two texts. All 35 are identical, so
  every proof proves the law as written, not a weaker one. It also checks
  that `PROOF.bend` has exactly one `def Laws.<name>` per law and no
  escape hatch.
- **Hypotheses.** `USE.bend` applies every law to concrete inputs with
  concrete proofs of its hypotheses (35 calls), so no law is vacuous.
  `NEG.bend` shows, for every hypothesis, an input where only it fails and
  the conclusion is false (22 checked facts). The audit found two spare
  hypotheses (`i < n` in `split_fair`, `b > 0` in `round_half_lower`); they
  were dropped, which makes those laws stronger.
- **Model mutants (31).** Each removes one mechanism of the code from
  `SPEC.bend`: the cap in proration, the SQL `least`, the `exit` of the
  allocation loop, rounding before capping, the `prorateFirstMonth` flag,
  the `maxFee` clamp, and so on. For each, the proofs fail, and a
  counterexample (`CEX.bend`) is proven by evaluation on the mutant and
  refuted on the real model. Together they break every one of the 35 laws.
- **Gate mutants (10).** An open law, a bogus proof, `@unsafe` (with
  `--check-only` and with `--verdict`), a partial def, a missing proof, a
  `?TODO` hole, a proof that redefines a model, a proof that restates its
  law with a weaker type (Bend does not even parse a type on a law's proof)
  and a swapped hypothesis. All are rejected.

## Fidelity: the models against the real code

`SPEC.bend` is compared with the code through `fidelity/spec.py`, its
transliteration:

1. **Bend against `spec.py`.** Bend evaluates `SPEC.bend` on 360 small
   inputs (every model function); all equal `spec.py`.
2. **The real Dart against `spec.py`.** `dart_cases.dart` runs `mm_core`:
   20,000 FIFO plans (chosen charges, deposit adjustments), 3,601 splits
   (negative amounts too), 20,000 `divideRounded` calls (up to 10^18),
   20,000 `proratedRent` calls on real calendar dates (bounded and
   open-ended occupancies, so `occupiedDays` is checked too), 20,000
   `billedRent` calls and 30,000 `DailyLateFee.feeFor` calls. 0 mismatches.
3. **The real SQL against `spec.py`**, on a scratch database with every
   migration applied:
   - `app.prorated_rent`: 171,336 rows (88 rents up to Rs 999,999,999,999.99,
     every month 2024-2028, every start day); 160,776 billing-start months
     are also checked against the Dart model.
   - `app.late_fee_amount` (daily): 238,464 rows, checked against both the
     SQL and the Dart model.
   - `private.allocate_payment` and `private.apply_lease_credit`: 120
     leases, 362 payments; 415 allocation rows, 362 unallocated amounts and
     467 outstanding amounts.
   - The lease insert trigger (`private.sync_lease_billing`),
     `public.change_rent` and `public.end_lease`: 150 leases (68 rent
     changes, 59 move-outs, 50 without `prorate_first_month`), 988 rent
     charges including 169 voided ones.
     All 0 mismatches.
4. **The checks have teeth.** Four `spec.py` mutants (the SQL without
   `least`, capping before rounding, `billedRent` without its flag, an
   allocation loop with a limit) each produce mismatches against the real
   Dart and SQL.

## Bounds, abstractions and why they are adequate

- **The proofs have no bounds.** Every law is proven for all naturals and
  all lists, so for every amount, every number of charges and payments and
  every order. Nothing is model-checked up to a size.
- **Non-negative amounts.** `Nat` models amounts >= 0, which is all these
  algorithms receive (payments >= 0, outstanding > 0, rents and rates >= 0).
  `splitEvenly` of a negative amount splits the magnitude and negates every
  part; this step is checked by the Dart fidelity runs, not proven.
- **No overflow.** `Nat` is unbounded. `numeric(14,2)` holds below 10^14
  paisa, below 2^53, and Dart's `int` is 64-bit on the VM; the fidelity runs
  use values up to these limits.
- **Inputs, not code.** The charge order and selection, days occupied,
  month lengths and the billing-start day are inputs of the models. The
  laws hold for every value, so for every order and every date. The date
  arithmetic itself (`occupiedDays`, `MonthPeriod`, `date_trunc`) is
  checked only by the fidelity runs on real dates.
- **The billing walk.** The models price one month. The walk over months
  in `sync_lease_billing`, the rent in force from `rent_changes`,
  `on conflict do nothing`, the re-pricing in `change_rent` and the voiding
  in `end_lease` are checked by the SQL fidelity run (988 charges), not
  proven. Since `20261107181820_ledger_findings.sql`, `end_lease` also
  releases and voids paid rent of later months; the fidelity leases have no
  payments, so the rent it voids is the same (`17_ledger_findings.test.sql`
  checks the release).
- **SQL division.** The model rounds the exact quotient. PostgreSQL
  computes `p_rent * days / dim` to at least 8 decimal places for any
  storable rent (`999999999999.99 * 30 / 31` gives
  `967741935483.86129032`), so its error is below 0.000000005. The exact
  quotient's fraction is j / (100 * dim); unless it is exactly 1/2 it is at
  least 1 / 6200 away from 1/2 (dim <= 31). So `round(..., 0)` cannot
  change. This is a paper argument; the 171,336 SQL rows, with rents up to
  the column maximum, agree with it.
- **Fuel.** Bend's `Nat` is unary, so concrete evaluations (counterexamples,
  regression vectors, the Bend fidelity run) use small amounts. Large
  amounts are covered by the Dart and SQL runs.

## Findings

None against the current code. The earlier audit (written before
`20261104143928_ledger_jobs_hardening.sql`) had three; the code has fixed
all three, and the laws now prove the fixed behaviour:

1. **Proration above the rent (fixed).** Both `RentMath.proratedRent` and
   `app.prorated_rent` now cap the rounded amount at the rent. The law
   `prorate_le_rent` now holds for any rent; it used to need a whole-rupee
   rent. The old counterexample (Rs 1.99 over 30 of 31 days billed
   Rs 2.00) is now the regression law `prorate_paisa_rent_capped`, and the
   mutants `prorate_no_cap` and `sql_prorate_no_least` reproduce the old
   behaviour.
2. **A daily fee above its cap (fixed).** Both sides now round to whole
   rupees first and cap afterwards, so `late_fee_le_cap` holds for any cap.
   The old counterexample (cap Rs 2.50 charged Rs 3.00) is now
   `late_fee_paisa_cap_capped`. Both sides also clamp the fee at `maxFee`,
   proven by `late_fee_le_max`.
3. **Preview against ledger (fixed).** Dart now has `RentMath.billedRent`,
   the ledger's own rule, and `billed_rent_matches_ledger` proves the two
   equal for every month, including the move-out month and with
   `prorate_first_month` off.

Two observations, not defects:

- `RentMath.proratedRent` still prorates a move-out month by the days
  occupied, while the ledger bills it in full. `billedRent`'s doc comment
  says this is deliberate. A preview of the ledger must use `billedRent`,
  not `proratedRent`. The class comment ("a preview never disagrees with the
  ledger") holds for `billedRent` only.
- For daily fees the final `Money.min(..., maxFee)` in `feeFor` (and the
  third argument of the SQL `least`) never changes the result:
  `computeFee` already clamps at `maxFee`, and a whole-rupee `maxFee`
  rounds to itself. It matters for flat and percent fees.

## What is not covered

- Locking, transactions, retries and idempotency: the TLA+ track covers
  them (`formal/tla`).
- Flat and percent late fees, `incrementedRent`, `roundToStep` with other
  steps, the general `allocate(ratios)` and `Money.percentage`.
- The order in which charges are visited and which charges are eligible:
  the laws hold for every list, and the fidelity runs check the code's
  order; the order itself is not a proven property.
- The late-fee job (`private.assess_late_fees` and its `on conflict`
  update), which decides when a fee is charged; only the amount is
  modelled.
