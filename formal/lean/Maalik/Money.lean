/-
Money arithmetic: packages/mm_core/lib/src/money/money.dart, `Money`.

An amount is an `Int` number of paisa (`Money.paisa`); 1 rupee = 100 paisa.
The Dart computes every product in `BigInt`, which `Int` models exactly;
`formal/smt` checks separately that each `int` the Dart keeps fits in 64
bits (Dart VM) and 53 bits (Dart on the web).
-/
import Maalik.Rounding

namespace Maalik

/-- `Money.paisaPerRupee`. -/
def paisaPerRupee : Int := 100

/-- `Money.maxValue.paisa`: the largest `numeric(14,2)` amount. -/
def maxPaisa : Int := 99999999999999

/-- `Money.multiply(numerator, denominator, mode)`. -/
def multiply (paisa numerator denominator : Int) (mode : RoundingMode := .halfUp) : Int :=
  divideRounded (paisa * numerator) denominator mode

/-- `Money.multiplyToStep(numerator, denominator, stepRupees:, mode:)`:
one rounding, straight to a multiple of `stepRupees` rupees. -/
def multiplyToStep (paisa numerator denominator : Int) (stepRupees : Int := 1)
    (mode : RoundingMode := .halfUp) : Int :=
  let step := stepRupees * paisaPerRupee
  divideRounded (paisa * numerator) (denominator * step) mode * step

/-- `Money.percentage(basisPoints, mode:)`. -/
def percentage (paisa basisPoints : Int) (mode : RoundingMode := .halfUp) : Int :=
  multiply paisa basisPoints 10000 mode

/-- `Money.roundToStep(stepRupees, mode:)`. -/
def roundToStep (paisa stepRupees : Int) (mode : RoundingMode := .halfUp) : Int :=
  let step := stepRupees * paisaPerRupee
  divideRounded paisa step mode * step

/-- `Money.roundToRupee(mode:)`. -/
def roundToRupee (paisa : Int) (mode : RoundingMode := .halfUp) : Int :=
  roundToStep paisa 1 mode

/-! ## multiplyToStep and roundToRupee bounds -/

/-- Half-up `multiplyToStep` is a whole number of steps (`st * 100` paisa)
within half a step of the exact `paisa * numerator / denominator`. -/
theorem multiplyToStep_halfUp {p num den st : Int} (hden : 0 < den) (hst : 0 < st) :
    let r := multiplyToStep p num den st .halfUp
    r % (st * 100) = 0 ∧ 2 * (r * den) - den * (st * 100) ≤ 2 * (p * num) ∧
      2 * (p * num) ≤ 2 * (r * den) + den * (st * 100) := by
  intro r
  have hD : 0 < den * (st * 100) := Int.mul_pos hden (by omega)
  have spec := halfUp_spec (n := p * num) hD
  simp only [r, multiplyToStep, paisaPerRupee]
  generalize divideRounded (p * num) (den * (st * 100)) .halfUp = q at spec ⊢
  have e : q * (st * 100) * den = den * (st * 100) * q := by grind
  refine ⟨Int.mul_emod_left q _, ?_, ?_⟩ <;>
    (by_cases h : 0 ≤ p * num
     · have := spec.1 h; omega
     · have := spec.2 (by omega); omega)

