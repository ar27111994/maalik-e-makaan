/-
Payment allocation: packages/mm_core/lib/src/ledger/allocation.dart
(`planFifoAllocation`) against SQL `private.allocate_payment`
(supabase/migrations/20261103193658_ledger.sql, not redefined later), which
`record_payment`, `apply_deposit` and `private.apply_lease_credit` use.

Abstractions:
- A charge id is a UUID. The model orders ids by their 128-bit value. For
  the canonical lower-case UUID text both sides use, Dart's
  `String.compareTo` and PostgreSQL's `uuid` comparison give that order.
- A due date is its order key (`year * 10000 + month * 100 + day`).
- Amounts are `Int` paisa. Only open charges are passed in: `OpenCharge`
  throws unless `outstanding > 0`, and the SQL selects
  `c.outstanding > 0 and c.voided_at is null` of the payment's lease.
-/
import Maalik.Rounding

namespace Maalik

/-- allocation.dart `OpenCharge`. -/
structure OpenCharge where
  id : Nat
  dueKey : Nat
  outstanding : Int
  isSecurityDeposit : Bool
  deriving DecidableEq, Repr

/-- Dart `rank`: `chosenChargeIds.indexOf(id)`, or `chosenChargeIds.length`
when not chosen (`List.idxOf` returns the length for a missing element). -/
def dartRank (chosen : List Nat) (c : OpenCharge) : Nat :=
  chosen.idxOf c.id

/-- SQL `coalesce(array_position(p_charge_ids, c.id), 2147483647)`:
1-based, and a NULL array (no choice) behaves like an empty one. -/
def sqlRank (chosen : List Nat) (c : OpenCharge) : Nat :=
  if c.id ∈ chosen then chosen.idxOf c.id + 1 else 2147483647

/-- The sort order: by rank, then due date, then id (Dart comparator;
SQL `order by <rank>, c.due_date, c.id`). -/
def chargeLe (rank : OpenCharge → Nat) (a b : OpenCharge) : Bool :=
  decide (rank a < rank b) ||
    (rank a == rank b &&
      (decide (a.dueKey < b.dueKey) || (a.dueKey == b.dueKey && decide (a.id ≤ b.id))))

/-- The charges a payment may pay, in the order it pays them. A deposit
adjustment never pays the security deposit itself. -/
def orderCharges (rank : OpenCharge → Nat) (charges : List OpenCharge) (deposit : Bool) :
    List OpenCharge :=
  (charges.filter fun c => !(deposit && c.isSecurityDeposit)).mergeSort (chargeLe rank)

/-- The Dart loop: `if (remaining.isZero) break; applied = min(remaining,
outstanding); remaining -= applied`. Returns the allocations and the
unallocated rest. -/
def dartLoop : Int → List OpenCharge → List (Nat × Int) × Int
  | remaining, [] => ([], remaining)
  | remaining, c :: cs =>
    if remaining = 0 then ([], remaining)
    else
      let applied := min remaining c.outstanding
      let rest := dartLoop (remaining - applied) cs
      ((c.id, applied) :: rest.1, rest.2)

/-- The SQL loop: `exit when v_remaining <= 0; v_apply := least(v_remaining,
v_charge.outstanding)`; the function also returns early when the payment's
unallocated amount is `<= 0`. -/
def sqlLoop : Int → List OpenCharge → List (Nat × Int) × Int
  | remaining, [] => ([], remaining)
  | remaining, c :: cs =>
    if remaining ≤ 0 then ([], remaining)
    else
      let applied := min remaining c.outstanding
      let rest := sqlLoop (remaining - applied) cs
      ((c.id, applied) :: rest.1, rest.2)

/-- `planFifoAllocation(payment, charges, chosenChargeIds:, depositAdjustment:)`. -/
def planFifo (payment : Int) (charges : List OpenCharge) (chosen : List Nat) (deposit : Bool) :
    List (Nat × Int) × Int :=
  dartLoop payment (orderCharges (dartRank chosen) charges deposit)

/-- `private.allocate_payment(p_payment_id, p_charge_ids)`: the allocations
it inserts (summed per charge by `on conflict ... do update`, but each charge
is visited once) and the `v_remaining` it leaves unallocated. -/
def sqlAllocate (payment : Int) (charges : List OpenCharge) (chosen : List Nat) (deposit : Bool) :
    List (Nat × Int) × Int :=
  sqlLoop payment (orderCharges (sqlRank chosen) charges deposit)

/-- The i-th allocation pays the i-th charge in order, a positive amount no
larger than what it owes. -/
def Pays : List (Nat × Int) → List OpenCharge → Prop
  | [], _ => True
  | a :: as, c :: cs => a.1 = c.id ∧ 0 < a.2 ∧ a.2 ≤ c.outstanding ∧ Pays as cs
  | _ :: _, [] => False

/-- Every allocation but the last pays its charge in full. -/
def FullBeforeLast : List (Nat × Int) → List OpenCharge → Prop
  | a :: b :: rest, c :: cs => a.2 = c.outstanding ∧ FullBeforeLast (b :: rest) cs
  | _, _ => True

