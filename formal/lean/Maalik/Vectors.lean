/-
Checks contracts/rent_math_vectors.json (written by
tool/contracts/generate.py from an independent Python reference) against the
proven Lean definitions: each vector is run through the Dart model and the
SQL model, and both must give the expected value.
-/
import Lean.Data.Json
import Maalik.Rent
import Maalik.LateFee
import Maalik.Allocation

namespace Maalik.Vectors

open Lean (Json)

/-- A non-empty run of ASCII digits as a `Nat`. -/
def digitsList? (cs : List Char) : Option Nat :=
  if cs.isEmpty || !cs.all Char.isDigit then none
  else some (cs.foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0)

def digits? (s : String) : Option Nat := digitsList? s.toList

/-- An exact decimal amount (`-?\d+(\.\d{1,2})?`) in paisa, like
`Money.tryParseDecimal`. -/
def parseMoney (s : String) : Option Int := do
  let (neg, body) := match s.toList with
    | '-' :: rest => (true, rest)
    | rest => (false, rest)
  let (whole, rest) := body.span (· != '.')
  let frac ← match rest with
    | [] => some []
    | _ :: f => if f.isEmpty || f.length > 2 then none else some f
  let w ← digitsList? whole
  let f ← if frac.isEmpty then some 0 else digitsList? (frac ++ List.replicate (2 - frac.length) '0')
  let paisa : Int := w * 100 + f
  return if neg then -paisa else paisa

/-- `YYYY-MM-DD`, a valid calendar date. -/
def parseDate (s : String) : Option Date := do
  match s.splitOn "-" with
  | [y, m, d] =>
    if y.length != 4 || m.length != 2 || d.length != 2 then none
    let date : Date := ⟨← digits? y, ← digits? m, ← digits? d⟩
    if 1 ≤ date.year ∧ 1 ≤ date.month ∧ date.month ≤ 12 ∧ 1 ≤ date.day ∧
        date.day ≤ daysInMonth date.year date.month then
      some date
    else none
  | _ => none

