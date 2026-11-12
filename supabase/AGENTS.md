# supabase/AGENTS.md

The backend: PostgreSQL 17 on Supabase (migrations, row-level security, RPCs, pg_cron jobs),
pgTAP suites and four Deno Edge Functions. The root [`AGENTS.md`](../AGENTS.md) rules apply; this
file adds what is specific here.

Deeper: [`docs/architecture/permissions.md`](../docs/architecture/permissions.md) (who may do
what, and the concurrency costs), [`docs/operations.md`](../docs/operations.md) (jobs, secrets,
health checks, deployment, the hosted apply process), `.planning/PROJECT.md` D-04 to D-07 and
D-13 to D-15.

## Where things are

| Path                      | What                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `migrations/`             | The chain, `<UTC timestamp>_<name>.sql`, applied in order                                  |
| `tests/database/`         | pgTAP suites `NN_<name>.test.sql` and `_helpers.psql`; 10, 12, 13, 20 and 23 are generated |
| `seed.sql`                | Demo data (`tool/db/reset.sh --seed`)                                                      |
| `local/supabase_shim.sql` | Emulates the Supabase roles and schemas on a plain PostgreSQL for `tool/db/test.sh`        |
| `config.toml`             | Local stack settings; every function has `verify_jwt = false` and checks the token itself  |
| `functions/<name>/`       | `delete-account`, `invite-member`, `health`, `storage-cleanup`                             |
| `functions/_shared/`      | CORS, config, crypto, errors, rate limits, validation, `database.types.ts` (generated)     |
| `functions/tests/`        | Unit tests (100% gate), snapshots, `e2e/` against a running stack                          |
| `functions/.env.example`  | The function secrets, for local development                                                |

Database tooling lives in `tool/db/`: `test.sh`, `reset.sh`, `upgrade_test.sh` with
`upgrade/<version>.*.sql`, `concurrency_test.sh`, `stress_test.sh`, `lint_migrations.sh`,
`schema_fingerprint.sql`, `fingerprint_diff.py` and `time_zone_skew.sql` (generated; run on the
hosted project after a Postgres or `tzdata` upgrade, `docs/operations.md`).

## Rules here

- New migration for every change; never edit an applied one. Migrations after the `.squawk.toml`
  baseline must pass squawk (`make lint`).
- Lock order: account, portfolio, lease, other rows. Client writes go through
  `app.lock_my_portfolio_ids`; write RPCs are `SECURITY DEFINER`, check the role, and are pinned
  in `tests/database/01_schema_security.test.sql`. Read RPCs are `SECURITY INVOKER`.
- Grants are explicit and column-level where a client must not write a column (D-13).
- Money is `numeric(14,2)`; financial rows are voided, never deleted.
- Every stored text, phone, CNIC and IBAN passes a CHECK that matches what `mm_core` reads back.
- Never apply anything to the hosted project (`aaifamxzzjspohwksxyr`) from an agent session
  unless the owner asks; the process is "After every migration" in `docs/operations.md`.

## Commands

```sh
make test-db                    # every migration, every pgTAP suite, then the upgrade tests
make test-db-concurrency        # parallel scenarios and invariants
make test-db-stress             # latency budgets, index use, pgbench
tool/db/test.sh supabase/tests/database/05_ledger.test.sql   # one suite
MM_TEST_DB=my_db tool/db/reset.sh --seed                    # a disposable database
make test-functions             # Edge Function tests, 100% lines, branches and functions
make test-functions-e2e         # needs supabase start (Docker)
```

The local PostgreSQL 16 runs on `127.0.0.1:54329` (`tool/db/env.sh`). Start it with
`su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/mm16 -l /var/lib/postgresql/mm16.log -w start"`.
