#!/usr/bin/env bash
# Checks the Bend proofs of the ledger's money algorithms and compares every
# step with the outcome it must have. Steps (one row each in the output):
#
#   verdict      bend PROOF.bend --verdict must print ALL PROOFS CHECK.
#   soundness    The kernel program states every law exactly as LAWS.bend
#                does, one proof per law, no @unsafe / partial def / hole.
#   use, neg     soundness/USE.bend (every law applied to concrete inputs) and
#                soundness/NEG.bend (every hypothesis is needed) must check.
#   mutant:*     Each mutant of soundness/mutants.py must FAIL with the
#                expected message; a model mutant's CEX.bend must check on
#                the mutant and FAIL on the real model.
#   fidelity:*   SPEC.bend (through its transliteration fidelity/spec.py)
#                must match Bend's own evaluation of SPEC.bend, the real
#                mm_core Dart and the real SQL on a scratch database, with 0
#                mismatches; each spec.py mutant must be caught.
#
# Usage: run.sh [ci|all]    (default: ci)
#   ci   the verdict only (about 15 s)
#   all  every step (a few minutes; needs Dart and a PostgreSQL server)
#
# Environment (tool/formal/install.sh installs both pinned tools and writes
# .cache/formal/env.sh, which this script reads; a variable already set wins):
#   BEND          bend 2.0.39 (default: from env.sh, else bend on PATH)
#   LEAN434_HOME  Lean 4.34.0 (its bin/ goes first on PATH: --verdict builds
#                 BendTT's kernel with it, into ~/.bend/bendtt). Default: from
#                 env.sh, else lean on PATH if it is 4.34.0.
#   DART          dart (all only; default: dart on PATH, else
#                 /opt/flutter/bin/dart). The pub workspace must be resolved
#                 (.dart_tool/package_config.json, `make bootstrap`).
#   PGHOST, PGPORT, PGUSER
#                 the PostgreSQL 16 server for the SQL checks (all only;
#                 defaults from tool/db/env.sh). The run creates the database
#                 FVBEND_DB (default fvbend_<pid>) and drops it at the end.
#   PYTHON        python3 (default python3)
#   TMPDIR        scratch root; the run uses a fresh directory below it
# LEAN_HOME, Z3_PYTHON and TLA2TOOLS belong to the other formal tracks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
PYTHON="${PYTHON:-python3}"
# nothing is written next to the sources, not even __pycache__
export PYTHONDONTWRITEBYTECODE=1
MODE="${1:-ci}"
case "$MODE" in
  ci | all) ;;
  *)
    echo "usage: run.sh [ci|all]" >&2
    exit 2
    ;;
esac

