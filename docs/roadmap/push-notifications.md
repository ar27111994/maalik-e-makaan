# Push notifications

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `push-notifications` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It has few blockers, so it should start in
the first half of 2027; Android and the web can ship before the iPhone.

## Why it matters

Today a landlord learns that rent is overdue, that a police-registration deadline is close or
that a caretaker has handed over cash only when they open the app. A notification on the phone,
at a sensible hour, means fewer missed dues and deadlines. For an owner abroad it is the quickest
sign that something needs their confirmation, and it must not wake them at night in London.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **There is no `device_tokens` table.** It is named only in the roadmap and the requirements
  ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)). The app has no `firebase_messaging`
  dependency ([pubspec.yaml](../../app/pubspec.yaml)), no Firebase configuration and no push
  entitlement.
- **An in-app inbox exists.** The daily job writes `notifications` rows, which the app renders
  from `kind` and `params`; `(user_id, dedupe_key)` keeps each event once per person
  ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql),
  [notifications_screen.dart](../../app/lib/src/features/notifications/presentation/notifications_screen.dart)).
  Nine kinds cover dues, overdue rent, lease expiry, increments, police registration, CNIC expiry,
  utility bills and invitations. None covers cash handovers, which only an owner can confirm
  ([operations.sql](../../supabase/migrations/20261103194151_operations.sql)).
- **A queue-and-wake pattern exists.** The storage-cleanup queue has `not_before` and
  `claimed_until`, and a pg_cron job wakes an Edge Function through pg_net with a token from
  Vault ([membership_deletion_storage.sql](../../supabase/migrations/20261105072426_membership_deletion_storage.sql)).
- **Everything runs on Pakistan time** (`app.today_pkt()` in
  [foundation.sql](../../supabase/migrations/20261103192528_foundation.sql), a fixed offset in
  [calendar_date.dart](../../packages/mm_core/lib/src/time/calendar_date.dart)). People have no
  time-zone field ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **The web app's CSP** allows connections only to its own origin, Supabase and a font fallback
  ([package_vercel.py](../../tool/web/package_vercel.py)), so web push needs a CSP change.
