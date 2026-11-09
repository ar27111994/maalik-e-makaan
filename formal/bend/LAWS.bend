# Maalik-e-Makaan: the laws of the ledger's money algorithms.
#
# Each law is a claim about the executable models in SPEC.bend, which follow
# mm_core (Dart) and the SQL migrations step by step; SPEC.bend cites the
# code. PROOF.bend proves every law, and `bend PROOF.bend --verdict` checks
# the proofs, then checks them again with Bend's kernel, which is proven
# correct in Lean.
#
# Amounts are whole paisa (Rs 1 = 100n). Spec.LE(a, b) is a <= b and
# Spec.LT(a, b) is a < b. Spec.at(xs, i) is the amount at position i (0n
# past the end) and Spec.sum(xs) is the total. A `for` whose type is a
# proposition (an LE, an LT or an equation) is a hypothesis of the law.

import Base
import ./SPEC.bend as Spec

# Vocabulary
# ----------

# LAW: Spec.LE means Base's <=: a proof of a <= b makes Nat.is_le(a, b) True
law le_is_base_le:
  for +a: Nat
  for +b: Nat
  for  h: Spec.LE(a, b)
  {Nat.is_le(a, b) == True{} : Bool}

# LAW: ... and Nat.is_le(a, b) == True{} gives a proof of a <= b
law base_le_is_le:
  for +a: Nat
  for +b: Nat
  for  e: {Nat.is_le(a, b) == True{} : Bool}
  Spec.LE(a, b)

# 1. FIFO payment allocation
# --------------------------
# SQL private.allocate_payment and Dart planFifoAllocation. xs: the charges'
# outstanding amounts in the order the loop visits them; p: the payment's
# unallocated amount. Every law holds for every list, so for every order and
# for both the SQL and the Dart way of choosing the charges.

# LAW (a) conservation: the amounts applied to the charges plus the amount
# left unallocated add up to the payment (so payments.allocated_amount is
# the sum of its payment_allocations rows)
law fifo_conserves:
  for +xs: List<&2, Nat>
  for +p: Nat
  {Nat.add(Spec.sum(Spec.alloc(xs, p)), Spec.unallocated(xs, p)) == p : Nat}

# LAW: a payment never allocates more than its amount
# (payments_allocation_check: allocated_amount <= amount + tax_withheld)
law fifo_allocated_le_payment:
  for +xs: List<&2, Nat>
  for +p: Nat
  Spec.LE(Spec.sum(Spec.alloc(xs, p)), p)

# LAW (b) no charge receives more than its outstanding amount
# (charges_not_overpaid_check: paid_amount + waived_amount <= amount)
law fifo_bounded:
  for +xs: List<&2, Nat>
  for +p: Nat
  for +i: Nat
  Spec.LE(Spec.at(Spec.alloc(xs, p), i), Spec.at(xs, i))

# LAW (c) if anything is left unallocated, every charge was settled in full:
# each charge received exactly its outstanding amount
law fifo_leftover_settles_all:
  for +xs: List<&2, Nat>
  for +p: Nat
  for +rest: Spec.LT(0n, Spec.unallocated(xs, p))
  {Spec.alloc(xs, p) == xs : List<&2, Nat>}

# LAW (d) FIFO: if charge i receives a positive amount, every earlier
# charge j was settled in full
law fifo_order:
  for +xs: List<&2, Nat>
  for +p: Nat
  for +i: Nat
  for +j: Nat
  for  before: Spec.LT(j, i)
  for  paid: Spec.LT(0n, Spec.at(Spec.alloc(xs, p), i))
  {Spec.at(Spec.alloc(xs, p), j) == Spec.at(xs, j) : Nat}

# LAW: every allocation row the loop writes for an open charge is positive
# (payment_allocations_amount_check: amount > 0)
law fifo_rows_positive:
  for +xs: List<&2, Nat>
  for +p: Nat
  for +i: Nat
  for  row: Spec.LT(i, List.length(&2, Nat, Spec.alloc(xs, p)))
  for  open: Spec.LT(0n, Spec.at(xs, i))
  Spec.LT(0n, Spec.at(Spec.alloc(xs, p), i))