# The pinned tools of tool/formal/install.sh, unless set already.
if [[ -f "$REPO/.cache/formal/env.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/.cache/formal/env.sh"
fi
INSTALL_HINT="run tool/formal/install.sh, or set BEND and LEAN434_HOME"
# No update check against bend-lang.com from a verification run.
export BEND_NO_TELEMETRY=1
BEND="${BEND:-$(command -v bend || true)}"
[[ -n "$BEND" && -x "$BEND" ]] || {
  echo "run.sh: bend 2.0.39 not found (BEND='$BEND'): $INSTALL_HINT" >&2
  exit 2
}
bend_version="$("$BEND" version 2>/dev/null | head -1 || true)"
[[ "$bend_version" == "bend 2.0.39" ]] || {
  echo "run.sh: needs bend 2.0.39, '$BEND' is ${bend_version:-not runnable}: $INSTALL_HINT" >&2
  exit 2
}
if [[ -n "${LEAN434_HOME:-}" ]]; then
  PATH="$LEAN434_HOME/bin:$PATH"
fi
export PATH
lean_version="$(lean --version 2>/dev/null || true)"
[[ "$lean_version" == *"version 4.34.0"* ]] || {
  echo "run.sh: --verdict needs Lean 4.34.0, found: ${lean_version:-no lean}: $INSTALL_HINT" >&2
  exit 2
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bend-proofs.XXXXXX")"
LOGS="$WORK/logs"
SRC="$WORK/src"
mkdir -p "$LOGS" "$SRC/soundness"
cp "$HERE"/SPEC.bend "$HERE"/LAWS.bend "$HERE"/PROOF.bend "$SRC/"
cp "$HERE"/soundness/USE.bend "$HERE"/soundness/NEG.bend "$SRC/soundness/"

echo "Bend: $BEND ($bend_version); Lean $(grep -o 'version [0-9.]*' <<<"$lean_version")"
echo "Mode: $MODE, logs in $LOGS"
printf '%-8s %-44s %-40s %-8s %s\n' RESULT STEP EXPECTED SECONDS DETAIL

failures=0
steps=0
total_start=$(date +%s)
# row RESULT STEP EXPECTED SECONDS DETAIL
row() {
  steps=$((steps + 1))
  [[ "$1" == OK ]] || failures=$((failures + 1))
  printf '%-8s %-44s %-40s %-8s %s\n' "$@"
}

# check STEP DIR EXPECTED-OUTCOME (pass|fail) EXPECTED-TEXT LOG -- COMMAND...
# Runs COMMAND in DIR. pass: exit 0 and EXPECTED-TEXT on a line of its own.
# fail: a non-zero exit and EXPECTED-TEXT somewhere in the output.
check() {
  local step="$1" dir="$2" outcome="$3" text="$4" log="$5"
  shift 6
  local start rc verdict=MISMATCH detail
  start=$(date +%s)
  set +e
  (cd "$dir" && "$@") </dev/null >"$log" 2>&1
  rc=$?
  set -e
  if [[ "$outcome" == pass && $rc -eq 0 ]] && grep -qxF -- "$text" "$log"; then
    verdict=OK
  elif [[ "$outcome" == fail && $rc -ne 0 ]] && grep -qF -- "$text" "$log"; then
    verdict=OK
  fi
  detail="exit $rc: $(grep -m1 -vE '^\s*$' "$log" | cut -c1-70)"
  row "$verdict" "$step" "$outcome: $text" "$(($(date +%s) - start))" "$detail"
  if [[ "$verdict" != OK ]]; then
    tail -8 "$log" | sed 's/^/         | /'
  fi
}

# 1. The verdict: the proofs, then BendTT's kernel (proven correct in Lean).
check verdict "$SRC" pass "ALL PROOFS CHECK" "$LOGS/verdict.log" -- "$BEND" PROOF.bend --verdict
law_count="$(grep -c '^law ' "$SRC/LAWS.bend")"
echo "         laws in LAWS.bend: $law_count"

if [[ "$MODE" == all ]]; then
  # 2. Static soundness: statements in the kernel program, escape hatches.
  start=$(date +%s)
  if (cd "$SRC" && "$BEND" PROOF.bend -o PROOF.bendtt) >"$LOGS/bendtt.log" 2>&1; then
    check soundness "$SRC" pass "SOUNDNESS CHECKS PASS" "$LOGS/soundness.log" -- \
      "$PYTHON" "$HERE/soundness/check_soundness.py" "$SRC" "$SRC/PROOF.bendtt"
  else
    row MISMATCH soundness "pass: SOUNDNESS CHECKS PASS" "$(($(date +%s) - start))" "bend -o PROOF.bendtt failed"
  fi
  check use "$SRC/soundness" pass "ALL PROOFS CHECK" "$LOGS/use.log" -- "$BEND" USE.bend --verdict
  check neg "$SRC/soundness" pass "ALL PROOFS CHECK" "$LOGS/neg.log" -- "$BEND" NEG.bend --verdict

  # 3. Mutants.
  MUT="$WORK/mutants"
  "$PYTHON" "$HERE/soundness/mutants.py" "$SRC" "$MUT" >"$LOGS/mutants.log"
  mkdir -p "$WORK/control"
  cp "$SRC"/SPEC.bend "$WORK/control/"
  while IFS=$'\t' read -r name command expect cex laws; do
    flag=--check-only
    [[ "$command" == verdict ]] && flag=--verdict
    check "mutant:$name" "$MUT/$name" fail "$expect" "$LOGS/mutant-$name.log" -- "$BEND" PROOF.bend "$flag"
    if [[ "$cex" == cex ]]; then
      check "  cex on mutant ($laws)" "$MUT/$name" pass "ALL PROOFS CHECK" "$LOGS/cex-$name.log" -- \
        "$BEND" CEX.bend --check-only
      cp "$MUT/$name/CEX.bend" "$WORK/control/CEX.bend"
      check "  cex on the real model" "$WORK/control" fail "SOME PROOFS FAIL" "$LOGS/cex-control-$name.log" -- \
        "$BEND" CEX.bend --check-only
    fi
  done <"$MUT/manifest.tsv"

  # 4. Fidelity: SPEC.bend against Bend itself, the real Dart and the real SQL.
  FID="$WORK/fidelity"
  "$PYTHON" "$HERE/fidelity/gen_cases.py" "$FID" "$REPO/supabase/tests/database/_helpers.psql" \
    >"$LOGS/gen_cases.log"
  sed 's/^/         /' "$LOGS/gen_cases.log"
  cp "$SRC/SPEC.bend" "$FID/eval/"
  start=$(date +%s)
  if (cd "$FID/eval" && "$BEND" main.bend) >"$FID/eval/out.txt" 2>"$LOGS/eval.log"; then
    echo "         bend main.bend (SPEC.bend evaluated by Bend): $(($(date +%s) - start))s"
    check "fidelity:bend" "$FID" pass "FIDELITY: all parts match" "$LOGS/fidelity-bend.log" -- \
      "$PYTHON" "$HERE/fidelity/compare.py" "$FID" bend
  else
    row MISMATCH "fidelity:bend" "pass: FIDELITY: all parts match" "$(($(date +%s) - start))" "bend main.bend failed"
  fi

  if [[ -z "${DART:-}" ]]; then
    DART="$(command -v dart || echo /opt/flutter/bin/dart)"
  fi
  start=$(date +%s)
  if (cd "$REPO" && "$DART" --packages="$REPO/.dart_tool/package_config.json" \
    "$HERE/fidelity/dart_cases.dart" "$FID/dart_cases.json" "$FID/dart_results.json") \
    >"$LOGS/dart.log" 2>&1; then
    echo "         dart_cases.dart (real mm_core): $(($(date +%s) - start))s"
    check "fidelity:dart" "$FID" pass "FIDELITY: all parts match" "$LOGS/fidelity-dart.log" -- \
      "$PYTHON" "$HERE/fidelity/compare.py" "$FID" dart
  else
    row MISMATCH "fidelity:dart" "pass: FIDELITY: all parts match" "$(($(date +%s) - start))" \
      "dart failed (DART=$DART; see $LOGS/dart.log)"
  fi

  # shellcheck source=tool/db/env.sh
  source "$REPO/tool/db/env.sh"
  export MM_TEST_DB="${FVBEND_DB:-fvbend_$$}"
  [[ "$MM_TEST_DB" =~ ^[a-z0-9_]+$ ]] || {
    echo "run.sh: FVBEND_DB must be a plain lower-case name" >&2
    exit 2
  }
  drop_db() {
    psql -X -q -d postgres -c "drop database if exists ${MM_TEST_DB} with (force)" >/dev/null 2>&1 || true
  }
  trap drop_db EXIT
  start=$(date +%s)
  sql_ok=1
  "$REPO/tool/db/reset.sh" >"$LOGS/db-reset.log" 2>&1 || sql_ok=0
  for script in pure fifo billing; do
    [[ $sql_ok -eq 1 ]] || break
    psql -X -q -v ON_ERROR_STOP=1 -d "$MM_TEST_DB" -f "$FID/sql/$script.sql" >"$LOGS/sql-$script.log" 2>&1 || sql_ok=0
  done
  echo "         scratch database and SQL scripts: $(($(date +%s) - start))s"
  if [[ $sql_ok -eq 1 ]]; then
    check "fidelity:sql (database $MM_TEST_DB)" "$FID" pass "FIDELITY: all parts match" "$LOGS/fidelity-sql.log" -- \
      "$PYTHON" "$HERE/fidelity/compare.py" "$FID" sql
  else
    row MISMATCH "fidelity:sql" "pass: FIDELITY: all parts match" "$(($(date +%s) - start))" \
      "the database or a script failed (PGHOST=$PGHOST PGPORT=$PGPORT; logs in $LOGS)"
  fi
  drop_db
  trap - EXIT
  sed -n 's/^\(.*cases, [0-9]* mismatches\)$/         \1/p' \
    "$LOGS/fidelity-bend.log" "$LOGS/fidelity-dart.log" "$LOGS/fidelity-sql.log" 2>/dev/null || true

  for mutant in sql_prorate_no_least fee_cap_before_rounding billed_ignores_prorate_flag alloc_cap_per_charge; do
    if [[ $sql_ok -eq 1 && -f "$FID/dart_results.json" ]]; then
      check "fidelity mutant:$mutant" "$FID" pass "MUTANT CAUGHT" "$LOGS/fidelity-mutant-$mutant.log" -- \
        "$PYTHON" "$HERE/fidelity/compare.py" "$FID" dart sql "mutant=$mutant"
    else
      row MISMATCH "fidelity mutant:$mutant" "pass: MUTANT CAUGHT" 0 "no Dart or SQL results to compare"
    fi
  done
fi

echo "Total: $steps steps, $failures mismatches, $(($(date +%s) - total_start))s"
if [[ $failures -ne 0 ]]; then
  echo "FAILED (logs kept in $LOGS)"
  exit 1
fi
echo "PASSED (logs in $LOGS)"
