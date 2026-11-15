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
  timestamps are UTC `DateTime` shown in Pakistan time. A person's own zone
  (`alertZoneProvider`) serves only their alerts, quiet hours and the second
  time an owner abroad sees; see [time](time.md).
- A stored country or time zone is read leniently (`CountryCode.fromJson`,
  `TimeZoneId.fromJson`): a well-formed value a newer build stored is kept,
  not refused, so an older app never fails on it.
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

### Residence, the owner-abroad answer and the caretaker

- `AccountResidence` is the signed-in user's own `profile_residences` row:
  `Residence` (country and time zone) and `statedAt`, which the server stamps.
  `ResidenceRepository.update` writes only the two values; `residenceProvider`
  reads it through the cache like the profile, and `alertZoneProvider` gives
  the zone of the user's alerts, Pakistan's when signed out, loading, failing
  or not stated. Nothing fills it in from the phone number, the language or the
  device; the device's zone may only be offered (`TimeZoneId.fromDevice`).
- `PortfolioMembership.ownerAbroad` is the portfolio's answer to "Does the
  owner of these properties live abroad?" (`OwnerAbroad`; not yet answered is
  NULL). The list embeds `portfolios!inner(id,name,owner_abroad)` without a
  hint, as the released apps do; pgTAP keeps exactly one relationship between
  the two tables, so the embed stays unambiguous.
- `PortfolioRepository.create` sends `p_owner_abroad` only when answered, so a
  portfolio created without an answer is stored as unanswered, and the call is
  the one older databases know. `answerOwnerAbroad` (`p_if_unanswered: true`)
  is the "ask on next open" answer, which returns an answer someone gave first
  instead of overwriting it; `changeOwnerAbroad` is an owner's change.
- `ownerAbroadQuestionProvider` names the current portfolio when the app should
  ask: unanswered, the user an owner or a manager, and the list just read from
  the server, never from a saved copy (someone may have answered since). It is
  never answered from the user's residence.
- `PortfolioDetails.ownerAbroad` and `caretaker` (`Caretaker`, always a manager)
  are read-only and stay out of `toUpdate()`: no client may write those
  columns, and PostgREST would refuse the whole save. A test pins the keys.
  `TeamController.setCaretaker`, `changeRole` and `remove` read the settings
  again, because the server clears a caretaker who stops being a manager.
- Saved copies written by an older version lack `owner_abroad`: they fail the
  strict read and the cache drops them once, so an offline first start after
  the upgrade shows no saved portfolio list once.

## Reading: stale while revalidate

