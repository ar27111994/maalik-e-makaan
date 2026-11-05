# Maalik-e-Makaan (مالکِ مکان)

[![CI](https://github.com/ar27111994/maalik-e-makaan/actions/workflows/ci.yml/badge.svg)](https://github.com/ar27111994/maalik-e-makaan/actions/workflows/ci.yml)
[![Security](https://github.com/ar27111994/maalik-e-makaan/actions/workflows/security.yml/badge.svg)](https://github.com/ar27111994/maalik-e-makaan/actions/workflows/security.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/ar27111994/maalik-e-makaan/badge)](https://scorecard.dev/viewer/?uri=github.com/ar27111994/maalik-e-makaan)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

Tenant and property management for **Pakistani landlords**, in English and Urdu. It replaces
registers, spreadsheets and WhatsApp threads with one trustworthy ledger, and handles the work
that global tools ignore:

- cash-first rent collection with numbered, bilingual receipts;
- dues that generate themselves, late fees, deposits and an overdue list;
- caretakers and relatives who collect on behalf of an overseas owner, with an audit trail;
- police tenant registration, rent-agreement and utility tracking;
- July–June tax-year statements, including tax withheld by company tenants;
- reminders over WhatsApp, in English, Urdu or Roman Urdu.

> **Status:** in active development towards v1.0. The database, Edge Functions, the domain
> library, the design-system foundations, the app core and CI/CD are in place. The app's
> screens are being built now. See [`.planning/STATE.md`](.planning/STATE.md) for the current
> position and [`.planning/ROADMAP.md`](.planning/ROADMAP.md) for the plan.

## How it is built

| Part             | Where                   | What                                                                                                                                |
| ---------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| App              | `app/`                  | Flutter 3.47 for Android, iOS and the web. Riverpod 3, go_router 18, English and Urdu (right to left).                              |
| Domain library   | `packages/mm_core/`     | Pure Dart: exact money in paisa, rent and late-fee maths, Pakistan time, CNIC, phone and IBAN checks.                               |
| Design system    | `packages/mm_ui/`       | Tokens, themes (light, dark, high contrast), icons and accessible components. See [`DESIGN.md`](DESIGN.md).                         |
| Database         | `supabase/migrations`   | Postgres 17 on Supabase: row-level security on every table, a ledger with idempotent payments and gapless receipts, scheduled jobs. |
| Edge Functions   | `supabase/functions`    | Deno 2: account deletion, invitations, health checks and storage clean-up.                                                          |
| Formal models    | `formal/` (being added) | TLA+ models of the concurrent paths; Lean 4, Bend and Z3 proofs of the money arithmetic.                                            |
| Shared contracts | `contracts/`            | Test vectors that keep Dart, SQL and TypeScript in agreement (rent maths, text cleaning).                                           |

Key decisions are recorded in [`.planning/PROJECT.md`](.planning/PROJECT.md):

- authorisation lives in Postgres;
- money is exact (never floating point);
- financial rows are voided, never deleted;
- secret keys never reach a client.

## Getting started

You need Flutter 3.47 (Dart 3.13), Deno 2.9, Node 22 and Python 3.12 or later. For the database
suites you also need PostgreSQL 16 with pgTAP, or the Supabase CLI with Docker.

```sh
make bootstrap   # dependencies and git hooks
make help        # every target, with a description
make test        # tooling, Dart packages, app, database and Edge Functions
```

To run the app against a local Supabase stack:

```sh
supabase start
cp app/config/local.example.json app/config/local.json   # paste the publishable key
cd app && flutter run --dart-define-from-file=config/local.json
```

[`docs/operations.md`](docs/operations.md) covers scheduled jobs, secrets, health checks and
deployment.

## Quality

Every change runs through CI ([`ci.yml`](.github/workflows/ci.yml)):

- formatting and linting for every language in the repository (Dart, TypeScript, Python, shell,
  SQL migrations, workflows, Markdown), and the design lint that keeps UI code on its tokens;
- analysis and tests for each Dart package, with coverage gates (100% for `mm_core`);
- Edge Function tests at 100% line, branch and function coverage;
- the pgTAP suites and the concurrency scenarios on PostgreSQL, and again on the real Supabase
  stack;
- release builds for the web and Android.

Security checks ([`security.yml`](.github/workflows/security.yml)) run CodeQL, gitleaks over the
whole history, OSV-Scanner, dependency review and zizmor. Every action is pinned to a commit.

## Contributing and security

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request. Report vulnerabilities
privately, as [`SECURITY.md`](SECURITY.md) explains.

## Licence

[MIT](LICENSE) © 2026 Ahmed Rehan
