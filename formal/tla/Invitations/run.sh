#!/usr/bin/env bash
# Model-checks Invitations.tla with TLC and compares every configuration with
# the outcome its header expects:
#
#   \* Expected result: PASS.
#   \* Expected result: FAIL -- Invariant <Name> is violated.
#   \* Mode: ci | all                  (ci configurations also run in "all")
#   \* Simulate: num=N depth=D seed=S  (random simulation instead of BFS)
#
# A configuration matches when TLC exits 0 with "No error has been found" for
# PASS (a simulation: exits 0, "Finished in" and no error), or exits 12 with exactly "Error: Invariant <Name> is violated." for
# FAIL. Anything else (another invariant, a deadlock, a parse error, a TLC
# crash) is a mismatch, and any mismatch fails the run.
#
# Usage: run.sh [ci|all|<config name or file> ...]     (default: ci)
#
# Environment:
#   TLA2TOOLS     tla2tools.jar (TLC 2.19; default: from .cache/formal/env.sh,
#                 which tool/formal/install.sh writes, else
#                 .cache/formal/tla2tools.jar in the repository)
#   JAVA          java binary (default: java on PATH)
#   TLC_WORKERS   TLC worker threads (default 2)
#   TLC_HEAP      JVM heap (default 2g)
#   TMPDIR        scratch root; the run uses a fresh directory below it
# Only TLA2TOOLS is used by this track; LEAN_HOME, LEAN434_HOME, Z3_PYTHON
# and BEND belong to the other formal tracks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
# The pinned tools of tool/formal/install.sh, unless set already.
if [[ -f "$REPO/.cache/formal/env.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/.cache/formal/env.sh"
fi
TLA2TOOLS="${TLA2TOOLS:-$REPO/.cache/formal/tla2tools.jar}"
JAVA="${JAVA:-java}"
TLC_WORKERS="${TLC_WORKERS:-2}"
TLC_HEAP="${TLC_HEAP:-2g}"

if [[ ! -f "$TLA2TOOLS" ]]; then
  echo "run.sh: tla2tools.jar (TLC 2.19) not found at '$TLA2TOOLS':" \
    "run tool/formal/install.sh, or set TLA2TOOLS" >&2
  exit 2
fi
command -v "$JAVA" >/dev/null 2>&1 || {
  echo "run.sh: '$JAVA' not found (set JAVA)" >&2
  exit 2
}

MODE="${1:-ci}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/invitations-tlc.XXXXXX")"
LOGS="$WORK/logs"
mkdir -p "$LOGS"
cp "$HERE/Invitations.tla" "$WORK/"

# Which configurations to run.
configs=()
case "$MODE" in
  ci | all)
    for f in "$HERE"/Invitations*.cfg; do
      mode_line="$(grep -m1 -oE '^\\\* Mode: (ci|all)' "$f" | awk '{print $3}')"
      if [[ -z "$mode_line" ]]; then
        echo "run.sh: $(basename "$f") has no Mode line" >&2
        exit 2
      fi
      if [[ "$MODE" == all || "$mode_line" == ci ]]; then
        configs+=("$(basename "$f")")
      fi
    done
    ;;
  *)
    for arg in "$@"; do
      name="$(basename "$arg")"
      [[ "$name" == *.cfg ]] || name="$name.cfg"
      [[ -f "$HERE/$name" ]] || {
        echo "run.sh: no configuration $name" >&2
        exit 2
      }
      configs+=("$name")
    done
    ;;
esac

tlc_banner="$("$JAVA" -cp "$TLA2TOOLS" tlc2.TLC -version 2>/dev/null || true)"
echo "TLC: $TLA2TOOLS ($(grep -m1 -o 'Version [0-9.]*' <<<"$tlc_banner" || echo 'version unknown'))"
echo "Mode: $MODE, ${#configs[@]} configurations, $TLC_WORKERS workers, logs in $LOGS"
printf '%-8s %-52s %-44s %-10s %s\n' RESULT CONFIGURATION EXPECTED SECONDS 'STATES (distinct) / DEPTH'

