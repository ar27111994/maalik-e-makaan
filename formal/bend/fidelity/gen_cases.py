"""Writes the inputs of the differential checks of SPEC.bend (see run.sh).

usage: gen_cases.py <output dir> <supabase/tests/database/_helpers.psql> [seed]

Writes, under the output dir:
  eval/main.bend, eval/expected.json  SPEC.bend evaluated by Bend on small
                                      inputs, and what spec.py says
  dart_cases.json                     inputs for dart_cases.dart (real mm_core)
  sql/pure.sql                        app.prorated_rent and app.late_fee_amount
                                      on a grid of inputs (read only)
  sql/fifo.sql, sql/fifo_plan.json    payments allocated by the real
                                      private.allocate_payment and
                                      private.apply_lease_credit (rolled back)
  sql/billing.sql, sql/billing_plan.json
                                      rent billed by the real lease insert
                                      trigger (private.sync_lease_billing),
                                      public.change_rent and public.end_lease
                                      (rolled back)
compare.py reads the results back and compares them with spec.py.
"""

# The SQL is built from literals this script generates, never from input, and
# the random inputs are test data, not secrets.
# ruff: noqa: S608, S311

import calendar
import json
import random
import sys
import uuid
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec

TODAY = date(2026, 11, 20)


def uid(rng):
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


def money(paisa):
    return f"{paisa // 100}.{paisa % 100:02d}"


# Bend evaluation of SPEC.bend (small inputs: Base's Nat is unary)


def gen_bend(out, rng):
    exprs, expected = [], []

    def nat(n):
        return f"{n}n"

    def lst(xs):
        return "[" + ", ".join(nat(x) for x in xs) + "]"

    def maybe(c):
        return "None{}" if c is None else "Some{" + nat(c) + "}"

    def boolean(b):
        return "True{}" if b else "False{}"

    def add(expr, value):
        exprs.append(expr)
        expected.append(value)

    for _ in range(40):
        xs = [rng.choice([0, 0, rng.randint(1, 60)]) for _ in range(rng.randint(0, 6))]
        p = rng.randint(0, 200)
        add(f"Spec.alloc({lst(xs)}, {nat(p)})", spec.alloc(xs, p))
        add(f"[Spec.unallocated({lst(xs)}, {nat(p)})]", [spec.unallocated(xs, p)])
        ps = [rng.randint(0, 80) for _ in range(rng.randint(0, 3))]
        add(f"Spec.outstanding({lst(ps)}, {lst(xs)})", spec.outstanding(ps, xs))
        i = rng.randint(0, 7)
        add(f"[Spec.paid_to({lst(ps)}, {lst(xs)}, {nat(i)})]", [spec.paid_to(ps, xs, i)])
    for _ in range(30):
        m, n = rng.randint(0, 50), rng.randint(0, 7)
        add(f"Spec.split_evenly({nat(m)}, {nat(n)})", spec.split_evenly(m, n))
    for _ in range(60):
        n, d = rng.randint(0, 300), rng.randint(0, 40)
        add(
            f"[Spec.half_up({nat(n)}, {nat(d)}), Spec.round_half({nat(n)}, {nat(d)})]",
            [spec.half_up(n, d), spec.round_half(n, d)],
        )
    for _ in range(50):
        rent, length = rng.randint(0, 260), rng.choice([3, 4, 28, 29, 30, 31])
        days, start = rng.randint(0, length), rng.randint(1, length)
        prorate, before, first = (rng.random() < 0.7 for _ in range(3))
        add(
            f"[Spec.prorated_rent({nat(rent)}, {nat(days)}, {nat(length)}),"
            f" Spec.prorated_rent_sql({nat(rent)}, {boolean(first)}, {nat(start)}, {nat(length)}),"
            f" Spec.billed_rent({nat(rent)}, {boolean(prorate)}, {boolean(before)},"
            f" {boolean(first)}, {nat(start)}, {nat(length)}),"
            f" Spec.billed_rent_sql({nat(rent)}, {boolean(prorate)}, {boolean(first)},"
            f" {nat(start)}, {nat(length)})]",
            [
                spec.prorated_rent(rent, days, length),
                spec.prorated_rent_sql(rent, first, start, length),
                spec.billed_rent(rent, prorate, before, first, start, length),
                spec.billed_rent_sql(rent, prorate, first, start, length),
            ],
        )
    for _ in range(60):
        rate = rng.randint(0, 60)
        cap = rng.choice([None, rng.randint(0, 400)])
        overdue = rng.choice([0, 1, 5])
        days, grace = rng.randint(0, 12), rng.randint(0, 6)
        top = rng.choice([100 * rng.randint(0, 6), rng.randint(0, 600)])
        args = f"{nat(rate)}, {maybe(cap)}, {nat(overdue)}, {nat(days)}, {nat(grace)}, {nat(top)}"
        add(
            f"[Spec.daily_late_fee({args}), Spec.daily_late_fee_sql({args})]",
            [
                spec.daily_late_fee(rate, cap, overdue, days, grace, top),
                spec.daily_late_fee_sql(rate, cap, overdue, days, grace, top),
            ],
        )
    folder = out / "eval"
    folder.mkdir(parents=True, exist_ok=True)
    body = ",\n   ".join(exprs)
    (folder / "main.bend").write_text(
        "import Base\nimport ./SPEC.bend as Spec\n\n"
        f"def main() -> List<&2, List<&2, Nat>>:\n  [{body}]\n"
    )
    (folder / "expected.json").write_text(json.dumps(expected))
    return len(exprs)


