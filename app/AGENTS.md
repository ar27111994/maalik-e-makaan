# app/AGENTS.md

The Flutter app (`maalik_e_makaan`) for Android, iOS and the web: Riverpod 3, go_router 18,
`supabase_flutter`, English and Urdu. The root [`AGENTS.md`](../AGENTS.md) rules apply; this file
adds what is specific here. Architecture in depth: [`docs/architecture/app.md`](../docs/architecture/app.md).
Who may do what: [`docs/architecture/permissions.md`](../docs/architecture/permissions.md).

## Where things are

| Path                                               | What                                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `lib/src/bootstrap.dart`, `app.dart`               | Start-up, `MaterialApp`, themes, localisation, `MmLicenses.register()`                      |
| `lib/src/config/app_config.dart`                   | Configuration from `--dart-define-from-file`; refuses secret keys                           |
| `lib/src/core/`                                    | `AppFailure` and `failureMessage`, dates, validation, text limits, SWR helper               |
| `lib/src/data/`                                    | Supabase client providers, `SwrCache`, keyset `paging.dart` (50 rows), ids, retry           |
| `lib/src/auth/`, `settings/`, `routing/`, `shell/` | Sign-in, settings, routes, adaptive navigation shell                                        |
| `lib/src/features/<feature>/`                      | `data/` (models, repository), `application/` (providers, notifiers), `presentation/`        |
| `lib/l10n/arb/`                                    | `app_en.arb` (template) and `app_ur.arb`; `lib/l10n/generated/` is generated                |
| `config/*.example.json`                            | Local and production configuration templates; the real files are not committed              |
| `test/support/`                                    | `harness.dart` (`pumpScreen`, `testEveryVariant`, `screenGoldenEveryVariant`), fakes, fonts |
| `test/src/goldens/`                                | Screen goldens; images in `test/src/goldens/goldens/`                                       |

## Rules here

- Dependencies point down: presentation → application → data → Supabase. Only a repository
  talks to Supabase, and it converts every error with `AppFailure.from`.
- Models are immutable with a strict `fromRow`; money is `Money` (`Money.fromJson`), dates
  `CalendarDate`. No `double` for money.
- Reads filter by the current portfolio and page by `created_at, id`. Writes are pessimistic and
  safe to retry: client-chosen ids, idempotency keys for payments and deposit applications,
  status-only updates. The rules and their exceptions are in `docs/architecture/app.md`.
- Every visible string is an ARB key in both files with an `@key` description; run
  `make codegen` after editing them.
- UI comes from `mm_ui`; no literal colours, sizes, radii or durations (`make design-lint`).
- The UI hides what a role cannot do, but the database is the authority; do not add client-only
  permission checks as protection.

## Commands

```sh
make test-app                               # tests, goldens, 90% line-coverage gate
make goldens                                # re-record goldens (Linux only; review every image)
make codegen                                # after editing an ARB file
make build-web-app                          # needs app/config/production.json
cd app && flutter analyze --fatal-infos     # what make analyze runs here
cd app && flutter test test/src/features/ledger   # one folder
```

Against a local Supabase stack (`supabase start`, which needs Docker):

```sh
cp app/config/local.example.json app/config/local.json   # paste the publishable key it prints
cd app && flutter run --dart-define-from-file=config/local.json
```

## Known gaps

No Flutter integration tests (`make test-integration` has no `integration_test/` to run). The
end-to-end tests are the browser UAT in `app/uat/` (`make test-uat`, [`docs/uat.md`](../docs/uat.md)):
Playwright drives the release web build against a local Supabase stack, so the REST requests are
checked against a running PostgREST for the journeys it covers. iOS is not built in this
environment.
