"""A small repository whose facts all agree, for the tests of tool/docs.

The tests never read the real repository (`make docs-check` does that in CI): each builds this
one in a temporary directory, changes a file or two, and runs a parser, a check or the command
line on it.
"""

from __future__ import annotations

from pathlib import Path

COMMITLINT = """\
// A trimmed copy of the repository's commitlint.config.mjs.
export default {
  extends: ['@commitlint/config-conventional'],
  // release-please's own commit.
  ignores: [(message) => /^chore\\(release\\): release \\d+\\.\\d+\\.\\d+/.test(message)],
  rules: {
    'type-enum': [2, 'always', ['build', 'chore', 'ci', 'docs', 'feat', 'fix', 'test']],
    'header-max-length': [2, 'always', 100],
    'scope-enum': [
      2,
      'always',
      [
        'app',
        'ci',
        'deps',
        // Dependabot's scope for development dependencies.
        'deps-dev',
        'docs',
        'repo',
      ],
    ],
    'body-max-line-length': [2, 'always', 100],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
  },
};
"""

RELEASE_PLEASE = """\
{
  "pull-request-title-pattern": "chore(release): release${component} ${version}",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug fixes" },
    { "type": "docs", "section": "Documentation" },
    { "type": "build", "section": "Build", "hidden": true },
    { "type": "chore", "section": "Maintenance", "hidden": true },
    { "type": "ci", "section": "Continuous integration", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true }
  ],
  "packages": {
    ".": {
      "extra-files": [
        { "type": "generic", "path": "app/pubspec.yaml" },
        { "type": "generic", "path": "README.md" }
      ]
    }
  }
}
"""

MAKEFILE = """\
SHELL := /usr/bin/env bash
VENV := $(CURDIR)/.venv
export PATH := $(VENV)/bin:$(PATH)

.PHONY: help
help: ## Show this help
\t@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST)

.PHONY: format
format: ## Format everything
\tblack tool

.PHONY: format-check
format-check: ## Formatting, checked
\tblack --check tool

.PHONY: lint
lint: ## Lint
\truff check tool

.PHONY: test-core
test-core: ## mm_core with its gate
\tcd packages/mm_core && dart test --coverage=coverage && \\
\t  dart run coverage:format_coverage --lcov
\tpython3 tool/coverage/check.py packages/mm_core/coverage/lcov.info --min 100

.PHONY: test-ui
test-ui: ## mm_ui with its gate
\tcd packages/mm_ui && flutter test --coverage
\tpython3 tool/coverage/check.py packages/mm_ui/coverage/lcov.info --min 95

.PHONY: test-app
test-app: ## The app with its gate
\tcd app && flutter test --coverage
\tpython3 tool/coverage/check.py app/coverage/lcov.info --min 90

.PHONY: test-db
test-db: ## pgTAP
\ttool/db/test.sh

.PHONY: test-functions
test-functions: ## Edge Functions with their gate
\tcd supabase/functions && deno task test
\tpython3 tool/coverage/check.py supabase/functions/coverage/lcov.info \\
\t  --min 100 --min-branches 100 --min-functions 100

.PHONY: test-web
test-web: ## The website
\tcd website && npm run check && npm test \\
\t  && npm run build

.PHONY: test-tools
test-tools: ## Tooling tests
\tpython3 -m unittest discover -s tool -p 'test_*.py'
\tpython3 -m unittest discover -s tool/docs -p 'test_*.py'

.PHONY: tokens
tokens: ## Rebuild the tokens
\tpython3 tool/design/build_tokens.py

.PHONY: tokens-check
tokens-check: ## Fail when the tokens are stale
\tpython3 tool/design/build_tokens.py --check

.PHONY: docs
docs: ## Rewrite the facts the docs repeat
\tpython3 tool/docs/sync_facts.py --write

.PHONY: docs-check
docs-check: ## Fail when a fact is stale
\tpython3 tool/docs/sync_facts.py --check

.PHONY: test
test: test-tools test-core test-ui ## Every fast suite
"""

