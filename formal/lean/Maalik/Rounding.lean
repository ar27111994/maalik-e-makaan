/-
Rounding of an exact quotient to an integer.

Follows `divideRounded` and `enum RoundingMode` in
packages/mm_core/lib/src/money/money.dart line by line, over `Int` (Dart
`BigInt` is unbounded, so `Int` is exact). The SQL side is `round(numeric, 0)`
(PostgreSQL rounds half away from zero), modelled by `sqlRound`; the
PostgreSQL rounding of an inexact `numeric` division to its result scale is
modelled by `pgScaledRound`.

Notation in the theorems: for a positive denominator `d`, the exact quotient
is `n / d` (a rational); "q * d ≤ n" is "q ≤ n / d" with both sides
multiplied by `d`.
-/
namespace Maalik

/-- money.dart `enum RoundingMode`. -/
inductive RoundingMode where
  | halfUp
  | halfEven
  | down
  | up
  | floor
  | ceiling
  deriving DecidableEq, Repr

/-- Dart `BigInt.abs`. -/
def absI (x : Int) : Int := if x < 0 then -x else x

/-- The part of money.dart `divideRounded` after the sign of the
denominator has been normalised (`d > 0`). `~/` truncates toward zero
(`Int.tdiv`); `remainder` carries the sign of `n` (`Int.tmod`). -/
def roundKernel (n d : Int) (mode : RoundingMode) : Int :=
  let quotient := n.tdiv d
  let remainder := n.tmod d
  if remainder = 0 then quotient
  else
    let awayFromZero := if n < 0 then quotient - 1 else quotient + 1
    let twiceRemainder := absI remainder * 2
    match mode with
    | .down => quotient
    | .up => awayFromZero
    | .floor => if n < 0 then quotient - 1 else quotient
    | .ceiling => if n < 0 then quotient else quotient + 1
    | .halfUp => if twiceRemainder ≥ d then awayFromZero else quotient
    | .halfEven =>
      if twiceRemainder > d then awayFromZero
      else if twiceRemainder < d then quotient
      else if quotient % 2 = 0 then quotient
      else awayFromZero

/-- money.dart `divideRounded(numerator, denominator, mode)`. Dart throws
`ArgumentError` for a zero denominator; the model returns 0 there and every
theorem assumes a non-zero denominator. A negative denominator is
normalised by negating both operands, as in the Dart. -/
def divideRounded (numerator denominator : Int) (mode : RoundingMode) : Int :=
  if denominator = 0 then 0
  else if denominator < 0 then roundKernel (-numerator) (-denominator) mode
  else roundKernel numerator denominator mode

/-- PostgreSQL `round(n / d, 0)` for the exact rational `n / d`, `d > 0`:
the nearest integer, ties away from zero (numeric.c `round_var`). -/
def sqlRound (n d : Int) : Int :=
  if n < 0 then -((2 * -n + d) / (2 * d)) else (2 * n + d) / (2 * d)

/-- PostgreSQL `round(a / b, 0)` when `a / b` is a `numeric` division that
is not exact: numeric.c `div_var` first rounds the quotient (half away from
zero) to the result scale `s` chosen by `select_div_scale`, then `round`
rounds that to an integer. The quotient at scale `s` is the integer
`sqlRound (a * 10^s) b` read as a multiple of `10^-s`. -/
def pgScaledRound (a b : Int) (s : Nat) : Int :=
  sqlRound (sqlRound (a * 10 ^ s) b) (10 ^ s)

/-! ## Division facts used throughout -/

theorem ediv_spec (n d : Int) (hd : 0 < d) :
    d * (n / d) + n % d = n ∧ 0 ≤ n % d ∧ n % d < d :=
  ⟨Int.mul_ediv_add_emod n d, Int.emod_nonneg n (by omega), Int.emod_lt_of_pos n hd⟩

/-- An integer quotient is pinned down by its two bounds. -/
theorem ediv_eq_of_bounds {a b q : Int} (hb : 0 < b) (h1 : b * q ≤ a) (h2 : a < b * q + b) :
    a / b = q := by
  have := (Int.ediv_emod_unique (a := a) (r := a - b * q) (q := q) hb).2 ⟨by omega, by omega, by omega⟩
  exact this.1

