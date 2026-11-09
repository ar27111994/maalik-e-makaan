/-
Late fees: packages/mm_core/lib/src/rent/late_fee_policy.dart
(`LateFeePolicy.feeFor`, `computeFee`, `capFee`) against SQL
`app.late_fee_amount` (last defined in
supabase/migrations/20261104143928_ledger_jobs_hardening.sql), which
`private.assess_late_fees` calls with `p_days_late = p_as_of - c.due_date`.

Amounts are `Int` paisa. The percent policy holds basis points
(`basisPointsFromPercent`: the `numeric(5,2)` percent times 100).
-/
import Maalik.Money

namespace Maalik

/-- The `LateFeePolicy` subclasses (`late_fee_type`, `late_fee_value`,
`late_fee_cap` of `leases`). -/
inductive LateFeePolicy where
  | none
  | flat (amount : Int)
  | percent (basisPoints : Int)
  | daily (perDay : Int) (cap : Option Int)
  deriving DecidableEq, Repr

/-- `LateFeePolicy.maxFee`: `Money.fromRupees(999999999999)`. -/
def maxFee : Int := 99999999999900

/-- `computeFee`: the fee before grace, rounding and capping. `DailyLateFee`
holds the exact product below `maxFee` (`fee > limit ? limit : fee`). -/
def computeFee : LateFeePolicy → Int → Int → Int
  | .none, _, _ => 0
  | .flat amount, _, _ => amount
  | .percent bp, overdue, _ => multiplyToStep overdue bp 10000
  | .daily perDay _, _, daysLate => min (perDay * daysLate) maxFee

/-- `capFee`: only `DailyLateFee` with a cap limits the rounded fee. -/
def capFee : LateFeePolicy → Int → Int
  | .daily _ (some cap), fee => min fee cap
  | _, fee => fee

/-- `LateFeePolicy.feeFor(overdueAmount:, daysLate:, graceDays:)`. The Dart
throws for `graceDays < 0`; theorems assume `0 ≤ graceDays`. -/
def feeFor (p : LateFeePolicy) (overdue daysLate graceDays : Int) : Int :=
  if overdue ≤ 0 ∨ daysLate ≤ graceDays then 0
  else min (capFee p (roundToRupee (computeFee p overdue daysLate) .halfUp)) maxFee