CI = """\
name: CI

on:
  pull_request:

env:
  FLUTTER_VERSION: 3.47.9
  DENO_VERSION: 2.9.6
  SUPABASE_CLI_VERSION: 2.122.1
  JAVA_VERSION: "21"
  PYTHON_VERSION: "3.13"

jobs:
  hygiene:
    name: Repository hygiene
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@0000000000000000000000000000000000000000 # v1
      - name: Lint (make lint)
        run: make lint
      - name: Generated files are up to date
        run: make tokens-check docs-check

  dart:
    name: Dart · ${{ matrix.package }}
    runs-on: ubuntu-24.04
    steps:
      - uses: subosito/flutter-action@0000000000000000000000000000000000000000 # v1
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
      - name: Tests
        env:
          TARGET: ${{ matrix.target }}
        run: make "$TARGET"

  website:
    name: Website (Astro)
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: website
    steps:
      - run: npm ci
      - name: Types and lint
        run: npm run check
      - name: Unit tests
        run: npm test
      - name: Build
        run: >
          npm run build

  database:
    name: Database
    runs-on: ubuntu-24.04
    steps:
      - uses: supabase/setup-cli@0000000000000000000000000000000000000000 # v1
        with:
          version: ${{ env.SUPABASE_CLI_VERSION }}
      - name: Suites
        run: |
          # The pgTAP suites.
          make test-db
      - uses: denoland/setup-deno@0000000000000000000000000000000000000000 # v1
        with:
          deno-version: ${{ env.DENO_VERSION }}
      - uses: actions/setup-java@0000000000000000000000000000000000000000 # v1
        with:
          distribution: temurin
          java-version: ${{ env.JAVA_VERSION }}
      - uses: actions/setup-python@0000000000000000000000000000000000000000 # v1
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      - name: Install PostgreSQL 16 and pgTAP
        run: |
          sudo apt-get install -y postgresql-16 postgresql-16-pgtap
          sudo pg_ctlcluster 16 main start

  passed:
    name: CI passed
    if: always()
    needs:
      [
        hygiene,
        dart,
        website,
        database,
      ]
    runs-on: ubuntu-24.04
    steps:
      - run: echo done
"""

DEPLOY = """\
name: Deploy

env:
  # Equal to ci.yml's.
  FLUTTER_VERSION: 3.47.9
  SUPABASE_CLI_VERSION: 2.122.1

jobs:
  web:
    name: Web app
    needs: [supabase]
    steps:
      - uses: subosito/flutter-action@0000000000000000000000000000000000000000 # v1
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
  supabase:
    name: Supabase
    steps:
      - name: The CLI
        uses: supabase/setup-cli@0000000000000000000000000000000000000000 # v1
        with:
          version: ${{ env.SUPABASE_CLI_VERSION }}
  site:
    name: Website
    env:
      # npx runs the CLI from npm.
      VERCEL_CLI_VERSION: 65.8.0
    steps:
      - name: Build
        run: npx --yes "vercel@$VERCEL_CLI_VERSION" build --prod
      - name: Deploy
        run: |
          npx --yes "vercel@${VERCEL_CLI_VERSION}" deploy --prebuilt --prod
"""

PR_TITLE = """\
name: Pull request title

jobs:
  conventional-title:
    name: Conventional title
    steps:
      - uses: amannn/action-semantic-pull-request@0000000000000000000000000000000000000000 # v1
        with:
          # docs:commit-types-and-scopes from commitlint.config.mjs; generated by make docs, do not edit
          types: |
            build
            chore
            ci
            docs
            feat
            fix
            test
          scopes: |
            app
            ci
            deps
            deps-dev
            docs
            repo
          # /docs:commit-types-and-scopes
          requireScope: false
      # GitHub adds " (#123)", and commitlint checks the 100-character header.
      - name: Title fits the squash commit's 100-character header
        env:
          # commitlint's header-max-length.
          MAX_HEADER: "100"
        run: |
          [ "${#TITLE}" -le "$MAX_HEADER" ]
"""

DEPENDABOT = """\
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    commit-message:
      prefix: ci
      include: scope
  - package-ecosystem: npm
    directory: /
    commit-message:
      prefix: chore
      include: scope
"""

JOURNEYS = """\
import { test } from "@playwright/test";

test.describe("journeys", () => {
  test.beforeAll(async () => {});
  test("J1 sign up", async () => {});
  test('J2 add a property', async () => {});
  test(`J3 record a payment`, async () => {});
});
"""

