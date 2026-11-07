"""Compares the results of the differential checks with spec.py.

usage: compare.py <output dir of gen_cases.py> [bend] [dart] [sql]

Each part prints its case count and its mismatches; the exit status is 1 if
any part has a mismatch (or a missing result), else 0.
"""

import calendar
import csv
import json
import re
import sys
from datetime import date
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec
import spec_mutants

INF = 2147483647


class Tally:
    def __init__(self):
        self.failures = 0
        self.failed = []

    def report(self, label, cases, bad, example=None):
        print(f"{label}: {cases} cases, {bad} mismatches")
        if bad:
            self.failures += 1
            self.failed.append(label)
            print(f"  first mismatch: {example}")


def paisa(text):
    value = Decimal(text)
    if value != value.to_integral_value():
        raise SystemExit(f"not whole paisa: {text}")
    return int(value)


def days_in(d):
    return calendar.monthrange(d.year, d.month)[1]


# Bend evaluation of SPEC.bend against spec.py


def check_bend(out, tally):
    text = (out / "eval" / "out.txt").read_text().strip()
    got = json.loads(re.sub(r"(\d+)n", r"\1", text))
    expected = json.loads((out / "eval" / "expected.json").read_text())
    bad = [(i, g, e) for i, (g, e) in enumerate(zip(got, expected, strict=False)) if g != e]
    if len(got) != len(expected):
        bad.append(("length", len(got), len(expected)))
    tally.report("bend SPEC.bend vs spec.py", len(expected), len(bad), bad[:1])


# Real Dart against spec.py


def fifo_model(c):
    chosen = c["chosen"]

    def rank(charge):
        return chosen.index(charge["id"]) if charge["id"] in chosen else len(chosen)

    ordered = [ch for ch in c["charges"] if not (c["deposit_adjustment"] and ch["deposit"])]
    ordered.sort(key=lambda ch: (rank(ch), ch["due"], ch["id"]))
    xs = [ch["outstanding"] for ch in ordered]
    amounts = spec.alloc(xs, c["payment"])
    return {
        "allocations": [[ch["id"], a] for ch, a in zip(ordered, amounts, strict=False)],
        "unallocated": spec.unallocated(xs, c["payment"]),
    }


def occupied_days(year, month, start, end):
    first = date(year, month, 1)
    last = date(year, month, calendar.monthrange(year, month)[1])
    if (end is not None and end < first) or start > last:
        return 0
    low = max(first, start)
    high = last if end is None else min(last, end)
    return (high - low).days + 1


def prorate_model(c):
    start = date.fromisoformat(c["start"])
    end = None if c["end"] is None else date.fromisoformat(c["end"])
    days = occupied_days(c["year"], c["month"], start, end)
    return spec.prorated_rent(c["rent"], days, calendar.monthrange(c["year"], c["month"])[1])


def billed_model(c):
    billing = date.fromisoformat(c["billing_starts_on"])
    period = (c["year"], c["month"])
    before = period < (billing.year, billing.month)
    first = period == (billing.year, billing.month)
    dim = calendar.monthrange(c["year"], c["month"])[1]
    dart = spec.billed_rent(c["rent"], c["prorate"], before, first, billing.day, dim)
    if not before and dart != spec.billed_rent_sql(
        c["rent"], c["prorate"], first, billing.day, dim
    ):
        return ("model disagrees with billed_rent_sql", dart)
    return dart


def split_model(c):
    parts = spec.split_evenly(abs(c["amount"]), c["count"])
    return [-p for p in parts] if c["amount"] < 0 else parts


def check_dart(out, tally):
    cases = json.loads((out / "dart_cases.json").read_text())
    results = json.loads((out / "dart_results.json").read_text())
    models = {
        "fifo": fifo_model,
        "split": split_model,
        "divide": lambda c: spec.half_up(c["n"], c["d"]),
        "prorate": prorate_model,
        "billed": billed_model,
        "fee": lambda c: spec.daily_late_fee(
            c["rate"], c["cap"], c["overdue"], c["days"], c["grace"]
        ),
    }
    for key, model in models.items():
        bad, example = 0, None
        for case, got in zip(cases[key], results[key], strict=True):
            want = model(case)
            if key == "divide" and spec.round_half(case["n"], case["d"]) != want:
                want = ("half_up and round_half disagree", want)
            if got != want:
                bad += 1
                example = example or (case, got, want)
        tally.report(f"dart {key} vs spec.py", len(cases[key]), bad, example)


