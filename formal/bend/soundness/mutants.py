"""Writes the mutants of the Bend proofs, for run.sh's soundness step.

usage: mutants.py <dir with SPEC.bend, LAWS.bend, PROOF.bend> <output dir>

Two kinds of mutant:

* Model mutants (non-vacuity). Each one removes, from SPEC.bend, the
  mechanism of the code that a law depends on (the cap on a prorated rent,
  the exit of the allocation loop, rounding before capping, ...). The
  mutant's PROOF.bend must then fail to check, and its CEX.bend proves, by
  evaluation, a concrete input on which the mutated model breaks each law
  named in `laws`. The same CEX.bend must FAIL against the real SPEC.bend:
  the counterexample is specific to the mutation.
* Gate mutants. Each one tries to sneak an unsound proof past the checker
  (an open law, @unsafe, a partial def, a TODO hole, a missing proof, a
  redefined model, a bogus proof) and must be rejected.

The manifest (manifest.tsv) has one line per mutant:
name, command (check = --check-only, verdict = --verdict), the text the
checker's output must contain, whether there is a CEX.bend, the laws.
"""

import shutil
import sys
from pathlib import Path

FILES = ("SPEC.bend", "LAWS.bend", "PROOF.bend")
CEX_HEAD = "import Base\nimport ./SPEC.bend as Spec\n\n"

PICK = """# a clamp that sets the fee to 0 instead of maxFee
def daily_fee.pick(x: Nat, b: Bool) -> Nat:
  match b:
    case True{}:
      0n
    case False{}:
      x
"""

