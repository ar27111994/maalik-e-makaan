# Operations runbook

How the hosted backend runs on its own, what an operator sets up once, and how to check that it
is healthy. Everything here applies to the hosted Supabase project and to `supabase start`; the
plain-Postgres test database (`tool/db/test.sh`) has no scheduler, network or Vault.

## Scheduled jobs (pg_cron)

| Job                     | Schedule         | Command                                    | What it does                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------- | ---------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mm-daily-jobs`         | every 10 minutes | `select private.run_daily_jobs()`          | Maintains up to 500 active leases not yet done for today (Pakistan date): current rent, rent dues, late fees. A lease a user is writing to is skipped and retried by the next run; a failing lease is rolled back alone and recorded. Once every lease is done, a run that maintained none sends the day's notifications and runs the daily cleanup (including the orphaned-file sweep). |
| `mm-rate-limit-cleanup` | hourly at :17    | deletes rate-limit windows older than 2 h  | Keeps `private.rate_limit_buckets` small.                                                                                                                                                                                                                                                                                                                                                |
| `mm-storage-cleanup`    | every 10 minutes | `select private.request_storage_cleanup()` | When the storage cleanup queue has due work, calls the `storage-cleanup` Edge Function through `pg_net` (see below).                                                                                                                                                                                                                                                                     |

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

| What to watch                            | Query or endpoint                                                                                                                                     |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Functions are up                         | `GET` or `HEAD /functions/v1/health` → 200                                                                                                            |
| Database, storage and auth are reachable | `GET /functions/v1/health?deep=1` with `x-health-token: <HEALTH_CHECK_TOKEN>` → 200 (503 lists the failing check)                                     |
| Leases the daily job could not maintain  | `select lease_id, maintained_on, failures, last_error from private.lease_maintenance where failures > 0;`                                             |
| Days whose once-a-day work ran           | `select * from private.job_runs order by run_on desc limit 7;`                                                                                        |
| Storage cleanup backlog and failures     | `select reason, count(*), min(enqueued_at), max(attempts) from private.storage_cleanup_queue group by reason;` and `... where last_error is not null` |
| Recent pg_cron runs (kept for two weeks) | `select jobname, status, return_message, start_time from cron.job_run_details join cron.job using (jobid) order by start_time desc limit 20;`         |
| pg_net responses of cleanup calls        | `select status_code, content, created from net._http_response order by created desc limit 10;`                                                        |

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
web app's first release it serves a short "being built" page in English and Urdu, with the same
security headers.

## Deployment (GitHub Actions)

The Deploy workflow (`.github/workflows/deploy.yml`) runs when a release is published and pushes
migrations and Edge Functions to Supabase; the Release workflow builds the signed Android app and
the web app. They read these repository settings:

| Setting                     | Kind     | What it is                                               |
| --------------------------- | -------- | -------------------------------------------------------- |
| `SUPABASE_ACCESS_TOKEN`     | secret   | A Supabase personal access token scoped to this project  |
| `SUPABASE_DB_PASSWORD`      | secret   | The database password, for `supabase db push`            |
| `ANDROID_KEYSTORE_BASE64`   | secret   | The upload keystore (`.jks`), base64-encoded             |
| `ANDROID_KEYSTORE_PASSWORD` | secret   | The keystore's password                                  |
| `ANDROID_KEY_ALIAS`         | secret   | The key's name in the keystore (`upload`)                |
| `ANDROID_KEY_PASSWORD`      | secret   | The key's password                                       |
| `RELEASE_PLEASE_TOKEN`      | secret   | Optional: a token whose release pull requests trigger CI |
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
