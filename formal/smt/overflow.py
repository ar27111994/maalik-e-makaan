#!/usr/bin/env python3
"""(a) No overflow anywhere in the money paths, for every amount the database
CHECK constraints admit.

Three integer models:
- Dart VM `int`: 64-bit two's complement. A value outside it wraps (an `int`
  sum) or clamps (`BigInt.toInt()`).
- Dart on the web: `int` is a JavaScript Number, exact only up to 2^53.
- PostgreSQL: `numeric(14,2)` columns and variables reject |x| >= 10^12
  rupees (SQLSTATE 22003, "numeric field overflow"); `date - date` is int4.
  Unconstrained `numeric` (function arguments, sum()) does not overflow.

The Edge Functions (supabase/functions) do no money arithmetic: see
dart_sql.py, which checks that. So JavaScript Number is only reached through
Dart on the web.

Each property is "every intermediate value stays inside the type". A check
asks Z3 for an admitted input whose value leaves it; "unsat" proves there is
none. Mutants remove one bound and must become "sat".

    overflow.py [ci|all]
"""

from __future__ import annotations

import sys

from smtkit import (
    INT64_MAX,
    INT64_MIN,
    JS_SAFE,
    MAX_BASIS_POINTS,
    MAX_DART_DAYS,
    MAX_FEE_PAISA,
    MAX_LATE_FEE_VALUE_PAISA,
    MAX_PAISA,
    PG_MAX_DATE,
    PG_MIN_DATE,
    RENT_STEPS,
    Check,
    dart_half_up,
    round_half_away,
    run,
    zmin,
)
from z3 import And, ArithRef, BoolRef, If, Int, Ints, Or

# A Dart value fits the VM int and, the stricter bound, a JavaScript Number.
VM = (INT64_MIN, INT64_MAX)
WEB = (-JS_SAFE, JS_SAFE)
# A numeric(14,2) column, in paisa.
NUMERIC_14_2 = (-MAX_PAISA, MAX_PAISA)


def outside(x: ArithRef, bounds: tuple[int, int]) -> BoolRef:
    return Or(x < bounds[0], x > bounds[1])


def between(x: ArithRef, lo: int, hi: int) -> BoolRef:
    return And(x >= lo, x <= hi)


# --------------------------------------------------------------------------
# Dart (packages/mm_core)
# --------------------------------------------------------------------------


def money_sum(bounds: tuple[int, int], limit: int = MAX_PAISA):
    """money.dart `operator +`/`-`: an int sum of two amounts, e.g. the
    ledger total of a charge and a payment, or `remaining -= applied`."""

    def build():
        a, b = Ints("a b")
        s = a + b
        return [between(a, -limit, limit), between(b, -limit, limit), outside(s, bounds)], {
            "a": a,
            "b": b,
        }

    return build


