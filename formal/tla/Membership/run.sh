#!/usr/bin/env bash
# Runs this directory's TLC configurations (cfg/*.cfg) and checks each one
# against the outcome its header expects:
#
#   \* EXPECT: pass                  no error
#   \* EXPECT: violates <Invariant>  TLC reports that invariant violated
#   \* EXPECT: temporal <Property>   TLC reports the (only) temporal property violated
#   \* MODE: ci | all                ci configurations also run in "all"
#   \* SPEC: <Module>                optional; default: the only *.tla here
#
# A mismatch in either direction (an expected violation that does not
# happen, or an unexpected one, or a TLC error) fails the run.
#
#   run.sh [ci|all] [name-filter]
#
# Environment: TLA2TOOLS (tla2tools.jar, TLC 2.19; default
# .cache/formal/tla2tools.jar in the repository; java on PATH), TLC_JOBS (configs
# checked at once, default 2), TLC_WORKERS (workers per TLC, default 1).
# Keep TLC_JOBS x TLC_WORKERS within the CPUs you may use. Scratch (copies
# of the specs, TLC state, logs) goes under ${TMPDIR:-/tmp}; it is kept
# when a configuration fails, or always with KEEP_LOGS=1.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-ci}"
FILTER="${2:-}"
case "$MODE" in
  ci | all) ;;
  *)
    echo "usage: $0 [ci|all] [name-filter]" >&2
    exit 2
    ;;
esac

REPO="$(cd "$HERE/../../.." && pwd)"
TLA2TOOLS="${TLA2TOOLS:-$REPO/.cache/formal/tla2tools.jar}"
JOBS="${TLC_JOBS:-2}"
WORKERS="${TLC_WORKERS:-1}"
[[ -f "$TLA2TOOLS" ]] || {
  echo "tla2tools.jar (TLC 2.19) not found at $TLA2TOOLS:" \
    "set TLA2TOOLS to it, or put it at .cache/formal/tla2tools.jar in the repository" >&2
  exit 2
}
command -v java >/dev/null || {
  echo "java not found on PATH" >&2
  exit 2
}

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/tla-$(basename "$HERE").XXXXXX")"
FAILED=0
cleanup() {
  if [[ "${KEEP_LOGS:-0}" == "1" || "$FAILED" != "0" ]]; then
    echo "logs kept in $SCRATCH"
  else
    rm -rf "$SCRATCH"
  fi
}
trap cleanup EXIT

header() { sed -n "s/^\\\\\\* $1: *//p" "$2" | head -1; }

default_spec() {
  local specs=("$HERE"/*.tla)
  if [[ ${#specs[@]} -ne 1 ]]; then
    echo "several specs here: name one with '\\* SPEC:'" >&2
    exit 2
  fi
  basename "${specs[0]}" .tla
}

outcome() { # log cfg -> pass | violates X | temporal Y | deadlock | error
  local log="$1" cfg="$2" inv
  if grep -q "^Model checking completed. No error has been found." "$log"; then
    echo "pass"
  elif inv="$(grep -oE "^Error: Invariant [A-Za-z0-9_]+ is violated" "$log" | head -1)" && [[ -n "$inv" ]]; then
    echo "violates $(awk '{print $3}' <<<"$inv")"
  elif grep -q "^Error: Temporal properties were violated" "$log"; then
    echo "temporal $(awk '/^PROPERTIES/{getline; print $1; exit} /^PROPERTY /{print $2; exit}' "$cfg")"
  elif grep -q "^Error: Deadlock reached" "$log"; then
    echo "deadlock"
  else
    echo "error"
  fi
}

run_one() { # cfg -> writes $SCRATCH/<name>/result
  local cfg="$1" name expected spec work start secs got states result
  name="$(basename "$cfg" .cfg)"
  expected="$(header EXPECT "$cfg")"
  spec="$(header SPEC "$cfg")"
  [[ -n "$spec" ]] || spec="$(default_spec)"
  work="$SCRATCH/$name"
  mkdir -p "$work"
  cp "$HERE"/*.tla "$work/"
  cp "$cfg" "$work/MC.cfg"
  start=$(date +%s)
  (cd "$work" && java -XX:+UseParallelGC -Djava.io.tmpdir="$work" -cp "$TLA2TOOLS" tlc2.TLC \
    -workers "$WORKERS" -metadir "$work/states" -config MC.cfg "$spec.tla" >"$work/tlc.log" 2>&1) || true
  secs=$(($(date +%s) - start))
  got="$(outcome "$work/tlc.log" "$work/MC.cfg")"
  states="$(grep -oE "[0-9]+ distinct states found" "$work/tlc.log" | tail -1 | awk '{print $1}')"
  if [[ "$got" == "$expected" ]]; then
    result="ok"
    rm -rf "$work/states"
  else result="FAIL"; fi
  printf '%-6s %-36s %-38s %-38s %5ss %10s\n' "$result" "$name" "$expected" "$got" "$secs" "${states:--}" \
    >"$work/result"
}

SELECTED=()
for cfg in "$HERE"/cfg/*.cfg; do
  name="$(basename "$cfg" .cfg)"
  [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && continue
  [[ "$MODE" == "ci" && "$(header MODE "$cfg")" != "ci" ]] && continue
  [[ -n "$(header EXPECT "$cfg")" ]] || {
    echo "$name: no EXPECT header" >&2
    exit 2
  }
  SELECTED+=("$cfg")
done
[[ ${#SELECTED[@]} -gt 0 ]] || {
  echo "no configuration matched" >&2
  exit 1
}

START_ALL=$(date +%s)
running=0
for cfg in "${SELECTED[@]}"; do
  if [[ "$running" -ge "$JOBS" ]]; then
    wait -n || true
    running=$((running - 1))
  fi
  run_one "$cfg" &
  running=$((running + 1))
done
wait || true

printf '%-6s %-36s %-38s %-38s %6s %10s\n' "result" "configuration" "expected" "got" "time" "states"
TOTAL=0
for cfg in "${SELECTED[@]}"; do
  name="$(basename "$cfg" .cfg)"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$SCRATCH/$name/result" ]]; then
    line="$(cat "$SCRATCH/$name/result")"
  else
    line="FAIL   $name (no result)"
  fi
  echo "$line"
  [[ "$line" == ok* ]] || FAILED=$((FAILED + 1))
done

echo "$((TOTAL - FAILED))/$TOTAL configurations as expected ($MODE mode, $(($(date +%s) - START_ALL))s wall, $JOBS jobs x $WORKERS workers)"
[[ "$FAILED" -eq 0 ]]
