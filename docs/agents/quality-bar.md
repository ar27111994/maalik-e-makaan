# Quality bar

The owner's definition of done, area by area, for anyone (person or agent) changing this project.
The short form is in the root [`AGENTS.md`](../../AGENTS.md#quality-bar). Each section says what
the bar means here, which gates hold it today, and what is still to reach. A gate is only ever
raised, never lowered, and a target becomes a gate when the tests that meet it exist.

## Frontend

The app, the design system (`packages/mm_ui`) and the website.

**The bar.** Every screen and page is high-quality, clean, intuitive, interactive, consistent,
fast and responsive to touch, beautiful, rich and tasteful, accessible, optimised for search
engines and AI answer engines, mobile-first, responsive and reliable. It reuses the design system
rather than one-off styles: shared tokens (colour, type, spacing, radii, elevation, motion), themes
and presets, states, components and icons.

**What that means in practice.**

- **States**: every interactive element has every state it can reach: default, hover, focus,
  pressed, selected, disabled, loading, empty, error and success. None is drawn by hand outside
  `mm_ui`.
- **Accessibility**: WCAG 2.2 AA in both languages and in every theme, including:
  - contrast, and visible focus;
  - targets of at least 48 dp in the app and 24 CSS px on the website;
  - text at 200%;
  - right-to-left Urdu;
  - reduced motion;
  - labels a screen reader announces.
- **Mobile first**: designed for a mid-range Android phone on a slow connection, then widened. No
  horizontal scrolling at 360 px. Layouts adapt rather than stretch.
- **Speed**: pages and screens show useful content quickly, and taps answer at once (the press
  state appears even when the work behind it takes time).
- **Search and AI answer engines**: on the website, every page has:
  - a title and description;
  - a canonical URL and its language twin (`hreflang`);
  - structured data;
  - an entry in the sitemap.

  [`llms.txt` and `llms-full.txt`](../../website/src/lib/llms.ts) describe the site for AI readers.

**Gates today.**

| Gate                                                                                            | Where                                                                                       |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| UI code takes colours, type, spacing, radii and motion from tokens, with directional geometry   | `make design-lint` ([`tool/design/lint_hardcoded.py`](../../tool/design/lint_hardcoded.py)) |
| Tokens and their generated outputs agree                                                        | `make tokens-check`                                                                         |
| Every gallery page in every theme, in Urdu and at 200% text, with the accessibility checks      | `make test-gallery`                                                                         |
| Golden images of components and screens, in the themes, in Urdu and at large text               | `make test-ui`, `make test-app`                                                             |
| Every website page passes axe for WCAG 2.2 AA, in both languages                                | [`website/tests/e2e/a11y.spec.ts`](../../website/tests/e2e/a11y.spec.ts)                    |
| Lighthouse 95 or more in every category, on the mobile profile                                  | [`website/lighthouserc.cjs`](../../website/lighthouserc.cjs) (CI runs a subset)             |
| Every page has its Urdu twin, and none has inline code (the Content-Security-Policy forbids it) | the website build                                                                           |

**Still to reach.** A design QA pass on every surface ([`docs/design-qa.md`](../design-qa.md)),
using the `design-systems-engineering` skill and a real browser. Lighthouse over every page in CI,
not only the subset.

## Testing and QA

**The bar.** 100% coverage is the floor, not the goal. Beyond it, the tests cover every relevant
case, at the unit, integration and end-to-end levels:

- edge cases and failure paths;
- concurrency;
- performance and stress;
- security and input sanitisation;
- smoke tests;
- fuzzing.

**What that means in practice.**

- **Branches as well as lines**: every branch is reached, and every error path is tested, not
  only the happy path.
- **Concurrency**: every write path that shares rows with another has a scenario that runs them
  in parallel and checks the invariants afterwards.
- **Security**: every role tries every table, view and function, and the refusals are tested as
  carefully as the successes. Hostile input is tried wherever text, files or numbers come in:
  injection, oversized values, wrong types, control characters and mixed scripts.
- **Fuzzing and properties**: parsers, money maths, validators and text guards are tested with
  generated input, not only examples. The contract vectors keep Dart, SQL and TypeScript in
  agreement.
- **Smoke tests**: run after every deploy, on the real site and backend, with sample data only.
- **No flaky tests**: a test that passes or fails by timing is a defect. Wait for the condition
  (a lock held, a row written), not for a fixed time.

**Gates today.**

| Gate                                                                      | Where                                                 |
| ------------------------------------------------------------------------- | ----------------------------------------------------- |
| `mm_core` 100% of lines                                                   | `make test-core`                                      |
| Edge Functions 100% of lines, branches and functions                      | `make test-functions`                                 |
| `mm_ui` 95% of lines, the app 90%                                         | `make test-ui`, `make test-app`                       |
| Migrations and the pgTAP suites, and the migrations' data changes         | `make test-db`                                        |
| Parallel payments, retries and billing races keep the ledger's invariants | `make test-db-concurrency`                            |
| Latency budgets, index use and throughput                                 | `make test-db-stress`                                 |
| Rent maths and identity rules agree across Dart, SQL and TypeScript       | `make contracts-check`, and the suites that read them |
| TLA+, Lean, Z3 and Bend models of the money and concurrency code          | `make verify`                                         |
| The web app's journeys in a browser, against a local Supabase stack       | `make test-uat` ([`docs/uat.md`](../uat.md))          |
| Website unit tests, end-to-end tests and the link check                   | `make test-web`                                       |

**Still to reach.**

- 100% of lines and branches in `mm_ui` and the app.
- Branch coverage reported for every Dart package.
- Fuzz and property tests where input arrives.
- A smoke test after each deploy.
- Every concurrency scenario ordered by the database's state rather than by sleeps.

## CI/CD

**The bar.** Every kind of check runs on every pull request, or on a schedule where it cannot.
The kinds are code quality and validation, security, coverage, maintenance, and the release
lifecycle. Each check is a `make` target first, so it runs the same way locally.

**Gates today** ([`docs/agents/commands.md`](commands.md#ci-jobs) maps each job to its targets):

| Kind                | Workflows and jobs                                                                                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Quality, validation | `ci.yml`: repository hygiene (formatting, lint, tooling tests, generated files, commit messages), Dart per package, website, web, Android and iOS builds, Edge Functions, database, Supabase stack, UAT, formal models; `pr-title.yml` |
| Coverage            | the coverage gates inside the `ci.yml` jobs ([`tool/coverage/check.py`](../../tool/coverage/check.py))                                                                                                                                 |
| Security            | `security.yml`: CodeQL, secret scanning, vulnerable dependencies (OSV), dependency review, workflow security (zizmor), outdated Edge Function dependencies; `scorecard.yml` (OpenSSF Scorecard)                                        |
| Maintenance         | Dependabot ([`.github/dependabot.yml`](../../.github/dependabot.yml)) for GitHub Actions, npm, pub, Gradle and pip                                                                                                                     |
| Release lifecycle   | `release.yml` (release-please, the signed Android app, the web app and an unsigned iOS app with attested provenance, deploy), `deploy.yml`, `site-refresh.yml`, `roadmap.yml`, `backup.yml`                                            |

**Still to reach.**

- A smoke test after each deploy.
- Lighthouse over every page.
- A check that keeps repeated facts in the documentation in step with their sources.

## API and database

**The bar.** A complete, fast and secure production system, hardened across the API, the
database, the frontend and the backend. It covers:

- type safety;
- rate limits;
- caching;
- indexes;
- roles;
- timing-safe equality;
- search-engine readiness.

Every implicit state machine is found, written down and enforced.

**What that means in practice.**

- **State machines**: anything with a status or a lifecycle has its states and allowed transitions
  written down and enforced by the database, with a test for every allowed and every refused
  transition. Examples are a tenancy, a charge, a payment, an invitation, a membership, a
  document and a background job. Where two of them interact, the formal models check the
  combination.
- **Type safety**: from the database to the screen. Generated types or contract tests sit at
  every boundary, there are no untyped maps across them, and money is whole paisa in integers.
- **Rate limits**: on every endpoint and RPC a person or a script can call repeatedly, with
  limits that suit the action.
- **Caching**: what can be cached is, with a clear rule for when it goes stale. Nothing private is
  cached where another person could read it.
- **Indexes**: every query on a hot path uses one, and the stress test proves it.
- **Roles**: row-level security on every table, write RPCs that authorise their caller first
  (D-15), and the least privilege for each role.
- **Secrets**: compared in constant time, never with `==`.

**Gates today.**

- Row-level security and its matrix in the pgTAP suites.
- The pinned allowlist of SECURITY DEFINER functions (D-15).
- The rate limiter, `private.hit_rate_limit`, in the foundation migration.
- The lock order (account, portfolio, lease, other rows).
- Timing-safe comparison in the Edge Functions, through `_shared/crypto.ts`.
- The stress test's index and latency checks.
- The formal models of the ledger, jobs and limiter.

**Still to reach.** An inventory of every state machine, each with its enforcement and its
transition tests. A review of rate limits, caching, indexes and type boundaries across the whole
API.

## Documentation

**The bar.** Documentation is part of the change. A pull request updates every document its change
makes wrong. `CHANGELOG.md` is written by release-please from the squash commits, so each commit
message is written for the reader of the changelog. A fact repeated in several places (commit
scopes, `make` targets, CI jobs, versions, the list of decisions) is generated from its source, and
CI fails when a copy drifts.

**Gates today.**

- `make roadmap-check` keeps the website's copy of the roadmap in step with `.github/roadmap.toml`.
- `make tokens-check` keeps `DESIGN.md`'s frontmatter in step with the tokens.
- The Markdown linters and the Unicode and Urdu guards run in `make lint`.

**Still to reach.** Generated blocks, with a CI check, for the other repeated facts.

## Tools and skills

Use what the environment provides, and pick by task:

| Task                                                    | Skills and tools                                                            |
| ------------------------------------------------------- | --------------------------------------------------------------------------- |
| Is a release ready to tag?                              | `release-readiness-audit`                                                   |
| Testing the repository's command-line tools and scripts | `cli-tool-qa`                                                               |
| Screens, tokens, components, accessibility, design QA   | `design-systems-engineering`, browser use, computer use                     |
| READMEs, guides, specs, agent context                   | `project-documentation`, `llm-context-modular-docs`                         |
| Planning and tracking multi-step work                   | `gsd` (the `.planning/` directory)                                          |
| Writing and reviewing code                              | `code-quality-standards`, `code-review`                                     |
| The website's search and AI-search health               | `seo-audit`                                                                 |
| Copy against the brand's voice                          | `brand-review`                                                              |
| A library's or service's current API                    | Context7, the service's own MCP server or documentation; never memory alone |

If a decision is the owner's, or you are blocked, ask: the owner has said to.