PROJECT = """\
# Project

## Decisions

- D-01: **Flutter.** The app.
- D-02: **Supabase.** The backend.

## Proposals

- P-01: **Reminders.** Later.
"""

HARNESS = """\
import 'package:flutter/material.dart';

/// The variants every golden runs in.
enum MmVariant {
  /// Light mode, English.
  light(Brightness.light, 1),

  /// Dark mode, English.
  dark(Brightness.dark, 1),

  /// English, text at 200%.
  largeText(Brightness.light, 2);

  const MmVariant(this.brightness, this.textScale);

  final Brightness brightness;
  final double textScale;
}
"""

INSTALL = """\
#!/usr/bin/env bash
TLA_VERSION=1.7.4 # TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
TLA_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
LEAN_VERSION=4.35.0
LEAN_SHA256=7289597a44543246c9227b8cae501767e095ce17f6d448b95fc4a8dc97268f6d
LEAN434_VERSION=4.34.0
LEAN434_SHA256=caaa98356098c85dc0fcbbd28e1ec66f39eb6551829972b752ff20e1286b646b
BEND_VERSION=2.0.39
BEND_SHA256=6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab
"""

AGENTS = """\
# AGENTS.md

- **Commits**: a scope from `commitlint.config.mjs`: <!-- docs:commit-scopes -->`app`, `ci`,
  `deps`, `deps-dev`, `docs`, `repo`<!-- /docs:commit-scopes -->. Body lines at most <!-- docs:commit-body-max -->100<!-- /docs:commit-body-max -->
  characters, and a title within the <!-- docs:commit-header-max -->100<!-- /docs:commit-header-max -->-character header.

```sh
make lint docs-check   # every guard
make test              # every fast suite
```
"""

CONVENTIONS = """\
# Conventions

The rules; `.planning/PROJECT.md` (<!-- docs:decision-range -->D-01 to D-02<!-- /docs:decision-range -->) says why.

- Scopes: <!-- docs:commit-scopes -->`app`, `ci`, `deps`, `deps-dev`, `docs`, `repo`<!-- /docs:commit-scopes -->.
- The type matters: <!-- docs:changelog-visible -->`feat`, `fix` and `docs`<!-- /docs:changelog-visible -->
  appear in the changelog, and <!-- docs:changelog-hidden -->`build`, `chore`, `ci` and `test`<!-- /docs:changelog-hidden --> do not.
- Body lines at most <!-- docs:commit-body-max -->100<!-- /docs:commit-body-max --> characters; the subject is not <!-- docs:commit-subject-case -->upper<!-- /docs:commit-subject-case --> case.
- The title fits commitlint's <!-- docs:commit-header-max -->100<!-- /docs:commit-header-max -->-character header.
- Goldens run in three variants: <!-- docs:golden-variants -->`light`<!-- /docs:golden-variants -->.

## Generated files

Edit the source and run the generator.

| Output         | Source                | Command       |
| -------------- | --------------------- | ------------- |
| The tokens     | `tokens.json`         | `make tokens` |
| Repeated facts | the source each names | `make docs`   |

## Dependencies

Nothing here.
"""

COMMANDS = """\
# Commands

```sh
export PATH=/opt/flutter/bin:$PATH   # Flutter 3.47
```

| Target                | What it does                                                                           |
| --------------------- | -------------------------------------------------------------------------------------- |
| `make help`           | Lists the targets                                                                      |
| `make format`         | Formats                                                                                |
| `make format-check`   | Checks the formatting                                                                  |
| `make lint`           | Lints                                                                                  |
| `make tokens`         | Rebuilds the tokens; `make tokens-check` checks them                                   |
| `make docs`           | Rewrites the repeated facts; `make docs-check` checks them                             |
| `make test-core`      | 100% line coverage                                                                     |
| `make test-ui`        | At least <!-- docs:coverage-ui -->95%<!-- /docs:coverage-ui --> line coverage        |
| `make test-app`       | At least <!-- docs:coverage-app -->90%<!-- /docs:coverage-app --> line coverage      |
| `make test-db`        | pgTAP                                                                                  |
| `make test-functions` | 100% line, branch and function coverage                                                |
| `make test-web`       | <!-- docs:test-web-steps -->`npm run check`<!-- /docs:test-web-steps -->             |
| `make test-tools`     | Every directory under `tool/` with tests                                               |
| `make test`           | <!-- docs:make-test-targets -->`test-tools`<!-- /docs:make-test-targets -->          |
| UAT                   | <!-- docs:uat-journeys -->3<!-- /docs:uat-journeys --> journeys                       |

## CI jobs

`.github/workflows/ci.yml` runs on every pull request; the `CI passed` job needs every other job.
Other workflows: `deploy.yml` and `pr-title.yml`.

| Job                | Runs                                        |
| ------------------ | ------------------------------------------- |
| Repository hygiene | `make lint`, `make tokens-check docs-check` |
| Dart · `<package>` | `make test-core`, `test-ui` or `test-app`   |
| Website (Astro)    | The `make test-web` sequence                |
| Database           | `make test-db`                              |
"""

