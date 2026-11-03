---
active_phase: "1"
next_action: execute-phase
next_phases: ["1", "2"]
progress: { total_phases: 12, completed_phases: 0, percent: 0 }
---

# Project State: Maalik-e-Makaan

## Current Position

- Milestone: v1.0. Phase: 1 (Foundations). Last action: new-project (research, requirements,
  roadmap).
- Next: finish the `mm_core` domain package and the repository tooling, then Phase 2 (database).

## Active Decisions

- See PROJECT.md D-01…D-13. Most load-bearing: D-04 (RLS plus composite foreign keys), D-05 (exact
  money), D-06/07 (ledger and idempotent payments), D-10 (no tax estimate) and D-13 (opt-in Data
  API).

## Environment Notes (for future sessions)

- The Flutter SDK is at `/opt/flutter`; add `export PATH=/opt/flutter/bin:$PATH`.
- Local Postgres 16 with pgTAP and pg_cron:
  `pg_ctl -D <scratchpad>/pgdata start` on port 54329. Run `tool/db/test.sh`.
- Docker image pulls are blocked in the agent container, so `supabase start` only runs in CI.
- `*.supabase.co` and `supabase.com` are blocked from the container. Use the Supabase MCP tools
  for the hosted project (`aaifamxzzjspohwksxyr`).
- GitHub `git ls-remote` works, which is how GitHub Actions get pinned to commit SHAs.

## Blockers

- None.

## Completed Phases

- (none yet)

## Session Notes

2026-11-03:

- Kicked off the project.
- The user confirmed: a new Supabase project, Flutter plus Astro, and Vercel hosting.
- Research briefs are archived in `.planning/research/`.
