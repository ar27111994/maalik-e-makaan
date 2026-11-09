#!/usr/bin/env bash
# End-to-end user acceptance tests (docs/uat.md): the release web build of
# the app, served with production's headers, driven in Chromium by Playwright
# (app/uat/) against a local Supabase stack.
#
#   tool/uat/run.sh            # start the stack if needed, build, serve, test
#
# Needs the Supabase CLI and Docker, Flutter, Node 22 and psql. Settings:
#   UAT_SUPABASE_WORKDIR the directory holding supabase/ (default: the repository)
#   UAT_RESET=1          reset the database first (supabase db reset)
#   UAT_SKIP_BUILD=1     reuse app/build/uat/web from an earlier run
#   UAT_CHROME           a Chrome or Chromium binary instead of Playwright's
#   UAT_SCREENSHOTS      a directory for the report's screenshots (docs/uat)
#   UAT_PORT             the app's port (8080: Auth's redirect URLs and the
#                        functions' APP_URL in supabase/config.toml expect it)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PORT=${UAT_PORT:-8080}
OUT=$ROOT/app/build/uat
WORKDIR=${UAT_SUPABASE_WORKDIR:-$ROOT}
SUPABASE=(supabase --workdir "$WORKDIR")
SERVICES_OFF=studio,imgproxy,logflare,vector,supavisor,realtime,postgres-meta

log() { printf '\n== %s\n' "$*"; }

# The storage-cleanup function needs a token (J10 calls it as pg_cron would).
# It is read from supabase/functions/.env when the stack starts.
ENV_FILE=$WORKDIR/supabase/functions/.env
[[ -f $ENV_FILE ]] || cp "$WORKDIR/supabase/functions/.env.example" "$ENV_FILE"
if ! grep -q '^STORAGE_CLEANUP_TOKEN=' "$ENV_FILE"; then
  if "${SUPABASE[@]}" status >/dev/null 2>&1; then
    echo "error: the stack is running without STORAGE_CLEANUP_TOKEN in $ENV_FILE;" \
      "add one (32+ characters) and restart it (supabase stop && supabase start)" >&2
    exit 2
  fi
  echo "STORAGE_CLEANUP_TOKEN=$(python3 -c 'import secrets; print(secrets.token_hex(24))')" >>"$ENV_FILE"
fi
UAT_CLEANUP_TOKEN=$(sed -n 's/^STORAGE_CLEANUP_TOKEN=//p' "$ENV_FILE" | tail -1)

if ! "${SUPABASE[@]}" status >/dev/null 2>&1; then
  log "Starting the local Supabase stack"
  "${SUPABASE[@]}" start -x "$SERVICES_OFF"
elif [[ ${UAT_RESET:-0} == 1 ]]; then
  log "Resetting the database (every migration and the seed)"
  "${SUPABASE[@]}" db reset
fi

STATUS=$("${SUPABASE[@]}" status -o json 2>/dev/null)
field() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$STATUS" "$1"; }
API_URL=$(field API_URL)
PUBLISHABLE_KEY=$(field PUBLISHABLE_KEY)
DB_URL=$(field DB_URL)
MAILPIT_URL=$(field MAILPIT_URL)

mkdir -p "$OUT"
if [[ ${UAT_SKIP_BUILD:-0} != 1 || ! -f $OUT/web/main.dart.js ]]; then
  log "Building the web app against $API_URL"
  python3 - "$OUT/config.json" "$API_URL" "$PUBLISHABLE_KEY" "$PORT" <<'PY'
import json, sys
path, api, key, port = sys.argv[1:]
config = {
    "ENVIRONMENT": "local",
    "SUPABASE_URL": api,
    "SUPABASE_PUBLISHABLE_KEY": key,
    "APP_URL": f"http://127.0.0.1:{port}",
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
PY
  (cd "$ROOT/app" && flutter build web --release --no-web-resources-cdn \
    --dart-define-from-file="$OUT/config.json" --output "$OUT/web")
fi

log "Serving the build on http://127.0.0.1:$PORT"
python3 "$ROOT/tool/uat/serve_app.py" "$OUT/web" --supabase-url "$API_URL" --port "$PORT" \
  >"$OUT/server.log" 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true' EXIT
for _ in {1..40}; do
  if curl -fs -o /dev/null "http://127.0.0.1:$PORT/"; then break; fi
  sleep 0.25
done
curl -fs -o /dev/null "http://127.0.0.1:$PORT/" || {
  cat "$OUT/server.log" >&2
  exit 1
}

log "Running the journeys"
cd "$ROOT/app/uat"
[[ -d node_modules/@playwright/test ]] || npm ci --no-audit --no-fund
if [[ -n ${UAT_SCREENSHOTS:-} ]]; then mkdir -p "$UAT_SCREENSHOTS"; fi
UAT_APP_URL="http://127.0.0.1:$PORT" UAT_API_URL=$API_URL UAT_PUBLISHABLE_KEY=$PUBLISHABLE_KEY \
  UAT_DB_URL=$DB_URL UAT_MAILPIT_URL=$MAILPIT_URL UAT_CLEANUP_TOKEN=$UAT_CLEANUP_TOKEN \
  npx --no-install playwright test "$@"