# (name, edits [(file, old, new)], appends [(file, text)], laws, cex body, command, expect)
# expect: the text the failing check must print (the def it stops at, or the
# reason it gives); every mutant must also print SOME PROOFS FAIL.
MODEL = [
    (
        "le_unit_for_succ_zero",
        [("SPEC.bend", "    case 1n+a1 0n:\n      Empty\n", "    case 1n+a1 0n:\n      Unit\n")],
        ["le_is_base_le"],
        "# 1 <= 0 has a proof, but Base says 1 <= 0 is False\n"
        "def cex_h() -> Spec.LE(1n, 0n):\n  Unit{}\n"
        "def cex_v() -> {Nat.is_le(1n, 0n) == False{} : Bool}:\n  {==}\n",
        "Location: le_trans",
    ),
    (
        "le_empty_for_zero",
        [("SPEC.bend", "    case 0n b0:\n      Unit\n", "    case 0n b0:\n      Empty\n")],
        ["base_le_is_le"],
        "# Base says 0 <= 0, but 0 <= 0 has no proof\n"
        "def cex_v() -> {Nat.is_le(0n, 0n) == True{} : Bool}:\n  {==}\n"
        "def cex_h(h: Spec.LE(0n, 0n)) -> Empty:\n  h\n",
        "Location: le_refl",
    ),
    (
        "fifo_leftover_dropped",
        [("SPEC.bend", "    case Nil{}:\n      rem\n", "    case Nil{}:\n      0n\n")],
        ["fifo_conserves"],
        "# Rs 0.03 against one charge of Rs 0.01: 1 + 0 is not 3\n"
        "def cex() -> {Nat.is_eq(Nat.add(Spec.sum(Spec.alloc([1n], 3n)), Spec.unallocated([1n], 3n)), 3n) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: Laws.fifo_conserves",
    ),
    (
        "fifo_applies_whole_charge",
        [("SPEC.bend", "+a = Nat.min(1n+r, h)", "+a = h")],
        ["fifo_allocated_le_payment"],
        "# 2 paisa against a charge of 5 allocates 5\n"
        "def cex() -> {Nat.is_le(Spec.sum(Spec.alloc([5n], 2n)), 2n) == False{} : Bool}:\n  {==}\n",
        "Location: Laws.fifo_conserves",
    ),
    (
        "fifo_applies_whole_payment",
        [("SPEC.bend", "+a = Nat.min(1n+r, h)", "+a = {1n+r : Nat}")],
        ["fifo_bounded"],
        "# 3 paisa against a charge of 1 puts 3 on it\n"
        "def cex() -> {Nat.is_le(Spec.at(Spec.alloc([1n], 3n), 0n), Spec.at([1n], 0n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: Laws.fifo_conserves",
    ),
    (
        "fifo_stops_after_first",
        [("SPEC.bend", "a <> alloc(t, Nat.sub(1n+r, a))", "a <> Nil{}")],
        ["fifo_leftover_settles_all"],
        "# 5 against [1, 1]: 3 is left over, yet the second charge gets nothing\n"
        "def cex_rest() -> {Spec.unallocated([1n, 1n], 5n) == 3n : Nat}:\n  {==}\n"
        "def cex() -> {List.length(&2, Nat, Spec.alloc([1n, 1n], 5n)) == 1n : Nat}:\n  {==}\n",
        "Location: Laws.fifo_conserves",
    ),
    (
        "fifo_spreads_one_paisa",
        [("SPEC.bend", "+a = Nat.min(1n+r, h)", "+a = Nat.min(1n+r, Nat.min(h, 1n))")],
        ["fifo_order"],
        "# 3 against [2, 2]: charge 1 is paid while charge 0 still owes 1\n"
        "def cex() -> {Spec.alloc([2n, 2n], 3n) == [1n, 1n] : List<&2, Nat>}:\n  {==}\n",
        "Location: Laws.fifo_conserves",
    ),
    (
        "fifo_no_exit",
        [
            (
                "SPEC.bend",
                "          # Dart `if (remaining.isZero) break;`\n          Nil{}\n",
                "          # Dart `if (remaining.isZero) break;`\n          0n <> alloc(t, 0n)\n",
            )
        ],
        ["fifo_rows_positive"],
        "# 1 against [1, 1]: without the exit the loop writes a 0 row for charge 1\n"
        "def cex() -> {Spec.alloc([1n, 1n], 1n) == [1n, 0n] : List<&2, Nat>}:\n  {==}\n",
        "",
    ),
    (
        "settle_forgets_payment",
        [("SPEC.bend", "Nat.sub(x, y) <> settle(xt, yt)", "x <> settle(xt, yt)")],
        ["fifo_two_payments"],
        "# two payments of 2 against a charge of 2 pay it 4\n"
        "def cex() -> {Nat.is_le(Nat.add(Spec.at(Spec.alloc([2n], 2n), 0n), Spec.at(Spec.alloc(Spec.settle([2n], Spec.alloc([2n], 2n)), 2n), 0n)), 2n) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: at_settle",
    ),
    (
        "credit_against_original_balance",
        [
            (
                "SPEC.bend",
                "Nat.add(at(a, i), paid_to(pt, settle(xs, a), i))",
                "Nat.add(at(a, i), paid_to(pt, xs, i))",
            )
        ],
        ["fifo_payments_conserve", "fifo_payments_never_overpay"],
        "# payments of 2 and 2 against a charge of 2, each allocated against the\n"
        "# original balance: 4 paid, 0 outstanding\n"
        "def cex_conserve() -> {Nat.is_eq(Nat.add(Spec.paid_to([2n, 2n], [2n], 0n), Spec.at(Spec.outstanding([2n, 2n], [2n]), 0n)), 2n) == False{} : Bool}:\n"
        "  {==}\n"
        "def cex_overpay() -> {Nat.is_le(Spec.paid_to([2n, 2n], [2n], 0n), 2n) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: Laws.fifo_payments_conserve",
    ),
    (
        "split_drops_slots",
        [("SPEC.bend", "(1n+h) <> split.bump(t, k)", "(1n+h) <> Nil{}")],
        ["split_count"],
        "# 5 paisa in 3 parts gives 1 part\n"
        "def cex() -> {List.length(&2, Nat, Spec.split_evenly(5n, 3n)) == 1n : Nat}:\n  {==}\n",
        "Location: len_bump",
    ),
    (
        "split_no_leftover",
        [
            (
                "SPEC.bend",
                "split.bump(parts, Nat.sub(m, sum(parts)))",
                "split.bump(parts, 0n)",
            )
        ],
        ["split_sum"],
        "# 5 paisa in 3 parts adds up to 3\n"
        "def cex() -> {Spec.sum(Spec.split_evenly(5n, 3n)) == 3n : Nat}:\n  {==}\n",
        "Location: Laws.split_count",
    ),
    (
        "split_leftover_to_first",
        [("SPEC.bend", "(1n+h) <> split.bump(t, k)", "Nat.add(h, 1n+k) <> t")],
        ["split_fair"],
        "# 5 paisa in 3 parts gives [3, 1, 1]: part 0 is more than part 1 + 1\n"
        "def cex() -> {Nat.is_le(Spec.at(Spec.split_evenly(5n, 3n), 0n), Nat.add(Spec.at(Spec.split_evenly(5n, 3n), 1n), 1n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: len_bump",
    ),
    (
        "round_half_adds_one",
        [
            (
                "SPEC.bend",
                "Nat.div(Nat.add(Nat.mul(2n, n), d), Nat.mul(2n, d))",
                "Nat.div(Nat.add(Nat.mul(2n, n), Nat.mul(2n, d)), Nat.mul(2n, d))",
            )
        ],
        ["round_half_lower"],
        "# 0 / 1 rounds to 1\n"
        "def cex() -> {Nat.is_le(Nat.mul(Nat.mul(2n, 1n), Spec.round_half(0n, 1n)), Nat.add(Nat.mul(2n, 0n), 1n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: half_up_agree",
    ),
    (
        "round_half_truncates",
        [
            (
                "SPEC.bend",
                "Nat.div(Nat.add(Nat.mul(2n, n), d), Nat.mul(2n, d))",
                "Nat.div(Nat.mul(2n, n), Nat.mul(2n, d))",
            )
        ],
        ["round_half_upper"],
        "# 1 / 2 rounds to 0\n"
        "def cex() -> {Nat.is_le(1n+Nat.add(Nat.mul(2n, 1n), 2n), Nat.mul(Nat.mul(2n, 2n), Nat.add(Spec.round_half(1n, 2n), 1n))) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: half_up_agree",
    ),
    (
        "half_up_ties_down",
        [
            (
                "SPEC.bend",
                "half_up.away(q, Nat.is_ge(Nat.mul(1n+k, 2n), d))",
                "half_up.away(q, Nat.is_gt(Nat.mul(1n+k, 2n), d))",
            )
        ],
        ["half_up_agrees"],
        "# Dart rounds 1 / 2 down to 0, SQL up to 1\n"
        "def cex() -> {Nat.is_eq(Spec.half_up(1n, 2n), Spec.round_half(1n, 2n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: agree_rem",
    ),
    (
        "prorate_no_full_month_shortcut",
        [
            (
                "SPEC.bend",
                "    case True{}:\n      rent\n    case False{}:\n      prorated_rent.some(rent, days, len)",
                "    case True{}:\n      prorated_rent.some(rent, days, len)\n    case False{}:\n      prorated_rent.some(rent, days, len)",
            )
        ],
        ["prorate_full_month"],
        "# Rs 1.49 for all 3 days of a 3-day month bills Rs 1.00\n"
        "def cex() -> {Spec.prorated_rent(149n, 3n, 3n) == 100n : Nat}:\n  {==}\n",
        "Location: Laws.prorate_full_month",
    ),
    (
        "prorate_zero_days_full_rent",
        [
            (
                "SPEC.bend",
                "    case 0n:\n      0n\n    case 1n+k:\n      Nat.min(rent,",
                "    case 0n:\n      rent\n    case 1n+k:\n      Nat.min(rent,",
            )
        ],
        ["prorate_no_days"],
        "# no day of a 3-day month bills the full Rs 0.05\n"
        "def cex() -> {Spec.prorated_rent(5n, 0n, 3n) == 5n : Nat}:\n  {==}\n",
        "Location: Laws.prorate_no_days",
    ),
    (
        "prorate_no_cap",
        [
            (
                "SPEC.bend",
                "Nat.min(rent, multiply_to_rupee(rent, 1n+k, len))",
                "multiply_to_rupee(rent, 1n+k, len)",
            )
        ],
        ["prorate_le_rent", "prorate_paisa_rent_capped"],
        "# without Money.min, Rs 1.99 for 30 of 31 days bills Rs 2.00 (finding 1\n"
        "# of the earlier audit)\n"
        "def cex() -> {Spec.prorated_rent(199n, 30n, 31n) == 200n : Nat}:\n  {==}\n",
        "Location: some_le_rent",
    ),
    (
        "prorate_rounds_up_a_rupee",
        [
            (
                "SPEC.bend",
                "Nat.mul(half_up(Nat.mul(paisa, num), Nat.mul(den, 100n)), 100n)",
                "Nat.mul(1n+half_up(Nat.mul(paisa, num), Nat.mul(den, 100n)), 100n)",
            )
        ],
        ["prorate_near_exact_upper"],
        "# Rs 10.00 for 1 of 3 days bills Rs 4.00, more than Rs 0.50 above Rs 3.33\n"
        "def cex() -> {Nat.is_le(Nat.mul(3n, Spec.prorated_rent(1000n, 1n, 3n)), Nat.add(Nat.mul(1000n, 1n), Nat.mul(50n, 3n))) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: upper_some",
    ),
    (
        "prorate_truncates",
        [
            (
                "SPEC.bend",
                "Nat.mul(half_up(Nat.mul(paisa, num), Nat.mul(den, 100n)), 100n)",
                "Nat.mul(Nat.div(Nat.mul(paisa, num), Nat.mul(den, 100n)), 100n)",
            )
        ],
        ["prorate_near_exact_lower"],
        "# Rs 10.00 for 2 of 3 days bills Rs 6.00, more than Rs 0.50 below Rs 6.67\n"
        "def cex() -> {Nat.is_le(Nat.mul(1000n, 2n), Nat.mul(3n, Nat.add(Spec.prorated_rent(1000n, 2n, 3n), 50n))) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: upper_some",
    ),
    (
        "sql_prorate_no_least",
        [
            (
                "SPEC.bend",
                "      Nat.min(rent, Nat.mul(round_half(Nat.mul(rent, Nat.add(Nat.sub(dim, start), 1n)), Nat.mul(dim, 100n)), 100n))",
                "      Nat.mul(round_half(Nat.mul(rent, Nat.add(Nat.sub(dim, start), 1n)), Nat.mul(dim, 100n)), 100n)",
            )
        ],
        [
            "prorate_sql_matches_dart",
            "billed_first_month_matches_dart",
            "billed_rent_matches_ledger",
        ],
        "# without least(p_rent, ...), SQL bills Rs 0.99 from day 2 of a 3-day month\n"
        "# at Rs 1.00; Dart at Rs 0.99\n"
        "def cex_sql() -> {Nat.is_eq(Spec.prorated_rent_sql(99n, True{}, 2n, 3n), Spec.prorated_rent(99n, 2n, 3n)) == False{} : Bool}:\n"
        "  {==}\n"
        "def cex_first() -> {Nat.is_eq(Spec.billed_rent_sql(99n, True{}, True{}, 2n, 3n), Spec.prorated_rent(99n, 2n, 3n)) == False{} : Bool}:\n"
        "  {==}\n"
        "def cex_billed() -> {Nat.is_eq(Spec.billed_rent(99n, True{}, False{}, True{}, 2n, 3n), Spec.billed_rent_sql(99n, True{}, True{}, 2n, 3n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: Laws.prorate_sql_matches_dart",
    ),
    (
        "dart_ignores_prorate_flag",
        [
            (
                "SPEC.bend",
                "    case False{}:\n      rent\n    case True{}:\n      prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim)",
                "    case False{}:\n      prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim)\n    case True{}:\n      prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim)",
            )
        ],
        ["billed_rent_matches_ledger"],
        "# prorate_first_month off, billing from day 2 of a 3-day month at Rs 3.00:\n"
        "# Dart previews Rs 2.00, the ledger bills Rs 3.00\n"
        "def cex() -> {Nat.is_eq(Spec.billed_rent(300n, False{}, False{}, True{}, 2n, 3n), Spec.billed_rent_sql(300n, False{}, True{}, 2n, 3n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: Laws.billed_rent_matches_ledger",
    ),
    (
        "dart_bills_before_start",
        [
            (
                "SPEC.bend",
                "    case True{}:\n      0n\n    case False{}:\n      billed_rent.month",
                "    case True{}:\n      rent\n    case False{}:\n      billed_rent.month",
            )
        ],
        ["billed_rent_before_start"],
        "# a month before billing starts is billed Rs 0.05\n"
        "def cex() -> {Spec.billed_rent(5n, True{}, True{}, False{}, 1n, 3n) == 5n : Nat}:\n  {==}\n",
        "Location: Laws.billed_rent_before_start",
    ),
    (
        "sql_prorates_every_month",
        [
            (
                "SPEC.bend",
                "  match first:\n    case False{}:\n      rent\n    case True{}:\n      prorated_rent_sql.later(",
                "  match first:\n    case False{}:\n      prorated_rent_sql.later(rent, start, dim, Nat.is_gt(start, 1n))\n    case True{}:\n      prorated_rent_sql.later(",
            )
        ],
        ["billed_later_month_full"],
        "# a later month of a lease billed from day 2 (Rs 3.00, 3-day month) bills Rs 2.00\n"
        "def cex() -> {Spec.billed_rent_sql(300n, True{}, False{}, 2n, 3n) == 200n : Nat}:\n  {==}\n",
        "Location: Laws.billed_rent_matches_ledger",
    ),
    (
        "fee_ignores_overdue",
        [
            (
                "SPEC.bend",
                "  match overdue:\n    case 0n:\n      0n\n    case 1n+o:\n      daily_late_fee.late(",
                "  match overdue:\n    case 0n:\n      daily_late_fee.late(rate, cap, days, top, Nat.is_le(days, grace))\n    case 1n+o:\n      daily_late_fee.late(",
            )
        ],
        ["late_fee_nothing_overdue"],
        "# nothing overdue, 8 days late, grace 5, Rs 1.00 a day: Rs 8.00\n"
        "def cex() -> {Spec.daily_late_fee(100n, None{}, 0n, 8n, 5n, 1000n) == 800n : Nat}:\n  {==}\n",
        "Location: Laws.late_fee_nothing_overdue",
    ),
    (
        "fee_grace_strict",
        [
            (
                "SPEC.bend",
                "      daily_late_fee.late(rate, cap, days, top, Nat.is_le(days, grace))",
                "      daily_late_fee.late(rate, cap, days, top, Nat.is_lt(days, grace))",
            )
        ],
        ["late_fee_in_grace"],
        "# 5 days late with 5 days of grace is charged Rs 5.00\n"
        "def cex() -> {Spec.daily_late_fee(100n, None{}, 1n, 5n, 5n, 1000n) == 500n : Nat}:\n  {==}\n",
        "Location: Laws.late_fee_in_grace",
    ),
    (
        "fee_zero_above_max",
        [
            (
                "SPEC.bend",
                "def daily_fee(+rate: Nat, +days: Nat, +top: Nat) -> Nat:\n  Nat.min(Nat.mul(rate, days), top)\n",
                PICK
                + "def daily_fee(+rate: Nat, +days: Nat, +top: Nat) -> Nat:\n"
                + "  daily_fee.pick(Nat.mul(rate, days), Nat.is_gt(Nat.mul(rate, days), top))\n",
            )
        ],
        ["late_fee_monotone"],
        "# a clamp that zeroes the fee: Rs 1.00 a day, maxFee Rs 5.00, 5 days\n"
        "# late is charged Rs 5.00 but 6 days late nothing\n"
        "def cex() -> {Nat.is_le(Spec.daily_late_fee(100n, None{}, 1n, 5n, 0n, 500n), Spec.daily_late_fee(100n, None{}, 1n, 6n, 0n, 500n)) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: late_fee_mono",
    ),
    (
        "fee_cap_before_rounding",
        [
            (
                "SPEC.bend",
                "      Nat.min(cap_fee(cap, round_to_rupee(daily_fee(rate, days, top))), top)",
                "      Nat.min(round_to_rupee(cap_fee(cap, daily_fee(rate, days, top))), top)",
            )
        ],
        ["late_fee_le_cap", "late_fee_paisa_cap_capped"],
        "# capping before rounding (the code before 20261104143928): Rs 1.00 a day,\n"
        "# cap Rs 2.50, 8 days late after 5 days of grace is charged Rs 3.00\n"
        "def cex() -> {Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, Nat.add(800n, 0n)) == 300n : Nat}:\n"
        "  {==}\n",
        "Location: late_mono.go",
    ),
    (
        "fee_no_max",
        [
            ("SPEC.bend", "  Nat.min(Nat.mul(rate, days), top)\n", "  Nat.mul(rate, days)\n"),
            (
                "SPEC.bend",
                "      Nat.min(cap_fee(cap, round_to_rupee(daily_fee(rate, days, top))), top)",
                "      cap_fee(cap, round_to_rupee(daily_fee(rate, days, top)))",
            ),
        ],
        ["late_fee_le_max"],
        "# without maxFee, Rs 1.00 a day for 20 days is charged Rs 20.00 above a\n"
        "# maxFee of Rs 10.00\n"
        "def cex() -> {Spec.daily_late_fee(100n, None{}, 1n, 20n, 0n, 1000n) == 2000n : Nat}:\n  {==}\n",
        "Location: late_fee_mono",
    ),
    (
        "sql_fee_cap_before_rounding",
        [
            (
                "SPEC.bend",
                "      Nat.min(Nat.min(Nat.mul(round_half(Nat.mul(rate, days), 100n), 100n), daily_late_fee_sql.cap(cap, top)), top)",
                "      Nat.min(Nat.mul(round_half(Nat.min(Nat.mul(rate, days), daily_late_fee_sql.cap(cap, top)), 100n), 100n), top)",
            )
        ],
        ["late_fee_sql_matches_dart"],
        "# the SQL before 20261104143928 capped first: Rs 1.00 a day, cap Rs 2.50,\n"
        "# 8 days late: SQL Rs 3.00, Dart Rs 2.50 (maxFee Rs 10.00)\n"
        "def cex() -> {Nat.is_eq(Spec.daily_late_fee_sql(100n, Some{250n}, 1n, 8n, 5n, Nat.mul(10n, 100n)), Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, Nat.mul(10n, 100n))) == False{} : Bool}:\n"
        "  {==}\n",
        "Location: late_sql.go",
    ),
]


