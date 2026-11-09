#!/usr/bin/env bash
# Smoke test of the deployed website (website/, the Astro site): the home pages
# in both languages and the files for crawlers answer 200 with the security
# headers of website/vercel.json, a missing page answers 404, and the site was
# built for the expected address.
#
#   tool/web/site_smoke_test.sh https://maalik-e-makaan-site.vercel.app [SITE_URL]
#
# SITE_URL (default: the base URL) is the address the build was given: the
# canonical links, robots.txt and the sitemap must use it. Pass it when testing
# a local server; after a deploy the two are the same.
set -euo pipefail

base="${1:?usage: site_smoke_test.sh BASE_URL [SITE_URL]}"
base="${base%/}"
site="${2:-$base}"
site="${site%/}"
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
# minutes for the home page before checking anything.
for attempt in $(seq 1 24); do
  status="$(fetch /)"
  [[ "$status" == 200 ]] && break
  echo "/ answered $status; waiting for the deployment ($attempt of 24)"
  sleep 5
done

# check_headers PATH: the headers every response carries (website/vercel.json).
check_headers() {
  local csp
  csp="$(header content-security-policy)"
  [[ "$csp" == *"default-src 'none'"* && "$csp" == *"frame-ancestors 'none'"* &&
    "$csp" == *"require-trusted-types-for 'script'"* ]] \
    || fail "$1 lacks the Content-Security-Policy"
  [[ "$(header strict-transport-security)" == max-age=* ]] || fail "$1 lacks HSTS"
  [[ "$(header x-content-type-options)" == nosniff ]] || fail "$1 lacks nosniff"
  [[ "$(header x-frame-options)" == DENY ]] || fail "$1 lacks X-Frame-Options: DENY"
  [[ "$(header referrer-policy)" == strict-origin-when-cross-origin ]] \
    || fail "$1 lacks the Referrer-Policy"
  [[ "$(header permissions-policy)" == *"camera=()"* ]] || fail "$1 lacks the Permissions-Policy"
  [[ "$(header cross-origin-opener-policy)" == same-origin ]] \
    || fail "$1 lacks Cross-Origin-Opener-Policy"
}

# path, the type it must be served as, and a string its body must contain.
checks=(
  "/|text/html|<link rel=\"canonical\" href=\"$site/\">"
  "/ur/|text/html|<link rel=\"canonical\" href=\"$site/ur/\">"
  "/robots.txt|text/plain|Sitemap: $site/sitemap-index.xml"
  "/sitemap-index.xml|xml|$site/sitemap-0.xml"
  "/llms.txt|text/plain|# "
)
for check in "${checks[@]}"; do
  IFS='|' read -r path type expected <<<"$check"
  status="$(fetch "$path")"
  served="$(header content-type)"
  if [[ "$status" != 200 ]]; then
    fail "$path answered $status"
  elif [[ "$served" != *"$type"* ]]; then
    fail "$path is served as $served"
  elif ! grep -qF -- "$expected" "$work/body"; then
    fail "$path does not contain: $expected"
  else
    echo "$path: 200, $served"
  fi
  check_headers "$path"
done

path="/smoke-test-$RANDOM/"
status="$(fetch "$path")"
[[ "$status" == 404 ]] || fail "a missing page ($path) answered $status, not 404"
check_headers "$path"
[[ "$status" != 404 ]] || echo "$path: 404"

if ((failures > 0)); then
  echo "$failures smoke check(s) failed"
  exit 1
fi
echo "Smoke test passed for $base"
