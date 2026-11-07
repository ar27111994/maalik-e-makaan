# Machine integers and SQL rounding (Z3)

Z3 checks of the money paths that the Lean proofs in
[`../lean`](../lean/README.md) treat as exact integers. Each check asks Z3
for an input the code admits that breaks a property. `unsat` proves no such
input exists; `sat` comes with a model. Every check states the answer it
expects, and the scripts fail on any other answer (including `unknown`).

Run them with `formal/lean/run.sh` (both parts) or alone:

```sh
python overflow.py ci|all
python dart_sql.py ci|all
```

The Python needs the `z3-solver` package. `run.sh` uses `Z3_PYTHON`, which
`tool/formal/install.sh` sets up (z3-solver 5.3.1.0, hash-pinned in
`tool/formal/requirements.txt`).

## Bounds

All from the code as it is now (`supabase/migrations`, last definition wins).
They live in `smtkit.py`.

| Bound                                | Value                                  | Source                                                                                         |
| ------------------------------------ | -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| any money amount                     | at most 999,999,999,999.99 either sign | `numeric(14,2)` columns; `private.require_valid_amount`; `Money.maxValue`                      |
| late fee value (flat, or daily rate) | `<= 10,000,000` rupees                 | `leases_late_fee_value_max_check` (`20261104143928_ledger_jobs_hardening.sql`)                 |
| percent late fee, rent increment     | `0..100` %, 10,000 bp                  | `leases_late_fee_percent_check`, `leases_increment_percent_check`                              |
| largest fee                          | Rs 999,999,999,999                     | `app.late_fee_amount` `least(...)`, `LateFeePolicy.maxFee`                                     |
| days late in Dart                    | `<= 3,652,058`                         | `CalendarDate` years 1..9999                                                                   |
| days late in SQL                     | PostgreSQL date range                  | `date` is int4 days from 2000-01-01, 4714-11-24 BC to 5874897-12-31 AD                         |
| rent rounding steps                  | 1, 10, 50, 100, 500, 1000              | `RentRounding.stepRupees`                                                                      |
| sum of `Money.allocate` ratios       | `< 2^53` (assumed)                     | caller-supplied, not stored; the only bound assumed rather than found                          |
| sums over many charges               | none needed                            | Dart sums only one payment's allocations (at most the payment); SQL sums are untyped `numeric` |

## (a) No overflow: `overflow.py`

Dart VM `int` is 64-bit; Dart on the web uses JavaScript Numbers, exact up to
2^53. PostgreSQL rejects a `numeric(14,2)` value of 10^12 rupees or more.
The Edge Functions do no money arithmetic (`dart_sql.py` checks that), so
JavaScript Numbers carry money only inside Dart on the web.

