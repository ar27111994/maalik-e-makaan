# Documentation

Where each topic is written down. Start with the [README](../README.md) for what the product is
and how to run it, and [CONTRIBUTING.md](../CONTRIBUTING.md) before a pull request.

## Architecture

| Document                                                             | What it covers                                                                                                      |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [`architecture/app.md`](architecture/app.md)                         | How the Flutter app reads, writes, caches, retries and fails: layers, models, repositories, uploads, open questions |
| [`architecture/permissions.md`](architecture/permissions.md)         | Who can do what in a portfolio, how the database enforces it, the global lock order and what it costs               |
| [`../.planning/PROJECT.md`](../.planning/PROJECT.md)                 | The product, its users, the stack, the key decisions D-01 to D-19 and the open proposals P-01 and P-02              |
| [`../DESIGN.md`](../DESIGN.md)                                       | The visual language: tokens, type, colour, components, Urdu and right-to-left rules                                 |
| [`../packages/mm_ui/COMPONENTS.md`](../packages/mm_ui/COMPONENTS.md) | How the design system's components are built, and the catalogue                                                     |
| [`../packages/mm_core/README.md`](../packages/mm_core/README.md)     | The domain library's modules: money, time, identity, text, rent, ledger                                             |
| [`../website/README.md`](../website/README.md)                       | The website's code, content, calculators, security headers and deployment                                           |

## Operations

| Document                                                 | What it covers                                                                                                                                                                                                                                   |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`operations.md`](operations.md)                         | Scheduled jobs, storage cleanup set-up, health checks, monitoring and alerts, Edge Function secrets, Vercel hosting, the Deploy workflow, releasing, rollback, backups and restore, account deletion, applying a migration to the hosted project |
| [`../SECURITY.md`](../SECURITY.md)                       | Reporting a vulnerability                                                                                                                                                                                                                        |
| [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) | Third-party packages, fonts and icons, their licences and what each asks                                                                                                                                                                         |

## Quality

| Document                                                                     | What it covers                                                                                   |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| [`uat.md`](uat.md)                                                           | Browser UAT: the landlord journeys on a local Supabase stack (`make test-uat`), results, defects |
| [`release-readiness.md`](release-readiness.md)                               | The v1.0 release-readiness verdict, the checklist with evidence, and the owner's actions         |
| [`design-qa.md`](design-qa.md)                                               | The automated design gates, the review checklist, the verdicts per surface and open follow-ups   |
| [`../formal/README.md`](../formal/README.md)                                 | The formal verification tracks (TLA+, Lean 4, Z3, Bend), their findings and how to run them      |
| [`../packages/mm_ui/example/README.md`](../packages/mm_ui/example/README.md) | The design-system gallery and its screenshots, the UAT record                                    |

## Planning

| Document                                                       | What it covers                                                                                           |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [`../.planning/STATE.md`](../.planning/STATE.md)               | Where the project is now: position, hosted project, blockers, follow-ups                                 |
| [`../.planning/REQUIREMENTS.md`](../.planning/REQUIREMENTS.md) | The v1.0 requirements and what remains of each                                                           |
| [`../.planning/ROADMAP.md`](../.planning/ROADMAP.md)           | The twelve phases of milestone v1.0                                                                      |
| [`roadmap/README.md`](roadmap/README.md)                       | After v1.0: the milestones and their items, a plan for each, the order of work and the owner's decisions |

## For coding agents

[`../AGENTS.md`](../AGENTS.md) is the entry point. It routes to the per-area `AGENTS.md` files and
to [`agents/`](agents/README.md): commands, conventions, workflows and the quality bar.
[`../llms.txt`](../llms.txt) indexes this documentation for AI readers.

## Changelog

`CHANGELOG.md` at the repository root is written by release-please from the Conventional Commit
messages (`release-please-config.json`, `changelog-path: CHANGELOG.md`) when it opens a release pull
request; do not write it by hand. The first release was v1.0.0 on 2026-11-09; release-please now picks
each next version from the commits since the last tag. `packages/mm_core/CHANGELOG.md` and
`packages/mm_ui/CHANGELOG.md` point to it.