# Real Dart (mm_core)


def gen_dart(out, rng):
    cases = {"fifo": [], "split": [], "divide": [], "prorate": [], "billed": [], "fee": []}
    for _ in range(20000):
        charges = []
        for _ in range(rng.randint(0, 7)):
            charges.append(
                {
                    "id": uid(rng),
                    "due": str(date(2026, rng.randint(1, 3), rng.randint(1, 3))),
                    "outstanding": rng.choice([rng.randint(1, 50), rng.randint(1, 10**8)]),
                    "deposit": rng.random() < 0.2,
                }
            )
        chosen = []
        if charges and rng.random() < 0.4:
            chosen = [rng.choice(charges)["id"] for _ in range(rng.randint(1, 4))]
        cases["fifo"].append(
            {
                "payment": rng.choice([0, rng.randint(1, 120), rng.randint(1, 4 * 10**8)]),
                "charges": charges,
                "chosen": chosen,
                "deposit_adjustment": rng.random() < 0.3,
            }
        )
    amounts = list(range(-300, 301)) + [rng.randint(-(10**14) + 1, 10**14 - 1) for _ in range(3000)]
    for m in amounts:
        cases["split"].append({"amount": m, "count": rng.randint(1, 12)})
    for _ in range(20000):
        cases["divide"].append(
            {
                "n": rng.choice([rng.randint(0, 1000), rng.randint(0, 10**18)]),
                "d": rng.choice([rng.randint(1, 100), rng.randint(1, 10**9)]),
            }
        )
    for _ in range(20000):
        year, month = rng.randint(2024, 2028), rng.randint(1, 12)
        dim = calendar.monthrange(year, month)[1]
        first = date(year, month, 1)
        start = first + timedelta(days=rng.randint(-40, dim + 5))
        end = None if rng.random() < 0.5 else start + timedelta(days=rng.randint(0, 70))
        rent = rng.choice(
            [rng.randint(1, 300), rng.randint(1, 10**14 - 1), rng.randint(1, 10**7) * 100]
        )
        cases["prorate"].append(
            {
                "rent": rent,
                "year": year,
                "month": month,
                "start": str(start),
                "end": None if end is None else str(end),
            }
        )
        billing = first + timedelta(days=rng.randint(-70, dim + 40))
        cases["billed"].append(
            {
                "rent": rent,
                "year": year,
                "month": month,
                "billing_starts_on": str(billing),
                "prorate": rng.random() < 0.7,
            }
        )
    for _ in range(30000):
        cases["fee"].append(
            {
                "rate": rng.choice([rng.randint(0, 300), rng.randint(0, 10**9)]),
                "cap": rng.choice(
                    [None, rng.randint(0, 500), rng.randint(0, 10**11), 99999999999999]
                ),
                "overdue": rng.choice([0, rng.randint(1, 10**9)]),
                "days": rng.choice([rng.randint(0, 400), rng.randint(0, 10**6)]),
                "grace": rng.randint(0, 60),
            }
        )
    (out / "dart_cases.json").write_text(json.dumps(cases))
    return {key: len(value) for key, value in cases.items()}


# Real SQL


