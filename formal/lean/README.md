# Money and rent arithmetic (Lean 4)

Machine-checked proofs about the money arithmetic of `packages/mm_core` and
the SQL it mirrors. The model is plain Lean 4.35.0 with no Mathlib and no
network, so `lake build` works offline. Amounts are `Int` paisa, exactly as
the Dart holds them (`Money.paisa`; products in `BigInt`). Dates are
year, month and day, as in `CalendarDate`.

The Z3 checks that every value fits its machine type, and that PostgreSQL's
inexact `numeric` division never changes a result, are in
[`../smt`](../smt/README.md). One runner, `run.sh`, checks both.

## What is modelled

Every definition cites the code it follows. The code is read as it is now;
for SQL that is the last definition across `supabase/migrations`.

| Lean                                                                                   | Code                                                                                                          |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `RoundingMode`, `divideRounded`, `roundKernel`                                         | `money.dart` `enum RoundingMode`, `divideRounded` (truncating `~/`, signed `remainder`)                       |
| `sqlRound`                                                                             | PostgreSQL `round(numeric, 0)`: nearest, ties away from zero                                                  |
| `pgScaledRound`                                                                        | PostgreSQL `round(a / b, 0)` when `div_var` first rounds `a / b` to its result scale                          |
| `multiply`, `multiplyToStep`, `percentage`, `roundToStep`, `roundToRupee`              | `Money.multiply`, `multiplyToStep`, `percentage`, `roundToStep`, `roundToRupee`                               |
| `allocBase`, `allocRems`, `remLe`, `remainderOrder`, `bump`, `allocate`, `splitEvenly` | `Money.allocate` (floors, remainders, the sort, the leftover loop), `Money.splitEvenly`                       |
| `Date`, `daysInMonth`, `Date.before`, `addMonths`                                      | `CalendarDate`, `daysInMonth`, `isBefore`, `addMonths`                                                        |
| `dueDate`, `billingDueDate`                                                            | `RentMath.dueDate`, `billingDueDate`                                                                          |
| `sqlDueDate`                                                                           | `app.due_date_for` (`20261103193403_leases.sql`)                                                              |
| `occupiedDays`, `proratedRent`, `billedRent`                                           | `RentMath.occupiedDays`, `proratedRent`, `billedRent`                                                         |
| `sqlProratedRent`, `pgProratedRent`                                                    | `app.prorated_rent` (`20261104143928_ledger_jobs_hardening.sql`), exact and with PostgreSQL's division scale  |
| `sqlBilledRent`                                                                        | the amount `private.sync_lease_billing` (`20261104143928`) bills for a month                                  |
| `nextAnniversary`                                                                      | `RentMath.nextAnniversary` (checked against the vectors only)                                                 |
| `LateFeePolicy`, `computeFee`, `capFee`, `feeFor`, `maxFee`                            | `late_fee_policy.dart` (`NoLateFee`, `FlatLateFee`, `PercentLateFee`, `DailyLateFee`, `feeFor`, `maxFee`)     |
| `sqlLateFee`                                                                           | `app.late_fee_amount` (`20261104143928`)                                                                      |
| `OpenCharge`, `dartRank`, `chargeLe`, `orderCharges`, `dartLoop`, `planFifo`           | `allocation.dart` `OpenCharge`, `planFifoAllocation` (rank, sort, loop)                                       |
| `sqlRank`, `sqlLoop`, `sqlAllocate`                                                    | `private.allocate_payment` (`20261103193658_ledger.sql`): `array_position` rank, `exit when v_remaining <= 0` |
| `Vectors.checkAll`, `Main.lean` (`check-vectors`)                                      | `contracts/rent_math_vectors.json` (from `tool/contracts/generate.py`)                                        |

## What is proven

Each theorem holds for every input of the stated kind, not for samples.
`d > 0` theorems cover every non-zero denominator through
`divideRounded_neg`, which is exactly how the Dart normalises a negative one.

