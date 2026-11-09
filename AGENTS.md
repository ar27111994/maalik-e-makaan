# AGENTS.md

Maalik-e-Makaan (مالکِ مکان) is tenant and property management for Pakistani landlords, in
English and Urdu: a Flutter app on a Supabase backend, an Astro website, and formal models of
the money and concurrency code. This file is the entry point for coding agents. It is short on
purpose: read the file for the area you are changing, not everything.

## Layout

| Path                | What it is                                                     | Read next                                                    |
| ------------------- | -------------------------------------------------------------- | ------------------------------------------------------------ |
| `app/`              | Flutter app (Android, iOS, web), Riverpod 3, go_router         | [`app/AGENTS.md`](app/AGENTS.md)                             |
| `packages/mm_ui/`   | Design system: tokens, themes, icons, components, gallery      | [`packages/mm_ui/AGENTS.md`](packages/mm_ui/AGENTS.md)       |
| `packages/mm_core/` | Pure-Dart domain: money in paisa, dates, identity, rent maths  | [`packages/mm_core/AGENTS.md`](packages/mm_core/AGENTS.md)   |
| `supabase/`         | Migrations, pgTAP suites, Deno Edge Functions, `config.toml`   | [`supabase/AGENTS.md`](supabase/AGENTS.md)                   |
| `website/`          | Astro static site, English and Urdu                            | [`website/AGENTS.md`](website/AGENTS.md)                     |
| `formal/`           | TLA+, Lean 4, Z3 and Bend models and proofs                    | [`formal/AGENTS.md`](formal/AGENTS.md)                       |
| `contracts/`        | Test vectors shared by Dart, SQL and TypeScript                | [`docs/agents/conventions.md`](docs/agents/conventions.md)   |
| `design/`           | Design-token and icon sources (`make tokens`, `make icons`)    | [`packages/mm_ui/AGENTS.md`](packages/mm_ui/AGENTS.md)       |
| `tool/`             | Repository tooling (db, design, coverage, formal, web, guards) | [`docs/agents/commands.md`](docs/agents/commands.md)         |
| `docs/`             | Architecture, operations runbook, permissions, design QA       | [`docs/README.md`](docs/README.md)                           |
| `.planning/`        | Project decisions, requirements, roadmap, current state        | [`.planning/STATE.md`](.planning/STATE.md)                   |
| `.github/`          | CI, Security, Release, Deploy workflows; issue and PR forms    | [`docs/agents/commands.md`](docs/agents/commands.md#ci-jobs) |

## Commands

Every check is a `make` target, and CI runs the same targets. `make help` lists them all;
[`docs/agents/commands.md`](docs/agents/commands.md) maps each to its area, prerequisites and CI job.

```sh
make bootstrap                       # pub, npm (installs the git hooks), deno, Python tools in .venv
make format-check-repo lint          # docs, shell, Python, workflows, migrations, design lint, Unicode guard
make format-check analyze            # adds Dart and Deno formatting and every analyzer
make test                            # tooling, mm_core, mm_ui, gallery, app, database, Edge Functions
make test-uat                        # browser UAT on a local Supabase stack (docs/uat.md)
```

Toolchain on the path: `export PATH=/opt/flutter/bin:$PWD/.venv/bin:$PATH` (see
[`.planning/STATE.md`](.planning/STATE.md), Environment Notes, for the local PostgreSQL 16 on
port 54329 and what this container cannot reach).

## Rules that apply everywhere

- **Commits**: Conventional Commits with a scope from `commitlint.config.mjs`: `app`, `core`,
  `ui`, `db`, `functions`, `web`, `ci`, `deps`, `deps-dev`, `docs`, `formal`, `planning`,
  `release`, `repo`, `security`, `test`. Body lines at most 100 characters. Pull requests are
  squash-merged, so the title follows the same rule.
- **British English** in prose, comments and UI text (`licence`, `colour`, `organisation`);
  identifiers follow their framework (`MmColorModes`, `MmLicenses`). Every user-facing string
  exists in English and Urdu.
- **No secrets, no real people.** Clients take only the publishable key (`AppConfig` refuses a
  secret key). No real names, CNICs, phone numbers or documents in code, tests, logs or
  screenshots.
- **Money is whole paisa in integers** (`Money` in `mm_core`), `numeric(14,2)` in SQL. Never a
  floating-point type. Financial rows are voided, never deleted.
- **Lock order**: account, then portfolio, then lease, then other rows. Every write path keeps it.
- **Migrations**: always a new file, never an edit to one in `supabase/migrations/`. The hosted
  project (`aaifamxzzjspohwksxyr`) is changed only by the process in
  [`docs/operations.md`](docs/operations.md#after-every-migration).
- **Design lint**: UI code takes colours, type, spacing, radii and motion from tokens and uses
  directional geometry (`make design-lint`).
- **Unicode guard**: no bidi controls, invisible or control characters in tracked files
  (`tool/check_unicode.py`, `contracts/clean_text.json`).
- **Goldens**: re-record with `make goldens` only on Linux, and look at every changed image
  before committing it.
- **Generated files** are rebuilt, not edited: see
  [`docs/agents/conventions.md`](docs/agents/conventions.md#generated-files).

The full list, with the reasons, is [`docs/agents/conventions.md`](docs/agents/conventions.md);
how to do common tasks is [`docs/agents/workflows.md`](docs/agents/workflows.md).
