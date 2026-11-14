#!/usr/bin/env bash
# Smoke test of an address that sends people on to another origin: an earlier
# address of the website or the web app, or an alias such as www
# (contracts/origins.json, decision D-20).
#
# Without --page (the website's earlier address, www): `/` and a deeper path
# with a query must answer 308 with a Location on TO that keeps the path and
# the query.
#
# With --page (the web app's earlier address): the same two must answer 200
# with the page that clears what the app kept in the browser there and then
# goes to TO (tool/web/package_vercel.py): the header Clear-Site-Data:
# "storage" and nothing more, TO as the page's destination, its script and its
# way on without scripts; and the script must be served. The script keeps the
# path, the query and the #fragment (tool/web/test_moved_js.py).
#
# Each --keep path must answer 200 where it is, without a redirect and without
# Clear-Site-Data.
#
#   tool/web/redirect_smoke_test.sh https://old-site.example.org https://example.pk
#   tool/web/redirect_smoke_test.sh https://old-app.example.org https://app.example.pk --page \
#     --keep '/auth/callback?code=smoke-test' --keep /.well-known/assetlinks.json
#   tool/web/redirect_smoke_test.sh http://127.0.0.1:8080 https://app.example.pk --page \
#     --host old-app.example.org --keep /.well-known/assetlinks.json
#
# --host sends that Host header, so a local server (tool/web/serve_output.py)
# answers as that address would. The Deploy workflow and CI take FROM and TO
# from contracts/origins.json.
set -euo pipefail

usage="usage: redirect_smoke_test.sh FROM TO [--page] [--host HOST] [--keep PATH]..."
from="${1:?$usage}"
to="${2:?$usage}"
shift 2
from="${from%/}"
to="${to%/}"
host=""
page=false
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
    --page)
      page=true
      shift
      ;;
    *)
      echo "$usage" >&2
      exit 2
      ;;
  esac
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# A request that gets no answer writes no headers; they then read as none.
: >"$work/headers"
failures=0
headers=()
[[ -z "$host" ]] || headers=(-H "Host: $host")
name="${host:-$from}"

fail() {
  echo "::error::$*"
  failures=$((failures + 1))
}

# fetch PATH: the status; the headers go to $work/headers, the body to $work/body. Redirects
# are not followed.
fetch() {
  curl -sS --max-time 30 --retry 5 --retry-delay 5 --retry-all-errors \
    "${headers[@]}" -D "$work/headers" -o "$work/body" -w '%{http_code}' "$from$1"
}

# header NAME: the value of that response header, or nothing when the response has none (a
# header that is missing is a finding to report, not an error to stop on).
header() {
  { grep -i "^$1:" "$work/headers" || true; } | tail -n 1 | cut -d: -f2- | tr -d '\r' \
    | sed 's/^ *//'
}

# moved: whether / already answers as the deployment that sends people on does.
moved() {
  local status
  status="$(curl -s --max-time 10 "${headers[@]}" -D "$work/headers" -o /dev/null \
    -w '%{http_code}' "$from/" || true)"
  if $page; then
    [[ "$status" == 200 && -n "$(header clear-site-data)" ]]
  else
    [[ "$status" == 308 ]]
  fi
}

# Just after a deploy the address can still answer from the deployment before
# it (see smoke_test.sh). Wait up to two minutes for / to send people on.
deadline=$((SECONDS + 120))
until moved; do
  if ((SECONDS >= deadline)); then
    echo "/ on $name did not send people on after two minutes; checking anyway"
    break
  fi
  echo "/ on $name does not send people on yet; waiting for the deployment"
  sleep 5
done

# check_page PATH: the page that clears this address's storage and goes to TO.
check_page() {
  local path="$1" status clears cache
  status="$(fetch "$path")"
  clears="$(header clear-site-data)"
  cache="$(header cache-control)"
  if [[ "$status" != 200 ]]; then
    fail "$path on $name answered $status, not 200 with the page that sends people on"
  elif [[ "$clears" != '"storage"' ]]; then
    fail "$path on $name answers Clear-Site-Data: ${clears:-(none)}, not \"storage\" alone"
  elif [[ "$(header content-type)" != text/html* ]]; then
    fail "$path on $name is served as $(header content-type), not HTML"
  elif ! grep -qF "<meta name=\"mm-moved-to\" content=\"$to\">" "$work/body"; then
    fail "$path on $name is not the page that sends people on to $to"
  elif ! grep -qF '<script src="/moved.js"></script>' "$work/body"; then
    fail "$path on $name lacks the script that clears the storage and goes to $to"
  elif ! grep -qF "<noscript><meta http-equiv=\"refresh\" content=\"0; url=$to/\"></noscript>" \
    "$work/body"; then
    fail "$path on $name has no way on to $to without scripts"
  elif [[ -n "$(header location)" ]]; then
    fail "$path on $name also redirects, to $(header location)"
  elif [[ "$cache" != *no-cache* && "$cache" != *no-store* && "$cache" != *max-age=0* ]]; then
    fail "$path on $name is cached: $cache"
  else
    echo "$path on $name: 200, clears its storage and goes to $to"
  fi
}

for path in / "/smoke-test-$RANDOM/a/?x=1&y=%20"; do
  if $page; then
    check_page "$path"
    continue
  fi
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

if $page; then
  status="$(fetch /moved.js)"
  if [[ "$status" != 200 ]]; then
    fail "/moved.js on $name answered $status, not 200"
  elif [[ "$(header content-type)" != *javascript* ]]; then
    fail "/moved.js on $name is served as $(header content-type), which browsers refuse to run"
  elif ! grep -qF 'mm-moved-to' "$work/body" || ! grep -qF 'location.replace(' "$work/body"; then
    fail "/moved.js on $name is not the page's script"
  elif [[ -n "$(header clear-site-data)" ]]; then
    fail "/moved.js on $name carries Clear-Site-Data, which only the page should"
  else
    echo "/moved.js on $name: 200, the page's script"
  fi
fi

for path in "${keep[@]}"; do
  status="$(fetch "$path")"
  if [[ "$status" != 200 ]]; then
    fail "$path on $name answered $status, not 200 (it must keep answering there)"
  elif [[ -n "$(header clear-site-data)" ]]; then
    fail "$path on $name carries Clear-Site-Data: it must never clear the storage"
  elif $page && grep -qF 'name="mm-moved-to"' "$work/body"; then
    fail "$path on $name answered with the page that sends people on, not with what it keeps"
  else
    echo "$path on $name: 200, kept"
  fi
done

if ((failures > 0)); then
  echo "$failures check(s) of $name failed"
  exit 1
fi
echo "Smoke test passed: $name sends people on to $to"
