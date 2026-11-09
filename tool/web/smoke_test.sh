#!/usr/bin/env bash
# Smoke test of a deployed web app: the app shell, the SPA fallback, the
# security headers and the Android App Links file.
#
#   tool/web/smoke_test.sh https://maalik-e-makaan.vercel.app io.github.ar27111994.maalik_e_makaan [SUPABASE_URL]
#
# With SUPABASE_URL, the Content-Security-Policy must allow that project.
set -euo pipefail

base="${1:?usage: smoke_test.sh BASE_URL ANDROID_PACKAGE [SUPABASE_URL]}"
package="${2:?usage: smoke_test.sh BASE_URL ANDROID_PACKAGE [SUPABASE_URL]}"
supabase="${3:-}"
supabase="${supabase%/}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "::error::$*"
  failures=$((failures + 1))
}

# fetch PATH: the body goes to $work/body, the headers to $work/headers.
fetch() {
  curl -sS --max-time 30 --retry 5 --retry-delay 5 --retry-all-errors \
    -D "$work/headers" -o "$work/body" -w '%{http_code}' "$base$1"
}

header() {
  grep -i "^$1:" "$work/headers" | tail -n 1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//'
}

# Just after `vercel deploy --prod`, the production address can still answer
# from before it moved to the new deployment (on 2026-11-09 the first site
# deploy answered 404 a second later and 200 soon after). Wait up to two
# minutes for the home page before checking anything. One short request per
# try (fetch retries, and under set -e a refused connection would end the
# script), so the wait cannot outlast the two minutes by much.
deadline=$((SECONDS + 120))
while :; do
  status="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$base/" || true)"
  [[ "$status" == 200 ]] && break
  if ((SECONDS >= deadline)); then
    echo "/ still answered $status after two minutes; checking anyway"
    break
  fi
  echo "/ answered $status; waiting for the deployment"
  sleep 5
done

for path in / /auth/callback?code=smoke-test "/invite/smoke-test-$RANDOM"; do
  status="$(fetch "$path")"
  if [[ "$status" != 200 ]]; then
    fail "$path answered $status"
  elif ! grep -q 'flutter_bootstrap.js' "$work/body"; then
    fail "$path did not serve the app's index.html"
  else
    echo "$path: 200, the app's index.html"
  fi
  csp="$(header content-security-policy)"
  [[ "$csp" == *"frame-ancestors 'none'"* ]] || fail "$path lacks the Content-Security-Policy"
  if [[ -n "$supabase" && "$csp" != *"connect-src 'self' $supabase "* ]]; then
    fail "$path: the Content-Security-Policy does not allow $supabase"
  fi
  [[ "$(header strict-transport-security)" == max-age=* ]] || fail "$path lacks HSTS"
  [[ "$(header x-content-type-options)" == nosniff ]] || fail "$path lacks nosniff"
  # index.html must be revalidated on every load, or a deploy reaches users late.
  cache="$(header cache-control)"
  [[ "$cache" == *no-cache* || "$cache" == *max-age=0* ]] || fail "$path is cached: $cache"
done

status="$(fetch /.well-known/assetlinks.json)"
type="$(header content-type)"
if [[ "$status" != 200 ]]; then
  fail "assetlinks.json answered $status"
elif [[ "$type" != application/json* ]]; then
  fail "assetlinks.json is served as $type"
elif ! jq -e --arg package "$package" \
  'any(.[]; .target.package_name == $package
    and (.relation | index("delegate_permission/common.handle_all_urls")))' \
  "$work/body" >/dev/null; then
  fail "assetlinks.json does not delegate to $package"
else
  echo "/.well-known/assetlinks.json: 200, $type, delegates to $package"
fi

if ((failures > 0)); then
  echo "$failures smoke check(s) failed"
  exit 1
fi
echo "Smoke test passed for $base"
