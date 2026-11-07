#!/usr/bin/env python3
"""Mutants of the Lean model, for run.sh's non-vacuity check ("all" mode).

Each mutant changes one definition the way a plausible bug would, in a
scratch copy of this directory. run.sh then builds the copy and runs
check-vectors. The expected outcome is either "proof <theorem>" (the first
error is inside that theorem) or "vectors" (everything still proves, but a
contract vector no longer matches).

    mutants.py list                 name<TAB>expected, one per line
    mutants.py apply NAME DIR       edit DIR in place (fails if the text is gone)
    mutants.py where FILE LINE      the declaration that contains FILE:LINE
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# name: (file, old text, new text, expected outcome, what it breaks)
MUTANTS: dict[str, tuple[str, str, str, str, str]] = {
    "halfup_ties_to_zero": (
        "Maalik/Rounding.lean",
        "| .halfUp => if twiceRemainder ≥ d then awayFromZero else quotient",
        "| .halfUp => if twiceRemainder > d then awayFromZero else quotient",
        "proof halfUp_spec",
        "divideRounded halfUp: ties toward zero",
    ),
    "halfeven_odd": (
        "Maalik/Rounding.lean",
        "else if quotient % 2 = 0 then quotient",
        "else if quotient % 2 = 1 then quotient",
        "proof halfEven_spec",
        "divideRounded halfEven: ties to odd",
    ),
    "floor_rounds_up": (
        "Maalik/Rounding.lean",
        "| .floor => if n < 0 then quotient - 1 else quotient",
        "| .floor => if n < 0 then quotient - 1 else quotient + 1",
        "proof floor_spec",
        "divideRounded floor: up for positive n",
    ),
    "sql_round_half_down": (
        "Maalik/Rounding.lean",
        "if n < 0 then -((2 * -n + d) / (2 * d)) else (2 * n + d) / (2 * d)",
        "if n < 0 then -((2 * -n + d) / (2 * d)) else (2 * n + d - 1) / (2 * d)",
        "proof halfUp_eq_sqlRound",
        "the SQL model rounds ties down",
    ),
    "allocate_no_leftover": (
        "Maalik/Money.lean",
        "  bump (allocBase m ratios) (remainderOrder (allocRems m ratios)) "
        "(m - (allocBase m ratios).sum)",
        "  bump (allocBase m ratios) (remainderOrder (allocRems m ratios)) 0",
        "proof allocateNat_sum",
        "allocate: leftover paisa not handed out",
    ),
    "allocate_smallest_remainders": (
        "Maalik/Money.lean",
        "  decide (rems.getD j 0 < rems.getD i 0) || (rems.getD i 0",
        "  decide (rems.getD i 0 < rems.getD j 0) || (rems.getD i 0",
        "proof bumped_largest",
        "allocate: extra paisa to the smallest remainders",
    ),
    "prorated_no_cap": (
        "Maalik/Rent.lean",
        "  else min rent (multiplyToStep rent days (daysInMonth y m))",
        "  else multiplyToStep rent days (daysInMonth y m)",
        "proof proratedRent_bounds",
        "proratedRent without Money.min(monthlyRent, ...)",
    ),
    "due_day_clamped_to_28": (
        "Maalik/Rent.lean",
        "  ⟨y, m, Nat.max 1 (Nat.min dueDay (daysInMonth y m))⟩",
        "  ⟨y, m, Nat.max 1 (Nat.min dueDay 28)⟩",
        "proof dueDate_eq_sql",
        "dueDate clamps to 28 instead of the month length",
    ),
    "anniversary_inclusive": (
        "Maalik/Rent.lean",
        "if candidate.before asOf then anniversaryLoop",
        "if !asOf.before candidate then anniversaryLoop",
        "vectors",
        "nextAnniversary skips an anniversary on the as-of date",
    ),
    "grace_inclusive": (
        "Maalik/LateFee.lean",
        "  if overdue ≤ 0 \u2228 daysLate ≤ graceDays then 0\n  else min (capFee",
        "  if overdue ≤ 0 \u2228 daysLate < graceDays then 0\n  else min (capFee",
        "proof feeFor_zero",
        "feeFor charges on the last day of grace",
    ),
    "no_max_fee": (
        "Maalik/LateFee.lean",
        "  else min (capFee p (roundToRupee (computeFee p overdue daysLate) .halfUp)) maxFee",
        "  else capFee p (roundToRupee (computeFee p overdue daysLate) .halfUp)",
        "proof feeFor_le_maxFee",
        "feeFor without the maxFee limit",
    ),
    "round_after_cap": (
        "Maalik/LateFee.lean",
        "  else min (capFee p (roundToRupee (computeFee p overdue daysLate) .halfUp)) maxFee",
        "  else min (roundToRupee (capFee p (computeFee p overdue daysLate)) .halfUp) maxFee",
        "proof feeFor_le_cap",
        "feeFor rounds after capping (a 99.50 cap becomes 100)",
    ),
    "overpay": (
        "Maalik/Allocation.lean",
        "    if remaining = 0 then ([], remaining)\n    else\n"
        "      let applied := min remaining c.outstanding",
        "    if remaining = 0 then ([], remaining)\n    else\n      let applied := c.outstanding",
        "proof dartLoop_rest",
        "planFifoAllocation applies the whole outstanding",
    ),
    "unchosen_rank_first": (
        "Maalik/Allocation.lean",
        "if c.id ∈ chosen then chosen.idxOf c.id + 1 else 2147483647",
        "if c.id ∈ chosen then chosen.idxOf c.id + 1 else 0",
        "proof rank_iff",
        "SQL rank puts unchosen charges first",
    ),
    "newest_due_first": (
        "Maalik/Allocation.lean",
        "(decide (a.dueKey < b.dueKey) || (a.dueKey == b.dueKey && decide (a.id ≤ b.id)))",
        "(decide (b.dueKey < a.dueKey) || (a.dueKey == b.dueKey && decide (a.id ≤ b.id)))",
        "vectors",
        "allocation pays the newest charge first",
    ),
    "deposit_paid": (
        "Maalik/Allocation.lean",
        "(charges.filter fun c => !(deposit && c.isSecurityDeposit)).mergeSort",
        "(charges.filter fun _ => true).mergeSort",
        "proof orderCharges_mem",
        "a deposit adjustment pays the security deposit",
    ),
}

DECL = re.compile(
    r"^(?:private\s+)?(?:theorem|def|lemma|abbrev|instance|structure|inductive)\s+(\S+)"
)


def where(file: Path, line: int) -> str:
    name = "?"
    for number, text in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        if number > line:
            break
        match = DECL.match(text)
        if match:
            name = match.group(1)
    return name


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[1] == "list":
        for name, (_, _, _, expected, _) in MUTANTS.items():
            print(f"{name}\t{expected}")
        return 0
    if len(argv) == 4 and argv[1] == "apply":
        file, old, new, _, _ = MUTANTS[argv[2]]
        path = Path(argv[3]) / file
        text = path.read_text(encoding="utf-8")
        if text.count(old) != 1:
            print(f"{argv[2]}: the text to mutate is not in {file} exactly once", file=sys.stderr)
            return 2
        path.write_text(text.replace(old, new), encoding="utf-8")
        return 0
    if len(argv) == 4 and argv[1] == "where":
        print(where(Path(argv[2]), int(argv[3])))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
