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
   answers 403 `deep_check_disabled`; with a wrong or missing header, 401. Add a monitor on the
   web app, `https://app.mmakaan.app/`, and one on the website, `https://mmakaan.app/` (200 each,
   with the certificate checked on the same host). All three are on Checkly since 15 November
   2026, every 5 minutes from one location, alerting the owner by e-mail. The account's plan
   read "Trial" that day: when the trial ends, check that all three still run.

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
| `MAIL_REPLY_TO`          | invite-member   | Optional: where a reply to an invitation goes (the company's mailbox).   |
| `HEALTH_CHECK_TOKEN`     | health          | At least 32 characters; enables deep checks.                             |
| `REAUTH_MAX_AGE_SECONDS` | delete-account  | 60–3600, default 600: how recent a sign-in must be to delete an account. |
| `STORAGE_CLEANUP_TOKEN`  | storage-cleanup | At least 32 characters; also stored in Vault (above).                    |

A malformed optional secret breaks only the feature that uses it (the function answers 500
`server_misconfigured` naming the variable); a malformed `ALLOWED_ORIGINS` breaks every function,
because CORS needs it on every request. `supabase/functions/.env.example` lists the same secrets
for local development.

While the web app has an earlier address that still serves e-mail links ([Domains](#domains)),
`ALLOWED_ORIGINS` names both: `https://app.mmakaan.app,https://maalik-e-makaan.vercel.app` (set by
the owner, reported on 14 November 2026). The Deploy workflow's `web` job checks before it builds
that the functions accept the web app's origin (a CORS preflight to `health` must answer 204), and
fails otherwise; for an earlier address it only warns. No secret holds the website's address.
`APP_URL` is `https://app.mmakaan.app` since 14 November 2026 (the owner), so invitation links
open on the new address ([Domains](#domains), step 8, has what that means before the release).
No workflow reads a secret's value, and none depends on which address `APP_URL` holds.

## E-mail

Supabase Auth's own sender is for testing only: it sends only to the project's team members, a
few an hour, so real users cannot sign up until custom SMTP is set. The project uses
[Resend](https://resend.com) for both kinds of e-mail: Auth's (confirm sign-up, reset password,
change e-mail address) through SMTP, and invitations through the HTTP API (`invite-member`).
Resend's free plan (3,000 e-mails a month, 100 a day, one domain, in November 2026) is enough at
launch; Auth and invitations share the daily 100. Check the plan's terms allow production use.

1. **A domain.** Resend sends to other people only from a domain whose DNS you control; a
   `vercel.app` address cannot be one. **Keep exactly one DMARC record** (below). Add the domain in
   Resend, then add at the DNS host exactly the DKIM and sending records Resend's page for that
   domain lists, as records on their own subdomains, and wait for "Verified"; a DMARC record that
   page suggests is added only when the domain has none yet. Copy the records from that page, not
   from a guide: they changed in 2026. For `mmakaan.app` (region ap-northeast-1, Tokyo; 15
   November 2026) Resend asked for a DKIM TXT on `resend._domainkey` and two `CNAME` records,
   `send` to `send.forge.rmta.net` and `rsend` to `rsend-apne1.forge.rmta.net`, and not the MX and SPF TXT on
   `send` that this step named before. Leave Resend's "Enable receiving" off, so that the domain's
   own MX records, the mailbox's, keep receiving. Keep exactly one DMARC record at
   `_dmarc.<domain>`: two TXT records that start `v=DMARC1` at one name mean that receivers apply
   neither (RFC 7489, section 6.6.3), and Gmail then shows no DMARC result at all. Where the mail
   host writes one for itself, as Dynadot's e-mail does on `mmakaan.app` (`p=none`), add none of
   your own; where none exists, add `v=DMARC1; p=none;`. In the domain's Configuration, turn **off**
   click tracking and open tracking: click tracking rewrites the sign-in links through Resend's
   servers, and open tracking adds a tracking pixel; the privacy page says the app has no
   trackers.

   **Since 15 November 2026** the app's e-mails come from the company's own address,
   `hello@mmakaan.app` (the owner's decision that day), so the domain in Resend is `mmakaan.app`
   itself, beside the company's mailbox, which Dynadot's e-mail serves on the same name.
   Resend's records sit on `send`, `rsend` and `resend._domainkey`, so the mailbox's own MX and
   SPF records on the apex stay as they are; what the two share is the domain's reputation. The
   owner added the domain at 15:06 UTC and it was verified at 15:21 UTC, with click and open
   tracking off (the owner reported); `news.ar27111994.dev` (verified 2026-11-09) is no longer the
   sender, and the free plan holds one domain. Step 8 has what the first e-mail showed.

2. **Two API keys**, both "Sending access" and limited to that domain: one for Supabase's SMTP,
   one for the `invite-member` function, so either can be revoked alone. After a move to
   another domain, make both again, limited to the new one, as the owner did for `mmakaan.app`
   on 15 November 2026 (reported that day).
3. **Supabase SMTP** (Authentication, Emails, SMTP Settings, Enable custom SMTP): sender
   `hello@mmakaan.app` (a mailbox someone reads, so a reply to a confirmation reaches the
   company), name "Maalik-e-Makaan", host `smtp.resend.com`, port 465, user
   `resend`, password the first key, minimum interval 60 seconds. (Resend's Supabase integration,
   Settings, Integrations, fills in the same.)
4. **Rate limit** (Authentication, Rate Limits, "Email sent"): custom SMTP starts at 30 an hour,
   which is fine. The real ceiling is Resend's 100 a day for Auth and invitations together: past
   it, confirmations and resets stop until the next day. Watch Resend's dashboard, and move to its
   paid plan before sign-ups come near it.
5. **URLs** (Authentication, URL Configuration): Site URL `https://app.mmakaan.app`, redirect
   URLs `https://app.mmakaan.app/auth/callback` (the web and Android apps) and
   `io.github.ar27111994.maalikemakaan://app.mmakaan.app/auth/callback` (the iOS app, which comes
   back through its own URL scheme). The app sends these exact addresses; one missing from the
   list sends the link to the Site URL instead, where the iOS sign-in cannot finish. Keep the
   earlier address's two beside them, `https://maalik-e-makaan.vercel.app/auth/callback` and
   `io.github.ar27111994.maalikemakaan://maalik-e-makaan.vercel.app/auth/callback`, for as long
   as builds made before the move are in use ([Domains](#domains)). Every release checks these
   settings before its builds, and every deploy before it deploys (`tool/web/check_auth_urls.py`,
   in the Release workflow's `preflight` job and the Deploy workflow's `supabase` job), and stops
   while one that a build sends is not allowed.
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
   `MAIL_FROM="Maalik-e-Makaan <hello@mmakaan.app>"` (Edge Function secrets, above; with the
   name, so that an inbox shows it and not "hello").
8. **Check**: sign up in each language, reset a password, change an address, and invite someone
   outside the team. Each link should open `/auth/callback`, and "Show original" in Gmail should
   say SPF, DKIM and DMARC "PASS". **On 15 November 2026** the agent read the raw headers of a
   sign-up confirmation sent at 15:44 UTC: From `Maalik-e-Makaan <hello@mmakaan.app>`,
   `dkim=pass` for `mmakaan.app` with the selector `resend`, `spf=pass` with the return path on
   the domain's `rsend` subdomain, links straight to the Auth server and no image in the HTML (so
   neither click nor open tracking is on), and the link returning to
   `https://app.mmakaan.app/auth/callback`. Gmail's result had no `dmarc` entry: `_dmarc` held two
   records then, the owner's and Dynadot's own, and the owner removed theirs (step 1); a lookup
   afterwards showed Dynadot's own record alone, `p=none`. Still open, the owner's: an e-mail that
   shows `dmarc=pass`, and the password reset and invitation e-mails, which the agent has not seen.

## Hosting (Vercel)

Two Vercel projects in the `ar27111994s-projects` team. Previews need a Vercel login;
production is public.

| Project                | Serves                         | Production address                                                                                                                                     |
| ---------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `maalik-e-makaan`      | the Flutter web app (`app/`)   | <!-- docs:app-origin from contracts/origins.json app.origin; generated by make docs, do not edit --><https://app.mmakaan.app><!-- /docs:app-origin --> |
| `maalik-e-makaan-site` | the Astro website (`website/`) | <!-- docs:site-origin from contracts/origins.json site.origin; generated by make docs, do not edit --><https://mmakaan.app><!-- /docs:site-origin -->  |

The addresses are `app.origin` and `site.origin` in
[`contracts/origins.json`](../contracts/origins.json) (decision D-20), the one place they are
written; each project's earlier `vercel.app` address sends people on to it
([Domains](#domains)). The web app's origin is its `APP_URL`: Supabase Auth's Site URL, its
redirect `APP_URL/auth/callback`, the invitation links and the Edge Functions' allowed origin.

### The web app on Vercel

Nothing is built on Vercel. The Deploy workflow builds the app (`flutter build web
--no-web-resources-cdn`, so CanvasKit is served from the app's own origin), and
`tool/web/package_vercel.py` turns `app/build/web` into a
[Build Output API v3](https://vercel.com/docs/build-output-api/configuration) directory
(`.vercel/output/static` plus `config.json`). `vercel deploy --prebuilt --prod` then uploads that
directory. The routes in `config.json`, in order:

1. Security headers on every response, the page of an earlier address included: the
   Content-Security-Policy below, HSTS (two years), `X-Content-Type-Options: nosniff`,
   `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY`,
   `Cross-Origin-Opener-Policy: same-origin`, and a `Permissions-Policy` that turns off the
   camera, microphone, geolocation, motion sensors, payment and USB. With them,
   `X-Robots-Tag: noindex`: every path answers with the app's shell, and the website is what
   search engines index (D-01).
2. `Cache-Control`. Flutter's file names (`main.dart.js`, `canvaskit/*`, `assets/*`) carry no
   content hash and stay the same from build to build, so every file is revalidated on each load
   (`no-cache`; an unchanged file answers 304). A file whose name does carry a hash
   (`name.0123abcd.ext`) gets `max-age=31536000, immutable`. The entry points (`index.html`,
   `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`, `manifest.json`) and
   `assetlinks.json` are always `no-cache`.
3. On an earlier address (`app.legacy` in `contracts/origins.json`, matched on the request's
   host): `/` and `/index.html`, also with more slashes before them (`//`, `//index.html`), answer
   200 with the page that clears what the app kept in the browser there and goes to the origin
   (`moved.html`, below), with the header `Clear-Site-Data: "storage"`.
4. `{"handle": "filesystem"}`: existing files are served, on every host.
5. On an earlier address: every other path but `/auth/callback` answers with the same page and
   header. The page's script goes to the same path, query and `#fragment` on the origin, so an
   invitation link keeps its `#token=…`.
6. Every other path, such as `/auth/callback?code=…` or `/invite/…`, serves `index.html` with
   status 200, and the app's router takes over.

`/.well-known/assetlinks.json` comes from `app/web/.well-known/` (the Flutter build copies it) and
is served as `application/json`, on the earlier address too ([Domains](#domains)).

On the earlier address only `/auth/callback` and `/.well-known/assetlinks.json` as written are
kept, the only forms Android and the e-mail links request. A form with a slash more
(`//auth/callback`, `/auth//callback`, `/auth/callback/`, `/.well-known//assetlinks.json`) is
another path and gets the page and its header, in `tool/web/serve_output.py` and in the tests that
pin it. Whether Vercel's filesystem step reads `//.well-known/assetlinks.json` as the file is not
in its documentation, so that form may get either answer there.

`moved.html` and `moved.js` are not part of the Flutter build: `package_vercel.py` copies them
from `tool/web/moved/` into the package when the web app has an earlier address, with the origin
written into the page, and refuses a build that already holds a file of either name. They are
files on the origin too, where the script does nothing. Why the earlier address answers with a
page and not a redirect, and what the header and the script each clear, is in
[Domains](#what-the-earlier-address-kept-in-the-browser).

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
`tool/web/smoke_test.sh` against the same local server on every push, and
`tool/web/redirect_smoke_test.sh --page` as each earlier address.

After a change to the earlier address's page, its script or their routes, check them in a browser
too:

```bash
node tool/web/moved_browser_check.cjs /tmp/web/.vercel/output
```

It opens the earlier address in Chromium (resolved to the local server and treated as a secure
origin, since a browser ignores `Clear-Site-Data` over plain http) and fails unless: with the
header, everything that address kept is gone and the browser is at the same path, query and
fragment on the origin; with the header taken off, the script alone removes the app's keys and
goes to the same address; without scripts, the browser reaches the origin's first page; the App
Links file, the callback and the app's files clear nothing; and nothing breaks the CSP.

### The website on Vercel

The website is built in GitHub Actions too, not by Vercel. The Deploy workflow writes the
project's settings into `.vercel/project.json` (root directory `website`, framework Astro), so
`vercel build --prod` runs `website/vercel.json`'s `npm ci` and `npm run build` and turns that
file's headers, trailing slashes and `dist/404.html` into a Build Output API directory;
`vercel deploy --prebuilt --prod` uploads it. The headers and the Content-Security-Policy are
described in [`website/README.md`](../website/README.md#security-headers).

The build bakes the site's own address into every page (canonical and `hreflang` links, Open
Graph URLs, the sitemap, `robots.txt`, `llms.txt`) and the web app's into its links and JSON-LD.
Both come from `contracts/origins.json` at the ref it builds (`site.origin` and `app.origin`,
read by `website/src/config/urls.ts`); the Deploy workflow sets neither `SITE_URL` nor
`PUBLIC_APP_URL`. A site refresh of an older tag therefore builds the addresses that tag was
released with, and a move reaches the site with the release that carries it. The `site` job reads
the origin back from the built sitemap, checks it against the ref's file and smoke-tests it.

Every production deployment is aliased to `mmakaan.app`, to `www.mmakaan.app` (which the
project's domain setting redirects to `mmakaan.app`) and to the project's first address,
`maalik-e-makaan-site.vercel.app`, which `website/vercel.json` redirects to `mmakaan.app` with
the path and the query ([Domains](#domains)).

Three things on the site update themselves, so a release needs no copy edits for them:

- **The release.** The download page's "Version …" block, the footer's version line, the
  release notes page (`/releases/`) and `llms.txt` are built from `CHANGELOG.md` and
  `.release-please-manifest.json` (`website/src/lib/release.ts`). The Release workflow deploys the
  site at the tag it has just made, so they always show that release; from version 1.0.0 the
  site describes the app as available rather than in development. The download page links to the
  APKs, the unsigned iOS app, the web zip and `SHA256SUMS` (not to the provenance files, which it
  mentions with a link to `SECURITY.md`, Checking a download), which exist only once Release's
  `artefacts` and `ios` jobs have attached them. So the `site` job lists the files attached when
  it runs (`website/src/data/release-assets.json`) and the page links to those alone, and Release
  deploys the site after both builds have finished (Deployment, below). A build that fails, even
  on every re-run, then costs the page that build's links only (all but any to files that an
  upload cut off part-way left on the release), never the deploy.
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

## Domains

The company's domain is `mmakaan.app`, registered at Dynadot, whose DNS serves it (decision
D-20). The website is on the apex and the web app on `app.`; both were first on `vercel.app`
addresses, which send people on to them for good. The company's mailbox is `hello@mmakaan.app`,
on Dynadot's own e-mail (its free plan, not Zoho Mail; the owner, 13 November 2026). It is the
contact address the website, its `llms.txt` and the pitch deck give (`contactEmail` in
`website/src/config/site.ts`), and the only address on the domain that a page or a document may
name: `make docs-check` refuses any other until it is added to `NAMED_MAILBOXES` in
`tool/docs/fact_registry.py`. A test message from the mailbox to Gmail passed SPF and DKIM for
`mmakaan.app` that day. `_dmarc` holds one record, Dynadot's own (`p=none`): the owner's own,
added that day beside it, was removed on 15 November 2026, since two DMARC records at one name
mean that none applies (E-mail, step 1). Auth's e-mails and the invitations are sent from
`hello@mmakaan.app` through Resend since 15 November 2026 (E-mail, above).

| Host                              | Vercel project         | Answers                                                                                                                                                                                                  |
| --------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mmakaan.app`                     | `maalik-e-makaan-site` | the website                                                                                                                                                                                              |
| `www.mmakaan.app`                 | `maalik-e-makaan-site` | 308 to `https://mmakaan.app`, path and query kept (the project's domain setting)                                                                                                                         |
| `maalik-e-makaan-site.vercel.app` | `maalik-e-makaan-site` | 308 to the same path and query on `mmakaan.app` (`website/vercel.json`), except a Google verification file `/google<hex>.html`                                                                           |
| `app.mmakaan.app`                 | `maalik-e-makaan`      | the web app                                                                                                                                                                                              |
| `maalik-e-makaan.vercel.app`      | `maalik-e-makaan`      | `/.well-known/assetlinks.json`, the app's files and `/auth/callback` as before; every other path 200 with the page that clears what the app kept there and goes to the same address on `app.mmakaan.app` |

**One source.** [`contracts/origins.json`](../contracts/origins.json) names each origin once, and
each earlier address under `legacy` (and `www` under the site's `aliases`). Code reads it: the
website's defaults, the deck, the Deploy and Release workflows (`APP_URL` for every build, and the
checks below) and the page the web app's earlier address answers with
(`tool/web/package_vercel.py`). Two files spell the addresses themselves, and CI checks them
against it: the Android manifest's App Link hosts (`tool/android/check_manifest.py`) and
`website/vercel.json`'s redirect (`tests/unit/vercel.test.ts`). The docs name the origins through
generated facts, and C17 of `make docs-check` checks every other address in the repository. The
addresses travel with the release tag: nothing changes in production until the release that
carries a change to the file, and a site refresh of an older tag keeps that tag's addresses.

**Checked before anything is deployed.** The workflows refuse to send people to an address that
cannot answer for them. Each check stops the jobs that wait for it, and only those:

- Release builds and attaches nothing until its `preflight` job has passed, and its `artefacts` and
  `ios` jobs wait for it. That job checks that the web app's origin answers over HTTPS with its App
  Links file (`tool/web/check_live.py app`): every build names the origin, and an Android build
  lists it in its App Links, where on Android 6 to 11 one host that fails costs every host's links.
  It then checks that Auth allows the e-mail links the builds send (`tool/web/check_auth_urls.py`,
  step 4 below): a callback Auth does not allow gets its links at the Site URL, where no build
  finishes the sign-in, and an APK cannot be recalled. With a token that may not read Auth's
  settings (HTTP 401 or 403) that check only warns and stops nothing: step 7 below says what to
  compare by hand then. Deploy's `web` job checks the origin again before it builds.
- Deploy's `site` job deploys nothing until the site's origin answers, `www` redirects to it, and
  the web app the site links to is the deployment built for its origin: the web app's earlier
  address must already send people on to it, with its page or a 308
  (`tool/web/check_live.py site`). Release also deploys the website only after the web app's deploy
  has succeeded.
- Deploy's `supabase` job deploys nothing until Auth allows the e-mail links of the release's builds
  (the same `tool/web/check_auth_urls.py`, and the same warning in place of a check when the token
  may not read Auth's settings), and its `web` job, which waits for it, builds nothing until the
  Edge Functions accept the origin (step 5).
- Release's `deploy` call runs beside `preflight` and the builds. So when the Edge Functions refuse
  the origin, only the web app's deploy stops (and the website after it): the builds may already be
  attached and the backend deployed, which is harmless, since apps send no `Origin` and only a
  browser's calls are refused. And when the web app's origin does not answer, Deploy's `supabase`
  job, which does not check it, may already have deployed the backend.
- A token that may not read Auth's settings (401 or 403) only warns, in both places: the builds
  and the backend's deploy then go ahead, so compare Authentication, URL Configuration with step 4
  by hand before approving the Deploy run.

None of these reads the `APP_URL` secret or repository variable, or depends on the address either
holds: the checks compare what production answers with `contracts/origins.json`, and Auth's
settings with the callbacks the builds send.

**What the earlier addresses keep answering, and why.**

- `maalik-e-makaan.vercel.app/.well-known/assetlinks.json`, for as long as the address exists: every
  Android build from the release that carries the move on also lists the old host in its App Links,
  and Android checks the file on each host without following a redirect. Builds from before the move
  list only the old host. Their sign-up, reset and e-mail-change links name the build's own
  `APP_URL`, the old address, so they keep opening the app. Invitation links do not: the server
  builds them from the Edge Functions' `APP_URL` secret, which names the new address since 14
  November 2026 (step 8), so such a build opens an invitation in the browser, on the web app, where
  the invitee signs in; installing the new APK brings invitations back into the app.
- `maalik-e-makaan.vercel.app/auth/callback` and the files it needs, until a release at least
  24 hours after the move's: a sign-up, reset or e-mail change requested on the old address
  keeps its sign-in verifier in that origin's storage, so its link must finish there, and the
  response must not clear that storage. That later release answers it like every other path,
  keeping only `assetlinks.json` (step 12). A release in between, without that change, leaves
  it as it is.
- Every other path of the web app's earlier address answers 200 with one small page, which clears
  what the app kept in the browser for that address and goes to the same path, query and
  `#fragment` on the origin (below). An invitation link, `/invite#token=…`, arrives with its token;
  on Android the App Link opens the app before any request.
- Every path of the website's earlier address redirects with 308 (permanent, the method kept), with
  the path and the query: Vercel passes the request's query on to a redirect's destination
  (Vercel's documentation, Redirects), and the redirect smoke tests check it after every deploy.
  The website keeps nothing in the browser, so it has nothing to clear.
- Keep both for at least a year, and best for good: links in old e-mails, bookmarks and search
  results use them.

### What the earlier address kept in the browser

A browser keeps what a web app stores apart for each address. On `maalik-e-makaan.vercel.app` the
app kept, in `localStorage`: the Supabase session (`sb-<project>-auth-token`), every list it had
loaded (`mm.swr.v1.*`, CNICs among them), the portfolio last open, an invitation not yet
answered, the settings (`mm.settings.*`) and a sign-in link's verifier
(`flutter.supabase.auth.token-code-verifier`). The app on `app.mmakaan.app` cannot read or remove
them, and once the earlier address only sent people on, no app would run there again to do it. So
the earlier address removes them itself, the first time a browser comes back to it
(`tool/web/moved/`, packaged by `tool/web/package_vercel.py`):

- **The header.** Every page of the earlier address answers `Clear-Site-Data: "storage"`, which
  tells the browser to delete that origin's `localStorage`, `sessionStorage`, IndexedDB and service
  workers before it shows the response. Only `"storage"`: `"cache"` can stall Chromium for seconds,
  and the app's files are revalidated on every load anyway; `"executionContexts"` reloads pages, and
  only Safari 17 to 18.3 and Firefox 63 to 68 ever acted on it; `"cookies"` has nothing to clear,
  since the app sets no cookie and keeps its session in `localStorage`; and `"*"` means all of
  them.
- **The script.** The page's script (`moved.js`: same-origin, no inline code, no HTML or script
  sink, so the app's Content-Security-Policy and Trusted Types allow it as they are) removes the
  app's own keys (`mm.*`, `sb-…-auth-token`, `flutter.*`) with `localStorage` calls, then replaces
  the address with the same path, query and `#fragment` on the origin. It is what clears in a
  browser that does not know the header: Safari before 17, which every browser on an iPhone or iPad
  up to iOS 16 is. On the origin itself, where the page's files are served too, it removes nothing
  and goes nowhere, so the page cannot loop.
- **Without scripts** a `<meta http-equiv="refresh">` inside `<noscript>` goes to the origin's
  first page, and the page shows a link in English and Urdu. The app itself needs scripts, so a
  browser without them kept nothing.

Why a page, and not a redirect that carries the header (researched on 14 November 2026):

| Browser                                          | Knows the header since | Acts on it on a redirect it follows                            |
| ------------------------------------------------ | ---------------------- | -------------------------------------------------------------- |
| Chromium (Chrome, Edge, Opera, Samsung Internet) | 61                     | Yes, by its source and its own browser test; tried here in 153 |
| Firefox                                          | 63                     | Yes, by its source                                             |
| Safari and every browser on iOS (WebKit)         | 17 (September 2023)    | No, by its source: only on the response a navigation ends on   |

- The specification applies the header to every response from the network, a redirect's included:
  "If the Clear-Site-Data header is present in an HTTP response received from the network, then
  data MUST be cleared before rendering the response to the user", as a step of Fetch's
  HTTP-network fetch, which runs for each response before a redirect is followed
  ([Clear Site Data](https://www.w3.org/TR/clear-site-data/), Fetch Integration; read in the
  specification's source, `index.src.html` of
  [w3c/webappsec-clear-site-data](https://github.com/w3c/webappsec-clear-site-data)). It needs a
  secure origin, and ignores a response a service worker made.
- Chromium handles the header for every response's headers, in
  `NetworkServiceNetworkDelegate::OnHeadersReceived`
  ([`network_service_network_delegate.cc`](https://github.com/chromium/chromium/blob/main/services/network/network_service_network_delegate.cc)),
  and holds the request until the data is cleared. Its browser test `RedirectNavigation`
  ([`clear_site_data_handler_browsertest.cc`](https://github.com/chromium/chromium/blob/main/content/browser/browsing_data/clear_site_data_handler_browsertest.cc))
  checks that "the header is recognized on the beginning, in the middle, and on the end of a
  navigation redirect chain". Tried here in Chromium 153: a 308 with the header cleared the
  redirecting origin's `localStorage` and IndexedDB, and the browser followed it with the fragment.
- Firefox notifies its `clear-site-data` observer for any response that has the header, in
  `nsHttpChannel::ContinueProcessResponse1`
  ([`nsHttpChannel.cpp`](https://github.com/mozilla-firefox/firefox/blob/main/netwerk/protocol/http/nsHttpChannel.cpp)),
  before the redirect is processed; the observer
  ([`ClearSiteData.cpp`](https://github.com/mozilla-firefox/firefox/blob/main/toolkit/components/clearsitedata/ClearSiteData.cpp))
  suspends the channel until the data is deleted.
- WebKit calls `processClearSiteDataHeader` only from `NetworkResourceLoader::didReceiveResponse`
  ([`NetworkResourceLoader.cpp`](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/NetworkProcess/NetworkResourceLoader.cpp)),
  which a navigation reaches for the response it ends on; the path of a redirect it follows
  (`willSendRedirectedRequest`) never calls it. This is from reading the source, not from a test in
  Safari: no Safari or Firefox was at hand, and their bug trackers could not be reached from here.
- The versions and the state of each directive are MDN's
  ([Clear-Site-Data](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Clear-Site-Data)
  and its browser-compatibility data): Chrome 61, Firefox 63, Safari 17; `"cache"` "may cause
  seconds-long hangs" in Chrome; `"executionContexts"` never in Chrome, Firefox 63 to 68, Safari 17
  to 18.3.

So a redirect with the header would have cleared in Chromium and Firefox, but in no Safari, and a
browser without the header clears nothing unless a page runs. A page answered with the header
clears in all of them. What it costs: the earlier address answers 200 with HTML where a redirect
answers 308, so a client that runs no script and follows no meta refresh (`curl`, a link checker)
stays on the page. Search engines are not among them (the web app answers `X-Robots-Tag: noindex`),
and Android opens an App Link in the app before any request.

Where it never clears: `/.well-known/assetlinks.json` and the app's other files, which are served as
files, and `/auth/callback` until a release at least 24 hours after the move's (step 12). A link
requested on the earlier address before the move has its verifier in that address's storage, and
Auth's links live an hour (`otp_expiry = 3600` in `supabase/config.toml`; the hosted project is
assumed to keep that default, and the dashboard allows up to a day, which is why step 12 waits at
least 24 hours). One case is lost: a link requested on the earlier address in its last hour, when
the same browser opens another page of that address after the release and before the link. That
visit removes the verifier, the app says to request the link again, and on the new address that
works. The session a browser held on the earlier address is removed from the browser, not ended on
the server, where it stays until it is revoked; nothing else holds its token.

The checks: `tool/web/test_package_vercel.py` (the routes: the header on the earlier addresses'
pages alone, never without the host condition, and the local server's answers for every route and
host); `tool/web/test_moved_js.py` (the script, run in Node: which keys go, the address it goes to,
nothing on the origin, storage a browser blocks, and that it removes every key the app's sources
write); `tool/web/redirect_smoke_test.sh --page` (in CI against the local server and after every
deploy against the earlier address: the header is `"storage"` alone on the pages, and absent from
the callback and the App Links file); `tool/web/smoke_test.sh` (the origin never sends the header);
and `tool/web/moved_browser_check.cjs` (Chromium, by hand: Hosting, above).

People who used the web app on the old address sign in once more on the new one, and choose their
language and theme again: the new address starts with empty storage, and the old one's is cleared.
A web app installed from the old address is removed and installed again from the new one. The note
for the release that carries the move says so: "If you used the web app at its earlier address,
sign in once more at `app.mmakaan.app`. What the app kept in your browser for the earlier address
is removed when you next open that address."

### Moving the addresses (the order, 2026-11)

The owner's steps, with the agent's pull request between them; `docs/release-readiness.md`, Owner
actions, item 13, tracks them in the same order. **On 15 November 2026:** steps 2 to 8 are done.
The pull request is merged (#74), release 1.3.0 deployed the move, and the owner reported Auth's
Site URL moved and the `APP_URL` repository variable deleted the same day. Release 1.3.1 (15:50
UTC that day) carried Search Console's file, and steps 1, 11 and the move of the app's e-mail to
the domain (step 13) were done the same day, with the homepage and the company's website of
step 10. Left: the checks by hand (step 9, and the e-mails with `dmarc=pass` of step 13), the
company's other records (step 10) and the callback's release (step 12).

**`APP_URL` was moved early (the owner, 14 November 2026)**, a day ahead of this order, in the
Edge Function secret and in the GitHub repository variable, and by the owner's decision of that
day it was not set back, because nobody used the app yet. From then until the release, invitation
e-mails linked to `https://app.mmakaan.app` while that address still served the web app from
before the move, whose own e-mail links named the old address, so a sign-up started there could
not finish its link. The release ended that, and the variable is deleted (step 8). When the
addresses move again, keep to the order: the secret after the web deploy, and no repository
variable at all (Moving again).

1. **Search Console, old property. Done on 15 November 2026.** A URL-prefix property for
   `https://maalik-e-makaan-site.vercel.app/`, verified by the HTML file method: the owner sent
   `google17fd3f30f3354533.html`, `website/public/` holds it byte for byte (#80), and release
   1.3.1 deployed it. At 16:03 UTC the agent read
   `https://mmakaan.app/google17fd3f30f3354533.html` and
   `https://maalik-e-makaan-site.vercel.app/google17fd3f30f3354533.html` through the Vercel
   connector: each answered 200 with the file's one line (53 bytes), the old address without a
   redirect (the redirect leaves that one path out). The owner then reported the property
   verified (screenshots, that day). Without the old address's property, Search Console's change
   of address cannot be used (step 11). A URL-prefix property for `https://mmakaan.app/` exists
   too (the owner, the same day). Another verification file goes in `website/public/` and in the
   unit test in `website/tests/unit/vercel.test.ts` that lists the files there.
2. **Dynadot DNS. Done on 13 November 2026:** the records are in, and Vercel reports `mmakaan.app`
   (`A` `216.198.79.1` and `64.29.17.1`), `www.mmakaan.app` and `app.mmakaan.app` (`CNAME` records)
   as correctly configured. What it took: the parking records removed (an `A` record to Dynadot's
   parking address on the apex, `www`, `app` or a wildcard, any `AAAA`, any URL forwarding); `A`
   records for the apex, and `CNAME` records for `www` and `app` to the targets Vercel shows for
   each (Settings, Domains; `cname.vercel-dns.com.` also works); no `CAA` record, or one that allows
   `letsencrypt.org`.
3. **HTTPS on the new addresses. Done on 14 November 2026:** the owner checked the new addresses
   over HTTPS in a browser. To check again: `curl -sI https://mmakaan.app/` answers 200,
   `https://www.mmakaan.app/x?y=1` answers 308 to `https://mmakaan.app/x?y=1`, and
   `https://app.mmakaan.app/.well-known/assetlinks.json` answers 200 with JSON; the Release and
   Deploy workflows check the same before they build or deploy. **The uptime monitors. Done on
   15 November 2026** (the agent, at the owner's word, through the Checkly connector): the web
   app's monitor, which requested the old address, now requests `https://app.mmakaan.app/`, and a
   new one requests `https://mmakaan.app/`; each expects 200, checks the certificate on its own
   host, runs every 5 minutes from one location and passed its first runs (Monitoring and
   alerts). No monitor requests the old address any more.
4. **Supabase Auth. Done on 14 November 2026:** the redirect URLs (Authentication, URL
   Configuration) list all four callbacks, `https://app.mmakaan.app/auth/callback`,
   `io.github.ar27111994.maalikemakaan://app.mmakaan.app/auth/callback`,
   `https://maalik-e-makaan.vercel.app/auth/callback` and
   `io.github.ar27111994.maalikemakaan://maalik-e-makaan.vercel.app/auth/callback`, and the Site
   URL was left as it was. The earlier https one may have worked unlisted before, only because
   Auth allows any address on the Site URL's scheme, host and port; step 8 moves the Site URL, and
   builds from before the move then need it listed. Release's `preflight` job, before the builds,
   and Deploy's `supabase` job, before the backend, read these settings with the Management API
   and stop while one is missing (only a warning if the token may not read them; the builds and
   the deploy then go ahead, so check by hand).
5. **Edge Function secret `ALLOWED_ORIGINS`. Done on 14 November 2026:** it holds both app
   origins, `https://app.mmakaan.app,https://maalik-e-makaan.vercel.app` (no redeploy needed).
   Deploy's `web` job checks it before it builds.
6. **Merge the pull request. Done on 15 November 2026** (#74, commit 8cd3c15). From the merge,
   the README and `llms.txt` on `main` name `https://app.mmakaan.app`, and nothing changes in
   production until the release: a site refresh of the last tag builds that tag's own addresses.
   So merge and release in one sitting.
7. **Release. Done on 15 November 2026:** release 1.3.0 (the Release run 43720578854). The
   `preflight` job's token could read Auth's settings, and all four callbacks were allowed. Every
   smoke test passed, the old addresses' included: the old web app address answers 200 with the
   page that clears its storage and goes to `https://app.mmakaan.app`, its `/auth/callback` and
   `assetlinks.json` are kept as they were, and `www` and the site's old address answer 308. No
   run waited for an approval, because the `production` environment has no required reviewer.
   How such a release goes: merge the release pull request. Before it builds
   anything, Release checks that the web app's origin answers and, if the token may read Auth's
   settings, that Auth allows the builds' callbacks (step 4). If the `preflight` or `supabase` job
   warns that the token may not (HTTP 401 or 403), Auth was not checked: the builds and the backend
   go ahead, and a green run does not show that Auth allows the callbacks. Then compare
   Authentication, URL Configuration with step 4's four callbacks by hand. The backend and the web
   app go first, beside the builds: the `supabase` job checks Auth's redirect URLs (step 4), the
   `web` job that the origin answers and that the Edge Functions accept it (step 5); then the web
   app's `APP_URL` becomes `https://app.mmakaan.app`, and the old address starts answering with the
   page that clears its storage and sends people on. The website follows once the builds are
   attached and the web app's deploy has succeeded, and checks first that its new addresses answer
   and that the old web app address sends people on. Check every smoke test, the ones of the old
   addresses included; if one fails on a path, the query or the header, roll forward with a fix
   rather than back (Rollback and restore).
8. **Right after the web deploy. Done on 15 November 2026, as the owner reported** (the agent's
   session can read neither setting): Auth's Site URL is `https://app.mmakaan.app`, and the
   `APP_URL` repository variable is deleted (Settings, Secrets and variables, Actions,
   Variables). Nothing from release 1.3.0 on reads the variable, and without it a Deploy run by
   hand on a tag from before the move stops at "Deployment is configured" instead of deploying
   that tag's web app and website (Rollback and restore). The Edge Function secret
   `APP_URL=https://app.mmakaan.app` was set ahead of this step, on 14 November 2026 (above), and
   stays. What that costs: Android builds from before the move open invitations in the browser
   until the new APK is installed.
9. **Check by hand:** on `app.mmakaan.app`, sign up, reset a password and invite someone; open
   `https://maalik-e-makaan.vercel.app/invite#token=x` in a desktop browser and land on
   `https://app.mmakaan.app/invite#token=x`; in a browser that was signed in on the old address,
   open the old address, land on the new one signed out, and find the old address's local storage
   empty (developer tools, Application, Local storage); on a phone with the new APK,
   `adb shell pm get-app-links io.github.ar27111994.maalik_e_makaan` shows both hosts verified; the
   Digital Asset Links API says `"linked": true` for both (Android App Links, below). **On 15
   November 2026:** Search Console's file answered 200 on both site addresses after release
   1.3.1, and the property was verified (step 1); the agent read a sign-up confirmation whose
   link returns to `https://app.mmakaan.app/auth/callback`, which passed SPF and DKIM but showed
   no DMARC result ([E-mail](#e-mail), step 8). Still the owner's: an e-mail that shows DMARC
   "PASS", and the password reset and the invitation, with SPF, DKIM and DMARC "PASS" in Gmail;
   the old invitation address with its
   `#token`; the old address's storage found empty; and App Links on a phone with release
   1.3.1's APK.
10. **Housekeeping.** Done on 15 November 2026: no uptime monitor requests the old web app
    address (step 3), and the `roadmap` label's description names the new address (the Roadmap
    workflow rewrote it from `.github/roadmap.toml` when the move reached `main`). The
    repository's homepage reads `https://mmakaan.app` (the owner set it, 15 November 2026; the
    agent's session may not change repository settings). **The company's website stays
    `https://ar27111994.dev/`** (the owner's decision of 15 November 2026), so `company.url` in
    `website/src/config/site.ts`, which the site's structured data and `llms.txt` give, does not
    change; the product's own domain carries the company's name, since the footer of every page
    reads "© 2026 AR LABS (SMC-PRIVATE) LIMITED" (the agent read it on the live terms page at
    16:19 UTC that day). The AWS Activate application: the three changes its provider asked for
    on 12 November 2026 (the website and the web app on the company's own domain, an e-mail
    address on it, the company's name on the website) are met, and a reply with the pitch deck at
    1.3.1 was drafted for the owner on 15 November 2026. Still the owner's: sending that reply,
    and the website on LinkedIn and on the D-U-N-S record.
11. **Search Console. Done on 15 November 2026, as the owner reported** (screenshots): a Domain
    property for `mmakaan.app` (a TXT record at Dynadot); the sitemap
    `https://mmakaan.app/sitemap-index.xml` submitted and read the same day, status Success, 42
    pages (the 44 built pages less the two not-found pages, which are kept out of the sitemap);
    and, with the old property verified (step 1), Settings, Change of address, to
    `https://mmakaan.app/`, started that day. Still optional: Bing Webmaster Tools, which can
    import the properties and has a site move of its own. On a later move, if Search Console
    rejects the 308, `website/vercel.json`'s rule can say `"statusCode": 301` instead. The web
    app answers `X-Robots-Tag: noindex` on every path, so the Domain property lists it as
    excluded, not as an error: the website is what search engines index (D-01).
12. **A release at least 24 hours after the move's** (so not before 14:00 UTC on 16 November
    2026; an earlier release simply goes without this change, as 1.3.1 did): the agent's pull
    request answers the old address's `/auth/callback` with the page too, so it clears that
    address's storage and sends people on like every other path (only `assetlinks.json` stays);
    after its deploy, the owner sets `ALLOWED_ORIGINS` to `https://app.mmakaan.app` (or removes
    it, which means `APP_URL`'s origin).
13. **The mail. Done on 15 November 2026, except the e-mail checks (DMARC "PASS", the reset and the
    invitation).** The mailbox's DNS records, as Dynadot sets them (MX, SPF, DKIM, and its own
    `_dmarc` record, `p=none`); leave the mailbox's own SPF record as Dynadot wrote it, and add no
    second DMARC record ([E-mail](#e-mail), step 1): the owner's own, added on 13 November 2026,
    stood beside Dynadot's, so that neither applied, and the owner removed it on 15 November 2026; a
    lookup afterwards showed Dynadot's own record alone. The Edge Function secret
    `MAIL_REPLY_TO=hello@mmakaan.app` (the owner), so that a reply to an invitation reaches the
    company. By the owner's decision of the same day the app's e-mails come from `hello@mmakaan.app`
    too, and Resend moved from `news.ar27111994.dev` to `mmakaan.app` ([E-mail](#e-mail) has the
    reasons and each setting).
    What the owner did, as reported that day:
    1. In Resend, `mmakaan.app` added at 15:06 UTC, in the region ap-northeast-1 (Tokyo).
    2. At Dynadot, the records Resend listed, as subdomain records: a DKIM TXT on
       `resend._domainkey`, and `CNAME` records `send` to `send.forge.rmta.net` and `rsend` to
       `rsend-apne1.forge.rmta.net`; the apex's records left alone, and Resend's "Enable
       receiving" off, so the mailbox at Dynadot keeps receiving.
    3. "Verified" at 15:21 UTC; click and open tracking off.
    4. Two sending keys limited to the domain: one is Auth's SMTP password, the other the secret
       `RESEND_API_KEY`.
    5. Auth's SMTP sender is `hello@mmakaan.app`, and
       `MAIL_FROM="Maalik-e-Makaan <hello@mmakaan.app>"`.
    6. Step 9's e-mails: the agent read a sign-up confirmation (15:44 UTC) that passed SPF and
       DKIM for `mmakaan.app`, with no tracking, but showed no DMARC result, from before the
       second record was removed ([E-mail](#e-mail), step 8). **Still open, the owner's:** an
       e-mail that shows DMARC "PASS", and the reset and invitation e-mails, with SPF, DKIM and
       DMARC "PASS" in Gmail.

    `MAIL_FROM` was set to the address at 14:13 UTC that day, before the domain was verified, so
    until 15:21 UTC Resend refused the invitations, and Auth's e-mails too if its sender was the
    same. Customer.io gets a subdomain of its own, in its own pull request (D-18).
    Every host on `mmakaan.app` is reached
    over HTTPS only: the whole `.app` domain is on the browsers' HSTS preload list, and the site
    sends HSTS with `includeSubDomains`. So a subdomain people open in a browser (a link-tracking
    domain, a custom webmail address) needs its certificate, through the provider's managed TLS,
    before its `CNAME` is added; one that carries only mail records (MX, SPF, DKIM, DMARC, or
    Resend's `send` and `rsend`) needs none.

Auth keeps the earlier redirect URLs, and the Android manifest the earlier host, until the builds
from before the move are out of use: a date or a lowest version for that is the owner's to set.

### Moving again

Put the new origin in `contracts/origins.json` and the current one under `legacy` (a `www`-style
host that the hosting redirects goes under `aliases`), in one pull request that also updates
`website/vercel.json`'s redirect, the Android manifest's hosts and the docs; `npm test`,
`make lint` and `make docs-check` say what is missing. The page the web app's earlier addresses
answer with takes the origin from the file, and each address in `legacy` gets it. Then follow the
order above: DNS and HTTPS, Auth's redirect URLs and `ALLOWED_ORIGINS` first, then merge and
release, then Auth's Site URL and `APP_URL` (the secret, and no repository variable). Release
builds nothing until the new origin answers and Auth allows its callbacks; Deploy deploys the
backend only once Auth does, and the web app only once all three first steps hold. A token that
may not read Auth's settings turns the Auth check into a warning (Checked before anything is
deployed, above).

## Deployment (GitHub Actions)

The Deploy workflow (`.github/workflows/deploy.yml`) runs when the Release workflow has released a
tag (Release calls it for that tag), or by hand (Actions, Deploy, Run workflow, for the branch or
tag chosen there; only once the workflow is on the default branch). Publishing a release by hand
does not start it. A run by hand runs the `deploy.yml` of the branch or tag chosen, not
`main`'s. See [Releasing](#releasing). Release and Site refresh call it as
`uses: $/.github/workflows/deploy.yml`, GitHub's self-repository syntax and its recommended form.
The called workflow is the one in the caller's commit, as it was with the earlier `./` form
(`docs/agents/conventions.md`, Workflows and actions). Its `supabase` job first runs
`tool/web/check_auth_urls.py`
(as the Release workflow's `preflight` job does before the builds), which reads Auth's Site URL
and redirect URLs with the Management API: the e-mail links of the
release's builds (the web app's `/auth/callback` and its iOS form) must be allowed, and so must
those of builds from before a move while the Site URL is still on their host ([Domains](#domains),
step 4). It stops before deploying anything otherwise; a token that may not read Auth's settings
only warns. It then pushes migrations and Edge Functions to Supabase and calls the `health`
function. Its `web` job then:

1. fails at once if the `VERCEL_TOKEN` secret or a repository variable is missing;
2. reads the web app's origin and earlier addresses from the ref's `contracts/origins.json`
   ([Domains](#domains)), and fails on a ref that predates the file (only a caller that passes
   an older ref meets this; a run by hand on an older tag runs that tag's own workflow, see
   Rollback and restore);
3. checks that the origin answers over HTTPS with its App Links file
   (`tool/web/check_live.py app`), and stops before building if it does not: the deploy makes
   each earlier address send people on to it;
4. checks that the Edge Functions accept the origin: a CORS preflight to `health` must answer
   204, or the deploy stops before building (an earlier address only warns);
5. writes `app/config/production.json` from the repository variables and that origin
   (`APP_URL`), as the Release workflow does, and runs
   `flutter build web --release --no-web-resources-cdn`;
6. packages the build with `tool/web/package_vercel.py`, which adds the page the earlier
   addresses answer with, its script and their routes (see Hosting);
7. runs `vercel deploy --prebuilt --prod` with the CLI pinned to an exact version, for the
   project's team and project ids;
8. runs `tool/web/smoke_test.sh` on the origin. It first waits up to two minutes for `/` to
   answer 200, since just after `vercel deploy --prod` the production address can still answer
   from the previous deployment ("waiting for the deployment" in the log). Then, on `/`,
   `/auth/callback?code=…` and an `/invite/…` path, it checks for a 200 with the app's
   `index.html`, the CSP (it must allow `SUPABASE_URL`), HSTS, `nosniff`, `X-Robots-Tag: noindex`
   and a revalidated `Cache-Control`. It also checks that `/.well-known/assetlinks.json` answers
   200 as JSON, delegating to the Android package, and that none of these carries
   `Clear-Site-Data`: the origin's storage is the app's own. Then
   `tool/web/redirect_smoke_test.sh --page` on each earlier address. It waits the same way, for
   `/` to answer with the header. Then `/` and a deep path with a query must answer 200 with the
   page that names the origin as its destination, its script and its way on without scripts, with
   `Clear-Site-Data: "storage"` and nothing more, revalidated; `/moved.js` must be served as
   JavaScript; and `/.well-known/assetlinks.json` and `/auth/callback?code=…` must still answer 200
   as before, without the header.

Its `site` job deploys the website. It does not wait for Supabase (the site never calls it), so it
runs alongside the other two when the workflow runs by hand. The Release workflow instead calls
Deploy twice: once with `skip-site` straight after tagging, for the backend and the web app, and
once with `site-only` after its `artefacts` and `ios` jobs have finished and the first call has
succeeded, so that the download page links to the files they attached and to a web app deployed
for the release. If a build fails, the website still goes out, without that build's links (or
with links to the part of its files that an upload cut off part-way left on the release);
re-running the failed job (Re-run failed jobs) runs the website's deploy again after it, which
adds them. If the backend's or the web app's deploy fails, the website waits for it the same way.
The `site` job:

1. fails at once if the `VERCEL_TOKEN` secret is missing;
2. checks, before building, that the site's origin answers over HTTPS, that each alias (`www`)
   redirects to it, and that the web app it links to answers at its origin and is the deployment
   built for it: each earlier address of the web app must answer `/` with the page that names the
   origin as its destination, or with 308 to the origin (`tool/web/check_live.py site`,
   [Domains](#domains)). It stops otherwise; a ref from before `contracts/origins.json` skips this;
3. renders the pitch deck (`npm run deck`, with Playwright's Chromium) and fetches the live
   roadmap (`tool/github/fetch_roadmap.py --from-github`); a tag from before either tool skips
   that step with a warning (see Hosting, The website on Vercel);
4. writes the names of the files attached to the manifest's release, read from GitHub, to
   `website/src/data/release-assets.json`, so the download page links to those alone: a run
   while a release is still building, or after one of its builds failed, publishes fewer links
   rather than dead ones. It fails, before anything is deployed, only if GitHub cannot be read
   or the release is not published yet; run it again later;
5. writes `.vercel/project.json` and runs `vercel build --prod`, which takes both origins from
   the ref (see Hosting, The website on Vercel) and fails on a page without its twin in the
   other language or with inline code; it then reads the origin back from the built sitemap and
   checks it against the ref's `contracts/origins.json`;
6. checks, as a safety net, that every release file the built pages link to
   (`/releases/download/…`) is attached to its GitHub release, and stops before deploying if one
   is not, leaving the live site as it was;
7. runs `vercel deploy --prebuilt --prod` with the same pinned CLI;
8. runs `tool/web/site_smoke_test.sh` on that origin, which first waits the same way for `/` to
   answer 200. Then `/`, `/ur/`, `/robots.txt`, `/sitemap-index.xml` and `/llms.txt` must answer
   200 with the right type, the canonical links, `robots.txt` and the sitemap must name the
   origin, a missing page must answer 404, and every response must carry the
   Content-Security-Policy, HSTS, `nosniff`, `X-Frame-Options`, `Referrer-Policy`,
   `Permissions-Policy` and `Cross-Origin-Opener-Policy`. Then `tool/web/redirect_smoke_test.sh`
   on each earlier address and alias (`www`): `/` and a deep path with a query must answer 308
   to the same path and query on the origin. A ref from before `contracts/origins.json` skips
   that part.

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
| `BACKUP_AGE_RECIPIENTS`     | variable | The public keys the weekly backup is encrypted to, one per line (Backups) |

The `production` environment, which Deploy's three jobs run in, should require a reviewer. The
Release workflow's `preflight`, `artefacts` and `ios` jobs run in the `release` environment, which
may hold the `ANDROID_*` secrets in place of the repository; a deployment branch rule on it must
allow `main`, the branch every release runs for, and never tags alone
([`docs/release-readiness.md`](release-readiness.md), Optional hardening). The web app's `APP_URL`
is no repository variable: every build takes it from the tag's `contracts/origins.json`
([Domains](#domains)). The `APP_URL` variable that releases before D-20 read still exists, and holds
`https://app.mmakaan.app` since 14 November 2026. Delete it right after the web deploy of the
release that carries D-20 ([Domains](#domains), step 8): a Deploy run by hand on an older tag then
stops before it deploys that tag's web app or website. Until then such a run would deploy them built
for the new web app address, without what the move needs (Rollback and restore), so do not start
one.

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
other platforms. The address must be among Auth's redirect URLs (E-mail, above): today
`io.github.ar27111994.maalikemakaan://app.mmakaan.app/auth/callback`, with the one for the earlier
host, `io.github.ar27111994.maalikemakaan://maalik-e-makaan.vercel.app/auth/callback`, kept for
builds made before the move. Check it on an iPhone once an iOS build exists: sign up and reset a
password from the app; iOS asks to open the link in Maalik-e-Makaan.

### iOS builds

There is no Apple Developer Program membership yet, so nothing signs the iOS app. CI's
`ios-build` job builds it for iPhone without signing on every push and pull request, which keeps it
compiling, and keeps the result for 14 days as the `ios-unsigned-ipa` artefact. Each release
attaches `maalik-e-makaan-vX.Y.Z-ios-unsigned.ipa`, built with production's configuration, with
its checksum in `SHA256SUMS-ios`, both covered by the provenance file
`maalik-e-makaan-vX.Y.Z-ios.intoto.jsonl` (Releasing, Release provenance).

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

`app/web/.well-known/assetlinks.json` lets Android open the web app's `/auth/callback` and `/invite`
links in the app (the `autoVerify` intent filter in `app/android/app/src/main/AndroidManifest.xml`).
The filter names both hosts of the web app, `app.mmakaan.app` and the earlier
`maalik-e-makaan.vercel.app`, which keeps serving the file for links already sent
([Domains](#domains)); `tool/android/check_manifest.py` (`make lint`, and CI on the merged release
manifest) fails unless its hosts are exactly the web app's in `contracts/origins.json`, and each
host opens both paths through a filter Android can launch: `VIEW`, `DEFAULT` and `BROWSABLE`, no
`android:port` (a link without a port matches no filter that names one; any port refuses the
filter, which is stricter than Android on purpose), no `android:mimeType` (a link carries no MIME
type, so Android never matches it to a filter that names one) and no `android:mimeGroup` (filled at
run time, so this is stricter than Android on purpose), no `android:featureFlag` on the filter,
anything in it or its component (Android drops such an element where the flag is off), nothing
nested inside its `<action>`, `<category>` or `<data>` (Android 11 and later read such an element
as the filter's own, Android 10 and earlier skip it, so the check refuses it on every filter), on an
`<activity>` or `<activity-alias>` that a link reaches: not `exported="false"` or `enabled="false"` (in any case aapt2 accepts, such as
`FALSE`), in an application that is not disabled, and with no permission a browser would need.
Android reads an alias's `enabled`, `exported` and `android:permission` from the alias alone, never
from its target activity, so a disabled or protected target does not matter; an activity that
writes no `android:permission` takes the application's, and an alias never does. Any value but an
empty one counts, spaces included, as Android reads it. An `exported` or `enabled` the check cannot
read, a resource such as `@bool/…` above all, is refused with a request to write the literal. A
verified filter on any other component (a service, say) is reported, as it opens no link. It works
out each filter on its own, as Android matches a link: one filter's host never combines with
another filter's path.
Android 12 and later verify each host on its own; Android 6 to 11 verify every web host of every
filter (with `VIEW` and an `http` or `https` scheme, `autoVerify` or not) and grant all or none, so
the check also fails on another host in any such filter, and both hosts must serve the file (and
Release builds nothing until the new host does, Domains). The file lists the SHA-256 fingerprint of
each certificate that signs the app the user installs. Today that is only the upload key, which
signs the APKs attached to releases.

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

Verify after a deployment. Google's Digital Asset Links API should answer `"linked": true` for
each host:

```bash
for site in https://app.mmakaan.app https://maalik-e-makaan.vercel.app; do
  curl -sS "https://digitalassetlinks.googleapis.com/v1/assetlinks:check?source.web.site=$site&relation=delegate_permission/common.handle_all_urls&target.android_app.package_name=io.github.ar27111994.maalik_e_makaan&target.android_app.certificate.sha256_fingerprint=96:C8:54:35:77:E8:20:5A:10:E6:01:5A:D0:8F:86:B2:CE:CE:D1:7A:8D:32:AB:B8:43:DF:2A:40:77:54:23:F8"
done
```

On a device or emulator with the release-signed app installed (Android 12 or later):

```bash
adb shell pm verify-app-links --re-verify io.github.ar27111994.maalik_e_makaan
adb shell pm get-app-links io.github.ar27111994.maalik_e_makaan   # both hosts: verified
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE \
  -d 'https://app.mmakaan.app/auth/callback?code=test'   # opens the app, not the browser
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
   checks that the web app's origin answers and that Auth allows the builds' callbacks
   (`preflight`; nothing is built or attached otherwise, except that a token which may not read
   Auth's settings only warns: Domains), builds the signed Android app and the web app and
   attaches them (`artefacts`), builds and attaches the unsigned iOS app (`ios`), each build with
   its provenance file beside it (Release provenance, below), and calls the Deploy workflow for
   the tag twice: at once for the
   backend and the web app (`deploy`), and for the website once `artefacts` and `ios` have
   finished and `deploy` has succeeded (`site`), since its download page links to the files they
   attached and to the web app. Each deployment waits for a reviewer when the `production`
   environment requires one. **Who merges it, and when (the owner, 15 November 2026):** the
   agent merges the release pull request without asking each time, once everything meant for
   the release is merged and every check on it is green. That standing word covers releases
   only: any other change outside the repository is still the owner's to approve.
4. Watch both Deploy calls: each job ends with its smoke test, and the `supabase` job with a call
   to `health`. If `artefacts` or `ios` failed, the website still describes the new release, but
   its download page has no links to that build's files, other than any an upload that was cut
   off part-way left on the release; re-run the failed job (Re-run failed
   jobs), which deploys the website again afterwards. A build that keeps failing (the optional
   iOS one after a macOS runner change, say) leaves those links out until a release has them,
   and holds up nothing else. A build whose attest step or "Provenance file, checked against
   every file it covers" step failed has attached nothing in that attempt, but files an earlier
   attempt's upload left on the release when it stopped part-way stay there (Release provenance,
   Re-runs): look at the release's files (`gh release view vX.Y.Z --json assets`, or the release
   page) before taking it to have none. If the log points at Sigstore or GitHub's attestation
   API, check githubstatus.com (Actions, API) and status.sigstore.dev, wait, then re-run the
   failed job. Then run the daily query of Monitoring and alerts.
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

### Release provenance

Both build jobs attest every file in `dist/` with `actions/attest-build-provenance`, so GitHub
keeps a signed build provenance attestation for each (a Sigstore bundle holding an in-toto
statement with SLSA provenance v1). The attestation in GitHub's store is not on the release, and
OpenSSF Scorecard's Signed-Releases check reads only the release's file names. So each job then
copies the attestation's bundle into `dist/` and attaches it with the files:

- `artefacts`: `maalik-e-makaan-vX.Y.Z.intoto.jsonl`, covering the app bundle, the three APKs, the
  web zip, the debug symbols and `SHA256SUMS`;
- `ios`: `maalik-e-makaan-vX.Y.Z-ios.intoto.jsonl`, covering the `.ipa` and `SHA256SUMS-ios`
  (before v1.4.0 this job attested the `.ipa` alone).

The file is JSON Lines, one Sigstore bundle on its one line, and `gh attestation verify --bundle`
reads it (`SECURITY.md`, Checking a download, has the commands; `slsa-verifier` does not apply).
It is not in `SHA256SUMS`, which is one of its subjects and written before it; its own signature
protects it. Before the upload, the job checks it against every build file in `dist/` (all but
the provenance file itself, the bundle they are checked against, which the upload then attaches
with them) with `gh attestation verify --bundle`, with the options `SECURITY.md` gives, and logs
`gh --version`. The source ref is `refs/heads/main`, written literally, so a run started by hand
(Run workflow) from another branch fails there and attaches nothing in that run: start Release
by hand from `main` only. That holds exactly with `gh` 2.102.0 or later on the runner: an older
`gh` compares the branch name without regard to case, so look at the version the step logs, and
if it is older, say so in the release's notes and do not rely on the check for a branch whose
name differs from `main` only in case.
`tool/github/check_release_provenance.py` (`make lint`) keeps the attest step, that check and the
one upload together, with no `if:`, `continue-on-error`, `shell:` or `working-directory:` on
them, and no `defaults.run.working-directory` on the job or the workflow (either would move
`dist/` away from the files attested from the workspace root). It requires the check's run to be
exactly its six lines, the upload's to be exactly
`gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"` (so it attaches nothing
outside `dist/` and runs nothing before, after or around it), the upload step's own `env` to set
only `GH_TOKEN` and the check step's only `BUNDLE` and `PROVENANCE`, the job's and the
workflow's `env` to set nothing that changes what bash or gh runs (`BASH_ENV`, `PATH`, `IFS`,
`LD_PRELOAD` or an exported function such as `BASH_FUNC_gh%%` could make every check pass), and
the job's default shell, where set, to be `bash` (which the runner starts
with `-e -o pipefail`; `bash {0}` would drop `-e`, and only the last file's check would count), so
no file is skipped, no failed check is lost and no unattested file is attached. It reads those
two runs as bash does and refuses what it could read otherwise: a comment that ends in a
backslash (bash ends the comment there and runs the next line, which reads as part of it), a `#`
right after an operator, a quoted string over more than one line, a here-document, a command
substitution or parameter expansion, a `${{ }}` expression (Actions replaces it before bash reads
the run), and a carriage return, a no-break or zero-width space or any other character but a
space, a tab and a line feed that Python reads as white space or as nothing. The provenance
file's name starts with a letter or a digit and holds only letters, digits, `.`, `_`, `-` and
plain context properties such as `${{ needs.release-please.outputs.tag }}` (an expression with a
literal or a function in it could put a `#` or a space there): `dist/*`, in the check's loop and in the upload, leaves out a name that
starts with a dot, so a hidden provenance file would never be attached. Nor may it hold two dots
in a row, which GitHub, and gh when it looks for the file `--clobber` replaces, fold into one.
No two jobs may name provenance files that can be the same file on the release, since each
`--clobber` upload would replace the other's. The check compares the names as GitHub reads them
(white space inside `${{ }}` dropped, the expressions' case ignored, and, more widely than
GitHub, the text's too), but it cannot know the expressions' values: another expression with
the same value (`${{ env.TAG }}`, `v${{ needs.release-please.outputs.version }}`) or an empty
one could make two names one. So two names pass only if they hold the same expressions, each
with one value in every job of the run (an output of a job both list in `needs`, `inputs`,
`github.repository`, `github.sha` and the like, but not `vars`, which a job's `environment:` can
set apart), and differ in the text around them
in a way no value can make up, as release.yml's do (`-ios` added after the tag); or if the text
of one before its first expression, or after its last, neither starts nor ends the other's. An
uploading job may not set a `strategy`, since each leg of a matrix would give its provenance
file the same name. In every workflow it refuses other ways of putting files on a release:
`gh release create` (and `gh release new`, its alias in gh), a release-upload action, and the
REST upload by its URL or its client libraries' names; ways of taking them off (`gh release
delete` and `delete-asset`, a `DELETE` on a release URL in any case and glued to its flag, as
gh and curl take `-XDELETE` and `--method delete`, the client libraries' delete calls), which
would leave a release without its provenance file; and a gh alias or extension, which could
upload under another name. It looks for them in every value of every step (so also in an
`actions/github-script` script and an `env` value), and in a run once its quoting is read
(`gh release $'upload'` counts, and so does `gh re$'\0'lease`, since a NUL ends such a string
where it stands), after a word that may run gh (`gh`, `"$GH"`, or any variable or expression,
such as `"$tool"`), so a summary line such as `echo "the release upload finished"` is not taken
for a command. A redirection, which bash takes out before gh sees its words, is skipped wherever
it stands among them (`gh </dev/null release upload`, `gh release > log delete`). Each `${{ }}`
expression is first filled in as Actions could fill it: a string literal as its text
(`gh release ${{ 'upload' }}` counts), any other expression as a word that could be any
subcommand, except as the value of `-R` or `--repo`, which always take one
(`gh release -R ${{ github.repository }} upload` counts, `… view` passes). It finds the
subcommand as gh does, past the flags gh skips first and a value after each
(`gh release -R "$GITHUB_REPOSITORY" upload` and `gh release --repo=x delete` count); in a
script, a flag's value may be a quoted string or be joined with `+` and calls
(`owner + '/' + name`, `String(repo)`, a template literal). Since only gh knows which flags take
a value, a word after a flag counts as the subcommand too. `gh release view`, `list`,
`download` and `edit` attach and delete nothing, and are left alone.

**What the check cannot see.** It reads only the workflow files, as PyYAML parses them, and runs
none of what they run. So these can still put a file on a release, or take one off, unseen:

- a script or program a step runs (`./attach.sh`, `node attach.js`, `python3 tool/x.py`, a
  built binary), which can call `gh` or the REST API itself;
- an action that is not in the check's list of release-upload actions;
- a gh alias or extension already configured on the runner, or read from a configuration
  directory in the repository (`GH_CONFIG_DIR`);
- a reusable workflow that uploads, called twice, whose two runs would give their provenance
  files the same name;
- text built at run time (`$(printf upload)`, a shell variable or function, positional
  parameters such as `set -- upload; gh release "$@"`, `xargs gh release`, a glob such as
  `upl[o]ad`), or a flag's value an action's script computes other than with `+`, a call or a
  template literal (`'-R', a ? b : c, 'upload'`);
- a context property in the provenance file's name whose value GitHub would change (a `/`, a
  `#`, a space, or a dot at either end): the check takes the tag's `vX.Y.Z` to hold none;
- a variable an earlier step writes to `$GITHUB_ENV` (a `GH_REPO` or `TAG` that sends the upload
  elsewhere, a `BASH_ENV` or `BASH_FUNC_*` for every later step).

A reviewer reads these paths by hand in every pull request that changes a workflow, or a script,
program or action a workflow's job runs: what each one sends to GitHub, and what each step writes
to `$GITHUB_ENV`. The check's docstring and the shorter mentions elsewhere point here.

**Re-runs.** "Re-run failed jobs" runs the whole job again on a new runner: a new build, a new
attestation and a new provenance file, under the same names, so `--clobber` replaces every file.
A job that ends green leaves a provenance file and a `SHA256SUMS` that match every file beside
them. If an upload is cut off part-way, the release can hold files from two attempts; the
provenance file and `SHA256SUMS` then do not match the mixed set, and the `--bundle` check and
`sha256sum -c` fail for the files of the other attempt (the online check still passes, since
GitHub keeps both attempts' attestations, and each file was built by the workflow). Re-run until
the job is green, which restores a matching set. A failed attempt's attestations stay in GitHub's
store, for files no longer on the release; that is harmless.

**What Scorecard counts** (v5.6.0, `checks/evaluation/signed_releases.go` and its probes). Only
file names: a release with a name ending in `.intoto.jsonl` scores 10; one with only a signature
(`.asc`, `.minisig`, `.sig`, `.sign`, `.sigstore`, `.sigstore.json`) 8; one with neither 0. It
looks at the five newest of the 30 most recent releases, leaves out any of those five that has no
files, and takes the floor of the mean. Nothing is downloaded or verified. With seven releases
(v1.0.0 to v1.3.1) and none carrying a provenance file, v1.4.0 scores 2, the release after it
4, and the fifth such release 10. Scorecard's `main` also scores an immutable release 10; v5.6.0
does not.

**Past releases (optional, the owner's own step).** v1.0.0 to v1.3.1 carry no provenance file,
but GitHub still holds their builds' attestations, so the online check already works for their
files (except `SHA256SUMS-ios`, which those runs did not attest). Attaching the files to them
would only raise the Scorecard score at once instead of release by release, and let their files
be checked offline. It is not part of releasing and nothing runs it; if the owner chooses to,
with their own `gh` login and in a new, empty folder, for each tag: set the tag on the third
line, then paste the whole block into the terminal (bash, or zsh, macOS's default shell). The
block downloads the release's files and the attestation of the Android and web build, checks it
against every file of that build, does the same for the iOS build, and only then attaches the two
provenance files, without `--clobber`, so nothing on the release is replaced. It has no comment
lines, since zsh, unless `setopt interactivecomments` is on, reads a pasted `#` line as a
command.

```sh
(
  set -euo pipefail
  repo=ar27111994/maalik-e-makaan tag=v1.3.0
  gh release download "$tag" --repo "$repo"
  gh attestation download SHA256SUMS --repo "$repo"
  mv -- sha256:*.jsonl "maalik-e-makaan-$tag.intoto.jsonl"
  for f in SHA256SUMS *.aab *.apk *-web.zip *-debug-symbols.zip; do
    gh attestation verify "$f" --bundle "maalik-e-makaan-$tag.intoto.jsonl" --repo "$repo" \
      --signer-workflow "$repo/.github/workflows/release.yml" --source-ref refs/heads/main
  done
  gh attestation download "maalik-e-makaan-$tag-ios-unsigned.ipa" --repo "$repo"
  mv -- sha256:*.jsonl "maalik-e-makaan-$tag-ios.intoto.jsonl"
  gh attestation verify "maalik-e-makaan-$tag-ios-unsigned.ipa" \
    --bundle "maalik-e-makaan-$tag-ios.intoto.jsonl" --repo "$repo" \
    --signer-workflow "$repo/.github/workflows/release.yml" --source-ref refs/heads/main
  gh release upload "$tag" maalik-e-makaan-"$tag"*.intoto.jsonl --repo "$repo"
  echo "Attached the two provenance files to $tag."
)
```

The parentheses keep the block apart from the terminal, and `set -euo pipefail` stops it at the
first command that fails. A stop means an error message is the last thing shown instead of
"Attached the two provenance files", nothing after the failed command has run (so a failed
download, rename or check attaches nothing), and the terminal stays open. A rename fails when the
download before it gave no `sha256:` file, or more than one (in a folder that was not empty).
`gh attestation download` writes the bundles for a file's digest to `sha256:<digest>.jsonl`; a
job re-run on the same files would give two lines, both valid. If the block stops, leave that
release as it is. Do it once v1.4.0's own provenance files have checked out.

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

## Code scanning and branch rules

The Security workflow (`security.yml`) uploads CodeQL, OSV-Scanner and zizmor results to code
scanning. Its "Workflow security (zizmor)" job runs the zizmor version that
`tool/requirements-lint.txt` installs for `make lint`, with its online audits, and fails on any
finding that no inline ignore suppresses, after the upload; `make lint` runs the same version
offline, which leaves out the four audits that need the GitHub API (`impostor-commit`,
`known-vulnerable-actions`, `ref-confusion` and `stale-action-refs`). A finding of one of those
four, such as a new advisory against a pinned action, can therefore turn the job red on every open
pull request with no change in any of them: bump the action, or add an inline ignore with its
reason, agreed in review (`docs/agents/conventions.md`, Workflows and actions). Until 15 November
2026 the job ran the newest zizmor and never failed on a finding, so the `self-repository` audit
added in zizmor 1.30.0 left three notes on `main` (the calls of `deploy.yml`, now written with `$/`)
without failing a pull request.

**After the change to `$/` merges.** `$/` first runs on GitHub after the merge, and two runs show
whether GitHub accepts it:

- The Release run on the merge commit. `release.yml` runs on every push to `main`, and GitHub
  validates the workflow file, called workflows included, when it creates the run, so a refused
  `$/` is expected to show here even when the deploy jobs are skipped. The run
  starts with no "Invalid workflow file" banner; release-please runs, and "Deploy the release"
  and "Deploy the website" are skipped, or run if a release was created. On a release, both
  deploy jobs expand into `deploy.yml`'s jobs at the release commit.
- The Security run on `main`, where the three `self-repository` alerts move to Fixed.

Site refresh, the third call, first runs on its schedule (Wednesdays at 04:23 UTC, the first on
18 November 2026) unless run by hand. If GitHub refuses `$/`, revert with a pull request that
reverts the whole squash commit, which also restores the zizmor job that does not fail on a
finding. A pull request that puts back only the three `./` lines is refused by its own gates:
the same-repository call check fails "Repository hygiene" and zizmor fails "Workflow security
(zizmor)", both required checks. The other way past those gates is the admin bypass, which is
the owner's decision.

**As read from GitHub on 15 November 2026** (a record of that day; the settings live on GitHub and
may have changed since):

- **The ruleset on `main`.** Pull requests are required, with 1 approving review; stale reviews
  are dismissed, the last push must be approved by someone else, and review threads must be
  resolved. Commits must be signed; force pushes and deletion are blocked. 18 status checks are
  required, among them "Workflow security (zizmor)", "Repository hygiene" and "CI passed"; the
  branch need not be up to date with `main` before merging (strict checks are off). A code
  scanning rule covers CodeQL only (errors, and security alerts of high or above), a code-quality
  rule stops errors, and Copilot is asked to review each push. The repository admin role may
  bypass the ruleset at any time.
- **OpenSSF Scorecard** v5.6.0 on `d24acdc` (the run of 14 November 2026 at 22:33 UTC, from the
  Scorecard job's log): 7.8 overall.
  Maintained 0: the repository was created on 3 November 2026, and Scorecard scores any
  repository younger than 90 days 0, so it clears itself from 1 February 2027 as long as there is
  a commit each week. Code-Review 9: 28 of 29 recent changesets had an approving review; the one
  without is pull request #64, and the score reaches 10 once it leaves that window.
  Branch-Protection 5, with four warnings: the rules do not apply to administrators (the
  bypass), 1 required approval where Scorecard wants 2, code-owner review is not required, and
  "up-to-date branches" is off. Signed-Releases 0: release files carried no signature or
  provenance file (the provenance that `release.yml` attested was kept by GitHub, not attached
  to the release); from v1.4.0 on each build attaches it as a `.intoto.jsonl`
  file, and the score rises by 2 with each release, to 10 at the fifth (Releasing, Release
  provenance). Contributors 3 (one organisation), CII-Best-Practices 5 (the passing badge), and
  Packaging not detected. Every other check scored 10.

**Who can change what.**

- In the repository: Signed-Releases. `release.yml` attaches each build's provenance file from
  v1.4.0 on, so the score rises with each release. Attaching provenance files to the five
  newest releases before it would reach 10 at once; that is the owner's optional step (Releasing, Release
  provenance).
- With time and steady reviewed work: Maintained and Code-Review.
- The owner's settings: the admin bypass and "up-to-date branches". Removing the bypass and
  turning on "up-to-date branches" are open decisions; neither has been made.
- A second person: two required approvals and code-owner review need someone besides the owner
  who can review, and Contributors needs people from other organisations.
- Packaging looks for a workflow that publishes a package to a registry, which this project does
  not have.

## Rollback and restore

Migrations are forward only: a mistake is fixed by a new migration, never by editing or reverting
an applied one (CONTRIBUTING.md). What can be rolled back, and how:

| What                   | Roll back by                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The web app            | Vercel dashboard, project `maalik-e-makaan`, Deployments: the previous production deployment, Promote to Production (or `vercel rollback <deployment-url> --scope ar27111994s-projects`). Takes effect at once; the database must still suit the older app (migrations add, they do not remove). Never to a deployment from before D-20: it has the old `APP_URL` and nothing that sends people on, and would serve that build on both hosts, so links requested on the new address would go to the old one. Roll forward instead.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| The website            | The same, project `maalik-e-makaan-site`, and never to a deployment from before D-20 either: its canonical and hreflang links, sitemap and `robots.txt` name the old address and it has no redirect, which undoes the change of address in Search Console. Roll forward instead.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Edge Functions         | Check out the previous tag and deploy its functions with the CLI: `supabase functions deploy --project-ref <project-ref> --use-api` (with `SUPABASE_ACCESS_TOKEN` set; `verify_jwt` comes from that tag's `supabase/config.toml`). Not with Deploy by hand on a tag: that runs the tag's own `deploy.yml`, which also redeploys its web app and website. A tag from before D-20 reads the web app's address from the `APP_URL` repository variable, which holds the new address since 14 November 2026. Such a run would put that tag's web app on both hosts, built for `app.mmakaan.app` but with nothing on the old host that sends people on or clears its storage, so a link requested on the old host would open on the new one, where its verifier is missing; and that tag's website on every site host, with the old address in its canonical links and no redirect. Once the variable is deleted ([Domains](#domains), step 8), those two jobs of such a tag stop at "Deployment is configured". |
| A migration            | A new migration that undoes it (forward fix), through the usual process (After every migration). If it destroyed data, restore that data from a backup (below) into a scratch project and copy the rows back.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Data lost or corrupted | Restore from a backup (below).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

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
message quotes the row, so it is kept off the public log. The job's first step reserves the stack's
host ports (54320 to 54329) so that no outgoing connection is given one before the stack binds
it (docs/agents/conventions.md, Workflows and actions); if the runner refuses that, the check
is skipped and the run fails at its end the same way. The hosted project lets `postgres` set `session_replication_role = replica` (checked on 2026-11-09), so step 3 of
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