| Theorem                                                          | In plain language                                                                                                                     |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `floor_spec`, `ceiling_spec`, `down_spec`, `up_spec`             | Each mode meets its defining inequalities, for numerators of either sign.                                                             |
| `halfUp_spec`, `halfEven_spec`                                   | Half-up is the nearest integer with ties away from zero; half-even is nearest with ties to the even neighbour.                        |
| `divideRounded_neg`                                              | A negative denominator gives the same result as negating both operands.                                                               |
| `halfUp_eq_sqlRound`                                             | Dart half-up equals SQL `round(n / d, 0)` for every `n` and every `d > 0`.                                                            |
| `double_round`, `pgScaledRound_eq`                               | Rounding first to `s` decimals and then to an integer is harmless once `10^s` exceeds the denominator.                                |
| `multiplyToStep_halfUp`, `multiplyToStep_within_step`            | `multiplyToStep` is a whole number of steps, within half a step (half-up) or one step (any mode) of the exact product.                |
| `multiplyToStep_eq_sql`, `roundToRupee_eq_sql`                   | Half-up `multiplyToStep` to rupees, and `roundToRupee`, are SQL `round(_, 0)` in rupees.                                              |
| `roundToRupee_bounds`, `roundToRupee_whole`, `roundToRupee_min`  | Whole rupees within 50 paisa; whole rupees are unchanged; capping at whole rupees commutes with rounding.                             |
| `allocate_sum`, `splitEvenly_sum`                                | The parts always add up to the amount.                                                                                                |
| `allocate_part`                                                  | Each part is its exact share rounded down, or one paisa more, with the amount's sign.                                                 |
| `allocateNat_largest_remainder`                                  | The extra paisa go to the largest remainders.                                                                                         |
| `splitEvenly_close`                                              | Any two parts of `splitEvenly` differ by at most one paisa.                                                                           |
| `dueDate_eq_sql`                                                 | Dart and SQL due dates agree and are a real day of the month.                                                                         |
| `proratedRent_bounds`, `billedRent_bounds`                       | `0 <= prorated <= rent` and `0 <= billed <= rent` for any rent `>= 0`.                                                                |
| `proratedRent_whole_month`, `proratedRent_started_before`        | A month billed from the 1st, or a tenancy that started earlier, costs the whole rent.                                                 |
| `proratedRent_eq_sql`, `billedRent_eq_sql`                       | Dart proration and billed rent equal `app.prorated_rent` and `sync_lease_billing`.                                                    |
| `pgProratedRent_eq`                                              | PostgreSQL's inexact division does not change the prorated rent at any result scale `>= 4` (formal/smt shows it is `>= 8`).           |
| `feeFor_zero`                                                    | No fee within the grace period or when nothing is overdue.                                                                            |
| `feeFor_le_maxFee`, `feeFor_le_cap`                              | A fee never exceeds Rs 999,999,999,999 nor a daily fee's cap.                                                                         |
| `feeFor_nonneg`, `feeFor_mono`                                   | Fees are never negative and never fall as the days late grow.                                                                         |
| `feeFor_eq_sql`                                                  | Dart `feeFor` equals `app.late_fee_amount` for every policy the CHECK constraints admit.                                              |
| `planFifo_conserves`, `planFifo_credit_bounds`                   | Allocations plus credit equal the payment; the credit is between nothing and the payment.                                             |
| `planFifo_pays`                                                  | The i-th allocation pays the i-th charge in order, a positive amount no larger than it owes: no overpayment.                          |
| `planFifo_full_before_last`, `planFifo_credit_after_all`         | Only the last allocation can be partial; credit is left only after every payable charge is paid in full.                              |
| `orderCharges_sorted`, `orderCharges_mem`, `planFifo_no_deposit` | Charges go chosen-first, then oldest due date, then id; every open charge is considered; a deposit adjustment never pays the deposit. |
| `planFifo_eq_sql`                                                | The Dart preview is exactly `private.allocate_payment`, for fewer than 2^31 - 2 chosen ids.                                           |

`Axioms.lean` prints the axioms of these 44 theorems. Every one depends only
on `propext`, `Classical.choice` and `Quot.sound` (some on fewer). The
sources contain no `sorry`, `axiom`, `native_decide`, `implemented_by`,
`partial` or `unsafe`; `run.sh` checks both.

`check-vectors` runs all 71 contract vectors (due dates, billing due dates,
proration, billed rent, anniversaries, late fees, allocation) through both
the Dart and the SQL model. `run.sh` also feeds it a copy with one expected
value changed, which it must reject.

## Mutants

`mutants.py` changes one definition the way a plausible bug would.
`run.sh all` builds each one in a scratch copy. It expects the first error
inside the named theorem, or (where no theorem covers the change) a vector
mismatch.

