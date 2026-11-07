"""Line-by-line Python transliteration of formal/bend/SPEC.bend.

Only Nat arithmetic is used: Nat.sub truncates at 0, and Nat.div / Nat.mod
by 0 give (0, a) like Base's Nat.divmod. run.sh checks this file against
SPEC.bend itself by evaluating SPEC.bend with Bend on small inputs
(gen_cases.py writes them); the other checks then compare this file with
the real Dart and the real SQL on inputs of every size.
"""

# LateFeePolicy.maxFee / the SQL literal 999999999999, in paisa.
MAX_FEE = 99999999999900


def nsub(a, b):
    return a - b if a > b else 0


def ndiv(a, b):
    return 0 if b == 0 else a // b


def nmod(a, b):
    return a if b == 0 else a % b


def at(xs, i):
    return xs[i] if i < len(xs) else 0


# 1. FIFO payment allocation


def alloc(xs, rem):
    out = []
    for h in xs:
        if rem == 0:
            break
        a = min(rem, h)
        out.append(a)
        rem = nsub(rem, a)
    return out


def unallocated(xs, rem):
    for h in xs:
        if rem == 0:
            return 0
        rem = nsub(rem, min(rem, h))
    return rem


def settle(xs, ys):
    out = []
    for k, x in enumerate(xs):
        if k < len(ys):
            out.append(nsub(x, ys[k]))
        else:
            out.extend(xs[k:])
            break
    return out


def paid_to(ps, xs, i):
    total = 0
    for p in ps:
        a = alloc(xs, p)
        total += at(a, i)
        xs = settle(xs, a)
    return total


def outstanding(ps, xs):
    for p in ps:
        xs = settle(xs, alloc(xs, p))
    return xs


# 2. Even split


def split_bump(xs, left):
    out = []
    for k, h in enumerate(xs):
        if left == 0:
            out.extend(xs[k:])
            break
        out.append(h + 1)
        left -= 1
    return out


def split_evenly(m, n):
    parts = [ndiv(m, n)] * n
    return split_bump(parts, nsub(m, sum(parts)))


# 3. Half-up division and proration


def half_up(n, d):
    q, r = ndiv(n, d), nmod(n, d)
    if r == 0:
        return q
    return q + 1 if r * 2 >= d else q


def round_half(n, d):
    return ndiv(2 * n + d, 2 * d)


def multiply_to_rupee(paisa, num, den):
    return half_up(paisa * num, den * 100) * 100


def prorated_rent(rent, days, length):
    if days == length:
        return rent
    if days == 0:
        return 0
    return min(rent, multiply_to_rupee(rent, days, length))


def billed_rent(rent, prorate, before, first, start, dim):
    if before:
        return 0
    if not first or not prorate:
        return rent
    return prorated_rent(rent, nsub(dim, start) + 1, dim)


def prorated_rent_sql(rent, first, start, dim):
    if not first:
        return rent
    if start > 1:
        return min(rent, round_half(rent * (nsub(dim, start) + 1), dim * 100) * 100)
    return rent


def billed_rent_sql(rent, prorate, first, start, dim):
    return prorated_rent_sql(rent, first, start, dim) if prorate else rent


# 4. Daily late fee with a cap


def daily_fee(rate, days, top):
    return min(rate * days, top)


def cap_fee(cap, x):
    return x if cap is None else min(x, cap)


def round_to_rupee(x):
    return half_up(x, 100) * 100


def daily_late_fee(rate, cap, overdue, days, grace, top=MAX_FEE):
    if overdue == 0 or days <= grace:
        return 0
    return min(cap_fee(cap, round_to_rupee(daily_fee(rate, days, top))), top)


def daily_late_fee_sql(rate, cap, overdue, days, grace, top=MAX_FEE):
    if overdue == 0 or days <= grace:
        return 0
    capped = top if cap is None else cap
    return min(min(round_half(rate * days, 100) * 100, capped), top)