/-- Truncating division by a positive `d`, in terms of floor division. -/
theorem tdiv_tmod_spec (n d : Int) (hd : 0 < d) :
    d * n.tdiv d + n.tmod d = n ∧
      (0 ≤ n → 0 ≤ n.tmod d ∧ n.tmod d < d) ∧
      (n < 0 → -d < n.tmod d ∧ n.tmod d ≤ 0) := by
  by_cases hn : 0 ≤ n
  · rw [Int.tdiv_eq_ediv_of_nonneg hn, Int.tmod_eq_emod_of_nonneg hn]
    have := ediv_spec n d hd
    refine ⟨this.1, fun _ => ⟨this.2.1, this.2.2⟩, fun h => absurd h (by omega)⟩
  · have hm : 0 ≤ -n := by omega
    have e1 : n.tdiv d = -((-n).tdiv d) := by
      rw [Int.neg_tdiv, Int.neg_neg]
    have e2 : n.tmod d = -((-n).tmod d) := by
      rw [Int.neg_tmod, Int.neg_neg]
    rw [e1, e2, Int.tdiv_eq_ediv_of_nonneg hm, Int.tmod_eq_emod_of_nonneg hm]
    have := ediv_spec (-n) d hd
    refine ⟨?_, fun h => absurd h hn, fun _ => ⟨by omega, by omega⟩⟩
    rw [Int.mul_neg]
    omega

theorem ite_t {α : Sort _} {c : Prop} [Decidable c] (h : c) (a b : α) :
    (if c then a else b) = a := by simp [h]

theorem ite_f {α : Sort _} {c : Prop} [Decidable c] (h : ¬c) (a b : α) :
    (if c then a else b) = b := by simp [h]

theorem divideRounded_pos {n d : Int} (hd : 0 < d) (m : RoundingMode) :
    divideRounded n d m = roundKernel n d m := by
  unfold divideRounded
  rw [ite_f (show ¬d = 0 by omega), ite_f (show ¬d < 0 by omega)]

/-- A negative denominator: the Dart negates both operands. With the
theorems for `d > 0` below this covers every non-zero denominator. -/
theorem divideRounded_neg {n d : Int} (hd : d < 0) (m : RoundingMode) :
    divideRounded n d m = divideRounded (-n) (-d) m := by
  rw [divideRounded_pos (n := -n) (d := -d) (by omega)]
  unfold divideRounded
  rw [ite_f (show ¬d = 0 by omega), ite_t hd]

/-! ## Each mode meets its defining inequalities (`d > 0`) -/

section Specs
variable {n d : Int}

/-- The quotient and remainder of the kernel, with every fact the proofs
need, including the two products `omega` treats as atoms. -/
private theorem kernel_facts (hd : 0 < d) :
    ∃ q r, n.tdiv d = q ∧ n.tmod d = r ∧ d * q + r = n ∧
      (0 ≤ n → 0 ≤ r ∧ r < d) ∧ (n < 0 → -d < r ∧ r ≤ 0) ∧
      d * (q + 1) = d * q + d ∧ d * (q - 1) = d * q - d :=
  ⟨_, _, rfl, rfl, (tdiv_tmod_spec n d hd).1, (tdiv_tmod_spec n d hd).2.1,
    (tdiv_tmod_spec n d hd).2.2, by rw [Int.mul_add, Int.mul_one], by rw [Int.mul_sub, Int.mul_one]⟩

theorem floor_spec (hd : 0 < d) :
    let q := divideRounded n d .floor
    d * q ≤ n ∧ n < d * q + d := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, hk, hr]
  by_cases hn : 0 ≤ n
  · have := hpos hn
    split <;> (try split) <;> omega
  · have := hneg (by omega)
    split <;> (try split) <;> omega

theorem ceiling_spec (hd : 0 < d) :
    let q := divideRounded n d .ceiling
    d * q - d < n ∧ n ≤ d * q := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, hk, hr]
  by_cases hn : 0 ≤ n
  · have := hpos hn
    split <;> (try split) <;> omega
  · have := hneg (by omega)
    split <;> (try split) <;> omega

/-- `down` truncates toward zero: floor for `n ≥ 0`, ceiling for `n < 0`. -/
theorem down_spec (hd : 0 < d) :
    let q := divideRounded n d .down
    (0 ≤ n → d * q ≤ n ∧ n < d * q + d) ∧ (n < 0 → d * q - d < n ∧ n ≤ d * q) := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, hk, hr]
  constructor
  · intro hn
    have := hpos hn
    split <;> omega
  · intro hn
    have := hneg hn
    split <;> omega

/-- `up` rounds away from zero: ceiling for `n ≥ 0`, floor for `n < 0`. -/
theorem up_spec (hd : 0 < d) :
    let q := divideRounded n d .up
    (0 ≤ n → d * q - d < n ∧ n ≤ d * q) ∧ (n < 0 → d * q ≤ n ∧ n < d * q + d) := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, hk, hr]
  constructor
  · intro hn
    have := hpos hn
    split <;> (try split) <;> omega
  · intro hn
    have := hneg hn
    split <;> (try split) <;> omega