def gen_sql_pure(out, rng):
    rents = sorted(
        {
            1,
            2,
            49,
            50,
            51,
            90,
            99,
            100,
            101,
            149,
            150,
            151,
            199,
            1099,
            4500,
            450000,
            4500000,
            1000100,
            3333333,
            99999999999999,
            99999999999949,
            99999999999900,
        }
        | {rng.randint(1, 10**k) for k in range(1, 15) for _ in range(5)}
    )
    lines = ["\\set ON_ERROR_STOP on", "begin read only;"]
    lines.append("\\o " + str(out / "sql" / "prorated.csv"))
    lines.append(
        "copy (\n"
        f"with r(rent) as (select unnest(array[{','.join(map(str, rents))}]::bigint[])),\n"
        "m(month) as (select generate_series(date '2024-01-01', date '2028-12-01', interval '1 month')::date),\n"
        "d(month, dim) as (select month, extract(day from (month + interval '1 month - 1 day'))::int from m),\n"
        "s(month, dim, start) as (\n"
        "  select month, dim, (month + (k - 1))::date from d, generate_series(1, dim) k\n"
        "  union all select month, dim, (month - 1)::date from d\n"
        "  union all select month, dim, (month + interval '1 month')::date from d)\n"
        "select rent, month, dim, start, (app.prorated_rent(rent::numeric / 100, month, start) * 100)::text\n"
        "from r, s) to stdout with csv;"
    )
    rates = sorted(
        {0, 1, 2, 33, 49, 50, 51, 99, 100, 101, 149, 150, 151, 3335, 250000, 1000000000}
        | {rng.randint(1, 10**k) for k in range(2, 10)}
    )
    caps = [None, 0, 1, 49, 50, 51, 99, 100, 101, 150, 250, 251, 350, 250050, 99999999999950]
    caps += [99999999999999] + [rng.randint(1, 10**k) for k in range(2, 13)]
    days = [*list(range(0, 40)), 100, 365, 3650, 10000, 100000, 1000000]
    graces = [0, 5, 30, 59]
    outstanding = [0, 4000000]

    def lit(v):
        return "null::bigint" if v is None else str(v)

    lines.append("\\o " + str(out / "sql" / "latefee.csv"))
    lines.append(
        "copy (\n"
        f"with rt(rate) as (select unnest(array[{','.join(map(str, rates))}]::bigint[])),\n"
        "cp(cap) as (values " + ", ".join(f"({lit(c)})" for c in caps) + "),\n"
        f"dl(days) as (select unnest(array[{','.join(map(str, days))}]::int[])),\n"
        f"gr(grace) as (select unnest(array[{','.join(map(str, graces))}]::int[])),\n"
        f"os(o) as (select unnest(array[{','.join(map(str, outstanding))}]::bigint[]))\n"
        "select rate, coalesce(cap::text, ''), o, days, grace,\n"
        "  (app.late_fee_amount('daily'::public.late_fee_type, rate::numeric / 100,"
        " cap::numeric / 100, o::numeric / 100, days, grace) * 100)::text\n"
        "from rt, cp, dl, gr, os) to stdout with csv;"
    )
    lines += ["\\o", "rollback;"]
    (out / "sql" / "pure.sql").write_text("\n".join(lines) + "\n")
    return len(rents), len(rates) * len(caps) * len(days) * len(graces) * len(outstanding)


