#!/usr/bin/env bash
# Runs every formal-verification track (formal/README.md) in one mode and
# fails if any track reports a mismatch. Every track runs, even after one
# fails, and a summary lists each one's verdict line and wall time.
#
#   tool/formal/verify.sh [ci|all] [track ...]
#
# ci   each track's fast set (what CI runs: `make verify`)
# all  every configuration, mutant and cross-check (`make verify-all`);
#      formal/bend all also needs Dart and a PostgreSQL 16 server.
#
# A track is a directory under formal/ with a run.sh (formal/lean also runs
# formal/smt). Name tracks to run only those, e.g. `verify.sh ci tla/RateLimit`.
# The tools come from tool/formal/install.sh (.cache/formal/env.sh); each
# run.sh reads them itself.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
MODE="${1:-ci}"
case "$MODE" in
  ci | all) ;;
  *)
    echo "usage: $0 [ci|all] [track ...]" >&2
    exit 2
    ;;
esac
shift || true

TRACKS=(
  tla/Invitations
  tla/Membership
  tla/StorageCleanup
  tla/LedgerPayments
  tla/LateFees
  tla/RateLimit
  lean
  bend
)
if [[ $# -gt 0 ]]; then
  TRACKS=("$@")
fi
for track in "${TRACKS[@]}"; do
  [[ -x "$REPO/formal/$track/run.sh" ]] || {
    echo "verify.sh: no track formal/$track (no executable run.sh)" >&2
    exit 2
  }
done

LOGS="$(mktemp -d "${TMPDIR:-/tmp}/formal-verify.XXXXXX")"
SUMMARY=()
FAILED=0
START_ALL=$(date +%s)
for track in "${TRACKS[@]}"; do
  echo
  echo "=== formal/$track/run.sh $MODE"
  log="$LOGS/${track//\//-}.log"
  start=$(date +%s)
  status=0
  "$REPO/formal/$track/run.sh" "$MODE" 2>&1 | tee "$log" || status=$?
  secs=$(($(date +%s) - start))
  # The runners end with "N/N ... as expected (...)" or "Total: ... mismatches".
  verdict="$(grep -E 'as expected|^Total: ' "$log" | tail -1 || true)"
  if [[ $status -eq 0 ]]; then
    result=ok
  else
    result=FAIL
    FAILED=$((FAILED + 1))
  fi
  SUMMARY+=("$(printf '%-6s %-22s %6ss  %s' "$result" "$track" "$secs" "${verdict:-exit $status}")")
done

echo
echo "=== formal verification, $MODE mode: $((${#TRACKS[@]} - FAILED))/${#TRACKS[@]} tracks as expected, $(($(date +%s) - START_ALL))s wall"
printf '%s\n' "${SUMMARY[@]}"
echo "(full output of each track in $LOGS)"
[[ $FAILED -eq 0 ]]
