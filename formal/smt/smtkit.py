"""Shared bounds and a small harness for the Z3 checks in this directory.

Every check asks Z3 whether some input the code admits breaks a property.
"unsat" means no such input exists (the property is proved for every input
in the bounds); "sat" comes with a model (a counterexample). Each check
states the result it expects: "unsat" for the current code, "sat" for a
mutant that removes a bound or for a real finding.
"""

from __future__ import annotations

import sys
import time
from collections.abc import Callable
from dataclasses import dataclass

from z3 import ArithRef, BoolRef, If, Solver, sat, unsat

# --------------------------------------------------------------------------
# Bounds, all from the database CHECK constraints or the code that validates
# input (supabase/migrations, last definition wins).
# --------------------------------------------------------------------------

# numeric(14,2): |x| < 10^12 rupees. Every money column (charges.amount,
# payments.amount, leases.monthly_rent, ...) and private.require_valid_amount
# (p_amount > 999999999999.99 fails). In paisa: up to 10^14 - 1.
# mm_core Money.maxValue is the same.
MAX_PAISA = 10**14 - 1

# leases_late_fee_value_max_check (20261104143928_ledger_jobs_hardening.sql):
# late_fee_value <= 10000000 rupees (a flat fee or a daily rate).
MAX_LATE_FEE_VALUE_PAISA = 10_000_000 * 100

# leases_late_fee_percent_check: a percent late fee is at most 100 (%),
# i.e. 10000 basis points. leases_increment_percent_check: increment 0..100.
MAX_BASIS_POINTS = 10_000

# app.late_fee_amount / LateFeePolicy.maxFee: 999999999999 whole rupees.
MAX_FEE_PAISA = 999_999_999_999 * 100

# Dart CalendarDate admits years 1..9999: the longest span in days between
# 0001-01-01 and 9999-12-31 (proleptic Gregorian) is 3652058.
MAX_DART_DAYS = 3_652_058

# PostgreSQL 16 dates are int32 day numbers relative to 2000-01-01 between
# 4714-11-24 BC (-2451545) and 5874897-12-31 AD (2145031948)
# (src/include/datatype/timestamp.h: JULIAN_MINDAY .. JULIAN_MAXDAY,
# POSTGRES_EPOCH_JDATE). date - date is int32.
PG_MIN_DATE = -2_451_545
PG_MAX_DATE = 2_145_031_948

# RentMath.incrementedRent rounding steps (RentRounding.stepRupees).
RENT_STEPS = (1, 10, 50, 100, 500, 1000)

INT64_MIN = -(2**63)
INT64_MAX = 2**63 - 1
# Dart on the web compiles int to a JavaScript Number: every integer with
# |x| <= 2^53 is exact.
JS_SAFE = 2**53


# --------------------------------------------------------------------------
# Integer division as the code does it (constant positive divisors only, so
# every query stays in linear integer arithmetic).
# --------------------------------------------------------------------------


def round_half_away(n: ArithRef, d: int) -> ArithRef:
    """PostgreSQL round(n / d, 0): nearest integer, ties away from zero."""
    return If(n >= 0, (2 * n + d) / (2 * d), -((2 * -n + d) / (2 * d)))


def dart_half_up(n: ArithRef, d: int) -> ArithRef:
    """mm_core money.dart divideRounded(n, d, RoundingMode.halfUp), d > 0.

    Follows the Dart line by line: quotient = n ~/ d truncates toward zero,
    remainder = n.remainder(d) has the sign of n, and the quotient moves one
    away from zero when 2 * |remainder| >= d.
    """
    quotient = If(n >= 0, n / d, -((-n) / d))
    remainder = n - quotient * d
    away = If(n < 0, quotient - 1, quotient + 1)
    twice = If(remainder < 0, -remainder, remainder) * 2
    return If(remainder == 0, quotient, If(twice >= d, away, quotient))


def zmin(a: ArithRef, b: ArithRef) -> ArithRef:
    return If(a <= b, a, b)


# --------------------------------------------------------------------------
# The harness.
# --------------------------------------------------------------------------


@dataclass
class Check:
    """One satisfiability query.

    build() returns the constraints and the model terms to print. The
    constraints are the admitted inputs plus the NEGATION of the property.
    """

    name: str
    code: str
    expect: str  # "unsat" or "sat"
    build: Callable[[], tuple[list[BoolRef], dict[str, ArithRef]]]
    mode: str = "ci"  # "ci" checks also run in "all"


def run(title: str, checks: list[Check], argv: list[str]) -> int:
    mode = argv[1] if len(argv) > 1 else "ci"
    if mode not in ("ci", "all"):
        print(f"usage: {argv[0]} [ci|all]", file=sys.stderr)
        return 2
    print(f"== {title} ({mode} mode)")
    print(f"{'result':6} {'check':58} {'expected':8} {'got':8} {'time':>7}")
    failures = 0
    selected = [c for c in checks if mode == "all" or c.mode == "ci"]
    start_all = time.monotonic()
    for check in selected:
        constraints, terms = check.build()
        solver = Solver()
        solver.set("timeout", 300_000)
        solver.add(*constraints)
        start = time.monotonic()
        answer = solver.check()
        secs = time.monotonic() - start
        got = "sat" if answer == sat else "unsat" if answer == unsat else "unknown"
        ok = got == check.expect
        failures += 0 if ok else 1
        print(f"{'ok' if ok else 'FAIL':6} {check.name:58} {check.expect:8} {got:8} {secs:6.2f}s")
        if not ok:
            print(f"       code: {check.code}")
        if answer == sat:
            model = solver.model()
            values = ", ".join(
                f"{label}={model.eval(term, model_completion=True)}"
                for label, term in terms.items()
            )
            print(f"       model: {values}")
    total = len(selected)
    elapsed = time.monotonic() - start_all
    print(f"{total - failures}/{total} checks as expected ({elapsed:.1f}s)")
    return 1 if failures else 0