| Check (expected `unsat`)                       | Code                                                 | Mutant (expected `sat`)                                 |
| ---------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------- |
| `Money` `+`/`-` of two amounts (web, VM)       | `money.dart` operators                               | amounts `numeric(16,2)`                                 |
| `Money.fromJson(int)`: `rupees * 100`          | `money.dart` `fromJson`, `fromRupees`                | no `numeric(14,2)` bound                                |
| proration `multiplyToStep(...).toInt()`        | `RentMath.proratedRent`                              | rent `numeric(16,2)`                                    |
| increment `multiplyToStep(...).toInt() * step` | `RentMath.incrementedRent`                           | basis points unbounded                                  |
| percent fee `multiplyToStep(bp, 10000)`        | `PercentLateFee.computeFee`                          | amounts `numeric(16,2)`                                 |
| daily fee clamped product `.toInt()` (web, VM) | `DailyLateFee.computeFee`                            | no clamp and no 10,000,000 value cap                    |
| allocation partial sums                        | `planFifoAllocation`, `AllocationPlan.allocated`     | amounts `numeric(16,2)`                                 |
| `allocate` int arithmetic                      | `Money.allocate`                                     | amounts `numeric(16,2)`                                 |
| late fee charge fits `numeric(14,2)`           | `app.late_fee_amount` via `private.assess_late_fees` | no `least(..., 999999999999)` (the pre-fix code)        |
| percent fee charge fits                        | `app.late_fee_amount`                                | no `least(...)`: 100 % of the largest balance overflows |
| prorated rent charge fits                      | `private.sync_lease_billing`                         | rent `numeric(16,2)`                                    |
| `paid_amount + v_apply` fits                   | `private.allocate_payment`                           | applies `v_remaining` without `least`                   |
| `waived_amount + v_amount` fits                | `public.waive_charge`                                | no `amount_exceeds_outstanding` check                   |
| `p_as_of - due_date` fits int4                 | `private.assess_late_fees`                           | dates over the whole int4 range                         |
| `applied_amount = amount + tax` fits           | `public.record_payment` (A1's fix)                   | no `amount + tax` check (the code before, finding A1)   |

`redundancy: daily fee no clamp, value cap kept` is expected `unsat`: the
10,000,000-rupee cap alone keeps `perDay * daysLate` below 2^53, so the
clamp in `DailyLateFee` is a second line of defence, not the only one.

### Finding A1 (fixed): `payments.applied_amount` overflowed for admitted input

- Severity: low. The payment was refused, nothing was corrupted, but the
  user got an unmapped `numeric field overflow` (SQLSTATE 22003) instead of
  `invalid_amount`.
- Where: `public.record_payment` checked `require_valid_amount(p_amount)`,
  `require_valid_amount(v_tax, true)` and `v_tax <= p_amount`, each at most
  999,999,999,999.99 on its own. The insert then computes the generated
  columns `applied_amount` and `unallocated_amount` (`amount + tax_withheld`,
  `numeric(14,2)`, `20261103193658_ledger.sql`).
- Counterexample (Z3 model, now the mutant `record_payment without the
amount + tax check`): `amount = 500,000,000,000.00`,
  `tax_withheld = 500,000,000,000.00`. On PostgreSQL 16 the insert of
  999,999,999,999.99 + 999,999,999,999.99 failed: `ERROR: numeric field
overflow. A field with precision 14, scale 2 must round to an absolute
value less than 10^12.`
- Fix (`20261107181820_ledger_findings.sql`): `record_payment` refuses
  `p_amount + v_tax > 999999999999.99` with `invalid_amount`. The check
  `pg: payments.applied_amount = amount + tax fits numeric(14,2)` is now
  `unsat` against it, and `17_ledger_findings.test.sql` replays the
  counterexample (`invalid_amount`) and the boundary (exactly
  999,999,999,999.99 accepted). No table CHECK: PostgreSQL computes the
  generated columns before it evaluates CHECK constraints, so the overflow
  would still come first (a temporary copy of `payments` with such a CHECK
  still fails with 22003).

## (b) Dart half-up equals SQL `round`: `dart_sql.py`

PostgreSQL's `numeric` division is not exact. `div_var` rounds the quotient,
half away from zero, to the scale `select_div_scale` picks (16 significant
digits, at least the operands' display scales), and `round(_, 0)` rounds
that. `pg_div_scale` models `select_div_scale` from numeric.c. It was
compared with `scale()` on PostgreSQL 16.15 for 120 random proration and
percent-fee divisions: 0 mismatches.

| Check (expected `unsat`)                                                                         | Mutant (expected `sat`)                                                   |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `divideRounded(n, d, halfUp) == round(n / d, 0)` for every `n` in ±2^80 and every divisor in use | ties toward zero (`twiceRemainder > d`)                                   |
| scale of `rent * days / dim` is at least 8                                                       | rent `numeric(22,2)`: scale 2                                             |
| proration: Dart quotient == PostgreSQL quotient                                                  | rent `numeric(22,2)`, 29 of 30 days: model rent 10,689,655,175,862,421.55 |
| scale of `outstanding * value / 100` is at least 8                                               | (covered by the next mutant)                                              |
| percent fee: Dart == PostgreSQL, with `least(...)`                                               | percent up to 999.99 and no `least(...)`: outstanding 101,001,016,000.01  |
| flat fee: Dart == PostgreSQL                                                                     | (the generic mutant)                                                      |
| daily fee with cap: Dart == PostgreSQL                                                           | rounding after the cap (the bug fixed in `20261104143928`)                |
| JSON number → `Money.fromJson(double)` is exact                                                  | amounts up to 10^16 rupees                                                |

Both division mutants were replayed on PostgreSQL 16. Rent
10,689,655,175,862,421.55 for 29 of 30 days gives `round(rent * 29 / 30, 0)`
= 10,333,333,336,667,008; the exact half-up value is ...007. Outstanding
101,001,016,000.01 at 999.99 % gives 1,010,000,059,899; exact is ...898. So
the double rounding is real, and only the current bounds keep it away.

The JSON check models IEEE binary64 exactly: in binade `e` a double is
`m * 2^e` with `2^52 <= m <= 2^53`, and any nearest double is within
`2^(e-1)`. Every amount up to 999,999,999,999.99 is read back to the paisa.

TypeScript has no rounding of its own: `typescript_scope()` scans
`supabase/functions/**/*.ts` (not tests or the generated
`database.types.ts`) for money fields and fails if one appears.

## Expected results

| Script        | `ci`              | `all`                 |
| ------------- | ----------------- | --------------------- |
| `overflow.py` | 34/34 checks, 2 s | 34/34 checks, 2 s     |
| `dart_sql.py` | 11/11 checks, 2 s | 14/14 checks, 30-45 s |

## Not covered

- Rounding in modes other than half-up against SQL (the SQL rounds half-up
  only).
- Report and dashboard SQL that sums money. Their results are untyped
  `numeric`, so they cannot overflow in SQL, but a total above
  999,999,999,999.99 is refused by `Money.fromJson` (`FormatException`).
- `Money.fromJson(int)` does not range-check. Values from the database are
  in range (checked above); a hand-made JSON could build an out-of-range
  `Money`.
- The `Money.allocate` ratios bound is assumed, not derived.
