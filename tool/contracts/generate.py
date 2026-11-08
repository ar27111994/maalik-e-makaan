#!/usr/bin/env python3
"""Builds the client/server contract vectors for rent arithmetic.

The app previews dues, proration, anniversaries and late fees in Dart
(packages/mm_core) while the database computes the authoritative ledger in
SQL. Both are tested against the same vectors so they can never disagree.

Expected values are computed here with an *independent* exact reference
implementation (Python Fractions, half-up ties) rather than by either side.

Outputs (all committed):
  contracts/rent_math_vectors.json
  supabase/tests/database/10_contract_vectors.test.sql
  supabase/tests/database/12_clean_text_contract.test.sql (from contracts/clean_text.json,
    which is written by hand: it is the text-safety contract itself)
  supabase/tests/database/13_ledger_contract.test.sql (allocation and billed-rent vectors,
    exercised through the real record_payment and billing on fresh leases)
  contracts/identity_vectors.json and supabase/tests/database/20_identity_contract.test.sql
    (stored phone numbers, CNICs, IBANs and Raast IDs: what mm_core reads back from a row
    is exactly what the database CHECKs accept)

Usage:
  tool/contracts/generate.py           # (re)write every file
  tool/contracts/generate.py --check   # exit 1 if any file is stale (CI)
"""

from __future__ import annotations

import calendar
import json
import sys
from datetime import date
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Largest late fee ever charged: whole rupees below numeric(14,2)'s 10^12.
MAX_FEE = Fraction(999999999999)


def half_up(value: Fraction) -> int:
    """Round to the nearest integer, ties away from zero."""
    sign = -1 if value < 0 else 1
    magnitude = abs(value)
    floor = magnitude.numerator // magnitude.denominator
    return sign * (floor + (1 if magnitude - floor >= Fraction(1, 2) else 0))


def money(value: str) -> Fraction:
    return Fraction(value)


def add_months(d: date, months: int) -> date:
    index = d.year * 12 + (d.month - 1) + months
    year, month = divmod(index, 12)
    month += 1
    return date(year, month, min(d.day, calendar.monthrange(year, month)[1]))


def due_date_for(month: date, due_day: int) -> date:
    return date(
        month.year, month.month, min(due_day, calendar.monthrange(month.year, month.month)[1])
    )


def prorated_rent(rent: Fraction, month: date, billing_start: date) -> Fraction:
    days = calendar.monthrange(month.year, month.month)[1]
    if (billing_start.year, billing_start.month) == (
        month.year,
        month.month,
    ) and billing_start.day > 1:
        # Never above the rent: 0.90 x 30/31 would otherwise round up to 1.
        return min(rent, Fraction(half_up(rent * (days - billing_start.day + 1) / days)))
    return rent