| Mutant                         | Change                                          | Expected                    |
| ------------------------------ | ----------------------------------------------- | --------------------------- |
| `halfup_ties_to_zero`          | half-up ties go toward zero                     | `halfUp_spec` fails         |
| `halfeven_odd`                 | half-even ties go to the odd neighbour          | `halfEven_spec` fails       |
| `floor_rounds_up`              | floor rounds a positive quotient up             | `floor_spec` fails          |
| `sql_round_half_down`          | the SQL model rounds ties down                  | `halfUp_eq_sqlRound` fails  |
| `allocate_no_leftover`         | the leftover paisa are not handed out           | `allocateNat_sum` fails     |
| `allocate_smallest_remainders` | the sort puts the smallest remainders first     | `bumped_largest` fails      |
| `prorated_no_cap`              | no `Money.min(monthlyRent, ...)`                | `proratedRent_bounds` fails |
| `due_day_clamped_to_28`        | due day clamped to 28, not the month length     | `dueDate_eq_sql` fails      |
| `anniversary_inclusive`        | an anniversary on the as-of date is skipped     | vectors fail                |
| `grace_inclusive`              | a fee on the last day of grace                  | `feeFor_zero` fails         |
| `no_max_fee`                   | no `maxFee` limit                               | `feeFor_le_maxFee` fails    |
| `round_after_cap`              | the daily cap applied before rounding (old bug) | `feeFor_le_cap` fails       |
| `overpay`                      | the loop applies the whole outstanding          | `dartLoop_rest` fails       |
| `unchosen_rank_first`          | SQL ranks unchosen charges first                | `rank_iff` fails            |
| `newest_due_first`             | the sort pays the newest charge first           | vectors fail                |
| `deposit_paid`                 | a deposit adjustment may pay the deposit        | `orderCharges_mem` fails    |

## Bounds and abstractions

There are no bounds in the proofs: every theorem is about all integers or all
lists. The bounds of the database (amount ranges, percentages, days) matter
only for machine integers, which `../smt` covers.

- `Int` for Dart `BigInt` and `int`, and for PostgreSQL `numeric`. The Dart
  computes every product in `BigInt`; whether each `int` fits 64 or 53 bits,
  and each SQL value its `numeric(14,2)` column, is checked in `../smt`.
- `numeric` division in SQL is modelled exactly (`sqlRound`) and, for
  proration, also with PostgreSQL's rounding to the result scale
  (`pgScaledRound`). `pgProratedRent_eq` covers every scale `>= 4`;
  `../smt/dart_sql.py` models `select_div_scale` and shows the scale is at
  least 8 for every admitted rent and percentage.
- `proratedRent` is modelled for the open-ended occupancy `billedRent`
  passes (`DateRange(billingStartsOn)`), the only one the ledger uses.
- Charge ids are UUIDs, ordered by their 128-bit value. For the canonical
  lower-case text both sides use, Dart's `String.compareTo` and PostgreSQL's
  `uuid` order agree with it. Due dates are ordered by
  `year * 10000 + month * 100 + day`.
- The allocation is one call of `private.allocate_payment` on the open
  charges it selects. Locking and concurrent payments are the TLA+ models'
  job (`formal/tla`).
- `nextAnniversary` loops with fuel (1,000 turns) instead of general
  recursion. That is far more than any vector needs. It is checked against
  the vectors, not proven.

## How to run

```sh
formal/lean/run.sh ci          # build, axioms, vectors, fast Z3 checks
formal/lean/run.sh all         # also every Z3 check and every Lean mutant
formal/lean/run.sh ci lean     # only the Lean part (or: smt)
```

`tool/formal/install.sh` (`make formal-install`) installs Lean 4.35.0 and
a `z3-solver` environment, pinned and checksum-verified, and `run.sh` reads
them from `.cache/formal/env.sh`. Otherwise set `LEAN_HOME` to a Lean
4.35.0 toolchain (or put `lake` on `PATH`) and `Z3_PYTHON` to a Python with
`z3-solver`. `LEAN_JOBS` mutants build at once
(default 2). By hand: `lake build`, then
`lake exe check-vectors ../../contracts/rent_math_vectors.json` and
`lake env lean Axioms.lean`.

## Expected results

On the shared 4-CPU machine this was written on:

| Mode  | Steps                                                | Wall time                                          |
| ----- | ---------------------------------------------------- | -------------------------------------------------- |
| `ci`  | 7: guard, build, axioms, 2 vector runs, 2 Z3 scripts | 31 s from a clean build; 5 s once built            |
| `all` | 23: the above, 16 mutants, all Z3 checks             | 4 to 6 minutes (mutants 12-75 s each, 2 at a time) |

Every step reports `ok`; the last line reads `7/7 steps as expected` or
`23/23 steps as expected`.

## Not covered

- Money formatting and parsing (`money_format.dart`, `money_parse.dart`,
  `basisPointsFromPercent`) beyond the decimal parser `check-vectors` uses.
- `nextAnniversary` and `billablePeriods` are not proven, only tested by the
  vectors (anniversaries) or not at all (billable periods).
- Rounding modes other than half-up are not compared with SQL: the SQL uses
  only `round(_, 0)`.
- The SQL that sums or reports money (`get_dashboard`, `get_receivables`,
  ...) and the deposit position functions.
- Concurrency, locking and idempotent replays (see `formal/tla`).
- The models are read from the code by hand. A change to the Dart or SQL
  needs the matching change here; the vectors catch some drift, not all.