# LAW (e) a second payment, applied to what the first one left outstanding,
# never overpays a charge: per charge, the two allocations add up to at most
# its outstanding amount
law fifo_two_payments:
  for +xs: List<&2, Nat>
  for +p1: Nat
  for +p2: Nat
  for +i: Nat
  Spec.LE(Nat.add(Spec.at(Spec.alloc(xs, p1), i), Spec.at(Spec.alloc(Spec.settle(xs, Spec.alloc(xs, p1)), p2), i)), Spec.at(xs, i))

# LAW (e, any number of payments) allocated one after another (as
# private.apply_lease_credit does), the payments ps pay each charge exactly
# what it owed minus what it still owes: no paisa is lost or created
law fifo_payments_conserve:
  for +ps: List<&2, Nat>
  for +xs: List<&2, Nat>
  for +i: Nat
  {Nat.add(Spec.paid_to(ps, xs, i), Spec.at(Spec.outstanding(ps, xs), i)) == Spec.at(xs, i) : Nat}

# LAW (e, any number of payments) ... so they never overpay a charge
law fifo_payments_never_overpay:
  for +ps: List<&2, Nat>
  for +xs: List<&2, Nat>
  for +i: Nat
  Spec.LE(Spec.paid_to(ps, xs, i), Spec.at(xs, i))

# 2. Even split (Money.splitEvenly)
# ---------------------------------
# m: the amount in paisa, n: the count of parts.

# LAW splitEvenly(count) returns count parts
law split_count:
  for +m: Nat
  for +n: Nat
  {List.length(&2, Nat, Spec.split_evenly(m, n)) == n : Nat}

# LAW the parts add up to the amount (count > 0; splitEvenly throws for 0)
law split_sum:
  for +m: Nat
  for +n: Nat
  for  pos: Spec.LT(0n, n)
  {Spec.sum(Spec.split_evenly(m, n)) == m : Nat}

# LAW any two parts differ by at most 1 paisa: part i <= part j + 1 (j must
# be a part; i need not be, as there is no part past the end)
law split_fair:
  for +m: Nat
  for +n: Nat
  for +i: Nat
  for +j: Nat
  for  hj: Spec.LT(j, n)
  Spec.LE(Spec.at(Spec.split_evenly(m, n), i), Nat.add(Spec.at(Spec.split_evenly(m, n), j), 1n))

# 3. Half-up division and proration
# ---------------------------------
# Spec.round_half(a, b) is q = (2a + b) div (2b), SQL's round(a / b, 0).

# LAW q = (2a + b) div (2b) satisfies 2b * q <= 2a + b (for b = 0 both
# sides are trivial: Base's division by 0 gives 0)
law round_half_lower:
  for +a: Nat
  for +b: Nat
  Spec.LE(Nat.mul(Nat.mul(2n, b), Spec.round_half(a, b)), Nat.add(Nat.mul(2n, a), b))

# LAW ... and 2a + b < 2b * (q + 1): q is the nearest whole number to a / b,
# halves rounded up
law round_half_upper:
  for +a: Nat
  for +b: Nat
  for  pos: Spec.LT(0n, b)
  Spec.LT(Nat.add(Nat.mul(2n, a), b), Nat.mul(Nat.mul(2n, b), Nat.add(Spec.round_half(a, b), 1n)))

# LAW Dart's divideRounded(n, d, RoundingMode.halfUp) computes exactly SQL's
# round(n / d, 0), for every n >= 0 and d > 0
law half_up_agrees:
  for +n: Nat
  for +d: Nat
  for  pos: Spec.LT(0n, d)
  {Spec.half_up(n, d) == Spec.round_half(n, d) : Nat}

# Proration. Spec.prorated_rent is Dart's RentMath.proratedRent with
# days = occupiedDays(period, occupancy) and len = period.lengthInDays.

# LAW a fully occupied month is billed the monthly rent
law prorate_full_month:
  for +rent: Nat
  for +len: Nat
  {Spec.prorated_rent(rent, len, len) == rent : Nat}