FALSE_LAW = """
law prorate_le_half:
  for +rent: Nat
  for +days: Nat
  for +len: Nat
  Spec.LE(Spec.prorated_rent(rent, days, len), Nat.mul(rent, 0n))
"""

# (name, edits, appends, command, expect)
GATE = [
    ("open_law", [], [("LAWS.bend", FALSE_LAW)], "check", "TODO found"),
    (
        "bogus_proof",
        [],
        [
            ("LAWS.bend", FALSE_LAW),
            (
                "PROOF.bend",
                "\ndef Laws.prorate_le_half(rent, days, len):\n  Laws.prorate_le_rent(rent, days, len)\n",
            ),
        ],
        "check",
        "Location: Laws.prorate_le_half",
    ),
    (
        "unsafe_loop",
        [],
        [
            ("LAWS.bend", "\nlaw zero_is_one:\n  {0n == 1n : Nat}\n"),
            (
                "PROOF.bend",
                "\n@unsafe def loop(n: Nat) -> {0n == 1n : Nat}:\n  loop(n)\n\n"
                "def Laws.zero_is_one():\n  loop(0n)\n",
            ),
        ],
        "check",
        "rely on unsafe",
    ),
    (
        "partial_def",
        [],
        [
            ("LAWS.bend", "\nlaw zero_is_one:\n  {0n == 1n : Nat}\n"),
            (
                "PROOF.bend",
                "\ndef spin?(n: Nat) -> {0n == 1n : Nat}:\n  spin(n)\n\n"
                "def Laws.zero_is_one():\n  spin(0n)\n",
            ),
        ],
        "check",
        "rely on unsafe",
    ),
    (
        "missing_proof",
        [
            (
                "PROOF.bend",
                "def Laws.late_fee_paisa_cap_capped(k):\n  {==}\n",
                "",
            )
        ],
        [],
        "check",
        "TODO found",
    ),
    (
        "todo_hole",
        [
            (
                "PROOF.bend",
                "def Laws.late_fee_paisa_cap_capped(k):\n  {==}\n",
                "def Laws.late_fee_paisa_cap_capped(k):\n  ?TODO\n",
            )
        ],
        [],
        "check",
        "TODO found",
    ),
    (
        "proof_redefines_model",
        [],
        [("PROOF.bend", "\ndef Spec.round_half(+n: Nat, +d: Nat) -> Nat:\n  Spec.half_up(n, d)\n")],
        "check",
        "Spec is an import's alias",
    ),
    (
        "weakened_law_type",
        [
            (
                "PROOF.bend",
                "def Laws.prorate_le_rent(rent, days, len):\n",
                "def Laws.prorate_le_rent(rent: Nat, days: Nat, len: Nat) -> Spec.LE(Spec.prorated_rent(rent, days, len), Nat.add(rent, 50n)):\n",
            )
        ],
        [],
        "check",
        "expected : a name",
    ),
    (
        "swapped_hypothesis",
        [("LAWS.bend", "  for  before: Spec.LT(j, i)\n", "  for  before: Spec.LT(i, j)\n")],
        [],
        "check",
        "Location: Laws.fifo_order",
    ),
    (
        "unsafe_verdict",
        [],
        [
            ("LAWS.bend", "\nlaw zero_is_one:\n  {0n == 1n : Nat}\n"),
            (
                "PROOF.bend",
                "\n@unsafe def loop(n: Nat) -> {0n == 1n : Nat}:\n  loop(n)\n\n"
                "def Laws.zero_is_one():\n  loop(0n)\n",
            ),
        ],
        "verdict",
        "SOME PROOFS FAIL",
    ),
]


