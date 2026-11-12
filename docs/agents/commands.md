# Commands

Every target below is in the root `Makefile` (`make help` prints the list) and is what CI runs.
Run them from the repository root. Put the toolchain on the path first:

```sh
export PATH=/opt/flutter/bin:$PWD/.venv/bin:$PATH   # Flutter 3.47, and the pinned Python tools after make bootstrap
```

## Setup and generators

| Target           | What it does                                                                                                                                                                                                                                                                                                                    | Needs                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `make bootstrap` | `.venv` with the hash-pinned Python tools, `flutter pub get`, `npm ci` (its `prepare` script installs the lefthook git hooks), website `npm ci`, `deno install`                                                                                                                                                                 | Flutter, Node 22, Deno, Python                         |
| `make codegen`   | `flutter gen-l10n` for the app's ARB files                                                                                                                                                                                                                                                                                      | Flutter                                                |
| `make tokens`    | Rebuilds `mm_tokens.g.dart`, `design/tokens/maalik.tokens.css` and `DESIGN.md`'s frontmatter from `design/tokens/maalik.tokens.json`                                                                                                                                                                                            | Python                                                 |
| `make icons`     | Rebuilds `MmIcons.ttf` and `mm_icons.g.dart` from `design/icons/icons.json`                                                                                                                                                                                                                                                     | `npm ci`                                               |
| `make fonts`     | Rebuilds the app's Urdu fonts from the upstream files in `design/fonts/`: Noto Sans Arabic at its normal width (every glyph and weight kept) and Noto Nastaliq Urdu cut to the letters of `appName` in `app_ur.arb`, the wordmark (`tool/design/build_fonts.py`)                                                                | Python                                                 |
| `make app-icons` | Rebuilds the launcher icons (Android, iOS, web, Google Play) from the mark in `website/src/lib/brand.ts` and the tokens, and the web manifest's name from `appName` in `app_en.arb` (`tool/design/build_app_icons.py`)                                                                                                          | Python                                                 |
| `make contracts` | Rewrites `contracts/rent_math_vectors.json`, `contracts/identity_vectors.json`, `contracts/residence_vectors.json`, `contracts/time_zone_vectors.json`, `packages/mm_core/lib/src/time/time_zone_data.g.dart`, `tool/db/time_zone_skew.sql` and the generated pgTAP suites 10, 12, 13, 20 and 23 (`tool/contracts/generate.py`) | Python, the `tzdata` pinned in `tool/requirements.txt` |
| `make roadmap`   | Rewrites `website/src/data/roadmap.json`, the website's offline copy of the roadmap, from `.github/roadmap.toml` (`tool/github/fetch_roadmap.py --from-file`)                                                                                                                                                                   | Python                                                 |
| `make format`    | Writes Dart, Deno, black, ruff, shfmt and Prettier formatting                                                                                                                                                                                                                                                                   | all toolchains                                         |
| `make clean`     | Removes build outputs and coverage                                                                                                                                                                                                                                                                                              | Flutter                                                |

## Gates

