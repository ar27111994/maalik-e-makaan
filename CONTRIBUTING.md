# Contributing

Thank you for helping landlords and tenants in Pakistan. This guide covers the
local setup, the conventions and what a pull request needs.

## Set up

You need Flutter 3.47 (Dart 3.13), Deno 2.9, Node 22, Python 3.12+, and, for the
database suites, PostgreSQL 16 with pgTAP (or the Supabase CLI and Docker).

```sh
make bootstrap   # pub, npm and deno dependencies; installs the git hooks
make help        # every target, with a one-line description
```

## Before you push

```sh
make format-check analyze
make test          # tooling, Dart packages, app, database and Edge Functions
make test-db-concurrency
```

CI runs the same targets, so a green `make` means a green pull request.

## Conventions

- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org)
  with a scope from `commitlint.config.mjs`, for example `fix(db): …`. The
  git hook checks each message. Pull requests are squash-merged, so the title
  follows the same rule.
- **Database changes** are new migrations, never edits to applied ones. Add
  pgTAP tests, and a concurrency scenario when rows can be written in parallel.
  Take locks in the global order (account, then portfolio, then lease, then
  other rows).
- **Money** is whole paisa in integers, never floating point. The rent maths is
  shared with SQL through `contracts/rent_math_vectors.json`.
- **Text** shown to people exists in English and Urdu, and screens work right to
  left. Components come from the design system (`packages/mm_ui`, see
  `DESIGN.md`).
- **Accessibility**: WCAG 2.2 AA. Check with a screen reader, at 200% text and
  with keyboard only.
- **Privacy**: never put real people's names, CNICs, phone numbers or documents
  in code, tests, fixtures, logs or screenshots.

## Reporting problems

Use the issue forms. Report security problems privately (see `SECURITY.md`).
