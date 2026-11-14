---
active_phase: "12"
next_action: execute-phase
next_phases: ["10", "11", "12"]
progress: { total_phases: 12, completed_phases: 9, percent: 75 }
---

# Project State: Maalik-e-Makaan

## Current Position (2026-11-14)

- D-20 (the owner, 2026-11-13): the company bought `mmakaan.app` (Dynadot). The website moves to
  `https://mmakaan.app` (`www` redirects to it) and the web app to `https://app.mmakaan.app`;
  the `vercel.app` addresses send people on for good. Pull request #74, in no release yet:
  `contracts/origins.json` as the one source of the origins (the website's
  defaults, the deck, the workflows' `APP_URL` and the page the web app's old address answers
  with read it; the Android manifest's hosts and `website/vercel.json`'s redirect are checked
  against it, and every other address by `make docs-check` C17); the website's old address
  redirects (`website/vercel.json`); the web app's old address answers every page with one that
  clears what the app kept in the browser there (`Clear-Site-Data: "storage"`, and a script for
  browsers without the header) and goes to the same address on the new one, while it keeps
  serving `assetlinks.json` and, until the next release, `/auth/callback`, neither of which
  clears anything; App Links on both hosts; `redirect_smoke_test.sh` in CI and after each
  deploy. Before building or deploying, Release and Deploy check that the new addresses answer
  (`tool/web/check_live.py`), that Auth allows every build's e-mail links
  (`tool/web/check_auth_urls.py`) and that the website goes out only after the web app it links
  to. The web app answers `X-Robots-Tag: noindex`.
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
  release, because nobody uses the app yet (the owner, 2026-11-14). Next: merge and release
  before then, then Auth's Site URL, then delete the
  `APP_URL` repository variable. Open for the owner: whether the company's website in the
  structured data becomes the new domain (step 10), and uptime monitors for the new addresses.
- The company's mailbox is `hello@mmakaan.app`, on Dynadot's own e-mail (free plan), not Zoho
  (the owner, 2026-11-13); a test message to Gmail passed SPF and DKIM for `mmakaan.app`, and the
  `_dmarc` record (`p=none`) was being added. The website, both privacy pages, `llms.txt` and the
  deck give it as the contact address in place of the Resend sending address, from which Auth's
  e-mails and the invitations are still sent. It is the one mailbox on the domain that
  `make docs-check` allows (`NAMED_MAILBOXES`).
- The amount reader's work items 1, 3 and 4 (`docs/roadmap/amount-parser.md`), merged in #75 and
  in no release yet: `contracts/amount_lexicon.json` (version 1,
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

- PROJECT.md D-01…D-20 record the decisions, and P-01 and P-02 the open proposals. The ones that
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
    once, in `contracts/origins.json`, and carried by each release tag.
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
- Twenty-three migrations applied, the latest `20261109081109_uat_display_fixes`, according
  to the commits that applied them (764e640, c1c0d7a, 13c5d18, f155413, 67639d8, e853378 and the
  Phase 12 release-readiness commit), each of which records a matching schema fingerprint
  (20261109081109: 1,185 objects, `fa5a29f9984e169a032725898e5b93b2`).
- `20261112092618_residence.sql` is **not applied** to the hosted project yet. The next release
  the owner approves applies it (the Deploy workflow's `supabase db push`), and then come "After
  every migration" in `docs/operations.md` and `tool/db/time_zone_skew.sql` on the hosted project.
  The pitch deck's trust slide (`website/deck/slides/trust.html`, slide and speaker notes) now says
  23 reviewed write functions and 23 database suites: the deck is rendered from the release tag,
  the same release that applies the migration.
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
- Advisors (2026-11-03):
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
  hosting and its mailbox, `hello@mmakaan.app`, exists (both 2026-11-13). Waiting on the owner:
  the merge of the move's pull request and the release, before Wednesday 2026-11-18, then the
  steps after it (`docs/release-readiness.md`, Owner actions, item 13). Apple enrols an
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
- The first production run of the Deploy workflow: it must be on the default branch to be run by
  hand (or a release published). It deploys the web app to Vercel (`web` job, needs
  `VERCEL_TOKEN`, set) and redeploys the Edge Functions so they send the database's Retry-After
  (`admin_rate_limit_hit`, 20261107181820); until then the hosted functions use the deprecated
  `admin_hit_rate_limit`, which still works.
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
  `news.ar27111994.dev` is verified (2026-11-09); its click and open tracking are off (the owner,
  reported 2026-11-12).
- Reported done by the owner on 2026-11-09 (not checkable from the agent's network): the backup
  key, `RELEASE_PLEASE_TOKEN`, Supabase SMTP through Resend with the templates, and the other
  configuration in `docs/release-readiness.md`, Owner actions. Waiting: the pull request to
  `main` (then the first Backup and Deploy runs), an uptime monitor (Better Stack refused
  sign-ups; Checkly or StatusCake next), and the D-U-N-S number. On 2026-11-12 the owner reported
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
- App: a voided Urdu receipt with tax withheld, a certificate and a note still takes two A5 pages
  (it flows on rather than being cut off); the usual one is one page (UAT D8).
- Design system: the open items in `docs/design-qa.md`, Follow-ups.

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

- Edge Functions `health`, `invite-member`, `delete-account` and `storage-cleanup` are version 1
  on the hosted project (deployed 2026-11-05 from commit b41771d through the Supabase connector,
  verify_jwt off as in config.toml). A byte-for-byte comparison with the repository matches,
  except one line of `invite-member/email.ts` where three `\u` escapes in a regular expression
  arrived as the literal characters (same behaviour); the Deploy workflow's CLI upload restores
  exact parity at the first release. Live checks: health 200; the other three refuse
  unauthenticated calls with 401 and allow the app's origin.

## Hosting

- Vercel team `ar27111994s-projects`: project `maalik-e-makaan` (the web app) and
  `maalik-e-makaan-site` (the website), both deployed by CI. Previews require a Vercel login;
  production is public.
- Domains (D-20, added 2026-11-13 through the Vercel connector): `mmakaan.app` and
  `www.mmakaan.app` (308 to the apex) on `maalik-e-makaan-site`, `app.mmakaan.app` on
  `maalik-e-makaan`; each project keeps its `vercel.app` address, which sends people on once the
  release that carries D-20 is deployed. The DNS at Dynadot points at Vercel since 2026-11-13
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
