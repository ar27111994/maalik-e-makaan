# app/AGENTS.md

The Flutter app (`maalik_e_makaan`) for Android, iOS and the web: Riverpod 3, go_router 18,
`supabase_flutter`, English and Urdu. The root [`AGENTS.md`](../AGENTS.md) rules apply; this file
adds what is specific here. Architecture in depth: [`docs/architecture/app.md`](../docs/architecture/app.md).
Who may do what: [`docs/architecture/permissions.md`](../docs/architecture/permissions.md).

## Where things are

| Path                                               | What                                                                                                           |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `lib/src/bootstrap.dart`, `app.dart`               | Start-up, `MaterialApp`, themes, localisation, `MmLicenses.register()`                                         |
| `lib/src/config/app_config.dart`                   | Configuration from `--dart-define-from-file`; refuses secret keys                                              |
| `lib/src/core/`                                    | `AppFailure` and `failureMessage`, dates, validation, text limits, SWR helper                                  |
| `lib/src/data/`                                    | Supabase client providers, `SwrCache`, keyset `paging.dart` (50 rows), ids, retry, `device/` (the device wipe) |
| `lib/src/auth/`, `settings/`, `routing/`, `shell/` | Sign-in, settings, routes, adaptive navigation shell                                                           |
| `lib/src/features/<feature>/`                      | `data/` (models, repository), `application/` (providers, notifiers), `presentation/`                           |
| `lib/l10n/arb/`                                    | `app_en.arb` (template) and `app_ur.arb`; `lib/l10n/generated/` is generated                                   |
| `config/*.example.json`                            | Local and production configuration templates; the real files are not committed                                 |
| `test/support/`                                    | `harness.dart` (`pumpScreen`, `testEveryVariant`, `screenGoldenEveryVariant`), fakes, fonts                    |
| `test/src/goldens/`                                | Screen goldens; images in `test/src/goldens/goldens/`                                                          |

## Rules here

- Dependencies point down: presentation → application → data → Supabase. Only a repository
  talks to Supabase, and it converts every error with `AppFailure.from`.
- Models are immutable with a strict `fromRow`; money is `Money` (`Money.fromJson`), dates
  `CalendarDate`. No `double` for money.
- Reads filter by the current portfolio and page by `created_at, id`. Writes are pessimistic and
  safe to retry: client-chosen ids, idempotency keys for payments and deposit applications,
  status-only updates. The rules and their exceptions are in `docs/architecture/app.md`.
- Every visible string is an ARB key in both files, with its `@key` description in
  `app_en.arb` (the template: the generator reads descriptions from it alone, so `app_ur.arb`
  carries none); run `make codegen` after editing them.
- UI comes from `mm_ui`; no literal colours, sizes, radii or durations (`make design-lint`).
- The UI hides what a role cannot do, but the database is the authority; do not add client-only
  permission checks as protection.
- Whatever the app keeps on the device for an account (a preference, a file it writes or a plugin
  copies) is removed by `DeviceDataWipe` (`lib/src/data/device/`) when the session ends. A new one
  is added there, to its tests, to `docs/architecture/app.md` (On the device) and to the website's
  privacy page, in both languages. Display settings belong to the device and stay; the pending
  invitation stays until the account is deleted (see On the device); text the person copies is
  theirs. The cache serves one user at a time (`SwrCache.serve`): every cache operation names
  its user and the epoch it belongs to (`read`, `write`, `save`, `watch` and `SwrNotifier.show`
  take a required `epoch`), and does anything only while the cache serves that user in that epoch
  (`SwrCache.serves`), asking again after each store answer and before a build's request. What a
  notifier shows of an answer it saves is what `SwrCache.save` gives back, never `write`'s time:
  `save` asks again once the write has returned (the portfolio list alone is shown without waiting
  for the store: its `_save` asks `serves` and the state is set with nothing awaited between). A
  notifier that reads or saves for the session watches `sessionProvider` and takes its user and
  epoch from it, as `SwrNotifier`, `PortfoliosController`, `ProfileController`,
  `ResidenceController` and `AccountDeletionController` do; built for another user than the build before,
  or for nobody, it sets `state = sessionChanged()` before anything else, since Riverpod would
  keep the earlier account's value on show. A screen that shows a provider's error asks
  `waitsForSession(state)` first and shows that state as loading (`SnapshotView` does), as the
  account signed in now has not failed. A command reads `requestEpoch()` (in a
  controller that is not an `SwrNotifier`, `SwrCache.require`) before each request, or
  `shownEpoch` with the value on show it builds on: either throws `SessionExpired` once the
  session has ended, so a new command does the same, also before a second request. One that
  chooses something on the device after its request (the current portfolio) first asks
  `SwrCache.serves` with the epoch of that request: the same user's next session is served too,
  and the choice belongs to the session that asked. Every
  saved entry names its portfolio in its key: each `SwrNotifier` declares its `scope` (`InPortfolio` when its
  request filters by a portfolio it names, `FromValue` when its rows carry `portfolio_id`, or
  `UnknownPortfolio`, kept only until the session's first list of portfolios); only the list,
  the profile and the residence are the user's own (`OwnScope`). A new query picks the scope its
  fetch guarantees, its model reads `portfolio_id` when it is `FromValue`, and it gets a row in
  `test/src/data/cache/cache_scopes_test.dart`. A list answer of the server is numbered before
  its request (`SwrCache.ask`) and applied with `SwrCache.applyPortfolios`, which removes what
  the list does not name; a list the controller builds itself never takes a number. A setting
  kept per account (the current portfolio, the camera's target) is written only while the cache
  serves its user (`SwrCache.serves(userId, cache.epoch)`). A new command
  that shows a value gets a case in `test/src/core/swr_commands_test.dart`, which checks when it
  reads it. Each step of the wipe runs on its own and is bounded; a plugin that answers after its
  limit still has its answer acted on.
- The launcher icons are generated from the brand mark (`website/src/lib/brand.ts`) and the colour
  tokens by `make app-icons`: Android's `mipmap-*`, `drawable/ic_launcher_foreground.xml` and
  `values/ic_launcher_background.xml`, iOS's `AppIcon.appiconset`, `web/favicon.png`,
  `web/icons/` and the name, colours and icons in `web/manifest.json`, whose `name` and
  `short_name` come from `appName` in `lib/l10n/arb/app_en.arb`. Change the source instead, run
  `make app-icons` (also after renaming the app), then look at every changed image.

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
