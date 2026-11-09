#!/usr/bin/env bash
# Checks the money arithmetic: the Lean proofs in this directory and the Z3
# checks in ../smt, each step against its expected outcome.
#
#   run.sh [ci|all] [lean|smt]
#
# ci:  lake build (no sorry, no warnings), #print axioms of the main
#      theorems, check-vectors on contracts/rent_math_vectors.json (and on a
#      copy with one expected value changed, which must fail), the fast Z3
#      checks.
# all: ci, plus every Z3 check and every Lean mutant in mutants.py (each
#      must break the proof or vector it names).
#
# Environment: LEAN_HOME (a Lean 4.35.0 toolchain with bin/lean and
# bin/lake; else lake on PATH), Z3_PYTHON (a Python with the z3-solver
# package; else python3), LEAN_JOBS (mutants built at once, default 2).
# tool/formal/install.sh installs both pinned tools and writes
# .cache/formal/env.sh, which this script reads; a variable already set wins.
# Scratch goes under ${TMPDIR:-/tmp} and is kept when a step fails, or always
# with KEEP_LOGS=1.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SMT="$REPO/formal/smt"
MODE="${1:-ci}"
ONLY="${2:-}"
case "$MODE" in
  ci | all) ;;
  *)
    echo "usage: $0 [ci|all] [lean|smt]" >&2
    exit 2
    ;;
esac
case "$ONLY" in
  "" | lean | smt) ;;
  *)
    echo "usage: $0 [ci|all] [lean|smt]" >&2
    exit 2
    ;;
esac