# Real SQL against spec.py


def check_sql_pure(out, tally):
    bad = n = first_months = 0
    example = None
    for rent, month, dim, start, res in csv.reader((out / "sql" / "prorated.csv").open()):
        rent, dim = int(rent), int(dim)
        m, s = date.fromisoformat(month), date.fromisoformat(start)
        first = (m.year, m.month) == (s.year, s.month)
        model = spec.prorated_rent_sql(rent, first, s.day, dim)
        n += 1
        problem = model != paisa(res)
        if first:
            first_months += 1
            # law prorate_sql_matches_dart, on the SQL's own inputs
            problem = problem or spec.prorated_rent(rent, dim - s.day + 1, dim) != model
        if problem:
            bad += 1
            example = example or (rent, month, start, res, model)
    tally.report(
        f"sql app.prorated_rent vs spec.py ({first_months} billing-start months)", n, bad, example
    )
    bad = n = 0
    example = None
    for rate, cap, o, days, grace, res in csv.reader((out / "sql" / "latefee.csv").open()):
        rate, o, days, grace = int(rate), int(o), int(days), int(grace)
        cap = None if cap == "" else int(cap)
        model = spec.daily_late_fee_sql(rate, cap, o, days, grace)
        dart = spec.daily_late_fee(rate, cap, o, days, grace)
        n += 1
        if model != paisa(res) or dart != model:
            bad += 1
            example = example or (rate, cap, o, days, grace, res, model, dart)
    tally.report("sql app.late_fee_amount (daily) vs spec.py", n, bad, example)


def fifo_sql_model(scenarios):
    rows, unalloc, outst = {}, {}, {}
    for sc in scenarios:
        charges = [dict(c, out=c["amount"] - c["waived"]) for c in sc["charges"]]
        pays = []

        def allocate(p, chosen, charges=charges):
            rem = unalloc[p["id"]]
            if rem <= 0:
                return
            elig = [
                c
                for c in charges
                if not c["voided"]
                and c["out"] > 0
                and not (p["method"] == "deposit_adjustment" and c["kind"] == "security_deposit")
            ]

            def pos(c):
                return chosen.index(c["id"]) + 1 if chosen and c["id"] in chosen else INF

            elig.sort(key=lambda c: (pos(c), c["due"], c["id"]))
            xs = [c["out"] for c in elig]
            amounts = spec.alloc(xs, rem)
            for c, amount in zip(elig, amounts, strict=False):
                if amount > 0:
                    key = (p["id"], c["id"])
                    rows[key] = rows.get(key, 0) + amount
            for c, left in zip(elig, spec.settle(xs, amounts), strict=False):
                c["out"] = left
            unalloc[p["id"]] = spec.unallocated(xs, rem)

        def apply_credit(pays=pays, allocate=allocate):
            for p in sorted(pays, key=lambda p: (p["paid_on"], p["id"])):
                if unalloc[p["id"]] > 0:
                    allocate(p, None)

        for st in sc["steps"]:
            p = st["pay"]
            pays.append(p)
            unalloc[p["id"]] = p["amount"] + p["tax"]
            if st["mode"] in ("now", "chosen"):
                allocate(p, st["chosen"])
        if sc["extra"]:
            charges.append(dict(sc["extra"], out=sc["extra"]["amount"]))
            apply_credit()
        if sc["apply_credit_at_end"]:
            apply_credit()
        for c in charges:
            outst[c["id"]] = c["out"]
    return rows, unalloc, outst