def next_anniversary(start: date, as_of: date, interval: int) -> date:
    cycles = 1
    if as_of > start:
        elapsed = (as_of.year * 12 + as_of.month) - (start.year * 12 + start.month)
        cycles = max(1, elapsed // interval)
    candidate = add_months(start, cycles * interval)
    while candidate < as_of:
        cycles += 1
        candidate = add_months(start, cycles * interval)
    return candidate


def late_fee(
    kind: str,
    value: Fraction | None,
    cap: Fraction | None,
    outstanding: Fraction,
    days_late: int,
    grace: int,
) -> Fraction:
    if kind == "none" or outstanding <= 0 or days_late <= grace:
        return Fraction(0)
    if kind == "flat":
        raw = value
    elif kind == "percent":
        raw = outstanding * value / 100
    else:
        raw = value * days_late
    # Round first, cap afterwards: a fee never exceeds its cap (99.50 stays
    # 99.50 instead of rounding up to 100), nor what a charge can hold.
    fee = Fraction(half_up(raw))
    if kind == "daily" and cap is not None:
        fee = min(fee, cap)
    return min(fee, MAX_FEE)


def allocate(
    payment: Fraction, charges: list[dict], chosen: list[str]
) -> tuple[list[dict], Fraction]:
    """Chosen charges first (first occurrence wins), then oldest due date, then id."""

    def rank(charge: dict) -> int:
        return chosen.index(charge["id"]) if charge["id"] in chosen else len(chosen)

    remaining = payment
    allocations = []
    for charge in sorted(charges, key=lambda c: (rank(c), c["due_date"], c["id"])):
        if remaining <= 0:
            break
        applied = min(remaining, money(charge["outstanding"]))
        allocations.append({"charge_id": charge["id"], "amount": f"{applied:.2f}"})
        remaining -= applied
    return allocations, remaining


def billed_rent(rent: Fraction, month: date, billing_start: date, prorate: bool) -> Fraction:
    """What sync_lease_billing bills for a month (zero before billing starts)."""
    first = date(billing_start.year, billing_start.month, 1)
    if month < first:
        return Fraction(0)
    if month != first or not prorate:
        return rent
    return prorated_rent(rent, month, billing_start)


def charge_id(case: int, letter: str) -> str:
    """Canonical UUIDs whose order within a case follows [letter]."""
    return f"01a1a2d1-{case:04x}-7000-8000-00000000000{letter}"


def build_allocations() -> list[dict]:
    def abc(case: int) -> list[dict]:
        return [
            {"id": charge_id(case, "a"), "due_date": "2026-10-05", "outstanding": "1000.00"},
            {"id": charge_id(case, "b"), "due_date": "2026-09-05", "outstanding": "500.00"},
            {"id": charge_id(case, "c"), "due_date": "2026-11-05", "outstanding": "700.00"},
        ]

    cases = [
        ("oldest due first", "1200.00", abc(1), []),
        (
            "chosen first, in the order given",
            "1000.00",
            abc(2),
            [charge_id(2, "c"), charge_id(2, "a")],
        ),
        ("chosen first, then the rest oldest first", "1500.00", abc(3), [charge_id(3, "c")]),
        ("an overpayment becomes credit", "5000.00", abc(4), []),
        (
            "the same due date is settled in id order",
            "400.00",
            [
                {"id": charge_id(5, "e"), "due_date": "2026-10-05", "outstanding": "300.00"},
                {"id": charge_id(5, "d"), "due_date": "2026-10-05", "outstanding": "300.00"},
            ],
            [],
        ),
        (
            "a charge chosen twice keeps its first position",
            "800.00",
            abc(6),
            [charge_id(6, "b"), charge_id(6, "c"), charge_id(6, "b")],
        ),
        (
            "paisa amounts",
            "120.10",
            [
                {"id": charge_id(7, "a"), "due_date": "2026-08-05", "outstanding": "100.25"},
                {"id": charge_id(7, "b"), "due_date": "2026-08-05", "outstanding": "50.50"},
            ],
            [],
        ),
    ]
    vectors = []
    for name, payment, charges, chosen in cases:
        allocations, remaining = allocate(money(payment), charges, chosen)
        vectors.append(
            {
                "name": name,
                "payment": payment,
                "charges": charges,
                "chosen_charge_ids": chosen,
                "expected_allocations": allocations,
                "expected_unallocated": f"{remaining:.2f}",
            }
        )
    return vectors


def build_billed_rents() -> list[dict]:
    vectors = []
    for rent, month, start, prorate in [
        ("45000.00", "2026-11-01", "2026-11-15", True),
        ("45000.00", "2026-11-01", "2026-11-15", False),
        ("45000.00", "2026-12-01", "2026-11-15", True),
        ("45000.00", "2026-10-01", "2026-11-15", True),
        ("45000.00", "2026-11-01", "2026-11-01", True),
        ("0.90", "2026-01-01", "2026-01-02", True),
        ("33333.33", "2026-02-01", "2026-02-14", True),
    ]:
        expected = billed_rent(
            money(rent), date.fromisoformat(month), date.fromisoformat(start), prorate
        )
        vectors.append(
            {
                "monthly_rent": rent,
                "month": month,
                "billing_starts_on": start,
                "prorate_first_month": prorate,
                "expected": f"{expected:.2f}",
            }
        )
    return vectors


def build() -> dict:
    due_dates = []
    for month in ["2026-02-01", "2028-02-01", "2026-04-01", "2026-11-01", "2026-12-01"]:
        for day in [1, 5, 10, 28]:
            m = date.fromisoformat(month)
            due_dates.append(
                {"month": month, "due_day": day, "expected": due_date_for(m, day).isoformat()}
            )

    billing_due_dates = []
    for month, day, start in [
        ("2026-09-01", 5, "2026-09-15"),
        ("2026-09-01", 20, "2026-09-15"),
        ("2026-10-01", 5, "2026-09-15"),
        ("2026-02-01", 28, "2026-02-01"),
    ]:
        m, s = date.fromisoformat(month), date.fromisoformat(start)
        billing_due_dates.append(
            {
                "month": month,
                "due_day": day,
                "billing_starts_on": start,
                "expected": max(due_date_for(m, day), s).isoformat(),
            }
        )

    prorations = []
    for rent, month, start in [
        ("45000.00", "2026-11-01", "2026-11-15"),
        ("45000.00", "2026-11-01", "2026-11-01"),
        ("10001.00", "2026-12-01", "2026-12-31"),
        ("33333.33", "2026-02-01", "2026-02-14"),
        ("100000.00", "2028-02-01", "2028-02-29"),
        ("37500.00", "2026-01-01", "2026-01-17"),
        ("45.00", "2026-02-01", "2026-02-15"),
        ("45000.00", "2026-12-01", "2026-11-15"),
        ("999999.99", "2026-07-01", "2026-07-02"),
        ("0.90", "2026-01-01", "2026-01-02"),
    ]:
        expected = prorated_rent(money(rent), date.fromisoformat(month), date.fromisoformat(start))
        prorations.append(
            {
                "monthly_rent": rent,
                "month": month,
                "billing_starts_on": start,
                "expected": f"{expected:.2f}",
            }
        )

    anniversaries = []
    for start, as_of, interval in [
        ("2025-03-15", "2025-01-01", 12),
        ("2025-03-15", "2025-03-15", 12),
        ("2025-03-15", "2026-03-15", 12),
        ("2025-03-15", "2026-03-16", 12),
        ("2025-03-15", "2030-01-01", 12),
        ("2025-03-15", "2026-03-01", 11),
        ("2024-02-29", "2025-01-01", 12),
        ("2024-01-31", "2024-02-15", 1),
        ("2025-09-15", "2026-11-03", 12),
    ]:
        anniversaries.append(
            {
                "start": start,
                "as_of": as_of,
                "interval_months": interval,
                "expected": next_anniversary(
                    date.fromisoformat(start), date.fromisoformat(as_of), interval
                ).isoformat(),
            }
        )

    late_fees = []
    for kind, value, cap, outstanding, days, grace in [
        ("none", None, None, "40000.00", 30, 5),
        ("flat", "1000.00", None, "40000.00", 6, 5),
        ("flat", "1000.00", None, "40000.00", 5, 5),
        ("flat", "499.50", None, "100.00", 9, 0),
        ("percent", "2.50", None, "40000.00", 6, 5),
        ("percent", "3.33", None, "1001.00", 6, 5),
        ("percent", "5.00", None, "249.90", 30, 0),
        ("daily", "100.00", None, "40000.00", 6, 5),
        ("daily", "100.00", "2500.00", "40000.00", 56, 5),
        ("daily", "33.35", None, "10.00", 3, 0),
        ("percent", "10.00", None, "0.00", 30, 0),
        ("daily", "33.35", "99.50", "10.00", 3, 0),
        ("daily", "10000000.00", None, "40000.00", 200000, 5),
        ("daily", "10000000.00", "5000.00", "40000.00", 200000, 5),
    ]:
        fee = late_fee(
            kind,
            money(value) if value else None,
            money(cap) if cap else None,
            money(outstanding),
            days,
            grace,
        )
        late_fees.append(
            {
                "type": kind,
                "value": value,
                "cap": cap,
                "outstanding": outstanding,
                "days_late": days,
                "grace_days": grace,
                "expected": f"{fee:.2f}",
            }
        )

    return {
        "$comment": "Generated by tool/contracts/generate.py — do not edit by hand.",
        "due_date": due_dates,
        "billing_due_date": billing_due_dates,
        "prorated_rent": prorations,
        "next_anniversary": anniversaries,
        "late_fee": late_fees,
        "allocation": build_allocations(),
        "billed_rent": build_billed_rents(),
    }


def sql_literal(value) -> str:
    return "null" if value is None else "'" + str(value).replace("'", "''") + "'"


def render_sql(vectors: dict) -> str:
    lines = []
    for v in vectors["due_date"]:
        lines.append(
            f"select is(app.due_date_for({sql_literal(v['month'])}, {v['due_day']}), "
            f"{sql_literal(v['expected'])}::date, 'due date {v['month']} day {v['due_day']}');"
        )
    for v in vectors["billing_due_date"]:
        lines.append(
            f"select is(greatest(app.due_date_for({sql_literal(v['month'])}, {v['due_day']}), "
            f"{sql_literal(v['billing_starts_on'])}::date), {sql_literal(v['expected'])}::date, "
            f"'billing due date {v['month']} from {v['billing_starts_on']}');"
        )
    for v in vectors["prorated_rent"]:
        lines.append(
            f"select is(app.prorated_rent({v['monthly_rent']}, {sql_literal(v['month'])}, "
            f"{sql_literal(v['billing_starts_on'])}), {v['expected']}::numeric, "
            f"'proration of {v['monthly_rent']} from {v['billing_starts_on']}');"
        )
    for v in vectors["next_anniversary"]:
        lines.append(
            f"select is(app.next_anniversary({sql_literal(v['start'])}, {sql_literal(v['as_of'])}, "
            f"{v['interval_months']}), {sql_literal(v['expected'])}::date, "
            f"'anniversary of {v['start']} as of {v['as_of']} every {v['interval_months']} months');"
        )
    for v in vectors["late_fee"]:
        lines.append(
            f"select is(app.late_fee_amount({sql_literal(v['type'])}, {v['value'] or 'null'}, "
            f"{v['cap'] or 'null'}, {v['outstanding']}, {v['days_late']}, {v['grace_days']}), "
            f"{v['expected']}::numeric, '{v['type']} late fee {v['value']} on {v['outstanding']} "
            f"after {v['days_late']} days');"
        )
    header = [
        "-- GENERATED by tool/contracts/generate.py from contracts/rent_math_vectors.json.",
        "-- Do not edit by hand. The same vectors are asserted by mm_core's Dart tests,",
        "-- so the app's previews always match the ledger the database writes.",
        "begin;",
        r"\ir _helpers.psql",
        f"select plan({len(lines)});",
        "",
    ]
    footer = ["", "select * from finish();", "rollback;", ""]
    return "\n".join(header + lines + footer)


def code_point(text: str) -> int:
    """Parses the contract's "U+XXXX" notation."""
    if not text.startswith("U+"):
        raise ValueError(f"not a code point: {text!r}")
    return int(text[2:], 16)


def clean_text_contract() -> dict:
    return json.loads((ROOT / "contracts" / "clean_text.json").read_text(encoding="utf-8"))


def forbidden_ranges(contract: dict) -> list[tuple[int, int, str]]:
    ranges = [
        (code_point(r["from"]), code_point(r["to"]), r["label"]) for r in contract["forbidden"]
    ]
    for low, high, label in ranges:
        if low > high:
            raise ValueError(f"empty range: {label}")
    return sorted(ranges)


def render_clean_text_sql(contract: dict) -> str:
    """pgTAP suite asserting app.is_clean_text against the contract.

    PostgreSQL text cannot hold U+0000 (chr(0) raises) or surrogates, so
    those are left out; every other code point is checked.
    """
    ranges = forbidden_ranges(contract)
    lines = []
    for low, high, label in ranges:
        low = max(low, 1)
        lines.append(
            f"select is((select array_agg(cp) from generate_series({low}, {high}) cp "
            f"where app.is_clean_text(chr(cp))), null::integer[], "
            f"'rejects every code point of: {label}');"
        )
    for sample in contract["allowed_samples"]:
        cp = code_point(sample["code_point"])
        lines.append(
            f"select ok(app.is_clean_text(chr({cp})), 'accepts {sample['code_point']} {sample['label']}');"
        )
    in_ranges = " or ".join(f"cp between {max(low, 1)} and {high}" for low, high, _ in ranges)
    lines.append(
        "select is((select count(*)::integer from generate_series(1, 1114111) cp "
        f"where cp not between 55296 and 57343 and not ({in_ranges}) and not app.is_clean_text(chr(cp))), 0, "
        "'accepts every code point outside the forbidden ranges');"
    )
    lines.append("select ok(app.is_clean_text(null), 'accepts null (optional columns)');")
    header = [
        "-- GENERATED by tool/contracts/generate.py from contracts/clean_text.json.",
        "-- Do not edit by hand. The Edge Functions, the app's sanitiser and the",
        "-- repository guard are tested against the same contract.",
        "begin;",
        r"\ir _helpers.psql",
        f"select plan({len(lines)});",
        "",
    ]
    footer = ["", "select * from finish();", "rollback;", ""]
    return "\n".join(header + lines + footer)


def render_ledger_sql(vectors: dict) -> str:
    """pgTAP suite running the allocation and billed-rent vectors through the real ledger."""
    body = [
        "set local app.today_override = '2026-11-03';",
        "select tests.create_user('ledger-contract@example.com') as owner \\gset",
        "select tests.create_portfolio(:'owner') as pid \\gset",
        "",
    ]
    assertions = 0
    for index, v in enumerate(vectors["allocation"], start=1):
        values = ", ".join(
            f"({sql_literal(c['id'])}, :'pid', :'lease{index}', 'other', {sql_literal(c['due_date'])}, "
            f"{c['outstanding']}, 'contract')"
            for c in v["charges"]
        )
        chosen = (
            "null"
            if not v["chosen_charge_ids"]
            else "array[" + ", ".join(sql_literal(i) for i in v["chosen_charge_ids"]) + "]::uuid[]"
        )
        expected = ", ".join(
            f"({sql_literal(a['charge_id'])}::text, {a['amount']}::numeric)"
            for a in v["expected_allocations"]
        )
        body += [
            f"-- allocation: {v['name']}",
            "reset role;",
            f"select tests.create_rental(:'pid') as rental{index} \\gset",
            f"select tests.create_lease(:'pid', :'rental{index}', '2027-01-01', 1000) as lease{index} \\gset",
            "insert into public.charges (id, portfolio_id, lease_id, kind, due_date, amount, description)",
            f"values {values};",
            "select tests.authenticate_as(:'owner');",
            f"select public.record_payment(:'lease{index}', {v['payment']}, '2026-11-03', 'cash', "
            f"gen_random_uuid(), null, null, 0, null, {chosen}) as payment{index} \\gset",
            "reset role;",
            "select set_eq(",
            "  format($f$select charge_id::text, amount from public.payment_allocations",
            f"            where payment_id = %L$f$, (:'payment{index}')::jsonb -> 'payment' ->> 'id'),",
            f"  $$values {expected}$$,",
            f"  'allocation: {v['name']}'",
            ");",
            f"select is(((:'payment{index}')::jsonb ->> 'lease_credit')::numeric, {v['expected_unallocated']}::numeric,",
            f"  'credit left: {v['name']}');",
            "",
        ]
        assertions += 2

    body += ["reset role;", "set local app.today_override = '2026-12-15';"]
    for index, v in enumerate(vectors["billed_rent"], start=1):
        overrides = (
            '{"billing_starts_on": "'
            + v["billing_starts_on"]
            + '", "prorate_first_month": '
            + ("true" if v["prorate_first_month"] else "false")
            + "}"
        )
        flag = "prorated" if v["prorate_first_month"] else "not prorated"
        body += [
            f"select tests.create_rental(:'pid') as billing{index} \\gset",
            f"select tests.create_lease(:'pid', :'billing{index}', {sql_literal(v['billing_starts_on'])}, "
            f"{v['monthly_rent']}, {sql_literal(overrides)}) as billed{index} \\gset",
            "select is(",
            "  (select coalesce(sum(amount), 0) from public.charges",
            f"   where lease_id = :'billed{index}' and kind = 'rent' and period_month = {sql_literal(v['month'])}),",
            f"  {v['expected']}::numeric,",
            f"  'billed rent of {v['monthly_rent']} for {v['month']} from {v['billing_starts_on']} ({flag})'",
            ");",
        ]
        assertions += 1

    header = [
        "-- GENERATED by tool/contracts/generate.py from contracts/rent_math_vectors.json.",
        "-- Do not edit by hand. mm_core's Dart tests assert the same allocation and",
        "-- billed-rent vectors, so payment previews match what the ledger records.",
        "begin;",
        r"\ir _helpers.psql",
        f"select plan({assertions});",
        "",
    ]
    footer = ["select * from finish();", "rollback;", ""]
    return "\n".join(header + body + footer)


# ---------------------------------------------------------------------------
# Identity values: phone numbers, CNICs, IBANs, Raast IDs
# ---------------------------------------------------------------------------
#
# The app writes these columns from mm_core's canonical forms and reads them
# back strictly (PhoneNumber.fromE164, Cnic.parse, Iban.parse in each
# fromRow), so a stored value the CHECK accepts but mm_core refuses breaks
# every screen that lists the row. The vectors below are the stored values;
# "valid" is whether mm_core reads the value back unchanged, decided here by
# an independent restatement of mm_core's rules, and the database CHECKs
# (app.is_valid_phone, app.is_valid_cnic, portfolios_bank_iban_check,
# portfolios_raast_id_check) must agree on every one.

ASCII_DIGITS = frozenset("0123456789")
UPPER = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZ")


def ascii_digits(text: str) -> bool:
    # str.isdigit() is true for Urdu and full-width digits too; the stored
    # forms are ASCII only.
    return bool(text) and set(text) <= ASCII_DIGITS


def urdu_digits(digits: str) -> str:
    """[digits] in Extended Arabic-Indic (Urdu keyboard) digits, U+06F0-U+06F9."""
    return "".join(chr(0x06F0 + int(d)) for d in digits)


def full_width_digits(digits: str) -> str:
    """[digits] in full-width digits, U+FF10-U+FF19."""
    return "".join(chr(0xFF10 + int(d)) for d in digits)


def phone_kind(value: str) -> str | None:
    """'mobile', 'landline', 'international' or None for a stored phone number.

    E.164 with a leading '+', ASCII digits only. +92 numbers follow
    Pakistan's plan: a mobile is 3 and nine more digits; any other national
    number (fixed line, UAN 111, toll-free 800) has 8 to 11 digits and does
    not start with 0. Other countries: 8 to 15 digits, not starting with 0.
    """
    if not value.startswith("+") or not ascii_digits(value[1:]):
        return None
    digits = value[1:]
    if digits.startswith("92"):
        national = digits[2:]
        if not national or national[0] == "0":
            return None
        if national[0] == "3":
            return "mobile" if len(national) == 10 else None
        return "landline" if 8 <= len(national) <= 11 else None
    if digits[0] == "0" or not 8 <= len(digits) <= 15:
        return None
    return "international"


def cnic_valid(value: str) -> bool:
    """13 ASCII digits, not starting with 0, not one digit repeated."""
    return len(value) == 13 and ascii_digits(value) and value[0] != "0" and len(set(value)) > 1


def iban_checksum_ok(value: str) -> bool:
    """ISO 13616 MOD-97-10 on an upper-case, compact IBAN."""
    rearranged = value[4:] + value[:4]
    if not set(rearranged) <= ASCII_DIGITS | UPPER:
        return False
    return int("".join(str(int(ch, 36)) for ch in rearranged)) % 97 == 1


def iban_valid(value: str) -> bool:
    """A Pakistani IBAN as stored: PK, 2 check digits, 4-letter bank, 16 letters/digits."""
    return (
        len(value) == 24
        and value[:2] == "PK"
        and ascii_digits(value[2:4])
        and set(value[4:8]) <= UPPER
        and set(value[8:]) <= ASCII_DIGITS | UPPER
        and iban_checksum_ok(value)
    )


def make_iban(country: str, bank: str, account: str) -> str:
    """An IBAN with correct check digits (bank + account as the BBAN)."""
    bban = bank + account
    remainder = int("".join(str(int(ch, 36)) for ch in bban + country + "00")) % 97
    return f"{country}{98 - remainder:02d}{bban}"


PHONE_CASES = [
    ("+923001234567", "mobile"),
    ("+923451234567", "mobile, prefix 345"),
    ("+923551234567", "mobile, SCO prefix 355"),
    ("+923991234567", "mobile, unallocated prefix (accepted, the app warns)"),
    ("+924235550123", "Lahore fixed line, 10-digit national number"),
    ("+92515551234", "Islamabad fixed line, 9-digit national number"),
    ("+9251555123", "fixed line, 8-digit national number (shortest)"),
    ("+9258212345678", "AJK fixed line, 11-digit national number (longest)"),
    ("+92111123456", "UAN 111"),
    ("+92800123456", "toll-free 800"),
    ("+971501234567", "UAE mobile"),
    ("+14155550123", "United States"),
    ("+12345678", "international, 8 digits (shortest)"),
    ("+123456789012345", "international, 15 digits (longest)"),
    ("+9112345678", "India, starts with 9 but not 92"),
    ("+92300123456", "mobile one digit short (accepted by the old CHECK)"),
    ("+9230012345678", "mobile one digit long (accepted by the old CHECK)"),
    ("+92300123456789", "mobile, 15 digits in all (accepted by the old CHECK)"),
    ("+920300123456", "+92 followed by the trunk 0 (accepted by the old CHECK)"),
    ("+921234567", "fixed line, 7-digit national number (accepted by the old CHECK)"),
    ("+92123456789012", "fixed line, 12-digit national number (accepted by the old CHECK)"),
    ("+92", "country code only"),
    ("+1234567", "international, 7 digits"),
    ("+1234567890123456", "international, 16 digits"),
    ("+0123456789", "starts with 0"),
    ("923001234567", "no plus"),
    ("03001234567", "national form"),
    ("+92 300 1234567", "spaces"),
    ("+92-300-1234567", "dashes"),
    (" +923001234567", "leading space"),
    ("+923001234567 ", "trailing space"),
    ("+923001234567\n", "trailing line feed"),
    ("++923001234567", "two plus signs"),
    ("+92300123456a", "a letter"),
    ("+" + urdu_digits("923001234567"), "Urdu digits"),
    ("+" + full_width_digits("923001234567"), "full-width digits"),
    ("", "empty"),
]

CNIC_CASES = [
    ("3520212345671", "Punjab"),
    ("4210198765432", "Sindh"),
    ("1000000000000", "one digit differs"),
    ("9520212345671", "unknown region 9 (accepted, the app warns)"),
    ("1111111111111", "one digit repeated (accepted by the old CHECK)"),
    ("9999999999999", "nines repeated (accepted by the old CHECK)"),
    ("0000000000000", "zeros"),
    ("0352021234567", "starts with 0"),
    ("352021234567", "12 digits"),
    ("35202123456712", "14 digits"),
    ("35202-1234567-1", "with dashes (the app stores digits only)"),
    (urdu_digits("3520212345671"), "Urdu digits"),
    (" 3520212345671", "leading space"),
    ("3520212345671\n", "trailing line feed"),
    ("", "empty"),
]


def iban_cases() -> list[tuple[str, str]]:
    meezan = make_iban("PK", "MEZN", "0001234567890123")
    letters = make_iban("PK", "HABB", "00AB12CD34EF56GH")
    return [
        ("PK36SCBL0000001123456702", "Standard Chartered example"),
        (meezan, "Meezan Bank"),
        (letters, "letters in the account part"),
        (make_iban("PK", "ZZZZ", "0000000000000001"), "unknown bank code (accepted)"),
        ("PK37SCBL0000001123456702", "wrong check digits"),
        ("PK36SCBL0000001123456720", "two digits swapped"),
        ("pk36scbl0000001123456702", "lower case"),
        ("PK36 SCBL 0000 0011 2345 6702", "spaces"),
        ("PK36SCBL000000112345670", "23 characters"),
        ("PK36SCBL00000011234567020", "25 characters"),
        (make_iban("PK", "SCB1", "0000001123456702"), "digit in the bank code, check digits right"),
        (make_iban("GB", "WEST", "12345698765432"), "United Kingdom (foreign IBANs are refused)"),
        ("PK36SCBL0000001123456702\n", "trailing line feed"),
        ("", "empty"),
    ]


def build_identity() -> dict:
    phones = []
    for value, name in PHONE_CASES:
        kind = phone_kind(value)
        phones.append(
            {"value": value, "name": name, "valid": kind is not None, "mobile": kind == "mobile"}
        )
    return {
        "$comment": (
            "Generated by tool/contracts/generate.py — do not edit by hand. Stored values; "
            '"valid" is whether mm_core reads the value back unchanged (PhoneNumber.fromE164, '
            "Cnic.parse, Iban.parse), which the database CHECKs must match. A Raast ID is a "
            'valid phone number that is "mobile".'
        ),
        "phone": phones,
        "cnic": [{"value": v, "name": n, "valid": cnic_valid(v)} for v, n in CNIC_CASES],
        "iban": [{"value": v, "name": n, "valid": iban_valid(v)} for v, n in iban_cases()],
    }


def render_identity_sql(vectors: dict) -> str:
    """pgTAP suite: the functions and the real CHECKs against the identity vectors."""

    def shown(value: str) -> str:
        return json.dumps(value, ensure_ascii=False)

    def write(table: str, column: str, row: str, value: str, valid: bool, name: str) -> str:
        statement = (
            f"format('update public.{table} set {column} = %L where id = %L', "
            f"{sql_literal(value)}, :'{row}')"
        )
        what = sql_literal(
            f"{table}.{column} {'accepts' if valid else 'refuses'} {shown(value)} ({name})"
        )
        if valid:
            return f"select lives_ok({statement}, {what});"
        return f"select throws_ok({statement}, '23514', null, {what});"

    lines = []
    for v in vectors["phone"]:
        lines.append(
            f"select is(app.is_valid_phone({sql_literal(v['value'])}), {str(v['valid']).lower()}, "
            f"{sql_literal('phone ' + shown(v['value']) + ': ' + v['name'])});"
        )
        lines.append(write("tenants", "phone", "tenant", v["value"], v["valid"], v["name"]))
        lines.append(
            write(
                "portfolios",
                "raast_id",
                "pid",
                v["value"],
                v["valid"] and v["mobile"],
                v["name"],
            )
        )
    for v in vectors["cnic"]:
        lines.append(
            f"select is(app.is_valid_cnic({sql_literal(v['value'])}), {str(v['valid']).lower()}, "
            f"{sql_literal('CNIC ' + shown(v['value']) + ': ' + v['name'])});"
        )
        lines.append(write("tenants", "cnic", "tenant", v["value"], v["valid"], v["name"]))
    for v in vectors["iban"]:
        lines.append(write("portfolios", "bank_iban", "pid", v["value"], v["valid"], v["name"]))
    header = [
        "-- GENERATED by tool/contracts/generate.py from contracts/identity_vectors.json.",
        "-- Do not edit by hand. mm_core's Dart tests assert the same vectors, so every",
        "-- value a CHECK lets in is one the app can read back (and the other way round).",
        "begin;",
        r"\ir _helpers.psql",
        f"select plan({len(lines)});",
        "",
        "select tests.create_user('identity-contract@example.com') as owner \\gset",
        "select tests.create_portfolio(:'owner') as pid \\gset",
        "select (tests.create_rental(:'pid') ->> 'tenant_id') as tenant \\gset",
        "",
    ]
    footer = ["", "select * from finish();", "rollback;", ""]
    return "\n".join(header + lines + footer)


def outputs() -> dict[Path, str]:
    vectors = build()
    identity = build_identity()
    database_tests = ROOT / "supabase" / "tests" / "database"
    return {
        ROOT
        / "contracts"
        / "rent_math_vectors.json": json.dumps(vectors, indent=2, ensure_ascii=False)
        + "\n",
        database_tests / "10_contract_vectors.test.sql": render_sql(vectors),
        database_tests
        / "12_clean_text_contract.test.sql": render_clean_text_sql(clean_text_contract()),
        database_tests / "13_ledger_contract.test.sql": render_ledger_sql(vectors),
        ROOT
        / "contracts"
        / "identity_vectors.json": json.dumps(identity, indent=2, ensure_ascii=False)
        + "\n",
        database_tests / "20_identity_contract.test.sql": render_identity_sql(identity),
    }


def main(argv: list[str]) -> int:
    check = argv[1:] == ["--check"]
    if argv[1:] and not check:
        print("usage: tool/contracts/generate.py [--check]", file=sys.stderr)
        return 2

    stale = []
    for path, content in outputs().items():
        if not check:
            path.write_text(content, encoding="utf-8")
        elif not path.exists() or path.read_text(encoding="utf-8") != content:
            stale.append(path.relative_to(ROOT))

    if stale:
        print(
            "Generated contract files are stale; run tool/contracts/generate.py:", file=sys.stderr
        )
        for path in stale:
            print(f"  {path}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
