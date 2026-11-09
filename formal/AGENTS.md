# formal/AGENTS.md

Machine-checked models and proofs of the code where a test can miss a bug: TLA+ models of the
concurrent database paths, and Lean 4, Z3 and Bend proofs of the money arithmetic shared by Dart
and SQL. The root [`AGENTS.md`](../AGENTS.md) rules apply. [`README.md`](README.md) is the full
guide: the tracks, what each proves, the findings and the migrations that fixed them, the pinned
tools and the timings. Each track's own `README.md` cites the code it follows.

## Rules here

- A track follows the code as it is now: for SQL, the last definition of each function across
  `supabase/migrations`. A change to that code updates the track in the same pull request.
- Every check states its expected outcome, and a mismatch either way fails, so a mutant that is
  not caught fails the run. Keep each finding as a failing configuration or mutant; when a
  migration fixes it, flip the baseline and keep the old code as a mutant.
- `run.sh [ci|all]` per track; `ci` stays under a few minutes (it runs on every push). A new
  track is added to `TRACKS` in `tool/formal/verify.sh`; a new tool goes into
  `tool/formal/install.sh` with its URL and sha256.
- The tools are the exact versions `make formal-install` pins and checksums into `.cache/formal`
  (TLC 2.19, Lean 4.35.0 and 4.34.0, z3-solver, Bend 2.0.39); a variable you set yourself
  overrides `.cache/formal/env.sh`. CI runs the pinned set.

## Commands

```sh
make formal-install                          # about 1.3 GB to download; idempotent
make verify                                  # every track's ci set, as CI runs it
make verify-all                              # every configuration and mutant (Bend needs Dart and PostgreSQL)
tool/formal/verify.sh ci tla/RateLimit lean  # some tracks
formal/tla/LateFees/run.sh ci                # one track
```

The PostgreSQL replays of the findings are each track's `replay/run.sh` and
`tla/Invitations/replay_findings.sh`; they need the local PostgreSQL 16 (`tool/db/env.sh`).