def gen_sql_fifo(out, rng, helpers):
    scenarios = []
    for s in range(120):
        charges = []
        for _ in range(rng.randint(0, 7)):
            amount = rng.choice([rng.randint(1, 60), rng.randint(1, 50000), rng.randint(1, 10**8)])
            charges.append(
                {
                    "id": uid(rng),
                    "kind": rng.choice(["other", "electricity", "security_deposit", "late_fee"]),
                    "due": str(date(2026, 9, 1) + timedelta(days=rng.randint(0, 6) * 9)),
                    "amount": amount,
                    "waived": rng.choice([0, 0, 0, rng.randint(0, amount)]),
                    "voided": rng.random() < 0.15,
                }
            )
        steps = []
        for k in range(rng.randint(1, 5)):
            amount = rng.choice(
                [rng.randint(1, 80), rng.randint(1, 60000), rng.randint(1, 3 * 10**8)]
            )
            pay = {
                "id": uid(rng),
                "amount": amount,
                "tax": rng.choice([0, 0, rng.randint(0, amount)]),
                "method": rng.choice(["cash", "cash", "bank_transfer", "deposit_adjustment"]),
                "paid_on": str(date(2026, 10, 1) + timedelta(days=rng.randint(0, 3))),
                "receipt": f"FVB-{s}-{k}",
                "key": uid(rng),
            }
            mode = rng.choice(["now", "now", "chosen", "later"])
            chosen = None
            if mode == "chosen" and charges:
                chosen = rng.sample([c["id"] for c in charges], rng.randint(1, len(charges)))
            steps.append({"pay": pay, "mode": mode, "chosen": chosen})
        extra = None
        if rng.random() < 0.5:
            extra = {
                "id": uid(rng),
                "kind": "other",
                "due": "2026-08-15",
                "amount": rng.randint(1, 10**6),
                "waived": 0,
                "voided": False,
            }
        scenarios.append(
            {
                "lease": uid(rng),
                "charges": charges,
                "steps": steps,
                "extra": extra,
                "apply_credit_at_end": rng.random() < 0.6,
            }
        )
    lines = [
        "\\set ON_ERROR_STOP on",
        "begin;",
        f"\\i {helpers}",
        "set local app.today_override = '2026-11-03';",
        "select tests.create_user('fvbend-fifo@example.com') as owner \\gset",
        "select tests.create_portfolio(:'owner') as pid \\gset",
    ]

    def charge_insert(lease, c):
        return (
            "insert into public.charges (id, portfolio_id, lease_id, kind, due_date, amount,"
            f" waived_amount, voided_at) values ('{c['id']}', :'pid', '{lease}', '{c['kind']}',"
            f" '{c['due']}', {money(c['amount'])}, {money(c['waived'])},"
            f" {'now()' if c['voided'] else 'null'});"
        )

    for sc in scenarios:
        lines.append("select tests.create_rental(:'pid') as r \\gset")
        lines.append(
            "select tests.create_lease(:'pid', :'r', '2026-08-01', 1000, "
            f"'{{\"id\": \"{sc['lease']}\", \"billing_starts_on\": \"2026-12-01\"}}') as lease \\gset"
        )
        lines += [charge_insert(sc["lease"], c) for c in sc["charges"]]
        for st in sc["steps"]:
            p = st["pay"]
            lines.append(
                "insert into public.payments (id, portfolio_id, lease_id, amount, tax_withheld,"
                " paid_on, method, receipt_number, idempotency_key) values "
                f"('{p['id']}', :'pid', '{sc['lease']}', {money(p['amount'])}, {money(p['tax'])},"
                f" '{p['paid_on']}', '{p['method']}', '{p['receipt']}', '{p['key']}');"
            )
            if st["mode"] == "now":
                lines.append(f"select private.allocate_payment('{p['id']}');")
            elif st["mode"] == "chosen":
                ids = (
                    "null"
                    if st["chosen"] is None
                    else "array[" + ",".join(f"'{c}'" for c in st["chosen"]) + "]::uuid[]"
                )
                lines.append(f"select private.allocate_payment('{p['id']}', {ids});")
        if sc["extra"]:
            # the charges insert trigger runs apply_lease_credit
            lines.append(charge_insert(sc["lease"], sc["extra"]))
        if sc["apply_credit_at_end"]:
            lines.append(f"select private.apply_lease_credit('{sc['lease']}');")
    leases = ",".join(f"'{sc['lease']}'" for sc in scenarios)
    lines.append("\\o " + str(out / "sql" / "fifo.csv"))
    lines.append(
        "copy (select 'A', a.payment_id::text, a.charge_id::text, (a.amount * 100)::bigint::text"
        " from public.payment_allocations a join public.payments p on p.id = a.payment_id"
        f" where p.lease_id in ({leases})"
        " union all select 'P', p.id::text, '', (p.unallocated_amount * 100)::bigint::text"
        f" from public.payments p where p.lease_id in ({leases})"
        " union all select 'C', c.id::text, '', (c.outstanding * 100)::bigint::text"
        f" from public.charges c where c.lease_id in ({leases})) to stdout with csv;"
    )
    lines += ["\\o", "rollback;"]
    (out / "sql" / "fifo.sql").write_text("\n".join(lines) + "\n")
    (out / "sql" / "fifo_plan.json").write_text(json.dumps(scenarios))
    return len(scenarios), sum(len(s["steps"]) for s in scenarios)


