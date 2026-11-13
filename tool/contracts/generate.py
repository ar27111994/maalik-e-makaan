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
  contracts/residence_vectors.json, contracts/time_zone_vectors.json,
    packages/mm_core/lib/src/time/time_zone_data.g.dart,
    supabase/tests/database/23_residence_contract.test.sql and tool/db/time_zone_skew.sql
    (the countries and time zones a person may store, and each zone's offsets from 2020 to
    2100, from the tzdata package pinned in tool/requirements.txt: tool/contracts/time_zones.py)

Usage:
  tool/contracts/generate.py                     # (re)write every file
  tool/contracts/generate.py --check             # exit 1 if any file is stale (CI)
  tool/contracts/generate.py --print-sql-lists   # the array literals for a migration that
                                                 # widens app.supported_time_zones()
"""

from __future__ import annotations

import calendar
import json
import re
import sys
from datetime import date
from fractions import Fraction
from pathlib import Path

import time_zones as tz

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


# ---------------------------------------------------------------------------
# Residence and time zones (D-16)
# ---------------------------------------------------------------------------
#
# A person's declared country and the zone of their own alerts are stored as
# names from the pinned tzdata (tool/contracts/time_zones.py): the database
# accepts exactly these (app.supported_country_codes, app.supported_time_zones,
# append-only), mm_core bundles each zone's offsets from 2020 to 2100 for an
# owner's alerts, quiet hours and dual time, and both are checked against the
# vectors below. Business dates (rent, ledger, deadlines, the tax year) stay
# on Pakistan time and are not touched here.

# Stored values; "valid" is membership in the supported list.
COUNTRY_CASES = [
    ("PK", "Pakistan"),
    ("GB", "United Kingdom"),
    ("AE", "United Arab Emirates"),
    ("SA", "Saudi Arabia"),
    ("US", "United States"),
    ("NO", "Norway"),
    ("BH", "Bahrain"),
    ("KW", "Kuwait"),
    ("pk", "lower case"),
    ("Gb", "mixed case"),
    ("UK", "reserved: the United Kingdom is GB"),
    ("XK", "user-assigned (Kosovo)"),
    ("XX", "user-assigned"),
    ("PAK", "alpha-3"),
    ("586", "numeric"),
    (" PK", "leading space"),
    ("PK ", "trailing space"),
    ("PK\n", "trailing line feed"),
    ("", "empty"),
]

# Stored values, and what a device reporting the same name is offered.
TIME_ZONE_CASES = [
    ("Europe/London", "the United Kingdom"),
    ("Asia/Karachi", "Pakistan"),
    ("Asia/Dubai", "the United Arab Emirates"),
    ("Asia/Kuwait", "a zone.tab name that tzdata.zi links to Asia/Riyadh"),
    ("America/Argentina/Buenos_Aires", "three parts"),
    ("America/Port-au-Prince", "a hyphen"),
    ("Asia/Calcutta", "an old name of Asia/Kolkata"),
    ("Europe/Kiev", "an old name of Europe/Kyiv"),
    ("US/Eastern", "a backward link"),
    ("America/Buenos_Aires", "a two-part link to a three-part zone"),
    ("GB", "a link without a slash"),
    ("UTC", "UTC"),
    ("Etc/UTC", "Etc/UTC"),
    ("Etc/GMT+5", "a fixed offset"),
    ("Factory", "no zone at all"),
    ("Asia/Lahore", "not a zone"),
    ("europe/london", "lower case"),
    ("Europe/london", "mixed case"),
    (" Europe/London", "leading space"),
    ("Europe/London\n", "trailing line feed"),
    ("", "empty"),
]

# The Dart decoder keeps a well-formed name it does not know (a newer build
# may store one); this is the shape it accepts.
ZONE_SHAPE = re.compile(r"^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+){1,2}$")

VECTOR_YEARS = (2026, 2029)  # clock changes in [2026, 2029)
SAMPLE_YEARS = range(2026, 2031)  # 1 January and 1 July, 12:00 UTC


def _schedules() -> tuple[list[tz.Schedule], dict[str, int]]:
    """The distinct schedules, in order of first use by zone name, and each zone's index."""
    schedules: list[tz.Schedule] = []
    index: dict[str, int] = {}
    for zone in tz.allowed_zones():
        schedule = tz.schedule(zone)
        if schedule not in schedules:
            schedules.append(schedule)
        index[zone] = schedules.index(schedule)
    return schedules, index