/-- In every rounding mode `multiplyToStep` is less than one step
(`st * 100` paisa) from the exact `paisa * numerator / denominator`. -/
theorem multiplyToStep_within_step {p num den st : Int} (hden : 0 < den) (hst : 0 < st)
    (mode : RoundingMode) :
    let r := multiplyToStep p num den st mode
    r % (st * 100) = 0 ∧ r * den - den * (st * 100) < p * num ∧
      p * num < r * den + den * (st * 100) := by
  intro r
  have hD : 0 < den * (st * 100) := Int.mul_pos hden (by omega)
  simp only [r, multiplyToStep, paisaPerRupee]
  refine ⟨Int.mul_emod_left _ _, ?_⟩
  have e : ∀ q : Int, q * (st * 100) * den = den * (st * 100) * q := by intro q; grind
  cases mode with
  | floor =>
    have hs := floor_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .floor); omega
  | ceiling =>
    have hs := ceiling_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .ceiling); omega
  | down =>
    have hs := down_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .down)
    by_cases h : 0 ≤ p * num
    · have := hs.1 h; omega
    · have := hs.2 (by omega); omega
  | up =>
    have hs := up_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .up)
    by_cases h : 0 ≤ p * num
    · have := hs.1 h; omega
    · have := hs.2 (by omega); omega
  | halfUp =>
    have hs := halfUp_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .halfUp)
    by_cases h : 0 ≤ p * num
    · have := hs.1 h; omega
    · have := hs.2 (by omega); omega
  | halfEven =>
    have hs := halfEven_spec (n := p * num) hD
    have he := e (divideRounded (p * num) (den * (st * 100)) .halfEven); omega

/-- Half-up `multiplyToStep` to whole rupees is SQL `round(p * num / den, 0)`
in rupees (`app.prorated_rent`, `app.late_fee_amount`). -/
theorem multiplyToStep_eq_sql {p num den : Int} (hden : 0 < den) :
    multiplyToStep p num den 1 .halfUp = 100 * sqlRound (p * num) (den * 100) := by
  simp only [multiplyToStep, paisaPerRupee]
  rw [show den * (1 * 100) = den * 100 by omega, halfUp_eq_sqlRound (by omega), Int.mul_comm]
  rfl

theorem roundToRupee_eq_sql (p : Int) : roundToRupee p .halfUp = 100 * sqlRound p 100 := by
  simp only [roundToRupee, roundToStep, paisaPerRupee]
  rw [show (1 : Int) * 100 = 100 by rfl, halfUp_eq_sqlRound (by omega), Int.mul_comm]

/-- `roundToRupee` gives whole rupees within half a rupee of the amount. -/
theorem roundToRupee_bounds (p : Int) :
    let r := roundToRupee p .halfUp
    r % 100 = 0 ∧ r - 50 ≤ p ∧ p ≤ r + 50 := by
  intro r
  have := multiplyToStep_halfUp (p := p) (num := 1) (den := 1) (st := 1) (by omega) (by omega)
  have e : r = multiplyToStep p 1 1 1 .halfUp := by
    simp only [r, roundToRupee, roundToStep, multiplyToStep, paisaPerRupee, Int.mul_one, Int.one_mul]
  rw [e]
  simp only [Int.mul_one, Int.one_mul] at this
  omega

/-- Whole rupees are left unchanged. -/
theorem roundToRupee_whole {p : Int} (h : p % 100 = 0) : roundToRupee p .halfUp = p := by
  rw [roundToRupee_eq_sql]
  obtain ⟨k, rfl⟩ : ∃ k, p = 100 * k := ⟨p / 100, by omega⟩
  by_cases hk : 0 ≤ k
  · rw [sqlRound_mul (by omega) hk]
  · unfold sqlRound
    rw [ite_t (by omega)]
    have : (2 * -(100 * k) + 100) / (2 * 100) = -k := by
      apply ediv_eq_of_bounds (by omega) <;> omega
    rw [this]; omega

theorem roundToRupee_nonneg {p : Int} (h : 0 ≤ p) : 0 ≤ roundToRupee p .halfUp := by
  rw [roundToRupee_eq_sql]; have := sqlRound_nonneg (d := 100) (by omega) h; omega

theorem roundToRupee_mono {a b : Int} (ha : 0 ≤ a) (hab : a ≤ b) :
    roundToRupee a .halfUp ≤ roundToRupee b .halfUp := by
  rw [roundToRupee_eq_sql, roundToRupee_eq_sql]
  have := sqlRound_mono (d := 100) (by omega) ha hab; omega

