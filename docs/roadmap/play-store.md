# Publish the Android app on Google Play

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `play-store` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

## Why it matters

Today an Android landlord installs Maalik-e-Makaan from a file attached to a GitHub release, after
telling the phone to allow installs from the browser. A Google Play listing under AR LABS's name
gives them the install and the automatic updates they expect, and keeps the e-mail links (confirm
your address, reset a password, join a portfolio) opening the app. It is also the Android channel
for the pilot's testers and, later, for paid plans.

## What is true now

Facts marked _(summary)_ were read only through a search engine's summary; confirm them in the Play
Console.

- **Organisation account.** An organisation developer account needs a D-U-N-S number _(summary)_
  ([Play Console Help 13634885](https://support.google.com/googleplay/android-developer/answer/13634885)).
  Dun & Bradstreet issues one free "in most cases" within 30 business days, or within eight business
  days for a fee ([D&B](https://www.dnb.com/en-us/smb/duns/get-a-duns.html)). No Pakistan-specific
  process was found. On 9 November 2026 the number was still awaited
  ([STATE.md](../../.planning/STATE.md)).
- **Closed testing.** Personal accounts created after 13 November 2023 must run a closed test with
  12 testers for 14 days; organisation accounts are described as exempt _(summary, secondary)_
  ([OnTest](https://ontest.app/blog/personal-vs-organization-google-play-account-12-testers)).
- **Target API.** Since 31 August 2026 new apps and updates must target API level 36
  ([Android Developers](https://developer.android.com/google/play/requirements/target-sdk)). The app
  takes Flutter's defaults ([build.gradle.kts](../../app/android/app/build.gradle.kts)), and CI pins
  Flutter 3.47.9 ([ci.yml](../../.github/workflows/ci.yml)), whose defaults are target and compile
  SDK 36 and minimum SDK 24.
- **Account deletion.** An app that creates accounts must give a working web link for deletion in
  the Data safety form; deactivating or "freezing" an account does not count _(summary)_
  ([Play Console Help 13327111](https://support.google.com/googleplay/android-developer/answer/13327111)).
  The app already deletes accounts in Settings
  ([delete_account_screen.dart](../../app/lib/src/features/account/presentation/delete_account_screen.dart),
  [delete-account](../../supabase/functions/delete-account/)), and the privacy page has a "Deleting
  your account" section ([privacy.md](../../website/src/content/pages/en/privacy.md)), but no page
  dedicated to deletion.
- **Financial-features declaration.** Every app must complete it, including apps with no financial
  features _(summary)_
  ([Play Console Help 13849271](https://support.google.com/googleplay/android-developer/answer/13849271)).
- **Photo permissions.** Since May 2026 pre-review checks flag unnecessary photo permissions
  _(summary)_
  ([Android Developers Blog](https://android-developers.googleblog.com/2026/05/making-it-easier-to-build-publish-safer-apps.html)).
  The app uses `image_picker` and `file_picker` ([pubspec.yaml](../../app/pubspec.yaml)); the
  existing manifest check requires the `INTERNET` permission in the merged release manifest but
  forbids nothing ([check_manifest.py](../../tool/android/check_manifest.py)).
- **Sideloaded apps.** Developer verification for apps installed outside Play began enforcement on
  30 September 2026 in four countries, with global expansion from 2027
  ([Android Developers Blog](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)).
- **Signing.** Read on 11 November 2026: a new app can upload its own app-signing key instead of
  having Google generate one, and Android installs an update only when its certificate matches the
  installed app's
  ([Android Developers, app signing](https://developer.android.com/studio/publish/app-signing)).
  Once published, a changed application ID makes Play treat the upload "as a completely different
  app"
  ([Android Developers, application ID](https://developer.android.com/build/configure-app-module)).
- **Repository.** Each release attaches a signed AAB and split APKs
  ([release.yml](../../.github/workflows/release.yml)); the current version is 1.0.1.
  [`assetlinks.json`](../../app/web/.well-known/assetlinks.json) lists only the upload key, and
  [operations.md](../../docs/operations.md) ("Android App Links") describes adding the Play key. The
  application ID sits in the `io.github` namespace of a personal GitHub account. No listing text or
  artwork exists, and the [download page](../../website/src/content/download/en.yaml) says the
  listing is "on its way".

## Design

- **Account.** A Play organisation account for AR LABS (SMC-PRIVATE) LIMITED, whose D&B name and
  address match the SECP record exactly.
- **Application ID, decided before the first upload.** Keep the current ID, or move to an AR LABS
  namespace now. After the first upload it can never change. Moving costs the same as a new signing
  key: people on the sideloaded 1.0.1 APK reinstall once.
- **Signing key.** If the ID stays, upload the existing release key as the Play app-signing key and
  register a separate upload key. Updates then install over the sideloaded APK, and
  `assetlinks.json` gains one fingerprint. If Google generated the key, sideloaded users could not
  update in place.
- **Metadata in the repository.** Title, short and full description and release notes live in
  `app/store/play/en-GB/` and `app/store/play/ur/` (to be created), so the Urdu editor and the
  lawyer review the same text that ships.
- **Honest declarations.** "No financial features": the app records rent and moves no money.
  Category Business or House & Home, not Finance, which draws more scrutiny. Target audience adults;
  no ads.
- **Reviewer access.** A reviewer account seeded with fictional data, with a script that resets it;
  its credentials go in the app-access form, never in the repository.
- **Deletion page.** A bilingual page on the website that says how to delete in the app and how to
  ask by e-mail, and names the app and AR LABS.
- **Tracks.** Internal track first, uploaded by hand and then by a `release.yml` job with a Play
  service account in the `release` environment; then a closed track for the pilot, even if Google
  would not require one; then production with a staged rollout after a clean pre-launch report.
- **Domain move.** When the web app moves to AR LABS's own domain (see [app-store](app-store.md)),
  `assetlinks.json` is served there too, and the app's intent filter keeps both hosts until old
  e-mail links have expired.

### Residence (decision 1)

The listing and screenshots show both cases: a resident landlord, and an owner abroad whose
caretaker records the rent. Availability covers Pakistan and the countries where overseas owners
live; October 2026 remittances came mostly from Saudi Arabia, the UAE, the UK and the US
([Business Recorder](https://www.brecorder.com/news/40448227/pakistan-records-39bn-in-remittances-for-october-2026)).
The Play account's country never stands in for residence: residence is declared in the app, and the
store country only decides the price shown once [billing](billing.md) ships.

### Letterheads (decision 2)

Once letterheads ship, one screenshot shows a receipt on a fictional letterhead. The listing does
not mention them before then.

### Analytics (decision 3)

The Data safety form must say what the privacy notice says. It declares what Supabase holds
(account, records, photos and documents). Data collected only after opt-in is still declared, as
optional: PostHog analytics, Intercom support chat, and Customer.io e-mail. Nothing is used for
advertising or shared for tracking. The form is updated in the same pull request that adds each SDK,
never after.

## Work

1. **Owner:** obtain the D-U-N-S number, check the D&B record against the SECP certificate, open the
   Play organisation account (US$25) and choose the public developer name.
2. **Owner:** decide the application ID and the signing key; record both as a decision entry in
   `.planning/PROJECT.md`.
3. **S:** `assetlinks.json` with both fingerprints, and a packaging test that fails if either is
   missing.
4. **S:** English and Urdu listing text under `app/store/play/`, with a test of Play's field
   lengths.
5. **S:** account-deletion page on the website in both languages, linked from the privacy page and
   the footer.
6. **S:** merged-manifest audit; `check_manifest.py` learns a list of forbidden permissions
   (`READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`) and fails CI on them.
7. **M:** first upload to the internal track by hand; then the CI upload job with the service
   account in the `release` environment.
8. **Owner + S:** Data safety, financial-features, content-rating, target-audience, ads and
   app-access forms; the reviewer account and its reset script.
9. **S:** Play badge and link on the download page in both languages; decision entry on sideloaded
   APKs and developer verification.
10. **Owner:** closed track for the pilot, then production with a staged rollout.

## Depends on / Unblocks

- **Depends on:** [legal-review](legal-review.md) (the privacy URL and the Data safety answers),
  [app-icon](app-icon.md) (512 px icon, feature graphic, screenshots), [urdu-review](urdu-review.md)
  (the Urdu listing), and [pilot](pilot.md) for the closed-track testers.
- **Shares with:** [app-store](app-store.md), which needs the same D-U-N-S number.
- **Unblocks:** [pilot](pilot.md) (the Android channel) and [billing](billing.md) (Play Billing and
  the merchant account).

## Risks

- **A late D-U-N-S number, or names that differ between D&B, SECP and Play.** Start now, and copy
  the SECP name and address character for character.
- **A reviewer reads a rent ledger as a financial product.** Declare no financial features, choose
  Business, and say in the review notes that no money moves.
- **A Data safety form that understates the SDKs.** Declare opt-in collection too, and change the
  form in the same pull request as the SDK.
- **E-mail links stop opening the app** if the Play key's fingerprint is missing. Add it before the
  production rollout, and check with the Digital Asset Links API and `adb`.
- **Sideloaded users stranded** by a new key or ID. Decide both before the first upload, and tell
  them on the download page if a reinstall is needed.

## Done when

- [ ] The app is live in production under AR LABS in Pakistan and the chosen countries, with English
      and Urdu listings.
- [ ] The Console shows no policy issues, and every declaration form is complete.
- [ ] The deletion URL in Data safety loads, in both languages, and in-app deletion removes what the
      privacy notice says.
- [ ] `assetlinks.json` lists the Play app-signing key, the API answers `"linked": true`, and an
      e-mail link opens the app on a device.
- [ ] The pre-launch report shows no crashes, and CI fails on a forbidden photo permission.
- [ ] The download page links to the listing in both languages.

## Questions for the owner

- Keep the current application ID, or move to an AR LABS namespace before the first upload?
- Upload the existing release key as the Play app-signing key, or let Google generate one?
- Which countries: Pakistan plus the Gulf, the UK, the US and Canada; worldwide; or a short list
  first?
- Business or House & Home as the category?
- Keep shipping sideloaded APKs after Play goes live, and register them for developer verification?
- Which public developer name, if Play allows one shorter than the legal name?
