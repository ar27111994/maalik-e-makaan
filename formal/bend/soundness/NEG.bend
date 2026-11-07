# Soundness audit: every hypothesis of a law is needed. For each one, a
# concrete input where that hypothesis fails (and the others hold) and the
# law's conclusion is false, checked by evaluating the models. So no law
# carries a hypothesis it could do without, which would make it weaker than
# it reads. (split_fair's `i < n` and round_half_lower's `b > 0` were dropped
# from the laws for this reason.)
import Base
import ../SPEC.bend as Spec

# le_is_base_le needs h: without it, 1 <= 0 would be True in Base
def n_le_is_base_le() -> {Nat.is_le(1n, 0n) == False{} : Bool}:
  {==}

# base_le_is_le needs e: 1 <= 0 has no proof
def n_base_le_is_le(h: Spec.LE(1n, 0n)) -> Empty:
  h

# fifo_leftover_settles_all needs a leftover: 120 against [100, 50] leaves
# nothing over and charge 1 gets 20 of its 50
def n_fifo_leftover_rest() -> {Spec.unallocated([100n, 50n], 120n) == 0n : Nat}:
  {==}
def n_fifo_leftover() -> {Spec.alloc([100n, 50n], 120n) == [100n, 20n] : List<&2, Nat>}:
  {==}

# fifo_order needs j < i: with i = 0 (paid 100) and j = 1, charge 1 got 20
# of its 50
def n_fifo_order_before() -> {Nat.is_eq(Spec.at(Spec.alloc([100n, 50n], 120n), 1n), 50n) == False{} : Bool}:
  {==}

# fifo_order needs charge i to be paid: 30 against [100, 50], i = 1 gets
# nothing and j = 0 got 30 of 100
def n_fifo_order_paid() -> {Spec.at(Spec.alloc([100n, 50n], 30n), 1n) == 0n : Nat}:
  {==}
def n_fifo_order_paid2() -> {Nat.is_eq(Spec.at(Spec.alloc([100n, 50n], 30n), 0n), 100n) == False{} : Bool}:
  {==}

# fifo_rows_positive needs i < length: 100 against [100, 50] writes one row
def n_fifo_rows_row() -> {Spec.alloc([100n, 50n], 100n) == [100n] : List<&2, Nat>}:
  {==}

# fifo_rows_positive needs an open charge: a charge with nothing outstanding
# gets 0
def n_fifo_rows_open() -> {Spec.alloc([0n, 5n], 3n) == [0n, 3n] : List<&2, Nat>}:
  {==}

# split_sum needs n > 0: 5 paisa in 0 parts sum to 0
def n_split_sum() -> {Spec.sum(Spec.split_evenly(5n, 0n)) == 0n : Nat}:
  {==}

# split_fair needs j < n: part 0 of 5 in 3 is 2, "part 3" is 0
def n_split_fair() -> {Nat.is_le(Spec.at(Spec.split_evenly(5n, 3n), 0n), Nat.add(Spec.at(Spec.split_evenly(5n, 3n), 3n), 1n)) == False{} : Bool}:
  {==}

# round_half_upper needs b > 0: 2a + 0 < 0 fails
def n_round_half_upper() -> {Nat.is_le(1n+Nat.add(Nat.mul(2n, 1n), 0n), Nat.mul(Nat.mul(2n, 0n), Nat.add(Spec.round_half(1n, 0n), 1n))) == False{} : Bool}:
  {==}

# half_up_agrees needs d > 0: Base's division by 0 makes them differ
def n_half_up_agrees() -> {Nat.is_eq(Spec.half_up(1n, 0n), Spec.round_half(1n, 0n)) == False{} : Bool}:
  {==}

# prorate_no_days needs len > 0: 0 of 0 days is the full month
def n_prorate_no_days() -> {Spec.prorated_rent(5n, 0n, 0n) == 5n : Nat}:
  {==}

# prorate_near_exact_lower needs days <= len: 6 "days" of a 3-day month at
# Rs 1.00 is capped at Rs 1.00, far below the Rs 2.00 pro rata
def n_prorate_lower() -> {Nat.is_le(Nat.mul(100n, 6n), Nat.mul(3n, Nat.add(Spec.prorated_rent(100n, 6n, 3n), 50n))) == False{} : Bool}:
  {==}

# prorate_sql_matches_dart, billed_rent_matches_ledger and
# billed_first_month_matches_dart need 1 <= start: start 0 of a 3-day month
# at Rs 0.10
def n_prorate_sql_from() -> {Nat.is_eq(Spec.prorated_rent_sql(10n, True{}, 0n, 3n), Spec.prorated_rent(10n, Nat.add(Nat.sub(3n, 0n), 1n), 3n)) == False{} : Bool}:
  {==}
def n_billed_from() -> {Nat.is_eq(Spec.billed_rent(10n, True{}, False{}, True{}, 0n, 3n), Spec.billed_rent_sql(10n, True{}, True{}, 0n, 3n)) == False{} : Bool}:
  {==}

# ... and start <= dim: start 1 of a 0-day "month" at Rs 5.00
def n_prorate_sql_upto() -> {Nat.is_eq(Spec.prorated_rent_sql(500n, True{}, 1n, 0n), Spec.prorated_rent(500n, Nat.add(Nat.sub(0n, 1n), 1n), 0n)) == False{} : Bool}:
  {==}
def n_billed_upto() -> {Nat.is_eq(Spec.billed_rent(500n, True{}, False{}, True{}, 1n, 0n), Spec.billed_rent_sql(500n, True{}, True{}, 1n, 0n)) == False{} : Bool}:
  {==}

# late_fee_in_grace needs days <= grace: 8 days late after 5 is Rs 8.00
def n_late_fee_in_grace() -> {Spec.daily_late_fee(100n, None{}, 1n, 8n, 5n, 1000n) == 800n : Nat}:
  {==}

# late_fee_monotone needs d1 <= d2: 8 days cost more than 6
def n_late_fee_monotone() -> {Nat.is_le(Spec.daily_late_fee(100n, None{}, 1n, 8n, 5n, 1000n), Spec.daily_late_fee(100n, None{}, 1n, 6n, 5n, 1000n)) == False{} : Bool}:
  {==}

# late_fee_sql_matches_dart needs maxFee in whole rupees: with maxFee
# Rs 1.49 and Rs 1.51 for 1 day, SQL charges Rs 1.49 and Dart Rs 1.00
def n_late_fee_sql() -> {(Spec.daily_late_fee_sql(151n, None{}, 1n, 1n, 0n, 149n), Spec.daily_late_fee(151n, None{}, 1n, 1n, 0n, 149n)) == (149n, 100n) : Nat & Nat}:
  {==}
