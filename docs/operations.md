# Operations runbook

How the hosted backend runs on its own, what an operator sets up once, and how to check that it
is healthy. Everything here applies to the hosted Supabase project and to `supabase start`; the
plain-Postgres test database (`tool/db/test.sh`) has no scheduler, network or Vault.

## Scheduled jobs (pg_cron)

| Job                     | Schedule         | Command                                    | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------- | ---------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mm-daily-jobs`         | every 10 minutes | `select private.run_daily_jobs()`          | Maintains up to 500 active leases not yet done for today (Pakistan date): current rent, rent dues, late fees. A lease a user is writing to is skipped and retried by the next run; a failing lease is rolled back alone and recorded. Once every lease is done, a run that maintained none sends the day's notifications and runs the daily cleanup (including the orphaned-file sweep; if document uploads keep the sweep's gate busy, later runs that day try the sweep again until `private.job_runs` records `orphaned_file_sweep`). |
| `mm-rate-limit-cleanup` | hourly at :17    | deletes rate-limit windows older than 2 h  | Keeps `private.rate_limit_buckets` small.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `mm-storage-cleanup`    | every 10 minutes | `select private.request_storage_cleanup()` | When the storage cleanup queue has due work, calls the `storage-cleanup` Edge Function through `pg_net` (see below).                                                                                                                                                                                                                                                                                                                                                                                                                     |

A missed run (for example while a free-tier project is paused) needs no action: the next run
catches up, and the app also generates missing rent dues when the dashboard opens.

## Storage cleanup (one-time setup)

Files are deleted through the Storage API, never by deleting rows of `storage.objects` (that
would leave the files behind and billed). Deleting a document row, an entity with documents, a
portfolio or an account queues the files in `private.storage_cleanup_queue`; the
`storage-cleanup` function drains the queue. It needs one shared token, known to the function and
to the database.

1. Generate a token of at least 32 characters:

   ```bash
   openssl rand -base64 48
   ```

2. Give it to the function and deploy the function:

   ```bash
   supabase secrets set STORAGE_CLEANUP_TOKEN='<token>'
   ```

   ```bash
   supabase functions deploy storage-cleanup
   ```

3. Store the same token and the project URL in Vault (SQL editor, as `postgres`):

   ```sql
   select vault.create_secret('<token>', 'mm_storage_cleanup_token', 'Token pg_cron presents to storage-cleanup');
   select vault.create_secret('https://<project-ref>.supabase.co', 'mm_project_url', 'Project URL for pg_net calls');
   ```

4. Check the wiring: `select private.request_storage_cleanup();` returns `idle` (nothing due),
   `requested` (a call was queued in `net.http_request_queue`), `not_configured` (a Vault secret is
   missing) or `unavailable` (no `pg_net`).

To rotate the token, set the new value in both places, function secret first:
`select vault.update_secret((select id from vault.secrets where name = 'mm_storage_cleanup_token'), '<new token>');`

Until the setup is done, files of deleted records stay queued (nothing is lost); account deletion
still removes a deleted account's files itself, within a few seconds' budget.

## Health checks

| What to watch                                                                                                                        | Query or endpoint                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Functions are up                                                                                                                     | `GET` or `HEAD /functions/v1/health` → 200                                                                                                                        |
| Database, storage and auth are reachable                                                                                             | `GET /functions/v1/health?deep=1` with `x-health-token: <HEALTH_CHECK_TOKEN>` → 200 (503 lists the failing check)                                                 |
| Leases the daily job could not maintain                                                                                              | `select lease_id, maintained_on, failures, last_error from private.lease_maintenance where failures > 0;`                                                         |
| Days whose once-a-day work ran                                                                                                       | `select * from private.job_runs order by run_on desc limit 7;`                                                                                                    |
| Multixact use (every client write locks, key share, all the portfolios where the caller has a role)                                  | `select mxid_age(datminmxid) from pg_database where datname = current_database();` stays far below `autovacuum_multixact_freeze_max_age` (400 million by default) |
| Storage cleanup backlog and failures                                                                                                 | `select reason, count(*), min(enqueued_at), max(attempts) from private.storage_cleanup_queue group by reason;` and `... where last_error is not null`             |
| The documents bucket keeps versioning off (a versioned delete is an update, which the trigger keeping referenced files does not see) | `select versioning_status from storage.buckets where id = 'documents';` → `DISABLED`                                                                              |
| The most portfolios one person belongs to (each client write locks all of them)                                                      | `select max(n) from (select count(*) n from public.portfolio_members group by user_id) m;` stays well below 100                                                   |
| Recent pg_cron runs (kept for two weeks)                                                                                             | `select jobname, status, return_message, start_time from cron.job_run_details join cron.job using (jobid) order by start_time desc limit 20;`                     |
| pg_net responses of cleanup calls                                                                                                    | `select status_code, content, created from net._http_response order by created desc limit 10;`                                                                    |

A queue item that keeps failing is retried with exponential backoff over its consecutive failed
claims (1 minute doubling to 6 hours); `last_error` says why. An item handed back unfinished (the
run's time budget ran out) is due again at once and does not count as a failure. Claims take turns
between portfolios, so one portfolio's backlog never holds up another's deletions.

## Edge Function secrets

| Secret                   | Needed by       | Notes                                                                    |
| ------------------------ | --------------- | ------------------------------------------------------------------------ |
| `APP_URL`                | invite-member   | Public HTTPS URL of the app; invitation links open here.                 |
| `ALLOWED_ORIGINS`        | all functions   | Browser origins, comma-separated; defaults to APP_URL's origin.          |
| `RESEND_API_KEY`         | invite-member   | Optional; without it invitations are shared as links only.               |
| `MAIL_FROM`              | invite-member   | Required with `RESEND_API_KEY`.                                          |
| `MAIL_REPLY_TO`          | invite-member   | Optional.                                                                |
| `HEALTH_CHECK_TOKEN`     | health          | At least 32 characters; enables deep checks.                             |
| `REAUTH_MAX_AGE_SECONDS` | delete-account  | 60–3600, default 600: how recent a sign-in must be to delete an account. |
| `STORAGE_CLEANUP_TOKEN`  | storage-cleanup | At least 32 characters; also stored in Vault (above).                    |

A malformed optional secret breaks only the feature that uses it (the function answers 500
`server_misconfigured` naming the variable); a malformed `ALLOWED_ORIGINS` breaks every function,
because CORS needs it on every request. `supabase/functions/.env.example` lists the same secrets
for local development.

## Hosting (Vercel)

Two Vercel projects in the `ar27111994s-projects` team. Previews need a Vercel login;
production is public.

| Project                | Serves                         | Production address                      |
| ---------------------- | ------------------------------ | --------------------------------------- |
| `maalik-e-makaan`      | the Flutter web app (`app/`)   | <https://maalik-e-makaan.vercel.app>    |
| `maalik-e-makaan-site` | the Astro website (`website/`) | assigned at its first production deploy |

`maalik-e-makaan.vercel.app` is the app's `APP_URL`: Supabase Auth's Site URL, its redirect
`APP_URL/auth/callback`, the invitation links and the Edge Functions' allowed origin. Until the
Deploy workflow's first web deployment it serves a short "being built" page in English and Urdu,
with the same security headers.

### The web app on Vercel

Nothing is built on Vercel. The Deploy workflow builds the app (`flutter build web
--no-web-resources-cdn`, so CanvasKit is served from the app's own origin), and
`tool/web/package_vercel.py` turns `app/build/web` into a
[Build Output API v3](https://vercel.com/docs/build-output-api/configuration) directory
(`.vercel/output/static` plus `config.json`). `vercel deploy --prebuilt --prod` then uploads that
directory. The routes in `config.json`, in order:

1. Security headers on every response: the Content-Security-Policy below, HSTS (two years),
   `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`,
   `X-Frame-Options: DENY`, `Cross-Origin-Opener-Policy: same-origin`, and a
   `Permissions-Policy` that turns off the camera, microphone, geolocation, motion sensors,
   payment and USB.
2. `Cache-Control`. Flutter's file names (`main.dart.js`, `canvaskit/*`, `assets/*`) carry no
   content hash and stay the same from build to build, so every file is revalidated on each load
   (`no-cache`; an unchanged file answers 304). A file whose name does carry a hash
   (`name.0123abcd.ext`) gets `max-age=31536000, immutable`. The entry points (`index.html`,
   `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`, `manifest.json`) and
   `assetlinks.json` are always `no-cache`.
3. `{"handle": "filesystem"}`: existing files are served.
4. Every other path, such as `/auth/callback?code=…` or `/invite/…`, serves `index.html` with
   status 200, and the app's router takes over.

`/.well-known/assetlinks.json` comes from `app/web/.well-known/` (the Flutter build copies it) and
is served as `application/json`.

The Content-Security-Policy, with `<ref>` the Supabase project:

| Directive         | Sources                                                                              | Why                                                                          |
| ----------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| `default-src`     | `'self'`                                                                             | Anything not listed comes from the app's origin only                         |
| `script-src`      | `'self' 'wasm-unsafe-eval'`                                                          | CanvasKit is WebAssembly; without `'wasm-unsafe-eval'` the app never starts  |
| `style-src`       | `'self' 'unsafe-inline'`                                                             | The engine injects `<style>` elements; a static host cannot hand out nonces  |
| `img-src`         | `'self' data: blob: https://<ref>.supabase.co`                                       | Storage images, and images the browser decodes                               |
| `font-src`        | `'self'`                                                                             | The bundled fonts                                                            |
| `connect-src`     | `'self' https://<ref>.supabase.co wss://<ref>.supabase.co https://fonts.gstatic.com` | Auth, data, Storage, Realtime; the engine `fetch()`es fallback fonts (below) |
| `worker-src`      | `'self'`                                                                             | The CanvasKit renderer starts no workers                                     |
| `manifest-src`    | `'self'`                                                                             | `manifest.json`                                                              |
| `object-src`      | `'none'`                                                                             | No plugins                                                                   |
| `base-uri`        | `'self'`                                                                             | `index.html` sets `<base href="/">`; `'none'` blocks it                      |
| `form-action`     | `'self'`                                                                             | Flutter wraps autofill groups in a `<form>`, whose submission it cancels     |
| `frame-ancestors` | `'none'`                                                                             | The app cannot be framed (clickjacking)                                      |

The bundled fonts cover Latin (Atkinson Hyperlegible Next) and Urdu (Noto Nastaliq Urdu). For any
other glyph, such as a tenant's name in another script or an emoji, Flutter's engine downloads a
Noto font from `https://fonts.gstatic.com/s/` (its default `fontFallbackBaseUrl`) with `fetch()`.
That is why `connect-src` allows exactly that origin and `font-src` stays `'self'`. Bundling every
fallback font instead would add hundreds of megabytes.

Check a change to the headers or the CSP locally before a release:

```bash
cd app && flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file=config/production.example.json && cd ..
python3 tool/web/package_vercel.py --build app/build/web \
  --output /tmp/web/.vercel/output --supabase-url https://placeholder-ref.supabase.co
node tool/web/browser_check.cjs /tmp/web/.vercel/output --offline-host placeholder-ref.supabase.co \
  --click "Continue in English" --type "日本語 😀" --screenshot /tmp/web/app.png
```

`browser_check.cjs` needs the `playwright` package and its Chromium. It serves the package with
`tool/web/serve_output.py`, which applies `config.json` the way Vercel does. It then loads `/`,
`/auth/callback?code=x` and a random deep path, and fails on a CSP violation, a console error, an
unexpected failed request or an app that does not start. CI's web build runs
`tool/web/smoke_test.sh` against the same local server on every push.

## Deployment (GitHub Actions)

The Deploy workflow (`.github/workflows/deploy.yml`) runs when a release is published, or by hand
(Actions, Deploy, Run workflow; only once the workflow is on the default branch). Its `supabase`
job pushes migrations and Edge Functions to Supabase and calls the `health` function. Its `web`
job then:

1. fails at once if the `VERCEL_TOKEN` secret or a repository variable is missing;
2. writes `app/config/production.json` from the repository variables, as the Release workflow
   does, and runs `flutter build web --release --no-web-resources-cdn`;
3. packages the build with `tool/web/package_vercel.py` (see Hosting);
4. runs `vercel deploy --prebuilt --prod` with the CLI pinned to an exact version, for the
   project's team and project ids;
5. runs `tool/web/smoke_test.sh`. On `/`, `/auth/callback?code=…` and an `/invite/…` path it
   checks for a 200 with the app's `index.html`, the CSP (it must allow `SUPABASE_URL`), HSTS,
   `nosniff` and a revalidated `Cache-Control`. It also checks that
   `/.well-known/assetlinks.json` answers 200 as JSON, delegating to the Android package.

The Release workflow builds the signed Android app and attaches the web build to the release. The
workflows read these repository settings:

| Setting                     | Kind     | What it is                                               |
| --------------------------- | -------- | -------------------------------------------------------- |
| `SUPABASE_ACCESS_TOKEN`     | secret   | A Supabase personal access token scoped to this project  |
| `SUPABASE_DB_PASSWORD`      | secret   | The database password, for `supabase db push`            |
| `ANDROID_KEYSTORE_BASE64`   | secret   | The upload keystore (`.jks`), base64-encoded             |
| `ANDROID_KEYSTORE_PASSWORD` | secret   | The keystore's password                                  |
| `ANDROID_KEY_ALIAS`         | secret   | The key's name in the keystore (`upload`)                |
| `ANDROID_KEY_PASSWORD`      | secret   | The key's password                                       |
| `RELEASE_PLEASE_TOKEN`      | secret   | Optional: a token whose release pull requests trigger CI |
| `VERCEL_TOKEN`              | secret   | A Vercel token for the `ar27111994s-projects` team       |
| `SUPABASE_PROJECT_REF`      | variable | `aaifamxzzjspohwksxyr`                                   |
| `SUPABASE_URL`              | variable | `https://aaifamxzzjspohwksxyr.supabase.co`               |
| `SUPABASE_PUBLISHABLE_KEY`  | variable | The project's publishable (client) key                   |
| `APP_URL`                   | variable | `https://maalik-e-makaan.vercel.app`                     |

The `production` environment should require a reviewer; `release` holds the signing secrets.

Create the keystore once, on a machine with a JDK (`keytool` ships with it; Android Studio's is
under `jbr/bin`):

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep it and its passwords out of the repository and backed up. With Google Play App Signing it is
the upload key, which Google can reset if lost.

### Android App Links

`app/web/.well-known/assetlinks.json` lets Android open `https://maalik-e-makaan.vercel.app/auth/callback`
links in the app (the `autoVerify` intent filter in `app/android/app/src/main/AndroidManifest.xml`).
It lists the SHA-256 fingerprint of each certificate that signs the app the user installs. Today
that is only the upload key, which signs the APKs attached to releases.

Once the app is on Google Play, Play re-signs it with the app-signing key. Add that key's
fingerprint to the list (Play Console, Test and release, App integrity, App signing key
certificate, SHA-256), keeping the upload key's:

```json
"sha256_cert_fingerprints": [
  "96:C8:54:35:77:E8:20:5A:10:E6:01:5A:D0:8F:86:B2:CE:CE:D1:7A:8D:32:AB:B8:43:DF:2A:40:77:54:23:F8",
  "<the Play app-signing key's SHA-256, upper case, colon-separated>"
]
```

`package_vercel.py` refuses a malformed file. The change goes live with the next web deployment.

Verify after a deployment. Google's Digital Asset Links API should answer `"linked": true`:

```bash
curl -sS 'https://digitalassetlinks.googleapis.com/v1/assetlinks:check?source.web.site=https://maalik-e-makaan.vercel.app&relation=delegate_permission/common.handle_all_urls&target.android_app.package_name=io.github.ar27111994.maalik_e_makaan&target.android_app.certificate.sha256_fingerprint=96:C8:54:35:77:E8:20:5A:10:E6:01:5A:D0:8F:86:B2:CE:CE:D1:7A:8D:32:AB:B8:43:DF:2A:40:77:54:23:F8'
```

On a device or emulator with the release-signed app installed (Android 12 or later):

```bash
adb shell pm verify-app-links --re-verify io.github.ar27111994.maalik_e_makaan
adb shell pm get-app-links io.github.ar27111994.maalik_e_makaan   # maalik-e-makaan.vercel.app: verified
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE \
  -d 'https://maalik-e-makaan.vercel.app/auth/callback?code=test'   # opens the app, not the browser
```

A debug build is signed with the debug key, which is not listed, so it stays unverified.

## After every migration

1. Apply it to the hosted project and keep the migration file's version equal to the version the
   platform records (`supabase migration list`).
2. Regenerate the functions' database types, so RPC names, arguments and results stay checked:

   ```bash
   supabase gen types typescript --project-id <project-ref> > supabase/functions/_shared/database.types.ts
   ```

3. Check for drift between the migration chain and the hosted schema:

   ```bash
   psql -X -At -d <local database> -f tool/db/schema_fingerprint.sql > local.json
   ```

   Run the same query on the hosted project (SQL editor) into `hosted.json`, then:

   ```bash
   tool/db/fingerprint_diff.py local.json hosted.json
   ```

4. Run the database advisors (dashboard → Advisors) and confirm only the reviewed findings remain
   (the write RPCs pinned in `supabase/tests/database/01_schema_security.test.sql`).