def from_json_int(bounds: tuple[int, int], limit: int = MAX_PAISA // 100):
    """money.dart `Money.fromJson(int)` -> `fromRupees`: `rupees * 100` (a
    whole-rupee numeric, e.g. app.late_fee_amount's round(..., 0))."""

    def build():
        r = Int("rupees")
        return [between(r, -limit, limit), outside(r * 100, bounds)], {"rupees": r}

    return build


def prorated_to_int(bounds: tuple[int, int], limit: int = MAX_PAISA):
    """rent_math.dart `proratedRent` -> `multiplyToStep(days, dim)`:
    `divideRounded(rent * days, dim * 100).toInt() * 100` for days < dim."""

    def build():
        rent, days, dim = Ints("rent days dim")
        n = Int("n")  # BigInt rent * days, any value in its range
        q = Int("q")
        cases = []
        for d in (28, 29, 30, 31):
            cases.append(And(dim == d, q == dart_half_up(n, d * 100)))
        return [
            between(rent, 1, limit),
            between(dim, 28, 31),
            between(days, 1, dim - 1),
            between(n, 0, limit * 30),
            Or(*cases),
            outside(q * 100, bounds),
        ], {"rent*days": n, "dim": dim}

    return build


def incremented_to_int(bounds: tuple[int, int], max_bp: int = MAX_BASIS_POINTS):
    """rent_math.dart `incrementedRent` -> `multiplyToStep(10000 + bp, 10000,
    stepRupees)`: `divideRounded(rent * (10000 + bp), 10000 * step).toInt()
    * step` (also `stepRupees * paisaPerRupee` in int)."""

    def build():
        rent, bp, n, q, step = Ints("rent bp n q step")
        cases = [And(step == s * 100, q == dart_half_up(n, 10000 * s * 100)) for s in RENT_STEPS]
        return [
            between(rent, 1, MAX_PAISA),
            between(bp, 0, max_bp),
            between(n, 10000, MAX_PAISA * (10000 + max_bp)),
            Or(*cases),
            outside(q * step, bounds),
        ], {"rent*(10000+bp)": n, "step": step}

    return build


def percent_fee_to_int(bounds: tuple[int, int], limit: int = MAX_PAISA):
    """late_fee_policy.dart `PercentLateFee.computeFee`:
    `multiplyToStep(bp, 10000)` = `divideRounded(paisa * bp, 10^6) * 100`."""

    def build():
        n, q = Ints("n q")
        return [
            between(n, 0, limit * MAX_BASIS_POINTS),
            q == dart_half_up(n, 1_000_000),
            outside(q * 100, bounds),
        ], {"overdue*bp": n}

    return build


def daily_fee_to_int(
    bounds: tuple[int, int], clamp: bool = True, max_value: int = MAX_LATE_FEE_VALUE_PAISA
):
    """late_fee_policy.dart `DailyLateFee.computeFee`: the BigInt
    `perDay * daysLate`, held at `maxFee` (`fee > limit ? limit : fee`), then
    `.toInt()`. Days late span Dart's CalendarDate range."""

    def build():
        per_day, days = Ints("perDay daysLate")
        fee = per_day * days
        value = zmin(fee, MAX_FEE_PAISA) if clamp else fee
        return [
            between(per_day, 0, max_value),
            between(days, 0, MAX_DART_DAYS),
            outside(value, bounds),
        ], {"perDay": per_day, "daysLate": days}

    return build


def allocation_sums(bounds: tuple[int, int], limit: int = MAX_PAISA):
    """allocation.dart `planFifoAllocation`: `remaining -= applied` and
    `AllocationPlan.allocated` (Money.sum). Lean proves allocations + credit
    = payment and 0 <= credit <= payment (planFifo_conserves,
    planFifo_credit_bounds), so every partial sum lies in [0, payment]."""

    def build():
        payment, partial = Ints("payment partial")
        return [
            between(payment, 0, limit),
            between(partial, 0, payment),
            Or(outside(partial, bounds), outside(payment - partial, bounds)),
        ], {"payment": payment, "partial": partial}

    return build


def zabs(x: ArithRef) -> ArithRef:
    return If(x < 0, -x, x)


def allocate_ints(bounds: tuple[int, int], limit: int = MAX_PAISA):
    """money.dart `allocate`: `allocated += part` (parts are floors of
    shares of |paisa|, so their sum is at most |paisa|), `leftover =
    |paisa| - allocated` (less than the number of ratios, Lean
    leftover_lt) and `part * sign`. Assumption: the caller's ratios sum to
    less than 2^53 (they are not stored in the database)."""

    def build():
        paisa, allocated, part = Ints("paisa allocated part")
        return [
            between(paisa, -limit, limit),
            between(allocated, 0, zabs(paisa)),
            between(part, 0, zabs(paisa)),
            Or(
                outside(zabs(paisa) - allocated, bounds),
                outside(part * -1, bounds),
                outside(part + 1, bounds),
            ),
        ], {"paisa": paisa}

    return build


# --------------------------------------------------------------------------
# PostgreSQL (supabase/migrations)
# --------------------------------------------------------------------------


def late_fee_charge(cap_fee: bool = True):
    """private.assess_late_fees inserts app.late_fee_amount(...) into
    charges.amount numeric(14,2). The daily fee value * days_late is capped
    by least(..., 999999999999). days_late = p_as_of - c.due_date spans the
    PostgreSQL date range."""

    def build():
        value, days = Ints("value days")
        rounded = 100 * round_half_away(value * days, 100)
        fee = zmin(rounded, MAX_FEE_PAISA) if cap_fee else rounded
        return [
            between(value, 0, MAX_LATE_FEE_VALUE_PAISA),
            between(days, 1, PG_MAX_DATE - PG_MIN_DATE),
            outside(fee, NUMERIC_14_2),
        ], {"value": value, "days": days}

    return build


def percent_fee_charge(cap_fee: bool = True):
    """app.late_fee_amount 'percent': least(round(outstanding * value / 100,
    0), 999999999999), value <= 100 %, outstanding a numeric(14,2) charge
    balance. Without the least(), 100 % of 999999999999.99 rounds up to
    10^12 rupees."""

    def build():
        n = Int("n")  # outstanding paisa * basis points
        rounded = 100 * round_half_away(n, 1_000_000)
        fee = zmin(rounded, MAX_FEE_PAISA) if cap_fee else rounded
        return [between(n, 0, MAX_PAISA * MAX_BASIS_POINTS), outside(fee, NUMERIC_14_2)], {
            "overdue*bp": n
        }

    return build


def prorated_charge(limit: int = MAX_PAISA):
    """private.sync_lease_billing: v_amount numeric(14,2) :=
    app.prorated_rent(v_rent, ...) = least(rent, round(...)) <= rent."""

    def build():
        rent, n, dim = Ints("rent n dim")
        cases = [And(dim == d, n >= 0) for d in (28, 29, 30, 31)]
        rounded = Int("rounded")
        amount = zmin(rent, rounded)
        return [
            between(rent, 1, limit),
            Or(*cases),
            between(n, 0, limit * 30),
            rounded >= 0,
            outside(amount, NUMERIC_14_2),
        ], {"rent": rent}

    return build


def paid_amount(least: bool = True):
    """private.allocate_payment: `update charges set paid_amount = paid_amount
    + v_apply` with v_apply = least(v_remaining, outstanding) and
    outstanding = amount - paid - waived (charges_not_overpaid_check)."""

    def build():
        amount, paid, waived, remaining, apply_ = Ints("amount paid waived remaining apply")
        outstanding = amount - paid - waived
        return [
            between(amount, 1, MAX_PAISA),
            paid >= 0,
            waived >= 0,
            paid + waived <= amount,
            outstanding > 0,
            between(remaining, 1, 2 * MAX_PAISA),
            apply_ == (zmin(remaining, outstanding) if least else remaining),
            outside(paid + apply_, NUMERIC_14_2),
        ], {"amount": amount}

    return build


def waived_amount(guard: bool = True):
    """public.waive_charge: waived_amount + v_amount, v_amount <= outstanding."""

    def build():
        amount, paid, waived, v = Ints("amount paid waived v")
        return [
            between(amount, 1, MAX_PAISA),
            paid >= 0,
            waived >= 0,
            paid + waived <= amount,
            between(v, 1, amount - paid - waived if guard else MAX_PAISA),
            outside(waived + v, NUMERIC_14_2),
        ], {"amount": amount}

    return build


def applied_amount(fix: bool = False):
    """payments.applied_amount numeric(14,2) GENERATED AS (amount +
    tax_withheld) (also unallocated_amount). public.record_payment checks
    require_valid_amount(p_amount), require_valid_amount(v_tax, true) and
    v_tax <= p_amount (payments_tax_withheld_check), each at most
    999999999999.99 on its own. The fix flag adds the proposed check
    amount + tax_withheld <= 999999999999.99."""

    def build():
        amount, tax = Ints("amount tax_withheld")
        constraints = [
            between(amount, 1, MAX_PAISA),
            between(tax, 0, MAX_PAISA),
            tax <= amount,
            outside(amount + tax, NUMERIC_14_2),
        ]
        if fix:
            constraints.append(amount + tax <= MAX_PAISA)
        return constraints, {"amount": amount, "tax_withheld": tax}

    return build


def date_difference(max_date: int = PG_MAX_DATE, min_date: int = PG_MIN_DATE):
    """private.assess_late_fees: `p_as_of - c.due_date` is int4."""

    def build():
        a, b = Ints("as_of due_date")
        return [
            between(a, min_date, max_date),
            between(b, min_date, max_date),
            outside(a - b, (-(2**31), 2**31 - 1)),
        ], {"as_of": a, "due_date": b}

    return build


CHECKS = [
    # Dart VM and web.
    Check("dart: Money +/- of two amounts (web)", "money.dart operator +", "unsat", money_sum(WEB)),
    Check(
        "dart: Money.fromJson(int) rupees*100 (web)",
        "money.dart fromJson/fromRupees",
        "unsat",
        from_json_int(WEB),
    ),
    Check(
        "dart: proratedRent multiplyToStep toInt (web)",
        "rent_math.dart proratedRent",
        "unsat",
        prorated_to_int(WEB),
    ),
    Check(
        "dart: incrementedRent multiplyToStep toInt (web)",
        "rent_math.dart incrementedRent",
        "unsat",
        incremented_to_int(WEB),
    ),
    Check(
        "dart: PercentLateFee multiplyToStep toInt (web)",
        "late_fee_policy.dart PercentLateFee",
        "unsat",
        percent_fee_to_int(WEB),
    ),
    Check(
        "dart: DailyLateFee clamped product toInt (web)",
        "late_fee_policy.dart DailyLateFee",
        "unsat",
        daily_fee_to_int(WEB),
    ),
    Check(
        "dart: planFifoAllocation partial sums (web)",
        "allocation.dart planFifoAllocation",
        "unsat",
        allocation_sums(WEB),
    ),
    Check(
        "dart: Money.allocate int arithmetic (web)",
        "money.dart allocate",
        "unsat",
        allocate_ints(WEB),
    ),
    Check(
        "dart: Money +/- of two amounts (VM int64)", "money.dart operator +", "unsat", money_sum(VM)
    ),
    Check(
        "dart: DailyLateFee clamped product toInt (VM)",
        "late_fee_policy.dart DailyLateFee",
        "unsat",
        daily_fee_to_int(VM),
    ),
    # PostgreSQL.
    Check(
        "pg: late fee charge fits numeric(14,2)",
        "app.late_fee_amount least(...)",
        "unsat",
        late_fee_charge(),
    ),
    Check(
        "pg: percent late fee fits numeric(14,2)",
        "app.late_fee_amount percent",
        "unsat",
        percent_fee_charge(),
    ),
    Check(
        "pg: prorated rent charge fits numeric(14,2)",
        "private.sync_lease_billing v_amount",
        "unsat",
        prorated_charge(),
    ),
    Check(
        "pg: paid_amount + v_apply fits numeric(14,2)",
        "private.allocate_payment",
        "unsat",
        paid_amount(),
    ),
    Check(
        "pg: waived_amount + v_amount fits numeric(14,2)",
        "public.waive_charge",
        "unsat",
        waived_amount(),
    ),
    Check(
        "pg: p_as_of - due_date fits int4", "private.assess_late_fees", "unsat", date_difference()
    ),
    # FINDING: the generated column overflows for admitted inputs.
    Check(
        "FINDING pg: payments.applied_amount = amount + tax",
        "payments.applied_amount / record_payment",
        "sat",
        applied_amount(),
    ),
    Check(
        "FIX pg: applied_amount with amount + tax <= max",
        "proposed record_payment check",
        "unsat",
        applied_amount(fix=True),
    ),
    # Mutants: each removes the bound that protects a check above.
    Check(
        "mutant: Money range numeric(16,2) -> sum (web)",
        "Money.maxValue",
        "sat",
        money_sum(WEB, limit=10**16 - 1),
    ),
    Check(
        "mutant: fromJson(int) without numeric(14,2) (web)",
        "Money.fromJson",
        "sat",
        from_json_int(WEB, limit=10**15),
    ),
    Check(
        "mutant: rent numeric(16,2) -> proratedRent (web)",
        "leases.monthly_rent",
        "sat",
        prorated_to_int(WEB, limit=10**16 - 1),
    ),
    Check(
        "mutant: increment bp unbounded -> incrementedRent (web)",
        "incrementedRent basisPoints >= 0 only",
        "sat",
        incremented_to_int(WEB, max_bp=10**6),
    ),
    Check(
        "mutant: daily fee no clamp, no 1e7 value cap (web)",
        "DailyLateFee + leases_late_fee_value_max_check",
        "sat",
        daily_fee_to_int(WEB, clamp=False, max_value=MAX_PAISA),
    ),
    Check(
        "mutant: daily fee no clamp, no 1e7 value cap (VM)",
        "DailyLateFee + leases_late_fee_value_max_check",
        "sat",
        daily_fee_to_int(VM, clamp=False, max_value=MAX_PAISA),
    ),
    Check(
        "redundancy: daily fee no clamp, value cap kept (web)",
        "DailyLateFee: the 1e7 cap alone suffices",
        "unsat",
        daily_fee_to_int(WEB, clamp=False),
    ),
    Check(
        "mutant: rent numeric(16,2) -> prorated charge",
        "leases.monthly_rent",
        "sat",
        prorated_charge(limit=10**16 - 1),
    ),
    Check(
        "mutant: percent fee without least(999999999999)",
        "app.late_fee_amount least(...)",
        "sat",
        percent_fee_charge(cap_fee=False),
    ),
    Check(
        "mutant: amounts numeric(16,2) -> percent fee (web)",
        "Money.maxValue",
        "sat",
        percent_fee_to_int(WEB, limit=10**16 - 1),
    ),
    Check(
        "mutant: amounts numeric(16,2) -> allocation sums (web)",
        "payments.amount",
        "sat",
        allocation_sums(WEB, limit=10**16 - 1),
    ),
    Check(
        "mutant: amounts numeric(16,2) -> allocate (web)",
        "Money.maxValue",
        "sat",
        allocate_ints(WEB, limit=10**16 - 1),
    ),
    Check(
        "mutant: allocate_payment applies v_remaining, no least",
        "private.allocate_payment least(...)",
        "sat",
        paid_amount(least=False),
    ),
    Check(
        "mutant: waive_charge without amount_exceeds_outstanding",
        "public.waive_charge",
        "sat",
        waived_amount(guard=False),
    ),
    Check(
        "mutant: late_fee_amount without least(999999999999)",
        "app.late_fee_amount before 20261104143928",
        "sat",
        late_fee_charge(cap_fee=False),
    ),
    Check(
        "mutant: int4 dates over the whole int4 range",
        "PostgreSQL date range",
        "sat",
        date_difference(max_date=2**31 - 1),
    ),
]

if __name__ == "__main__":
    sys.exit(run("overflow", CHECKS, sys.argv))
