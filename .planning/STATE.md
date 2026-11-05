---
active_phase: "4"
next_action: execute-phase
next_phases: ["4", "5", "11"]
progress: { total_phases: 12, completed_phases: 3, percent: 25 }
---

# Project State: Maalik-e-Makaan

## Current Position (2026-11-05)

- Milestone v1.0. Phases 1 (Foundations), 2 (Database) and 3 (Edge Functions, code and tests)
  are complete. The functions are not deployed yet: they need secrets only the owner can enter
  (see Blockers).
- Phase 4 (Design System): tokens, icons, themes, foundations, localisation, window sizes and the
  test harness are committed. The component families (actions, inputs, choices, display, records,
  feedback, layout, charts) and the gallery are being built and reviewed.
- Phase 5 (App Core): configuration, failures, settings, auth repository, offline cache, router
  guards and the adaptive shell are committed (76 tests, 96% coverage). The auth and settings
  screens wait for the components.
- Phase 11 (CI/CD): CI, Security, Scorecard, PR-title, Release and Deploy workflows, Dependabot,
  CODEOWNERS, templates, SECURITY.md and CONTRIBUTING.md are committed. The first runs are being
  checked.
- Formal verification (requested by the user, across phases): TLA+ models of membership and
  storage cleanup, invitations, the ledger, late fees and the rate limiter; Lean 4 and Z3 proofs of
  the money arithmetic; and the Bend proofs (36 laws) are being finished against the current code,
  then wired into `make verify`.

## Active Decisions

- PROJECT.md D-01…D-15 record the decisions. The ones that carry most weight:
  - D-04: RLS plus composite foreign keys;
  - D-05: exact money;
  - D-06/07: the ledger and idempotent payments;
  - D-10: no tax estimate;
  - D-13: the Data API is opt-in;
  - D-14: the hosted migration history names the migrations;
  - D-15: write RPCs are SECURITY DEFINER behind a pgTAP allowlist.

## Hosted Supabase Project

- Ref `aaifamxzzjspohwksxyr` ("maalik-e-makaan"), org AR Labs, region ap-south-1, Postgres 17.11.
- Fifteen migrations are applied, the latest `20261105072426_membership_deletion_storage` (the
  file names in `supabase/migrations/` are the hosted versions).
- pg_cron jobs:
  - `mm-daily-jobs`: `5 19 * * *` UTC, which is 00:05 PKT;
  - `mm-rate-limit-cleanup`: hourly.
- `authenticator` has `pgrst.db_pre_request = app.check_request`.
- Drift check (2026-11-05): all 1,166 objects match the local chain, by function, relation,
  column, constraint, index, trigger, policy, enum, schema ACL and bucket.
- Advisors (2026-11-03):
  - Security: only the 20 reviewed definer RPCs (lint 0029, intentional; see D-15).
  - Performance: "unused index" INFO findings only. These are expected on an empty database, and
    the indexes are justified by foreign-key coverage and the stress test.

## Environment Notes (for future sessions)

- The Flutter SDK is at `/opt/flutter`; add `export PATH=/opt/flutter/bin:$PATH`.
- Local Postgres 16 with pgTAP and pg_cron:
  - The data directory is `/var/lib/postgresql/mm16`, on port 54329. It runs as the `postgres`
    OS user.
  - Use `tool/db/test.sh` (pgTAP), `tool/db/concurrency_test.sh` and `tool/db/stress_test.sh`.
  - `MM_TEST_DB=<name> tool/db/reset.sh [--seed]` gives you a disposable database.
- Postgres 17 is not available locally (the apt repository is blocked). Postgres 17 behaviour is
  verified against the hosted project with read-only queries, and in CI through
  `supabase test db`.
- Docker image pulls are blocked in the agent container, so `supabase start` only runs in CI.
- `*.supabase.co` and `supabase.com` are blocked from the container. Use the Supabase MCP tools
  for the hosted project; `search_docs` reads the documentation.
- `git ls-remote` against GitHub works, which is how GitHub Actions get pinned to commit SHAs.
- The session scratchpad holds the formal-verification toolchain (tla2tools, Lean 4.35.0 and
  4.34.0, z3-solver, Bend) and is lost with the container; `tool/formal/install.sh` reinstalls the
  pinned versions with checksums.
- The GitHub MCP tools can read workflow runs and job logs (`actions_list`, `get_job_logs`).

## Blockers (need the owner)

- Supabase Vault needs `mm_storage_cleanup_token` with the same value as the
  `STORAGE_CLEANUP_TOKEN` function secret (`mm_project_url` is set); until then the scheduler
  reports `not_configured` and deleted files stay queued (docs/operations.md, Storage cleanup).
- Done by the owner on 2026-11-05: the Edge Function secrets (`APP_URL`, `STORAGE_CLEANUP_TOKEN`,
  `RESEND_API_KEY`, `MAIL_FROM`), Supabase Auth's Site URL and redirect
  (`https://maalik-e-makaan.vercel.app/auth/callback`), and the GitHub secrets, variables and
  `production`/`release` environments the Deploy and Release workflows read.

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
  `maalik-e-makaan-site` (the website). Previews require a Vercel login; production is public.

## Completed Phases

- Phase 1, Foundations:
  - `mm_core`: money, PKT dates, CNIC/phone/IBAN identity, rent maths and late fees, with shared
    contract vectors;
  - repository tooling.
- Phase 2, Database. Twelve migrations at first, fifteen now:
  - identity and portfolios;
  - properties, units and tenants;
  - leases;
  - the ledger;
  - operations;
  - documents and storage;
  - notifications and audit;
  - reports;
  - jobs and API guards;
  - two hardening migrations.

  Also delivered:
  - pgTAP suites (510 tests today);
  - the concurrency and stress harnesses: 271 payments/s, dashboard 61 ms with 300 leases;
  - the demo seed;
  - schema-fingerprint drift detection.

- Phase 3, Edge Functions: `delete-account`, `invite-member`, `health` and `storage-cleanup`, with
  352 tests at 100% line, branch and function coverage, plus end-to-end tests for the local stack.

## Session Notes

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