def allOpen (cs : List OpenCharge) : Prop := ∀ c ∈ cs, 0 < c.outstanding

section Loop

theorem dartLoop_zero (cs : List OpenCharge) : dartLoop 0 cs = ([], 0) := by
  cases cs <;> simp [dartLoop]

theorem dartLoop_conserves (remaining : Int) (cs : List OpenCharge) :
    ((dartLoop remaining cs).1.map (·.2)).sum + (dartLoop remaining cs).2 = remaining := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop]
  | cons c cs ih =>
    simp only [dartLoop]
    split
    · simp
    · -- Independent of how much is applied: what is applied plus what the
      -- rest of the loop allocates and leaves is what there was.
      simp only [List.map_cons, List.sum_cons]
      rw [Int.add_assoc, ih]
      omega

theorem dartLoop_rest (remaining : Int) (cs : List OpenCharge) (ho : allOpen cs)
    (hr : 0 ≤ remaining) : 0 ≤ (dartLoop remaining cs).2 ∧ (dartLoop remaining cs).2 ≤ remaining := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop]; omega
  | cons c cs ih =>
    have hc := ho c (by simp)
    simp only [dartLoop]
    split
    · simp; omega
    · have := ih (remaining - min remaining c.outstanding) (fun d hd => ho d (by simp [hd]))
        (by omega)
      simp only; omega

theorem dartLoop_pays (remaining : Int) (cs : List OpenCharge) (ho : allOpen cs)
    (hr : 0 ≤ remaining) : Pays (dartLoop remaining cs).1 cs := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop, Pays]
  | cons c cs ih =>
    have hc := ho c (by simp)
    simp only [dartLoop]
    split
    · simp [Pays]
    · exact ⟨rfl, by omega, by omega, ih _ (fun d hd => ho d (by simp [hd])) (by omega)⟩

theorem dartLoop_full (remaining : Int) (cs : List OpenCharge) :
    FullBeforeLast (dartLoop remaining cs).1 cs := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop, FullBeforeLast]
  | cons c cs ih =>
    simp only [dartLoop]
    split
    · simp [FullBeforeLast]
    · have ihr := ih (remaining - min remaining c.outstanding)
      by_cases hz : remaining - min remaining c.outstanding = 0
      · rw [hz, dartLoop_zero]; simp [FullBeforeLast]
      · generalize hrest : dartLoop (remaining - min remaining c.outstanding) cs = rest at ihr
        rcases rest with ⟨as, u⟩
        cases as with
        | nil => simp [FullBeforeLast]
        | cons b bs => exact ⟨by simp only; omega, ihr⟩

/-- A payment that leaves credit has paid every charge in full. -/
theorem dartLoop_credit (remaining : Int) (cs : List OpenCharge)
    (hpos : 0 < (dartLoop remaining cs).2) :
    (dartLoop remaining cs).1.length = cs.length ∧
      ((dartLoop remaining cs).1.map (·.2)).sum = (cs.map (·.outstanding)).sum := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop]
  | cons c cs ih =>
    simp only [dartLoop] at hpos ⊢
    split at hpos
    · rename_i h; subst h; simp at hpos
    · rename_i h
      rw [ite_f h]
      have hz : remaining - min remaining c.outstanding ≠ 0 := by
        intro hz; rw [hz, dartLoop_zero] at hpos; simp at hpos
      have := ih (remaining - min remaining c.outstanding) hpos
      simp only [List.length_cons, List.map_cons, List.sum_cons]
      omega

theorem dartLoop_eq_sqlLoop (remaining : Int) (cs : List OpenCharge) (hr : 0 ≤ remaining) :
    dartLoop remaining cs = sqlLoop remaining cs := by
  induction cs generalizing remaining with
  | nil => simp [dartLoop, sqlLoop]
  | cons c cs ih =>
    simp only [dartLoop, sqlLoop]
    by_cases h : remaining = 0
    · subst h; simp
    · rw [ite_f h, ite_f (by omega), ih _ (by omega)]

end Loop

/-! ## The order -/

theorem rank_iff {chosen : List Nat} (hlen : chosen.length < 2147483646) (a b : OpenCharge) :
    (dartRank chosen a < dartRank chosen b ↔ sqlRank chosen a < sqlRank chosen b) ∧
      (dartRank chosen a = dartRank chosen b ↔ sqlRank chosen a = sqlRank chosen b) := by
  simp only [dartRank, sqlRank]
  by_cases ha : a.id ∈ chosen <;> by_cases hb : b.id ∈ chosen
  · rw [ite_t ha, ite_t hb]; omega
  · have := List.idxOf_lt_length_iff.mpr ha
    rw [ite_t ha, ite_f hb, List.idxOf_eq_length hb]; omega
  · have := List.idxOf_lt_length_iff.mpr hb
    rw [ite_f ha, ite_t hb, List.idxOf_eq_length ha]; omega
  · rw [ite_f ha, ite_f hb, List.idxOf_eq_length ha, List.idxOf_eq_length hb]; omega