def check_time_zone_data() -> None:
    """The generator's own assertions; mm_core's tests repeat them on the bundled data."""
    countries = tz.countries()
    for zone, country in tz.zone_countries().items():
        if country not in countries:
            raise ValueError(f"{zone}: country {country} is not in iso3166.tab")
        if not ZONE_SHAPE.match(zone) or len(zone) > 64:
            raise ValueError(f"{zone}: not a name mm_core's TimeZoneId.fromJson accepts")
        schedule = tz.schedule(zone)
        previous_at, previous_offset = None, schedule.initial
        for at, offset in schedule.transitions:
            if not tz.FROM <= at < tz.UNTIL or offset == previous_offset:
                raise ValueError(f"{zone}: transition at {tz.utc(at)} changes nothing")
            if previous_at is not None and at - previous_at < tz.MIN_SPACING:
                raise ValueError(f"{zone}: clock changes at {tz.utc(at)} less than 2 days apart")
            previous_at, previous_offset = at, offset
    allowed = set(tz.zone_countries())
    for name, target in tz.device_links().items():
        if target not in allowed or name in allowed:
            raise ValueError(f"device link {name} -> {target}")
    pakistan = tz.schedule(tz.PAKISTAN)
    if pakistan != tz.Schedule(5 * 3600, ()):
        raise ValueError(
            "Asia/Karachi is no longer UTC+05:00 all year: see docs/architecture/time.md"
        )


def check_append_only(previous: dict) -> None:
    """Every country and zone the committed vectors list is still supported."""
    gone = sorted({z["name"] for z in previous["timeZones"]} - set(tz.zone_countries()))
    gone += sorted({c["code"] for c in previous["countries"]} - set(tz.countries()))
    if gone:
        raise ValueError(
            "stored names are append-only, but tzdata dropped "
            + ", ".join(gone)
            + ": keep each in RETAINED_ZONES or RETAINED_COUNTRIES (tool/contracts/time_zones.py)"
        )


def build_residence() -> dict:
    check_time_zone_data()
    committed = ROOT / "contracts" / "residence_vectors.json"
    if committed.exists():
        check_append_only(json.loads(committed.read_text(encoding="utf-8")))
    countries = tz.countries()
    allowed = tz.zone_countries()
    links = tz.device_links()
    return {
        "$comment": (
            f"Generated by tool/contracts/generate.py from tzdata {tz.iana_version()} — do not edit "
            "by hand. The countries and zones a person may store (append-only), each zone's "
            "country, and the zone a device's other name is offered as (deviceLinks: a stored name "
            'is offered as itself). "valid" is whether a stored value is accepted; "device" is '
            "what TimeZoneId.fromDevice suggests for the same name."
        ),
        "tzdata": tz.iana_version(),
        "pakistan": tz.PAKISTAN,
        "countries": [{"code": code, "zones": zones} for code, zones in tz.country_zones().items()],
        "timeZones": [{"name": name, "country": country} for name, country in allowed.items()],
        "retainedZones": dict(sorted(tz.RETAINED_ZONES.items())),
        "deviceLinks": links,
        "countryCases": [
            {"value": value, "valid": value in countries, "name": name}
            for value, name in COUNTRY_CASES
        ],
        "timeZoneCases": [
            {
                "value": value,
                "valid": value in allowed,
                "device": value if value in allowed else links.get(value),
                "name": name,
            }
            for value, name in TIME_ZONE_CASES
        ],
    }


def _in_vector_years(at: int) -> bool:
    return (
        tz.parse_utc(f"{VECTOR_YEARS[0]}-01-01T00:00:00Z")
        <= at
        < tz.parse_utc(f"{VECTOR_YEARS[1]}-01-01T00:00:00Z")
    )


def _offset_vector(name: str, zone: str | None, at: int) -> dict:
    real = zone or tz.PAKISTAN
    return {
        "name": name,
        "zone": zone,
        "utc": tz.utc(at),
        "offsetSeconds": tz.offset_at(real, at),
        "local": tz.local(real, at),
        "pg": real in tz.PG_STABLE_ZONES,
    }