| Target                   | What it checks                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make format-check-repo` | black, shfmt and Prettier (`**/*.{md,yml,yaml,json,jsonc}`); needs no Flutter or Deno                                                                                                                                                                                                                                                                                                                                                                                                        |
| `make format-check`      | `dart format` for `mm_core`, `mm_ui` and `app`, `deno fmt --check`, then `format-check-repo`                                                                                                                                                                                                                                                                                                                                                                                                 |
| `make lint`              | ruff, shellcheck, actionlint, the migration transaction check (`tool/db/check_migration_transactions.py`: no `LOCK TABLE` or savepoint outside `begin; … commit;`, which the Supabase CLI cannot apply), squawk on migrations after the `.squawk.toml` baseline, editorconfig-checker, markdownlint, the Unicode guard, the plain-Urdu guard (`tool/check_urdu_words.py`), the Android manifest check (`tool/android/check_manifest.py`: `INTERNET` and the two launcher icons), design lint |
| `make design-lint`       | `tool/design/lint_hardcoded.py` over `mm_ui` and `app` `lib/`                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `make analyze`           | `dart`/`flutter analyze --fatal-infos` for each package and the gallery, `deno lint` and `deno task check`, the Unicode guard                                                                                                                                                                                                                                                                                                                                                                |
| `make tokens-check`      | Tokens valid and their outputs current                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `make icons-check`       | Icon font and constants current                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `make fonts-check`       | The app's Urdu fonts current with `design/fonts/` (whose SHA-256 it checks) and with the Urdu `appName`, byte for byte                                                                                                                                                                                                                                                                                                                                                                       |
| `make app-icons-check`   | The app launcher icons current with the mark, the colour tokens and `appName`. It decodes each PNG and compares its format and pixels, not its bytes: a lossless re-encode passes, but a change of colour type or bit depth fails, because Google Play wants 32-bit PNGs and iOS refuses alpha. A damaged PNG fails too, even when its pixels decode (a bad chunk checksum, a file cut short or with bytes after `IEND`), and `make app-icons` rewrites it                                   |
| `make roadmap-check`     | The website's offline roadmap copy matches `.github/roadmap.toml`                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `make contracts-check`   | Contract vectors and generated suites current                                                                                                                                                                                                                                                                                                                                                                                                                                                |

## Tests by area

| Area           | Target                     | Gate or notes                                                                                                                               |
| -------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Tooling        | `make test-tools`          | Python `unittest` in `tool/` and `tool/{coverage,db,design,web,formal,ios,android,github,contracts}`                                        |
| `mm_core`      | `make test-core`           | 100% line coverage                                                                                                                          |
| `mm_ui`        | `make test-ui`             | Widget, golden and accessibility tests; at least 95% line coverage                                                                          |
| Gallery        | `make test-gallery`        | Every gallery page in every theme, Urdu and 200% text                                                                                       |
| App            | `make test-app`            | Unit, widget and golden tests; at least 90% line coverage                                                                                   |
| Goldens        | `make goldens`             | Re-records `mm_ui` and app goldens (`--tags golden`); review every changed image                                                            |
| Database       | `make test-db`             | Migrations and pgTAP on a local PostgreSQL 16 (`tool/db/test.sh`), then `tool/db/upgrade_test.sh`                                           |
| Database       | `make test-db-concurrency` | Parallel payments, retries, billing and deletion races keep the invariants; a stuck scenario fails with its sessions and locks printed      |
| Database       | `make test-db-stress`      | Latency budgets and index use (fails when one is missed) and pgbench throughput; not run in CI                                              |
| Edge Functions | `make test-functions`      | 100% line, branch and function coverage                                                                                                     |
| Edge Functions | `make test-functions-e2e`  | Against a running `supabase start` stack                                                                                                    |
| Website        | `make test-web`            | `npm run check`, `npm test`, `npm run deck`, `npm run build`, `npm run test:e2e`, `npm run lighthouse:ci`                                   |
| UAT            | `make test-uat`            | 14 browser journeys on the release web build against `supabase start` ([`docs/uat.md`](../uat.md)); `UAT_RESET=1` resets the database first |
| Formal         | `make formal-install`      | Pinned, sha256-checked tools into `.cache/formal`                                                                                           |
| Formal         | `make verify`              | Every track's fast set, as CI runs it; `make verify-all` runs every configuration and mutant                                                |
| Everything     | `make test`                | `test-tools test-core test-ui test-app test-gallery test-db test-functions`                                                                 |
| Builds         | `make build-web-app`       | Release web build with `app/config/production.json`                                                                                         |
| Builds         | `make build-apk`           | Release APKs split per ABI, same configuration                                                                                              |

`make test-integration` points at `app/integration_test/`, which does not exist: the app's
end-to-end tests are the browser UAT (`make test-uat`, `app/uat/`), which drives the release web
build through a real Supabase stack.

### Narrower runs

```sh
tool/db/test.sh supabase/tests/database/05_ledger.test.sql   # one pgTAP suite
MM_TEST_DB=my_db tool/db/reset.sh --seed                      # a disposable database with demo data
cd app && flutter test test/src/features/ledger                # one app folder
cd supabase/functions && deno task test                        # functions, with coverage
tool/formal/verify.sh ci tla/RateLimit lean                    # some formal tracks
```

`tool/db/env.sh` sets the connection defaults (`127.0.0.1:54329`, user `postgres`, database
`mm_test`). Use your own `MM_TEST_DB` when another session may be using `mm_test`.

## CI jobs

`.github/workflows/ci.yml` runs on every push and pull request; the `CI passed` job needs all of
them.

| Job                   | Runs                                                                                                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Repository hygiene    | commitlint, `make format-check-repo`, `make lint`, `make test-tools`, `make tokens-check icons-check fonts-check app-icons-check contracts-check roadmap-check`, `designmd lint DESIGN.md` |
| Dart (matrix)         | `dart format` and analyze per package, then `make test-core`, `test-ui`, `test-app` or `test-gallery`; failing goldens are uploaded as `golden-failures-<package>`                         |
| Flutter web build     | Release web build, `tool/web/package_vercel.py`, `tool/web/smoke_test.sh` against a local server                                                                                           |
| Website (Astro)       | The `make test-web` sequence, with Playwright and Lighthouse reports uploaded                                                                                                              |
| Android release build | `flutter build appbundle --release` with the example configuration                                                                                                                         |
| iOS build (unsigned)  | `flutter build ios --release --no-codesign` on macOS, kept as the `ios-unsigned-ipa` artefact                                                                                              |
| Edge Functions        | `deno fmt --check`, `deno lint`, `deno task check`, `make test-functions`                                                                                                                  |
| Database              | `make test-db`, `make test-db-concurrency` on PostgreSQL 16 with pgTAP                                                                                                                     |
| Supabase stack        | `supabase start`, `supabase db lint`, `supabase test db`, `make test-functions-e2e`                                                                                                        |
| UAT                   | `supabase start`, then `make test-uat` (Playwright's Chromium); uploads the report, failure traces and screenshots as `uat-report`                                                         |
| Formal verification   | `make formal-install`, `make verify`                                                                                                                                                       |

Other workflows: `security.yml` (CodeQL, gitleaks, OSV-Scanner, dependency review, zizmor,
outdated function dependencies), `scorecard.yml`, `pr-title.yml` (the squash title), `release.yml`
(release-please and the release artefacts), `deploy.yml` (Supabase, web app and website; see
[`docs/operations.md`](../operations.md#deployment-github-actions)), `backup.yml` (the weekly
encrypted backup, restored and checked on a local stack before it is kept; see
[`docs/operations.md`](../operations.md#backups)), `roadmap.yml` (the roadmap's GitHub
milestones and issues, from `.github/roadmap.toml`) and `site-refresh.yml` (the website alone,
redeployed at the latest release every week for a current roadmap; see
[`docs/operations.md`](../operations.md#the-website-on-vercel)).