# The pinned tools of tool/formal/install.sh, unless set already.
if [[ -f "$REPO/.cache/formal/env.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/.cache/formal/env.sh"
fi
INSTALL_HINT="run tool/formal/install.sh, or set LEAN_HOME and Z3_PYTHON"
if [[ -n "${LEAN_HOME:-}" ]]; then
  PATH="$LEAN_HOME/bin:$PATH"
fi
export PATH
Z3_PYTHON="${Z3_PYTHON:-python3}"
JOBS="${LEAN_JOBS:-2}"
# Keep the repository free of __pycache__.
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/formal-lean-smt.XXXXXX")"
FAILED=0
cleanup() {
  if [[ "${KEEP_LOGS:-0}" == "1" || "$FAILED" != "0" ]]; then
    echo "logs kept in $SCRATCH"
  else
    rm -rf "$SCRATCH"
  fi
}
trap cleanup EXIT

START_ALL=$(date +%s)
RESULTS=()
# step NAME EXPECTED GOT SECONDS
step() {
  local result="ok"
  [[ "$2" == "$3" ]] || {
    result="FAIL"
    FAILED=$((FAILED + 1))
  }
  RESULTS+=("$(printf '%-6s %-40s %-28s %-28s %5ss' "$result" "$1" "$2" "$3" "$4")")
  echo "${RESULTS[-1]}"
}

timed() { # LOG CMD... -> exit status of CMD; output in LOG
  local log="$1" status=0
  shift
  "$@" >"$log" 2>&1 || status=$?
  return "$status"
}

run_lean() {
  command -v lake >/dev/null || {
    echo "lake (Lean 4.35.0) not found: $INSTALL_HINT" >&2
    exit 2
  }
  local version
  version="$(cd "$HERE" && lean --version 2>/dev/null || true)"
  [[ "$version" == *"version 4.35.0"* ]] || {
    echo "needs Lean 4.35.0, found: ${version:-no lean}: $INSTALL_HINT" >&2
    exit 2
  }
  local start got

  # No escape hatches in the proofs.
  start=$(date +%s)
  if grep -nE '\b(sorry|native_decide|implemented_by|partial|unsafe)\b|^\s*(axiom|admit)\b' \
    "$HERE"/Maalik/*.lean "$HERE"/Main.lean "$HERE"/Maalik.lean >"$SCRATCH/guard.log"; then
    got="forbidden"
  else got="clean"; fi
  step "source guard (sorry, native_decide, ...)" "clean" "$got" $(($(date +%s) - start))

  start=$(date +%s)
  if timed "$SCRATCH/build.log" bash -c "cd '$HERE' && lake build"; then
    if grep -qE '^(warning|error)' "$SCRATCH/build.log"; then got="warnings"; else got="built"; fi
  else got="failed"; fi
  step "lake build" "built" "$got" $(($(date +%s) - start))
  [[ "$got" == "built" ]] || {
    cat "$SCRATCH/build.log"
    return
  }

  start=$(date +%s)
  local printed allowed
  timed "$SCRATCH/axioms.log" bash -c "cd '$HERE' && lake env lean Axioms.lean" || true
  printed="$(grep -c '^#print axioms' "$HERE/Axioms.lean")"
  allowed="$(grep -cE "^'[^']+' depends on axioms: \[(propext|Classical\.choice|Quot\.sound)(, (propext|Classical\.choice|Quot\.sound))*\]$" "$SCRATCH/axioms.log" || true)"
  got="$allowed/$(wc -l <"$SCRATCH/axioms.log" | tr -d ' ') standard"
  step "#print axioms ($printed theorems)" "$printed/$printed standard" "$got" $(($(date +%s) - start))
  cat "$SCRATCH/axioms.log" >"$SCRATCH/axioms.txt"

  start=$(date +%s)
  local exe="$HERE/.lake/build/bin/check-vectors" status=0
  "$exe" "$REPO/contracts/rent_math_vectors.json" >"$SCRATCH/vectors.log" 2>&1 || status=$?
  step "check-vectors (contract)" "exit 0" "exit $status" $(($(date +%s) - start))
  tail -1 "$SCRATCH/vectors.log"

  # The checker is not vacuous: one wrong expected value must be caught.
  start=$(date +%s)
  sed '0,/"expected": "24000.00"/s//"expected": "24001.00"/' \
    "$REPO/contracts/rent_math_vectors.json" >"$SCRATCH/bad_vectors.json"
  status=0
  "$exe" "$SCRATCH/bad_vectors.json" >"$SCRATCH/bad_vectors.log" 2>&1 || status=$?
  step "check-vectors (one value changed)" "exit 1" "exit $status" $(($(date +%s) - start))

  [[ "$MODE" == "all" ]] && run_mutants
  return 0
}

mutant_outcome() { # DIR LOG -> proof <decl> | vectors | survives | error
  local dir="$1" log="$2" first file line status=0
  if ! (cd "$dir" && lake build) >"$log" 2>&1; then
    first="$(grep -oE '^error: Maalik/[A-Za-z]+\.lean:[0-9]+' "$log" | head -1)" || true
    [[ -n "$first" ]] || {
      echo "error"
      return
    }
    file="${first#error: }"
    line="${file##*:}"
    file="${file%:*}"
    echo "proof $("$Z3_PYTHON" "$HERE/mutants.py" where "$dir/$file" "$line")"
    return
  fi
  "$dir/.lake/build/bin/check-vectors" "$REPO/contracts/rent_math_vectors.json" >>"$log" 2>&1 || status=$?
  case "$status" in
    0) echo "survives" ;;
    1) echo "vectors" ;;
    *) echo "error" ;;
  esac
}

run_one_mutant() { # NAME EXPECTED -> writes $SCRATCH/mutants/NAME.result
  local name="$1" expected="$2" dir="$SCRATCH/mutants/$1" start got
  start=$(date +%s)
  mkdir -p "$dir/.lake/build"
  cp -r "$HERE"/Maalik "$HERE"/Maalik.lean "$HERE"/Main.lean "$HERE"/lakefile.toml \
    "$HERE"/lean-toolchain "$dir/"
  cp -r "$HERE/.lake/build/lib" "$dir/.lake/build/"
  if "$Z3_PYTHON" "$HERE/mutants.py" apply "$name" "$dir" 2>"$dir.log"; then
    got="$(mutant_outcome "$dir" "$dir.log")"
  else got="not applied"; fi
  printf '%s|%s|%s|%s\n' "$name" "$expected" "$got" $(($(date +%s) - start)) >"$dir.result"
  rm -rf "$dir"
}

run_mutants() {
  mkdir -p "$SCRATCH/mutants"
  local running=0 name expected
  while IFS=$'\t' read -r name expected; do
    if [[ "$running" -ge "$JOBS" ]]; then
      wait -n || true
      running=$((running - 1))
    fi
    run_one_mutant "$name" "$expected" &
    running=$((running + 1))
  done < <("$Z3_PYTHON" "$HERE/mutants.py" list)
  wait || true
  local result
  for result in "$SCRATCH"/mutants/*.result; do
    IFS='|' read -r name expected got secs <"$result"
    step "mutant $name" "$expected" "$got" "$secs"
  done
}

run_smt() {
  "$Z3_PYTHON" -c 'import z3' 2>/dev/null || {
    echo "$Z3_PYTHON cannot import z3: $INSTALL_HINT" >&2
    exit 2
  }
  local script start status
  for script in overflow dart_sql; do
    start=$(date +%s)
    status=0
    "$Z3_PYTHON" "$SMT/$script.py" "$MODE" >"$SCRATCH/$script.log" 2>&1 || status=$?
    cat "$SCRATCH/$script.log"
    step "z3 $script.py $MODE" "exit 0" "exit $status" $(($(date +%s) - start))
  done
}

[[ "$ONLY" == "smt" ]] || run_lean
[[ "$ONLY" == "lean" ]] || run_smt

echo
printf '%-6s %-40s %-28s %-28s %6s\n' "result" "step" "expected" "got" "time"
printf '%s\n' "${RESULTS[@]}"
echo "$((${#RESULTS[@]} - FAILED))/${#RESULTS[@]} steps as expected ($MODE mode, $(($(date +%s) - START_ALL))s wall)"
[[ "$FAILED" -eq 0 ]]
