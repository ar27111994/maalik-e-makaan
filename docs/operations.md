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

| What to watch                                                                                                                          | Query or endpoint                                                                                                                                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Functions are up                                                                                                                       | `GET` or `HEAD /functions/v1/health` → 200                                                                                                                                                                                               |
| Database, storage and auth are reachable                                                                                               | `GET /functions/v1/health?deep=1` with `x-health-token: <HEALTH_CHECK_TOKEN>` → 200 (503 lists the failing check)                                                                                                                        |
| Leases the daily job could not maintain                                                                                                | `select lease_id, maintained_on, failures, last_error from private.lease_maintenance where failures > 0;`                                                                                                                                |
| Days whose once-a-day work ran                                                                                                         | `select * from private.job_runs order by run_on desc limit 7;`                                                                                                                                                                           |
| Multixact use (every client write locks, key share, all the portfolios where the caller has a role)                                    | `select mxid_age(datminmxid) from pg_database where datname = current_database();` stays far below `autovacuum_multixact_freeze_max_age` (400 million by default)                                                                        |
| Storage cleanup backlog and failures                                                                                                   | `select reason, count(*), min(enqueued_at), max(attempts) from private.storage_cleanup_queue group by reason;` and `... where last_error is not null`                                                                                    |
| The documents bucket keeps versioning off (a versioned delete is an update, which the trigger keeping referenced files does not see)   | `select versioning_status from storage.buckets where id = 'documents';` → `DISABLED`                                                                                                                                                     |
| The most portfolios one person belongs to (each client write locks all of them)                                                        | `select max(n) from (select count(*) n from public.portfolio_members group by user_id) m;` stays well below 100                                                                                                                          |
| Every caretaker is a manager of their portfolio (`CaretakerIsManager`; see [Deleting a user account](#deleting-a-user-account))        | `select p.id from public.portfolios p where p.caretaker_user_id is not null and not exists (select 1 from public.portfolio_members m where m.portfolio_id = p.id and m.user_id = p.caretaker_user_id and m.role = 'manager');` → no rows |
| The server's time zones agree with the app's (after a Supabase Postgres upgrade or a `tzdata` bump; [Time-zone data](#time-zone-data)) | Run `tool/db/time_zone_skew.sql` → never an `Asia/Karachi` row; any other row is explained by a `tzdata` release the server and the app do not share, and recorded                                                                       |
| Recent pg_cron runs (kept for two weeks)                                                                                               | `select jobname, status, return_message, start_time from cron.job_run_details join cron.job using (jobid) order by start_time desc limit 20;`                                                                                            |
| pg_net responses of cleanup calls                                                                                                      | `select status_code, content, created from net._http_response order by created desc limit 10;`                                                                                                                                           |

A queue item that keeps failing is retried with exponential backoff over its consecutive failed
claims (1 minute doubling to 6 hours); `last_error` says why. An item handed back unfinished (the
run's time budget ran out) is due again at once and does not count as a failure. Claims take turns
between portfolios, so one portfolio's backlog never holds up another's deletions.

## Monitoring and alerts

Nothing in the project raises an alert by itself: the free tier has no alerting, and the app has
no telemetry (privacy). Two checks cover it, one outside and one inside.

1. **An external uptime monitor** on
   `GET https://<project-ref>.supabase.co/functions/v1/health?deep=1` with the header
   `x-health-token: <HEALTH_CHECK_TOKEN>`, expecting 200, every 5 minutes or less, alerting by
   e-mail. A 503 names the failing check (database, storage or auth). The token goes only in that
   header: the function reads no query parameter, and a monitor that cannot send a custom header
   on its free plan (UptimeRobot, HetrixTools) cannot do this check. Without the secret, `?deep=1`
   answers 403 `deep_check_disabled`; with a wrong or missing header, 401. Add a second monitor on
   `https://maalik-e-makaan.vercel.app/` (200) for the web app.

   Setting it up. Any monitor whose free plan sends a custom request header will do. Better Stack
   Uptime was the first suggestion, but it refused new sign-ups on 2026-11-09. Next in line:
   Checkly's free Hobby plan (an API check has a Headers tab; about 8,700 runs a month at one
   location every 5 minutes, under the plan's monthly cap), then StatusCake's free plan (the
   test's Custom Headers field). Check the header field is open on the free plan before relying
   on it.
   1. Make a token of at least 32 characters, `openssl rand -hex 32`, and keep it in a password
      manager.
   2. Set it as an Edge Function secret: dashboard, Edge Functions, Secrets, `HEALTH_CHECK_TOKEN`
      (or `supabase secrets set HEALTH_CHECK_TOKEN=<token> --project-ref <project-ref>`). No
      redeploy is needed.
   3. Check it: `curl -i <url>?deep=1` answers 401, and
      `curl -i -H "x-health-token: <token>" <url>?deep=1` answers 200 with every check `ok`.
   4. In the monitor service, create an HTTP (or API) check on the deep URL, method GET, from one
      location, expected status 200, the request header `x-health-token` with the token, e-mail
      alerts to the owner. Then a
      second monitor on the web app. Do not publish a status page that lists the deep check, and
      never put the token in a URL, a monitor name or a description.
   5. Rotating the token: pause the monitor, set the new secret, update the header, resume.

   The checks cost about 9,000 function calls a month at a 5-minute interval (the free plan
   includes 500,000), and the database reads they make count as activity, which keeps the free
   project from pausing.

2. **A daily look at the jobs** (SQL editor, as `postgres`; a saved query). Each row it returns is
   something to act on:

   ```sql
   -- Leases the daily job failed on, the day's work not done, and stuck file deletions.
   select 'lease' as what, lease_id::text as id, last_error as detail
   from private.lease_maintenance where failures > 0
   union all
   select 'daily jobs', null, 'no run recorded for today'
   where not exists (select 1 from private.job_runs where run_on = app.today_pkt())
   union all
   select 'storage cleanup', id::text, last_error
   from private.storage_cleanup_queue where last_error is not null and attempts >= 3
   union all
   select 'pg_cron', jobname, return_message
   from cron.job_run_details join cron.job using (jobid)
   where status = 'failed' and start_time > now() - interval '1 day';
   ```

   - `lease`: the error says why (usually data the job refuses, such as an overflowing late fee);
     fix the lease or its charges, and the next run retries it.
   - `daily jobs`: after 01:00 Pakistan time, check that the project is not paused (free projects
     pause after a week without activity) and that `mm-daily-jobs` is scheduled
     (`select * from cron.job;`).
   - `storage cleanup`: see Storage cleanup; usually the Vault token and the function secret
     differ.
   - `pg_cron`: the failing job's message.

Also check the Supabase dashboard's usage page once a week: the free tier's database size and
egress limits.

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

## E-mail

Supabase Auth's own sender is for testing only: it sends only to the project's team members, a
few an hour, so real users cannot sign up until custom SMTP is set. The project uses
[Resend](https://resend.com) for both kinds of e-mail: Auth's (confirm sign-up, reset password,
change e-mail address) through SMTP, and invitations through the HTTP API (`invite-member`).
Resend's free plan (3,000 e-mails a month, 100 a day, one domain, in November 2026) is enough at
launch; Auth and invitations share the daily 100. Check the plan's terms allow production use.

1. **A domain.** Resend sends to other people only from a domain whose DNS you control; a
   `vercel.app` address cannot be one. Use a subdomain (`mail.<domain>`), add the records Resend
   lists (MX and SPF TXT on `send.mail.<domain>`, DKIM TXT on `resend._domainkey.mail.<domain>`)
   and a DMARC record (`_dmarc.<domain>`, `v=DMARC1; p=none;`), and wait for "Verified". The
   project's domain is `news.ar27111994.dev` (verified 2026-11-09). In the domain's
   Configuration, turn **off** click tracking and open tracking: click tracking rewrites the
   sign-in links through Resend's servers, and open tracking adds a tracking pixel; the privacy
   page says the app has no trackers.
2. **Two API keys**, both "Sending access" and limited to that domain: one for Supabase's SMTP,
   one for the `invite-member` function, so either can be revoked alone.
3. **Supabase SMTP** (Authentication, Emails, SMTP Settings, Enable custom SMTP): sender
   `no-reply@mail.<domain>`, name "Maalik-e-Makaan", host `smtp.resend.com`, port 465, user
   `resend`, password the first key, minimum interval 60 seconds. (Resend's Supabase integration,
   Settings, Integrations, fills in the same.)
4. **Rate limit** (Authentication, Rate Limits, "Email sent"): custom SMTP starts at 30 an hour,
   which is fine. The real ceiling is Resend's 100 a day for Auth and invitations together: past
   it, confirmations and resets stop until the next day. Watch Resend's dashboard, and move to its
   paid plan before sign-ups come near it.
5. **URLs** (Authentication, URL Configuration): Site URL `https://maalik-e-makaan.vercel.app`,
   redirect URLs `https://maalik-e-makaan.vercel.app/auth/callback` (the web and Android apps) and
   `io.github.ar27111994.maalikemakaan://maalik-e-makaan.vercel.app/auth/callback` (the iOS app,
   which comes back through its own URL scheme). The app sends these exact addresses; one missing
   from the list sends the link to the Site URL instead, where the iOS sign-in cannot finish.
6. **Templates** (Authentication, Emails, Templates). Each e-mail is in English, then Urdu. For
   "Confirm signup", "Reset password" and "Change email address", paste the subject from
   `supabase/config.toml` (`[auth.email.template.*]`) and the body from
   `supabase/templates/<name>.html`; the local stack uses the same files, and the UAT checks the
   sign-up e-mail. The app uses no magic link, invite or reauthentication e-mail. The hosted
   project keeps the copy last pasted, and Deploy does not change it (it deploys the invitation
   e-mail with `invite-member`, but not these), so paste a body again after every release that
   changes its file (Releasing, step 5). The Urdu `font-family`, `font-size` and `line-height`
   in the files are written by `make tokens` from the type tokens, at the role each Urdu element
   names with `data-mm-type`; edit the tokens, not the values in the files.
7. **Invitations**: the Edge Function secrets `RESEND_API_KEY` (the second key) and
   `MAIL_FROM="Maalik-e-Makaan <no-reply@mail.<domain>>"` (Edge Function secrets, above).
8. **Check**: sign up in each language, reset a password, change an address, and invite someone
   outside the team. Each link should open `/auth/callback`, and "Show original" in Gmail should
   say SPF, DKIM and DMARC "PASS".

## Hosting (Vercel)

Two Vercel projects in the `ar27111994s-projects` team. Previews need a Vercel login;
production is public.

| Project                | Serves                         | Production address                        |
| ---------------------- | ------------------------------ | ----------------------------------------- |
| `maalik-e-makaan`      | the Flutter web app (`app/`)   | <https://maalik-e-makaan.vercel.app>      |
| `maalik-e-makaan-site` | the Astro website (`website/`) | <https://maalik-e-makaan-site.vercel.app> |

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

The bundled fonts cover Latin (Atkinson Hyperlegible Next) and Urdu (Noto Sans Arabic, and Noto
Nastaliq Urdu with only the letters of the Urdu wordmark). The engine downloads every bundled font
before it starts the app; the four of `mm_ui`, the icon font included, come to about 700 KB, 375 KB
compressed (`make fonts` keeps the two Noto fonts to what the app sets). For any
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

### The website on Vercel

The website is built in GitHub Actions too, not by Vercel. The Deploy workflow writes the
project's settings into `.vercel/project.json` (root directory `website`, framework Astro), so
`vercel build --prod` runs `website/vercel.json`'s `npm ci` and `npm run build` and turns that
file's headers, trailing slashes and `dist/404.html` into a Build Output API directory;
`vercel deploy --prebuilt --prod` uploads it. The headers and the Content-Security-Policy are
described in [`website/README.md`](../website/README.md#security-headers).

The build bakes the site's own address into every page (canonical and `hreflang` links, Open
Graph URLs, the sitemap, `robots.txt`, `llms.txt`), so it takes two values from the workflow:

| Variable         | Value in the Deploy workflow                                | Used for                                 |
| ---------------- | ----------------------------------------------------------- | ---------------------------------------- |
| `SITE_URL`       | `https://maalik-e-makaan-site.vercel.app` (in `deploy.yml`) | the site's canonical origin              |
| `PUBLIC_APP_URL` | the `APP_URL` repository variable                           | the "Open the web app" links and JSON-LD |

`maalik-e-makaan-site.vercel.app` is the project's default production domain (Vercel assigned it
when the project was created); every production deployment is aliased to it.

Three things on the site update themselves, so a release needs no copy edits for them:

- **The release.** The download page's "Version …" block, the footer's version line, the
  release notes page (`/releases/`) and `llms.txt` are built from `CHANGELOG.md` and
  `.release-please-manifest.json` (`website/src/lib/release.ts`). The Release workflow deploys the
  site at the tag it has just made, so they always show that release; from version 1.0.0 the
  site describes the app as available rather than in development. The download page links to the
  APKs, the unsigned iOS app, the web zip and `SHA256SUMS`, which exist only once Release's
  `artefacts` and `ios` jobs have attached them. So the `site` job lists the files attached when
  it runs (`website/src/data/release-assets.json`) and the page links to those alone, and Release
  deploys the site after both builds have finished (Deployment, below). A build that fails, even
  on every re-run, then costs the page that build's links only, never the deploy.
- **The roadmap.** `/roadmap/` shows the GitHub milestones and the issues labelled `roadmap`, as
  they are when the site is built: the `site` job runs `tool/github/fetch_roadmap.py
--from-github` before the build (falling back, with a warning, to the copy in
  `website/src/data/roadmap.json`). Two kinds of labelled issue stay off the page: one opened by
  someone outside the project (not the owner, a member, a collaborator or the Roadmap workflow),
  because its author can retitle it at any time and the weekly refresh would publish the new
  title unreviewed; and one closed as not planned or as a duplicate, which was dropped, not done.
  To put a suggestion from outside on the roadmap, open an issue of your own for it; to take an
  item off, close its issue as not planned. The plan itself is `.github/roadmap.toml`; when it
  changes on main, the Roadmap workflow (`roadmap.yml`) creates the missing label, milestones and
  issues and keeps milestone titles, descriptions and due dates in step, without ever closing,
  deleting or rewriting an issue. It renames only the roadmap's own milestones: when a title in
  the file is held by another milestone (made by hand, or left by a stage taken out of the file),
  the workflow stops before changing anything and names it, to be renamed or deleted on GitHub.
  Run `make roadmap` after editing the file, to refresh the offline copy. Between releases, the
  Site refresh workflow (`site-refresh.yml`) redeploys the site alone at the latest release's tag
  every Wednesday, and by hand (Actions, Site refresh, Run workflow); the Deploy workflow can also
  be run by hand with "Only the website". Site refresh builds the tag's content with main's
  `deploy.yml`, so its steps can be newer than the tag: a step whose tool is newer than the tag
  (the pitch deck, the live roadmap) is skipped with a warning, and the site keeps what the tag
  has (the committed `roadmap.json`, if any); the next release brings the tool along.
- **The pitch deck.** `/company/` links to a PDF of the deck in `website/deck/`, rendered by
  `npm run deck` (`website/scripts/render-deck.ts`) with the release's version and date and the
  app's current screens; the `site` job renders it before every build. Edit the slides in
  `website/deck/slides/`; their format is the one in that folder's README.

To move the site to a custom domain later:

1. In the Vercel project `maalik-e-makaan-site`, Settings, Domains, add the domain (for example
   `www.example.pk`, plus the apex redirecting to it) and create the DNS records Vercel shows;
   wait until it reads "Valid Configuration".
2. Set `SITE_URL` and the `site` job's `environment.url` in `.github/workflows/deploy.yml` to
   `https://<the domain>` (https, no path), and update `DEFAULT_SITE_URL` in `website/src/config/urls.ts` and
   `website/README.md` if the domain is to be the default for local builds too.
3. Run the Deploy workflow. The smoke test checks that the canonical links, `robots.txt` and the
   sitemap name the new origin.
4. Keep `maalik-e-makaan-site.vercel.app`, but redirect it to the domain (Settings, Domains,
   Edit, Redirect to) so search engines see one address.

## Deployment (GitHub Actions)

The Deploy workflow (`.github/workflows/deploy.yml`) runs when the Release workflow has released a
tag (Release calls it for that tag), or by hand (Actions, Deploy, Run workflow, for the branch or
tag chosen there; only once the workflow is on the default branch). Publishing a release by hand
does not start it. See [Releasing](#releasing). Its `supabase`
job pushes migrations and Edge Functions to Supabase and calls the `health` function. Its `web`
job then:

1. fails at once if the `VERCEL_TOKEN` secret or a repository variable is missing;
2. writes `app/config/production.json` from the repository variables, as the Release workflow
   does, and runs `flutter build web --release --no-web-resources-cdn`;
3. packages the build with `tool/web/package_vercel.py` (see Hosting);
4. runs `vercel deploy --prebuilt --prod` with the CLI pinned to an exact version, for the
   project's team and project ids;
5. runs `tool/web/smoke_test.sh`. It first waits up to two minutes for `/` to answer 200, since
   just after `vercel deploy --prod` the production address can still answer from the previous
   deployment ("waiting for the deployment" in the log). Then, on `/`, `/auth/callback?code=…`
   and an `/invite/…` path, it checks for a 200 with the app's `index.html`, the CSP (it must allow `SUPABASE_URL`), HSTS,
   `nosniff` and a revalidated `Cache-Control`. It also checks that
   `/.well-known/assetlinks.json` answers 200 as JSON, delegating to the Android package.

Its `site` job deploys the website. It does not wait for Supabase (the site never calls it), so it
runs alongside the other two when the workflow runs by hand. The Release workflow instead calls
Deploy twice: once with `skip-site` straight after tagging, for the backend and the web app, and
once with `site-only` after its `artefacts` and `ios` jobs have finished, so that the download page
links to the files they attached. If a build fails, the website still goes out, without that
build's links; re-running the failed job (Re-run failed jobs) runs the website's deploy again
after it, which adds them. The `site` job:

1. fails at once if the `VERCEL_TOKEN` secret or the `APP_URL` variable is missing;
2. renders the pitch deck (`npm run deck`, with Playwright's Chromium) and fetches the live
   roadmap (`tool/github/fetch_roadmap.py --from-github`); a tag from before either tool skips
   that step with a warning (see Hosting, The website on Vercel);
3. writes the names of the files attached to the manifest's release, read from GitHub, to
   `website/src/data/release-assets.json`, so the download page links to those alone: a run
   while a release is still building, or after one of its builds failed, publishes fewer links
   rather than dead ones. It fails, before anything is deployed, only if GitHub cannot be read
   or the release is not published yet; run it again later;
4. writes `.vercel/project.json` and runs `vercel build --prod` with `SITE_URL` and
   `PUBLIC_APP_URL` set (see Hosting, The website on Vercel); the build fails on a page without
   its twin in the other language or with inline code;
5. checks, as a safety net, that every release file the built pages link to
   (`/releases/download/…`) is attached to its GitHub release, and stops before deploying if one
   is not, leaving the live site as it was;
6. runs `vercel deploy --prebuilt --prod` with the same pinned CLI;
7. runs `tool/web/site_smoke_test.sh`, which first waits the same way for `/` to answer 200.
   Then `/`, `/ur/`, `/robots.txt`, `/sitemap-index.xml` and
   `/llms.txt` must answer 200 with the right type, the canonical links, `robots.txt` and the
   sitemap must name `SITE_URL`, a missing page must answer 404, and every response must carry
   the Content-Security-Policy, HSTS, `nosniff`, `X-Frame-Options`, `Referrer-Policy`,
   `Permissions-Policy` and `Cross-Origin-Opener-Policy`.

CI's `website` job checks every push first, with the steps of `make test-web` (listed in
[`docs/agents/commands.md`](agents/commands.md#tests-by-area)), Lighthouse on a subset of pages
included.

The Release workflow builds the signed Android app and an unsigned iOS app, and attaches them and
the web build to the release. The workflows read these repository settings:

| Setting                     | Kind     | What it is                                                                |
| --------------------------- | -------- | ------------------------------------------------------------------------- |
| `SUPABASE_ACCESS_TOKEN`     | secret   | A Supabase personal access token scoped to this project                   |
| `SUPABASE_DB_PASSWORD`      | secret   | The database password, for `supabase db push`                             |
| `ANDROID_KEYSTORE_BASE64`   | secret   | The upload keystore (`.jks`), base64-encoded                              |
| `ANDROID_KEYSTORE_PASSWORD` | secret   | The keystore's password                                                   |
| `ANDROID_KEY_ALIAS`         | secret   | The key's name in the keystore (`upload`)                                 |
| `ANDROID_KEY_PASSWORD`      | secret   | The key's password                                                        |
| `RELEASE_PLEASE_TOKEN`      | secret   | Recommended: a token whose release pull requests trigger CI (Releasing)   |
| `VERCEL_TOKEN`              | secret   | A Vercel token for the `ar27111994s-projects` team                        |
| `SUPABASE_PROJECT_REF`      | variable | `aaifamxzzjspohwksxyr`                                                    |
| `SUPABASE_URL`              | variable | `https://aaifamxzzjspohwksxyr.supabase.co`                                |
| `SUPABASE_PUBLISHABLE_KEY`  | variable | The project's publishable (client) key                                    |
| `APP_URL`                   | variable | `https://maalik-e-makaan.vercel.app`; also the website's `PUBLIC_APP_URL` |
| `BACKUP_AGE_RECIPIENTS`     | variable | The public keys the weekly backup is encrypted to, one per line (Backups) |

The `production` environment should require a reviewer; `release` holds the signing secrets.

Create the keystore once, on a machine with a JDK (`keytool` ships with it; Android Studio's is
under `jbr/bin`):

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep it and its passwords out of the repository and backed up. With Google Play App Signing it is
the upload key, which Google can reset if lost.

### iOS e-mail links

iOS has no associated domain, so the iOS app asks Auth to send its e-mail links to
`io.github.ar27111994.maalikemakaan://<app host>/auth/callback` (`AppConfig.authCallbackUrlFor`),
a scheme it registers in `ios/Runner/Info.plist` (`CFBundleURLTypes`). Safari hands the link back
to the app, which holds the sign-in verifier, and the router opens `/auth/callback` as on the
other platforms. The address must be among Auth's redirect URLs (E-mail, above). Check it on an
iPhone once an iOS build exists: sign up and reset a password from the app; iOS asks to open the
link in Maalik-e-Makaan.

### iOS builds

There is no Apple Developer Program membership yet, so nothing signs the iOS app. CI's
`ios-build` job builds it for iPhone without signing on every push and pull request, which keeps it
compiling, and keeps the result for 14 days as the `ios-unsigned-ipa` artefact. Each release
attaches `maalik-e-makaan-vX.Y.Z-ios-unsigned.ipa`, built with production's configuration, with
its checksum in `SHA256SUMS-ios` and a provenance attestation.

An unsigned `.ipa` installs on no iPhone as it is. To try it on your own phone:

- With a free Apple Account and no Mac: a third-party signing tool such as Sideloadly (Windows or
  macOS) signs the `.ipa` with that account and installs it over USB. The install lasts 7 days, and
  the phone must allow developer apps (Settings, General, VPN & Device Management) and, from iOS 16,
  Developer Mode.
- With a Mac: open `app/ios/Runner.xcworkspace` in Xcode, choose your Apple Account as the team
  under Signing & Capabilities, and run on the phone. The same 7-day limit applies.
- TestFlight and the App Store need the paid Apple Developer Program, a signing certificate and a
  provisioning profile in the release workflow.

An Apple Account needs a phone number that can receive Apple's verification code; it does not need
an iPhone.

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

## Releasing

1. CI must be green on `main` (the "CI passed" check). Pull requests are squash-merged with a
   Conventional Commit title.
2. The Release workflow keeps a release pull request open on `main` (release-please). It bumps
   the version in <!-- docs:release-files from release-please-config.json extra-files; generated by make docs, do not edit -->`.release-please-manifest.json`, `app/pubspec.yaml`, `README.md` and `website/package.json`<!-- /docs:release-files --> (the manifest and
   `extra-files` in `release-please-config.json`), and writes `CHANGELOG.md`. It picks the next
   version from the commits since the last tag: a `fix` gives a patch release, a `feat` a minor
   one, and a breaking change (`!` or `BREAKING CHANGE:`) a major one. (v1.0.0 was pinned with
   `"release-as"`, removed straight after it was tagged.)
3. Merging the release pull request tags `vX.Y.Z` and publishes the GitHub release. The same run
   builds the signed Android app and the web app and attaches them (`artefacts`), builds and
   attaches the unsigned iOS app (`ios`), and calls the Deploy workflow for the tag twice: at once
   for the backend and the web app (`deploy`), and for the website once `artefacts` and `ios` have
   finished (`site`), since its download page links to the files they attached. Each deployment
   waits for a reviewer when the `production` environment requires one.
4. Watch both Deploy calls: each job ends with its smoke test, and the `supabase` job with a call
   to `health`. If `artefacts` or `ios` failed, the website still describes the new release, but
   its download page has no links to that build's files; re-run the failed job (Re-run failed
   jobs), which deploys the website again afterwards. A build that keeps failing (the optional
   iOS one after a macOS runner change, say) leaves those links out until a release has them,
   and holds up nothing else. Then run the daily query of Monitoring and alerts.
5. If the release changed a file in `supabase/templates/` (its changelog says so, or
   `git diff --stat <previous tag> vX.Y.Z -- supabase/templates/` lists it), paste that body into
   its Auth template in the dashboard (E-mail, step 6), with the subject from
   `supabase/config.toml` if that changed too. Then send yourself the e-mail (sign up, reset a
   password or change an address) and check both halves.

`RELEASE_PLEASE_TOKEN` (repository secret) is needed once `main` requires "CI passed" with no
bypass. A
release pull request that release-please opens or updates with the default `GITHUB_TOKEN` starts
no workflow by itself: GitHub either holds its runs until someone clicks "Approve workflows to
run" or starts none, so the required check waits on every update. With the token, CI, Security
and the title check run on it as on any pull request; nothing else starts (no workflow listens to
tags or releases), and Deploy still runs only when Release calls it. Without the token, the
repository setting "Allow GitHub Actions to create and approve pull requests" (Settings, Actions,
General) must be on, or release-please cannot open its pull request.

Making the token: GitHub, Settings, Developer settings, Personal access tokens, Fine-grained
tokens, Generate new token. Resource owner the account, Only select repositories
(`maalik-e-makaan`), Repository permissions Contents and Pull requests "Read and write" (Metadata
is added; nothing else). An expiry of 366 days with a reminder two weeks before, or none. Save it
as the repository secret `RELEASE_PLEASE_TOKEN`. An expired token is not empty, so the fallback to
`GITHUB_TOKEN` does not apply: Release fails with "Bad credentials" until the secret is replaced.

Android version codes come from the Release run's number N. Each split APK gets 1000 times its
ABI number plus N (Flutter's scheme: 1001 + N up to 4000 + N); the app bundle for Google Play gets
10000 + N. A later bundle is therefore always above any APK already released, so Google Play can
update a phone that installed an APK, if Play signs with the same key. With Play App Signing's
own key the signatures differ and such a phone must uninstall first whatever the codes. Keep the
offset: lowering it later would put a Play build below an APK already in someone's hands.

release-please titles its pull request `chore(release): release X.Y.Z`
(`pull-request-title-pattern` in `release-please-config.json`), which the title check and
commitlint accept; commitlint skips that commit's generated changelog body.

### Store icons

The launcher icons and the store icons come from the brand mark (`website/src/lib/brand.ts`) and
the colour tokens, through `make app-icons` (`tool/design/build_app_icons.py`); CI fails when a
committed icon is stale (`make app-icons-check`).

- **Google Play:** the listing's app icon is `app/android/store/play-icon-512.png` (512 × 512,
  32-bit PNG, a full square; Play rounds the corners itself). Upload it in Play Console, Grow
  users, Store presence, Main store listing, App icon, and again whenever it changes.
- **App Store:** nothing to upload. The 1024 × 1024 icon in
  `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` ships in the build, and App Store Connect
  takes the store icon from it. The dark and tinted versions beside it are what iOS 18 and later
  show on a home screen set to those looks.

## Rollback and restore

Migrations are forward only: a mistake is fixed by a new migration, never by editing or reverting
an applied one (CONTRIBUTING.md). What can be rolled back, and how:

| What                   | Roll back by                                                                                                                                                                                                                                                                                     |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The web app            | Vercel dashboard, project `maalik-e-makaan`, Deployments: the previous production deployment, Promote to Production (or `vercel rollback <deployment-url> --scope ar27111994s-projects`). Takes effect at once; the database must still suit the older app (migrations add, they do not remove). |
| The website            | The same, project `maalik-e-makaan-site`.                                                                                                                                                                                                                                                        |
| Edge Functions         | Run Deploy by hand on the previous tag (Actions, Deploy, Run workflow, choose the tag): its `supabase` job redeploys that tag's functions. Its `db push` finds nothing new to apply.                                                                                                             |
| A migration            | A new migration that undoes it (forward fix), through the usual process (After every migration). If it destroyed data, restore that data from a backup (below) into a scratch project and copy the rows back.                                                                                    |
| Data lost or corrupted | Restore from a backup (below).                                                                                                                                                                                                                                                                   |

### Backups

The free plan has no backups the owner can download or restore: Supabase backs up Pro, Team and
Enterprise projects daily, and recommends that free projects export their data with
`supabase db dump` and keep the copies off-site
([Database Backups](https://supabase.com/docs/guides/platform/backups)). The **Backup** workflow
(`.github/workflows/backup.yml`) does that every Monday at 02:41 Pakistan time, and by hand
(Actions, Backup, Run workflow) before every release that carries a migration:

1. It links the project with `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD`, and dumps the
   data only (the schema comes back from the migration chain, Restoring below):

   ```bash
   supabase db dump --linked -f data.sql --use-copy --data-only \
     -x storage.buckets -x storage.buckets_vectors -x storage.vector_indexes
   ```

2. It records the schema fingerprint, the applied migration versions and the commit, and warns
   when the project's history differs from the commit's chain.
3. It downloads every file in the `documents` bucket (`supabase storage cp -r ss:///documents`),
   and fails unless it got as many files as `storage.objects` lists.
4. It encrypts all of it with [age](https://age-encryption.org) to the backup key (below), checks
   that the file names every recipient, and keeps only the ciphertext, as the artefact
   `database-backup-<UTC time>` of the run, for 90 days (the privacy policy says 90 days). The
   plaintext is shredded on the runner; the logs name tables and count rows, never print one.

GitHub turns off the scheduled runs of a public repository after 60 days without a commit,
and e-mails the owner when it does. If that happens, turn Backup back on (Actions, Backup, Enable
workflow); a run by hand works either way.

When the hosted history and the commit's chain differ, the run still keeps the encrypted backup
but fails at the end, saying it was not proven to restore. Migrations merged but not yet applied
(normal just before a release) are left out of the check, which then passes; a migration applied
but missing from `main` leaves nothing to compare against, so fix that drift first.

**The backup key.** The workflow encrypts only to the public keys in the repository variable
`BACKUP_AGE_RECIPIENTS`, one per line (age keys `age1...`, or ed25519 and RSA SSH public keys),
and fails, before dumping anything, when there is none. Nothing else can open a backup, so a key
added to the GitHub account later does not become a backup key. The owner makes the key once,
on a trusted computer:

```bash
age-keygen -o maalik-e-makaan-backup.key   # prints "Public key: age1..."
```

(Windows: `winget install FiloSottile.age`; macOS: `brew install age`; Linux: the `age`
package.) Put the `age1...` line in the variable (Settings, Secrets and variables, Actions,
Variables). Keep the `.key` file in a password manager and one offline copy: without it no
backup can be opened, and anyone with it can open all of them. To change keys, add the new public
key, wait for one backup, then remove the old one; backups already taken stay readable only with
the key they were made for.

**Opening a backup.** Download the artefact from the run (Actions, Backup, the run, Artifacts),
unzip it, then:

```bash
age -d -i maalik-e-makaan-backup.key -o backup.tar maalik-e-makaan-<time>.tar.age
tar -xf backup.tar   # data/data.sql, data/schema_fingerprint.json, data/migrations.txt, documents/
```

`data/data.sql` holds tenants' CNICs, phone numbers and the whole ledger: open it only on a
trusted computer, and delete the plaintext when done.

**Every backup is restored and checked.** The same run starts a local Supabase stack from
the commit's migration chain (`supabase start`, then `supabase db reset --local --no-seed`),
stops its pg_cron jobs, empties the tables the dump fills, loads `data.sql` by step 3 of
Restoring (triggers off, one transaction), and checks that `tool/db/fingerprint_diff.py` says
"schemas match" against the hosted project and that `tool/db/dump_digest.py compare` finds every
table's rows equal in a fresh dump of the stack. The backup is kept either way; a failed check
fails the run at its end. A failed load names the table and the SQLSTATE only: PostgreSQL's own
message quotes the row, so it is kept off the public log. The hosted project lets `postgres` set `session_replication_role = replica` (checked on 2026-11-09), so step 3 of
Restoring works there too. The rehearsal does not use a hosted scratch project: the repository's
`SUPABASE_ACCESS_TOKEN` is scoped and may not create projects, and should stay that way.

### Restoring

Restore into a **new** project, never over the live one, then point the app at it. Rebuild the
schema from the migration chain and load only the data. Do not restore a `supabase db dump`
schema file (Supabase's generic recipe): the 2026-11-08 rehearsal showed that it loses the
policies on `storage.objects`, the triggers on `auth.users` and `storage.objects` and the
pg_cron jobs (the dump leaves out the `auth`, `storage` and `cron` schemas), and that every
function comes back executable by `anon` and `service_role`, which the chain revokes (decision
D-15).

1. Create a project in the same region (ap-south-1) and link it:
   `supabase link --project-ref <new-ref>`.
2. Apply the chain at the tag that was live when the dump was taken:
   `git checkout vX.Y.Z && supabase db push --linked`. This creates the schema, the grants, the
   storage bucket and policies, the Auth trigger and the pg_cron jobs.
3. Load the data, triggers off, in one transaction:

   ```bash
   psql --single-transaction --variable ON_ERROR_STOP=1 \
     --command 'SET session_replication_role = replica' --file data.sql \
     --dbname "$NEW_DB_URL"
   ```

   If it stops on a duplicate key in a table the scheduled jobs write (`private.job_runs`), a job
   ran between steps 2 and 3: the transaction rolled back, so truncate that table and load again.

4. Check it: the schema fingerprint equals the chain's (After every migration, step 3:
   `tool/db/fingerprint_diff.py` says "schemas match"), and the row counts of `auth.users`,
   `public.portfolios`, `public.leases`, `public.charges` and `public.payments`, and
   `sum(outstanding)` of the open charges, equal the old project's when it is still reachable.
5. Put the files back, from the backup's `documents/` folder:
   `supabase storage cp -r documents ss:///documents --experimental --linked`. Not rehearsed
   yet (the bucket was empty on 2026-11-09): the rows of `storage.objects` are already loaded
   by step 3, so if the upload refuses objects that exist, delete that bucket's rows from
   `storage.objects` and upload again (the uploader is then recorded as the service role). Rehearse
   this once the bucket holds files.
6. Set up what neither the chain nor the dump carries: the Edge Function secrets and the Vault
   secrets (Storage cleanup), Auth's Site URL, redirect URLs and SMTP, then deploy the functions
   (Deploy by hand, with the repository variables and secrets pointed at the new project).
7. Point the app at it: the `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` variables, then run
   Deploy so the web app is rebuilt. Users must sign in again (the new project signs tokens with
   new keys).

The procedure was rehearsed on 2026-11-08 against the local stack (Supabase CLI 2.122.1,
Postgres 17.11): see `docs/release-readiness.md`, Rollback and restore. Since 2026-11-09 the
Backup workflow repeats steps 2 to 4 on every backup, against a local stack (Backups, above).

## Deleting a user account

Users delete their own accounts in the app (the `delete-account` Edge Function). It calls
`public.admin_delete_account_data` and only then deletes the Auth user. When an operator must
delete a user (a support request, abuse), keep that order:

1. In the SQL editor, run the account-data deletion first. It deletes every portfolio where the
   user is the only owner (with its data and files), removes their other memberships (which clears
   them as caretaker wherever they were one; each clearing is in the audit trail with no actor),
   revokes their pending invitations, clears the country and time zone they declared, and stops
   the account from joining or creating portfolios or changing its residence:

   ```sql
   select public.admin_delete_account_data('<user id>');
   ```

2. Then delete the user in the dashboard (Authentication → Users) or through the Auth admin API.

Known issue (finding M2 of `formal/tla/Membership`, open, low): even in this order, step 2 can
deadlock with the deletion, at the same moment, of a portfolio the user created or worked in. By
then the user belongs to no portfolio, but 30 `ON DELETE SET NULL` foreign keys may still name
them (the portfolios they created, the members they invited, the rows they created, voided or
uploaded, their audit rows). The Auth deletion sets them to NULL row by row without the
portfolio's lock, while the portfolio's deletion holds the portfolio and its audit trail.
PostgreSQL aborts one side with 40P01. If it is the Auth deletion, the user is still in Auth:
repeat step 2 (in the app, the person's retry of `delete-account` runs both steps again). If it
is the portfolio's deletion, it retries up to three times
(`formal/tla/Membership/replay/residence.sh`, R9 and R10). The remedy is the owner's decision:
`admin_delete_account_data` would set those columns to NULL under portfolio locks taken in id
order, so that the Auth deletion finds nothing to lock (the model's README, Finding M2).

Never delete a user in Auth alone:

- Portfolios the user owned alone stay behind with no member at all, so no app user can reach or
  delete them (checked on PostgreSQL 16).
- The deletion can deadlock with an acceptance of one of the user's invitations (finding F3 of
  `formal/tla/Invitations`): GoTrue's `DELETE` holds the `auth.users` row and its
  `ON DELETE SET NULL` waits for the invitation the acceptance holds, while the acceptance's
  membership insert waits for the `auth.users` row. PostgreSQL aborts one of them with 40P01: the invitee sees an
  error, or the deletion fails and must be repeated. A create by the user can fail the same way
  (or with 23503). Step 1 takes the account and then the portfolios `FOR UPDATE`, in the order
  every other writer uses, so in-flight requests finish first and later ones are refused; the
  Auth deletion then has nothing left to wait for (`formal/tla/Invitations/replay_findings.sh`
  checks both orders), on a database built from the migrations (see the restored database
  below).
- A member's deletion can deadlock with a change of their membership or with the portfolio's
  deletion. The cascade deletes the membership and then, by `ON DELETE SET NULL`, needs their
  audit rows (`audit_logs.actor_id`; everyone who created a portfolio or accepted an invitation
  has one) and, for a caretaker, the portfolio row (`portfolios.caretaker_user_id`, the reverse
  of the global order). PostgreSQL aborts one side with 40P01 if at the same moment they leave
  the portfolio (caretaker or not: the leave's audit row needs their `auth.users` row), the
  portfolio is deleted (`delete_portfolio`, or the account deletion of its only owner, which
  holds the portfolio's audit trail), or, for a caretaker, an owner names them
  (`set_caretaker`), changes their role or removes them (`update_member_role`,
  `remove_member`). A portfolio deletion retries and usually succeeds; the others fail
  (`formal/tla/Membership`: the `assume_direct_auth_*` configurations;
  `formal/tla/Membership/replay/residence.sh`, R1, R2, R4 and R8). Step 1 removes the
  memberships first, under the portfolio locks, so the Auth deletion finds none (R5).

After pushing `20261108082804_invitation_findings.sql`, which revokes once the pending invitations
direct Auth deletions left behind, this must answer 0 (`tool/db/upgrade_test.sh` checks the same on a
local upgrade):

```sql
select count(*) from public.portfolio_invitations i
where i.accepted_at is null and i.revoked_at is null
  and (i.invited_by is null or not exists (
    select 1 from public.portfolio_members m
    where m.portfolio_id = i.portfolio_id and m.user_id = i.invited_by and m.role = 'owner'));
```

If a user was deleted in Auth alone, their pending invitations are revoked anyway (since
`20261108082804_invitation_findings.sql`), but their sole-owned portfolios are left without
members. Find and delete them in the SQL editor (the deletion queues their files for
storage-cleanup):

```sql
select p.id, p.name from public.portfolios p
where not exists (select 1 from public.portfolio_members m where m.portfolio_id = p.id);

begin;
select private.lock_portfolios_for_deletion(array['<portfolio id>']::uuid[]);
select private.delete_locked_portfolios(array['<portfolio id>']::uuid[]);
commit;
```

Why no trigger on `auth.users` does step 1 for you: a `BEFORE DELETE` trigger runs only after
PostgreSQL has locked the `auth.users` row, so it would lock the account and the portfolios after
that row, while every insert that names the user locks that row last (its foreign-key check). On
PostgreSQL 16.15 and 17.11 such a trigger still deadlocked with an acceptance in the same
interleaving (`replay_findings.sh` keeps that check). It would also run inside GoTrue's transaction, where any
error it raised would fail the Auth deletion. For a caretaker, a trigger that cleared the caretaker
first would avoid the deadlock with `update_member_role` and `remove_member`, but not the one with
`set_caretaker`, whose foreign-key check needs the `auth.users` row last
(`formal/tla/Membership/replay/residence.sh` checks both), nor those with leaving or with the
portfolio's deletion through the audit row.

### Changing a membership by hand

The app changes memberships through `update_member_role` and `remove_member`, which lock the
portfolio first. An operator who changes or deletes a `portfolio_members` row in the SQL editor
does the same, in one transaction:

```sql
begin;
select 1 from public.portfolios where id = '<portfolio id>' for update;
update public.portfolio_members set role = 'viewer'
where portfolio_id = '<portfolio id>' and user_id = '<user id>';
commit;
```

Without the first statement, a change to the caretaker's membership locks the row and then, in
its trigger (which clears the caretaker), the portfolio row: if an owner's `update_member_role`
or `remove_member` of that person holds the portfolio at the same moment, PostgreSQL aborts one
of them with 40P01 (`formal/tla/Membership`, `assume_service_member_write`;
`formal/tla/Membership/replay/residence.sh`, R3). Concurrency scenario 31 checks the rule
(`operator_locks_portfolio_first_*`).

### A database restored from a dump

Every order above holds on a database built from the migrations, where the foreign keys'
actions on `auth.users` run in the order the migrations created them. A schema re-created from
a dump (`pg_dump`, `supabase db dump`) gets them back in constraint-name order: the
notifications are deleted before the profile, and the `ON DELETE SET NULL` of
`portfolio_members.invited_by` runs before that of `portfolios.created_by`. There, even step 1
first does not keep the Auth deletion of a user who created a portfolio and invited one of its
members from deadlocking with an owner who names that member caretaker or changes their role at
the same moment, and a direct Auth deletion can deadlock with the person marking notifications
read (`formal/tla/Membership`: `assume_restored_inviter`, `assume_restored_notes`;
`formal/tla/Membership/replay/residence.sh`, R6 and R7, on a `pg_dump | psql` copy). The
procedure in [Restoring](#restoring) rebuilds the schema from the migrations, which keeps their
order: never restore the schema from a dump.

## Time-zone data

The app bundles the IANA tz database in `mm_core` for each person's own alerts, quiet hours and
dual time; business dates stay on Pakistan time ([time](architecture/time.md)). The data comes from
the PyPI `tzdata` package pinned in `tool/requirements.txt`. When IANA publishes a release
(Dependabot opens the bump for `/tool`):

1. Bump `tzdata` in `tool/requirements.txt` with its hash from PyPI, and install it
   (`make bootstrap`).
2. Run `make contracts`. It rewrites `contracts/residence_vectors.json`,
   `contracts/time_zone_vectors.json`, `packages/mm_core/lib/src/time/time_zone_data.g.dart`,
   suite 23 and `tool/db/time_zone_skew.sql`, and fails if the release dropped a stored name or put
   two clock changes of a zone less than two days apart.
3. If `zone.tab` or `iso3166.tab` gained a name, write a migration that widens
   `app.supported_time_zones()` or `app.supported_country_codes()` first, with the lists from
   `python3 tool/contracts/generate.py --print-sql-lists` (no revalidation is needed: no stored
   value becomes invalid). Suite 23 fails until it is there. Apply it to the hosted project before
   the app release.
4. Run `make test-core test-db`, then release the app.
5. A name never leaves the lists: one that leaves `zone.tab` goes into `RETAINED_ZONES` in
   `tool/contracts/time_zones.py` with the zone it now links to (codes into
   `RETAINED_COUNTRIES`).

The hosted database keeps its own tz data (the Supabase image's). After each Supabase Postgres
upgrade, and after a `tzdata` bump, run `tool/db/time_zone_skew.sql` on the hosted project (SQL
editor, read-only). Every row it returns is a stored zone and an instant where the server's offset
differs from the app's. Rows are normal when the server's `tzdata` and the pinned one are different
releases; read each one this way:

- `Asia/Karachi`: never expected. Stop and follow "The Pakistan tripwire" in
  [time](architecture/time.md): Pakistan's clock has changed, and business time needs its own
  change.
- A zone that a release between the server's and the pinned one changed (IANA's `NEWS` file names
  the zones of each release; on PostgreSQL 16 with tzdata 2026e it is `America/Havana`, which
  2026f changed), or `Africa/Casablanca`, whose changes Morocco sets year by year: expected. Record
  the rows where the run is recorded (its commit, and `.planning/STATE.md`, Hosted Supabase
  Project). Nothing reads a stored zone in SQL yet, so they change nothing; once the push
  planner's SQL helpers exist, a person in that zone may get an alert an hour early or late on the
  dates listed, until the two releases agree.
- `server_seconds` NULL (the server does not know the zone), or a row no release explains: look
  into it before any SQL relies on that zone.

Business dates are unaffected: they use Pakistan's fixed offset.

## Phone and CNIC checks (`20261108200216`, `20261108200227`)

Both files were applied to the hosted project on 2026-11-08 (commit e853378 records it). The steps
below stay for any other project the chain is applied to.

`20261108200216_identity_checks.sql` was later wrapped in `begin; … commit;` (docs/uat.md, D1):
the Supabase CLI sends a file as one implicit transaction, which is not a transaction block, so
its `LOCK TABLE` stopped `supabase start`, `db reset` and any `db push` to a new project with
SQLSTATE 25P01. The schema it builds is unchanged (the schema fingerprints with and without the
wrap are identical), and the hosted project, which records the version, does not apply it again:
the CLI compares versions, not contents. `tool/db/check_migration_transactions.py` (`make lint`)
now rejects such a statement outside an explicit transaction.

Before pushing `20261108200216_identity_checks.sql`, run the count query in its header on the
hosted project (SQL editor, read-only). Every row must say 0. If one does not, the migration would
stop with SQLSTATE 23514 and change nothing: have the owners correct those values in the app, or
set them to NULL with their agreement, and run the query again.

The migration locks the five tables against writes (reads go on) from its own count until it
commits, so a write cannot slip in between (`tool/db/upgrade/20261108200216.race.sql` checks
this locally). If `20261108200227_identity_checks_validate.sql` fails anyway, the first file is
already applied and its CHECKs are enforced on new writes but still `NOT VALID`: run the same
count query, have the values fixed, and push again. Only the validate file is left to apply.

## After every migration

Migrations reach the hosted project in one of two ways, and agents use neither on their own:

- By the owner, through the Supabase MCP `apply_migration` (decision D-14 in
  `.planning/PROJECT.md`), which records the migration under its name with a version the
  platform assigns. The local file is then renamed to that version, so the chain and the hosted
  history agree.
- By the Deploy workflow's `supabase` job, which runs `supabase db push --linked --dry-run` and
  then `supabase db push --linked` (see Deployment above).

Then:

1. Check that every local file's version equals the version the platform records
   (`supabase migration list`).
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
   (the 23 write RPCs pinned in `supabase/tests/database/01_schema_security.test.sql`).
5. List the order in which GoTrue's foreign-key actions on `auth.users` run (read-only, SQL
   editor), and compare it with the migrated order `formal/tla/Membership/replay/residence.sh`
   prints:

   ```sql
   select string_agg(c.conrelid::regclass || '.' || a.attname, ', ' order by t.tgname collate "C")
   from pg_trigger t
   join pg_constraint c on c.oid = t.tgconstraint
   join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
   where t.tgrelid = 'auth.users'::regclass and t.tgname like 'RI_ConstraintTrigger_a_%'
     and t.tgtype & 8 = 8;
   ```

   `portfolios.caretaker_user_id` comes last while its trigger's OID has as many digits as the
   others'. If it comes before `portfolio_members.user_id`, record it in `.planning/STATE.md`:
   the Membership model's `caretaker_first` configurations then describe the hosted project (see
   its README, What is modelled).
