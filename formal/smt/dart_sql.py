#!/usr/bin/env python3
"""(b) Dart half-up rounding equals SQL round(numeric) on the admitted domain.

The Dart side is mm_core `divideRounded(..., RoundingMode.halfUp)` as used by
`multiplyToStep` and `roundToRupee` (packages/mm_core/lib/src/money). The SQL
side is PostgreSQL `round(x, 0)` applied to what `app.prorated_rent` and
`app.late_fee_amount` compute. A PostgreSQL `numeric` division is not exact:
numeric.c `div_var` rounds the quotient (half away from zero) to the result
scale chosen by `select_div_scale`, and only then does `round` see it. The
checks below model that scale exactly and show the double rounding never
changes a rent or a fee.

TypeScript: the Edge Functions do no money arithmetic and have no rounding of
their own; `typescript_scope()` checks that, so the comparison is Dart vs SQL.
Dart on the web and JavaScript read JSON numbers as IEEE binary64; the last
group shows `Money.fromJson(double)` recovers every numeric(14,2) amount.

    dart_sql.py [ci|all]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from smtkit import (
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
from z3 import And, ArithRef, BoolRef, If, Int, Ints, IntVal, Or

REPO = Path(__file__).resolve().parents[2]

# numeric.c: NUMERIC_MIN_SIG_DIGITS, DEC_DIGITS (base NBASE = 10000),
# NUMERIC_MIN_DISPLAY_SCALE, NUMERIC_MAX_DISPLAY_SCALE.
MIN_SIG_DIGITS = 16
DEC_DIGITS = 4
MAX_DISPLAY_SCALE = 1000
WEIGHTS = range(-1, 7)  # base-10000 weights reachable here (0.0001 <= X < 10^28)


def pg_div_scale(n: ArithRef, k: int, divisor: int, dscale: int) -> ArithRef:
    """numeric.c select_div_scale(var1, var2) for var1 = n / 10^k (n >= 0,
    display scale `dscale`) and a whole divisor 1 <= divisor < 10000
    (weight 0, first digit = divisor).

    weight1 is the base-10000 exponent of var1's first non-zero digit and
    firstdigit1 that digit (both 0 when var1 is zero); qweight = weight1 -
    weight2, less one when firstdigit1 <= firstdigit2; rscale =
    16 - 4 * qweight, raised to the operands' display scales, within
    [0, 1000].
    """
    weight: ArithRef = IntVal(0)
    first: ArithRef = IntVal(0)
    for w in WEIGHTS:
        if w >= 0:
            low = 10**k * 10 ** (DEC_DIGITS * w)
            in_band = And(n >= low, n < low * 10**DEC_DIGITS)
            digit = n / low
        else:  # 10^-4 <= var1 < 1: n * 10^(4 - k) is the first digit
            in_band = And(n >= 1, n < 10**k)
            digit = n * 10 ** (DEC_DIGITS - k)
        weight = If(in_band, w, weight)
        first = If(in_band, digit, first)
    qweight = weight - If(first <= divisor, 1, 0)
    rscale = MIN_SIG_DIGITS - qweight * DEC_DIGITS
    rscale = If(rscale < dscale, dscale, rscale)
    rscale = If(rscale < 0, 0, rscale)
    return If(rscale > MAX_DISPLAY_SCALE, MAX_DISPLAY_SCALE, rscale)


def pg_round_quotient(n: ArithRef, denominator: int, rscale: ArithRef) -> ArithRef:
    """round(q, 0) where q = n / denominator was first rounded to `rscale`
    decimals by div_var. The scales that can occur are enumerated so every
    term stays linear."""
    result = Int("unreachable_scale")
    for s in (0, 2, 4, 8, 12, 16, 20, 24):
        at_scale = round_half_away(n * 10**s, denominator)
        result = If(rscale == s, round_half_away(at_scale, 10**s), result)
    return result


def scales_known(rscale: ArithRef) -> BoolRef:
    return Or(*[rscale == s for s in (0, 2, 4, 8, 12, 16, 20, 24)])


# --------------------------------------------------------------------------
# app.prorated_rent: least(rent, round(rent * days / dim, 0)), rent in
# rupees with 2 decimals, days = dim - day + 1 for a billing start day > 1.
# Dart: Money.min(rent, rent.multiplyToStep(days, dim)) =
# min(rent, divideRounded(rent * days, dim * 100) * 100).
# --------------------------------------------------------------------------


def prorated_scale(limit: int = MAX_PAISA):
    def build():
        n, dim = Ints("rent_x_days dim")
        cases = []
        for d in (28, 29, 30, 31):
            scale = pg_div_scale(n, 2, d, 2)
            cases.append(And(dim == d, n <= limit * (d - 1), scale < 8))
        return [n >= 1, Or(*cases)], {"rent*days": n, "dim": dim}

    return build


def prorated_witness(limit: int, days: int):
    """A mutant's counterexample as a real rent: days of a 30-day month
    fixed, so rent * days stays linear."""

    def build():
        rent, n = Ints("rent rent_x_days")
        scale = pg_div_scale(n, 2, 30, 2)
        dart = zmin(rent, dart_half_up(n, 3000) * 100)
        sql = zmin(rent, pg_round_quotient(n, 3000, scale) * 100)
        return [rent >= 1, rent <= limit, n == rent * days, dart != sql], {
            "rent": rent,
            "rent*days": n,
            "scale": scale,
        }

    return build


def prorated_equal_linear():
    """The rounded quotient round(rent * days / dim) of Dart and PostgreSQL
    agree for every rent * days up to MAX_PAISA * (dim - 1) (any value in
    that range, not only products, so the query stays linear); least(rent,
    100 * q) is then equal too."""

    def build():
        n, dim = Ints("rent_x_days dim")
        cases = []
        for d in (28, 29, 30, 31):
            scale = pg_div_scale(n, 2, d, 2)
            q_dart = dart_half_up(n, d * 100)
            q_sql = pg_round_quotient(n, 100 * d, scale)
            cases.append(And(dim == d, n <= MAX_PAISA * (d - 1), q_dart != q_sql))
        return [n >= 1, Or(*cases)], {"rent*days": n, "dim": dim}

    return build


# --------------------------------------------------------------------------
# app.late_fee_amount.
# --------------------------------------------------------------------------


def percent_scale():
    """'percent': round(outstanding * value / 100, 0); outstanding and value
    are numeric(14,2), so the product has display scale 4."""

    def build():
        n = Int("overdue_x_bp")  # outstanding paisa * basis points = X * 10^4
        return [n >= 1, n <= MAX_PAISA * 10_000, pg_div_scale(n, 4, 100, 4) < 8], {"overdue*bp": n}

    return build


def percent_equal(max_bp: int = 10_000, witness_bp: int | None = None, cap: bool = True):
    """Dart PercentLateFee (multiplyToStep(bp, 10000), then roundToRupee and
    maxFee) == SQL least(round(outstanding * value / 100), 999999999999).
    Where the scale drops to 4 the fee is above the cap, so a mutant must
    remove both the percent check and the cap to see a difference."""

    def build():
        n, paisa = Ints("overdue_x_bp overdue")
        scale = pg_div_scale(n, 4, 100, 4)
        limit = MAX_FEE_PAISA if cap else 10**40
        dart = zmin(dart_half_up(n, 1_000_000) * 100, limit)
        sql = zmin(pg_round_quotient(n, 1_000_000, scale) * 100, limit)
        constraints = [n >= 0, n <= MAX_PAISA * max_bp, dart != sql]
        if witness_bp is not None:
            constraints += [paisa >= 1, paisa <= MAX_PAISA, n == paisa * witness_bp]
        return constraints, {"overdue*bp": n, "overdue": paisa, "scale": scale}

    return build


def flat_equal():
    """'flat': Dart roundToRupee(value) == SQL round(value, 0)."""

    def build():
        v = Int("value")
        return [
            v >= 0,
            v <= MAX_LATE_FEE_VALUE_PAISA,
            dart_half_up(v, 100) * 100 != round_half_away(v, 100) * 100,
        ], {"value": v}

    return build


def daily_equal(round_after_cap: bool = False):
    """'daily': Dart min(min(roundToRupee(min(perDay * days, maxFee)), cap),
    maxFee) == SQL least(round(value * days, 0), cap, 999999999999). The
    mutant rounds after capping (the bug fixed in 20261104143928: a cap of
    99.50 rounded up to 100)."""

    def build():
        x, cap = Ints("perDay_x_days cap")
        if round_after_cap:
            dart = zmin(dart_half_up(zmin(zmin(x, MAX_FEE_PAISA), cap), 100) * 100, MAX_FEE_PAISA)
        else:
            dart = zmin(zmin(dart_half_up(zmin(x, MAX_FEE_PAISA), 100) * 100, cap), MAX_FEE_PAISA)
        sql = zmin(zmin(round_half_away(x, 100) * 100, cap), MAX_FEE_PAISA)
        # The mutant looks among small amounts, for a readable model.
        top = 100_000 if round_after_cap else MAX_PAISA
        return [
            x >= 0,
            x <= MAX_LATE_FEE_VALUE_PAISA * (PG_MAX_DATE - PG_MIN_DATE),
            cap >= 1,
            cap <= top,
            dart != sql,
        ], {"perDay*days": x, "cap": cap}

    return build


def generic_equal(ties_toward_zero: bool = False):
    """divideRounded(n, d, halfUp) == round(n / d, 0) for every n of either
    sign and every divisor the code uses: 100 (roundToRupee), 10^6 (percent
    fee), 2800..3100 (proration), 10^6 * step (incrementedRent)."""

    def build():
        n, d = Ints("n d")
        cases = []
        steps = tuple(10_000 * s * 100 for s in RENT_STEPS)
        for divisor in (100, 1_000_000, 2800, 2900, 3000, 3100, *steps):
            dart = dart_half_up(n, divisor)
            if ties_toward_zero:
                dart = mutant_half_down(n, divisor)
            cases.append(And(d == divisor, dart != round_half_away(n, divisor)))
        return [n >= -(2**80), n <= 2**80, Or(*cases)], {"n": n, "d": d}

    return build


def mutant_half_down(n: ArithRef, d: int) -> ArithRef:
    """divideRounded with `twiceRemainder > d`: ties toward zero."""
    quotient = If(n >= 0, n / d, -((-n) / d))
    remainder = n - quotient * d
    away = If(n < 0, quotient - 1, quotient + 1)
    twice = If(remainder < 0, -remainder, remainder) * 2
    return If(remainder == 0, quotient, If(twice > d, away, quotient))


# --------------------------------------------------------------------------
# JSON numbers: PostgREST writes numeric as a JSON number; Dart (VM and web)
# and JavaScript read it as the nearest binary64 x. Money.fromJson(double)
# then takes x.toStringAsFixed(2), which is the paisa amount c exactly when
# |x - c/100| < 1/200. A double in binade e is m * 2^e with 2^52 <= m <= 2^53
# (m = 2^53 is the next binade's first value); any nearest double is within
# half a unit, 2^(e-1). Scaled by 100 * 2^-e (e < 0) or 100 (e >= 0), all
# terms are integers.
# --------------------------------------------------------------------------


def json_double(limit: int = MAX_PAISA):
    def build():
        c, m = Ints("paisa mantissa")
        cases = []
        for e in range(-70, 30):
            if e < 0:
                s = 2**-e
                gap = 100 * m - c * s  # 100 * 2^-e * (x - c/100)
                nearest = And(gap <= 50, gap >= -50)
                wrong = Or(2 * gap >= s, 2 * gap <= -s)
                band = And(c * s >= 100 * 2**52, c * s < 100 * 2**53)
            else:
                gap = 100 * m * 2**e - c  # 100 * (x - c/100)
                nearest = And(2 * gap <= 100 * 2**e, 2 * gap >= -100 * 2**e)
                wrong = Or(2 * gap >= 1, 2 * gap <= -1)
                band = And(c >= 100 * 2 ** (52 + e), c < 100 * 2 ** (53 + e))
            cases.append(And(band, nearest, wrong))
        return [c >= 1, c <= limit, m >= 2**52, m <= 2**53, Or(*cases)], {
            "paisa": c,
            "mantissa": m,
        }

    return build


# --------------------------------------------------------------------------
# TypeScript scope.
# --------------------------------------------------------------------------

MONEY_WORDS = re.compile(
    r"\b(amount|monthly_rent|paid_amount|waived_amount|outstanding|tax_withheld|"
    r"late_fee_\w+|security_deposit|paisa|rupees?)\b"
)


def typescript_scope() -> int:
    """The Edge Functions must not touch money columns outside the
    generated database types (and tests). If one ever does, its arithmetic
    needs a check here."""
    root = REPO / "supabase" / "functions"
    hits = []
    files = sorted(root.rglob("*.ts"))
    for path in files:
        rel = path.relative_to(root).as_posix()
        if rel.startswith(("tests/", "coverage/")) or rel.endswith("database.types.ts"):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if MONEY_WORDS.search(line):
                hits.append(f"{rel}:{number}: {line.strip()}")
    print(f"== TypeScript scope: {len(files)} .ts files under supabase/functions")
    if hits:
        print("FAIL   money fields used outside database.types.ts:")
        for hit in hits:
            print(f"       {hit}")
        return 1
    print("ok     no money arithmetic or rounding in the Edge Functions")
    return 0


CHECKS = [
    Check(
        "halfUp == round(n/d) for every divisor in use",
        "money.dart divideRounded",
        "unsat",
        generic_equal(),
    ),
    Check(
        "mutant: halfUp ties toward zero",
        "divideRounded twiceRemainder > d",
        "sat",
        generic_equal(ties_toward_zero=True),
        mode="all",
    ),
    Check(
        "pg scale of rent*days/dim is at least 8",
        "app.prorated_rent select_div_scale",
        "unsat",
        prorated_scale(),
    ),
    Check(
        "mutant: rent numeric(22,2) -> scale below 8",
        "leases.monthly_rent",
        "sat",
        prorated_scale(limit=10**20 - 1),
    ),
    Check(
        "proration quotient: Dart == PostgreSQL",
        "proratedRent vs app.prorated_rent",
        "unsat",
        prorated_equal_linear(),
    ),
    Check(
        "mutant: rent numeric(22,2), 29 of 30 days",
        "leases.monthly_rent",
        "sat",
        prorated_witness(limit=10**20 - 1, days=29),
        mode="all",
    ),
    Check(
        "pg scale of outstanding*value/100 is at least 8",
        "app.late_fee_amount select_div_scale",
        "unsat",
        percent_scale(),
    ),
    Check(
        "percent fee: Dart == PostgreSQL",
        "PercentLateFee vs app.late_fee_amount",
        "unsat",
        percent_equal(),
    ),
    Check(
        "mutant: percent up to 999.99, no least() cap",
        "leases_late_fee_percent_check + least(...)",
        "sat",
        percent_equal(max_bp=99_999, witness_bp=99_999, cap=False),
        mode="all",
    ),
    Check(
        "flat fee: Dart == PostgreSQL", "FlatLateFee vs app.late_fee_amount", "unsat", flat_equal()
    ),
    Check(
        "daily fee with cap: Dart == PostgreSQL",
        "DailyLateFee vs app.late_fee_amount",
        "unsat",
        daily_equal(),
    ),
    Check(
        "mutant: daily fee rounded after the cap",
        "late_fee_amount before 20261104143928",
        "sat",
        daily_equal(round_after_cap=True),
    ),
    Check(
        "JSON double -> toStringAsFixed(2) is exact",
        "money.dart Money.fromJson(double)",
        "unsat",
        json_double(),
    ),
    Check(
        "mutant: amounts up to 10^16 rupees in JSON",
        "numeric(14,2)",
        "sat",
        json_double(limit=10**18),
    ),
]

if __name__ == "__main__":
    status = typescript_scope()
    status |= run("Dart half-up vs SQL round(numeric)", CHECKS, sys.argv)
    sys.exit(status)
