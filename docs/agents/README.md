# Agent context

Modular context for coding agents. Load the root [`AGENTS.md`](../../AGENTS.md) first, then only
the file a task needs.

| File                               | Kind      | Load it to                                                                                                      |
| ---------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------- |
| [`commands.md`](commands.md)       | Reference | find the `make` target for an area, its gate, its prerequisites and its CI job                                  |
| [`conventions.md`](conventions.md) | Reference | check a rule: commits, language, money, database, secrets, design, goldens, generated files                     |
| [`workflows.md`](workflows.md)     | How-to    | make a common change in the right order: migration, money maths, screen, design system, function, website, docs |
| [`quality-bar.md`](quality-bar.md) | Reference | check what done means for the frontend, testing, CI/CD, the API and database, and docs, and today's gates       |

Per-area context, loaded when you work in that directory:

| Area                   | File                                                             |
| ---------------------- | ---------------------------------------------------------------- |
| Flutter app            | [`app/AGENTS.md`](../../app/AGENTS.md)                           |
| Design system          | [`packages/mm_ui/AGENTS.md`](../../packages/mm_ui/AGENTS.md)     |
| Domain library         | [`packages/mm_core/AGENTS.md`](../../packages/mm_core/AGENTS.md) |
| Database and functions | [`supabase/AGENTS.md`](../../supabase/AGENTS.md)                 |
| Website                | [`website/AGENTS.md`](../../website/AGENTS.md)                   |
| Formal verification    | [`formal/AGENTS.md`](../../formal/AGENTS.md)                     |

Deeper documents are indexed in [`docs/README.md`](../README.md) and, for AI readers outside the
repository, in [`llms.txt`](../../llms.txt).