/-- `halfUp` is the nearest integer, ties away from zero: for `n ≥ 0`,
`q - 1/2 ≤ n/d < q + 1/2`; for `n < 0`, `q - 1/2 < n/d ≤ q + 1/2`. -/
theorem halfUp_spec (hd : 0 < d) :
    let q := divideRounded n d .halfUp
    (0 ≤ n → 2 * (d * q) - d ≤ 2 * n ∧ 2 * n < 2 * (d * q) + d) ∧
      (n < 0 → 2 * (d * q) - d < 2 * n ∧ 2 * n ≤ 2 * (d * q) + d) := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, absI, hk, hr]
  constructor
  · intro hn
    have := hpos hn
    split <;> (try split) <;> (try split) <;> (try split) <;> omega
  · intro hn
    have := hneg hn
    split <;> (try split) <;> (try split) <;> (try split) <;> omega

/-- `halfEven` is the nearest integer, and on a tie the even one. -/
theorem halfEven_spec (hd : 0 < d) :
    let q := divideRounded n d .halfEven
    2 * (d * q) - d ≤ 2 * n ∧ 2 * n ≤ 2 * (d * q) + d ∧
      ((2 * n = 2 * (d * q) - d ∨ 2 * n = 2 * (d * q) + d) → q % 2 = 0) := by
  intro q
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  simp only [q, divideRounded_pos hd, roundKernel, absI, hk, hr]
  by_cases hn : 0 ≤ n
  · have := hpos hn
    split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> omega
  · have := hneg (by omega)
    split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> omega

end Specs

/-! ## Half-up equals SQL `round(numeric, 0)` -/

/-- For every numerator and every positive denominator, Dart's half-up
`divideRounded` is PostgreSQL's `round(n / d, 0)` of the exact quotient. -/
theorem halfUp_eq_sqlRound {n d : Int} (hd : 0 < d) :
    divideRounded n d .halfUp = sqlRound n d := by
  obtain ⟨k, r, hk, hr, he, hpos, hneg, m1, m2⟩ := kernel_facts (n := n) hd
  have h2d : 0 < 2 * d := by omega
  have p0 : 2 * d * k = 2 * (d * k) := Int.mul_assoc 2 d k
  have p1 : 2 * d * (k + 1) = 2 * (d * k) + 2 * d := by
    rw [Int.mul_add, Int.mul_one, Int.mul_assoc]
  have p2 : 2 * d * -k = -(2 * (d * k)) := by rw [Int.mul_neg, Int.mul_assoc]
  have p3 : 2 * d * (-k + 1) = -(2 * (d * k)) + 2 * d := by
    rw [Int.mul_add, Int.mul_one, Int.mul_neg, Int.mul_assoc]
  rw [divideRounded_pos hd]
  simp only [roundKernel, absI, sqlRound, hk, hr]
  by_cases hn : 0 ≤ n
  · have := hpos hn
    have e : (2 * n + d) / (2 * d) = if 2 * r ≥ d then k + 1 else k := by
      split <;> apply ediv_eq_of_bounds h2d <;> omega
    rw [ite_f (show ¬n < 0 by omega), e]
    repeat' split
    all_goals omega
  · have := hneg (by omega)
    have e : (2 * -n + d) / (2 * d) = if 2 * -r ≥ d then -k + 1 else -k := by
      split <;> apply ediv_eq_of_bounds h2d <;> omega
    rw [ite_t (show n < 0 by omega), e]
    repeat' split
    all_goals omega

/-! ## Half-up is monotone (used for late fees) -/

theorem sqlRound_nonneg {n d : Int} (hd : 0 < d) (hn : 0 ≤ n) : 0 ≤ sqlRound n d := by
  unfold sqlRound
  rw [ite_f (by omega)]
  exact Int.ediv_nonneg (by omega) (by omega)

theorem sqlRound_mono {a b d : Int} (hd : 0 < d) (ha : 0 ≤ a) (hab : a ≤ b) :
    sqlRound a d ≤ sqlRound b d := by
  unfold sqlRound
  rw [ite_f (by omega), ite_f (by omega)]
  exact Int.ediv_le_ediv (by omega) (by omega)

theorem halfUp_nonneg {n d : Int} (hd : 0 < d) (hn : 0 ≤ n) : 0 ≤ divideRounded n d .halfUp := by
  rw [halfUp_eq_sqlRound hd]; exact sqlRound_nonneg hd hn

theorem halfUp_mono {a b d : Int} (hd : 0 < d) (ha : 0 ≤ a) (hab : a ≤ b) :
    divideRounded a d .halfUp ≤ divideRounded b d .halfUp := by
  rw [halfUp_eq_sqlRound hd, halfUp_eq_sqlRound hd]; exact sqlRound_mono hd ha hab

/-- An exact quotient is returned unchanged. -/
theorem sqlRound_mul {k d : Int} (hd : 0 < d) (hk : 0 ≤ k) : sqlRound (d * k) d = k := by
  have : 0 ≤ d * k := Int.mul_nonneg (by omega) hk
  unfold sqlRound
  rw [ite_f (by omega)]
  apply ediv_eq_of_bounds (by omega) <;> grind

