# Scheduled reminders through the WhatsApp Business Platform

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `whatsapp-reminders` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). Meta's verification of AR LABS gates it, so
the owner's side should start in the first half of 2027 and the build in the second.

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Landlords already remind tenants on WhatsApp, but by hand, one tenant at a time, and they forget
or feel awkward chasing. Reminders sent on the landlord's schedule, by the etiquette the app
already follows (never at night, never during Friday prayers, never twice in three days), and
stopped as soon as rent is recorded, take that chore away. The free reminder from the landlord's
own phone stays.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries; Meta's own pages could not be fetched, and the sources on prices
disagree in places.

**In the repository:**

- **Reminders go from the landlord's own number** through `wa.me` links, and each is logged in
  `reminder_logs` with channel, template, language and sender
  ([operations.sql](../../supabase/migrations/20261103194151_operations.sql)). Decision D-11 chose
  this over the Business API, citing US$0.015 a message ([PROJECT.md](../../.planning/PROJECT.md));
  this item revisits D-11, as open proposal P-01 there.
- **Five templates** (upcoming, due today, overdue, payment received with the receipt number,
  utility bill) exist in English, Urdu and Roman Urdu
  ([reminder.dart](../../app/lib/src/features/reminders/data/reminder.dart)), and messages can
  carry the portfolio's Raast ID.
- **The etiquette rules live only in Dart:** quiet from 22:00 to 08:00 Pakistan time, Friday
  prayers from 12:30 to 14:30, at least three days between reminders
  ([reminders.dart](../../app/lib/src/features/reminders/application/reminders.dart)). The due
  day is set per lease, default the 5th ([leases.sql](../../supabase/migrations/20261103193403_leases.sql)).
- **There is no inbound endpoint or outbound queue.** A constant-time compare exists
  ([crypto.ts](../../supabase/functions/_shared/crypto.ts)), and the storage-cleanup queue shows
  the pattern to copy
  ([membership_deletion_storage.sql](../../supabase/migrations/20261105072426_membership_deletion_storage.sql)).

**On the platform:**