README = """\
# Project

**v1.2.3 is the latest release** <!-- x-release-please-version -->
([release notes](CHANGELOG.md)).

## Quality gates

- coverage gates (100% for `mm_core`, <!-- docs:coverage-ui -->95%<!-- /docs:coverage-ui --> for
  `mm_ui`, <!-- docs:coverage-app -->90%<!-- /docs:coverage-app --> for the app);
- the pgTAP suites (<!-- docs:pgtap-count -->21 suites<!-- /docs:pgtap-count -->);
- browser UAT: <!-- docs:uat-journeys -->three<!-- /docs:uat-journeys --> journeys.

You need Flutter 3.47 (Dart 3.13), Deno 2.9, Node 22 and Python 3.12 or later. The app uses
Riverpod 3, go_router 18 and supabase_flutter 2; the proofs Lean 4 (Lean 4.35.0 and 4.34.0),
Bend 2.0.39, TLC 2.19 from tlaplus v1.7.4, and z3-solver 5.3.3.0.

| Area | Commands                                                       |
| ---- | -------------------------------------------------------------- |
| App  | `make test-app` keeps 90% line coverage, `make test-core` 100% |
| UI   | `make test-ui` checks 200% text                                |

Make the most of it: make sure, make do.

The database is Postgres 17 on Supabase; the suites need a local PostgreSQL 16 with pgTAP, or a
PostgreSQL 16 server. Measured on PostgreSQL 15, which is a record. Goldens in three variants,
and two TLA+ models. The decisions D-01 to D-02 and the proposal P-01 are in `.planning/`.
"""

QUALITY_BAR = """\
# Quality bar

| Gate                                                                                                    | Where           |
| ------------------------------------------------------------------------------------------------------- | --------------- |
| `mm_ui` <!-- docs:coverage-ui -->95%<!-- /docs:coverage-ui --> of lines, the app <!-- docs:coverage-app -->90%<!-- /docs:coverage-app --> | `make test-ui`, `make test-app` |
"""

CONTRIBUTING = """\
# Contributing

- **Commits**: with the `(#123)` GitHub adds, a title stays within <!-- docs:commit-header-max -->100<!-- /docs:commit-header-max --> characters.
"""

OPERATIONS = """\
# Operations

## Releasing

1. release-please bumps the version in <!-- docs:release-files -->`app/pubspec.yaml`<!-- /docs:release-files -->.
"""

UAT = """\
# UAT

- Suite: Playwright, <!-- docs:uat-journeys -->3<!-- /docs:uat-journeys --> journeys.
"""

WEBSITE_README = """\
# Website

`make test-web` runs <!-- docs:test-web-steps -->`npm run check`,
`npm test` and `npm run build`<!-- /docs:test-web-steps -->, as CI does.
"""

LLMS = """\
# Project

> A Flutter app on a Supabase backend (PostgreSQL 17), with `make test` and decisions D-01 to
> D-02.
"""

TRUST_SLIDE = """\
<section id="trust">
<p style="font-size:60px">1,974</p>
<p style="font-size:24px">database tests in 2 suites</p>
<p style="font-size:60px">2</p>
<p style="font-size:24px">TLA+ models of the concurrent paths</p>
</section>
"""