/-- Capping at whole rupees `M` commutes with rounding to rupees. -/
theorem roundToRupee_min {x M : Int} (hx : 0 ≤ x) (hM : 0 ≤ M) (hM100 : M % 100 = 0) :
    roundToRupee (min x M) .halfUp = min (roundToRupee x .halfUp) M := by
  have hMr := roundToRupee_whole hM100
  by_cases h : x ≤ M
  · rw [Int.min_eq_left h]
    have := roundToRupee_mono hx h
    omega
  · rw [Int.min_eq_right (by omega), hMr]
    have := roundToRupee_mono hM (show M ≤ x by omega)
    omega

/-! ## allocate and splitEvenly

`Money.allocate(ratios)`: the largest-remainder method on `|paisa|`, then
the sign put back. Ratios are non-negative `int`s (the Dart throws
otherwise), modelled as `Nat`. -/

/-- Dart `parts[i] += 1` (no change when `i` is out of range; the Dart
indices are always in range, which `bump_sum` assumes). -/
def incAt : List Nat → Nat → List Nat
  | [], _ => []
  | x :: xs, 0 => (x + 1) :: xs
  | x :: xs, i + 1 => x :: incAt xs i

/-- The Dart loop `for (entry in remainders) { if (leftover == 0) break;
parts[entry.index] += 1; leftover -= 1; }`. -/
def bump : List Nat → List Nat → Nat → List Nat
  | parts, [], _ => parts
  | parts, _ :: _, 0 => parts
  | parts, i :: is, l + 1 => bump (incAt parts i) is l

/-- The Dart comparator of `remainders.sort(...)`: by remainder, largest
first, then by index, as a relation on indices. -/
def remLe (rems : List Nat) (i j : Nat) : Bool :=
  decide (rems.getD j 0 < rems.getD i 0) || (rems.getD i 0 == rems.getD j 0 && decide (i ≤ j))

/-- The Dart `remainders.sort(...)`. `mergeSort` with this total order gives
the one sorted order. -/
def remainderOrder (rems : List Nat) : List Nat :=
  (List.range rems.length).mergeSort (remLe rems)

/-- `parts`: each ratio's share of `m`, rounded down (`share ~/ totalBig`). -/
def allocBase (m : Nat) (ratios : List Nat) : List Nat :=
  ratios.map fun r => m * r / ratios.sum

/-- `remainders`: what rounding down left of each share
(`share.remainder(totalBig)`). -/
def allocRems (m : Nat) (ratios : List Nat) : List Nat :=
  ratios.map fun r => m * r % ratios.sum

/-- `allocate` on a magnitude `m = |paisa|`: the floors, then one more paisa
each for the `leftover = m - allocated` largest remainders. -/
def allocateNat (m : Nat) (ratios : List Nat) : List Nat :=
  bump (allocBase m ratios) (remainderOrder (allocRems m ratios)) (m - (allocBase m ratios).sum)

/-- `Money.allocate(ratios)`. -/
def allocate (paisa : Int) (ratios : List Nat) : List Int :=
  let sign : Int := if paisa < 0 then -1 else 1
  (allocateNat paisa.natAbs ratios).map fun (part : Nat) => (part : Int) * sign

/-- `Money.splitEvenly(count)`. -/
def splitEvenly (paisa : Int) (count : Nat) : List Int :=
  allocate paisa (List.replicate count 1)

section ListFacts

theorem length_incAt (l : List Nat) (i : Nat) : (incAt l i).length = l.length := by
  induction l generalizing i with
  | nil => rfl
  | cons x xs ih => cases i <;> simp [incAt, ih]

theorem sum_incAt (l : List Nat) (i : Nat) :
    (incAt l i).sum = l.sum + (if i < l.length then 1 else 0) := by
  induction l generalizing i with
  | nil => simp [incAt]
  | cons x xs ih =>
    cases i with
    | zero => simp [incAt]; omega
    | succ i =>
      simp [incAt, ih]
      repeat' split
      all_goals omega

theorem getD_incAt (l : List Nat) (i j : Nat) :
    (incAt l i).getD j 0 = l.getD j 0 + (if i = j ∧ j < l.length then 1 else 0) := by
  induction l generalizing i j with
  | nil => simp [incAt]
  | cons x xs ih =>
    cases i <;> cases j
    · simp [incAt]
    · simp [incAt]
    · simp [incAt]
    · simp only [incAt, List.getD_cons_succ, ih, List.length_cons, Nat.add_right_cancel_iff,
        Nat.add_lt_add_iff_right]