def hexDigit? (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else none

/-- A canonical lower-case UUID as its 128-bit value; for such strings the
lexicographic order is the numeric order. -/
def parseUuid (s : String) : Option Nat := do
  let parts := s.splitOn "-"
  if parts.map String.length != [8, 4, 4, 4, 12] then none
  (String.join parts).toList.foldlM (fun acc c => do return acc * 16 + (← hexDigit? c)) 0

def Date.key (d : Date) : Nat := d.year * 10000 + d.month * 100 + d.day

def showPaisa (p : Int) : String :=
  let a := p.natAbs
  let frac := toString (a % 100)
  (if p < 0 then "-" else "") ++ toString (a / 100) ++ "." ++ "".pushn '0' (2 - frac.length) ++ frac

def showDate (d : Date) : String :=
  let pad (n w : Nat) := let s := toString n; "".pushn '0' (w - s.length) ++ s
  pad d.year 4 ++ "-" ++ pad d.month 2 ++ "-" ++ pad d.day 2

/-! ## JSON access -/

def field (j : Json) (k : String) : Except String Json := j.getObjVal? k

def str (j : Json) (k : String) : Except String String := do (← field j k).getStr?

def int (j : Json) (k : String) : Except String Int := do (← field j k).getInt?

def bool (j : Json) (k : String) : Except String Bool := do (← field j k).getBool?

def need {α} (what : String) : Option α → Except String α
  | some a => .ok a
  | none => .error s!"cannot parse {what}"

def money (j : Json) (k : String) : Except String Int := do
  let s ← str j k
  need s!"{k} = {s}" (parseMoney s)

/-- A nullable money field. -/
def moneyOpt (j : Json) (k : String) : Except String (Option Int) := do
  match ← field j k with
  | .null => return none
  | v => return some (← need s!"{k}" (parseMoney (← v.getStr?)))

def date (j : Json) (k : String) : Except String Date := do
  let s ← str j k
  need s!"{k} = {s}" (parseDate s)

def arr (j : Json) (k : String) : Except String (Array Json) := do (← field j k).getArr?

/-! ## One check per vector kind. Each returns the mismatches it found. -/

def expectEq {α} [BEq α] (label : String) (shown : α → String) (expected got : α) : List String :=
  if got == expected then [] else [s!"{label}: expected {shown expected}, got {shown got}"]

def checkDueDate (j : Json) : Except String (List String) := do
  let month ← date j "month"
  let dueDay := (← int j "due_day").toNat
  let expected ← date j "expected"
  let label := s!"due_date {showDate month} day {dueDay}"
  return expectEq (label ++ " (Dart)") showDate expected (dueDate month.year month.month dueDay) ++
    expectEq (label ++ " (SQL)") showDate expected (sqlDueDate month.year month.month dueDay)

def checkBillingDueDate (j : Json) : Except String (List String) := do
  let month ← date j "month"
  let dueDay := (← int j "due_day").toNat
  let start ← date j "billing_starts_on"
  let expected ← date j "expected"
  return expectEq s!"billing_due_date {showDate month} day {dueDay} from {showDate start}" showDate
    expected (billingDueDate month.year month.month dueDay start)

def checkProratedRent (j : Json) : Except String (List String) := do
  let rent ← money j "monthly_rent"
  let month ← date j "month"
  let start ← date j "billing_starts_on"
  let expected ← money j "expected"
  let label := s!"prorated_rent {showPaisa rent} {showDate month} from {showDate start}"
  return expectEq (label ++ " (Dart)") showPaisa expected (proratedRent rent month.year month.month start) ++
    expectEq (label ++ " (SQL)") showPaisa expected (sqlProratedRent rent month.year month.month start)

def checkBilledRent (j : Json) : Except String (List String) := do
  let rent ← money j "monthly_rent"
  let month ← date j "month"
  let start ← date j "billing_starts_on"
  let prorate ← bool j "prorate_first_month"
  let expected ← money j "expected"
  let label := s!"billed_rent {showPaisa rent} {showDate month} from {showDate start} prorate {prorate}"
  return expectEq (label ++ " (Dart)") showPaisa expected
      (billedRent rent month.year month.month start prorate) ++
    expectEq (label ++ " (SQL)") showPaisa expected
      (sqlBilledRent rent month.year month.month start prorate)

def checkNextAnniversary (j : Json) : Except String (List String) := do
  let start ← date j "start"
  let asOf ← date j "as_of"
  let interval := (← int j "interval_months").toNat
  let expected ← date j "expected"
  return expectEq s!"next_anniversary {showDate start} as of {showDate asOf} every {interval}"
    showDate expected (nextAnniversary start asOf interval)

def checkLateFee (j : Json) : Except String (List String) := do
  let kind ← str j "type"
  let value ← moneyOpt j "value"
  let cap ← moneyOpt j "cap"
  let overdue ← money j "outstanding"
  let daysLate ← int j "days_late"
  let grace ← int j "grace_days"
  let expected ← money j "expected"
  let policy ← match kind, value with
    | "none", none => pure LateFeePolicy.none
    | "flat", some v => pure (LateFeePolicy.flat v)
    -- `value` is a percent with two decimals, so its "paisa" are basis points.
    | "percent", some v => pure (LateFeePolicy.percent v)
    | "daily", some v => pure (LateFeePolicy.daily v cap)
    | k, _ => throw s!"late_fee: bad policy {k}"
  let label := s!"late_fee {kind} {(value.map showPaisa).getD "-"} cap {(cap.map showPaisa).getD "-"} " ++
    s!"on {showPaisa overdue}, {daysLate} days late, grace {grace}"
  return expectEq (label ++ " (Dart)") showPaisa expected (feeFor policy overdue daysLate grace) ++
    expectEq (label ++ " (SQL)") showPaisa expected (sqlLateFee policy overdue daysLate grace)

def showPlan (p : List (Nat × Int) × Int) : String :=
  toString (p.1.map fun (id, a) => s!"{id}:{showPaisa a}") ++ s!" credit {showPaisa p.2}"

def checkAllocation (j : Json) : Except String (List String) := do
  let name ← str j "name"
  let payment ← money j "payment"
  let charges ← (← arr j "charges").toList.mapM fun c => do
    let id ← need "charge id" (parseUuid (← str c "id"))
    let due ← date c "due_date"
    let outstanding ← money c "outstanding"
    return ({ id, dueKey := Date.key due, outstanding, isSecurityDeposit := false } : OpenCharge)
  let chosen ← (← arr j "chosen_charge_ids").toList.mapM fun c => do
    need "chosen id" (parseUuid (← c.getStr?))
  let allocations ← (← arr j "expected_allocations").toList.mapM fun a => do
    return ((← need "charge id" (parseUuid (← str a "charge_id"))), (← money a "amount"))
  let expected := (allocations, ← money j "expected_unallocated")
  let label := s!"allocation '{name}'"
  return expectEq (label ++ " (Dart)") showPlan expected (planFifo payment charges chosen false) ++
    expectEq (label ++ " (SQL)") showPlan expected (sqlAllocate payment charges chosen false)

/-- The vector kinds and their checks. Every kind must be present. -/
def kinds : List (String × (Json → Except String (List String))) :=
  [("due_date", checkDueDate), ("billing_due_date", checkBillingDueDate),
    ("prorated_rent", checkProratedRent), ("billed_rent", checkBilledRent),
    ("next_anniversary", checkNextAnniversary), ("late_fee", checkLateFee),
    ("allocation", checkAllocation)]

structure Report where
  counts : List (String × Nat)
  failures : List String

/-- Parses the vector file and checks every vector. -/
def checkAll (text : String) : Except String Report := do
  let json ← Json.parse text
  let mut counts := []
  let mut failures := []
  for (kind, check) in kinds do
    let vectors ← arr json kind
    if vectors.isEmpty then throw s!"no {kind} vectors"
    for v in vectors do
      failures := failures ++ (← (check v).mapError (s!"{kind}: " ++ ·))
    counts := counts ++ [(kind, vectors.size)]
  return { counts, failures }

end Maalik.Vectors
