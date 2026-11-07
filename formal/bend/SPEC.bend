# Maalik-e-Makaan: executable models of the ledger's money algorithms, as
# Bend functions over Base's Nat. LAWS.bend states what they guarantee and
# PROOF.bend proves it.
#
# Every amount is a whole number of paisa (Rs 1 = 100 paisa): mm_core's
# Money stores `final int paisa` (packages/mm_core/lib/src/money/money.dart)
# and PostgreSQL's numeric(14,2) columns hold two fraction digits, i.e. whole
# paisa. These algorithms only ever see non-negative amounts, counts and day
# numbers, so Nat models them exactly; README.md lists what is left out.
#
# Each model follows the LAST definition of its SQL function across
# supabase/migrations/*.sql (later migrations redefine some of them); the
# migration named next to a function is the one holding that definition.

import Base

# Vocabulary
# ----------

# LE(a, b): the proofs of a <= b. Unit when it holds, Empty when it fails.
def LE(a: Nat, b: Nat) -> Data:
  match a b:
    case 0n b0:
      Unit
    case 1n+a1 0n:
      Empty
    case 1n+a1 1n+b1:
      LE(a1, b1)

# LT(a, b): the proofs of a < b
def LT(a: Nat, b: Nat) -> Data:
  LE(1n+a, b)