theorem length_bump (parts order : List Nat) (l : Nat) :
    (bump parts order l).length = parts.length := by
  induction order generalizing parts l with
  | nil => simp [bump]
  | cons i is ih => cases l <;> simp [bump, ih, length_incAt]

theorem bump_sum (parts order : List Nat) (l : Nat) (h : ∀ i ∈ order, i < parts.length) :
    (bump parts order l).sum = parts.sum + min l order.length := by
  induction order generalizing parts l with
  | nil => simp [bump]
  | cons i is ih =>
    cases l with
    | zero => simp [bump]
    | succ l =>
      simp only [bump]
      rw [ih _ _ (by intro j hj; rw [length_incAt]; exact h j (by simp [hj]))]
      rw [sum_incAt, ite_t (h i (by simp))]
      simp; omega

theorem bump_getD (parts order : List Nat) (l j : Nat) (h : ∀ i ∈ order, i < parts.length) :
    (bump parts order l).getD j 0 = parts.getD j 0 + (order.take l).count j := by
  induction order generalizing parts l with
  | nil => simp [bump]
  | cons i is ih =>
    cases l with
    | zero => simp [bump]
    | succ l =>
      simp only [bump]
      rw [ih _ _ (by intro k hk; rw [length_incAt]; exact h k (by simp [hk]))]
      rw [getD_incAt, List.take_succ_cons, List.count_cons]
      have hi := h i (by simp)
      by_cases hij : i = j
      · subst hij; simp [hi] <;> omega
      · simp [hij]

/-- `T * floor(m*r/T) + (m*r mod T)` summed over the ratios. -/
theorem div_mod_sum (m T : Nat) (rs : List Nat) :
    T * (rs.map fun r => m * r / T).sum + (rs.map fun r => m * r % T).sum = m * rs.sum := by
  induction rs with
  | nil => simp
  | cons r rs ih =>
    simp only [List.map_cons, List.sum_cons]
    have := Nat.div_add_mod (m * r) T
    rw [Nat.mul_add, Nat.mul_add]
    omega

theorem sum_lt_of_lt (T : Nat) (l : List Nat) (h : ∀ x ∈ l, x < T) (hne : l ≠ []) :
    l.sum < l.length * T := by
  induction l with
  | nil => exact absurd rfl hne
  | cons x xs ih =>
    simp only [List.sum_cons, List.length_cons, Nat.succ_mul]
    have hx := h x (by simp)
    by_cases hxs : xs = []
    · subst hxs; simp; omega
    · have := ih (fun y hy => h y (by simp [hy])) hxs; omega

theorem getD_map {α β : Type} (f : α → β) (l : List α) (i : Nat) (a : α) (b : β)
    (hi : i < l.length) : (l.map f).getD i b = f (l.getD i a) := by
  induction l generalizing i with
  | nil => simp at hi
  | cons x xs ih => cases i <;> simp_all

theorem sum_map_mul_sign (l : List Nat) (s : Int) :
    (l.map fun (p : Nat) => (p : Int) * s).sum = (l.sum : Int) * s := by
  induction l with
  | nil => simp
  | cons x xs ih => simp only [List.map_cons, List.sum_cons, ih]; push_cast; grind

end ListFacts

theorem remainderOrder_perm (rems : List Nat) :
    (remainderOrder rems).Perm (List.range rems.length) :=
  List.mergeSort_perm _ _

theorem remainderOrder_mem {rems : List Nat} {i : Nat} (h : i ∈ remainderOrder rems) :
    i < rems.length := by
  have := (remainderOrder_perm rems).mem_iff.mp h
  simpa using this

theorem remainderOrder_nodup (rems : List Nat) : (remainderOrder rems).Nodup :=
  (remainderOrder_perm rems).nodup_iff.mpr List.nodup_range

