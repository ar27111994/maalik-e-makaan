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

## Formal verification

The models and proofs under [`formal/`](../../formal/README.md), and the code they follow: the money
arithmetic shared by Dart and SQL, and the database paths where sessions race.

**The bar.** Every money path, every concurrency protocol and every state machine they pass through
has a model or a proof, and CI checks it. Each model is tied to the code it follows, so a change
that breaks a property fails a check, not only a review. A test checks some runs; an exhaustive
model check covers every run within its bounds, and a proof covers every input. A prose argument
("the lock order prevents this") is not evidence: the evidence is a check that a machine runs.

**What that means in practice.**

- **Same pull request**: new or changed money or concurrency code is not done until a track
  models it and `make verify` passes. For new behaviour, write the property first and see it fail
  on the code as it is, then change the code.
- **Named properties**: every property has a stable name: a TLA+ invariant, a Lean theorem, a Z3
  check or a Bend law. READMEs and code comments cite the name, not a description, and every claim
  in a track's README names the configuration, invariant or theorem that checks it.
- **Stated assumptions**: every hypothesis names the guard that makes it true (a CHECK constraint,
  a Dart throw, an RPC's refusal, a lock), and that guard has a test. A fact proved under one lock
  holds on another write path only when that path takes the same locks in the same order.
  Hypotheses have names a search finds, so before a bound is widened, a search shows which
  theorems and checks rely on it.
- **Tied to the code**: by the contract vectors (read by Dart, SQL, TypeScript and Lean), by runs
  against the real Dart and SQL, by a PostgreSQL replay of every finding, and by a pgTAP test or
  concurrency scenario for each TLA+ property. Each track cites the migration that holds the last
  definition of every function it follows, and each such function names its track in a comment.
- **Never vacuous**: every property has a mutant that breaks it, and a mutant that is not caught
  fails the run. A finding stays as a failing configuration or mutant after its fix. A pull
  request that weakens an invariant, shrinks a bound or deletes a mutant says so and why in its
  description, and waits for the owner. A baseline flips only with the fix of its finding, which
  keeps the old code as a mutant.
- **Proofs a reader can check**: each non-trivial theorem has a short sketch of why it holds. Long
  proofs are split into named steps, and the key theorems that a definition equals the SQL are
  chains with one reason per step, so the step that fails is plain when either side changes. No
  "similarly for the other cases": the shared step becomes a named lemma. No `sorry`, no new axiom.
- **State machines**: each machine in the inventory (see [API and database](#api-and-database)) is
  a table of transitions: state before, state after, the RPC or job, and the columns it writes.
  The pgTAP tests of allowed and refused transitions, and the model's frame conditions, come from
  that table, and a check fails when an enum gains a value the model does not cover.
- **Voids are not undos**: a void keeps the voided row, its receipt number and its audit entries,
  and other rows need not go back to where they were (a late fee that a payment voided stays
  voided when that payment is voided). The property of each void says what it restores and what
  it leaves.
- **Same as one at a time**: after any interleaving, the money rows equal what the same committed
  calls give when run one at a time in the order they committed, apart from work a job skipped
  because a row was busy, which its next run must pick up. Running a job twice changes nothing.
- **The boundary**: each track lists every path that can write its rows outside the functions it
  models (an Auth admin delete, a service-role script, the Storage API, a migration's data
  change), and models it or closes it. A message, receipt or e-mail cannot be taken back, so it
  leaves only after its transaction commits.
- **Progress**: every retry loop, sweep and job says what decreases and why it stops, and its track
  checks that it finishes, under stated fairness.
- **Where proof stops**: proofs and models hold fixed properties of a stable core. Behaviour with
  no fixed specification, such as a language model's answers or how well a parser reads real
  messages, is held by evaluation sets instead (see [Agentification](#agentification)).

**Gates today.**

| Gate                                                                                                                                                                                             | Where                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| Every track's fast set on every pull request, as part of the "CI passed" check: six TLA+ models with the mutants in their fast sets, Lean 4 with Z3, and Bend's proof verdict                    | `make verify` ([`tool/formal/verify.sh`](../../tool/formal/verify.sh)), the `formal` job in `ci.yml` |
| The tools are pinned, and every download is checked against its sha256                                                                                                                           | `make formal-install` ([`tool/formal/install.sh`](../../tool/formal/install.sh))                     |
| Every check states its expected outcome, and a mismatch either way fails, so a mutant that is not caught fails the run                                                                           | each track's `run.sh` ([`formal/AGENTS.md`](../../formal/AGENTS.md))                                 |
| Lean refuses `sorry`, `native_decide`, new axioms and the other escape hatches, and its 44 headline theorems use only the standard axioms                                                        | `formal/lean/run.sh`, [`formal/lean/Axioms.lean`](../../formal/lean/Axioms.lean)                     |
| The 71 contract vectors pass in Lean, and a copy with one value changed fails                                                                                                                    | `check-vectors` in `formal/lean/run.sh`                                                              |
| No overflow in Dart, `numeric(14,2)` or JSON within the bounds the code enforces (one, the sum of `Money.allocate` ratios, is assumed), and PostgreSQL's inexact division never changes a result | Z3 in [`formal/smt/`](../../formal/smt/README.md), run by `formal/lean/run.sh`                       |
| The pgTAP suites and concurrency scenarios that each TLA+ track's README maps to its properties                                                                                                  | `make test-db`, `make test-db-concurrency` (the `database` job in `ci.yml`)                          |

Not yet in CI, and so run by hand: `make verify-all` (every mutant, Bend's soundness checks and its
runs against the real Dart and SQL) and the PostgreSQL replays of the findings (each track's
`replay/run.sh`, `formal/tla/Invitations/replay_findings.sh` and
`formal/tla/Membership/replay/residence.sh`).

**Still to reach.**

- `make verify-all` and the replays of the findings in CI on a schedule, so every mutant and every
  run against the real Dart and SQL is checked, not only the fast sets.
- A check in `tool/formal/` that fails when a migration redefines a function a track follows and
  the track does not change in the same pull request.
- Models of the money paths not covered yet: deposits (`apply_deposit`, `refund_deposit`),
  `waive_charge`, `void_charge`, utility bills, receipt numbers across a year boundary, due-date
  edits, and the sums in `get_dashboard` and `get_receivables`. Proofs for money formatting and
  parsing, and for the website's TypeScript money.
- Every state machine as a transition table, with a check that its model covers every value of its
  enum.
- The void, one-at-a-time and progress properties in the ledger and job tracks, and the
  one-at-a-time comparison as a check in `make test-db-concurrency`.
- Inductive invariants for the money properties, so a pass does not depend on which states the
  scenarios reach; then structured proofs of them in the TLA+ proof system.
- In each track's README: the paths that write its rows outside the modelled functions, and the
  pairs of operations on shared rows that commute, with the lock that orders the rest.
- Sketches and named steps in the long Lean proofs, step-by-step chains for the key theorems that a
  definition equals the SQL, and a named check for every claim in a README.
- The agent of [agent-limits](../roadmap/agent-limits.md) (retries, reorders and duplicates; the
  budget, forbidden actions, revocation) and the late, repeated webhooks of
  [raast-request-to-pay](../roadmap/raast-request-to-pay.md), each modelled with its feature, not
  after it.

Background, from papers the owner shared: Leslie Lamport, _How to Write a Proof_ (1993), for named
steps, stated assumptions, sketches and no "similarly"; Yifan Shi, Wei Zhang and Tianyi Cui, _A
Programming Paradigm for Spatiotemporal Composability_ (preprint, 2026), for voids as
compensations, messages that cannot be taken back, boundaries, progress and transition tables;
Dhruv Srikanth and others, _Recursive self-improvement of AI research agents_ (2026), for where
evaluation takes over from proof; and, by analogy only, the test-first advice in Peter Bell,
_Scaling AI Adoption in Engineering_ (early release, 2026), which has no formal methods in it.

## Agentification

Agents on both sides of the product. Coding agents build and run this repository. Inside the
product, the [roadmap](../roadmap/README.md) plans a read-only MCP server, assistants that write
within limits, Munshi on WhatsApp, payments drafted from voice notes and SMS, and assistants that
coordinate between roles.

**The bar.** The repository is built for agents: an agent finds what it needs, loads only that,
follows rules that a machine checks, shows evidence for its work, stays within stated limits and
leaves a record of what it did. The product is safe and useful to agents: each sees the least it
needs, writes only drafts within a mandate that a person granted and can revoke, and every call
is consented to, logged, rate-limited and attributed. The model drafts, a person confirms, and
the database decides what is allowed.

**What that means in practice, in the repository.**

- **Layered context**: the root `AGENTS.md`, then the area's `AGENTS.md`, then its README, then
  the code. Each layer summarises the one below without contradicting it, and an agent can do a
  task in an area from that area's layer. `.planning/STATE.md` says where things stand; no whole
  history goes into instructions.
- **Rules a machine checks**: a rule that matters is a `make` target, a hook or a CI gate, not
  only a sentence in `AGENTS.md`. A fact repeated across the agent context is generated from its
  source.
- **One bar for every author**: an agent's pull request passes the same gates as a person's, and
  no gate is lowered for it.
- **Evidence, not claims**: done means the named `make` targets ran and passed, and the pull
  request says so. A claim that something is correct points to a test, a pgTAP assertion, a model
  configuration or a theorem. No case is left out as "the same for the other roles".
- **Gates are not the agent's to move**: passing a check by weakening a test, adding a coverage
  exclusion, lowering a threshold or deleting a mutant is a defect. A change that weakens a test,
  a gate or a checker is named in the pull request with its reason, and waits for the owner. A
  checker never lets one failing case hide the others.
- **Review before merge**: every change an agent writes gets a review pass before it merges (the
  `code-review` skill, or a second agent), and money, row-level security and migrations always
  do. Reviewers read the evidence (CI logs, the coverage report, the `verify.sh` summary) and
  check each claim against it.
- **Limits on autonomy**: an agent asks the owner before a release, a change to the hosted
  project, a write to an external service, or any decision that is the owner's. It runs with the
  least permission it needs, and never widens its own permissions, hooks or guards in the session
  they govern: such a change comes in its own pull request and passes CI first.
- **Provenance**: every commit an agent writes names the agent and its session in trailer lines,
  and the pull request says how the change was checked.
- **Learning loops**: a recurring review finding or agent mistake goes back into an `AGENTS.md`
  file, a skill or a guard. A rejected approach is kept with its reason. A new practice (a skill,
  an orchestration script, a review loop) is tried against written criteria, then adopted into
  `docs/agents/` or dropped with a note.

**What that means in practice, in the product.**

- **Least privilege by construction**: outside AI clients read through a few `STABLE` functions
  under row-level security, with output schemas and no CNIC, phone number or storage URL in the
  output. The database enforces it: every write RPC and every table refuses a token that carries
  a `client_id`, except the draft RPCs, which need a mandate. A tool annotation such as
  `readOnlyHint` is a hint, not a control.
- **Bounded mandates**: an assistant is a delegate, not a member. Its rights are its person's role
  narrowed by a mandate that person granted (the actions, the leases, the largest amount, a
  monthly budget and an end date), checked by the database under the lock order. It writes only
  drafts, and a person confirms each one before it reaches the ledger; whether a small amount may
  ever skip that tap is an open question for the owner. Voids, waivers, deletions and team
  changes never come through an assistant.
- **Revocation**: revoking a grant or a mandate takes effect at once and discards its open drafts
  and pending actions; nothing is confirmed under it afterwards. Every write an agent may call
  names the RPC that retracts it.
- **Consent, audit and limits**: nothing reaches a model, speech or OCR provider before explicit
  consent, recorded with the version of the text the person saw. Providers keep nothing and train
  on nothing, as the plans require. Every agent call is logged, and every agent write is
  attributed (source, client, mandate) in an audit trail whose seals show any later edit. Rate
  limits apply per client and per person, and model cost has a monthly cap per account.
- **Deterministic checks around the model**: a model may choose an intent or suggest a lease.
  Amounts and dates come from the reviewed amount grammar, never from the model, and are read back
  before the tap. Untrusted text reaches a model marked as data, capped and cleaned. Assistants
  never message one another: only typed fields that constraints check cross between roles.
- **Evaluation sets**: each feature that runs a model has a fixed set in the languages and forms
  it accepts (English, Urdu and Roman Urdu; text, synthetic voice or sample documents), with no
  real people, scored against fixed expected answers rather than by another model. A held-out
  part is never used for tuning. A new prompt, model or provider is accepted only if it does at
  least as well on the held-out part, over several runs at the same cost, with the spread
  reported. One whole family (one wallet's SMS, or all voice notes) stays out of tuning, to test
  what is new.
- **Stable contracts and a way out**: a published tool's output only gains fields; any other
  change is a new tool. Every AI provider sits behind an interface, with a written way to replace
  it.

**Gates today.** In the repository, the agent context is layered: the root
[`AGENTS.md`](../../AGENTS.md), six area `AGENTS.md` files and [`docs/agents/`](README.md), with a
`CLAUDE.md` beside each `AGENTS.md` that points to it.
[`.claude/settings.json`](../../.claude/settings.json) pre-approves one command (`bend`) and sets
no other rule. What checks an agent's work:

| Gate                                                                                                        | Where                                                                                                                          |
| ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Commit messages and pull request titles follow the rules                                                    | `commitlint.config.mjs` (the `commit-msg` hook and the CI hygiene job), `pr-title.yml`                                         |
| Formatting, the Unicode and Urdu guards, design lint and migration lint before each commit, and again in CI | [`lefthook.yml`](../../lefthook.yml), `make format-check-repo lint`                                                            |
| Generated files match their sources                                                                         | `make tokens-check icons-check app-icons-check contracts-check roadmap-check`                                                  |
| Every author, person or agent, passes the same checks, gathered in one "CI passed" job                      | the "CI passed" job in `ci.yml`                                                                                                |
| GitHub asks the owner to review every pull request, and the template asks how the change was checked        | [`.github/CODEOWNERS`](../../.github/CODEOWNERS), [`.github/pull_request_template.md`](../../.github/pull_request_template.md) |

In the product, where no agent feature is built yet, the foundations an agent would meet:

| Gate                                                                                                                                                                                                                                                         | Where                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The two Edge Functions for signed-in people refuse tokens issued to third-party OAuth clients                                                                                                                                                                | `requireUser` in [`supabase/functions/_shared/handler.ts`](../../supabase/functions/_shared/handler.ts), used by `invite-member` and `delete-account`, and its tests |
| Payments, memberships and invitations are written only through the reviewed SECURITY DEFINER RPCs that a pgTAP allowlist pins, each of which authorises its caller (D-15); other writes go through row-level security; payments are idempotent by key (D-07) | `supabase/tests/database/01_schema_security.test.sql`, `03_rls_matrix.test.sql`, `05_ledger.test.sql`                                                                |
| A rate limiter for requests and Edge Functions, modelled in TLA+                                                                                                                                                                                             | `app.check_request`, `public.admin_rate_limit_hit`, `_shared/rate_limit.ts`, `formal/tla/RateLimit`                                                                  |
| An audit trail that signed-in people cannot change, with CNICs redacted; it is deleted with its portfolio                                                                                                                                                    | `public.audit_logs`, `07_notifications_audit.test.sql`                                                                                                               |
| Stored text refuses control, bidi-override and invisible characters                                                                                                                                                                                          | `app.is_clean_text` in CHECK constraints, [`contracts/clean_text.json`](../../contracts/clean_text.json)                                                             |
| The website describes itself to AI readers, from the same content as its pages                                                                                                                                                                               | `llms.txt` and `llms-full.txt` ([`website/src/lib/llms.ts`](../../website/src/lib/llms.ts)), `llms.test.ts`                                                          |

**Still to reach.** In the repository:

- A check that keeps the facts repeated across the agent context in step: the commit scopes
  (`commitlint.config.mjs`, `pr-title.yml`, `AGENTS.md`), the list of context files, and this
  file's sections (`AGENTS.md`, `docs/agents/README.md`, `llms.txt`).
- Project skills in `.claude/skills/` for the recurring tasks: a migration with its pgTAP suite and
  concurrency scenario, a change to a formal track, a roadmap item.
- Permission rules in `.claude/settings.json` that make an agent ask before it touches the hosted
  project or an external service, and a hook that formats and lints a file after an agent edits
  it.
- A CI check that commits on agent branches carry the trailers that name the agent and its session.
- A CI notice when a pull request changes a test, a coverage threshold, a mutant or a formal
  baseline together with the code they judge.
- A short record in `.planning/` of rejected approaches and recurring agent mistakes.
- A small, fixed set of past tasks to try a large change to the agent context or a skill on before
  adopting it.
- Delivery measures from pull requests, releases and deploys (lead time, change failure rate, time
  to restore), to show whether agent work speeds delivery without more failures.

In the product, before any assistant writes:

- The database, not only the Edge Functions, refuses a `client_id` token on every write RPC and
  table, proven by pgTAP; grants, an access log and per-client rate limits
  ([mcp-read](../roadmap/mcp-read.md)).
- Mandates checked by `app.assert_agent_mandate` under the lock order, and the allowlist test split
  into "an agent may call" and "an agent never calls" ([agent-limits](../roadmap/agent-limits.md)).
- Attribution of every write (`source`, `via_client_id`, `mandate_id`) and audit seals that
  `verify_audit` checks ([audit-screen](../roadmap/audit-screen.md)).
- Drafts confirmed by a tap, and the amount grammar with its hand-written vectors in Dart and
  TypeScript ([draft-payments](../roadmap/draft-payments.md),
  [amount-parser](../roadmap/amount-parser.md)).
- Munshi's evaluation set and the accuracy target the owner sets
  ([whatsapp-assistant](../roadmap/whatsapp-assistant.md)), with a held-out part, which the plan
  does not have yet.
- The retracting RPC of every write an agent may call, tested in pgTAP, and a TLA+ property that no
  open draft or pending action outlives a revocation.
- Each MCP tool's output schema in `contracts/`, with a check that a new version only adds fields.
- A written way to replace each AI provider and each service that agents reach.
- Public claims about agents (the deck, the pricing page) that match what the database enforces.

Background, from papers the owner shared: Peter Bell, _Scaling AI Adoption in Engineering_ (early
release, 2026), for persistent context, one bar for all code, red lines, guard rails and off-ramps;
Dhruv Srikanth and others, _Recursive self-improvement of AI research agents_ (2026), for held-out
evaluation at a fixed cost over several runs, bounded context and gates an agent must not move;
Yifan Shi, Wei Zhang and Tianyi Cui, _A Programming Paradigm for Spatiotemporal Composability_
(preprint, 2026), for limits enforced below the agent rather than in it, writes paired with their
retraction, and tool outputs that only gain fields; and Leslie Lamport, _How to Write a Proof_
(1993), by analogy, for evidence over convincing prose and no "similarly".

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

| Task                                                                 | Skills and tools                                                                                                  |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Is a release ready to tag?                                           | `release-readiness-audit`                                                                                         |
| Testing the repository's command-line tools and scripts              | `cli-tool-qa`                                                                                                     |
| Screens, tokens, components, accessibility, design QA                | `design-systems-engineering`, browser use, computer use                                                           |
| READMEs, guides, specs, agent context                                | `project-documentation`, `llm-context-modular-docs`                                                               |
| Planning and tracking multi-step work                                | `gsd` (the `.planning/` directory)                                                                                |
| Writing and reviewing code                                           | `code-quality-standards`, `code-review`                                                                           |
| Formal models and proofs                                             | the pinned TLC, Lean, Z3 and Bend (`make formal-install`), and each tool's own documentation                      |
| Workflow scripts that run agents, and the briefs they give subagents | `workflow-authoring`                                                                                              |
| In-product assistants: prompts, tools and evaluation sets            | the chosen provider's own documentation, through Context7 or its MCP server; the provider is the owner's decision |
| The website's search and AI-search health                            | `seo-audit`                                                                                                       |
| Copy against the brand's voice                                       | `brand-review`                                                                                                    |
| A library's or service's current API                                 | Context7, the service's own MCP server or documentation; never memory alone                                       |

If a decision is the owner's, or you are blocked, ask: the owner has said to.
