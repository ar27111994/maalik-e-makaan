/-
The axioms behind the main theorems. run.sh elaborates this file and fails
unless every theorem depends only on `propext`, `Classical.choice` and
`Quot.sound` (no `sorryAx`, no `Lean.ofReduceBool` from `native_decide`).
-/
import Maalik

open Maalik

-- Rounding
#print axioms floor_spec
#print axioms ceiling_spec
#print axioms down_spec
#print axioms up_spec
#print axioms halfUp_spec
#print axioms halfEven_spec
#print axioms divideRounded_neg
#print axioms halfUp_eq_sqlRound
#print axioms double_round
#print axioms pgScaledRound_eq
-- Money
#print axioms multiplyToStep_halfUp
#print axioms multiplyToStep_within_step
#print axioms multiplyToStep_eq_sql
#print axioms roundToRupee_bounds
#print axioms roundToRupee_whole
#print axioms roundToRupee_min
#print axioms allocate_sum
#print axioms allocate_part
#print axioms allocateNat_largest_remainder
#print axioms splitEvenly_sum
#print axioms splitEvenly_close
-- Rent
#print axioms dueDate_eq_sql
#print axioms proratedRent_bounds
#print axioms proratedRent_whole_month
#print axioms proratedRent_started_before
#print axioms proratedRent_eq_sql
#print axioms pgProratedRent_eq
#print axioms billedRent_eq_sql
#print axioms billedRent_bounds
-- Late fees
#print axioms feeFor_zero
#print axioms feeFor_le_maxFee
#print axioms feeFor_le_cap
#print axioms feeFor_nonneg
#print axioms feeFor_mono
#print axioms feeFor_eq_sql
-- Allocation
#print axioms planFifo_conserves
#print axioms planFifo_credit_bounds
#print axioms planFifo_pays
#print axioms planFifo_full_before_last
#print axioms planFifo_credit_after_all
#print axioms planFifo_no_deposit
#print axioms orderCharges_sorted
#print axioms orderCharges_mem
#print axioms planFifo_eq_sql