/-- With fewer than 2^31 - 2 chosen ids, the Dart and SQL ranks sort alike. -/
theorem chargeLe_dart_eq_sql {chosen : List Nat} (hlen : chosen.length < 2147483646) :
    chargeLe (dartRank chosen) = chargeLe (sqlRank chosen) := by
  funext a b
  have ⟨h1, h2⟩ := rank_iff hlen a b
  have e1 : decide (dartRank chosen a < dartRank chosen b) =
      decide (sqlRank chosen a < sqlRank chosen b) := decide_eq_decide.mpr h1
  have e2 : (dartRank chosen a == dartRank chosen b) = (sqlRank chosen a == sqlRank chosen b) := by
    rw [Bool.eq_iff_iff]; simp only [beq_iff_eq]; exact h2
  simp only [chargeLe]
  rw [e1, e2]

theorem chargeLe_trans (rank : OpenCharge → Nat) (a b c : OpenCharge) :
    chargeLe rank a b = true → chargeLe rank b c = true → chargeLe rank a c = true := by
  simp only [chargeLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
  omega

theorem chargeLe_total (rank : OpenCharge → Nat) (a b : OpenCharge) :
    (chargeLe rank a b || chargeLe rank b a) = true := by
  simp only [chargeLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
  omega

/-- The charges are paid in order: rank, then due date, then id. -/
theorem orderCharges_sorted (rank : OpenCharge → Nat) (charges : List OpenCharge) (deposit : Bool) :
    (orderCharges rank charges deposit).Pairwise fun a b => chargeLe rank a b = true :=
  List.pairwise_mergeSort (chargeLe_trans rank) (chargeLe_total rank) _

/-- Every open charge is considered (once), except the deposit itself in a
deposit adjustment. -/
theorem orderCharges_mem (rank : OpenCharge → Nat) (charges : List OpenCharge) (deposit : Bool)
    (c : OpenCharge) :
    c ∈ orderCharges rank charges deposit ↔ c ∈ charges ∧ !(deposit && c.isSecurityDeposit) := by
  simp [orderCharges, List.mem_mergeSort, List.mem_filter]

theorem orderCharges_open {rank : OpenCharge → Nat} {charges : List OpenCharge} {deposit : Bool}
    (ho : allOpen charges) : allOpen (orderCharges rank charges deposit) :=
  fun c hc => ho c ((orderCharges_mem rank charges deposit c).mp hc).1

/-! ## planFifoAllocation -/

section Plan
variable (payment : Int) (charges : List OpenCharge) (chosen : List Nat) (deposit : Bool)

/-- The allocations and the credit add up to the payment. -/
theorem planFifo_conserves :
    ((planFifo payment charges chosen deposit).1.map (·.2)).sum +
      (planFifo payment charges chosen deposit).2 = payment :=
  dartLoop_conserves _ _

/-- The credit left over is between nothing and the whole payment. -/
theorem planFifo_credit_bounds (ho : allOpen charges) (hp : 0 ≤ payment) :
    0 ≤ (planFifo payment charges chosen deposit).2 ∧
      (planFifo payment charges chosen deposit).2 ≤ payment :=
  dartLoop_rest _ _ (orderCharges_open ho) hp

/-- Never overpays, and pays the charges in order: the i-th allocation pays
the i-th charge of `orderCharges`, a positive amount at most its outstanding. -/
theorem planFifo_pays (ho : allOpen charges) (hp : 0 ≤ payment) :
    Pays (planFifo payment charges chosen deposit).1
      (orderCharges (dartRank chosen) charges deposit) :=
  dartLoop_pays _ _ (orderCharges_open ho) hp

/-- Oldest first: only the last allocation can leave a charge part-paid. -/
theorem planFifo_full_before_last :
    FullBeforeLast (planFifo payment charges chosen deposit).1
      (orderCharges (dartRank chosen) charges deposit) :=
  dartLoop_full _ _

/-- Credit is left only after every payable charge is paid in full. -/
theorem planFifo_credit_after_all (h : 0 < (planFifo payment charges chosen deposit).2) :
    ((planFifo payment charges chosen deposit).1.map (·.2)).sum =
      ((orderCharges (dartRank chosen) charges deposit).map (·.outstanding)).sum :=
  (dartLoop_credit _ _ h).2

/-- A deposit adjustment never pays the security deposit. -/
theorem planFifo_no_deposit (c : OpenCharge) (hc : c ∈ orderCharges (dartRank chosen) charges true) :
    c.isSecurityDeposit = false := by
  have := ((orderCharges_mem _ charges true c).mp hc).2
  simpa using this

/-- The Dart preview is exactly what `private.allocate_payment` does. -/
theorem planFifo_eq_sql (hp : 0 ≤ payment) (hlen : chosen.length < 2147483646) :
    planFifo payment charges chosen deposit = sqlAllocate payment charges chosen deposit := by
  simp only [planFifo, sqlAllocate]
  rw [show orderCharges (dartRank chosen) charges deposit = orderCharges (sqlRank chosen) charges deposit
      by simp only [orderCharges, chargeLe_dart_eq_sql hlen]]
  exact dartLoop_eq_sqlLoop _ _ hp

end Plan

end Maalik
