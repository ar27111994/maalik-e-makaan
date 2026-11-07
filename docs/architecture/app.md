# App architecture

How the Flutter app in `app/` is organised, so every feature reads, writes,
caches and fails the same way. Read it before adding a screen.

## Layers

```text
app/lib/src/
  bootstrap.dart, app.dart     start-up, MaterialApp, themes, localisation
  config/                      AppConfig from --dart-define (refuses secret keys)
  core/                        AppFailure and failureMessage (every error, both languages)
  data/                        Supabase client, offline cache (SwrCache), shared providers
  auth/  settings/  routing/  shell/
  features/<feature>/
    data/          models and the repository (the only code that talks to Supabase)
    application/   Riverpod providers and notifiers: queries and commands
    presentation/  screens and feature widgets, built from packages/mm_ui
```

Dependencies point down: presentation → application → data → Supabase. A
screen never calls Supabase, and a repository never touches Flutter widgets.
Domain logic that is not about I/O (money, dates, rent maths, CNIC/phone/IBAN
checks) lives in `packages/mm_core` and is shared with the tests and contracts.

## Models

- Immutable, hand-written classes with value equality and a `fromRow`
  constructor that reads a PostgREST row strictly: a missing or mistyped field
  throws `FormatException` (the repository turns it into a `ServerFailure`).
- Money is `Money` from `mm_core` (integer paisa), decoded with
  `Money.fromJson`, which is exact for every value `numeric(14,2)` can hold.
  Never `double` for money.
- Dates without a time are `CalendarDate` (`CalendarDate.fromJson`);
  timestamps are UTC `DateTime` shown in Pakistan time.
- Enumerations mirror the database enums one to one, with an `unknown` case
  only where a newer server could send a value an older app does not know.

## Repositories

- One per aggregate (portfolios and team, properties and units, tenants,
  leases, ledger, operations, documents, reports, notifications), each an
  abstract interface plus a `Supabase…Repository`.
- Reads select only the columns the screen needs, always filter by the current
  portfolio, and page with keysets (`created_at, id`), 50 rows at a time.
- Writes follow the database's rules:
  - money and membership changes go through their functions (`record_payment`,
    `void_payment`, `update_charge`, `change_rent`, `end_lease`,
    `update_member_role`, …); a charge is edited only through `update_charge`
    (clients cannot `UPDATE` charges);
  - other edits insert or update only the columns the client is granted
    (see `docs/architecture/permissions.md`).
- Every Supabase error is converted with `AppFailure.from` at the repository
  boundary, so callers only ever see `AppFailure`.

## Reading: stale while revalidate

Lists and dashboards show the last saved result at once, then the fresh one.
`SwrCache.watch` emits the cached snapshot (marked with when it was saved),
then the server's answer; the cache key is the user, the portfolio and the
query with its parameters. Signing out clears the user's cache. A screen shows
"Offline, showing what was saved at …" when the refresh fails with a
`NetworkFailure` and data is on screen; otherwise it shows the error with a
retry.

## Writing: commands

- A command is a method on an `AsyncNotifier` that calls the repository, then
  invalidates the queries it affects.
- Writes are pessimistic: the button shows progress and the screen updates
  when the server answers. Money is never shown as recorded before it is.
- `record_payment` takes an idempotency key: the form creates one UUID when it
  opens and reuses it for every retry until the payment is recorded, so a
  dropped connection never records a payment twice. (Queuing payments while
  offline is not in v1.)
- Refusals show `failureMessage`: inline next to the field when the reason
  belongs to one (`invalid_amount`), otherwise in a snackbar or dialog.

## State

- The current portfolio is chosen once and remembered on the device; every
  feature provider depends on it, so switching portfolios refreshes them all.
- Providers are scoped to what a screen needs; nothing global holds lists.
- Roles come from the membership row; the UI hides what a role cannot do, and
  the database enforces it anyway.

## Testing

- Models: `fromRow` with real PostgREST JSON, including malformed rows.
- Repositories: a `SupabaseClient` built on `package:http`'s `MockClient`, so a
  test asserts the exact REST or RPC request and returns the server's JSON;
  every error path maps to the right `AppFailure`.
- Notifiers: `ProviderContainer.test` with fake repositories.
- Screens: widget and golden tests in light, dark, high-contrast, Urdu and
  large-text variants, with the tap-target and contrast guidelines; the design
  lint keeps values on tokens.
- End to end: the local Supabase stack in CI.