theorem remainderOrder_length (rems : List Nat) : (remainderOrder rems).length = rems.length := by
  rw [(remainderOrder_perm rems).length_eq]; simp

/-- The extra paisa go to the largest remainders: every index that gets one
has a remainder at least that of every index that does not. -/
theorem bumped_largest (rems : List Nat) (L i j : Nat) (hi : i ∈ (remainderOrder rems).take L)
    (hj : j ∈ (remainderOrder rems).drop L) : rems.getD j 0 ≤ rems.getD i 0 := by
  have trans : ∀ a b c, remLe rems a b = true → remLe rems b c = true → remLe rems a c = true := by
    intro a b c
    simp only [remLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
    omega
  have total : ∀ a b, (remLe rems a b || remLe rems b a) = true := by
    intro a b
    simp only [remLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
    omega
  have hp := List.pairwise_mergeSort trans total (List.range rems.length)
  rw [← remainderOrder, ← List.take_append_drop L (remainderOrder rems)] at hp
  have h := (List.pairwise_append.mp hp).2.2 i hi j hj
  simp only [remLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  omega

/-- In `allocate`, a part that got the extra paisa had a remainder at least
as large as that of any part that did not. -/
theorem allocateNat_largest_remainder {m : Nat} {ratios : List Nat} (i j : Nat)
    (hi : i ∈ (remainderOrder (allocRems m ratios)).take (m - (allocBase m ratios).sum))
    (hj : j ∈ (remainderOrder (allocRems m ratios)).drop (m - (allocBase m ratios).sum)) :
    (allocRems m ratios).getD j 0 ≤ (allocRems m ratios).getD i 0 :=
  bumped_largest _ _ i j hi hj

/-- What is left over after the floors is less than the number of parts,
so the bump loop always hands it all out. -/
theorem leftover_lt {m : Nat} {ratios : List Nat} (hne : ratios ≠ []) (hT : 0 < ratios.sum) :
    (allocBase m ratios).sum ≤ m ∧ m - (allocBase m ratios).sum < ratios.length := by
  have hdm : ratios.sum * (allocBase m ratios).sum + (allocRems m ratios).sum = m * ratios.sum :=
    div_mod_sum m ratios.sum ratios
  have hrem : (allocRems m ratios).sum < ratios.length * ratios.sum := by
    have := sum_lt_of_lt ratios.sum (allocRems m ratios)
      (by intro x hx; simp [allocRems] at hx; obtain ⟨a, _, rfl⟩ := hx; exact Nat.mod_lt _ hT)
      (by simpa [allocRems] using hne)
    simpa [allocRems] using this
  generalize (allocRems m ratios).sum = R at hdm hrem
  generalize (allocBase m ratios).sum = B at hdm ⊢
  generalize ratios.sum = T at hdm hrem hT
  have hc : m * T = T * m := Nat.mul_comm m T
  have hB : B ≤ m := by
    apply Classical.byContradiction; intro h
    have h1 : T * (m + 1) ≤ T * B := Nat.mul_le_mul_left T (by omega)
    have h2 : T * (m + 1) = T * m + T := by rw [Nat.mul_add, Nat.mul_one]
    omega
  refine ⟨hB, ?_⟩
  obtain ⟨L, rfl⟩ : ∃ L, m = B + L := ⟨m - B, by omega⟩
  have h3 : T * (B + L) = T * B + T * L := Nat.mul_add T B L
  have h4 : ratios.length * T = T * ratios.length := Nat.mul_comm _ _
  apply Classical.byContradiction; intro h
  have h5 : T * ratios.length ≤ T * L := Nat.mul_le_mul_left T (by omega)
  omega

/-- `allocate` conserves the magnitude: the parts sum to `m`. -/
theorem allocateNat_sum {m : Nat} {ratios : List Nat} (hne : ratios ≠ []) (hT : 0 < ratios.sum) :
    (allocateNat m ratios).sum = m := by
  have ⟨hB, hL⟩ := leftover_lt (m := m) hne hT
  simp only [allocateNat]
  rw [bump_sum _ _ _ (by
      intro i hi; have := remainderOrder_mem hi; simpa [allocRems, allocBase] using this),
    remainderOrder_length]
  simp only [allocRems, List.length_map]
  omega

/-- Each part is the floor of its exact share `m * r / total`, or one
paisa more. -/
theorem allocateNat_part {m : Nat} {ratios : List Nat} (i : Nat) (hi : i < ratios.length) :
    let base := m * ratios.getD i 0 / ratios.sum
    base ≤ (allocateNat m ratios).getD i 0 ∧ (allocateNat m ratios).getD i 0 ≤ base + 1 := by
  intro base
  simp only [allocateNat]
  rw [bump_getD _ _ _ _ (by intro j hj; have := remainderOrder_mem hj; simpa [allocRems, allocBase] using this)]
  rw [show (allocBase m ratios).getD i 0 = m * ratios.getD i 0 / ratios.sum from
    getD_map _ _ _ 0 0 hi]
  have hnd := (remainderOrder_nodup (allocRems m ratios)).sublist
    (List.take_sublist (m - (allocBase m ratios).sum) _)
  rw [List.Nodup.count hnd]
  split <;> omega

/-- `Money.allocate`: the parts always sum to the amount. -/
theorem allocate_sum {p : Int} {ratios : List Nat} (hne : ratios ≠ []) (hT : 0 < ratios.sum) :
    (allocate p ratios).sum = p := by
  simp only [allocate]
  rw [sum_map_mul_sign, allocateNat_sum hne hT]
  have := Int.natAbs_eq p
  split <;> omega

/-- `Money.allocate`: each part is its exact share of `|p|` rounded down, or
one paisa more, with the sign of `p`. -/
theorem allocate_part {p : Int} {ratios : List Nat} (i : Nat) (hi : i < ratios.length) :
    let base : Int := (p.natAbs * ratios.getD i 0 / ratios.sum : Nat)
    let part := (allocate p ratios).getD i 0
    (0 ≤ p → base ≤ part ∧ part ≤ base + 1) ∧ (p < 0 → -base - 1 ≤ part ∧ part ≤ -base) := by
  intro base part
  have h := allocateNat_part (m := p.natAbs) (ratios := ratios) i hi
  have hl : i < (allocateNat p.natAbs ratios).length := by
    simp [allocateNat, length_bump, allocBase, hi]
  have e : part = ((allocateNat p.natAbs ratios).getD i 0 : Int) * (if p < 0 then -1 else 1) := by
    simp only [part, allocate]
    exact getD_map _ _ _ 0 0 hl
  rw [e]
  constructor
  · intro hp; rw [ite_f (by omega)]; omega
  · intro hp; rw [ite_t hp]; omega

/-- `Money.splitEvenly(count)`: the parts sum to the amount ... -/
theorem splitEvenly_sum {p : Int} {count : Nat} (hc : 0 < count) :
    (splitEvenly p count).sum = p := by
  apply allocate_sum
  · intro h; have := congrArg List.length h; simp at this; omega
  · simp; omega

/-- ... and any two parts differ by at most one paisa. -/
theorem splitEvenly_close {p : Int} {count : Nat} (i j : Nat) (hi : i < count) (hj : j < count) :
    let s := splitEvenly p count
    s.getD i 0 - s.getD j 0 ≤ 1 ∧ s.getD j 0 - s.getD i 0 ≤ 1 := by
  intro s
  have hi' : i < (List.replicate count 1).length := by simpa using hi
  have hj' : j < (List.replicate count 1).length := by simpa using hj
  have a := allocate_part (p := p) i hi'
  have b := allocate_part (p := p) j hj'
  have ri : (List.replicate count 1).getD i 0 = 1 := by simp [hi]
  have rj : (List.replicate count 1).getD j 0 = 1 := by simp [hj]
  simp only [ri, rj] at a b
  simp only [s, splitEvenly]
  by_cases hp : 0 ≤ p
  · have := a.1 hp; have := b.1 hp; omega
  · have := a.2 (by omega); have := b.2 (by omega); omega

end Maalik