# the total of a list of amounts (Money.sum)
def sum(xs: List<&2, Nat>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(h, sum(t))

# at(xs, i): the amount at position i, counting from 0n; 0n past the end
def at(xs: List<&2, Nat>, i: Nat) -> Nat:
  match xs i:
    case Nil{} _:
      0n
    case h <> t 0n:
      h
    case h <> t 1n+p:
      at(t, p)

# 1. FIFO payment allocation
# --------------------------
# SQL : private.allocate_payment, supabase/migrations/20261103193658_ledger.sql
#       (not redefined by any later migration)
# Dart: planFifoAllocation, packages/mm_core/lib/src/ledger/allocation.dart
#
# xs holds the outstanding amount of each charge, in the order the loop
# visits them (SQL: order by array_position(p_charge_ids, c.id), then
# c.due_date, c.id; Dart: by the rank in chosenChargeIds, then dueDate, then
# id). The laws hold for every list, hence for every order and every
# selection of charges (voided charges, the deposit on a deposit adjustment).
# rem is the amount still to apply (SQL v_remaining, Dart remaining): at
# first, the payment's unallocated amount.
#
# alloc(xs, rem) holds, at position i, what the payment applies to charge i:
# the payment_allocations.amount (Dart: ChargeAllocation.amount) the loop
# writes for it, or 0n where it writes none. The list stops where the loop
# exits. A charge with nothing outstanding gets min(rem, 0n) = 0n and leaves
# rem as it was: no row, exactly as the SQL `where c.outstanding > 0` (and
# Dart's OpenCharge, which requires outstanding > 0) keeps it out of the loop.
def alloc(xs: List<&2, Nat>, +rem: Nat) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      match rem:
        case 0n:
          # SQL `exit when v_remaining <= 0;`
          # Dart `if (remaining.isZero) break;`
          Nil{}
        case 1n+r:
          # SQL `v_apply := least(v_remaining, v_charge.outstanding);`
          # Dart `final applied = Money.min(remaining, charge.outstanding);`
          +a = Nat.min(1n+r, h)
          # SQL `v_remaining := v_remaining - v_apply;`
          # Dart `remaining -= applied;`
          a <> alloc(t, Nat.sub(1n+r, a))

# unallocated(xs, rem): what the same loop leaves over. SQL: v_remaining at
# the end, stored through `allocated_amount = amount + tax_withheld -
# v_remaining` (so payments.unallocated_amount is v_remaining); Dart:
# AllocationPlan.unallocated.
def unallocated(xs: List<&2, Nat>, +rem: Nat) -> Nat:
  match xs:
    case Nil{}:
      rem
    case h <> t:
      match rem:
        case 0n:
          0n
        case 1n+r:
          unallocated(t, Nat.sub(1n+r, Nat.min(1n+r, h)))

# settle(xs, ys): each charge's outstanding amount once the allocations ys
# are booked. SQL `update public.charges set paid_amount = paid_amount +
# v_apply`, and charges.outstanding is generated as amount - paid_amount -
# waived_amount, so it drops by v_apply. Past the end of ys nothing changes.
def settle(xs: List<&2, Nat>, ys: List<&2, Nat>) -> List<&2, Nat>:
  match xs ys:
    case Nil{} _:
      Nil{}
    case x <> xt Nil{}:
      x <> xt
    case x <> xt y <> yt:
      Nat.sub(x, y) <> settle(xt, yt)

# paid_to(ps, xs, i): what the payments ps, allocated one after another
# against what the previous ones left outstanding, apply to charge i in all
# (private.apply_lease_credit, 20261103193658_ledger.sql, runs
# allocate_payment for each payment with unallocated credit, ordered by
# paid_on, id); outstanding(ps, xs): the outstanding amounts they leave.
def paid_to(ps: List<&2, Nat>, +xs: List<&2, Nat>, +i: Nat) -> Nat:
  match ps:
    case Nil{}:
      0n
    case p <> pt:
      +a = alloc(xs, p)
      Nat.add(at(a, i), paid_to(pt, settle(xs, a), i))

def outstanding(ps: List<&2, Nat>, +xs: List<&2, Nat>) -> List<&2, Nat>:
  match ps:
    case Nil{}:
      xs
    case p <> pt:
      outstanding(pt, settle(xs, alloc(xs, p)))

# 2. Even split
# -------------
# Dart: Money.splitEvenly(count), packages/mm_core/lib/src/money/money.dart,
# which is allocate(List<int>.filled(count, 1)), for an amount of m >= 0
# paisa split into n = count parts.
#
# In allocate, every ratio is 1 and total = n, so every share is
# magnitude * 1 = m and every part is `share ~/ totalBig` = m div n; then
# `leftover = paisa.abs() - allocated`, allocated being the sum of the parts.
# Every slot's remainder `share.remainder(totalBig)` is the same, so
# `remainders.sort` (remainder descending, then index ascending) leaves the
# slots in index order, and the final loop
#   for (final entry in remainders) {
#     if (leftover == 0) break;
#     parts[entry.index] += 1;
#     leftover -= 1;
#   }
# is split.bump: one more paisa to each slot, in index order, until the
# leftover runs out. A negative amount is split as its magnitude, then every
# part is negated (`sign`), which keeps both laws.
def split.bump(xs: List<&2, Nat>, l: Nat) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      match l:
        case 0n:
          h <> t
        case 1n+k:
          (1n+h) <> split.bump(t, k)

def split_evenly(+m: Nat, +n: Nat) -> List<&2, Nat>:
  +parts = List.replicate(Nat, n, Nat.div(m, n))
  split.bump(parts, Nat.sub(m, sum(parts)))

# 3. Half-up division and proration
# ---------------------------------
# Dart: divideRounded(n, d, RoundingMode.halfUp) (money.dart) for n >= 0 and
# d > 0:
#   final quotient = n ~/ d;
#   final remainder = n.remainder(d);
#   if (remainder == BigInt.zero) return quotient;
#   final twiceRemainder = remainder.abs() * BigInt.two;
#   return twiceRemainder >= d ? awayFromZero : quotient;
# (awayFromZero is quotient + 1 for n >= 0)
def half_up.away(q: Nat, b: Bool) -> Nat:
  match b:
    case True{}:
      1n+q
    case False{}:
      q

def half_up.rem(q: Nat, r: Nat, d: Nat) -> Nat:
  match r:
    case 0n:
      q
    case 1n+k:
      half_up.away(q, Nat.is_ge(Nat.mul(1n+k, 2n), d))

def half_up(+n: Nat, +d: Nat) -> Nat:
  half_up.rem(Nat.div(n, d), Nat.mod(n, d), d)

# SQL: round(n / d, 0) for numeric n >= 0 and d > 0 is the nearest whole
# number, halves away from zero: floor(n / d + 1/2) = (2n + d) div (2d).
def round_half(+n: Nat, +d: Nat) -> Nat:
  Nat.div(Nat.add(Nat.mul(2n, n), d), Nat.mul(2n, d))

# Money.multiplyToStep(numerator, denominator) with stepRupees = 1 and
# RoundingMode.halfUp: step = 1 * paisaPerRupee = 100 paisa,
# steps = divideRounded(paisa * numerator, denominator * step, halfUp), and
# the result is steps * step paisa.
def multiply_to_rupee(paisa: Nat, num: Nat, den: Nat) -> Nat:
  Nat.mul(half_up(Nat.mul(paisa, num), Nat.mul(den, 100n)), 100n)

# RentMath.proratedRent (packages/mm_core/lib/src/rent/rent_math.dart), with
# days = occupiedDays(period, occupancy) and len = period.lengthInDays:
#   if (days == period.lengthInDays) return monthlyRent;
#   if (days == 0) return Money.zero;
#   return Money.min(
#     monthlyRent,
#     monthlyRent.multiplyToStep(days, period.lengthInDays),
#   );
# occupiedDays counts the days of the month inside the occupancy DateRange,
# both ends included. Its date arithmetic is not modelled: days is an input
# (the fidelity harness checks it against the real Dart on real dates).
def prorated_rent.some(+rent: Nat, days: Nat, len: Nat) -> Nat:
  match days:
    case 0n:
      0n
    case 1n+k:
      Nat.min(rent, multiply_to_rupee(rent, 1n+k, len))

def prorated_rent.full(+rent: Nat, days: Nat, len: Nat, full: Bool) -> Nat:
  match full:
    case True{}:
      rent
    case False{}:
      prorated_rent.some(rent, days, len)

def prorated_rent(+rent: Nat, +days: Nat, +len: Nat) -> Nat:
  prorated_rent.full(rent, days, len, Nat.is_eq(days, len))

# RentMath.billedRent (rent_math.dart): the rent the ledger bills for a
# month, as Dart previews it.
#   final firstMonth = MonthPeriod.of(billingStartsOn);
#   if (period.compareTo(firstMonth) < 0) return Money.zero;
#   if (period != firstMonth || !prorateFirstMonth) return monthlyRent;
#   return proratedRent(monthlyRent: monthlyRent, period: period,
#                       occupancy: DateRange(billingStartsOn));
# before = (period < firstMonth), first = (period == firstMonth),
# prorate = prorateFirstMonth, start = billingStartsOn.day and dim = the
# number of days in the month. The occupancy DateRange(billingStartsOn) is
# open-ended, so in the first month occupiedDays is dim - start + 1.
def billed_rent.first(+rent: Nat, prorate: Bool, +start: Nat, +dim: Nat) -> Nat:
  match prorate:
    case False{}:
      rent
    case True{}:
      prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim)