def _local_vector(name: str, zone: str, wall: str, expected_kind: str | None = None) -> dict:
    at, kind = tz.local_to_instant(zone, wall)
    if expected_kind is not None and kind != expected_kind:
        raise ValueError(f"{zone} {wall}: expected {expected_kind}, got {kind}")
    return {
        "name": name,
        "zone": zone,
        "local": wall,
        "utc": tz.utc(at),
        "kind": kind,
        "pg": zone in tz.PG_STABLE_ZONES,
    }


def _wall(seconds: int) -> str:
    return tz.utc(seconds)[:-1]


def build_time_zone_vectors() -> dict:
    offsets = []
    local_to_instant = []
    for zone in tz.VECTOR_ZONES:
        for year in SAMPLE_YEARS:
            for month in ("01", "07"):
                at = tz.parse_utc(f"{year}-{month}-01T12:00:00Z")
                offsets.append(_offset_vector(f"{zone} on {year}-{month}-01", zone, at))
        schedule = tz.schedule(zone)
        before = schedule.initial
        for at, after in schedule.transitions:
            if _in_vector_years(at):
                change = f"{zone} clock change at {tz.utc(at)}"
                offsets.append(_offset_vector(f"{change}, a second before", zone, at - 1))
                offsets.append(_offset_vector(f"{change}, at the change", zone, at))
                # The local times either side of the change, and those it skips
                # (the clock goes forward: a gap) or repeats (back: an overlap).
                low, high = sorted((at + before, at + after))
                kind = "gap" if after > before else "overlap"
                samples = [
                    ("a second before the change", low - 1, "normal"),
                    (f"the first second of the {kind}", low, kind),
                    (f"the middle of the {kind}", (low + high) // 2, kind),
                    (f"the last second of the {kind}", high - 1, kind),
                    (f"the end of the {kind}", high, "normal"),
                ]
                for label, wall, expected in samples:
                    local_to_instant.append(
                        _local_vector(f"{change}: {label}", zone, _wall(wall), expected)
                    )
            before = after
    for year in SAMPLE_YEARS:
        at = tz.parse_utc(f"{year}-01-01T00:00:00Z")
        offsets.append(_offset_vector(f"not stated is Pakistan time on {year}-01-01", None, at))
    for zone in ("Asia/Karachi", "Asia/Kolkata", "Asia/Kathmandu", "Europe/London"):
        local_to_instant.append(
            _local_vector(f"{zone}, an ordinary time", zone, "2026-11-12T15:15:00")
        )

    def quiet(name, zone, start, end, at):
        real = zone or tz.PAKISTAN
        first, last = (int(t[:2]) * 60 + int(t[3:]) for t in (start, end))
        instant = tz.parse_utc(at)
        return {
            "name": name,
            "zone": zone,
            "start": start,
            "end": end,
            "at": at,
            "quiet": tz.is_quiet(first, last, real, instant),
            "releaseAt": tz.utc(tz.release_at(first, last, real, instant)),
        }

    quiet_hours = [
        quiet("London, overnight", "Europe/London", "22:00", "07:00", "2026-11-12T23:00:00Z"),
        quiet("London, at the start", "Europe/London", "22:00", "07:00", "2026-11-12T22:00:00Z"),
        quiet(
            "London, a second before the end",
            "Europe/London",
            "22:00",
            "07:00",
            "2026-11-13T06:59:59Z",
        ),
        quiet("London, at the end", "Europe/London", "22:00", "07:00", "2026-11-13T07:00:00Z"),
        quiet("London, in the day", "Europe/London", "22:00", "07:00", "2026-11-12T12:00:00Z"),
        quiet(
            "London, half a minute in", "Europe/London", "22:00", "07:00", "2026-11-12T23:00:30Z"
        ),
        quiet(
            "London, spring: the end (01:30) is skipped, released when the clock goes forward",
            "Europe/London",
            "22:00",
            "01:30",
            "2027-03-28T00:50:00Z",
        ),
        quiet(
            "London, spring: after the clock went forward",
            "Europe/London",
            "22:00",
            "01:30",
            "2027-03-28T01:00:00Z",
        ),
        quiet(
            "London, spring: the clock goes forward into quiet hours",
            "Europe/London",
            "01:15",
            "03:00",
            "2027-03-28T01:00:00Z",
        ),
        quiet(
            "London, autumn: released at the first 01:30",
            "Europe/London",
            "22:00",
            "01:30",
            "2027-10-31T00:20:00Z",
        ),
        quiet(
            "London, autumn: between the first 01:30 and the clock going back",
            "Europe/London",
            "22:00",
            "01:30",
            "2027-10-31T00:40:00Z",
        ),
        quiet(
            "London, autumn: quiet again in the repeated hour, released at the second 01:30",
            "Europe/London",
            "22:00",
            "01:30",
            "2027-10-31T01:05:00Z",
        ),
        quiet(
            "New York, spring: the end (02:30) is skipped",
            "America/New_York",
            "01:00",
            "02:30",
            "2027-03-14T06:30:00Z",
        ),
        quiet(
            "New York, autumn: released at the first 01:30",
            "America/New_York",
            "00:00",
            "01:30",
            "2027-11-07T05:20:00Z",
        ),
        quiet(
            "New York, autumn: quiet again in the repeated hour",
            "America/New_York",
            "00:00",
            "01:30",
            "2027-11-07T06:10:00Z",
        ),
        quiet(
            "Lord Howe, spring: a half-hour change skips the end",
            "Australia/Lord_Howe",
            "22:00",
            "02:15",
            "2026-10-03T15:20:00Z",
        ),
        quiet(
            "Dubai, a window within the day", "Asia/Dubai", "13:00", "14:00", "2026-11-12T09:30:00Z"
        ),
        quiet(
            "Kathmandu, quarter-hour offset",
            "Asia/Kathmandu",
            "22:00",
            "06:00",
            "2026-11-12T17:00:00Z",
        ),
        quiet("not stated is Pakistan time", None, "22:00", "08:00", "2026-11-12T18:00:00Z"),
        quiet(
            "Auckland, overnight across the date",
            "Pacific/Auckland",
            "21:00",
            "06:30",
            "2026-11-12T09:00:00Z",
        ),
    ]

    def next_vector(name, zone, time, weekday, after):
        real = zone or tz.PAKISTAN
        minute = int(time[:2]) * 60 + int(time[3:])
        return {
            "name": name,
            "zone": zone,
            "time": time,
            "isoWeekday": weekday,
            "after": after,
            "utc": tz.utc(tz.next_at(real, minute, weekday, tz.parse_utc(after))),
        }

    next_at = [
        next_vector("London, later today", "Europe/London", "18:00", None, "2026-11-12T10:15:00Z"),
        next_vector("London, tomorrow", "Europe/London", "08:00", None, "2026-11-12T10:15:00Z"),
        next_vector(
            "London, a second before", "Europe/London", "08:00", None, "2026-11-12T07:59:59Z"
        ),
        next_vector(
            "London, exactly then: the next day",
            "Europe/London",
            "08:00",
            None,
            "2026-11-12T08:00:00Z",
        ),
        next_vector(
            "London, a time the clock skips", "Europe/London", "01:30", None, "2027-03-27T12:00:00Z"
        ),
        next_vector(
            "London, a time the clock repeats: the later",
            "Europe/London",
            "01:30",
            None,
            "2027-10-30T12:00:00Z",
        ),
        next_vector("London, Monday", "Europe/London", "09:00", 1, "2026-11-12T10:15:00Z"),
        next_vector(
            "London, Thursday, later the same day",
            "Europe/London",
            "18:00",
            4,
            "2026-11-12T10:15:00Z",
        ),
        next_vector(
            "London, Thursday, already past", "Europe/London", "09:00", 4, "2026-11-12T10:15:00Z"
        ),
        next_vector(
            "New York, Monday across the spring change",
            "America/New_York",
            "09:00",
            1,
            "2027-03-12T18:00:00Z",
        ),
        next_vector("Sydney, Sunday", "Australia/Sydney", "07:00", 7, "2026-11-12T10:15:00Z"),
        next_vector(
            "Auckland, the local date is ahead",
            "Pacific/Auckland",
            "07:00",
            None,
            "2026-11-12T20:00:00Z",
        ),
        next_vector(
            "Lord Howe, a time the clock skips",
            "Australia/Lord_Howe",
            "02:15",
            None,
            "2026-10-03T00:00:00Z",
        ),
        next_vector("Kathmandu, midnight", "Asia/Kathmandu", "00:00", None, "2026-11-12T10:15:00Z"),
        next_vector(
            "St John's, half-hour offset", "America/St_Johns", "08:00", None, "2026-11-12T10:15:00Z"
        ),
        next_vector("not stated is Pakistan time", None, "09:00", None, "2026-11-12T10:15:00Z"),
    ]

    def dual(name, zone, at):
        instant = tz.parse_utc(at)
        own = zone or tz.PAKISTAN
        same = tz.offset_at(own, instant) == tz.offset_at(tz.PAKISTAN, instant)
        return {
            "name": name,
            "zone": zone,
            "utc": at,
            "pakistan": tz.local(tz.PAKISTAN, instant),
            "own": None if same else tz.local(own, instant),
        }

    dual_time = [
        dual("London in winter (the owner's example)", "Europe/London", "2026-11-12T10:15:00Z"),
        dual("London in summer", "Europe/London", "2027-07-01T10:15:00Z"),
        dual("Dubai", "Asia/Dubai", "2026-11-12T10:15:00Z"),
        dual("Riyadh", "Asia/Riyadh", "2026-11-12T10:15:00Z"),
        dual("New York in summer", "America/New_York", "2027-07-01T12:00:00Z"),
        dual("Toronto in winter", "America/Toronto", "2026-12-01T12:00:00Z"),
        dual("Kolkata, half an hour ahead", "Asia/Kolkata", "2026-11-12T10:15:00Z"),
        dual("Kathmandu", "Asia/Kathmandu", "2026-11-12T10:15:00Z"),
        dual("Auckland, a day ahead", "Pacific/Auckland", "2026-11-12T20:00:00Z"),
        dual("Los Angeles, a day behind", "America/Los_Angeles", "2026-11-12T20:00:00Z"),
        dual("Karachi: one time only", "Asia/Karachi", "2026-11-12T10:15:00Z"),
        dual("not stated: one time only", None, "2026-11-12T10:15:00Z"),
        dual("Tashkent, also UTC+05:00: one time only", "Asia/Tashkent", "2026-11-12T10:15:00Z"),
    ]

    return {
        "$comment": (
            f"Generated by tool/contracts/generate.py from tzdata {tz.iana_version()} — do not edit "
            'by hand. Instants are UTC; local times are a zone\'s wall clock. "zone": null is not '
            'stated, which is Pakistan time. Rows with "pg": true are also checked against '
            "PostgreSQL (suite 23); the others are Dart-only."
        ),
        "tzdata": tz.iana_version(),
        "rule": (
            "a local time a clock change skips or repeats is read as the later of its two "
            "instants (PostgreSQL); quiet hours [start, end) end at the first later instant the "
            "wall clock is outside them"
        ),
        "pakistan": tz.PAKISTAN,
        "offsets": offsets,
        "localToInstant": local_to_instant,
        "quietHours": quiet_hours,
        "nextAt": next_at,
        "dualTime": dual_time,
    }


def sql_text_array(items: list[str], indent: str = "    ", width: int = 100) -> str:
    """Quoted, comma-separated, wrapped at [width]: the migration's array literals."""
    lines, line = [], indent
    for i, item in enumerate(items):
        token = sql_literal(item) + ("," if i < len(items) - 1 else "")
        candidate = token if line == indent else " " + token
        if len(line) + len(candidate) > width:
            lines.append(line)
            line = indent + token
        else:
            line += candidate
    lines.append(line)
    return "\n".join(lines)


def render_sql_lists(residence: dict) -> str:
    countries = [c["code"] for c in residence["countries"]]
    zones = [z["name"] for z in residence["timeZones"]]
    return (
        f"-- app.supported_country_codes(): {len(countries)} codes\n"
        f"  select array[\n{sql_text_array(countries)}\n  ]::text[]\n\n"
        f"-- app.supported_time_zones(): {len(zones)} zones (tzdata {residence['tzdata']})\n"
        f"  select array[\n{sql_text_array(zones)}\n  ]::text[]\n"
    )


def render_residence_sql(residence: dict, vectors: dict) -> str:
    """pgTAP suite 23: the stored lists, the CHECKs and PostgreSQL's conversions."""

    def shown(value: str) -> str:
        return json.dumps(value, ensure_ascii=False)

    countries = [c["code"] for c in residence["countries"]]
    zones = [z["name"] for z in residence["timeZones"]]
    lines = [
        "select is(app.supported_country_codes(), array[\n"
        + sql_text_array(countries, "  ")
        + "\n]::text[], 'the stored countries are exactly the contract''s');",
        "select is(app.supported_time_zones(), array[\n"
        + sql_text_array(zones, "  ")
        + "\n]::text[], 'the stored time zones are exactly the contract''s');",
        "select is((select array_agg(z) from unnest(app.supported_time_zones()) z\n"
        "           where not exists (select 1 from pg_timezone_names n where n.name = z)), null,\n"
        "  'the server knows every stored time zone');",
    ]
    for v in residence["countryCases"]:
        what = f"{shown(v['value'])} ({v['name']})"
        lines.append(
            f"select is(app.is_valid_country_code({sql_literal(v['value'])}), "
            f"{str(v['valid']).lower()}, {sql_literal('country ' + what)});"
        )
        lines.append(_residence_write("residence_country", v["value"], v["valid"], what))
    for v in residence["timeZoneCases"]:
        what = f"{shown(v['value'])} ({v['name']})"
        lines.append(
            f"select is(app.is_valid_time_zone({sql_literal(v['value'])}), "
            f"{str(v['valid']).lower()}, {sql_literal('time zone ' + what)});"
        )
        lines.append(_residence_write("time_zone", v["value"], v["valid"], what))
    lines.append("")
    lines.append("-- PostgreSQL's conversions agree with mm_core's on the stable zones.")
    for v in vectors["offsets"]:
        if not v["pg"]:
            continue
        zone = sql_literal(v["zone"] or residence["pakistan"])
        utc = f"timestamptz {sql_literal(v['utc'])}"
        lines.append(
            f"select is(format('%s %s', to_char({utc} at time zone {zone}, "
            "'YYYY-MM-DD\"T\"HH24:MI:SS'), "
            f"extract(epoch from ({utc} at time zone {zone}) - ({utc} at time zone 'UTC'))::integer), "
            f"{sql_literal(v['local'] + ' ' + str(v['offsetSeconds']))}, {sql_literal(v['name'])});"
        )
    for v in vectors["localToInstant"]:
        if not v["pg"]:
            continue
        lines.append(
            f"select is(timestamp {sql_literal(v['local'])} at time zone {sql_literal(v['zone'])}, "
            f"timestamptz {sql_literal(v['utc'])}, {sql_literal(v['name'] + ' (' + v['kind'] + ')')});"
        )
    assertions = sum(1 for line in lines if line.startswith("select "))
    header = [
        "-- GENERATED by tool/contracts/generate.py from contracts/residence_vectors.json and",
        "-- contracts/time_zone_vectors.json. Do not edit by hand. mm_core's Dart tests assert",
        "-- the same vectors: the countries and zones the database stores are exactly those",
        "-- the app reads back, and PostgreSQL converts the stable zones' times as mm_core does",
        "-- (a skipped or repeated local time is the later instant).",
        "begin;",
        r"\ir _helpers.psql",
        f"select plan({assertions});",
        "",
        "select tests.create_user('residence-contract@example.com') as person \\gset",
        "select tests.authenticate_as(:'person');",
        "",
    ]
    footer = ["", "select * from finish();", "rollback;", ""]
    return "\n".join(header + lines + footer)


def _residence_write(column: str, value: str, valid: bool, what: str) -> str:
    statement = (
        f"format('update public.profile_residences set {column} = %L where user_id = %L', "
        f"{sql_literal(value)}, :'person')"
    )
    label = sql_literal(f"profile_residences.{column} {'accepts' if valid else 'refuses'} {what}")
    if valid:
        return f"select lives_ok({statement}, {label});"
    return f"select throws_ok({statement}, '23514', null, {label});"


def _dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def _dart_packed(items: list[str], indent: str, width: int = 80) -> list[str]:
    """Items separated by ", ", a trailing comma after each line, wrapped at [width]."""
    lines, line = [], ""
    for item in items:
        token = item + ","
        candidate = token if not line else line + " " + token
        if line and len(indent) + len(candidate) > width:
            lines.append(indent + line)
            line = token
        else:
            line = candidate
    if line:
        lines.append(indent + line)
    return lines


def _zone_summary(zones: list[str], width: int = 70) -> str:
    """The first zones of a schedule that fit a comment line, then how many more."""
    shown: list[str] = []
    for zone in zones:
        rest = len(zones) - len(shown) - 1
        more = f" and {rest} more" if rest else ""
        if shown and len(", ".join([*shown, zone]) + more) > width:
            break
        shown.append(zone)
    rest = len(zones) - len(shown)
    return ", ".join(shown) + (f" and {rest} more" if rest else "")


def render_time_zone_dart(residence: dict) -> str:
    schedules, index = _schedules()
    out = [
        "// GENERATED by tool/contracts/generate.py from the IANA tz database",
        f"// {residence['tzdata']} (the PyPI tzdata pinned in tool/requirements.txt). Do not",
        "// edit by hand: bump tzdata and run `make contracts` (docs/operations.md,",
        '// "Time-zone data").',
        "//",
        "// The stored zones and countries (contracts/residence_vectors.json) and each",
        "// zone's UTC offsets from 2020 to 2100, read by time_zone.dart and",
        "// country_code.dart. Not exported.",
        "",
        "// dart format off",
        "",
        "/// The IANA tz database release these tables come from.",
        f"const String tzdataVersion = {_dart_string(residence['tzdata'])};",
        "",
        "/// The first instant the offsets cover: 2020-01-01T00:00:00Z, in Unix seconds.",
        f"const int tzdataFrom = {tz.FROM};",
        "",
        "/// The end of the offsets: 2100-01-01T00:00:00Z, in Unix seconds. The last",
        "/// offset of each zone carries on after it.",
        f"const int tzdataUntil = {tz.UNTIL};",
        "",
        "/// Each distinct schedule of offsets: the offset at [tzdataFrom], then each",
        "/// clock change as its instant and the offset from then on, in seconds.",
        "const List<List<int>> tzSchedules = [",
    ]
    for number, schedule in enumerate(schedules):
        out.append(f"  // {number}: {_zone_summary([z for z, i in index.items() if i == number])}")
        if not schedule.transitions:
            out.append(f"  [{schedule.initial}],")
            continue
        # The offset at tzdataFrom, then whole (instant, offset) pairs per line.
        out += ["  [", f"    {schedule.initial},"]
        out += _dart_packed([f"{at}, {offset}" for at, offset in schedule.transitions], "    ")
        out.append("  ],")
    out += [
        "];",
        "",
        "/// Every stored zone: its schedule in [tzSchedules] and its country.",
        "const Map<String, (int, String)> tzZones = {",
    ]
    for zone in residence["timeZones"]:
        out.append(
            f"  {_dart_string(zone['name'])}: ({index[zone['name']]}, {_dart_string(zone['country'])}),"
        )
    out += [
        "};",
        "",
        "/// A device's name for a zone that is not stored, to the stored zone it",
        "/// links to (Asia/Calcutta to Asia/Kolkata).",
        "const Map<String, String> tzDeviceLinks = {",
    ]
    for name, target in residence["deviceLinks"].items():
        out.append(f"  {_dart_string(name)}: {_dart_string(target)},")
    out += [
        "};",
        "",
        "/// Every stored country and its zones, in zone.tab's order.",
        "const Map<String, List<String>> tzCountries = {",
    ]
    for country in residence["countries"]:
        zones = [_dart_string(z) for z in country["zones"]]
        single = f"  {_dart_string(country['code'])}: [{', '.join(zones)}],"
        if len(single) <= 80:
            out.append(single)
        else:
            out.append(f"  {_dart_string(country['code'])}: [")
            out += _dart_packed(zones, "    ")
            out.append("  ],")
    out += ["};", "", "// dart format on", ""]
    return "\n".join(out)


def render_skew_sql(residence: dict) -> str:
    """The operator's read-only check that a server's tzdata agrees with mm_core's."""
    rows = []
    for zone in (z["name"] for z in residence["timeZones"]):
        instants = [
            tz.parse_utc(f"{year}-{month}-01T12:00:00Z")
            for year in SAMPLE_YEARS
            for month in ("01", "07")
        ]
        for at, _ in tz.schedule(zone).transitions:
            if _in_vector_years(at):
                instants += [at - 1, at]
        for at in sorted(instants):
            rows.append(
                f"  ({sql_literal(zone)}, timestamptz {sql_literal(tz.utc(at))}, {tz.offset_at(zone, at)})"
            )
    return "\n".join(
        [
            f"-- GENERATED by tool/contracts/generate.py from tzdata {residence['tzdata']}. Do not edit",
            "-- by hand. Read-only; not run in CI. Run it on the hosted project after each",
            '-- Supabase Postgres upgrade or tzdata bump (docs/operations.md, "Time-zone data"):',
            "-- every row it returns is a stored zone and an instant at which the server's UTC",
            "-- offset differs from the one mm_core bundles (server_seconds is NULL when the",
            "-- server does not know the zone). Asia/Karachi must never appear: if it does,",
            '-- stop and follow "The Pakistan tripwire" in docs/architecture/time.md. Any other',
            f"-- row is expected when the server's tzdata is older or newer than {residence['tzdata']} and a",
            "-- release between the two changed that zone (IANA's NEWS file names the zones each",
            "-- release changes); Africa/Casablanca may also differ by decree. Record such rows",
            "-- with the run. They change nothing while no SQL reads a stored zone (the push",
            "-- planner's helpers do not exist yet). A NULL server_seconds, or a row no release",
            "-- explains, needs a look before any SQL relies on that zone. Business dates are",
            "-- unaffected: they use Asia/Karachi's fixed offset.",
            "with known as materialized (select n.name from pg_timezone_names n),",
            "expected (zone, at, bundled_seconds) as (values",
            ",\n".join(rows),
            ")",
            "select e.zone, e.at, e.bundled_seconds, s.server_seconds",
            "from expected e",
            "left join known k on k.name = e.zone",
            "cross join lateral (",
            "  select case when k.name is not null then",
            "    extract(epoch from (e.at at time zone e.zone) - (e.at at time zone 'UTC'))::integer",
            "  end as server_seconds",
            ") s",
            "where s.server_seconds is distinct from e.bundled_seconds",
            "order by e.zone, e.at;",
            "",
        ]
    )


def outputs() -> dict[Path, str]:
    vectors = build()
    identity = build_identity()
    residence = build_residence()
    time_zones = build_time_zone_vectors()
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
        ROOT
        / "contracts"
        / "residence_vectors.json": json.dumps(residence, indent=2, ensure_ascii=False)
        + "\n",
        ROOT
        / "contracts"
        / "time_zone_vectors.json": json.dumps(time_zones, indent=2, ensure_ascii=False)
        + "\n",
        ROOT
        / "packages"
        / "mm_core"
        / "lib"
        / "src"
        / "time"
        / "time_zone_data.g.dart": render_time_zone_dart(residence),
        database_tests
        / "23_residence_contract.test.sql": render_residence_sql(residence, time_zones),
        ROOT / "tool" / "db" / "time_zone_skew.sql": render_skew_sql(residence),
    }


def main(argv: list[str]) -> int:
    check = argv[1:] == ["--check"]
    lists = argv[1:] == ["--print-sql-lists"]
    if argv[1:] and not (check or lists):
        print("usage: tool/contracts/generate.py [--check | --print-sql-lists]", file=sys.stderr)
        return 2
    try:
        if lists:
            print(render_sql_lists(build_residence()), end="")
            return 0
        files = outputs()
    except tz.MissingTzdataError as error:
        print(error, file=sys.stderr)
        return 2

    stale = []
    for path, content in files.items():
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
