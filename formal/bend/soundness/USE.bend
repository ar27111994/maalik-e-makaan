# Soundness audit: every law, applied to concrete inputs with concrete
# proofs of its hypotheses. If a law's hypotheses could never hold together,
# no such call would type-check, so this shows that no law is vacuous. Each
# call also yields a concrete fact about the code's figures.
import Base
import ../SPEC.bend as Spec
import ../LAWS.bend as Laws
import ../PROOF.bend as Proof

def u_le_is_base_le() -> {Nat.is_le(3n, 5n) == True{} : Bool}:
  Laws.le_is_base_le(3n, 5n, Unit{})

def u_base_le_is_le() -> Spec.LE(3n, 5n):
  Laws.base_le_is_le(3n, 5n, {==})

# FIFO: Rs 1.20 against charges of Rs 1.00 and Rs 0.50
def u_fifo_conserves() -> {Nat.add(Spec.sum(Spec.alloc([100n, 50n], 120n)), Spec.unallocated([100n, 50n], 120n)) == 120n : Nat}:
  Laws.fifo_conserves([100n, 50n], 120n)

def u_fifo_allocated_le_payment() -> Spec.LE(Spec.sum(Spec.alloc([100n, 50n], 120n)), 120n):
  Laws.fifo_allocated_le_payment([100n, 50n], 120n)

def u_fifo_bounded() -> Spec.LE(Spec.at(Spec.alloc([100n, 50n], 120n), 1n), Spec.at([100n, 50n], 1n)):
  Laws.fifo_bounded([100n, 50n], 120n, 1n)

# Rs 2.00 leaves Rs 0.50 over, so both charges are settled
def u_fifo_leftover_settles_all() -> {Spec.alloc([100n, 50n], 200n) == [100n, 50n] : List<&2, Nat>}:
  Laws.fifo_leftover_settles_all([100n, 50n], 200n, Unit{})

# charge 1 receives Rs 0.20, so charge 0 is settled
def u_fifo_order() -> {Spec.at(Spec.alloc([100n, 50n], 120n), 0n) == Spec.at([100n, 50n], 0n) : Nat}:
  Laws.fifo_order([100n, 50n], 120n, 1n, 0n, Unit{}, Unit{})

def u_fifo_rows_positive() -> Spec.LT(0n, Spec.at(Spec.alloc([100n, 50n], 120n), 1n)):
  Laws.fifo_rows_positive([100n, 50n], 120n, 1n, Unit{}, Unit{})

def u_fifo_two_payments() -> Spec.LE(Nat.add(Spec.at(Spec.alloc([100n, 50n], 120n), 1n), Spec.at(Spec.alloc(Spec.settle([100n, 50n], Spec.alloc([100n, 50n], 120n)), 40n), 1n)), Spec.at([100n, 50n], 1n)):
  Laws.fifo_two_payments([100n, 50n], 120n, 40n, 1n)

def u_fifo_payments_conserve() -> {Nat.add(Spec.paid_to([120n, 40n], [100n, 50n], 1n), Spec.at(Spec.outstanding([120n, 40n], [100n, 50n]), 1n)) == Spec.at([100n, 50n], 1n) : Nat}:
  Laws.fifo_payments_conserve([120n, 40n], [100n, 50n], 1n)

def u_fifo_payments_never_overpay() -> Spec.LE(Spec.paid_to([120n, 40n], [100n, 50n], 1n), Spec.at([100n, 50n], 1n)):
  Laws.fifo_payments_never_overpay([120n, 40n], [100n, 50n], 1n)

# Even split of 10 paisa in 3 parts
def u_split_count() -> {List.length(&2, Nat, Spec.split_evenly(10n, 3n)) == 3n : Nat}:
  Laws.split_count(10n, 3n)

def u_split_sum() -> {Spec.sum(Spec.split_evenly(10n, 3n)) == 10n : Nat}:
  Laws.split_sum(10n, 3n, Unit{})

def u_split_fair() -> Spec.LE(Spec.at(Spec.split_evenly(10n, 3n), 0n), Nat.add(Spec.at(Spec.split_evenly(10n, 3n), 2n), 1n)):
  Laws.split_fair(10n, 3n, 0n, 2n, Unit{})

# Half-up division of 7 by 2
def u_round_half_lower() -> Spec.LE(Nat.mul(Nat.mul(2n, 2n), Spec.round_half(7n, 2n)), Nat.add(Nat.mul(2n, 7n), 2n)):
  Laws.round_half_lower(7n, 2n)

def u_round_half_upper() -> Spec.LT(Nat.add(Nat.mul(2n, 7n), 2n), Nat.mul(Nat.mul(2n, 2n), Nat.add(Spec.round_half(7n, 2n), 1n))):
  Laws.round_half_upper(7n, 2n, Unit{})

def u_half_up_agrees() -> {Spec.half_up(7n, 2n) == Spec.round_half(7n, 2n) : Nat}:
  Laws.half_up_agrees(7n, 2n, Unit{})

