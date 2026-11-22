---
active_phase: "12"
next_action: execute-phase
next_phases: ["10", "11", "12"]
progress: { total_phases: 12, completed_phases: 9, percent: 75 }
---

# Project State: Maalik-e-Makaan

## Current Position (2026-11-22)

- Release 1.4.2 was published on 22 November 2026 at 05:46 UTC (tag `v1.4.2`, commit 9807197 on
  `main`; the Release run 44990804084, two attempts, 05:45 to 06:07 UTC). The agent merged the
  release pull request (#99) at 05:45 UTC on the owner's standing word, 13 minutes after #70.
  For users it carries #70: signing out, a session that ends for another reason and deleting the
  account now remove what the app kept on the phone or computer for that account (the record
  cache, the last-chosen portfolio, the camera's record, and on phones the pickers' copies and
  files written to share), and the record cache serves one account at a time. It also carries
  #98 (the record of 1.4.1) and three changes the changelog leaves out: #100 (the Dependabot
  updates of 16 November), #96 (the pull-request title action 6.1.2) and #91 (the Gradle wrapper
  9.9.0). No migration: 24 stay applied (`list_migrations`), and nothing under `supabase/`
  changed since v1.4.1, so Releasing step 5 (the Auth templates) did not apply.
  **The first attempt failed in one job.** "Build and attach artefacts" stopped in its Android
  step at 05:48 UTC: Gradle could not resolve
  `org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20` for the `kotlin-dsl` plugin of the
  Flutter SDK's own included build (`:gradle`, which provides
  `dev.flutter.flutter-plugin-loader`), because the Gradle Plugin Portal sends that request on to
  `repo.maven.apache.org`, which answered 429 Too Many Requests, on the first try and again on
  Flutter's one retry, 100 ms later. That job attached nothing, so the release had only the three
  iOS files, which the iOS build attached at 05:52 UTC. The rest of attempt 1 passed: preflight;
  the iOS build; Deploy's backend (`supabase db push` found the database up to date, the four
  Edge Functions were redeployed, version 20 at 05:47 UTC, and `health` answered 200) and web app
  (its smoke tests on `https://app.mmakaan.app` and on the old address, whose `/auth/callback`
  still clears its storage and goes on); and the website, whose download page then linked to the
  iPhone file alone. CI's Android release build of the same commit passed in those same minutes,
  on a restored Gradle cache (Follow-ups, Open, has why that matters). As `docs/operations.md`,
  Releasing step 4, says, the agent re-ran the failed jobs once, at 05:55 UTC (attempt 2): the
  Android and web build passed and attached its seven files and their provenance file by 06:05
  UTC, and the website was deployed again by 06:07 UTC, its smoke tests passing, with the
  release's eleven files listed.
  Checked by the agent afterwards, on downloads of all eleven files: each matches the digest
  GitHub gives for it, and the seven build files have the SHA-256s that `SHA256SUMS` and
  `SHA256SUMS-ios` list (`sha256sum -c`, all OK). Both provenance files were read against them:
  seven and two subjects, each with the listed SHA-256, whose certificates name
  `.github/workflows/release.yml@refs/heads/main`, commit 9807197 and a GitHub-hosted runner (the
  Android one from attempt 2, the iOS one from attempt 1), one transparency-log entry each; that
  reading checks no signature, but the Release run's own check steps verified both files with
  `gh attestation verify` (gh 2.104.0: step 9 of the iOS job in attempt 1, step 12 of
  `artefacts` in attempt 2). Not
  passed: `SECURITY.md`'s `gh attestation verify`, run on all nine files, stopped at "error
  creating Sigstore verifier", since the container's proxy refuses `tuf-repo-cdn.sigstore.dev`
  and `tuf-repo.github.com`, where `gh` fetches Sigstore's trusted root; the owner's own run is
  still needed. The download page, in English and Urdu, shows 1.4.2 and links to the v1.4.2
  files; the site's `llms.txt` and `https://app.mmakaan.app/version.json` say 1.4.2 (read through
  the Vercel connector, as the proxy refuses both hosts). The daily query of Monitoring and
  alerts returned no rows (07:17 UTC). Merged after the release, the same day: #107 (the
  Dependabot updates of 22 November, among them Gradle 9.9.1, AGP 9.5.2 and actions/setup-java
  6.3.0).
- Release 1.4.1 was published on 16 November 2026 at 15:46 UTC (tag `v1.4.1`, commit 17888e9 on
  `main`; the Release run 43899955940, 15:46 to 15:58 UTC; every job passed, as the agent read
  it). The agent merged the release pull request (#87) on the owner's standing word, after the
  hold on step 12 of the move ended at 14:00 UTC. It carries #84 (the old address's
  `/auth/callback` clears its storage and sends people on), #88 (the pitch deck's notes take the
  version and the release count from the changelog) and #86 (the record of 1.4.0). No migration:
  24 stay applied (`list_migrations`). Its Deploy run redeployed the four Edge Functions
  (version 19, 15:47 UTC, `list_edge_functions`), the web app and the website, each with its
  smoke tests, and the download page shows 1.4.1.
  It was the first real run of the callback's check against Vercel. The Deploy job's log has
  `/auth/callback?code=smoke-test on https://maalik-e-makaan.vercel.app: 200, clears its storage
and goes to https://app.mmakaan.app`, with the App Links file still answered there. Eleven
  files are attached, as for 1.4.0. The agent read both provenance files against the checksum
  lists again: seven and two subjects, each with the listed SHA-256, signed for
  `.github/workflows/release.yml@refs/heads/main` at commit 17888e9, one transparency-log entry
  each. Not run by the agent: `gh attestation verify` (its container cannot reach Sigstore).
  Now the owner's (`docs/operations.md`, Domains, step 12): `ALLOWED_ORIGINS` set to
  `https://app.mmakaan.app` alone, and the check by hand of the old callback.
  Merged the same day after the release: #96 (the pull-request title action, 6.1.2) and #91
  (the Gradle wrapper, 9.9.0), Dependabot's two updates that needed nothing else.
