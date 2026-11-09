/-
Rent maths: packages/mm_core/lib/src/rent/rent_math.dart (`RentMath`) and
the calendar it uses (packages/mm_core/lib/src/time/*.dart), against the SQL
it mirrors: `app.prorated_rent` (last defined in
supabase/migrations/20261104143928_ledger_jobs_hardening.sql),
`app.due_date_for` (20261103193403_leases.sql) and the amounts
`private.sync_lease_billing` (20261104143928) bills.

Amounts are `Int` paisa. A SQL `numeric` rupee amount `x` is `100 * x` paisa.
-/
import Maalik.Money

namespace Maalik

/-- calendar_date.dart `CalendarDate`: a valid date has year 1..9999, month
1..12 and day 1..`daysInMonth`. -/
structure Date where
  year : Nat
  month : Nat
  day : Nat
  deriving DecidableEq, Repr

/-- `CalendarDate.isLeapYear`. -/
def isLeapYear (y : Nat) : Bool :=
  (y % 4 == 0 && y % 100 != 0) || y % 400 == 0

/-- `CalendarDate.daysInMonth`: `[31, 28, 31, 30, ...][month - 1]`, 29 for
a leap February. -/
def daysInMonth (y m : Nat) : Nat :=
  match m with
  | 2 => if isLeapYear y then 29 else 28
  | 4 | 6 | 9 | 11 => 30
  | _ => 31

def Date.valid (d : Date) : Prop :=
  1 ≤ d.year ∧ d.year ≤ 9999 ∧ 1 ≤ d.month ∧ d.month ≤ 12 ∧ 1 ≤ d.day ∧
    d.day ≤ daysInMonth d.year d.month

/-- `CalendarDate.isBefore` (`compareTo < 0`: year, then month, then day). -/
def Date.before (a b : Date) : Bool :=
  a.year < b.year || (a.year == b.year && (a.month < b.month || (a.month == b.month && a.day < b.day)))

/-- `CalendarDate.max`: `a.isBefore(b) ? b : a`. -/
def Date.max (a b : Date) : Date := if a.before b then b else a

theorem daysInMonth_bounds (y m : Nat) : 28 ≤ daysInMonth y m ∧ daysInMonth y m ≤ 31 := by
  unfold daysInMonth
  split
  · split <;> omega
  all_goals omega

/-! ## Due dates -/

/-- `RentMath.dueDate(period, dueDay)` = `period.dayClamped(dueDay)` =
`CalendarDate(year, month, dueDay.clamp(1, lengthInDays))`. -/
def dueDate (y m dueDay : Nat) : Date :=
  ⟨y, m, Nat.max 1 (Nat.min dueDay (daysInMonth y m))⟩

/-- SQL `app.due_date_for(p_month, p_due_day)`: the first of the month plus
`least(p_due_day, days in month) - 1` days. -/
def sqlDueDate (y m dueDay : Nat) : Date :=
  ⟨y, m, Nat.min dueDay (daysInMonth y m)⟩

/-- Dart and SQL agree for every due day the app accepts (1..31; the
`leases_rent_due_day_check` allows 1..28), and the due date is a real day of
the month. -/
theorem dueDate_eq_sql {y m dueDay : Nat} (h1 : 1 ≤ dueDay) :
    dueDate y m dueDay = sqlDueDate y m dueDay ∧
      1 ≤ (dueDate y m dueDay).day ∧ (dueDate y m dueDay).day ≤ daysInMonth y m := by
  have := daysInMonth_bounds y m
  simp only [dueDate, sqlDueDate, Date.mk.injEq, true_and]
  refine ⟨?_, ?_, ?_⟩ <;> simp only [Nat.max_def, Nat.min_def] <;> repeat' split
  all_goals omega

/-- `RentMath.billingDueDate`: never before billing starts. -/
def billingDueDate (y m dueDay : Nat) (billingStartsOn : Date) : Date :=
  Date.max (dueDate y m dueDay) billingStartsOn

/-! ## Proration -/

/-- `RentMath.occupiedDays(period, DateRange(start))`: the days of the month
covered by an occupancy that starts on `s` and has no end (the occupancy
`billedRent` passes). The intersection is empty when `s` is after the last
day; it starts on the first day when `s` is before it. -/
def occupiedDays (y m : Nat) (s : Date) : Nat :=
  let len := daysInMonth y m
  if Date.before ⟨y, m, len⟩ s then 0
  else if Date.before s ⟨y, m, 1⟩ then len
  else len - s.day + 1

/-- `RentMath.proratedRent(monthlyRent:, period:, occupancy: DateRange(s))`. -/
def proratedRent (rent : Int) (y m : Nat) (s : Date) : Int :=
  let days := occupiedDays y m s
  if days = daysInMonth y m then rent
  else if days = 0 then 0
  else min rent (multiplyToStep rent days (daysInMonth y m))

/-- SQL `app.prorated_rent(p_rent, p_month, p_billing_starts_on)` with the
division taken exactly: `least(rent, round(rent * days / dim, 0))` in the
billing month when it starts after the 1st, else the rent. -/
def sqlProratedRent (rent : Int) (y m : Nat) (s : Date) : Int :=
  let dim := daysInMonth y m
  if s.year = y ∧ s.month = m ∧ 1 < s.day then
    min rent (100 * sqlRound (rent * (dim - s.day + 1 : Nat)) (100 * dim))
  else rent

/-- The same with PostgreSQL's `numeric` division rounded to result scale
`rscale` first (numeric.c `select_div_scale`; formal/smt shows it is at least
8 for every rent the database admits). -/
def pgProratedRent (rent : Int) (y m : Nat) (s : Date) (rscale : Nat) : Int :=
  let dim := daysInMonth y m
  if s.year = y ∧ s.month = m ∧ 1 < s.day then
    min rent (100 * pgScaledRound (rent * (dim - s.day + 1 : Nat)) (100 * dim) rscale)
  else rent

theorem occupiedDays_in_month {y m : Nat} {s : Date} (hy : s.year = y) (hm : s.month = m)
    (h1 : 1 ≤ s.day) (h2 : s.day ≤ daysInMonth y m) :
    occupiedDays y m s = daysInMonth y m - s.day + 1 := by
  subst hy hm
  have a : ¬daysInMonth s.year s.month < s.day := by omega
  have b : ¬s.day < 1 := by omega
  simp [occupiedDays, Date.before, a, b]

/-- Proration never charges less than nothing nor more than the rent. -/
theorem proratedRent_bounds {rent : Int} {y m : Nat} {s : Date} (hr : 0 ≤ rent) :
    0 ≤ proratedRent rent y m s ∧ proratedRent rent y m s ≤ rent := by
  have := daysInMonth_bounds y m
  simp only [proratedRent]
  split
  · omega
  · split
    · omega
    · rw [multiplyToStep_eq_sql (by omega)]
      have : 0 ≤ sqlRound (rent * (occupiedDays y m s : Int)) ((daysInMonth y m : Int) * 100) :=
        sqlRound_nonneg (by omega) (Int.mul_nonneg hr (by omega))
      omega

/-- A month billed from its first day costs the whole rent. -/
theorem proratedRent_whole_month {rent : Int} {y m : Nat} :
    proratedRent rent y m ⟨y, m, 1⟩ = rent := by
  have := daysInMonth_bounds y m
  have hocc : occupiedDays y m ⟨y, m, 1⟩ = daysInMonth y m := by
    have h := occupiedDays_in_month (y := y) (m := m) (s := ⟨y, m, 1⟩) rfl rfl (Nat.le_refl 1)
      (by show 1 ≤ daysInMonth y m; omega)
    rw [h]; show daysInMonth y m - 1 + 1 = daysInMonth y m; omega
  simp [proratedRent, hocc]

/-- A tenancy that started before the month covers all of it. -/
theorem proratedRent_started_before {rent : Int} {y m : Nat} {s : Date}
    (h : Date.before s ⟨y, m, 1⟩) : proratedRent rent y m s = rent := by
  have := daysInMonth_bounds y m
  have hn : ¬Date.before ⟨y, m, daysInMonth y m⟩ s := by
    simp only [Date.before] at h ⊢; simp at h ⊢; omega
  have hocc : occupiedDays y m s = daysInMonth y m := by
    simp only [occupiedDays]; rw [ite_f hn, ite_t h]
  simp [proratedRent, hocc]

/-- Dart proration equals SQL `app.prorated_rent` in the billing month. -/
theorem proratedRent_eq_sql {rent : Int} {y m : Nat} {s : Date} (hy : s.year = y)
    (hm : s.month = m) (h1 : 1 ≤ s.day) (h2 : s.day ≤ daysInMonth y m) :
    proratedRent rent y m s = sqlProratedRent rent y m s := by
  have hb := daysInMonth_bounds y m
  have hocc := occupiedDays_in_month hy hm h1 h2
  simp only [proratedRent, sqlProratedRent, hocc]
  by_cases hd : s.day = 1
  · rw [ite_t (by omega), ite_f (by omega)]
  · rw [ite_f (by omega), ite_f (by omega), ite_t ⟨hy, hm, by omega⟩,
      multiplyToStep_eq_sql (by omega)]
    rw [show ((daysInMonth y m : Nat) : Int) * 100 = 100 * (daysInMonth y m : Int) by omega]

/-- PostgreSQL's inexact `numeric` division does not change the result once
its scale is at least 4 (`100 * dim ≤ 3100 < 10^4`). -/
theorem pgProratedRent_eq {rent : Int} {y m : Nat} {s : Date} {rscale : Nat} (hr : 0 ≤ rent)
    (hs : 4 ≤ rscale) : pgProratedRent rent y m s rscale = sqlProratedRent rent y m s := by
  have hb := daysInMonth_bounds y m
  simp only [pgProratedRent, sqlProratedRent]
  split
  · rw [pgScaledRound_eq (Int.mul_nonneg hr (by omega)) (by omega) (by omega)]
    obtain ⟨j, rfl⟩ : ∃ j, rscale = 4 + j := ⟨rscale - 4, by omega⟩
    have hj : ∀ j : Nat, (1 : Int) ≤ 10 ^ j := by
      intro j; induction j with
      | zero => simp
      | succ j ih => rw [Int.pow_succ]; omega
    have := hj j
    rw [Int.pow_add, show (10 : Int) ^ 4 = 10000 by rfl]
    have : (10000 : Int) ≤ 10000 * 10 ^ j := by omega
    omega
  · rfl

/-! ## The billed rent of a month -/

/-- `RentMath.billedRent(monthlyRent:, period:, billingStartsOn:,
prorateFirstMonth:)`. -/
def billedRent (rent : Int) (y m : Nat) (start : Date) (prorate : Bool) : Int :=
  if y < start.year ∨ (y = start.year ∧ m < start.month) then 0
  else if (y ≠ start.year ∨ m ≠ start.month) ∨ !prorate then rent
  else proratedRent rent y m start

/-- `private.sync_lease_billing`: no charge for a month before billing
starts (the loop starts at `date_trunc('month', billing_starts_on)`), else
`case when prorate_first_month then app.prorated_rent(...) else v_rent end`. -/
def sqlBilledRent (rent : Int) (y m : Nat) (start : Date) (prorate : Bool) : Int :=
  if y < start.year ∨ (y = start.year ∧ m < start.month) then 0
  else if prorate then sqlProratedRent rent y m start
  else rent

theorem billedRent_eq_sql {rent : Int} {y m : Nat} {start : Date} {prorate : Bool}
    (hv : start.valid) :
    billedRent rent y m start prorate = sqlBilledRent rent y m start prorate := by
  obtain ⟨_, _, _, _, h1, h2⟩ := hv
  simp only [billedRent, sqlBilledRent]
  split
  · rfl
  · by_cases hym : y = start.year ∧ m = start.month
    · obtain ⟨rfl, rfl⟩ := hym
      cases prorate
      · simp
      · simp only [Bool.not_true, Bool.false_eq_true, or_false]
        rw [ite_f (by omega), ite_t trivial]
        exact proratedRent_eq_sql rfl rfl h1 h2
    · rw [ite_t (Or.inl (by omega))]
      cases prorate
      · rfl
      · simp only [ite_true, sqlProratedRent]
        rw [ite_f (by omega)]

theorem billedRent_bounds {rent : Int} {y m : Nat} {start : Date} {prorate : Bool}
    (hr : 0 ≤ rent) :
    0 ≤ billedRent rent y m start prorate ∧ billedRent rent y m start prorate ≤ rent := by
  have := proratedRent_bounds (y := y) (m := m) (s := start) hr
  simp only [billedRent]
  repeat' split
  all_goals omega

/-! ## Anniversaries (checked against the vectors, not proven) -/

/-- `CalendarDate.addMonths(months)` for `months ≥ 0`. -/
def addMonths (d : Date) (k : Nat) : Date :=
  let zeroBased := d.year * 12 + (d.month - 1) + k
  let ty := zeroBased / 12
  let tm := zeroBased % 12 + 1
  ⟨ty, tm, Nat.max 1 (Nat.min d.day (daysInMonth ty tm))⟩

/-- The `while (candidate.isBefore(asOf))` loop of `nextAnniversary`, with
fuel instead of general recursion. -/
def anniversaryLoop (start asOf : Date) (interval : Nat) : Nat → Nat → Date
  | 0, cycles => addMonths start (cycles * interval)
  | fuel + 1, cycles =>
    let candidate := addMonths start (cycles * interval)
    if candidate.before asOf then anniversaryLoop start asOf interval fuel (cycles + 1)
    else candidate

/-- `RentMath.nextAnniversary(leaseStart, asOf, intervalMonths:)`, with the
first guess `(monthsElapsed ~/ intervalMonths).clamp(1, 1 << 20)`. The fuel
(1,000 loop turns) is far more than any vector needs. -/
def nextAnniversary (start asOf : Date) (interval : Nat) : Date :=
  let cycles :=
    if start.before asOf then
      let monthsElapsed := (asOf.year * 12 + asOf.month) - (start.year * 12 + start.month)
      Nat.min (Nat.max (monthsElapsed / interval) 1) (2 ^ 20)
    else 1
  anniversaryLoop start asOf interval 1000 cycles

end Maalik