Lists and dashboards show the last saved result at once, then the fresh one.
`SwrCache.watch` emits the cached snapshot (marked with when it was saved),
then the server's answer. Each saved entry's key names the user, what the
entry holds and the query with its parameters:
`mm.swr.v2.<user>.<tag>.<query>`, where the tag is `own` (the portfolio
list, the profile and the residence, which hold nothing of a portfolio
beyond the list itself), `p:<portfolio id>`, or `unknown`. Every query says
which (`CacheScope`, `lib/src/data/cache/cache_scope.dart`): an
`SwrNotifier` declares a `RecordScope`, either `InPortfolio` (its request
filters by a portfolio it names, as every list does) or `FromValue` (a
record or a parent's list found by an id, whose portfolio comes back with
its rows: the ten models behind them read `portfolio_id`), or
`UnknownPortfolio`; only `OwnScope.portfolioList`, `.profile` and
`.residence` make the user's own. An empty list names no portfolio and is
`unknown`. A query found by its value is read under whatever tag it has:
while the portfolios the user is in are known, by reading `p:<id>.<query>`
for each; before, by listing the store's keys. When a session ends, the
device wipe clears the cache and starts a new `SwrCache.epoch`: a value
fetched for the ended session is not saved, even when it arrives after the
wipe (see [On the device](#on-the-device)). How a portfolio that leaves the
user's list loses its saved entries is in On the device, Writes after a
removal. A screen shows
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
   there (`cameraLosesPhotosProvider`). If the target cannot be written (or
   the sheet has no screen to come back to), the sheet removes whatever target
   is stored before the camera opens: one that an earlier camera left behind,
   because removing it failed, is still recent, and a lost photo would
   otherwise go back to that earlier record. The camera then opens with no
   target, so a photo Android loses cannot come back, which is safe. If the
   removal fails as well, the camera does not open (`camera_not_ready`): the
   sheet says that the phone could not get ready to take a photo, and that the
   landlord can try again or choose a file instead.
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

The picker deletes the camera's copy of a photo, like every copy a picker
makes, once it has read its bytes (`DeviceScratch.discard`). A lost photo is
resized by image_picker only as it is handed over, next to the camera's
full-size original, which it leaves: both go (`cameraOriginalOf`). When a
session ends, the device wipe drains the camera's record of a lost photo and
deletes its files. At start-up it keeps them only while a photo may still
come back to its record (`lostPhotoMayReturn`: a readable target younger than
`lostPhotoMaxAge`), so that signing in again within the day still brings it
back; otherwise they go, with the photos versions before the wipe left.
image_picker (`image_picker_android` 0.8.13) writes its own note of a camera
pick (the pending file's path and the size asked for) each time the app goes
to the background while the camera is open, and does not clear it when the
photo comes back normally: it goes at the next pick, when the record is
drained, or at the wipe's drain. It names only a file `discard` has already
deleted, so no account data stays with it.

## On the device

`DeviceDataWipe` (`lib/src/data/device/device_data.dart`) removes what the
app kept on the phone or computer for an account. Every preference and file
the app writes for an account is listed here and removed by it; a new one is
added to it, to its tests and to the website's privacy page. The pending
invitation is kept on purpose (below), and text the person copies to the
clipboard is theirs.

| On the device                                                                         | Session ends           | Account deleted | App starts, nobody signed in                      | App starts, signed in                                        |
| ------------------------------------------------------------------------------------- | ---------------------- | --------------- | ------------------------------------------------- | ------------------------------------------------------------ |
| `mm.swr.v2.*` (and the old `mm.swr.v1.*`): every list the app loaded (CNICs included) | removed                | removed         | removed                                           | the user's `v2` kept, other accounts' and every `v1` removed |
| `mm.portfolio.current`: the portfolio last chosen                                     | removed                | removed         | removed                                           | kept if the user's, otherwise removed                        |
| `mm.documents.camera_target`: the record a camera photo is for                        | removed                | removed         | kept while a photo may come back                  | kept while a photo may come back                             |
| `mm.invitation.pending`: an invitation opened, not answered                           | kept                   | removed         | kept                                              | kept                                                         |
| `mm.settings.*`: language, theme, contrast, digit grouping                            | kept                   | kept            | kept                                              | kept                                                         |
| Android: image_picker's and file_picker's record of a lost pick, and its files        | drained, files deleted | the same        | drained and deleted, unless a photo may come back | drained and deleted, unless a photo may come back            |
| Android: the camera's photos (`<uuid>….jpg`, `scaled_<uuid>….jpg`)                    | deleted                | deleted         | deleted, unless a photo may come back             | deleted, unless a photo may come back                        |
| Phones: the pickers' copies (Android `cache/file_picker/<time>/`, iOS `tmp/`)         | deleted                | deleted         | deleted                                           | deleted                                                      |
| Phones: share_plus's files (`<uuid>/`, Android `share_plus/`) unchanged for 10 min    | deleted                | deleted         | deleted                                           | deleted                                                      |
| Supabase's session and gotrue's sign-in-link verifier                                 | removed by the library | the same        | never touched                                     | never touched                                                |

Files touched by a pass are the ones that last changed before it began
("older than the wipe"). Each time the app comes back to the foreground,
share_plus's files unchanged for ten minutes go too (`atResume`); nothing
else does then, since a picker may be handing over a copy.

- **Hooks.** `SupabaseAuthRepository` wipes on every `signedOut` event (the
  Sign out buttons, a refresh the server refused, a session that cannot be
  read, another tab signing out, whatever its `signOutReason`) and, in
  `signOut`'s `finally`, when that event never came (gotrue failed before
  announcing it). It also wipes, as a sign-out, when an event carries another
  account's session than the one the device held without a sign-out between
  them: an e-mail link of account B opened while A is signed in. Account
  deletion signs out with `SignOutCause.accountDeleted`, which wipes the
  invitation too. When the deletion's answer is lost or the server failed
  part-way (`mayHaveDeleted`: a `NetworkFailure`, `ServerFailure` or
  `UnexpectedFailure` after the re-authentication succeeded), it signs out
  all the same with `SignOutCause.deletionUnconfirmed`, wiped as a deletion;
  the sign-in screen says the account may be gone and how to check. A
  refusal, a rate limit or a busy database (503, rolled back) signs nobody
  out. `bootstrap` calls `tidyDeviceAtStart` once Supabase has read the
  stored session (the last two columns of the table), and the root widget
  watches `deviceTidyOnResumeProvider`.
- **Other devices.** Signing out is local (gotrue's default scope): another
  phone or browser keeps its copy until its own session ends there, which
  for a deleted account is when its next refresh is refused, within an hour
  of its next use online (an access token lives an hour). That wipe is a plain sign-out, so the invitation it
  holds stays. A member's device removes a deleted or left portfolio's
  entries the next time it loads the list of portfolios online, and at the
  latest when its session ends; only a store that fails can leave one longer
  (Writes after a removal).
- **Writes after a removal.** Two things remove saved entries: the wipe and
  the portfolio list.
  - _The wipe._ `SwrCache.clear` starts a new epoch before it deletes
    anything (every `mm.swr.` key, of every version and user). Every write
    names the epoch read before its value was asked for
    (`SwrCache.write(epoch:)`, a required argument): `SwrCache.watch` takes
    it when it is called; `SwrNotifier`, `PortfoliosController`,
    `ProfileController` and `ResidenceController` note it when they are
    built, and a command hands over that epoch (`SwrNotifier.requestEpoch`)
    or, for a value made from the one on show ("load more", a notification
    marked read, a language saved, an owner-abroad answer),
    `SwrNotifier.shownEpoch` or the controller's own, the epoch that value
    was asked for in. A write is dropped when the cache was cleared since its
    epoch, and one the store had not finished then is deleted as it lands:
    a fetch on its way when the session ended (its token is still valid for
    up to an hour) cannot put the account back on the device, nor can a
    notifier built for that session. Every `SwrNotifier`, and
    `PortfoliosController`, is built again when the signed-in user changes
    (every wipe ends a session): a portfolio list held across a sign-out
    reads nothing while signed out, and applies the next session's lists.
    Its commands (reload, create, delete, the owner-abroad answer) throw
    `SessionExpired` unless the signed-in user is the list's own, and ask
    for, show and save nothing: a caller that read the user before a request
    of its own (leaving a portfolio, changing one's own role) reloads the
    list afterwards, and by then the session may have ended, or be another
    account's.
  - _The portfolio list._ Each list the server answers is numbered before
    it is asked (`SwrCache.ask`), and only the newest-asked answer of the
    session applies (`SwrCache.applyPortfolios`; one asked before a wipe is
    refused, and the numbers count up across wipes). It sets, in memory, the
    portfolios the user is in (S), then removes, from the store's keys alone
    and reading no value (`SwrCache.prune`), every entry of the user's that S
    does not keep (a `p:` tag outside S, every `unknown` one, a key that does
    not parse), every key of another user, and every `mm.swr.v1.` key. The
    user's own are never removed. A removal begun before a wipe deletes
    nothing after it, and nor does the start's removal of other accounts'
    entries (`SwrCache.forgetOthers`): the wipe deleted it all, and the keys
    the store lists by then are the next session's, another account's among
    them. The list is shown at once and saved without
    waiting for the store, so a store that never answers holds up neither
    the screens nor the commands that reload it. A list the controller
    builds itself (an owner-abroad answer; a created or deleted portfolio
    when the server's list cannot be read) takes no number and sets nothing:
    creating adds the new portfolio to S and deleting removes it (and its
    entries) once the server has confirmed, when S is known, and the list
    shown and saved is cut to S.
  - _A write as it lands._ A write is kept only when, once the store has
    written it, the cache was not cleared since its epoch and S keeps its
    tag, or no list was applied yet in this session (then the first list
    removes it when it does not name its portfolio); otherwise it is
    deleted as it lands, and when it is already not kept as it is asked, it
    is not written. A later write of the same entry that landed first wins
    (the store may finish two in either order): the older is deleted as it
    lands, and so, then, is the newer value it overwrote. When a write of a
    query found by its value lands, the same query's copies under another tag
    go, so an empty list does not leave an older copy with rows behind; one
    the rule does not keep removes them all. A read never shows an entry S
    does not keep, and asks for its deletion.
  - _What is lost._ Every `mm.swr.v1.*` entry goes once, after the upgrade
    (a start signed in, the first list, or the wipe): an offline first
    start after it shows nothing saved, the portfolio list included. An
    entry of unknown portfolio (an empty list of units, tenancies, leases
    or reminders) does not outlive a list load: before the session's first
    list it is saved, that list removes it, and after it it is not saved.
    A record of a portfolio the user joined on another device since this
    session's last list is shown but not saved until the list loads again
    (pull to refresh, accepting an invitation here, or the next start). Two
    writes of one entry landing in reverse leave no entry; so does a write
    of a query found by its value whose removal of its other copies lists
    the keys after the store has finished a newer write under another tag
    but before the cache has heard that it landed; a write from
    before a wipe landing after a newer one deletes the newer; a wipe whose
    listing of the keys answers after its three seconds, when the next
    account has signed in, deletes what that account saved meanwhile (it
    cannot tell which keys were there when it asked, and nothing of the
    ended session may stay); a write the
    store fails deletes its entry; an answer asked before the newest is
    neither shown nor saved; an answer asked before a create that drops the
    created portfolio costs that portfolio's saves until the next list.
  - _Offline starts._ Until the session's first list, S is unknown and every
    saved entry is shown, also one of a portfolio left on another device
    since this device last loaded the list: it goes the next time the list
    loads online, as the privacy page says.
  - _What only a failing store can leave._ A deletion the store refuses or
    never answers, a listing of the keys that fails or hangs, a write that
    never answers although the store keeps it, or the app closing before a
    removal ends leaves an entry until a later list the store lets delete it,
    or the session's end. While S is known such an entry is never shown; an
    offline start can show it. A failed write of the list whose deletion is
    also refused can leave an older saved list (names, roles, owner-abroad
    answers) until the next list or sign-out. After a delete whose follow-up
    read of the list fails, a list answer asked before the delete and
    arriving after it names the deleted portfolio again, and a record of it
    fetched before the delete and landing after that answer stays until the
    next list (three races, and the portfolio no longer exists). A key
    listing that fails while a record opened by its link is read before the
    first list shows no saved copy.
  - _Commands._ A command that chooses the current portfolio after a request
    (creating a portfolio, accepting an invitation) passes the epoch it read
    before it (`select(askedIn:)`), and chooses nothing when the session
    ended meanwhile. When a portfolio leaves the list, `mm.portfolio.current`
    may still name it until the user picks another or the session ends; it
    is two ids, and `pickCurrent` falls back to the first portfolio. Apart
    from the wipe nothing puts a limit on the store: a read or write of a
    record query that never answers keeps its screen or command waiting.
  - _Tests._ `test/src/core/swr_commands_test.dart` runs every feature
    command that shows a value: held while its portfolio leaves it is not
    saved, held while another leaves it is, and neither is saved across a
    wipe. `test/src/data/cache/cache_scopes_test.dart` builds all 34 cached
    queries over the fakes and checks each one's key names the portfolio of
    what it fetched. `portfolio_prune_test.dart` keeps the probes of earlier
    reviews (P1 to P9, N1 to N10) as tests. `swr_cache_model_test.dart`
    (operational) and `swr_cache_ref_model_test.dart` (declarative, with a
    key-format fuzz) compare `SwrCache` with two models written apart from
    its code and from each other (500 and 400 random sequences by default,
    fixed seeds, `--dart-define=MODEL_SEQ=` and `REF_SEQ=` for more).
- **Replays.** gotrue's auth stream replays every earlier event to a new
  listener (an unbounded `ReplaySubject`), so a `signedOut` is acted on only
  when no session exists, and a session counts as replaced only when the
  event's session is the current one; gotrue removes the session before it
  announces a sign-out.
- **A start signed in.** A wipe whose cache deletions failed, never answered
  or were cut off by the app closing is not retried by a session that
  begins later (an e-mail link of account B opened while A was signed in
  wipes A only once B's session exists). So a start signed in removes what
  any other account left and every entry of the old format, which names no
  portfolio (`SwrCache.forgetOthers`), and a current portfolio
  chosen by another user, each on its own and waited for at most
  `wipePreferencesLimit`.
- **Timing.** The preferences go before the signed-out status is shown (a few
  milliseconds). The cache and each preference are removed on their own, all
  asked for at the start, and each waited for at most `wipePreferencesLimit`
  (three seconds): a store that does not answer holds up neither the other
  removals nor the sign-out. A removal that answers later finishes what it was
  asked and no more: no preference is asked for after the start, when someone
  else may have signed in (the cache's entries are the exception: its
  listing names the keys there are when it answers; see What is lost). While
  that step runs, a wipe that removes no more
  shares it; once it has ended, in time or not, the next wipe is a wipe of its
  own, with its own pass over the files. So a session that begins while a
  store has not answered (a link signs another account in) and ends within
  those three seconds removes nothing of its own: accepted, since it needs a
  store that hangs and a session of under three seconds, and the next wipe
  removes it. The files follow, one pass
  at a time, never holding the user up and given up after thirty seconds
  (`wipeFilesLimit`). The steps of a pass (the records of a lost pick and
  their copies, the pickers' copies, the sweep) start together, so one that
  never answers holds up no other. A plugin's record of a lost pick is
  waited for at most five seconds (`pluginCallLimit`); one that answers
  later has the copies it names discarded then, since its record is gone
  and nothing else would name them. The cache folder is asked for without
  a limit of its own, so a late answer still lets its step finish. A pass
  touches no camera photo or picker copy written after its wipe began: a
  picker copies into a folder it has just made, whose time is new even when the copy keeps its original's. A file written to
  share is kept until it has not changed for ten minutes (`sharedFileGrace`):
  Android's share sheet returns before the receiving app has read it. Such a
  file goes at the next start or return to the foreground after that. A
  second wipe for one sign-out (gotrue's announcement handled after
  `signOut` returned, when the auth stream was busy) does no harm.
- **The invitation.** It survives signing out because the way to take up an
  invitation sent to another address is "sign out, then sign in with the
  address it was sent to" (`invitationEmailMismatchBody`). The token names
  nobody and only the invited address's verified account can use it. It has
  no expiry on the device: it goes when answered, refused or set aside, or
  when the account is deleted on this device.
- **Copies on read.** On a phone, `PluginDocumentPicker` deletes the picker's
  copy of a photo or file once it has read it, or refused it; it waits at
  most `pluginCallLimit` for that, and the copy goes when the cache folder
  answers later.
- **Only the app's own folders.** path_provider's temporary directory
  (Android's cache, iOS's `Library/Caches`) and on iOS `tmp/`; never on the
  web or a computer. The app sweeps file_picker's copies itself rather than
  call `FilePicker.clearTemporaryFiles`, which takes every entry whatever its
  age and, on iOS, stops at the first it cannot delete. Links are neither
  followed nor deleted. Every step runs on its own, never throws and logs
  nothing: a statement's file name carries the tenant's name.
- **Not the app's to delete.** Files the person downloads (the browser's
  Downloads, the documents' Open and Download buttons on every platform, and
  on the web a file the browser could not share), files handed to another
  app, a photo a phone's own camera app also saved to the gallery, the
  browser's own cache (pictures shown, files opened), text copied with the
  Copy buttons (and a keyboard's clipboard history), and the phone's backup
  of the app's preferences (Android Auto Backup is on: `allowBackup` is not
  set). A session whose sign-out could not reach the server stays valid on
  it (refresh tokens do not expire by time, and no session time-box is set),
  so a backup made before can still sign in.
- **Moving the web app to another address.** The browser keeps the web app's
  storage per origin. When the web app moves (to `app.mmakaan.app`), the old
  origin's storage stays in every browser that used it, and the app on the
  new origin cannot reach it: see `docs/operations.md`, Moving the web app.

## State

- The current portfolio is chosen once and remembered on the device until a
  session ends; every feature provider depends on it, so switching portfolios
  refreshes them all.
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
- End to end: the browser UAT ([`docs/uat.md`](../uat.md)) drives the release
  web build against a local Supabase stack, in CI as well, so the REST requests
  its journeys make meet a running PostgREST. Other requests (foreign-key embed
  names such as `utility_bills_charge_id_fkey` included) are still checked
  against the SQL by hand.

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