def check_sql_fifo(out, tally):
    scenarios = json.loads((out / "sql" / "fifo_plan.json").read_text())
    rows, unalloc, outst = fifo_sql_model(scenarios)
    got_rows, got_unalloc, got_outst = {}, {}, {}
    for kind, a, b, v in csv.reader((out / "sql" / "fifo.csv").open()):
        if kind == "A":
            got_rows[(a, b)] = int(v)
        elif kind == "P":
            got_unalloc[a] = int(v)
        else:
            got_outst[a] = int(v)
    for label, want, got in (
        ("allocation rows", rows, got_rows),
        ("payments' unallocated amounts", unalloc, got_unalloc),
        ("charges' outstanding amounts", outst, got_outst),
    ):
        keys = set(want) | set(got)
        bad = [k for k in keys if want.get(k) != got.get(k)]
        example = (bad[0], want.get(bad[0]), got.get(bad[0])) if bad else None
        tally.report(
            f"sql allocate_payment/apply_lease_credit {label} vs spec.py",
            len(keys),
            len(bad),
            example,
        )


def check_sql_billing(out, tally):
    plan = json.loads((out / "sql" / "billing_plan.json").read_text())
    today = date.fromisoformat(plan["today"])
    want = {}
    dart_bad = 0
    for lease in plan["leases"]:
        billing = date.fromisoformat(lease["billing"])
        last = date.fromisoformat(lease["moveout"]) if lease["moveout"] else today
        change = lease["change"]
        month = date(billing.year, billing.month, 1)
        while month <= date(today.year, today.month, 1):
            rent = lease["rent"]
            if change and month >= date.fromisoformat(change["month"]):
                rent = change["rent"]
            first = month == date(billing.year, billing.month, 1)
            amount = spec.billed_rent_sql(
                rent, lease["prorate"], first, billing.day, days_in(month)
            )
            if (
                spec.billed_rent(rent, lease["prorate"], False, first, billing.day, days_in(month))
                != amount
            ):
                dart_bad += 1
            voided = month > date(last.year, last.month, 1)
            if amount > 0:
                want[(lease["id"], str(month))] = (amount, voided)
            month = date(month.year + month.month // 12, month.month % 12 + 1, 1)
    got = {}
    for lease_id, month, amount, voided in csv.reader((out / "sql" / "billing.csv").open()):
        got[(lease_id, month)] = (int(amount), voided == "true")
    keys = set(want) | set(got)
    bad = [k for k in keys if want.get(k) != got.get(k)]
    example = (bad[0], want.get(bad[0]), got.get(bad[0])) if bad else None
    voided = sum(1 for v in want.values() if v[1])
    tally.report(
        f"sql sync_lease_billing/change_rent/end_lease rent charges vs spec.py ({voided} voided)",
        len(keys),
        len(bad) + dart_bad,
        example,
    )


def main():
    out = Path(sys.argv[1])
    mutants = [arg.split("=", 1)[1] for arg in sys.argv[2:] if arg.startswith("mutant=")]
    parts = [arg for arg in sys.argv[2:] if not arg.startswith("mutant=")] or [
        "bend",
        "dart",
        "sql",
    ]
    for name in mutants:
        spec_mutants.apply(name, spec)
        print(f"spec.py mutant: {name}; expected mismatches in: {spec_mutants.EXPECTED[name]}")
    tally = Tally()
    if "bend" in parts:
        check_bend(out, tally)
    if "dart" in parts:
        check_dart(out, tally)
    if "sql" in parts:
        check_sql_pure(out, tally)
        check_sql_fifo(out, tally)
        check_sql_billing(out, tally)
    if mutants:
        # a mutant is caught when every part it should break reports mismatches
        expected = [label for name in mutants for label in spec_mutants.EXPECTED[name]]
        missed = [e for e in expected if not any(f.startswith(e) for f in tally.failed)]
        if missed:
            print(f"MUTANT MISSED by: {missed}")
            sys.exit(1)
        print("MUTANT CAUGHT")
        print(f"by: {tally.failed}")
        return
    if tally.failures:
        print(f"FIDELITY: {tally.failures} parts with mismatches")
        sys.exit(1)
    print("FIDELITY: all parts match")


if __name__ == "__main__":
    main()