- Release 1.4.0 was published on 15 November 2026 at 20:25 UTC (tag `v1.4.0`, commit 433395a on
  `main`; the Release run 43757999421, 20:25 to 20:36 UTC; every job passed, as the agent read
  it). The agent merged the release pull request (#83) on the owner's standing word (`AGENTS.md`,
  How to work here). It carries #81 (each release's signed build provenance, and how to check a
  download), #82 (the record after 1.3.1) and #85 (the CI port reservation, which the changelog
  does not list, being a `ci` change). No migration: 24 stay applied. Its Deploy run redeployed
  the four Edge Functions (Deployed), the web app and the website, each with its smoke tests,
  and the download page shows 1.4.0 with its line on checking a download. Eleven files are
  attached: the nine kinds 1.3.1 has, and the two provenance files,
  `maalik-e-makaan-v1.4.0.intoto.jsonl` and `maalik-e-makaan-v1.4.0-ios.intoto.jsonl`.
  It was the provenance steps' first real run. The runner's `gh` was 2.103.3, so the source ref
  was compared exactly (`SECURITY.md`, Checking a download). `gh attestation verify` prints
  nothing when it succeeds outside a terminal, so each step's log shows only that version; the
  steps passed under `bash -e`, and the agent read the two attached files instead. Each is one
  Sigstore bundle holding SLSA provenance v1, signed for
  `.github/workflows/release.yml@refs/heads/main` with one transparency-log entry, built from
  commit 433395a (the tag's). Their subjects are the seven files `artefacts` attached and the
  two `ios` attached, each with the SHA-256 that `SHA256SUMS` and `SHA256SUMS-ios` list (and
  those two lists' own). Not run: `gh attestation verify` by the agent, whose container cannot
  reach Sigstore; the first person to run `SECURITY.md`'s command on a download does that.
- Release 1.3.1 was published on 15 November 2026 at 15:50 UTC (tag `v1.3.1`, commit 8f6f062 on
  `main`; the Release run 43732066821; every job passed, as the agent read it). The agent
  merged the release pull request (#79) itself, on the owner's standing word of that day:
  release whenever everything meant for a release is merged and green (#81 recorded it in
  `AGENTS.md` and the runbook). It carries #77 (the record after
  1.3.0 and the regenerated database types), #78 (the pitch deck brought up to date) and #80 (Search
  Console's ownership file). No migration: 24 stay applied. Its Deploy run redeployed the four
  Edge Functions (Deployed), the web app and the website, each with its smoke tests. Nine files are
  attached: the app bundle, three APKs, the web zip, the debug symbols, the unsigned iOS app,
  `SHA256SUMS` and `SHA256SUMS-ios`.
- Release 1.3.0 was published on 15 November 2026 (tag `v1.3.0`, commit 638586b on `main`; the
  Release run 43720578854). Its Deploy run applied `20261112092618_residence.sql` to the hosted
  project with `supabase db push` and redeployed the four Edge Functions through the CLI; every
  job passed. The web app is at `https://app.mmakaan.app`, and its earlier address
  (`https://maalik-e-makaan.vercel.app`) answers with the page that clears its storage and goes
  on to the same path there, while `/auth/callback` (until step 12's release) and
  `assetlinks.json` are kept as they were;
  the website is at `https://mmakaan.app`, and `www` and the site's earlier address answer 308 to
  it. The Deploy run's smoke tests showed each of these. "After every migration" was done the
  same day (branch `claude/post-release-1-3-0`; Hosted Supabase Project has the results).
- After the release, on 15 November 2026 (`docs/release-readiness.md`, Owner actions, item 13):
  the owner reported step 8 done, Auth's Site URL on `https://app.mmakaan.app` and the `APP_URL`
  repository variable deleted (the agent's session can read neither). At the owner's word the
  agent moved the web app's Checkly monitor to `https://app.mmakaan.app/` and added one on
  `https://mmakaan.app/`; both pass, beside the deep health check, and the account's plan reads
  "Trial", so check them again when the trial ends. The owner sent Search Console's HTML file
  the same day; it is `website/public/google17fd3f30f3354533.html` (#80, in release 1.3.1). The
  `roadmap` label's description names the new address. The owner set
  the Edge Function secret `MAIL_REPLY_TO=hello@mmakaan.app` in the dashboard that day (the
  Supabase connector's way of storing a secret was paused); the dashboard's digest is the
  address's SHA-256.
- **Step 12, released in 1.4.1 on 16 November 2026 (pull request #84):** the old
  address's `/auth/callback` answers with the page that clears its storage and goes on, like every
  other path; the old address serves only files (`assetlinks.json`, and the app's other files for
  tabs still open there). `redirect_smoke_test.sh --moved` checks the callback in CI and after each
  deploy, and its wait covers it (`tool/web/test_redirect_smoke_test.py`); the Deploy workflow's
  Edge Functions preflight checks only the origin. It waited until 14:00 UTC on 16 November 2026,
  24 hours after the move's deploy, and went out at 15:46 UTC. Still to do, by the owner:
  `ALLOWED_ORIGINS` set to `https://app.mmakaan.app` alone, and the check by hand of
  `docs/operations.md`, Domains, step 12. A late link (asked for in a tab open on the old address
  since before the move, the only app whose links name the old callback, and opened after that
  release) cannot finish; D-20 and Where it never clears say why the window stays. Two app
  follow-ups came out of it (Follow-ups, Open).
- **Closed, 15 November 2026: the app's e-mail sender.** `MAIL_FROM` was changed to
  `hello@mmakaan.app` at 14:13 UTC, which Resend refused while it had verified only
  `news.ar27111994.dev`. The owner finished the move that day (item 13, step 13, and
  `docs/operations.md`, E-mail, step 1): `mmakaan.app` added to Resend at 15:06 UTC and verified
  at 15:21 UTC (ap-northeast-1, Tokyo), with the records Resend listed (a DKIM TXT on
  `resend._domainkey`, `CNAME` records `send` and `rsend`, not the MX and TXT the runbook named),
  "Enable receiving" off, click and open tracking off, two new sending keys limited to the
  domain, Auth's SMTP sender `hello@mmakaan.app` and `MAIL_FROM` with the display name (the
  owner reported); `news.ar27111994.dev` is no longer the sender. The agent read the raw headers
  of a sign-up confirmation sent at 15:44 UTC: from `Maalik-e-Makaan <hello@mmakaan.app>`,
  `dkim=pass` for `mmakaan.app` (selector `resend`), `spf=pass` with the return path on
  the domain's `rsend` subdomain, no click or open tracking, the link back to
  `https://app.mmakaan.app/auth/callback`; but no `dmarc` entry, because the domain's `_dmarc`
  held two records, the owner's and Dynadot's own, and two DMARC records at one name mean that
  none applies (RFC 7489, section 6.6.3). The owner removed theirs; a lookup then showed
  Dynadot's own alone, `p=none`. Still open, the owner's: an e-mail that shows `dmarc=pass`, and
  the password reset and invitation e-mails, which the agent has not seen.
- Search Console (item 13, steps 1 and 11): at 16:03 UTC on 15 November 2026 the agent read
  `/google17fd3f30f3354533.html` on `https://mmakaan.app` and on
  `https://maalik-e-makaan-site.vercel.app` through the Vercel connector, 200 with the file's one
  line (53 bytes) each, the old address without a redirect. The owner then reported
  (screenshots): the old site address's URL-prefix property verified and its change of address
  to `mmakaan.app` started; a Domain property for `mmakaan.app` and a URL-prefix property for
  `https://mmakaan.app/`; the sitemap `/sitemap-index.xml` submitted and read, status Success, 42
  pages (the 44 built pages less the two not-found pages). Bing stays optional.
- Step 10, 15 November 2026: the repository's homepage reads `https://mmakaan.app` (the owner
  set it). The company's website stays `https://ar27111994.dev/` (the owner's decision), so
  `company.url` in `website/src/config/site.ts` does not change; the footer of every page reads
  "© 2026 AR LABS (SMC-PRIVATE) LIMITED" (read by the agent on the live terms page at 16:19 UTC).
- Waiting on the owner, 15 November 2026: the AWS Activate provider's three requests of 12
  November 2026 (the website and the web app on the company's own domain, an e-mail address
  there, the company's name on the website) are met, and a reply with the pitch deck at 1.3.1
  was drafted for the owner to send; the agent advised a separate mailbox for the application
  over sharing the company mailbox's login. Also still the owner's: the rest of step 9's checks
  by hand (the reset and invitation e-mails with `dmarc=pass`; an old invitation address with
  its hash; the old address's storage emptied; App Links on a phone with the 1.3.1 APK); leaked
  password protection in Auth; `tool/db/time_zone_skew.sql` in the SQL editor; the website on
  LinkedIn and the D-U-N-S record; the three Checkly monitors once the account's "Trial" (read
  on 15 November) ends; now that release 1.4.1 carries step 12 (16 November 2026),
  `ALLOWED_ORIGINS` set to the new origin alone and the old callback checked by hand; and
  `SECURITY.md`'s `gh attestation verify` on a download of 1.4.0, 1.4.1 or 1.4.2 (Checking a
  download), which the agent's container cannot run, as it cannot reach Sigstore's trusted root.
- Open note for the owner (15 November 2026): the owner also made an inbox for
  `hello@mmakaan.app` in Resend, with a receiving address; nothing is forwarded to it. The
  agent's advice: forwarding the mailbox there would put people's incoming messages at Resend,
  which the privacy page names only as the sender of the app's e-mails, so the privacy page
  changes first if that is wanted.
- Code scanning (2026-11-15, branch `claude/self-repository-syntax`, not merged into `main`):
  zizmor's three `self-repository` notes on `main` are settled by calling `deploy.yml` as
  `uses: $/.github/workflows/deploy.yml` (Release twice, Site refresh once). actionlint 1.7.12
  refuses `$/`, so `.github/actionlint.yaml` ignores exactly that message and
  `tool/github/check_workflow_calls.py` (`make lint`, with a canary test that fails once
  actionlint accepts `$/`) checks the calls instead. zizmor 1.32.0 is pinned in
  `tool/requirements-lint.txt` (and `.in`), runs offline in `make lint`, and the Security
  workflow's zizmor job now runs that version and fails on any finding without an inline ignore
  (`make docs-check`'s `zizmor-pin` check keeps the three equal).
  `docs/operations.md`, Code scanning and branch rules, records the ruleset on `main` and the
  Scorecard result of that day; turning on "up-to-date branches" and removing the admin bypass
  are open decisions for the owner. Signed release files (the owner chose this work on
  2026-11-15): since pull request #81, first released in 1.4.0 (Current Position has that run),
  each Release build copies its
  attestation's Sigstore bundle into `dist/` as `maalik-e-makaan-vX.Y.Z.intoto.jsonl` (and
  `-ios.intoto.jsonl`), checks it against every build file there with `gh attestation verify
--bundle`, and attaches it with them; `tool/github/check_release_provenance.py` (`make lint`)
  keeps the workflow so, within the limits `docs/operations.md` (Release provenance) names (a
  script or program a step runs, a gh alias or extension already on the runner, text built at
  run time), and
  `SECURITY.md`, Checking a download, tells people how to check. Signed-Releases then rises by 2
  a release; attaching provenance to v1.0.0 to v1.3.1 is the owner's optional step
  (`docs/operations.md`, Release provenance). zizmor's auditor persona (not the
  gate) still reports seven `secrets-outside-env` notes in `backup.yml` and `release.yml`.
- CI (2026-11-15, pull request #85): the UAT job of run 43740334888 (pull
  request #82) stopped before any test because `supabase start` could not bind `0.0.0.0:54322`,
  a port inside the kernel's automatic range that an outgoing connection can hold, so every job
  that starts the local stack now first reserves 54320-54329 (`net.ipv4.ip_local_reserved_ports`)
  and `tool/github/check_stack_ports.py` in `make lint` requires it. The pull request's own CI
  was the step's first run on a runner: in both jobs the kernel took the range, and the jobs
  passed. The race itself was not reproduced there.
- D-20 (the owner, 2026-11-13): the company bought `mmakaan.app` (Dynadot). The website moves to
  `https://mmakaan.app` (`www` redirects to it) and the web app to `https://app.mmakaan.app`;
  the `vercel.app` addresses send people on for good. Pull request #74, released in 1.3.0:
  `contracts/origins.json` as the one source of the origins (the website's
  defaults, the deck, the workflows' `APP_URL` and the page the web app's old address answers
  with read it; the Android manifest's hosts and `website/vercel.json`'s redirect are checked
  against it, and every other address by `make docs-check` C17); the website's old address
  redirects (`website/vercel.json`); the web app's old address answers every page with one that
  clears what the app kept in the browser there (`Clear-Site-Data: "storage"`, and a script for
  browsers without the header) and goes to the same address on the new one, while it keeps
  serving `assetlinks.json` and, until step 12's release, `/auth/callback`, neither of which
  clears anything; App Links on both hosts; `redirect_smoke_test.sh` in CI and after each
  deploy. Release builds and attaches nothing until its `preflight` job has checked that the web
  app's origin answers (`tool/web/check_live.py`) and that Auth allows every build's e-mail links
  (`tool/web/check_auth_urls.py`, which Deploy's `supabase` job also runs before the backend; a
  token that may not read Auth's settings only warns, and what the check gates goes ahead);
  Deploy's web app also waits for the Edge Functions to accept the origin, and the website goes
  out only after the web app it links to. The web app answers `X-Robots-Tag: noindex`. After
  CodeRabbit's review of dca00eb (2026-11-14): the Auth check gates the builds too, the Android
  manifest check works out each intent filter on its own and requires VIEW, DEFAULT and
  BROWSABLE, and the website's local Vercel emulation passes a redirected path on literally.
  A verification pass after it: the manifest check also refuses another host in an unverified
  web link filter (Android 6 to 11 verify every web host of the app, all or none).
- The move's state on 2026-11-14, from the owner (`docs/release-readiness.md`, Owner actions,
  item 13, has the steps): the Dynadot records are in and Vercel reports the three hosts as
  correctly configured (2026-11-13); the new addresses were checked over HTTPS in a browser,
  Auth's redirect URLs list all four callbacks with the Site URL left as it was, and the Edge
  Function secret `ALLOWED_ORIGINS` holds both app origins (reported 2026-11-14). The owner also
  set `APP_URL` to `https://app.mmakaan.app` that day, ahead of the order, in the Edge Function
  secret and in the GitHub repository variable. So invitation e-mails already link to the new
  address, which serves the web app from before the move until the release (a sign-up started
  there cannot finish its e-mail link), and the workflows on `main` would build for the new
  address until this pull request is merged; the weekly site refresh is next due on Wednesday
  2026-11-18. `APP_URL` stays at the new address in both places and is not set back before the
  release, because nobody uses the app yet (the owner, 2026-11-14). The merge, the release, Auth's
  Site URL, the variable's deletion and the monitors all followed on 2026-11-15 (the Current
  Position). The company's website in the structured data stays `https://ar27111994.dev/` (the
  owner's decision of 2026-11-15, step 10).
- The company's mailbox is `hello@mmakaan.app`, on Dynadot's own e-mail (free plan), not Zoho
  (the owner, 2026-11-13); a test message to Gmail passed SPF and DKIM for `mmakaan.app`. The
  website, both privacy pages, `llms.txt` and the deck give it as the contact address, and since
  2026-11-15 Auth's e-mails and the invitations are sent from it too (above). It is the one
  mailbox on the domain that `make docs-check` allows (`NAMED_MAILBOXES`).
- The device forgets the account (2026-11-13, branch `claude/signout-device-data`): signing out, a
  session that ends by itself, a session replaced by another account's (an e-mail link) and
  account deletion run `DeviceDataWipe` (`docs/architecture/app.md`, On the device). It removes
  the record cache, the
  portfolio last chosen and the camera's record, and on phones the pickers' copies, Android's
  records of a lost pick with the camera's full-size original, and the files written to share
  (once unchanged for ten minutes; younger ones at the next start or return to the app). The
  pickers' copies, the camera's original included, also go as soon as they are read; at start-up
  the camera's photos and record stay only while a lost photo may still come back (a day). A
  deletion whose answer was lost signs out and wipes as a deletion, and says so. Every saved
  entry names its portfolio in its key (`own`, `p:<id>` or `unknown`; each cached query declares
  its `CacheScope`, and the ten models behind the record queries read `portfolio_id`), as the
  owner decided on 15 November 2026 (D-21). Each list of portfolios the server answers (the newest
  asked only) sets the portfolios the user is in and removes, from the keys alone, every entry
  outside them, the unknown ones and the old `mm.swr.v1.` format included; a write is checked
  again as it lands, and a read never shows what the rule rejects. A portfolio joined on another
  device, opened here by its link and left before this device loads the list again is now
  removed at that load (P9, closed). A store that does not answer holds up neither the other
  removals nor the sign-out (three seconds each), and every wipe runs its own; the steps of
  a pass over the files start together, and a plugin's record of a lost pick that answers after
  five seconds has its copies discarded when it does. The list is shown and saved without
  waiting for the store; a profile or list made from the one on show is saved for the epoch it
  was asked for in; two reference models, a table of all 34 cached queries and the earlier
  reviews' probes check it
  (`test/src/data/cache/`). The cache serves one user at a time (16 November 2026, the owner's word
  to make the rules hold more simply, with fewer mechanisms: a fix that needs a new mechanism is not
  built, and the loss is named in `docs/architecture/app.md` instead): a wipe starts an epoch nobody
  owns, each status serves its user, and every read, write, list answer and removal does anything
  only while its user owns its epoch (`SwrCache.serve` and `serves`; `docs/architecture/app.md`, The
  session the cache serves). It replaced five guards (the epoch's `clearedSince`, the list's
  `_requireSession`, its shown-but-not-saved answer, `select(askedIn:)` and the wipe's
  single-flight), and closed what an independent verifier found on 2026-11-16: a query built
  between the wipe and the status saved the next account's answer under the ended one's key, a
  list command asked for the list after its session ended during its request, a profile
  notifier of one account read and saved under another's session, and the status followed a
  replayed event. A second pass by that verifier the same day found that Riverpod kept the
  earlier account's value in a provider rebuilt for the next account (now dropped,
  `sessionChanged`), and a loss of the saved list that is now named and pinned. Both reference
  models serve users too; built with each of three defects a cache could have, each predicts what
  such a cache would do, and the cache must differ from it (the defects live in the tests, not in
  `lib`). Greptile's review of 63b047d found three more, fixed on 21 November 2026: a write whose
  late deletion answered after another account had signed in put the earlier account's value on
  show (the write now asks again after that deletion, and what a notifier shows comes from
  `SwrCache.save`, which asks once more after the write; the portfolio list, shown without
  waiting for the store, sets its state with nothing awaited after its check); accepting an
  invitation read the signed-in user only after the answer (the answer now belongs to the session
  that asked); and two wipe tests wrote for an account the cache never served, so their write
  never began. Two independent verifiers of that round found more, fixed the same day: the
  delete-account screen kept the earlier account's preview, naming its portfolios, after another
  account's session replaced it (the preview now watches the session); a read went on reading
  after its listing of the keys answered for an ended session, and a build whose saved copy was
  read then still sent its request with the next account's token (each now asks again); an
  invitation's late answer forgot the one the next account had opened since (only the invitation
  answered is forgotten); bootstrap's start-up wipe was run by no test (it now is); and five lines
  were held by no test (now pinned). The last check of that round found that a screen left open
  while another account's session replaced the user's said the session had ended, with "Try
  again", to the person now signed in, until that account's first answer came; screens now show
  that state as loading (`waitsForSession`, which knows `sessionChanged`'s state by a stack trace
  only it gives its error), and a session that really expired still shows as one. The check
  after it found a search's results still on show, and not asked again, after another account
  signed in with the same portfolio current; a search is now keyed by the user too, as the
  portfolio list is. A deletion's sign-out is the deleting account's alone: when another account
  has signed in from another tab by the time the answer comes, nobody is signed out; when nobody
  holds the device, or the same account signed in again, it signs out as a deletion all the same
  (unless a store that does not answer holds up an earlier wipe with that sign-in queued behind it;
  see Follow-ups), decided from the session gotrue holds rather than the status shown (the first
  version of the rule, found by the next check, left the invitation after a sign-out in another
  tab). That check also found a documents list's photo links, signed for the earlier account, used
  again beside the next account's rows; they are now made again for each user who signs in. The
  check after that found the deletion's sign-out reading the provider's ref after the answer, which
  threw once the
  delete screen was left (the back button, or the router at a sign-out), so the device kept the
  deleted account's session and records; the command now reads everything it uses before its first
  wait. As #70 shipped it (since replaced by D-22, below), the command went on without its screen,
  also when the screen was left while it signed in again, and then sent the deletion (before #70,
  it sent none then, through an uncaught error): Cancel was disabled while it ran, and leaving was
  not cancelling. Whether back should cancel before the request goes was the owner's call: on 22
  November 2026 they chose "Back cancels until sent" (D-22), built on the branch
  `claude/deletion-back-and-sheets`, where leaving while the password is checked cancels and the
  screen cannot be left while a request is on its way. A command that chooses the current
  portfolio after a request chooses nothing when the session it asked in has ended meanwhile, and a
  start signed in removes what other accounts left in the cache and their chosen portfolio. Display
  settings stay; an invitation opened and not answered stays until it is answered or the account is
  deleted on that device (unless another account signed in there while it was being deleted, as the
  invitation may be that account's, or the app was closed meanwhile: the next start shows the
  account until its refresh is refused, and that sign-out wipes it as a plain one), because "sign
  out, then sign in with the invited address" needs it. The website's how-it-works step and privacy
  page say this in both languages, with what the app cannot delete (downloads, the browser's copies,
  the clipboard, other devices, backups); the privacy page also names the two exceptions. The J14
  browser-storage checks in the UAT (after a plain sign-out, which keeps an unanswered invitation,
  and after each deletion, which removes it) are written but not run here yet: they need the Docker
  stack.
- The amount reader's work items 1, 3 and 4 (`docs/roadmap/amount-parser.md`), merged in #75 and
  released in 1.3.0: `contracts/amount_lexicon.json` (version 1,
  `"reviewed": false`; the native-speaker review is the owner's, work item 2, through
  `docs/roadmap/urdu-review.md`, starting with its `review.check_first`),
  `contracts/amount_vectors.json` (353 parse and 33 words vectors, written by hand), their checks
  in `generate.py --check` (`tool/contracts/amounts.py`, 30 tests; the promised examples are
  pinned to their amounts), and `mm_core`'s `parseAmount` and `formatAmountWords` with the
  generated `amount_lexicon.g.dart`, 100% line coverage, and property tests of 10,000 cases each
  (words in three scripts, digits in any script, random token strings). A review round
  (2026-11-14) made a dropped lower unit ("ek lakh bees", "1 crore 20"), a spaced `mn` or `bn`,
  "rupay do", `0,500`, "sawa 100 hazar" and a pasted bank line's "Cr" ambiguous rather than a
  number, and a million-digit input fast; a second (the same day) made every number exact or
  refused, after a long decimal under a chain of multipliers read as a wrong amount. Owner
  question 1 (million and m) is built as
  recommended until the owner answers, with `mn` and `bn` read like `k`. Still to do:
  `findAmounts` (5), the Deno and website ports (6), the read-back widget (7).
- D-19 is in place (2026-11-12, branch `wip/urdu-sans-2`, one pull request): Urdu interface text
  is Noto Sans Arabic in the tokens, `mm_ui`, the app (250 goldens re-recorded and looked at),
  the website (its Open Graph cards redrawn) and the pitch deck; Nastaliq is left for the
  wordmark مالکِ مکان. Urdu pages download 50,892 bytes of Urdu fonts instead of 196,068; English
  pages 1,352 on a phone and 16,788 from 30rem wide (where the header shows the wordmark) instead
  of 23,696. The app bundles Noto Sans Arabic at its normal width and Nastaliq cut to the
  wordmark's letters (`make fonts`): its fonts come to about 700 KB, down from 838 KB. The
  e-mails followed (#65, released in 1.2.0 on 2026-11-12): the three Auth templates and the
  invitation set Urdu text in Noto Sans Arabic or an installed sans, a size larger than the
  English (the Urdu type roles, on lines of whole pixels), with Nastaliq only for the wordmark,
  written by `make tokens`; the owner pasted the three template bodies into the dashboard on
  2026-11-13, and a test send of each is still to do (`docs/release-readiness.md`, Owner
  actions, item 5). Not yet
  changed: the gallery's Urdu screenshots, and an independent design review of the change
  (`docs/design-qa.md`). Pilot readers confirm the face (`docs/roadmap/urdu-review.md`).
- Decision 1 of the roadmap (D-16, residence), backend and domain half, on branch
  `wip/residence` (pull request #61), rebased on `main` at 415ce29 and since merged with `main` at
  16c200c (1.2.0; not merged into `main`):
  `20261112092618_residence.sql`
  (`profile_residences`, `portfolios.owner_abroad` added as NULL with the caretaker columns and
  their triggers, `create_portfolio` with `p_owner_abroad`, `set_owner_abroad`, `set_caretaker`;
  the definer allowlist is now 23), pgTAP suites 22 (by hand) and 23 (generated), the upgrade test,
  the contracts `residence_vectors.json` and `time_zone_vectors.json` from the pinned PyPI
  `tzdata` 2026.6 (IANA 2026f), `mm_core`'s `CountryCode`, `Residence`, `OwnerAbroad`,
  `TimeZoneId`, `QuietHours` and `DualTime` with the bundled zone data, and the app's data layer
  (models, repositories, providers; no screens). A review round added concurrency scenario 31
  (the caretaker, the owner-abroad answer and a declared residence in races; the invariants step
  is now 32, with `CaretakerIsManager`), pgTAP cases for the app's next-open answer and for
  memberships moved by the service role, an import-chain Pakistan-time guard in `mm_core`, and
  checks that `docs/agents/commands.md` names what `make test-tools` and `make contracts` do.
  In the rebase onto #56's harness, scenario 31 got `scenario 60 30` and orders its sessions with
  `fv.hold` and `await_session` like the others: about 7 s, at most 12.1 s under four busy loops,
  and it fails on each of five mutants of the migration (the caretaker trigger without
  `FOR SHARE`, either second role check, the answer read without its lock, the residence clear
  filtered on its values). After the rebase every gate passed: `make format-check analyze lint`,
  the generated-file checks, `test-tools`, `test-core`, `test-ui`, `test-app`, `test-gallery`,
  `test-db`, `test-db-concurrency` (three runs, and one under four busy loops),
  `test-functions` and `verify`; no golden changed.
  The TLA+ Membership model covers the residence paths (`set_caretaker`, its two triggers and
  the foreign key's `SET NULL`, `set_owner_abroad` with and without `p_if_unanswered`, a declared
  residence and its clear): five new properties, every mutant of scenario 31 mirrored. Its review
  round (2026-11-13) made GoTrue's foreign-key actions lock one row per step in any order, and
  added the audit rows (GoTrue's `SET NULL` of `actor_id`, the deletions' audit-trail `DELETE`,
  the audited RPCs' actor check), the second-level timing of GoTrue's revoke, `FOR SHARE` only on
  a committed manager's row, and the deadlock retry keeping its `KEY SHARE` on `auth.users`. Now
  106 configurations (71 in `ci`, 100 s; `all` 367 s, `team` 261 s of it), with mutants for every
  guard the README credits and two expected to pass (redundant guards). The residence paths
  needed no SQL change. Outside the app's paths, a direct Auth delete of a manager deadlocks with
  their leaving (with or without the caretaker: the audit row's actor check) and with the
  portfolio's deletion (their audit row), and for the caretaker with an owner's membership
  change (D1, D3); a service-role change of the caretaker's membership with the RPCs (D2); a
  restored schema's foreign-key order with the delete-account order (P1). All are operator rules
  in `docs/operations.md`, replayed by `formal/tla/Membership/replay/residence.sh` (R1 to R8);
  scenario 31 runs the delete-account order of the caretaker and the operator's rule. The model
  found one defect older than this branch, finding M2 (open, low): on the
  `delete-account` path, GoTrue's `SET NULL` actions after `admin_delete_account_data` can form a
  wait-for cycle with a deletion of a portfolio the user created or acted in (a former manager's
  row and audit row against `delete_portfolio`; a creator's portfolios locked in heap order
  against a co-owner's account deletion). `finding_m2_*` and replays R9 and R10 show it; the
  detector and the retries resolve it, and every other property holds. Its remedy
  (`admin_delete_account_data` nulls the user's 29 remaining `SET NULL` columns under id-ordered
  portfolio locks) is the owner's decision (Blockers); moving the audit-trail `DELETE` after the
  cascade alone was rejected (one shape only, and a new cycle on a restored schema).
  After the review round and the merge with `main`, every gate passed (2026-11-13):
  `make format-check-repo lint docs-check test-tools`, `make verify` (8/8 tracks, 452 s), the
  Membership `run.sh all` (106/106, 367 s), `replay/residence.sh` (76 s), `make test-db` (23 suites,
  1,974 tests) and `make test-db-concurrency` (288 s).
  `make test-db-stress` ran
  while another worktree was building (load average up to 15): every check passed except the
  once-a-day notifications' 15 s budget (25 s), which the base commit 9480e22 missed too (30 s and
  38 s), so its figures were not compared with "What it costs" in `permissions.md`; the review
  round's run (load average 6, no schema change) missed only the same budget (25.5 s). Re-run it
  on an idle machine.
  The UI half (onboarding, the owner-abroad question, settings, ARB strings, goldens, the privacy
  page, the data export) can start: the Noto Sans Arabic switch it waited for, because it
  re-records goldens, is in place (D-19). The owner's open questions Q1–Q7 are in
  `docs/roadmap/README.md`, decision 1.
- The roadmap after v1.0 (planned 2026-11-11; v1.0 itself is still in progress, below): its 25
  items are researched and planned, one plan each in `docs/roadmap/`, indexed by
  `docs/roadmap/README.md` (milestones, sizes, the order of work in waves, the owner's open
  decisions). The issue bodies in `.github/roadmap.toml` link the plans; the Roadmap workflow
  creates the issues when this reaches `main`. The owner's decisions of 11 November 2026 are
  D-16 to D-19 in `PROJECT.md`, and the roadmap changes that would reverse an earlier decision are
  open proposals P-01 and P-02 there.
- Milestone v1.0 (as of 2026-11-08), at commit e853378 on `claude/exciting-cray-2wue0f`. Phases 1–9 are built and
  tested; `REQUIREMENTS.md` ticks each requirement and says what remains of the six that are not
  finished (TEAM-05, WEB-01, NFR-03, NFR-04, NFR-07, NFR-08).
- Phase 4 (Design System): `mm_ui` passed its final design QA with notes (2e791e4: 2,494 tests,
  100% line coverage). The gaps the app's feature reviews found in it were closed in e853378
  (see [Follow-ups](#follow-ups)); what remains is in `docs/design-qa.md`.
- Phases 5–9 (the app): sign-in, first portfolio, shell and settings (fa5b6e5); team,
  properties, units, tenants and tenancies (b555c43); documents, money, operations, dashboard,
  reports and search (02050c1); the review follow-ups across database, design system and app
  (e853378: 1,740 app tests, 98.6% line coverage; `mm_ui` 2,627 tests, 100% coverage, as the
  commit records). Every feature group was reviewed independently for code and data and for
  design, and each finding was fixed or answered.
- Phase 10 (Website): built and deployed by CI (663331c, 0fb84fc, 682ceb3). Open before launch:
  a lawyer on privacy and terms, the official legal texts, a native Urdu editor.
- Phase 11 (CI/CD): CI, Security, Scorecard, PR-title, Release and Deploy workflows are
  committed, including the formal-verification job (3139ca4) and the web deploys (c1013b8,
  682ceb3). The first production Deploy run has not happened (see Blockers).
- Phase 12 (Documentation, UAT and release readiness) is in progress. Documentation stage
  (2026-11-08): root and per-area `AGENTS.md` (with `CLAUDE.md` pointers), `docs/agents/`
  (commands, conventions, workflows), `llms.txt`, `docs/README.md`, the README rewritten, and
  the docs checked against the code for drift. Browser UAT stage: `app/uat/` and `make test-uat`,
  14 journeys passing against a local Supabase stack (`docs/uat.md`), eight defects (D1–D8).
  Release-readiness stage: D1–D8 and the audit's engineering issues fixed (one new migration,
  `20261109081109_uat_display_fixes`, applied to the hosted project on 2026-11-09), the UAT
  passing with each fix asserted; verdict and owner actions in `docs/release-readiness.md`.
- The identity CHECK constraints (`20261108200216_identity_checks.sql`,
  `20261108200227_identity_checks_validate.sql`, pgTAP suites 19 and 20,
  `contracts/identity_vectors.json`) are committed in e853378 and applied to the hosted
  project.
- Formal verification: TLA+ models (Invitations, Membership, StorageCleanup, LedgerPayments,
  LateFees, RateLimit), Lean 4 and Z3 money proofs and the Bend proofs run with `make verify`
  and in CI.

## Active Decisions

- PROJECT.md D-01…D-23 record the decisions, and P-01 and P-02 the open proposals. The ones that
  carry most weight:
  - D-04: RLS plus composite foreign keys;
  - D-05: exact money;
  - D-06/07: the ledger and idempotent payments;
  - D-10: no tax estimate;
  - D-13: the Data API is opt-in;
  - D-14: the hosted migration history names the migrations;
  - D-15: write RPCs are SECURITY DEFINER behind a pgTAP allowlist;
  - D-16 to D-18 (the owner, 2026-11-11): residence declared per person and recorded per
    portfolio; letterheads on every generated document; privacy-first analytics, with PostHog
    cookieless on the website, PostHog and Intercom opt-in in the app, and Customer.io e-mail;
  - the owner's answers of 2026-11-12, recorded in D-16 to D-18: every caretaker is a member with
    the `manager` role; amounts in rupees only at launch, with no converted totals and no
    `display_currency`; the owner-abroad question asked with no answer chosen; letterheads per
    portfolio, with an optional Urdu version, A5 or A4 receipts (A5 by default), on every plan;
    PostHog's US Cloud organisation and Customer.io's US workspace kept, with the US named in the
    privacy notice; a dedicated PostHog project (730301) created that day with recording,
    heatmaps, console-log and dead-click capture, autocapture and surveys off and cookieless on;
  - D-19 (the owner, 2026-11-11; in place since 2026-11-12): Urdu interface text in Noto Sans
    Arabic, Nastaliq kept for the wordmark;
  - D-20 (the owner, 2026-11-13): the domain `mmakaan.app`, the website on the apex and the web
    app on `app.`, the `vercel.app` addresses sending people on (the web app's clears its storage
    first), the company's mailbox `hello@mmakaan.app` on Dynadot's e-mail; the origins written
    once, in `contracts/origins.json`, and carried by each release tag;
  - D-22 and D-23 (the owner, 2026-11-22): Back cancels an account deletion until its request is
    sent, and waits once it is on its way ("Back cancels until sent"); sheets, dialogs and menus
    close when the signed-in account changes ("Close sheets on account change").
- Open proposals, waiting for the owner: P-01 automatic WhatsApp reminders (against D-11); P-02
  Raast Request-to-Pay and open banking (against "recorded, not processed"). The website's promise
  of no analytics is withdrawn by D-18; its new text waits for the lawyer's review.
- App rules introduced by the feature stages (recorded in `docs/architecture/app.md`):
  - a document's file is uploaded first, then its row, with one uuid for every retry; a file
    queued for deletion is uploaded again under a new uuid;
  - client-chosen ids make every insert safe to retry; a deposit refund, which takes no key,
    recovers a lost answer by reading the ledger again;
  - charges change only through `update_charge`;
  - status taps write only the status columns (`setBillPayment`, `moveMaintenanceRequest`).
- Waiting for the owner: whether long lists may be ordered other than by when rows were added
  (maintenance by priority, expenses by date). The trade-off is in `docs/architecture/app.md`,
  "Open questions"; the code keeps keyset paging by `created_at, id`.

## Hosted Supabase Project

- Ref `aaifamxzzjspohwksxyr` ("maalik-e-makaan"), org AR Labs, region ap-south-1, Postgres 17.11.
- Twenty-four migrations applied, the latest `20261112092618_residence` (below). The first
  twenty-three, up to `20261109081109_uat_display_fixes`, according to the commits that applied
  them (764e640, c1c0d7a, 13c5d18, f155413, 67639d8, e853378 and the
  Phase 12 release-readiness commit), each of which records a matching schema fingerprint
  (20261109081109: 1,185 objects, `fa5a29f9984e169a032725898e5b93b2`).
- `20261112092618_residence.sql` was applied on 15 November 2026 by release 1.3.0's Deploy run
  (`supabase db push`), so 24 migrations are applied; releases 1.3.1 to 1.4.2 carried none
  (`list_migrations`, read again by the agent after 1.4.2). "After every
  migration" (`docs/operations.md`), done the same day with read-only queries:
  1. Versions: the hosted history (`list_migrations`) lists the 24 local versions, in the same
     order, with nothing extra on either side.
  2. Types: `_shared/database.types.ts` regenerated from the hosted project: the table
     `profile_residences`, the `portfolios` columns `caretaker_since`, `caretaker_user_id` and
     `owner_abroad` (also in `create_portfolio`'s result), `create_portfolio`'s `p_owner_abroad`,
     and the RPCs `set_caretaker` and `set_owner_abroad`; no enum changed. The functions needed
     no change.
  3. Drift: `tool/db/fingerprint_diff.py` says "schemas match (1220 objects)" between the local
     chain (PostgreSQL 16) and the hosted project (the `psql -At` output's md5 is
     `ebe541b2085461f621b30aa26a82297e`).
  4. Advisors: security lists the 23 write RPCs pinned in `01_schema_security.test.sql`, name for
     name, and leaked password protection (off; an Auth setting, the owner's). Performance lists
     only "unused index" INFO findings (62), among them the new
     `portfolios_caretaker_user_id_idx`; no unindexed foreign key and no policy that re-evaluates
     auth functions per row.
  5. GoTrue's foreign-key actions on `auth.users`: the hosted order, without Auth's own tables,
     is the order `formal/tla/Membership/replay/residence.sh` prints for the migrated local
     database (34 entries), with `portfolios.caretaker_user_id` last, after
     `portfolio_members.user_id`; so the Membership model's `caretaker_first` configurations do
     not describe the hosted project. The replay's outcomes were all as expected.

  Still to run on the hosted project, by the owner in the SQL editor (the file is too long for
  the connector's query call): `tool/db/time_zone_skew.sql` (`docs/operations.md`, Time-zone
  data). The pitch deck's trust slide (`website/deck/slides/trust.html`, slide and
  speaker notes) says 23 reviewed write functions and 23 database suites, as releases 1.3.0 to
  1.4.0 have. The deck's notes named 1.3.0 as the released app and counted five releases
  since 1.0.0 until after 1.4.0; they now take both from the manifest and the changelog
  (`{{version}}`, `{{laterReleases}}`; `website/deck/README.md`), and a unit test refuses a
  slide that writes either out.

- `20261109081109_uat_display_fixes.sql` (UAT D5 and D6: "vacant since" as a Pakistan date;
  automatic late fees without the English note, and the note removed from those already written)
  was applied on 2026-11-09 by the process in `docs/operations.md`; afterwards no live automatic
  late fee carries the note, and the security advisor lists only the known write-RPC warnings.
- `20261108200216_identity_checks.sql` was wrapped in `begin; … commit;` after the hosted project
  applied it (UAT D1: the CLI could not apply its `LOCK TABLE`). The schema it builds is
  unchanged (identical fingerprints), and `supabase db push` skips it because the hosted history
  records the version (checked locally: `supabase db push --dry-run` says up to date with the file
  changed).
- pg_cron jobs:
  - `mm-daily-jobs`: every 10 minutes; the day's notifications and cleanup run once per
    Pakistan day, and later runs retry a skipped orphaned-file sweep;
  - `mm-storage-cleanup`: every 10 minutes, through pg_net, once the Vault secrets are set;
  - `mm-rate-limit-cleanup`: hourly.
- `authenticator` has `pgrst.db_pre_request = app.check_request`.
- Advisors (2026-11-03; on 2026-11-15, after the residence migration, the same, as step 4 above
  records):
  - Security: only the reviewed definer RPCs (lint 0029, intentional; see D-15).
  - Performance: "unused index" INFO findings only. These are expected on an empty database, and
    the indexes are justified by foreign-key coverage and the stress test.

## Environment Notes (for future sessions)

- The Flutter SDK is at `/opt/flutter` (3.47.9 stable); add `export PATH=/opt/flutter/bin:$PATH`.
  The pinned Python tools are in `.venv` (`make bootstrap`).
- Local Postgres 16 with pgTAP and pg_cron:
  - The data directory is `/var/lib/postgresql/mm16`, on port 54329. It runs as the `postgres`
    OS user.
  - Use `tool/db/test.sh` (pgTAP), `tool/db/concurrency_test.sh` and `tool/db/stress_test.sh`.
  - `MM_TEST_DB=<name> tool/db/reset.sh [--seed]` gives you a disposable database.
- Postgres 17 is not available locally (the apt repository is blocked). Postgres 17 behaviour is
  verified against the hosted project with read-only queries, and in CI through
  `supabase test db`.
- `supabase start` runs here with the Supabase CLI 2.122.1 (`/usr/local/bin/supabase`) and a
  `dockerd` started by hand: `public.ecr.aws` is blocked, so set
  `SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io`; the root disk has about 1 GB free, so Docker's
  data lives on a RAM disk (`/mnt/mmdocker`); the edge-runtime container must trust the proxy's
  CA (`docs/uat.md`, Environment). `make test-uat` then runs the browser UAT.
- Time zones: the local PostgreSQL 16 uses the system's tzdata 2026e, and `pg_timezone_names` has
  no backward links (`Asia/Calcutta`, `US/Eastern` are absent). The contract generator never reads
  it: `tool/contracts/time_zones.py` reads the PyPI `tzdata` pinned in `tool/requirements.txt`
  (`make bootstrap` installs it into `.venv`). `tool/db/time_zone_skew.sql` here returns one row,
  `America/Havana` on 1 January 2027 (2026f changed Cuba's clock).
- `*.supabase.co` and `supabase.com` are blocked from the container. Use the Supabase MCP tools
  for the hosted project; `search_docs` reads the documentation.
- `git ls-remote` against GitHub works, which is how GitHub Actions get pinned to commit SHAs.
- `tool/formal/install.sh` installs the pinned formal toolchain (TLC, Lean 4.35.0 and 4.34.0,
  z3-solver, Bend) into `.cache/formal`, checking every checksum.
- The GitHub MCP tools can read workflow runs and job logs (`actions_list`, `get_job_logs`).
- There is no Xcode here: iOS changes (for example the `InfoPlist.strings` localisations in
  02050c1) are unbuilt until CI or a Mac builds them.
- The sub-agent model: `.claude/settings.json` names it (`CLAUDE_CODE_SUBAGENT_MODEL`, with
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`), and a session on someone's own computer reads it once they
  trust the folder. A cloud session did not: on 2026-11-14, restarted with the file in place, it
  still started a sub-agent and a workflow agent on its own model, and gave another sub-agent the
  different model that call asked for. Until the owner sets both variables on the cloud
  environment (its settings, Edit, environment variables; a new session picks them up), name the
  model on every agent a cloud session starts: `model` on the Agent call or in the workflow
  script. A fork always runs on its parent conversation's model, with or without the variables.

## Blockers (need the owner)

The ordered checklist of everything the owner must do before launch is in
`docs/release-readiness.md`, Owner actions. For the roadmap, `docs/roadmap/README.md` lists the
owner's decisions by date. The ones that hold up the launch milestone (due 2027-02-28):

- **By 2026-11-30:** the response to the State Bank's draft open-banking regulations, if AR LABS
  is to comment (`docs/roadmap/open-banking.md`).
- **The D-U-N-S number** gates Google Play, the App Store and paid plans; Dun & Bradstreet quotes
  up to 30 business days.
- **The move to the domain:** `mmakaan.app` is bought (D-20, 2026-11-13), its DNS points at the
  hosting and its mailbox, `hello@mmakaan.app`, exists (both 2026-11-13). The move's pull request
  is merged and released (1.3.0, 2026-11-15), and the owner's steps up to step 8 are done, with
  steps 1, 11 and 13 (except its e-mail checks) and step 10's homepage and company website (the
  same day). Waiting on the owner: step 9's checks by hand and the e-mails with `dmarc=pass`, the
  website on LinkedIn and the D-U-N-S record, and, step 12 being released (1.4.1),
  `ALLOWED_ORIGINS` and the check by hand of the old callback
  (`docs/release-readiness.md`, Owner actions, item 13).
  Apple enrols an
  organisation only if its website is on a domain associated with it, with work e-mail there; the
  same domain serves Meta's verification and the e-mail sending subdomains.
- **A lawyer:** a fixed-fee request for quotation this month, with a deadline at least six weeks
  before the store submissions. The plans have the lawyer review the privacy text for D-18 before
  any analytics SDK ships, as the research recommends.
- **A native Urdu editor**, after the owner signs off the glossary.
- **By 2026-12-30:** the 60-day notice to early-access users, if anyone is to be charged before
  2027-02-28; billing's web checkout would then come into wave 1 (`docs/roadmap/README.md`).

The rest, in short:

- Finding M2 of `formal/tla/Membership` (open, low; `docs/operations.md`, Deleting a user
  account): decide whether `admin_delete_account_data` should set the 29 `ON DELETE SET NULL`
  columns that name the user (`created_by`, `invited_by`, `voided_by`, `actor_id` and the like)
  to NULL under portfolio locks taken in id order, so that GoTrue's deletion finds nothing to
  lock. It writes 20 tables (each write audited) and locks more portfolios, including ones the
  user has left. Until then a rare 40P01 on the delete-account path is resolved by the retries.
- Done with release 1.0.0 (2026-11-09) and by every release since: the first production run of
  the Deploy workflow. It deploys the web app to Vercel (`web` job) and redeploys the Edge
  Functions, so they send the database's Retry-After (`admin_rate_limit_hit`, 20261107181820)
  and no longer call the deprecated `admin_hit_rate_limit`.
- Google Play: the organisation account waits for its D-U-N-S number. Once the app is on Play,
  add the Play app-signing key's SHA-256 to `app/web/.well-known/assetlinks.json`, and link the
  listing from the website.
- The owner, a native Urdu speaker, reviews the app's and the website's Urdu (including the date
  picker's day names, one glossary for the app and the site, and the e-mail templates).
- The backup key: an `age1...` public key in the repository variable `BACKUP_AGE_RECIPIENTS`.
  Until then the Backup workflow refuses to run.
- A lawyer to review the privacy policy and the terms (website and app) before launch.
- The official legal texts (`.gov.pk`) behind the guides could not be reached from here; the
  guides word every unconfirmed point as unconfirmed until someone checks them.
- Custom SMTP for Supabase Auth e-mails before launch, through Resend's free plan (owner's
  choice, 2026-11-09), with the bilingual templates in `supabase/templates/`. The sending domain
  `news.ar27111994.dev` was verified (2026-11-09), with click and open tracking off (the owner,
  reported 2026-11-12). Since 2026-11-15 the domain is `mmakaan.app`, verified with tracking off,
  and the sender `hello@mmakaan.app` (the Current Position).
- Reported done by the owner on 2026-11-09 (not checkable from the agent's network): the backup
  key, `RELEASE_PLEASE_TOKEN`, Supabase SMTP through Resend with the templates, and the other
  configuration in `docs/release-readiness.md`, Owner actions. Since then: the pull request to
  `main` and the first Deploy run (release 1.0.0, 2026-11-09), and the uptime monitors, on
  Checkly (Better Stack refused sign-ups; the Current Position). Waiting: the D-U-N-S number. On 2026-11-12 the owner reported
  the three Auth templates updated in the dashboard (the plain-Urdu copies, still in Nastaliq);
  on 2026-11-13, after release 1.2.0, they pasted the sans-Urdu copies from `main`.
- Answered by the owner on 2026-11-09: the operator named on the privacy page (Ahmed Rehan) is
  right; the repository secrets, variables and environments are set (`RELEASE_PLEASE_TOKEN`
  still to add); Resend's free plan for e-mail. Done by the agent the same day: migration
  20261109081109 applied, the Backup workflow, the first backup restored and checked
  (`docs/release-readiness.md`, The first backup and restore).
- Done by the owner on 2026-11-07: the Vault secret `mm_storage_cleanup_token` (checked: a
  cleanup call with it answers 200), the GitHub secret `VERCEL_TOKEN` and the upload key's
  SHA-256 fingerprint for Android App Links.
- Done by the owner on 2026-11-05: the Edge Function secrets (`APP_URL`, `STORAGE_CLEANUP_TOKEN`,
  `RESEND_API_KEY`, `MAIL_FROM`), Supabase Auth's Site URL and redirect
  (`https://maalik-e-makaan.vercel.app/auth/callback`), and the GitHub secrets, variables and
  `production`/`release` environments the Deploy and Release workflows read.

## Follow-ups

Collected from the feature reviews of 02050c1. None blocks the code that is committed; each needs
the owner of the area named. Checked against the code on 2026-11-08 (documentation stage).

### Open

- Owner: Android Auto Backup is on (`allowBackup` is not set in `AndroidManifest.xml`), so the
  session and the record cache reach the person's Google backup, as the preferences reach iCloud
  on iPhone; the privacy page now says so. Turning it off, or excluding the preferences, is the
  owner's decision with the lawyer (legal pack, question T7). The legal pack's data map (rows
  14a to 14e, PR #66) describes the device before the wipe and needs the same update.
- Owner: a sign-out that cannot reach the server leaves that session valid on it (refresh tokens
  do not expire by time; `supabase/config.toml` sets no `[auth.sessions]` time-box or inactivity
  timeout), so a copy of it in a phone backup can still sign in; the privacy page says so. A
  session inactivity timeout on the hosted project, or retrying the server sign-out later, is the
  owner's decision.
- Licences: `MmIcons.ttf` has empty copyright fields (`THIRD_PARTY_NOTICES.md`, Gaps). dbus
  0.8.0 (MPL-2.0, Linux desktop only, unmodified): a distributed Linux build must say where its
  source is.
- App: decide list ordering for maintenance (priority) and expenses (date); see Active
  Decisions.
- App: check every REST request, including the foreign-key embed names such as
  `utility_bills_charge_id_fkey`, against a running PostgREST before release (NFR-07). There is
  no `app/integration_test/` yet, so `make test-integration` has nothing to run.
- App: names are not bidi-isolated inside some messages (not re-checked).
- App: a ten-year Urdu statement PDF is about 6.8 MB; Urdu PDF rows are a few points out of
  line, and Latin names in them come out small and grey. PDFs have no automated image golden.
- App: iOS localised permission prompts are unbuilt; the web compression timing is unmeasured on
  a real phone.
- App: the audit trail has no screen (TEAM-05; nothing in `app/lib` reads `audit_logs`).
- App: the browser UAT does not reach the operations screens, reports or search (NFR-07).
- App: a provider disposed while its fetch waits raises an uncaught error when the fetch goes on
  (found on #70, 22 November 2026): `DashboardController.fetch` reads `ref` after an await
  (`insights.dart`, `UnmountedRefException`), and `SwrCache._watch` (`swr_cache.dart`) throws a
  fetch's `NetworkFailure` or `SessionExpired` once its listener has gone. Screens are right;
  the errors reach only the handler of uncaught errors (`bootstrap.dart`, which prints them).
  Read the dependencies before the first await, or ask `ref.mounted` after each, and have
  `_watch` drop the error of a fetch whose subscriber has cancelled.
- App: a re-authentication on its way when another tab signs the account out signs it back in
  (found on #70, 22 November 2026; older than #70): `reauthenticate` (`auth_repository.dart`) is
  a real `signInWithPassword`, whose answer gives the device, and every tab, a new session of
  that account, while the delete screen reports an expired session and sends no deletion. The
  owner's call; one way is to sign out again after it when the cache no longer serves the
  session that asked.
- App: the check-email screen shows the last address an e-mail was sent to for the whole run,
  across sign-outs (found on #70, 22 November 2026; older than #70): `pendingEmailProvider`
  (`auth_controller.dart`) is in memory, and nothing clears it at a sign-out or a wipe;
  `docs/architecture/app.md` names it. Clear it when a session starts or ends, or accept it
  there.
- App: a sign-out whose gotrue fails before announcing it (its storage cannot remove the
  sign-in-link verifier) wipes the device in `signOut`'s `finally` but applies no status, and
  supabase_flutter, which removes the stored session only on that announcement, keeps it: the app
  goes on showing the status it had, and the next start restores the session (found on #70, 22
  November 2026; the status and the stored session behaved so before #70).
  `docs/architecture/app.md` (Hooks) names it. Rare; the owner's call whether `signOut` should
  then remove the stored session and apply the device's status itself.
- App: a deletion answered while a store that does not answer holds up an earlier sign-out's wipe,
  with the same account signed in again behind it, ends as a plain sign-out (found on #70, 22
  November 2026): the deleting session was signed out elsewhere, that wipe waits for the store (up
  to `wipePreferencesLimit`), and the same account's sign-in, queued behind it, clears the cause the
  deletion's sign-out set. The sign-in screen does not say the account was deleted, and the
  invitation stays unless gotrue's call to the server ends before the held wipe does.
  `docs/architecture/app.md` (Hooks) and the command's doc comment name it; the privacy page does
  not, as it needs a store that fails. The owner's call whether the privacy page should say it too.
- App: pages open with no transition (found 22 November 2026, building D-22): in widget tests of
  the whole app (`MaalikApp`) every page the router builds is go_router's `NoTransitionPage`, its
  fallback for an app it does not take for a `MaterialApp`, and a plain `MaterialApp.router` with
  go_router 18.1.4 under Flutter 3.47.9 gets the same, so screens change at once, iOS has no swipe
  back and Android's predictive back has no animation. Check on a device; if it holds, find why
  go_router does not see the `MaterialApp`, or give the routes a `pageBuilder`. The delete screen
  already says when it cannot be popped (`PopScope`), which a swipe back asks first. On the same
  device, look at a snack bar as the account changes (D-23): in widget tests none shows on the first
  frame after the change, but Flutter's `clearSnackBars` runs the snack bar's exit animation, a
  quarter of a second, unless accessible navigation is on (`MmSnackbar` shows with no animation
  under reduced motion), so on a device its text may stay readable that long, as a sheet already
  closing does; if it does, the shell can call `removeCurrentSnackBar()` after `clearSnackBars()`.
- App: a voided Urdu receipt with tax withheld, a certificate and a note still takes two A5 pages
  (it flows on rather than being cut off); the usual one is one page (UAT D8).
- App: after the language is chosen, the router drops `/auth/callback` from `from` (it is a
  public path), so an e-mail link opened first in a fresh browser lands on sign-in with no word
  on what happened to the link. Keep the callback when it carries a `code` or an `error`, so its
  screen explains (step 12 of the move, 2026-11-15; goldens, l10n tests and the Urdu glossary
  check with it).
- App: `reasonLinkOtherDevice` tells a password reset to open the link where it was asked for,
  which cannot work once that browser's storage is gone; add "If you were resetting your
  password, ask for a new link here" in English and Urdu (the same source). Its "it is confirmed"
  holds for a sign-up; an e-mail change needs both of its links (`double_confirm_changes`), so
  say so there too.
- Website: Stylelint 18 (#95) and stylelint-config-standard 41 (#92) wait for
  stylelint-use-logical, the plugin behind `csstools/use-logical`, whose latest release (2.1.3,
  checked 2026-11-21) accepts stylelint `>= 11 < 18`, so `npm ci` fails with ERESOLVE.
  `.github/dependabot.yml` ignores both until a release that accepts 18, or a replacement plugin,
  lifts it; then take the two together and run the lint suite against stylelint 18's removed
  rules and options.
- Dart: `test` stays at 1.31.1. test 1.32.0 needs test_api 0.7.14, and the flutter_test of the
  Flutter that `FLUTTER_VERSION` in ci.yml names pins 0.7.12, so `.github/dependabot.yml` ignores
  test 1.32.0 and later until that pin moves. CI's `flutter pub get` re-resolves quietly, so a
  lockfile pub cannot satisfy still passes CI; `flutter pub get --enforce-lockfile` in CI would
  catch it (not yet done: it changes every Flutter job). Dependabot resolves with a newer Flutter
  than CI's: its lockfile in #105 named test 1.32.0 and test_api 0.7.14 despite the ignore, and
  the batch of 22 November kept 1.31.1 again. Flutter 3.50.0 and 3.50.1 (stable, 11 and 20
  November) pin test_api 0.7.14, so moving `FLUTTER_VERSION` to 3.50 lifts this; that is its
  own change, with the analyzer, the goldens and every Flutter job.
- Release: one rate limit of Maven Central can stop a release's Android build, as it stopped
  release 1.4.2's first attempt (22 November 2026, Current Position). The Release workflow's
  `artefacts` job restores no Gradle cache, so every release build fetches each Gradle plugin and
  library afresh; CI's Android release build caches them (`actions/setup-java` with
  `cache: gradle`: `~/.gradle/caches` and `~/.gradle/wrapper`, keyed on a hash of the Gradle
  files and restored only on that exact key). At 05:46 UTC that day CI's build of the release
  commit restored the cache CI had saved on `main` for 50bb156 at 05:38, and passed; the release
  build, with none, met the 429. Gradle retries a 429 itself (its source: three attempts, waiting
  1 s and then 2 s) before it disables the repository for the build, and Flutter 3.47.9 retries
  a build that fails on the network once, after 100 ms: neither waits as long as a rate limit
  lasts. Until a fix is chosen, a release whose build fails on the network is re-run as step 4
  of Releasing says. A split of the Release job into build jobs and a publish job is planned
  (the next change to release.yml); whichever option is chosen then goes in the Android build
  job, where a cache can change the bytes a build makes but not what the publish job holds. The
  options, none of them chosen yet:
  1. **`cache: gradle` in the build job**, one line as in CI. The release would restore what CI
     saved on `main` for the same Gradle files, which a release commit never changes (it touches
     version files only), so 1.4.2's first attempt would have found it. Costs: the signed build
     then takes input from every job of every CI run on `main`, any of which can save a key first
     (GitHub keeps caches per branch, not per job or workflow), so a poisoned plugin in the cache
     would be built into files whose provenance truthfully names release.yml; zizmor 1.32.0 does
     not flag it (tried on a copy, the gate and the auditor persona). It misses after a change to
     the Gradle files until CI on `main` has saved the new key, and it restores about 1.7 GB.
     `cache-read-only: true` would keep the release from saving, not from reading. Gradle's
     dependency verification (checksums of every dependency in the repository, checked on every
     build) would make a poisoned entry fail, at the cost of regenerating them with each update.
  2. **A retry with long waits around the Android step** (say up to three tries, minutes apart).
     No new input to trust, but a real failure takes longer, and a limit that outlasts the waits
     still stops the release.
  3. **Gradle's own retry settings for dependency resolution**
     (`org.gradle.internal.repository.max.tentatives` and
     `org.gradle.internal.repository.initial.backoff`, read by
     `ErrorHandlingModuleComponentRepository` in Gradle 9.9.0, as `systemProp.` lines in a
     `gradle.properties`). They reach Flutter's included build too, but they are internal names
     that Gradle does not document and may change, and they slow every real failure as well.
  4. **A mirror of Maven Central** listed before it. The request that failed came from the
     Flutter SDK's included build (`:gradle`) through the Gradle Plugin Portal's redirect, which
     `app/android/settings.gradle.kts` does not govern, so it is reached only by an init script
     on the runner (`~/.gradle/init.d`) or by the internal system property
     `org.gradle.internal.plugins.portal.url.override` (a JVM-wide `systemProp.` line), with the
     costs of an internal name; a mirror adds a party to trust, and Gradle moves on to the next
     repository only when a module is missing, not after an error.
- Design system: the open items in `docs/design-qa.md`, Follow-ups.

### Closed on 22 November 2026

The owner answered two questions #70 left open, on 22 November 2026; both are built on the branch
`claude/deletion-back-and-sheets`.

- Account deletion, in their words "Back cancels until sent" (D-22): Back pressed while the app is
  still checking the password cancels and sends nothing; once the delete request is on its way,
  Back is blocked, so leaving never looks like cancelling. The router asks the deletion whichever
  way its screen is left (`GoRoute.onExit`, `AccountDeletionController.leave`); Cancel does the
  same; the sign-out rules for an answer that deleted or may have deleted are unchanged. The
  branch's checks found three gaps, all closed there. Another account, signed in meanwhile in
  another tab, could start its own deletion while the earlier request was on its way: the earlier
  answer then let Back leave while the later request was out, and during the later deletion's
  password check neither Back nor Cancel could stop it, so it was sent. That account's Delete now
  waits for the earlier answer, as Cancel does, and the deletion counts the requests on their way as
  a defence. And another section, which cancels as Back does but keeps the screen in its own, now
  finds it no longer busy, saying the deletion was cancelled and nothing was sent. `app_test.dart`
  ("deleting the account") and `account_test.dart` pin it.
- Two accounts on one device, in their words "Close sheets on account change" (D-23): a sheet left
  open while another account signs in (another tab) kept the earlier account's record on show, an
  occupant's CNIC and phone included, and its buttons and the dialogs it opened sent their requests
  with that account's token; a new tenant's warning kept "Save anyway". Every sheet, dialog and menu
  now closes when the signed-in account changes, from one listener in the app shell, and so does
  every snack bar (one may name a record); a refreshed or new session of the same account keeps
  them. `app_test.dart` ("when the signed-in account changes") pins it, two routes on one navigator
  included.

### Closed on 15 November 2026

The portfolio prune that knew a portfolio only from a saved list (P9: a portfolio joined on
another device, opened here by its link and left before this device loads the list again). Saved
entries now name their portfolio, the owner's decision (D-21); the privacy page keeps its plain
sentence (the copy goes "the next time it loads your list of portfolios").

### Closed in e853378

Checked in the code: `packages/mm_ui/LICENSE` and `packages/mm_core/LICENSE` hold the MIT
licence; `MmLicenses.register()` and a licence page in Settings, About; `Receivable.fromRow`
reads an unreadable phone as null (`row.dialablePhone`); `Validators.name` counts code points
(`core/validation.dart`); Urdu times name the part of the day instead of "AM/PM"
(`core/dates.dart`); text fields follow the direction of what is typed
(`MmSemantics.firstStrongDirection` in `mm_text_input.dart`), which also fixes an Urdu reminder
typed in the English app; document thumbnails (`DocumentRepository.thumbnailLinks`); the
destructive-button rule in `DESIGN.md`; sheet titles as user text (`mm_sheet.dart`);
`MmDetailRow.prose`; `MmIconSize`, `MmSize.preview`, `MmIcons.receiptText`,
`MmBarArrangement`, `MmSegmentTone.overdueOlder`, `MmButtonVariant.link` and
`destructiveOutlined`, the confirm dialog's `cancelLabel`; the arrear badge's exception to the
no-break amount rule in `DESIGN.md`. As the commit records: the `MmListTile`, `MmReflow`,
`firstStrongDirection` isolate, 200% Urdu badge and seal, and Nastaliq spacing items.

## Deployed

- Edge Functions `health`, `invite-member`, `delete-account` and `storage-cleanup` are version
  20 on the hosted project (`list_edge_functions`, read by the agent on 2026-11-22), active,
  verify_jwt off as in config.toml: release 1.4.2's Deploy run uploaded them from the tag with
  the Supabase CLI at 05:47 UTC that day, as every release since 1.0.0 (2026-11-09) has.
- They were first deployed on 2026-11-05, from commit b41771d through the Supabase connector
  (version 1). A byte-for-byte comparison with the repository matched then, except one line of
  `invite-member/email.ts` where three `\u` escapes in a regular expression arrived as the
  literal characters (same behaviour); the CLI uploads take the files as they are. Live checks
  that day: health 200; the other three refused unauthenticated calls with 401 and allowed the
  app's origin.

## Hosting

- Vercel team `ar27111994s-projects`: project `maalik-e-makaan` (the web app) and
  `maalik-e-makaan-site` (the website), both deployed by CI. Previews require a Vercel login;
  production is public.
- Domains (D-20, added 2026-11-13 through the Vercel connector): `mmakaan.app` and
  `www.mmakaan.app` (308 to the apex) on `maalik-e-makaan-site`, `app.mmakaan.app` on
  `maalik-e-makaan`; each project keeps its `vercel.app` address, which sends people on since
  release 1.3.0, which carries D-20, was deployed (2026-11-15). The DNS at Dynadot points at
  Vercel since 2026-11-13
  (the owner: Vercel reports the three hosts as correctly configured); `docs/operations.md`,
  Domains, has the records.

## Completed Phases

- Phase 1, Foundations:
  - `mm_core`: money, PKT dates, CNIC/phone/IBAN identity, rent maths and late fees, with shared
    contract vectors;
  - repository tooling.
- Phase 2, Database. Twenty-two committed migrations:
  - identity and portfolios;
  - properties, units and tenants;
  - leases;
  - the ledger;
  - operations;
  - documents and storage;
  - notifications and audit;
  - reports;
  - jobs and API guards;
  - hardening from the formal models and reviews (ledger and jobs, deletion and storage, lock
    order, lease delete guard, police registration rules, ledger findings, invitation
    findings, identity checks).

  Also delivered:
  - 20 committed pgTAP suites (904 tests; all pass on the local PostgreSQL 16, 2026-11-08);
  - the concurrency and stress harnesses: 271 payments/s, dashboard 61 ms with 300 leases;
  - the demo seed;
  - schema-fingerprint drift detection.

- Phase 3, Edge Functions: `delete-account`, `invite-member`, `health` and `storage-cleanup`, at
  100% line, branch and function coverage, plus end-to-end tests for the local stack.
- Phase 4, Design System: tokens, icon font, themes, the component families and the gallery;
  final design QA PASS WITH NOTES (`docs/design-qa.md`).
- Phases 5–9, the app: see Current Position.

## Session Notes

2026-11-08:

- Documentation follow-ups: the document upload contract, retry rules, status-only commands and
  the list-ordering question in `docs/architecture/app.md`; accountants' stranded files in
  `docs/architecture/permissions.md`; `THIRD_PARTY_NOTICES.md` (direct dependencies of every
  part, copyleft scan of every lockfile, fonts).

2026-11-04 and 2026-11-05:

- Formal models (TLA+, Bend) found real races; migrations `ledger_jobs_hardening` and
  `membership_deletion_storage` fixed them, each proven by a concurrency scenario that fails on
  the old code. Highlights: the daily jobs claim work with SKIP LOCKED; account deletion freezes
  the account and retries its lock-and-delete on deadlock; portfolio ids are single-use;
  invitations carry the inviter's authority; documents cannot point at missing or doomed files;
  the storage cleanup queue is durable and fair.
- The Supabase connector asks the owner to confirm destructive SQL; `ALTER POLICY` instead of
  drop-and-create avoids the prompt when the change allows it.

2026-11-03:

- Kicked off the project. The user confirmed: a new Supabase project, Flutter plus Astro, and
  Vercel hosting. Research briefs are archived in `.planning/research/`.
- Applied the migration chain to the hosted project. The fingerprint diff found two problems:
  - The API roles held PostgreSQL 17's MAINTAIN privilege, which came from the platform's default
    grants. Migration `revoke_api_maintain_privilege` fixed it, and pgTAP now checks raw ACLs.
  - One function body had a whitespace-only transcription difference. It was repaired by
    re-running its exact definition.
- `get_deposit_position` became SECURITY INVOKER (migration `deposit_position_invoker`).