failures=0
total_start=$(date +%s)
for cfg in "${configs[@]}"; do
  name="${cfg%.cfg}"
  cp "$HERE/$cfg" "$WORK/"
  expect_line="$(grep -m1 -E '^\\\* Expected result: ' "$HERE/$cfg" || true)"
  if [[ "$expect_line" =~ Expected\ result:\ PASS ]]; then
    expect=PASS
  elif [[ "$expect_line" =~ Expected\ result:\ FAIL\ --\ Invariant\ ([A-Za-z0-9_]+)\ is\ violated ]]; then
    expect="${BASH_REMATCH[1]}"
  else
    echo "run.sh: $cfg has no valid 'Expected result' line" >&2
    exit 2
  fi
  sim_args=()
  sim_line="$(grep -m1 -E '^\\\* Simulate: ' "$HERE/$cfg" || true)"
  if [[ -n "$sim_line" ]]; then
    num="$(sed -nE 's/.*num=([0-9]+).*/\1/p' <<<"$sim_line")"
    depth="$(sed -nE 's/.*depth=([0-9]+).*/\1/p' <<<"$sim_line")"
    seed="$(sed -nE 's/.*seed=([0-9]+).*/\1/p' <<<"$sim_line")"
    sim_args=(-simulate "num=$num" -depth "$depth" -seed "$seed")
  fi

  log="$LOGS/$name.log"
  start=$(date +%s)
  set +e
  (cd "$WORK" && "$JAVA" -XX:+UseParallelGC -Xmx"$TLC_HEAP" -Djava.io.tmpdir="$WORK" \
    -cp "$TLA2TOOLS" tlc2.TLC -workers "$TLC_WORKERS" -cleanup \
    -metadir "$WORK/states/$name" "${sim_args[@]}" -config "$cfg" Invitations.tla) >"$log" 2>&1
  rc=$?
  set -e
  secs=$(($(date +%s) - start))

  got="$(grep -m1 -oE 'Error: Invariant [A-Za-z0-9_]+ is violated\.|Deadlock reached|No error has been found' "$log" || true)"
  # A simulation that reaches num= traces says only "Finished in ...": TLC
  # 2.19 prints no "No error has been found" for it. Exit 0, that line and no
  # error at all is its pass.
  if [[ -n "$sim_line" && -z "$got" && $rc -eq 0 ]] && grep -q '^Finished in' "$log" \
    && ! grep -q '^Error' "$log"; then
    got="No error has been found"
  fi
  stats="$(grep -E 'states generated' "$log" | tail -1 | sed -E 's/^([0-9,]+) states generated, ([0-9,]+) distinct states found.*/\1 (\2)/' || true)"
  depth_found="$(grep -oE 'depth of the complete state graph search is [0-9]+' "$log" | grep -oE '[0-9]+$' || true)"
  if [[ -n "$sim_line" ]]; then
    # || true: a TLC error prints none of these, and must still be reported.
    stats="simulation: $(grep -oE '[0-9,]+ states checked|checked [0-9,]+ states|[0-9,]+ traces' "$log" | head -2 | tr '\n' ' ' || true)"
  fi

  verdict=MISMATCH
  if [[ "$expect" == PASS && $rc -eq 0 && "$got" == "No error has been found" ]]; then
    verdict=OK
  elif [[ "$expect" != PASS && $rc -eq 12 && "$got" == "Error: Invariant $expect is violated." ]]; then
    verdict=OK
  fi
  shown_expect="$expect"
  [[ "$expect" != PASS ]] && shown_expect="FAIL $expect"
  printf '%-8s %-52s %-44s %-10s %s / %s\n' "$verdict" "$cfg" "$shown_expect" "$secs" "${stats:-?}" "${depth_found:--}"
  if [[ "$verdict" != OK ]]; then
    failures=$((failures + 1))
    echo "         exit $rc, TLC said: ${got:-<nothing recognisable>} (log: $log)"
    tail -5 "$log" | sed 's/^/         | /'
  fi
done

echo "Total: ${#configs[@]} configurations, $failures mismatches, $(($(date +%s) - total_start))s"
if [[ $failures -ne 0 ]]; then
  echo "FAILED (logs kept in $LOGS)"
  exit 1
fi
rm -rf "${WORK:?}/states"
echo "PASSED (logs in $LOGS)"