def billed_rent.month(+rent: Nat, prorate: Bool, first: Bool, +start: Nat, +dim: Nat) -> Nat:
  match first:
    case False{}:
      rent
    case True{}:
      billed_rent.first(rent, prorate, start, dim)

def billed_rent(+rent: Nat, prorate: Bool, before: Bool, first: Bool, +start: Nat, +dim: Nat) -> Nat:
  match before:
    case True{}:
      0n
    case False{}:
      billed_rent.month(rent, prorate, first, start, dim)

# SQL: app.prorated_rent(p_rent, p_month, p_billing_starts_on), last defined
# in supabase/migrations/20261104143928_ledger_jobs_hardening.sql, with
# first = whether billing starts in p_month, start = extract(day from
# p_billing_starts_on) and dim = the number of days in p_month:
#   case when first and start > 1
#        then least(p_rent, round(p_rent * (dim - start + 1) / dim, 0))
#        else p_rent end
# p_rent is in rupees, so in paisa the prorated branch is
# min(rent, 100 * round(rent * days / (dim * 100), 0)), days = dim - start + 1.
def prorated_rent_sql.later(+rent: Nat, start: Nat, +dim: Nat, later: Bool) -> Nat:
  match later:
    case False{}:
      rent
    case True{}:
      Nat.min(rent, Nat.mul(round_half(Nat.mul(rent, Nat.add(Nat.sub(dim, start), 1n)), Nat.mul(dim, 100n)), 100n))

def prorated_rent_sql(+rent: Nat, first: Bool, +start: Nat, +dim: Nat) -> Nat:
  match first:
    case False{}:
      rent
    case True{}:
      prorated_rent_sql.later(rent, start, dim, Nat.is_gt(start, 1n))

# SQL: the rent the ledger bills for a month. private.sync_lease_billing
# (last defined in 20261104143928_ledger_jobs_hardening.sql) walks the months
# from the billing-start month (or the month after the newest 'auto_rent'
# charge) through the month of p_as_of, and bills each month v_month at
#   v_amount := case
#     when v_lease.prorate_first_month then app.prorated_rent(v_rent, v_month, v_lease.billing_starts_on)
#     else v_rent
#   end;
# inserting no charge when v_amount is 0. v_rent is the rent in force for
# v_month (the latest rent_changes row on or before it, else
# leases.monthly_rent). public.change_rent (20261103193658_ledger.sql)
# re-prices generated rent nobody has paid or waived with the same case, and
# public.end_lease (20261103193658_ledger.sql) bills through the move-out
# month with sync_lease_billing(p_lease_id, p_moved_out_on), so the move-out
# month is billed by this rule too: the move-out day is not one of its
# inputs. prorate = prorate_first_month; first, start and dim are as for
# prorated_rent_sql. No month before the billing-start month is billed.
def billed_rent_sql(+rent: Nat, prorate: Bool, first: Bool, +start: Nat, +dim: Nat) -> Nat:
  match prorate:
    case True{}:
      prorated_rent_sql(rent, first, start, dim)
    case False{}:
      rent

