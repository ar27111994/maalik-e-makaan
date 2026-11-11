# App architecture

How the Flutter app in `app/` is organised, so every feature reads, writes,
caches and fails the same way. Read it before adding a screen.

## Layers

```text
app/lib/src/
  bootstrap.dart, app.dart     start-up, MaterialApp, themes, localisation
  config/                      AppConfig from --dart-define (refuses secret keys)
  core/                        AppFailure and failureMessage (every error, both languages),
                               dates, validation, text limits, SwrNotifier
  data/                        Supabase client, offline cache (SwrCache), shared providers,
                               keyset paging, client-chosen ids, provider retry
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

- One per aggregate (auth, account and profile, portfolios, team, properties
  and units, tenants, leases, ledger, cash handovers, reminders, operations,
  documents, insights and reports, notifications), each an abstract interface
  plus a `Supabase…Repository`.
- Reads select only the columns the screen needs, always filter by the current
  portfolio, and page with keysets (`created_at, id`), 50 rows at a time
  (`app/lib/src/data/paging.dart`). A list that must be in another order and
  stays short is read whole up to 50 rows, without paging (the unpaid bills,
  earliest due first). Ordering a long list by anything else is an open
  question; see [Open questions](#open-questions).
- Writes follow the database's rules:
  - money and membership changes go through their functions (`record_payment`,
    `void_payment`, `update_charge`, `change_rent`, `end_lease`,
    `update_member_role`, …);
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
  offline is not in v1.) `apply_deposit` takes a key the same way.
- Refusals show `failureMessage`: inline next to the field when the reason
  belongs to one (`invalid_amount`), otherwise in a snackbar or dialog.

### Retries and lost answers

A request can reach the server and its answer still be lost. Every command
is safe to send again, or says why it is not:

- **New rows** get their `id` from the app, chosen once when the form opens
  and kept for every retry. When an insert fails with a unique violation
  (`23505`), the repository reads the row with that `id`: if it is there, the
  first try stored it and it is returned; if not, another row clashed and the
  insert is refused with the form's own reason (for example
  `duplicate_bill_month`). A form whose first try stored different values
  says so ("This was already saved, as first entered. Your later changes were
  not saved").
- **Payments and deposit applications** carry an idempotency key (see above).
- **Deposit refunds**: `refund_deposit` takes no key. After a `NetworkFailure`
  the ledger is read again, and a refund that was not there before, is not
  voided, and has the same amount, date and method is taken as the one sent.
  If none is found the failure is passed on, and the sheet closes and asks the
  landlord to check the deposit instead of offering to send it again: the
  refund may still have been recorded (`TenancyLedgerController.refundDeposit`,
  `RefundDepositSheet`).
- **Charges** are changed only through `update_charge`; clients cannot
  `UPDATE` charges. A null argument keeps the value and an empty note clears
  it; only a charge added by hand can change its amount.
- **Status changes** write only the status columns, never the whole row from
  the copy on screen, so a tap on a stale screen cannot undo someone else's
  edit: `setBillPayment` sends `status`, `paid_on` and `paid_by`;
  `moveMaintenanceRequest` sends `status`, `resolved_on` and
  `resolution_note`. Editing a bill's details leaves whether it is paid as
  stored.

### Uploading a document

A document is a file in the private `documents` bucket and a row in
`documents` that points at it. The database refuses a row whose file is
missing (`document_file_missing`) or queued for deletion
(`document_file_pending_deletion`), so the order is fixed:

1. When a file is picked, the upload gets one uuid. It is the document's `id`
   and the file's name: `<portfolio_id>/<entity>/<entity_id>/<uuid>.<ext>`.
2. The file is uploaded first. A `409` means an earlier try of this upload
   stored it already, and counts as success.
3. Then the row is inserted with that `id`. A primary-key violation on a retry
   returns the row the first try added.
4. Retries reuse the same uuid, so a retry never stores the file twice or adds
   a second row.
5. If the row is refused with `document_file_missing`, the file is uploaded
   again under the same uuid. If it is refused with
   `document_file_pending_deletion` (the file waited without a row long enough
   for the daily sweep to queue it), the upload gets a new uuid and the file
   is uploaded again under it. Either way the row is tried once more before
   the refusal is shown.
6. If the landlord gives up with the file stored and no row written, owners
   and managers delete the file on the spot (the storage delete policy lets
   them delete a file no row refers to; failures are ignored). Accountants may
   upload but not delete files, so their abandoned file stays until the daily
   sweep queues it, a day after it was uploaded, and `storage-cleanup` deletes
   it (see "Documents and files" in `docs/architecture/permissions.md`). An
   upload still running when its sheet closes is left to finish.

Photos are encoded again from their pixels as JPEG before upload, which drops
Exif, GPS and other metadata. A file the device cannot decode (HEIC in most
browsers) has its metadata segments removed byte by byte
(`documents/data/image_metadata.dart`). Links to a file are signed for five
minutes (`DocumentRepository.linkLifetime`) and made again every three
minutes while its sheet is open. A document list shows photos as thumbnails:
one request signs a link for every photo it shows (`thumbnailLinks`), and the
links are signed again before they expire; a file that cannot be signed keeps
its row's icon.

#### A camera photo Android lost

On a phone short of memory, Android may close the app while the camera app is
in front. The photo is then not returned to the sheet that asked for it:
`image_picker` keeps it for the app's next start (`retrieveLostData`). So that
it is not lost, and still goes to the right record:

1. On Android, before the camera opens, the add-document sheet remembers the
   target in the device's preferences (`CameraTarget`, key
   `mm.documents.camera_target`, behind `CameraTargetStore`): the signed-in
   user, the portfolio, the record (entity and id), the path of the record's
   screen, and when the camera opened. The write finishes before the camera
   opens. When the camera answers (a photo, a cancel or a refusal) the target
   is forgotten. iOS and the web never lose a photo, so nothing is written
   there (`cameraLosesPhotosProvider`).
2. When the app starts, once the user is signed in and their portfolios are
   known, `LostPhotoRecovery` (around the signed-in shell) asks once per run
   for a lost photo (`DocumentPicker.recoverLostPhoto`), on Android only. On
   iOS and the web it does not ask, and a target an older version left there
   is forgotten. It does not ask again when the app comes back to the
   foreground, because a run that was not closed gets its photo from the
   camera itself.
3. `recoverLostPhoto` decides. The photo comes back only if all of these
   hold: a readable target says which record it is for; the same user opened
   the camera; the camera opened at most a day ago (`lostPhotoMaxAge`); the
   member still belongs to the portfolio with a role that adds documents; and
   the record still takes documents (`ownerTakesDocuments`, a `select` under
   the record's row policy that leaves out an archived property, unit or
   tenant and a voided payment, whose screens offer no "Add document"). A day
   still covers a landlord called away just after taking the photo. Older
   photos are let go, so that a photo of a CNIC never appears days later on a
   record the landlord has forgotten. If the record cannot be checked (no
   connection, or no answer within five seconds, `lostPhotoCheckLimit`), the
   photo is kept, because the database checks the record again on upload.
   Otherwise the photo is let go without a message, and the app does not move.
   If the camera had failed, the usual failure message is shown. In every case
   the target is forgotten, unless a camera opened in the meantime has stored
   a new one; a device that cannot remove it still gets its photo.
4. The app can be used while this runs. If the landlord is still on the screen
   and in the portfolio they were in when it started, a photo that comes back
   takes them to its portfolio and record (`GoRouter.go` to the remembered
   path). If they have moved on, they are not pulled away: a snackbar says the
   photo was kept, and its "Show photo" action takes them there; if they let
   it pass, the photo is let go. On the record, its documents section opens
   the add-document sheet with the photo already chosen. A banner says that
   the photo was kept when the app closed. The photo goes through
   `prepareFile` like any other: it is made smaller and its metadata is
   removed. Nothing is uploaded until the landlord taps Upload. If the record
   was archived in the meantime, or the role does not upload, the section lets
   the photo go.

The camera's own copy of the photo stays in the app's cache directory, as it
does for every camera photo, until Android clears it.

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
- End to end: the local Supabase stack in CI. Not built yet for the app: the
  REST requests (including foreign-key embed names such as
  `utility_bills_charge_id_fkey`) are checked against the SQL by hand, not
  against a running PostgREST.

## Open questions

### Ordering long lists by something other than when they were added

Keyset paging over `created_at, id` gives exact pages at any depth with one
index range scan, and the cache stores one cursor shape. The cost is that
every paged list is in the order rows were added. Two screens want another
order:

- maintenance requests to do, by priority (urgent first) and then by date;
- expenses, by the day the money was spent (`spent_on`) rather than the day it
  was recorded.

The options, for the owner to decide:

1. **Keep the order rows were added** (today). Paging stays exact and cheap,
   and a back-dated expense appears at the top, where the person who just
   entered it looks for it. An urgent repair reported after many others is
   not at the top; its priority badge is the only signal.
2. **A keyset per order**: `(priority, created_at, id)` for requests and
   `(spent_on, created_at, id)` for expenses. Pages stay exact. It needs a
   cursor type per order, matching indexes (today's are
   `(portfolio_id, status, reported_on desc)` and
   `(portfolio_id, spent_on desc)`, neither ending in `created_at, id`), and a
   cache that keeps the cursor's shape.
3. **Read the short list whole**, as the unpaid bills are: the requests still
   to do, up to a limit, sorted by priority; closed requests and expenses stay
   paged. It is simple, but anything past the limit is silently not shown
   unless the screen says so.

The operations review recommended deciding this before release; the current
code is option 1.
