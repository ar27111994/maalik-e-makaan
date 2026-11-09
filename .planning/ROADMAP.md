# Roadmap: Milestone v1.0

Each phase is independently verifiable, and every plan inside a phase is one atomic, conventional
commit. Phases run in order, except where a dependency allows overlap.

## Phase 1: Foundations

Monorepo layout and tooling (Dart pub workspace, lint, format, commit conventions), the GSD
planning artifacts, and the pure-Dart domain package `mm_core`: money, dates and tax year,
identity validators, sanitisation, rent maths and allocation. 100% unit coverage. (Payment
scores and insight rules were built in the app's insights feature in Phase 9 instead.)
Requirements: NFR-05 (sanitisation), NFR-07 (partial), foundations for LEDGER-03/04/07, INS-03/04.
Dependencies: none.

## Phase 2: Database

Supabase migrations:

- schemas and grants;
- identity, portfolios and roles;
- properties, units, tenants and leases;
- the ledger (charges, payments, allocations, deposits, receipts, withholding, cash handovers);
- expenses, utilities, maintenance and documents (storage);
- notifications, audit, rate limiting, jobs (pg_cron) and report RPCs.

Also: seed data; the pgTAP suites (schema, RLS matrix, RPCs, concurrency, stress); applying the
migrations to the hosted project; running the advisors.
Requirements: TEAM-_, PROP-_, TEN-_, LEASE-_, LEDGER-_, EXP-01, UTIL-_, MAINT-01, DOC-01,
REM-03, INS-01/02/05, RPT-01 (data), SRCH-01, NFR-05/06.
Dependencies: Phase 1.

## Phase 3: Edge Functions

Deno functions on the `@supabase/server` SDK:

- `delete-account`;
- `invite-member`, which e-mails the invitation through the Resend HTTP API when
  `RESEND_API_KEY` and `MAIL_FROM` are set (Edge Functions cannot open SMTP ports; Auth's own
  SMTP settings are separate), and always returns the link for sharing;
- `health`;
- shared utilities: CORS, constant-time comparison, validation, rate limits, error envelopes.

Every function has Deno unit tests.
Requirements: AUTH-03, TEAM-03, NFR-05.
Dependencies: Phase 2.

## Phase 4: Design System

`mm_ui`:

- tokens (colour, type, spacing, radius, elevation, motion);
- light, dark and high-contrast themes for LTR and RTL;
- Latin and Nastaliq typography;
- components: buttons, fields, cards, list tiles, chips, badges, money text, stat tiles, charts
  wrappers, empty, error and loading states, sheets, dialogs, snackbars, navigation scaffolds;
- the gallery app and golden tests (light, dark, RTL, 200% text);
- a11y guideline tests.

Requirements: NFR-01/02/03.
Dependencies: Phase 1.

## Phase 5: App Core

Configuration through dart-define, plus:

- Supabase bootstrap;
- the auth flows;
- the go_router shell with adaptive navigation;
- l10n (English and Urdu);
- Riverpod architecture and the repository layer with error mapping;
- stale-while-revalidate cache;
- the settings screen (language, theme, account deletion).

Requirements: AUTH-*, NFR-03/04/06.
Dependencies: Phases 2–4.

## Phase 6: Portfolio Features

Portfolios and team (invites and roles), properties and units, tenants, and leases (agreement,
police registration, occupants, rent changes, end lease), with documents attached throughout.
Requirements: TEAM-_, PROP-_, TEN-_, LEASE-_, DOC-*.
Dependencies: Phase 5.

## Phase 7: Money Features

- Ledger: dues, payments, receipts PDF, deposits, withholding, cash handovers, tenant
  statement PDF.
- Reminders: WhatsApp composer and etiquette guard.
- Notification centre.
  Requirements: LEDGER-_, REM-_.
  Dependencies: Phase 6.

## Phase 8: Operations Features

Expenses, utilities (connections, bills, readings, recharge to the tenant) and maintenance.
Requirements: EXP-01, UTIL-*, MAINT-01.
Dependencies: Phase 6.

## Phase 9: Insights & Reports

Dashboard, insight cards, payment scores, cash-flow and property performance, the tax-year
statement, the owner statement, CSV exports and global search.
Requirements: INS-_, RPT-_, SRCH-01.
Dependencies: Phases 7–8.

## Phase 10: Website

The Astro bilingual site:

- guides and calculators;
- SEO/AI-SEO artefacts;
- Playwright e2e and axe a11y tests, and Lighthouse budgets;
- Vercel configuration.
  Requirements: WEB-*.
  Dependencies: Phase 1 (content); Phase 4 (brand tokens).

## Phase 11: CI/CD & Governance

GitHub Actions:

- quality, test and coverage gates;
- DB tests on the Supabase CLI stack;
- edge-function tests;
- website tests;
- security: CodeQL, gitleaks, OSV-Scanner, dependency review;
- Dependabot;
- conventional PR titles;
- release-please;
- build artefacts (APK, AAB, web);
- deploys (Vercel, Supabase).

Plus templates, CODEOWNERS and SECURITY.md.
Requirements: NFR-07/08.
Dependencies: all build targets exist.

## Phase 12: Documentation, UAT & Release Readiness

README, architecture docs and ADRs, runbooks, AGENTS.md/llms.txt modular context, browser-driven
UAT with screenshots, a release-readiness audit, and CI green.
Requirements: all (verification).
Dependencies: Phases 1–11.
