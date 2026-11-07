"""Mutants of spec.py, to show that the differential checks have teeth.

compare.py <dir> <parts> mutant=<name> swaps one function of spec.py for a
version with one mechanism of the code removed; run.sh then expects the
named parts to report mismatches against the real Dart and SQL.
"""


def apply(name, spec):
    """Replaces one function of the spec module in place."""
    if name == "sql_prorate_no_least":
        # app.prorated_rent without least(p_rent, ...): the code before
        # 20261104143928_ledger_jobs_hardening.sql
        def prorated_rent_sql(rent, first, start, dim):
            if first and start > 1:
                return spec.round_half(rent * (spec.nsub(dim, start) + 1), dim * 100) * 100
            return rent

        spec.prorated_rent_sql = prorated_rent_sql
    elif name == "fee_cap_before_rounding":
        # cap first, round afterwards: the code before the same migration
        def daily_late_fee(rate, cap, overdue, days, grace, top=spec.MAX_FEE):
            if overdue == 0 or days <= grace:
                return 0
            fee = spec.round_to_rupee(spec.cap_fee(cap, spec.daily_fee(rate, days, top)))
            return min(fee, top)

        spec.daily_late_fee = daily_late_fee
    elif name == "billed_ignores_prorate_flag":
        # RentMath.billedRent without prorateFirstMonth
        def billed_rent(rent, prorate, before, first, start, dim):
            if before:
                return 0
            if not first:
                return rent
            return spec.prorated_rent(rent, spec.nsub(dim, start) + 1, dim)

        spec.billed_rent = billed_rent
    elif name == "alloc_cap_per_charge":
        # an allocation loop that applies at most 10^6 paisa per charge
        def alloc(xs, rem):
            out = []
            for h in xs:
                if rem == 0:
                    break
                applied = min(rem, h, 10**6)
                out.append(applied)
                rem = spec.nsub(rem, applied)
            return out

        spec.alloc = alloc
    else:
        raise SystemExit(f"unknown spec mutant {name}")


# name -> the parts of compare.py that must report mismatches
EXPECTED = {
    "sql_prorate_no_least": ["dart billed", "sql app.prorated_rent"],
    "fee_cap_before_rounding": ["dart fee", "sql app.late_fee_amount"],
    "billed_ignores_prorate_flag": ["dart billed", "sql sync_lease_billing"],
    "alloc_cap_per_charge": ["dart fifo", "sql allocate_payment"],
}