def copy_base(src: Path, dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for name in FILES:
        shutil.copy(src / name, dest / name)


def apply(dest: Path, name: str, edits, appends) -> None:
    for file, old, new in edits:
        path = dest / file
        text = path.read_text()
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"mutant {name}: {file} has {count} copies of {old!r}, not 1")
        path.write_text(text.replace(old, new))
    for file, extra in appends:
        with (dest / file).open("a") as handle:
            handle.write(extra)


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    names = set()
    for name, edits, laws, cex, expect in MODEL:
        if name in names:
            raise SystemExit(f"duplicate mutant {name}")
        names.add(name)
        dest = out / name
        copy_base(src, dest)
        apply(dest, name, edits, [])
        (dest / "CEX.bend").write_text(CEX_HEAD + cex)
        rows.append((name, "check", expect or "SOME PROOFS FAIL", "cex", ",".join(laws)))
    for name, edits, appends, command, expect in GATE:
        if name in names:
            raise SystemExit(f"duplicate mutant {name}")
        names.add(name)
        dest = out / name
        copy_base(src, dest)
        apply(dest, name, edits, appends)
        rows.append((name, command, expect, "-", "-"))
    lines = ["\t".join(row) for row in rows]
    (out / "manifest.tsv").write_text("\n".join(lines) + "\n")
    print(f"{len(MODEL)} model mutants, {len(GATE)} gate mutants")


if __name__ == "__main__":
    main()