def month_start(d):
    return date(d.year, d.month, 1)


def add_month(d):
    return date(d.year + d.month // 12, d.month % 12 + 1, 1)


def gen_sql_billing(out, rng, helpers):
    leases = []
    for _ in range(150):
        start = TODAY - timedelta(days=rng.randint(0, 420))
        billing = start + timedelta(days=rng.choice([0, 0, rng.randint(0, 60)]))
        if billing > TODAY:
            billing = TODAY
        rent = rng.choice([rng.randint(10000, 9999999), rng.randint(100, 99999) * 100])
        lease = {
            "id": uid(rng),
            "start": str(start),
            "billing": str(billing),
            "prorate": rng.random() < 0.7,
            "rent": rent,
            "change": None,
            "moveout": None,
        }
        if rng.random() < 0.4:
            months = []
            month = month_start(billing)
            while month <= add_month(month_start(TODAY)):
                months.append(month)
                month = add_month(month)
            lease["change"] = {
                "month": str(rng.choice(months)),
                "rent": rng.choice([rng.randint(10000, 9999999), rng.randint(100, 99999) * 100]),
            }
        if rng.random() < 0.4:
            span = (TODAY - start).days
            lease["moveout"] = str(start + timedelta(days=rng.randint(0, span)))
        leases.append(lease)
    lines = [
        "\\set ON_ERROR_STOP on",
        "begin;",
        f"\\i {helpers}",
        f"set local app.today_override = '{TODAY}';",
        "select tests.create_user('fvbend-billing@example.com') as owner \\gset",
        "select tests.create_portfolio(:'owner') as pid \\gset",
    ]
    for lease in leases:
        overrides = json.dumps(
            {
                "id": lease["id"],
                "billing_starts_on": lease["billing"],
                "prorate_first_month": lease["prorate"],
            }
        )
        lines.append("select tests.create_rental(:'pid') as r \\gset")
        lines.append(
            f"select tests.create_lease(:'pid', :'r', '{lease['start']}',"
            f" {money(lease['rent'])}, '{overrides}') as lease \\gset"
        )
    lines.append("select tests.authenticate_as(:'owner');")
    for lease in leases:
        if lease["change"]:
            change = lease["change"]
            lines.append(
                f"select (public.change_rent('{lease['id']}', '{change['month']}',"
                f" {money(change['rent'])}, 'renegotiation')).id;"
            )
    for lease in leases:
        if lease["moveout"]:
            lines.append(
                f"select (public.end_lease('{lease['id']}', '{lease['moveout']}',"
                " 'tenant_moved_out')).status;"
            )
    lines.append("select tests.clear_authentication();")
    ids = ",".join(f"'{lease['id']}'" for lease in leases)
    lines.append("\\o " + str(out / "sql" / "billing.csv"))
    lines.append(
        "copy (select c.lease_id::text, c.period_month::text, (c.amount * 100)::bigint::text,"
        " (c.voided_at is not null)::text from public.charges c"
        f" where c.lease_id in ({ids}) and c.kind = 'rent' and c.source = 'auto_rent'"
        " order by 1, 2) to stdout with csv;"
    )
    lines += ["\\o", "rollback;"]
    (out / "sql" / "billing.sql").write_text("\n".join(lines) + "\n")
    (out / "sql" / "billing_plan.json").write_text(
        json.dumps({"today": str(TODAY), "leases": leases})
    )
    return len(leases)


def main():
    out = Path(sys.argv[1]).resolve()
    helpers = Path(sys.argv[2]).resolve()
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 2026
    (out / "sql").mkdir(parents=True, exist_ok=True)
    print(f"bend: {gen_bend(out, random.Random(seed))} expressions")
    print(f"dart: {gen_dart(out, random.Random(seed + 1))}")
    rents, fee_rows = gen_sql_pure(out, random.Random(seed + 2))
    print(f"sql pure: {rents} rents, {fee_rows} late-fee rows")
    scenarios, payments = gen_sql_fifo(out, random.Random(seed + 3), helpers)
    print(f"sql fifo: {scenarios} leases, {payments} payments")
    print(f"sql billing: {gen_sql_billing(out, random.Random(seed + 4), helpers)} leases")


if __name__ == "__main__":
    main()