- **The Cloud API is the only first-party route** since the On-Premises API was retired on 23
  October 2025 _(summary)_
  ([Meta](https://developers.facebook.com/docs/whatsapp/on-premises/sunset)).
- **Billing is per delivered message,** priced by the recipient's country _(summary)_
  ([YCloud](https://www.ycloud.com/blog/whatsapp-api-message-pricing-update-effective-october-1-2026)).
  Pakistani numbers cost about US$0.015 per utility message and about US$0.0473 per marketing
  message, after rises in April and October 2026 _(summary)_
  ([ProPakistani](https://propakistani.pk/2026/09/15/meta-charges-pakistan-11x-more-than-india-for-whatsapp-business-messages/),
  [Intellicon](https://www.intellicon.io/whatsapp-pricing-calculator/)).
- **A reminder stays "utility" only if purely transactional,** and Meta can reclassify a template
  as marketing _(summary)_
  ([YCloud](https://www.ycloud.com/blog/why-utility-templates-in-whatsapp-api-still-get-classified-as-marketing-and-how-to-fix-it)).
- **Opt-in** may be general since November 2024 but must say plainly that the person agrees to
  messages from the business; an approved template is not opt-in _(summary)_
  ([Meta](https://developers.facebook.com/documentation/business-messaging/whatsapp/getting-opt-in)).
- **Urdu is template language `ur`;** Roman Urdu has no code _(summary)_
  ([Meta](https://developers.secure.facebook.com/docs/whatsapp/api/messages/message-templates)). A
  template may carry one PDF as its document header _(summary)_
  ([Chakra](https://help.chakrahq.com/learning-centre/whatsapp-business-api/message-template-basics)).
- **New business portfolios start at 250 business-initiated messages a day;** sources conflict
  on the higher tiers _(summary)_ ([respond.io](https://respond.io/help/whatsapp/whatsapp-messaging-limits)).
- **Verification** needs the legal name and address to match exactly, and the website should show
  the legal name _(summary)_
  ([360dialog](https://docs.360dialog.com/partner/onboarding/meta-business-verification)).

## Design

**Account.** The Cloud API directly: one Meta business portfolio for AR LABS (SMC-PRIVATE)
LIMITED, one WhatsApp Business Account, a dedicated number and the display name
"Maalik-e-Makaan". A Business Solution Provider only if verification stalls.

**Templates.** Six utility templates (upcoming, due today, overdue, payment received with the
receipt as a PDF header, utility bill, portal link), each in English, Urdu and a Roman Urdu
variant filed under its own name: 18 in all. Each names the landlord, the unit, the amount, the
due date, and the receipt number or Raast ID. No offers and no app promotion. The texts live in
the repository and are reviewed by the Urdu editor.

**Opt-in started by the tenant.** "Invite to WhatsApp updates" opens `wa.me` on the landlord's
own phone with a message for the tenant. It holds a link to the Maalik-e-Makaan number with a
single-use code for the tenancy, valid for seven days. The tenant's own message records consent,
with its message ID as evidence, and binds their number to the tenancy. If the sender's number
differs from the tenant's recorded phone, the landlord confirms before anything is sent, so a
stolen code cannot redirect a tenancy's reminders. Consent is a row in `tenant_consents`, the
tenants' consent table shared with [document-reading](document-reading.md), with purpose
`whatsapp_updates`. "STOP", "بند کریں" and "band karo" revoke it; "START" restores it.

**Data.** A private `outbound_messages` queue (idempotency key of lease, template, due and step;
`not_before`; `claimed_until`; status; WhatsApp message ID; pricing category), `whatsapp_events`
for raw webhook events, and `reminder_schedules` per portfolio or lease. Automatic sends also
write `reminder_logs` rows marked "sent by Maalik-e-Makaan", so one history shows both kinds.
Locks follow account, portfolio, lease, then message rows.

**Functions.** `whatsapp-webhook` (auth `none`) reads each body once and checks Meta's
HMAC-SHA256 signature in `X-Hub-Signature-256` in constant time _(summary)_
([Meta](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)),
stores the event by ID, answers 200 at once, then handles opt-in codes, STOP and START, and
delivery statuses. `whatsapp-send`, woken by pg_cron through pg_net, claims due rows, re-checks
consent and suppression, and sends.

**Planner.** In SQL, per active lease with consent: upcoming 3 days before the due day, due
today, overdue 3 days after, overdue again 7 days after, then stop and tell the landlord. Sends
fall between 10:00 and 20:00 Pakistan time, a narrower window inside the 08:00 to 22:00 the app
allows for a reminder the landlord sends by hand. They never fall during Friday prayers, and come
at least three days after the last reminder through any channel, including logged `wa.me` ones.
The etiquette rules move to contract vectors in `contracts/`, read by Dart, SQL and TypeScript.
The vectors carry both windows, the app's for reminders sent by hand and the planner's for
automatic sends, and the Friday prayers and the three-day gap that both share, so the app and the
planner agree on every shared rule. The app's own hours do not change.

**Suppression.** Recording a payment that clears a due cancels its queued reminders in the same
transaction, under the lease lock. A cap per due and per month, and the landlord's switch,
cancel the rest.

**Monitoring.** Counts and estimated cost per account, the number's quality rating, and an
automatic pause on a low rating or a reached monthly cap. At about US$0.015, four messages a month
to each of 10 tenants cost about US$0.60 a month per landlord (an inference from the summary
price).

**`wa.me` stays** the default, and the fallback whenever the platform route is not approved, out
of budget, paused, or the tenant has not opted in.

### Residence (decision 1)

The schedule runs on the tenant's Pakistan clock, whatever the owner's time zone. The owner
chooses whether reminders are signed as the owner or as the caretaker on the owner's behalf.
Messages to the owner about failures, opt-outs and the end of a chase follow the owner's own time
zone and quiet hours, through [push-notifications](push-notifications.md). A tenant with a
foreign number is billed at that country's rate.

### Letterheads (decision 2)

The payment-received header is the letterheaded receipt the app stored when the payment was
confirmed. A payment with no stored receipt gets the portal-link template instead of a receipt
without the letterhead.

### Consent and analytics (decision 3)

WhatsApp consent is the tenant's, recorded with its text version, and separate from any
analytics consent. Meta becomes a processor of tenants' numbers and messages and is named in the
privacy notice. No message text, phone number or amount reaches PostHog; delivery and cost
figures come from server aggregates. Customer.io is not used to message tenants.

## Work

1. **Owner (weeks):** Meta business portfolio, business verification of AR LABS, the WhatsApp
   Business Account, the number and the display name.
2. **S:** the legal name and address in the website footer in both languages; the privacy notice
   on messaging; a decision entry revisiting D-11.
3. **M:** write and submit the 18 templates; track approval and category; Urdu review.
4. **S:** etiquette rules as contract vectors in Dart, SQL and TypeScript, with both windows; the
   app's `Etiquette` reads them and keeps its 08:00 to 22:00.
5. **M:** migrations for schedules, the consent purpose, the queue, events and the
   `reminder_logs` marker; RLS and pgTAP; a concurrency scenario of a payment against the planner.
6. **M:** `whatsapp-webhook`: signatures, idempotency by event and message ID, opt-in codes, STOP
   and START; Deno tests at 100% with signed fixtures.
7. **M:** `whatsapp-send` and the planner: suppression, caps, retries.
8. **S:** app: a per-portfolio switch (off by default), the schedule, the invite, consent status,
   delivery ticks and the month's count, in both languages with goldens.
9. **S:** cost and quality monitoring with the automatic pause; new secrets and a runbook in
   [`operations.md`](../operations.md).

## Depends on / Unblocks

- **Depends on:** Meta's verification (owner); the company's own domain, set up for
  [app-store](app-store.md); [legal-review](legal-review.md) (Meta as a processor of tenants'
  numbers); [urdu-review](urdu-review.md) (the templates); letterheads (decision 2);
  [billing](billing.md), since the [pricing page](../../website/src/content/pricing/en.yaml)
  lists it as coming on the Business and Overseas plans; and
  [tenant-portal](tenant-portal.md) for the portal-link template.
- **Unblocks:** [whatsapp-assistant](whatsapp-assistant.md), which shares the business account and
  the webhook. Related: [push-notifications](push-notifications.md)
  and the timing lessons of the [pilot](pilot.md).

## Risks

- **Verification is slow or refused.** Mitigation: start early; partner-led verification through
  a provider; `wa.me` continues meanwhile.
- **Cost rises:** two price rises in 2026, and reclassification as marketing at about three
  times the price. Mitigation: transactional wording only, the category watched, a monthly cap.
- **Tenant blocks lower the quality rating** and the sending limit. Mitigation: opt-in only,
  caps, stop on payment, automatic pause.
- **Tenants confused by messages from "Maalik-e-Makaan".** Mitigation: every message names the
  landlord, and the invitation comes first from the landlord's own phone.
- **The planner races a payment.** Mitigation: suppression under the lease lock; the concurrency
  scenario.

## Done when

- [ ] No automatic message reaches a tenant without recorded, unrevoked consent.
- [ ] Nothing is sent outside 10:00 to 20:00 Pakistan time, during Friday prayers, or within three
      days of the tenancy's last reminder by any channel, tested with the shared vectors.
- [ ] A recorded payment cancels the due's queued reminders before their send time, even when the
      two race.
- [ ] STOP in English, Urdu and Roman Urdu revokes consent with one confirmation; START restores
      it.
- [ ] A webhook without a valid signature gets 401 and changes nothing; replayed events are
      ignored.
- [ ] Re-running the planner never sends a message twice.
- [ ] The tenant gets the template in their recorded language; the landlord sees delivery status
      and the month's count.
- [ ] With the switch off, nothing is sent and `wa.me` works as today.

## Questions for the owner

1. Who pays for messages: included in the plan with a monthly cap, or passed on?
2. Switched on per portfolio or per tenancy?
3. Signed as the owner, or as the caretaker on the owner's behalf?
4. A Roman Urdu variant, if Meta rejects it under `en` or `ur`?
5. The receipt PDF on every payment-received message, or only on request?
6. The Cloud API directly, or a Pakistani provider?