# Proration of Rs 3.00 in a 3-day month
def u_prorate_full_month() -> {Spec.prorated_rent(300n, 3n, 3n) == 300n : Nat}:
  Laws.prorate_full_month(300n, 3n)

def u_prorate_no_days() -> {Spec.prorated_rent(300n, 0n, 3n) == 0n : Nat}:
  Laws.prorate_no_days(300n, 3n, Unit{})

def u_prorate_le_rent() -> Spec.LE(Spec.prorated_rent(199n, 2n, 3n), 199n):
  Laws.prorate_le_rent(199n, 2n, 3n)

def u_prorate_near_exact_upper() -> Spec.LE(Nat.mul(3n, Spec.prorated_rent(300n, 2n, 3n)), Nat.add(Nat.mul(300n, 2n), Nat.mul(50n, 3n))):
  Laws.prorate_near_exact_upper(300n, 2n, 3n)

def u_prorate_near_exact_lower() -> Spec.LE(Nat.mul(300n, 2n), Nat.mul(3n, Nat.add(Spec.prorated_rent(300n, 2n, 3n), 50n))):
  Laws.prorate_near_exact_lower(300n, 2n, 3n, Unit{})

def u_prorate_paisa_rent_capped() -> {Spec.prorated_rent(199n, 30n, 31n) == 199n : Nat}:
  Laws.prorate_paisa_rent_capped()

def u_prorate_sql_matches_dart() -> {Spec.prorated_rent_sql(300n, True{}, 2n, 3n) == Spec.prorated_rent(300n, Nat.add(Nat.sub(3n, 2n), 1n), 3n) : Nat}:
  Laws.prorate_sql_matches_dart(300n, 2n, 3n, Unit{}, Unit{})

def u_billed_rent_matches_ledger() -> {Spec.billed_rent(300n, True{}, False{}, True{}, 2n, 3n) == Spec.billed_rent_sql(300n, True{}, True{}, 2n, 3n) : Nat}:
  Laws.billed_rent_matches_ledger(300n, True{}, True{}, 2n, 3n, Unit{}, Unit{})

def u_billed_rent_before_start() -> {Spec.billed_rent(300n, True{}, True{}, False{}, 2n, 3n) == 0n : Nat}:
  Laws.billed_rent_before_start(300n, True{}, False{}, 2n, 3n)

def u_billed_first_month_matches_dart() -> {Spec.billed_rent_sql(300n, True{}, True{}, 2n, 3n) == Spec.prorated_rent(300n, Nat.add(Nat.sub(3n, 2n), 1n), 3n) : Nat}:
  Laws.billed_first_month_matches_dart(300n, 2n, 3n, Unit{}, Unit{})

def u_billed_later_month_full() -> {Spec.billed_rent_sql(300n, True{}, False{}, 2n, 3n) == 300n : Nat}:
  Laws.billed_later_month_full(300n, True{}, 2n, 3n)

# Daily late fee: Rs 1.00 a day, cap Rs 2.50, grace 5 days, maxFee Rs 10.00
def u_late_fee_nothing_overdue() -> {Spec.daily_late_fee(100n, Some{250n}, 0n, 8n, 5n, 1000n) == 0n : Nat}:
  Laws.late_fee_nothing_overdue(100n, Some{250n}, 8n, 5n, 1000n)

def u_late_fee_in_grace() -> {Spec.daily_late_fee(100n, Some{250n}, 1n, 4n, 5n, 1000n) == 0n : Nat}:
  Laws.late_fee_in_grace(100n, Some{250n}, 1n, 4n, 5n, 1000n, Unit{})

def u_late_fee_monotone() -> Spec.LE(Spec.daily_late_fee(100n, Some{250n}, 1n, 6n, 5n, 1000n), Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, 1000n)):
  Laws.late_fee_monotone(100n, Some{250n}, 1n, 6n, 8n, 5n, 1000n, Unit{})

def u_late_fee_le_cap() -> Spec.LE(Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, 1000n), 250n):
  Laws.late_fee_le_cap(100n, 250n, 1n, 8n, 5n, 1000n)

def u_late_fee_le_max() -> Spec.LE(Spec.daily_late_fee(100n, None{}, 1n, 20n, 5n, 1000n), 1000n):
  Laws.late_fee_le_max(100n, None{}, 1n, 20n, 5n, 1000n)

def u_late_fee_paisa_cap_capped() -> {Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, Nat.add(800n, 200n)) == 250n : Nat}:
  Laws.late_fee_paisa_cap_capped(200n)

def u_late_fee_sql_matches_dart() -> {Spec.daily_late_fee_sql(100n, Some{250n}, 1n, 8n, 5n, Nat.mul(10n, 100n)) == Spec.daily_late_fee(100n, Some{250n}, 1n, 8n, 5n, Nat.mul(10n, 100n)) : Nat}:
  Laws.late_fee_sql_matches_dart(100n, Some{250n}, 1n, 8n, 5n, 10n)
