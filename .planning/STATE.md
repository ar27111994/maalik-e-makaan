---
active_phase: "12"
next_action: execute-phase
next_phases: ["10", "11", "12"]
progress: { total_phases: 12, completed_phases: 9, percent: 75 }
---

# Project State: Maalik-e-Makaan

## Current Position (2026-11-08)

- Milestone v1.0, at commit 02050c1 on `claude/exciting-cray-2wue0f`. Phases 1–9 are built and
  tested; `REQUIREMENTS.md` ticks each requirement and says what remains of the six that are not
  finished (TEAM-05, WEB-01, NFR-03, NFR-04, NFR-07, NFR-08).
- Phase 4 (Design System): `mm_ui` passed its final design QA with notes (2e791e4: 2,494 tests,
  100% line coverage). The gaps the app's feature reviews found in it are listed under
  [Follow-ups](#follow-ups).
- Phases 5–9 (the app): sign-in, first portfolio, shell and settings (fa5b6e5); team,
  properties, units, tenants and tenancies (b555c43); documents, money, operations, dashboard,
  reports and search (02050c1). At 02050c1: 1,652 tests in 87 files, 98.7% line coverage,
  analyzer and design lint clean, release web build passing. Every feature group was reviewed
  independently for code and data and for design, and each finding was fixed or answered.
- Phase 10 (Website): built and deployed by CI (663331c, 0fb84fc, 682ceb3). Open before launch:
  a lawyer on privacy and terms, the official legal texts, a native Urdu editor.
- Phase 11 (CI/CD): CI, Security, Scorecard, PR-title, Release and Deploy workflows are
  committed, including the formal-verification job (3139ca4) and the web deploys (c1013b8,
  682ceb3). The first production Deploy run has not happened (see Blockers).
- Phase 12 (Documentation, UAT and release readiness) is next. The architecture docs
  (`docs/architecture/app.md`, `permissions.md`) and the third-party licence inventory
  (`THIRD_PARTY_NOTICES.md`) are current.
- In the working tree, not committed: a database stage adding identity CHECK constraints
  (`20261108200216_identity_checks.sql` and `…163641_identity_checks_validate.sql`, pgTAP suites
  19 and 20, `contracts/identity_vectors.json`) and further `mm_ui` changes.
- Formal verification: TLA+ models (Invitations, Membership, StorageCleanup, LedgerPayments,
  LateFees, RateLimit), Lean 4 and Z3 money proofs and the Bend proofs run with `make verify`
  and in CI.

## Active Decisions

- PROJECT.md D-01…D-15 record the decisions. The ones that carry most weight:
  - D-04: RLS plus composite foreign keys;
  - D-05: exact money;
  - D-06/07: the ledger and idempotent payments;
  - D-10: no tax estimate;
  - D-13: the Data API is opt-in;
  - D-14: the hosted migration history names the migrations;
  - D-15: write RPCs are SECURITY DEFINER behind a pgTAP allowlist.
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
- Twenty migrations, the latest `20261108082804_invitation_findings`, according to the commits
  that applied them (764e640, c1c0d7a, 13c5d18, f155413, 67639d8), each of which records a
  matching schema fingerprint. Not re-checked on 2026-11-08 (this stage did not touch the hosted
  project). The two identity-check migrations in the working tree are not applied.
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
- Docker image pulls are blocked in the agent container, so `supabase start` only runs in CI,
  and there is no local PostgREST to check the app's requests against.
- `*.supabase.co` and `supabase.com` are blocked from the container. Use the Supabase MCP tools
  for the hosted project; `search_docs` reads the documentation.
- `git ls-remote` against GitHub works, which is how GitHub Actions get pinned to commit SHAs.
- `tool/formal/install.sh` installs the pinned formal toolchain (TLC, Lean 4.35.0 and 4.34.0,
  z3-solver, Bend) into `.cache/formal`, checking every checksum.
- The GitHub MCP tools can read workflow runs and job logs (`actions_list`, `get_job_logs`).
- There is no Xcode here: iOS changes (for example the `InfoPlist.strings` localisations in
  02050c1) are unbuilt until CI or a Mac builds them.

## Blockers (need the owner)

- The first production run of the Deploy workflow: it must be on the default branch to be run by
  hand (or a release published). It deploys the web app to Vercel (`web` job, needs
  `VERCEL_TOKEN`, set) and redeploys the Edge Functions so they send the database's Retry-After
  (`admin_rate_limit_hit`, 20261107181820); until then the hosted functions use the deprecated
  `admin_hit_rate_limit`, which still works.
- Google Play: the organisation account waits for its D-U-N-S number. Once the app is on Play,
  add the Play app-signing key's SHA-256 to `app/web/.well-known/assetlinks.json`, and link the
  listing from the website.
- A native Urdu speaker to review the app's and the website's Urdu, including the date picker's
  day names and one glossary shared by the app and the site.
- A lawyer to review the privacy policy and the terms (website and app) before launch.
- The official legal texts (`.gov.pk`) behind the guides could not be reached from here; the
  guides word every unconfirmed point as unconfirmed until someone checks them.
- Custom SMTP for Supabase Auth e-mails before launch (`REQUIREMENTS.md`, Open Questions).
- Done by the owner on 2026-11-07: the Vault secret `mm_storage_cleanup_token` (checked: a
  cleanup call with it answers 200), the GitHub secret `VERCEL_TOKEN` and the upload key's
  SHA-256 fingerprint for Android App Links.
- Done by the owner on 2026-11-05: the Edge Function secrets (`APP_URL`, `STORAGE_CLEANUP_TOKEN`,
  `RESEND_API_KEY`, `MAIL_FROM`), Supabase Auth's Site URL and redirect
  (`https://maalik-e-makaan.vercel.app/auth/callback`), and the GitHub secrets, variables and
  `production`/`release` environments the Deploy and Release workflows read.

## Follow-ups

Collected from the feature reviews of 02050c1 and from this documentation stage. None blocks the
code that is committed; each needs the owner of the area named.

### Licences

- `packages/mm_ui/LICENSE` is Flutter's placeholder ("TODO: Add your license here."), which
  Flutter copies into the app's `NOTICES`; `packages/mm_core` has no licence file.
- The app shows no licences page, and the fonts' OFL texts and the Lucide notice are not in the
  build's `NOTICES`: register them with `LicenseRegistry.addLicense` and add an entry in
  Settings. `MmIcons.ttf` has empty copyright fields.
- dbus 0.8.0 (MPL-2.0, Linux desktop only, unmodified): a distributed Linux build must say where
  its source is. See `THIRD_PARTY_NOTICES.md`.

### App

- Decide list ordering for maintenance (priority) and expenses (date); see Active Decisions.
- Check every REST request, including the foreign-key embed names such as
  `utility_bills_charge_id_fkey`, against a running PostgREST before release (NFR-07).
- Strict phone parsing: `Receivable.fromRow` (`ledger/data/ledger.dart`) still fails a whole read
  on a phone the database accepts but `mm_core` rejects (`Arrear` now reads it as null). The
  identity CHECK constraints in the working tree would close this at the database once
  applied.
- `Validators.name` counts characters, not code points, outside documents; names are not
  bidi-isolated inside some messages.
- The Latin "AM/PM" in Urdu times (`momentLabel`, `core/dates.dart`).
- Typing an Urdu reminder while the app is in English shows it left to right.
- A ten-year Urdu statement PDF is about 6.8 MB; Urdu PDF rows are a few points out of line,
  and Latin names in them come out small and grey. PDFs have no automated image golden.
- No thumbnails in the document list or sheet (would need a signed link per row).
- iOS: the localised permission prompts are unbuilt; the web compression timing is unmeasured on
  a real phone.
- The audit trail has no screen (TEAM-05).
- Delete buttons are filled red in every sheet; a rule for destructive buttons belongs in
  `DESIGN.md`.

### Design system (`mm_ui`)

- `MmTextField` should follow its text's own direction (Urdu fields lay English out right to
  left).