- **iOS is not built in this environment** ([app/AGENTS.md](../../app/AGENTS.md)).
- **FCM** sends through the HTTP v1 API with a short-lived OAuth token minted from a service
  account _(summary)_ ([Firebase](https://firebase.google.com/docs/cloud-messaging/auth-server)).
  It reaches iPhones through APNs once an APNs key is uploaded and the app has the Push
  Notifications capability, and needs a physical device _(summary)_
  ([Firebase Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client)).
- **Android 13 and later** require the runtime `POST_NOTIFICATIONS` permission _(summary)_
  ([The Flutter Kit](https://theflutterk.it.com/blog/flutter-push-notifications-firebase-fcm-2026)).
- **Web push on the iPhone** works only for web apps added to the Home Screen, from iOS 16.4,
  after a tap _(summary)_
  ([Pushpad](https://pushpad.xyz/blog/ios-special-requirements-for-web-push-notifications)).
  Subscriptions have been reported to drop on iOS 18.4 and later
  ([firebase-js-sdk #8010](https://github.com/firebase/firebase-js-sdk/issues/8010)).
- **Payloads pass through Apple and Google**, which see at least the app and the timing, so
  content should be minimal and fetched after the tap _(summary)_
  ([EFF](https://www.eff.org/deeplinks/2026/04/how-push-notifications-can-betray-your-privacy-and-what-do-about-it)).

## Design

**One source of events.** The `notifications` rows stay the record: the inbox and push show the
same events, and push only adds a delivery. A new kind, `cash_handover_recorded`, is written by a
trigger on `cash_handovers` for the owners who can confirm the handover.

**Tokens.** `device_tokens`: person, FCM token, platform (`android`, `ios`, `web`), app version,
locale, last seen and revoked times. Own-row RLS and explicit grants, so a person registers,
refreshes and revokes only their own tokens. Signing out revokes the device's token, and
`delete-account` removes them all.

**Planner.** A pg_cron step reads new notifications whose kind the person has switched on and
queues one row per active device in a private `push_deliveries` table, keyed by notification and
token, with `not_before` and `claimed_until` as in storage cleanup. `not_before` comes from the
person's quiet hours in their own time zone, computed in SQL with `AT TIME ZONE` and checked
against the vectors of the `mm_core` time-zone utility of decision 1. Events held by quiet hours
go out as one digest when the quiet hours end ("3 things need your attention").

**Sender.** A `push-send` Edge Function, woken through pg_net and authenticated by its own token
as `storage-cleanup` is. It claims a batch, caches the Google access token, sends through FCM v1
with a collapse key per notification, marks each row sent, retries transient errors with
back-off, and revokes a token on its first `UNREGISTERED` or invalid-token answer. The service
account key is an Edge Function secret.

**Content.** Free of detail by default: "A due needs your attention", in the person's language,
with the portfolio's name at most. The text is rendered on the server from `kind` and `params` in
the person's locale; a test checks that its keys match the ARB strings. A tap opens the record
through a deep link, and the app loads the details after its usual session check. Names and
amounts appear only for people who switch details on, if the owner allows that at all.

**Permission.** Asked after a meaningful step (the first tenancy added, or the first handover to
confirm), with a short explanation in both languages; never at first launch. Android gets one
channel per kind, so a person can mute one kind in the system settings. A refusal leaves the
inbox complete.

**Preferences.** A Notifications section in Settings: kinds on or off, quiet hours, the digest,
and details on or off.

**Web.** Chrome and Edge through FCM's web SDK, a service worker and a VAPID key, with the CSP
widened for the FCM hosts only. On the iPhone, the web app explains how to add it to the Home
Screen first and is documented as supported with caveats.

### Residence (decision 1)

Quiet hours (default 22:00 to 08:00) and the digest follow the recipient's declared time zone,
`profiles.time_zone`. A resident owner and their caretaker are on Pakistan time; an owner who
declared Europe/London gets them on London time, across the clock change. Until a person states
a time zone, Pakistan time applies, and the device's zone may only pre-fill a suggestion in
Settings. Due dates in the text stay Pakistan dates. On a portfolio marked `owner_abroad`, the
defaults differ by role: the caretaker gets dues and deadlines, the owner gets handovers to
confirm and overdue rent. Each person can change their own.

### Analytics (decision 3)

Firebase is used for messaging only: no Firebase Analytics, and automatic data collection off.
The system permission is the consent for push and is separate from analytics consent. Nothing
about a notification reaches PostHog unless the person opted in, and then only its kind, never
its content. Google and Apple are named in the privacy notice and the store privacy forms as
processors of device tokens. Push carries service events only; product news would need the
lifecycle consent of decision 3 and is outside this item.

## Work

1. **Owner + S:** Firebase project without Analytics, APNs key from the Apple membership, the
   service account key as an Edge Function secret, and the secrets table in
   [`operations.md`](../operations.md).
2. **S:** `device_tokens` migration with own-row RLS and grants; revocation on sign-out and in
   `delete-account`; pgTAP.
3. **S:** `cash_handover_recorded` kind and trigger; pgTAP that only owners receive it.
4. **M:** `push_deliveries` and the planner: kinds per person, quiet hours in their own zone,
   the digest, idempotency; pgTAP with time-zone vectors across the UK and US clock changes.
5. **M:** `push-send` function: token cache, batching, collapse keys, retries, pruning; Deno tests
   at 100% with recorded FCM answers.
6. **M:** Flutter: `firebase_messaging`, a channel per kind, the permission flow in both
   languages, token registration and refresh, deep links; goldens;
   [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).
7. **S:** Notifications section in Settings, in both languages.
8. **M:** web push: service worker, VAPID key, the CSP change in `package_vercel.py` with its
   test, iPhone Home Screen guidance.
9. **S:** privacy notice, Play Data safety and App Store privacy answers, a UAT journey in
   [`uat.md`](../uat.md), and a runbook entry.

## Depends on / Unblocks

- **Depends on:** [app-store](app-store.md) (the APNs key needs the Apple membership), the
  residence fields and time-zone utility of decision 1, [legal-review](legal-review.md) (Google
  and Apple in the privacy notice) and [urdu-review](urdu-review.md) (the notification text).
- **Unblocks:** [overseas-oversight](overseas-oversight.md) (high-severity findings),
  [retention](retention.md) (notice before documents are removed), [move-out](move-out.md) and
  [hostel-mode](hostel-mode.md) (the short police-reporting deadline). Related:
  [tenant-portal](tenant-portal.md) (a tenant's request reaches the landlord),
  [agent-limits](agent-limits.md) and [whatsapp-assistant](whatsapp-assistant.md) (drafts that
  wait for a tap).

## Risks

- **Permission refused.** Mitigation: ask after a meaningful step with an explanation; the inbox
  stays complete without push.
- **Names and amounts on lock screens.** Mitigation: content-free text by default; details only
  by the person's own choice.
- **Duplicates after retries or re-planning.** Mitigation: one row per notification and token,
  and a collapse key per notification.
- **Alerts at night from a wrong or missing time zone.** Mitigation: Pakistan time until a zone
  is stated; Settings says which zone quiet hours use; vectors across clock changes.
- **iPhone web subscriptions dropping.** Mitigation: web push is best effort; the inbox is the
  record.
- **No iOS build here.** Mitigation: iPhone acceptance on a Mac and a device, recorded in the UAT
  results.

## Done when

- [ ] Each notification reaches each of a person's active devices at most once, including after
      retries and planner re-runs (pgTAP and Deno tests).
- [ ] Nothing arrives in the recipient's quiet hours in their own time zone; held events arrive
      in one digest, tested across the UK clock change.
- [ ] By default no payload contains a tenant name, phone number or amount, checked over
      fixtures.
- [ ] A token reported as unregistered is revoked after the first failure.
- [ ] Signing out and deleting the account stop pushes to that device.
- [ ] A recorded cash handover notifies the owners who can confirm it.
- [ ] It works on Android 13 and later with the permission flow, on an iPhone device build and in
      Chrome on the web.
- [ ] The app's dependencies include no Firebase Analytics.

## Questions for the owner

1. Default quiet hours of 22:00 to 08:00, with a digest when they end?
2. May owners switch on names and amounts in notifications, or never?
3. Which events at launch: overdue rent, police-registration deadlines, lease end, handovers,
   tenant requests?
4. Web push at the first release, or Android and iPhone first?