# LAW no occupied day is billed nothing
law prorate_no_days:
  for +rent: Nat
  for +len: Nat
  for  pos: Spec.LT(0n, len)
  {Spec.prorated_rent(rent, 0n, len) == 0n : Nat}

# LAW the prorated rent never exceeds the monthly rent, for any rent (paisa
# included) and any number of days: rounding half-up to whole rupees is
# capped at the rent (`Money.min(monthlyRent, ...)`)
law prorate_le_rent:
  for +rent: Nat
  for +days: Nat
  for +len: Nat
  Spec.LE(Spec.prorated_rent(rent, days, len), rent)

# LAW the prorated rent is at most 50 paisa above the exact pro-rata share
# rent * days / len: len * bill <= rent * days + 50 * len
law prorate_near_exact_upper:
  for +rent: Nat
  for +days: Nat
  for +len: Nat
  Spec.LE(Nat.mul(len, Spec.prorated_rent(rent, days, len)), Nat.add(Nat.mul(rent, days), Nat.mul(50n, len)))

# LAW ... and, for days <= len, at most 50 paisa below it:
# rent * days <= len * (bill + 50)
law prorate_near_exact_lower:
  for +rent: Nat
  for +days: Nat
  for +len: Nat
  for +part: Spec.LE(days, len)
  Spec.LE(Nat.mul(rent, days), Nat.mul(len, Nat.add(Spec.prorated_rent(rent, days, len), 50n)))

# LAW (a regression vector) a rent with paisa is no longer billed above
# itself: Rs 1.99 for 30 days of a 31-day month rounds to Rs 2.00 and is
# capped at Rs 1.99 (it was billed Rs 2.00 before the cap was added)
law prorate_paisa_rent_capped:
  {Spec.prorated_rent(199n, 30n, 31n) == 199n : Nat}

# LAW SQL app.prorated_rent prices the billing-start month exactly as Dart
# RentMath.proratedRent prices the days from billing_starts_on (day `start`
# of a `dim`-day month) to the month's last day: dim - start + 1 days
law prorate_sql_matches_dart:
  for +rent: Nat
  for +start: Nat
  for +dim: Nat
  for  from: Spec.LE(1n, start)
  for  upto: Spec.LE(start, dim)
  {Spec.prorated_rent_sql(rent, True{}, start, dim) == Spec.prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim) : Nat}

# The ledger against Dart. Spec.billed_rent_sql is the rent that
# private.sync_lease_billing bills for a month (public.change_rent re-prices
# with it, and public.end_lease bills the move-out month with it).
# Spec.billed_rent is Dart's RentMath.billedRent.

# LAW Dart's RentMath.billedRent equals the rent the ledger bills, for every
# month from the billing-start month on (before = False{}), both values of
# prorate_first_month, and every billing-start day 1..dim. This includes the
# move-out month, which both bill in full
law billed_rent_matches_ledger:
  for +rent: Nat
  for +prorate: Bool
  for +first: Bool
  for +start: Nat
  for +dim: Nat
  for  from: Spec.LE(1n, start)
  for  upto: Spec.LE(start, dim)
  {Spec.billed_rent(rent, prorate, False{}, first, start, dim) == Spec.billed_rent_sql(rent, prorate, first, start, dim) : Nat}

# LAW Dart bills nothing for a month before the billing-start month (the
# ledger's month walk starts at the billing-start month)
law billed_rent_before_start:
  for +rent: Nat
  for +prorate: Bool
  for +first: Bool
  for +start: Nat
  for +dim: Nat
  {Spec.billed_rent(rent, prorate, True{}, first, start, dim) == 0n : Nat}

# LAW with prorate_first_month set, the ledger bills the billing-start month
# exactly as RentMath.proratedRent prices an occupancy that starts on
# billing_starts_on (day `start`) and is open-ended or ends on or after the
# month's last day
law billed_first_month_matches_dart:
  for +rent: Nat
  for +start: Nat
  for +dim: Nat
  for  from: Spec.LE(1n, start)
  for  upto: Spec.LE(start, dim)
  {Spec.billed_rent_sql(rent, True{}, True{}, start, dim) == Spec.prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim) : Nat}

