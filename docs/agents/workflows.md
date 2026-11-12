# Workflows

Step-by-step recipes for the changes agents make most often. Each ends with the checks to run.
Facts (targets, rules, generated files) are in [`commands.md`](commands.md) and
[`conventions.md`](conventions.md); this file is the order of work.

## Change the database

1. `supabase migration new <name>` creates `supabase/migrations/<UTC timestamp>_<name>.sql`.
   Never edit an existing migration. Start the file with a comment block that says what it
   changes and why (see `20261108200216_identity_checks.sql`).
2. Keep the lock order (account, portfolio, lease, other rows), grant columns explicitly, enable
   row-level security on any new table and pin `search_path = ''` on every `SECURITY DEFINER`
   function (`01_schema_security.test.sql` checks it).
3. A new write RPC that signed-in users call is `SECURITY DEFINER`, checks the caller's role, and
   is added to the allowlist in `supabase/tests/database/01_schema_security.test.sql`. A read RPC
   is `SECURITY INVOKER`.
4. Add a pgTAP suite `supabase/tests/database/<next number>_<name>.test.sql` (`\ir _helpers.psql`,
   `select plan(n)`). Rule changes also update `03_rls_matrix.test.sql` and
   `docs/architecture/permissions.md`.
5. Rows written in parallel: add a scenario to `tool/db/concurrency_test.sh`, opened with
   `scenario <budget s> <lock wait s> "<n>. <title>"`: past the budget its watchdog prints the
   sessions and locks and fails the run, and no statement waits for a lock longer than the lock
   wait. Existing rows changed: add `tool/db/upgrade/<version>.before.sql` and `.after.sql` (and
   `.refused.sql` or `.race.sql` when the migration may refuse to run).
6. Run `make lint test-db test-db-concurrency`. If the change touches the ledger, locks or money,
   also `make verify` and update the matching `formal/` track.
7. Do not apply it to the hosted project yourself. The owner applies it as
   [`docs/operations.md`](../operations.md#after-every-migration) describes, and the local file
   takes the version the platform records.

## Change money or rent maths

The same rule lives in `mm_core` (Dart), in SQL and in the website's calculators, and is pinned
by `contracts/`.

1. Change `packages/mm_core/lib/src/rent/` or `money/` and its tests (100% line coverage).
2. Change the SQL in a new migration.
3. Update `tool/contracts/generate.py` if the vectors change, then `make contracts`.
4. Run `make test-core test-db contracts-check test-web` and `make verify` (the Lean, Z3 and Bend
   tracks prove the arithmetic equal to the SQL).

## Add or change an app screen

1. Read [`app/AGENTS.md`](../../app/AGENTS.md) and
   [`docs/architecture/app.md`](../architecture/app.md).
2. Data access goes in the feature's `data/` repository, state in `application/`, widgets in
   `presentation/`, built from `mm_ui` components.
3. Add strings to both ARB files, then `make codegen`. Write the Urdu with the plain-Urdu
   glossary, `contracts/urdu_glossary.json`, and run `python3 tool/check_urdu_words.py` on the
   ARB file. A change to `appName` in `app_en.arb` also renames the web app: run
   `make app-icons`, which writes it into `app/web/manifest.json`.
4. Add widget tests and goldens in the six variants; record them with `make goldens` on Linux and
   review every image.
5. Run `make format-check analyze design-lint test-app`.

## Change the design system

1. Visual values: edit `design/tokens/maalik.tokens.json`, then `make tokens`. Icons: add the
   Lucide name to `design/icons/icons.json`, then `make icons` (needs `npm ci`). A change to
   `primary`, `onPrimary` or the light `bg`, or to the mark in `website/src/lib/brand.ts`, also
   changes the app's launcher icons: run `make app-icons` and look at every changed image (and
   `npm run og` in `website/` for the site's own icons).
2. Components: follow `packages/mm_ui/COMPONENTS.md`; keep the API additive, because the app
   depends on it.
3. Add the component to its family's gallery page in `packages/mm_ui/example/lib/src/pages/`.
4. Run `make tokens-check icons-check app-icons-check test-ui test-gallery test-app` (the app's
   goldens show whether a change leaks into its screens).

## Change an Edge Function

1. Code in `supabase/functions/<name>/`, shared code in `_shared/`, tests in
   `supabase/functions/tests/`.
2. A new secret goes in `supabase/functions/.env.example` and the secrets table in
   `docs/operations.md`.
3. After a migration that changes an RPC the functions call, regenerate
   `_shared/database.types.ts` (`docs/operations.md`).
4. Run `make test-functions` (100% lines, branches and functions) and
   `cd supabase/functions && deno fmt --check && deno lint && deno task check`.

## Change the website

Follow [`website/README.md`](../../website/README.md) ("Add a page", "Add a guide"), then
`make test-web`.

## Change documentation

1. Update the doc in the same change as the code it describes. The index is
   [`docs/README.md`](../README.md); per-area context is each `AGENTS.md`.
2. Every command you write is one you ran; every path is one that exists.
3. Run `make format-check-repo lint` (Prettier and markdownlint cover every `*.md`).