/-! ## Rounding twice is harmless when the first scale is fine enough

PostgreSQL rounds an inexact `numeric` quotient `a / b` to `s` decimal
places before `round(_, 0)` sees it. That cannot change the result when
`10^s > b`: a quotient whose fraction is below one half is at least `1/b`
below it, more than the `1/2 · 10^-s` the first rounding can add. -/

theorem double_round {a b P : Int} (ha : 0 ≤ a) (hb : 0 < b) (hbP : b < P) (hP : P % 2 = 0) :
    sqlRound (sqlRound (a * P) b) P = sqlRound a b := by
  have hP0 : 0 < P := by omega
  obtain ⟨hk, hr0, hrb⟩ := ediv_spec a b hb
  generalize a / b = k at hk
  generalize a % b = r at hk hr0 hrb
  have hk0 : 0 ≤ k := by
    apply Classical.byContradiction
    intro h
    have : b * k ≤ b * (-1) := Int.mul_le_mul_of_nonneg_left (by omega) (by omega)
    omega
  have h2b : 0 < 2 * b := by omega
  -- First rounding: a * P / b = k * P + (r * P / b); t is its rounded fraction.
  obtain ⟨ht, ht0, htb⟩ := ediv_spec (2 * (r * P) + b) (2 * b) h2b
  generalize (2 * (r * P) + b) / (2 * b) = t at ht
  generalize (2 * (r * P) + b) % (2 * b) = u at ht ht0 htb
  have hrP : 0 ≤ r * P := Int.mul_nonneg hr0 (by omega)
  have hkP : 0 ≤ k * P := Int.mul_nonneg hk0 (by omega)
  have haP : 0 ≤ a * P := Int.mul_nonneg ha (by omega)
  have hX : a * P = b * (k * P) + r * P := by rw [← hk]; grind
  have hm : sqlRound (a * P) b = k * P + t := by
    unfold sqlRound
    rw [ite_f (by omega)]
    apply ediv_eq_of_bounds h2b <;> grind
  rw [hm]
  have ht0' : 0 ≤ t := by
    apply Classical.byContradiction
    intro h
    have : 2 * b * t ≤ 2 * b * (-1) := Int.mul_le_mul_of_nonneg_left (by omega) (by omega)
    omega
  have htP : t ≤ P := by
    apply Classical.byContradiction
    intro h
    have h1 : r * P ≤ (b - 1) * P := Int.mul_le_mul_of_nonneg_right (by omega) (by omega)
    have h2 : 2 * b * (P + 1) ≤ 2 * b * t := Int.mul_le_mul_of_nonneg_left (by omega) (by omega)
    grind
  -- 2t ≥ P exactly when 2r ≥ b.
  have up : 2 * r ≥ b → 2 * t ≥ P := by
    intro h
    apply Classical.byContradiction
    intro hlt
    have h1 : b * P ≤ 2 * r * P := Int.mul_le_mul_of_nonneg_right h (by omega)
    have h2 : b * (2 * t + 1) ≤ b * P := Int.mul_le_mul_of_nonneg_left (by omega) (by omega)
    grind
  have down : 2 * r < b → 2 * t < P := by
    intro h
    have h1 : 2 * r * P ≤ (b - 1) * P := Int.mul_le_mul_of_nonneg_right (by omega) (by omega)
    have : b * (2 * t) < b * P := by grind
    exact Int.lt_of_mul_lt_mul_left this (by omega)
  have e1 : sqlRound (k * P + t) P = k + (if 2 * t ≥ P then 1 else 0) := by
    unfold sqlRound
    rw [ite_f (by omega)]
    apply ediv_eq_of_bounds (by omega) <;> split <;> grind
  have e2 : sqlRound a b = k + (if 2 * r ≥ b then 1 else 0) := by
    unfold sqlRound
    rw [ite_f (by omega)]
    apply ediv_eq_of_bounds h2b <;> split <;> grind
  rw [e1, e2]
  by_cases h : 2 * r ≥ b
  · rw [ite_t (up h), ite_t h]
  · rw [ite_f (show ¬2 * t ≥ P by have := down (by omega); omega), ite_f h]

/-- The PostgreSQL scaled division agrees with the exact `round` whenever
the result scale `s ≥ 1` has `10^s > b`. -/
theorem pgScaledRound_eq {a b : Int} {s : Nat} (ha : 0 ≤ a) (hb : 0 < b) (hs : 1 ≤ s)
    (hbs : b < 10 ^ s) : pgScaledRound a b s = sqlRound a b := by
  unfold pgScaledRound
  apply double_round ha hb hbs
  obtain ⟨j, rfl⟩ : ∃ j, s = j + 1 := ⟨s - 1, by omega⟩
  rw [Int.pow_succ]
  grind

end Maalik
