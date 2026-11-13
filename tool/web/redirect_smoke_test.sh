#!/usr/bin/env bash
# Smoke test of an address that redirects permanently to another origin: an
# earlier address of the website or the web app, or an alias such as www
# (contracts/origins.json, decision D-20). `/` and a deeper path with a query
# must answer 308 with a Location on TO that keeps the path and the query, and
# each --keep path must answer 200 where it is, without a redirect.
#
#   tool/web/redirect_smoke_test.sh https://old-app.example.org https://app.example.pk \
#     --keep '/auth/callback?code=smoke-test' --keep /.well-known/assetlinks.json
#   tool/web/redirect_smoke_test.sh http://127.0.0.1:8080 https://app.example.pk \
#     --host old-app.example.org --keep /.well-known/assetlinks.json
#
# --host sends that Host header, so a local server (tool/web/serve_output.py)
# answers as that address would. The Deploy workflow and CI take FROM and TO
# from contracts/origins.json.
set -euo pipefail

usage="usage: redirect_smoke_test.sh FROM TO [--host HOST] [--keep PATH]..."
from="${1:?$usage}"
to="${2:?$usage}"
shift 2
from="${from%/}"
to="${to%/}"
host=""
keep=()
while (($# > 0)); do
  case "$1" in
    --host)
      host="${2:?$usage}"
      shift 2
      ;;
    --keep)
      keep+=("${2:?$usage}")
      shift 2
      ;;
    *)
      echo "$usage" >&2
      exit 2
      ;;
  esac
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
headers=()
[[ -z "$host" ]] || headers=(-H "Host: $host")
name="${host:-$from}"

fail() {
  echo "::error::$*"
  failures=$((failures + 1))
}

# fetch PATH: the status; the headers go to $work/headers. Redirects are not followed.
fetch() {
  curl -sS --max-time 30 --retry 5 --retry-delay 5 --retry-all-errors \
    "${headers[@]}" -D "$work/headers" -o /dev/null -w '%{http_code}' "$from$1"
}

header() {
  grep -i "^$1:" "$work/headers" | tail -n 1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//'
}

# Just after a deploy the address can still answer from the deployment before
# it (see smoke_test.sh). Wait up to two minutes for / to redirect.
deadline=$((SECONDS + 120))
while :; do
  status="$(curl -s --max-time 10 "${headers[@]}" -o /dev/null -w '%{http_code}' "$from/" || true)"
  [[ "$status" == 308 ]] && break
  if ((SECONDS >= deadline)); then
    echo "/ on $name still answered $status after two minutes; checking anyway"
    break
  fi
  echo "/ on $name answered $status; waiting for the deployment"
  sleep 5
done

for path in / "/smoke-test-$RANDOM/a/?x=1&y=%20"; do
  status="$(fetch "$path")"
  location="$(header location)"
  if [[ "$status" != 308 ]]; then
    fail "$path on $name answered $status, not 308"
  elif [[ "$location" != "$to$path" ]]; then
    fail "$path on $name redirects to $location, not $to$path"
  else
    echo "$path on $name: 308 to $location"
  fi
done

for path in "${keep[@]}"; do
  status="$(fetch "$path")"
  if [[ "$status" != 200 ]]; then
    fail "$path on $name answered $status, not 200 (it must keep answering there)"
  else
    echo "$path on $name: 200, kept"
  fi
done

if ((failures > 0)); then
  echo "$failures redirect check(s) failed"
  exit 1
fi
echo "Redirect smoke test passed: $name to $to"
