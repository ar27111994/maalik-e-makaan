/-
check-vectors: re-checks the shared rent-maths contract vectors against the
proven Lean model.

  lake exe check-vectors [path/to/rent_math_vectors.json]

Exits 0 when every vector matches both the Dart and the SQL model, 1 on a
mismatch and 2 when the file cannot be read or parsed.
-/
import Maalik

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../../contracts/rent_math_vectors.json"
  let text ← try IO.FS.readFile path catch e => do
    IO.eprintln s!"check-vectors: cannot read {path}: {e}"
    return 2
  match Maalik.Vectors.checkAll text with
  | .error e =>
    IO.eprintln s!"check-vectors: {path}: {e}"
    return 2
  | .ok report =>
    for (kind, n) in report.counts do
      IO.println s!"{kind}: {n} vectors"
    for f in report.failures do
      IO.eprintln s!"MISMATCH {f}"
    let total := report.counts.foldl (fun acc (_, n) => acc + n) 0
    if report.failures.isEmpty then
      IO.println s!"check-vectors: all {total} vectors match the Dart and SQL models"
      return 0
    else
      IO.eprintln s!"check-vectors: {report.failures.length} mismatches in {total} vectors"
      return 1