# 4. Daily late fee with a cap
# ----------------------------
# Dart: LateFeePolicy.feeFor, DailyLateFee.computeFee and DailyLateFee.capFee,
# packages/mm_core/lib/src/rent/late_fee_policy.dart. SQL: app.late_fee_amount
# with p_type = 'daily', last defined in
# supabase/migrations/20261104143928_ledger_jobs_hardening.sql.
# rate = perDay / p_value, cap = cap / p_cap (None{} for no cap),
# overdue = overdueAmount / p_outstanding, days = daysLate / p_days_late,
# grace = graceDays / p_grace_days.
#
# top is the largest fee ever charged: Dart LateFeePolicy.maxFee =
# Money.fromRupees(999999999999), SQL the literal 999999999999 (rupees), i.e.
# 99999999999900 paisa. It is a parameter here, not a literal, because
# Base's Nat is unary: the laws hold for every top (or every whole-rupee top),
# so for the real one, and the fidelity harness runs the real value.

# DailyLateFee.computeFee:
#   final fee = BigInt.from(perDay.paisa) * BigInt.from(daysLate);
#   final limit = BigInt.from(LateFeePolicy.maxFee.paisa);
#   return Money.fromPaisa((fee > limit ? limit : fee).toInt());
def daily_fee(+rate: Nat, +days: Nat, +top: Nat) -> Nat:
  Nat.min(Nat.mul(rate, days), top)

# DailyLateFee.capFee(roundedFee):
#   limit == null ? roundedFee : Money.min(roundedFee, limit)
def cap_fee(cap: Maybe<&2, Nat>, +x: Nat) -> Nat:
  match cap:
    case None{}:
      x
    case Some{c}:
      Nat.min(x, c)

# Money.roundToRupee() = roundToStep(1): step = 100 paisa,
# steps = divideRounded(paisa, step, halfUp), result steps * step.
def round_to_rupee(x: Nat) -> Nat:
  Nat.mul(half_up(x, 100n), 100n)

# LateFeePolicy.feeFor:
#   if (!overdueAmount.isPositive || daysLate <= graceDays) return Money.zero;
#   final rounded = computeFee(...).roundToRupee();
#   return Money.min(capFee(rounded), maxFee);
def daily_late_fee.late(+rate: Nat, cap: Maybe<&2, Nat>, +days: Nat, +top: Nat, within: Bool) -> Nat:
  match within:
    case True{}:
      0n
    case False{}:
      Nat.min(cap_fee(cap, round_to_rupee(daily_fee(rate, days, top))), top)

def daily_late_fee(+rate: Nat, cap: Maybe<&2, Nat>, overdue: Nat, +days: Nat, +grace: Nat, +top: Nat) -> Nat:
  match overdue:
    case 0n:
      0n
    case 1n+o:
      daily_late_fee.late(rate, cap, days, top, Nat.is_le(days, grace))

# SQL app.late_fee_amount for p_type = 'daily', amounts in rupees:
#   case when p_type = 'none' or p_outstanding <= 0
#             or p_days_late <= p_grace_days then 0::numeric
#        else least(
#          round(p_value * p_days_late, 0),
#          coalesce(case when p_type = 'daily' then p_cap end, 999999999999),
#          999999999999) end
# round(x, 0) on rupees is, in paisa, 100 * round(x / 100, 0), and least of
# three is min(min(a, b), c).
def daily_late_fee_sql.cap(cap: Maybe<&2, Nat>, +top: Nat) -> Nat:
  match cap:
    case None{}:
      top
    case Some{c}:
      c

def daily_late_fee_sql.late(+rate: Nat, cap: Maybe<&2, Nat>, +days: Nat, +top: Nat, within: Bool) -> Nat:
  match within:
    case True{}:
      0n
    case False{}:
      Nat.min(Nat.min(Nat.mul(round_half(Nat.mul(rate, days), 100n), 100n), daily_late_fee_sql.cap(cap, top)), top)

def daily_late_fee_sql(+rate: Nat, cap: Maybe<&2, Nat>, overdue: Nat, +days: Nat, +grace: Nat, +top: Nat) -> Nat:
  match overdue:
    case 0n:
      0n
    case 1n+o:
      daily_late_fee_sql.late(rate, cap, days, top, Nat.is_le(days, grace))