/-- SQL `app.late_fee_amount(p_type, p_value, p_cap, p_outstanding,
p_days_late, p_grace_days)` in paisa, the `numeric` arithmetic taken
exactly (formal/smt shows PostgreSQL's division by 100 is exact here):
`flat` rounds `value`, `percent` rounds `outstanding * value / 100` (value
in percent = `bp / 100`), `daily` rounds `value * days_late`; then
`least(fee, daily cap or 999999999999, 999999999999)`. -/
def sqlLateFee (p : LateFeePolicy) (overdue daysLate graceDays : Int) : Int :=
  match p with
  | .none => 0
  | _ =>
    if overdue ≤ 0 ∨ daysLate ≤ graceDays then 0
    else
      let rounded : Int :=
        match p with
        | .flat value => 100 * sqlRound value 100
        | .percent bp => 100 * sqlRound (overdue * bp) 1000000
        | .daily value _ => 100 * sqlRound (value * daysLate) 100
        | .none => 0
      let cap : Int :=
        match p with
        | .daily _ (some c) => c
        | _ => maxFee
      min (min rounded cap) maxFee

/-- The policies the `leases` CHECK constraints admit: non-negative value,
percent at most 100 (`leases_late_fee_percent_check`), positive cap
(`leases_late_fee_cap_check`). -/
def LateFeePolicy.valid : LateFeePolicy → Prop
  | .none => True
  | .flat a => 0 ≤ a
  | .percent bp => 0 ≤ bp ∧ bp ≤ 10000
  | .daily perDay cap => 0 ≤ perDay ∧ ∀ c, cap = some c → 0 < c

theorem maxFee_whole : maxFee % 100 = 0 := by decide

/-- No fee inside the grace period, or when nothing is overdue. -/
theorem feeFor_zero {p : LateFeePolicy} {overdue daysLate graceDays : Int}
    (h : overdue ≤ 0 ∨ daysLate ≤ graceDays) : feeFor p overdue daysLate graceDays = 0 := by
  simp [feeFor, h]

/-- The fee never exceeds `maxFee`, what a `numeric(14,2)` charge can hold. -/
theorem feeFor_le_maxFee (p : LateFeePolicy) (overdue daysLate graceDays : Int) :
    feeFor p overdue daysLate graceDays ≤ maxFee := by
  unfold feeFor
  split
  · decide
  · omega

/-- A capped daily fee never exceeds its cap. -/
theorem feeFor_le_cap {perDay c overdue daysLate graceDays : Int} (hc : 0 < c) :
    feeFor (.daily perDay (some c)) overdue daysLate graceDays ≤ c := by
  unfold feeFor
  simp only [capFee]
  split <;> omega

theorem computeFee_nonneg {p : LateFeePolicy} (hp : p.valid) {overdue daysLate : Int}
    (ho : 0 ≤ overdue) (hd : 0 ≤ daysLate) : 0 ≤ computeFee p overdue daysLate := by
  cases p with
  | none => simp [computeFee]
  | flat a => exact hp
  | percent bp =>
    simp only [computeFee, multiplyToStep, paisaPerRupee]
    have := halfUp_nonneg (n := overdue * bp) (d := 10000 * (1 * 100)) (by omega)
      (Int.mul_nonneg ho hp.1)
    exact Int.mul_nonneg this (by omega)
  | daily perDay cap =>
    simp only [computeFee]
    have := Int.mul_nonneg hp.1 hd
    simp [maxFee] <;> omega

/-- Fees are never negative for a valid policy. -/
theorem feeFor_nonneg {p : LateFeePolicy} (hp : p.valid) {overdue daysLate graceDays : Int}
    (hg : 0 ≤ graceDays) : 0 ≤ feeFor p overdue daysLate graceDays := by
  unfold feeFor
  split
  · omega
  · have hc := computeFee_nonneg hp (overdue := overdue) (daysLate := daysLate) (by omega) (by omega)
    have hr := roundToRupee_nonneg hc
    cases p with
    | daily perDay cap =>
      cases cap with
      | none => simp only [capFee]; simp [maxFee] <;> omega
      | some c => have := hp.2 c rfl; simp only [capFee]; simp [maxFee] <;> omega
    | _ => simp only [capFee]; simp [maxFee] <;> omega

/-- Paying later never costs less: the fee is monotone in the days late. -/
theorem feeFor_mono {p : LateFeePolicy} (hp : p.valid) {overdue d1 d2 graceDays : Int}
    (hg : 0 ≤ graceDays) (h : d1 ≤ d2) :
    feeFor p overdue d1 graceDays ≤ feeFor p overdue d2 graceDays := by
  by_cases h1 : overdue ≤ 0 ∨ d1 ≤ graceDays
  · rw [feeFor_zero h1]; exact feeFor_nonneg hp hg
  · have h2 : ¬(overdue ≤ 0 ∨ d2 ≤ graceDays) := by omega
    unfold feeFor
    rw [ite_f h1, ite_f h2]
    have key : roundToRupee (computeFee p overdue d1) .halfUp ≤
        roundToRupee (computeFee p overdue d2) .halfUp := by
      cases p with
      | daily perDay cap =>
        apply roundToRupee_mono
        · exact computeFee_nonneg hp (by omega) (by omega)
        · simp only [computeFee]
          have := Int.mul_le_mul_of_nonneg_left h hp.1
          omega
      | _ => simp [computeFee]
    cases p with
    | daily perDay cap =>
      cases cap with
      | none => simp only [capFee]; omega
      | some c => simp only [capFee]; omega
    | _ => simp only [capFee]; omega

/-- Dart `feeFor` equals SQL `app.late_fee_amount` for every policy the
database admits and every non-negative grace period. -/
theorem feeFor_eq_sql {p : LateFeePolicy} (hp : p.valid) {overdue daysLate graceDays : Int}
    (hg : 0 ≤ graceDays) : feeFor p overdue daysLate graceDays = sqlLateFee p overdue daysLate graceDays := by
  unfold feeFor sqlLateFee
  cases p with
  | none =>
    split
    · rfl
    · simp only [computeFee, capFee]
      rw [roundToRupee_whole (by decide)]; simp [maxFee] <;> omega
  | flat a =>
    simp only
    split
    · rfl
    · simp only [computeFee, capFee]
      rw [roundToRupee_eq_sql]
      simp [maxFee] <;> omega
  | percent bp =>
    simp only
    split
    · rfl
    · rename_i h
      simp only [computeFee, capFee]
      have hm : multiplyToStep overdue bp 10000 1 .halfUp % 100 = 0 :=
        (multiplyToStep_halfUp (p := overdue) (num := bp) (den := 10000) (st := 1)
          (by omega) (by omega)).1
      rw [roundToRupee_whole hm, multiplyToStep_eq_sql (by omega)]
      simp [maxFee] <;> omega
  | daily perDay cap =>
    simp only
    split
    · rfl
    · rename_i h
      simp only [computeFee]
      have hx : 0 ≤ perDay * daysLate := Int.mul_nonneg hp.1 (by omega)
      rw [roundToRupee_min hx (by decide) maxFee_whole, roundToRupee_eq_sql]
      cases cap with
      | none => simp [capFee, maxFee] <;> omega
      | some c => simp [capFee, maxFee] <;> omega

end Maalik