# LAW the ledger bills every month after the billing-start month at the full
# rent, with either value of prorate_first_month and whatever part of the
# month the tenant occupies (so a move-out month too)
law billed_later_month_full:
  for +rent: Nat
  for +prorate: Bool
  for +start: Nat
  for +dim: Nat
  {Spec.billed_rent_sql(rent, prorate, False{}, start, dim) == rent : Nat}

# 4. Daily late fee with a cap
# ----------------------------
# rate: perDay, cap: the optional cap, overdue: the overdue amount,
# days / d1 / d2: days late, grace: the grace period in days, top: the
# largest fee ever charged (LateFeePolicy.maxFee; 99999999999900 paisa in the
# code, a parameter here).

# LAW nothing overdue, no fee
law late_fee_nothing_overdue:
  for +rate: Nat
  for  cap: Maybe<&2, Nat>
  for +days: Nat
  for +grace: Nat
  for +top: Nat
  {Spec.daily_late_fee(rate, cap, 0n, days, grace, top) == 0n : Nat}

# LAW no fee within the grace period (daysLate <= graceDays)
law late_fee_in_grace:
  for +rate: Nat
  for  cap: Maybe<&2, Nat>
  for  overdue: Nat
  for +days: Nat
  for +grace: Nat
  for +top: Nat
  for  within: Spec.LE(days, grace)
  {Spec.daily_late_fee(rate, cap, overdue, days, grace, top) == 0n : Nat}

# LAW the fee is monotone (non-decreasing) in daysLate, across the end of
# the grace period, the clamp to maxFee, the rounding to whole rupees and
# the cap
law late_fee_monotone:
  for +rate: Nat
  for +cap: Maybe<&2, Nat>
  for  overdue: Nat
  for +d1: Nat
  for +d2: Nat
  for +grace: Nat
  for +top: Nat
  for +later: Spec.LE(d1, d2)
  Spec.LE(Spec.daily_late_fee(rate, cap, overdue, d1, grace, top), Spec.daily_late_fee(rate, cap, overdue, d2, grace, top))

# LAW the fee never exceeds its cap, for any cap (paisa included): the fee
# is rounded to whole rupees first and capped afterwards
law late_fee_le_cap:
  for +rate: Nat
  for +cap: Nat
  for  overdue: Nat
  for +days: Nat
  for +grace: Nat
  for +top: Nat
  Spec.LE(Spec.daily_late_fee(rate, Some{cap}, overdue, days, grace, top), cap)

# LAW the fee never exceeds maxFee, capped or not
law late_fee_le_max:
  for +rate: Nat
  for +cap: Maybe<&2, Nat>
  for  overdue: Nat
  for +days: Nat
  for +grace: Nat
  for +top: Nat
  Spec.LE(Spec.daily_late_fee(rate, cap, overdue, days, grace, top), top)

# LAW (a regression vector) Rs 1.00 a day, capped at Rs 2.50, 8 days late
# after a 5-day grace period, is charged Rs 2.50 (it was charged Rs 3.00
# before rounding moved ahead of the cap), for any maxFee of at least Rs 8
law late_fee_paisa_cap_capped:
  for +k: Nat
  {Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, Nat.add(800n, k)) == 250n : Nat}

# LAW SQL app.late_fee_amount (daily) charges exactly what Dart
# LateFeePolicy.feeFor does, when maxFee is a whole number of rupees
# (k rupees; the code's is 999999999999)
law late_fee_sql_matches_dart:
  for +rate: Nat
  for +cap: Maybe<&2, Nat>
  for  overdue: Nat
  for +days: Nat
  for +grace: Nat
  for +k: Nat
  {Spec.daily_late_fee_sql(rate, cap, overdue, days, grace, Nat.mul(k, 100n)) == Spec.daily_late_fee(rate, cap, overdue, days, grace, Nat.mul(k, 100n)) : Nat}