- `MmModalSheet`/sheet headers need a user-text (Latin face) title option; the team member
  sheet has the same defect.
- `MmListTile`: hold UI text, allow an unlimited subtitle, keep a plain chevron on the title
  line, and more space between title and subtitle in Urdu.
- `MmDetailRow` needs a prose variant (the app composes `core/prose_row.dart` for now).
- `MmReflow` should count the subtitle's narrowest width; `MmSemantics.firstStrongDirection`
  should skip isolated runs; the receipt seal and badges need a way to fit an amount at 200%
  Urdu; spaces between Nastaliq words and Latin names look collapsed.
- Export the icon-size helper; add a preview-size token, a currency-free receipt icon, a
  side-by-side bar series, a fourth overdue tone for `MmProportionBar`, an inline text-link
  button, and a cancel-label option for the confirm dialog.
- Write the arrear badge's exception to the no-break amount rule into `DESIGN.md`.

## Deployed

- Edge Functions `health`, `invite-member`, `delete-account` and `storage-cleanup` are version 1
  on the hosted project (deployed 2026-11-05 from commit b41771d through the Supabase connector,
  verify_jwt off as in config.toml). A byte-for-byte comparison with the repository matches,
  except one line of `invite-member/email.ts` where three `\u` escapes in a regular expression
  arrived as the literal characters (same behaviour); the Deploy workflow's CLI upload restores
  exact parity at the first release. Live checks: health 200; the other three refuse
  unauthenticated calls with 401 and allow the app's origin.

## Hosting

- Vercel team `ar27111994s-projects`: project `maalik-e-makaan` (web app, production address
  `maalik-e-makaan.vercel.app`, a placeholder page until the first web release) and
  `maalik-e-makaan-site` (the website, deployed by CI). Previews require a Vercel login;
  production is public.

## Completed Phases

- Phase 1, Foundations:
  - `mm_core`: money, PKT dates, CNIC/phone/IBAN identity, rent maths and late fees, with shared
    contract vectors;
  - repository tooling.
- Phase 2, Database. Twenty committed migrations:
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
    findings).

  Also delivered:
  - 18 committed pgTAP suites (707 planned tests);
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
