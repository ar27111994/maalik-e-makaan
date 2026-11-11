# Conventions

The rules every change follows, with where each is enforced. `CONTRIBUTING.md` is the short
human version; `.planning/PROJECT.md` (D-01 to D-15) records why.

## Commits and pull requests

- Conventional Commits, checked by commitlint (`commitlint.config.mjs`) in the `commit-msg` hook
  and in CI. Allowed scopes: `app`, `core`, `ui`, `db`, `functions`, `web`, `ci`, `deps`,
  `deps-dev`, `docs`, `formal`, `planning`, `release`, `repo`, `security`, `test`. A scope
  outside the list fails (`feat(foo): …` is refused).
- Body lines at most 100 characters; the subject is not upper, Pascal or Start case.
- Pull requests are squash-merged; `pr-title.yml` checks the title the same way.
- release-please writes `CHANGELOG.md` and the version from these messages
  (`release-please-config.json`), so the type matters: `feat` and `fix` appear in the
  changelog, `chore`, `ci`, `test`, `refactor`, `style` and `build` do not, unless the commit is
  breaking (`!`) or has a `Release-As:` footer. Each section needs a heading in both languages on
  the website's release notes page (`website/src/i18n/ui.ts`, `releases.sections`).

## Language and text

- British English in prose, comments and UI text: licence, colour, organisation, catalogue.
- Every string a person sees is in English and Urdu. App strings live in
  `app/lib/l10n/arb/app_en.arb` (the template) and `app_ur.arb`; every key needs its `@key`
  description (`required-resource-attributes: true` in `app/l10n.yaml`). Website pages exist
  in both languages or the build fails.
- Screens work right to left: directional geometry only (`EdgeInsetsDirectional`,
  `AlignmentDirectional`); the design lint refuses `left`/`right`.
- Unicode guard: `tool/check_unicode.py` fails on bidi overrides and isolates, zero-width and
  other invisible characters, and C0/C1 controls in any tracked file; the contract is
  `contracts/clean_text.json`. Urdu's ZWNJ/ZWJ and LRM/RLM are allowed. Code that needs a
  forbidden character builds it from its code point.

## Money, time and identity

- Money is whole paisa in integers: `Money` in `mm_core`, `numeric(14,2)` in SQL, decoded with
  `Money.fromJson`. Never `double`. Percentages are basis points in Dart, `numeric(5,2)` in SQL.
- Financial rows are never deleted, only voided with a reason; a voided row cannot change.
- Payments are written only through `record_payment`, with an idempotency key the form creates
  once and reuses for every retry.
- Dates without a time are `CalendarDate`; "today" is Pakistan time. The tax year runs 1 July to
  30 June.
- Phone numbers, CNICs and IBANs are stored in exactly the form `mm_core` reads back; the
  database CHECKs and `mm_core` share `contracts/identity_vectors.json`. Never infer gender from
  a CNIC, and mask CNICs by default.

## Database

- A change is a new migration in `supabase/migrations/`, never an edit to an applied one. The
  migrations after the squawk baseline in `.squawk.toml` are linted by `make lint`.
- Locks are taken in one global order: account, then portfolio, then lease, then other rows.
  Client writes lock their portfolios first through `app.lock_my_portfolio_ids`.
- Authorisation lives in Postgres: row-level security on every table, explicit column grants,
  and `SECURITY DEFINER` write RPCs that check the caller's role. The 21 such RPCs are pinned in
  `supabase/tests/database/01_schema_security.test.sql`; a new one updates that list and
  `docs/architecture/permissions.md`.
- Every migration comes with pgTAP tests, a concurrency scenario when rows can be written in
  parallel, and an upgrade test in `tool/db/upgrade/` when it changes existing rows.
- The hosted project is changed only through the process in
  `docs/operations.md`, "After every migration".

## Secrets and privacy

- Clients take the publishable key only; `AppConfig` refuses an `sb_secret_` key or a
  service-role JWT. Service keys live in Edge Function secrets and GitHub secrets.
- gitleaks scans the whole history in CI (`security.yml`, `.gitleaks.toml`).
- No real names, CNICs, phone numbers or documents in code, tests, fixtures, logs or
  screenshots.

## Design

- UI code takes colours, type, spacing, radii and motion from tokens (`MmSpace`, `MmRadius`,
  `MmMotion`, the theme). `make design-lint` fails otherwise; a reviewed exception carries
  `// design-lint: allow <reason>`.
- Components come from `packages/mm_ui`; the visual rules are `DESIGN.md`, the code conventions
  `packages/mm_ui/COMPONENTS.md`.
- WCAG 2.2 AA: 48 dp targets, 4.5:1 text contrast, labelled controls, 200% text. The test
  harnesses check each in every variant.

## Goldens

- Golden tests carry the `golden` tag and run in six variants: `light`, `dark`,
  `lightHighContrast`, `darkHighContrast`, `urdu` and `largeText` (200%). Files are
  `goldens/<name>_<variant>.png` beside the test.
- They are Linux renderings with the real fonts (`test/flutter_test_config.dart`). Re-record
  only on Linux: `make goldens`.
- Review every changed image before committing it, and say in the pull request which goldens
  changed and why. A failing comparison in CI uploads the diffs as `golden-failures-<package>`.

## Generated files

Edit the source and run the generator; the `-check` targets fail CI on a stale output.

| Output                                                                                                       | Source                                                    | Command                                     |
| ------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- | ------------------------------------------- |
| `packages/mm_ui/lib/src/tokens/mm_tokens.g.dart`, `design/tokens/maalik.tokens.css`, `DESIGN.md` frontmatter | `design/tokens/maalik.tokens.json`                        | `make tokens`                               |
| `packages/mm_ui/assets/fonts/MmIcons.ttf`, `packages/mm_ui/lib/src/icons/mm_icons.g.dart`                    | `design/icons/icons.json`                                 | `make icons`                                |
| `contracts/rent_math_vectors.json`, `contracts/identity_vectors.json`, pgTAP suites 10, 12, 13, 20           | `tool/contracts/generate.py`, `contracts/clean_text.json` | `make contracts`                            |
| `app/lib/l10n/generated/`                                                                                    | `app/lib/l10n/arb/*.arb`                                  | `make codegen`                              |
| `supabase/functions/_shared/database.types.ts`                                                               | the hosted schema                                         | `supabase gen types` (`docs/operations.md`) |
| `CHANGELOG.md`                                                                                               | commit messages                                           | release-please                              |

## Dependencies

Adding, removing or upgrading a direct dependency, or bundling a font or icon set, updates
`THIRD_PARTY_NOTICES.md` with its version and licence. Copyleft code (GPL, LGPL, AGPL, MPL)
needs the owner's agreement before it ships. Every GitHub Action is pinned to a commit SHA.

Dependabot pull requests (`.github/dependabot.yml`) change only the manifest and lockfile, so a
bump is not done until the same branch updates `THIRD_PARTY_NOTICES.md` and any README or
comment naming the old version, and rebuilds generated files that depend on it (`make icons`
after lucide-static). A lockfile is written with the npm in `packageManager`, which is the npm
that the Node in `.nvmrc` bundles. When a bump moves a pinned override with it (the website's
`playwright-core` follows `@playwright/test`), the override changes in the same commit.