FILES: dict[str, str] = {
    "commitlint.config.mjs": COMMITLINT,
    "release-please-config.json": RELEASE_PLEASE,
    ".release-please-manifest.json": '{".":"1.2.3"}\n',
    "Makefile": MAKEFILE,
    ".github/workflows/ci.yml": CI,
    ".github/workflows/deploy.yml": DEPLOY,
    ".github/workflows/pr-title.yml": PR_TITLE,
    ".github/dependabot.yml": DEPENDABOT,
    "app/uat/tests/journeys.spec.ts": JOURNEYS,
    "supabase/tests/database/01_schema.test.sql": "begin;\nselect plan(600);\nselect pass('a');\n",
    "supabase/tests/database/02_ledger.test.sql": "BEGIN;\nSELECT PLAN( 1374 );\n",
    "supabase/tests/database/_helpers.psql": "-- not a suite\n",
    ".planning/PROJECT.md": PROJECT,
    ".nvmrc": "22.23.4\n",
    "pubspec.yaml": (
        "name: workspace\nenvironment:\n  sdk: ^3.13.0\n\nworkspace:\n  - app\n  - packages/mm_core\n"
    ),
    "app/pubspec.yaml": (
        "name: app\nversion: 1.2.3+1 # x-release-please-version\nenvironment:\n  sdk: ^3.13.0\n"
        "dependencies:\n  flutter_riverpod: ^3.4.3\n  go_router: ^18.1.3\n"
        "  supabase_flutter: ^2.18.3\n"
    ),
    "packages/mm_core/pubspec.yaml": "name: mm_core\nenvironment:\n  sdk: ^3.13.0\n",
    "pyproject.toml": (
        '[tool.black]\nline-length = 100\ntarget-version = ["py312"]\n\n'
        '[tool.ruff]\nline-length = 100\ntarget-version = "py312"\n'
    ),
    "tool/formal/install.sh": INSTALL,
    "supabase/config.toml": "[db]\nport = 54322\nmajor_version = 17\n",
    "packages/mm_ui/test/support/harness.dart": HARNESS,
    "formal/tla/Alpha/Alpha.tla": "---- MODULE Alpha ----\n====\n",
    "formal/tla/Beta/Beta.tla": "---- MODULE Beta ----\n====\n",
    "formal/tla/Beta/BetaProbes.tla": "---- MODULE BetaProbes ----\n====\n",
    "formal/tla/README.md": "# TLA+\n",
    "website/deck/slides/trust.html": TRUST_SLIDE,
    "tool/formal/requirements.txt": "z3-solver==5.3.3.0 \\\n    --hash=sha256:00\n",
    "formal/lean/lean-toolchain": "leanprover/lean4:v4.35.0\n",
    "tool/test_guard.py": "",
    "tool/docs/test_docs.py": "",
    "tool/docs/helper.py": "",
    "AGENTS.md": AGENTS,
    "docs/agents/conventions.md": CONVENTIONS,
    "docs/agents/commands.md": COMMANDS,
    "docs/agents/quality-bar.md": QUALITY_BAR,
    "docs/operations.md": OPERATIONS,
    "CONTRIBUTING.md": CONTRIBUTING,
    "docs/uat.md": UAT,
    "docs/release-readiness.md": "# Dated\n\nFlutter 3.40 and `make test-app` at 80% line coverage.\n",
    "website/README.md": WEBSITE_README,
    "website/src/content/guides/en/a.md": "Flutter 1.0, `make nothing`.\n",
    "README.md": README,
    "CHANGELOG.md": "# Changelog\n\n## 1.2.3\n",
    "llms.txt": LLMS,
}


def with_changes(changes: dict[str, str | None]) -> dict[str, str | None]:
    """FILES with some files replaced, or left out where the value is None."""
    contents: dict[str, str | None] = dict(FILES)
    contents.update(changes)
    return contents


def write(root: Path, changes: dict[str, str | None] | None = None) -> list[str]:
    """Writes FILES under `root`, with `changes` applied, and returns the tracked paths."""
    tracked = []
    for path, text in with_changes(changes or {}).items():
        if text is None:
            continue
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(text.encode("utf-8"))
        tracked.append(path)
    return sorted(tracked)


def edited(path: str, old: str, new: str) -> dict[str, str | None]:
    """A change that replaces the one occurrence of `old` in FILES[path] with `new`."""
    text = FILES[path]
    if text.count(old) != 1:
        raise ValueError(f"{old!r} is not in {path} exactly once")
    return {path: text.replace(old, new)}
