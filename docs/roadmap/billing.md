# Paid plans, with early-access users told first

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `billing` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Plans pay for the copy of the app that AR LABS runs: hosting, backups, the store apps and
support. Early-access landlords were promised at least 60 days' notice, no plan they did not
choose, and half price for their first year; billing must keep those promises exactly. Over a
limit, nothing is deleted or hidden: units become read-only and can still be opened, searched
and exported.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **The pricing page fixes the promises** ([pricing](../../website/src/content/pricing/en.yaml)):
  Free for 5 let units; Pro at Rs 499 a month for 5; Business at Rs 2,999 for 30; Overseas at
  US$2.49 for 5 in the store's currency. The store account's country decides which plans show.
  Rupee plans on the website are prepaid, with no auto-renewal and no card. Prices include tax.
  Over a limit: 14 days' grace, then the extra units become read-only.
- **No plan, subscription or usage tables exist**, and no `in_app_purchase` dependency
  ([pubspec](../../app/pubspec.yaml)). The only limit is 20 portfolios per user
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)). Let
  units can be counted through the `unit_occupancy` view
  ([reports migration](../../supabase/migrations/20261103194625_reports.sql)).
- **Clients insert leases directly** under RLS, checked by the `leases_before_insert` trigger
  ([leases migration](../../supabase/migrations/20261103193403_leases.sql)), so a unit limit
  belongs in that path. "Billing" already means rent dues in the code
  (`sync_portfolio_billing`, [ledger migration](../../supabase/migrations/20261103193658_ledger.sql)).
- **Google Play:** the fee cut of 30 June 2026 applies in the US, UK and EEA; elsewhere a Play
  subscription still pays 15% _(summary)_ ([TipRanks](https://www.tipranks.com/news/private-companies/google-googl-vs-epic-games-battle-update-tech-giant-slashes-play-store-fees-to-20-in-major-settlement),
  [PricePush](https://pricepush.app/blog/google-play-subscription-fees-2026-real-math)). No
  source names Pakistan for user choice billing, so its exclusion is inferred from silence
  _(summary)_ ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/13821247)).
  JazzCash and Easypaisa are not Play payment methods; cards and carrier billing are
  _(summary)_ ([Pakera](https://pakera.pk/google-play-pay-jazzcash-easypaisa-pakistan/)).
- **Apple** allows a link out to web checkout only in the US, and by entitlement in the EU,
  Japan and Brazil; elsewhere it breaks guideline 3.1.1 _(summary)_
  ([Newly](https://newly.app/how-to/app-store-external-purchase-link),
  [AppSubmitter](https://www.appsubmitter.io/app-rejection-guides/app-store-guideline-3-1-1-in-app-purchase/)).
- **Payment service providers (PSPs):** Safepay has held a full State Bank licence since April
  2025 _(summary)_ ([Profit](https://profit.pakistantoday.com.pk/2025/04/21/safepay-granted-full-commercial-license-by-sbp-to-operate-as-payment-service-provider/)).
  PayFast was the first gateway live on Raast P2M, and its payment links trigger a Raast
  Request-to-Pay _(summary)_ ([PayFast](https://gopayfast.com/payfast-becomes-the-first-payment-gateway-to-enable-raast-p2m-payments-in-pakistan/)).
  Unofficial rates: 0.60% for Raast QR, 2.95% for local cards, 3.50% for international cards
  _(summary)_ ([partner guide](https://www.scribd.com/document/890936512/Partner-Guide-PayFast)).
  Stripe is not available to Pakistani companies _(summary)_
  ([LearnWithHasan](https://learnwithhasan.com/payment-gateways/country/pakistan/)).
- **Tax is unsettled:** provincial sales tax on IT services is reported at 5% or 8% in Punjab,
  13–15% in Sindh and 15–16% in Islamabad, with a possible local exemption _(summary)_
  ([ConSerIC](https://conseric.pk/punjab-sales-tax-on-services/),
  [EY](https://taxnews.ey.com/news/2023-1654)). The 0.25% final tax for PSEB-registered IT
  exporters runs to tax year 2029 _(summary)_
  ([TechJuice](https://www.techjuice.pk/pakistan-budget-2026-27-it-tax-exemption-extended-but-is-it-enough/)).
- **What a channel nets:** Rs 499 through a store at 15% nets about Rs 424; through the website
  with Raast it nets Rs 496–499, about Rs 72 a month more per Pro subscriber, before tax.
- **Calendar:** a charge before 28 February 2027 needs the notice sent by 30 December 2026.

## Design

**Data model.** Versioned `plans` and `plan_bands`; `entitlements` per portfolio, recording the
payer, the source (`play`, `app_store`, `web`, `comp`, `early_access`), the state (`active`,
`grace`, `lapsed`), the period end and the storefront country of the purchase (a fact about the
purchase, never taken as the person's residence). A
`let_units_in_use(portfolio)` function counts units with a running lease; empty units never
count. The new objects are named for plans and subscriptions, never "billing", so they cannot
be confused with rent dues.

**How Free is counted is open.** The research counts let units per portfolio and does not say
how Free is counted across several. This plan adds a proposal of its own, not from the research:
count the free 5 units across every portfolio a person owns, so that splitting a building into
portfolios does not multiply the free allowance, while paid entitlements still cover named
portfolios. The owner decides (question 4); until then the design counts per portfolio.

**Enforcement in Postgres.** Limits are checked where rows are written: the lease insert path
(units), `create_invitation` (people) and document inserts (storage), each taking the account
and then the portfolio lock first, as the lock order requires. The app only explains a refusal.

**Lapse and grace.** A pg_cron job keeps a lapsed plan in `grace` for 14 days with reminders.
Then units above the plan become read-only through the write helpers, and the owner chooses
which stay active. Nothing is deleted; export always works.

**Stores.** Google Play Billing and StoreKit 2, verified on the server. Store notifications go
to a `subscription-webhook` Edge Function, which writes through a definer RPC callable only with
the secret key, idempotent on the store's transaction ID. The bands imply about 26 Play products
with two base plans each, or about 52 Apple products.

**Web checkout.** One PSP's hosted page; order creation and the payment notification (IPN) in
Edge Functions with signature checks; an idempotent `record_subscription_payment` keyed on the
PSP's transaction ID; a job that asks the PSP about pending orders. Receipts carry the tax, a
sequential number and a slot for an FBR e-invoice reference.

**Store compliance.** A CI check fails if any web price or "pay on our website" text reaches the
apps.

### Residence (decision 1)

One store account belongs to one person, but residence is per person and per portfolio. The
entitlement therefore names the portfolio it covers: one owner can hold Overseas for one
portfolio and Pro for another, and a relative in Pakistan can pay rupees for an overseas
owner's portfolio. The store country decides which prices are shown, as store rules require;
declared residence only suggests a plan and never changes a price.

### Letterheads (decision 2)

Letterheads, both the builder and uploads, are on every plan, Free included (the owner's
decision of 12 November 2026, D-17), so no entitlement check gates them. Subscription receipts are
AR LABS's own documents, not the landlord's.

### Analytics and e-mail (decision 3)

The 60-day notice is a contractual service message, not marketing. It goes to every
early-access user through Customer.io's transactional path, which reaches people who
unsubscribed unless that is turned off _(summary)_
([Customer.io](https://docs.customer.io/messaging/channels/subscriptions/unsubscribes/)), and as
an in-app notification. No purchase event goes to PostHog or any other SDK; billing metrics come
from entitlement rows, aggregated on the server.

## Work

1. **Owner:** tax registrations (NTN, provincial or Islamabad services tax, PSEB) and a written
   tax opinion on "prices include tax", for web and store sales.
2. **Owner:** Play payments profile, Apple Small Business Program, a PKR settlement account, and
   a PSP merchant agreement with a written rate card that says whether tax is included.
3. **M:** migration for plans, bands, entitlements and `let_units_in_use`, with pgTAP and
   contract vectors for unit counting.
4. **M:** limits in the lease insert path, `create_invitation` and document inserts; a
   concurrency scenario where two leases race for the last unit
   ([`concurrency_test.sh`](../../tool/db/concurrency_test.sh)).
5. **M:** grace job, read-only over-limit units and the "choose which units stay active" flow,
   measured with [`stress_test.sh`](../../tool/db/stress_test.sh).
6. **M:** Play Billing in the app: products, base plans, purchase, restore.
7. **M:** Play on the server: Developer API verification, notifications through Pub/Sub,
   upgrades, refunds.
8. **M:** StoreKit 2 in the app: subscription group, PKR price points, purchase, restore, offer
   codes for the half-price year.
9. **M:** App Store Server API and Server Notifications v2 in `subscription-webhook`.
10. **M:** rupee web checkout through the PSP, 14-day refunds, expiry reminder.
11. **M:** plan screen and paywall in English and Urdu; the store-compliance check.
12. **M:** early-access programme: mark accounts at the cut-off, send the 60-day notice, apply
    half price per channel.
13. **M:** test environments (Play licence testers, StoreKit testing, PSP sandbox), UAT journeys
    in [`docs/uat.md`](../uat.md), and the new definer RPCs in
    [`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql).

In the index's [order of work](README.md#order-of-work), items 3 and 4 (the schema and the
limits) come before 28 February 2027 and the checkout (items 6 to 10) after it, so the index
recommends moving the checkout to The assistant. A charge before 28 February instead needs at
least items 1, 2, 10 and 12 in that first wave as well, with the notice sent by 30 December 2026;
the store checkout still follows.

## Depends on / Unblocks

- **Depends on:** [play-store](play-store.md), [app-store](app-store.md),
  [legal-review](legal-review.md) (terms, refunds, the PSP named in the privacy notice),
  [urdu-review](urdu-review.md), the residence fields of decision 1, the consent records and
  Customer.io set-up of decision 3, and the owner's tax registrations.
- **Related:** [pilot](pilot.md) informs the plans and prices, but does not hold up the code or a
  charge in February.
- **Unblocks:** [hostel-mode](hostel-mode.md) (Business limits) and
  [raast-request-to-pay](raast-request-to-pay.md).

## Risks

- **Unknown tax on top of the 15% store fee**, possibly owed on store sales too. Mitigation: the
  tax opinion before any price goes live; prices stay data in `plan_bands`.
- **Steering in the app.** Mitigation: the CI check and a store-review checklist item.
- **Guideline 3.1.3(b)** may require web plans to be sold in-app on iOS too. Mitigation: read it
  in the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) before
  web plans unlock anything on iPhone.
- **Proration across bands.** Mitigation: upgrades apply at once, downgrades at period end, in
  every channel.
- **Refunds and chargebacks.** Mitigation: each store or PSP event, keyed on its own ID,
  reverses an entitlement exactly once.
- **Read-only checks slow every write.** Mitigation: measure in item 5 against the costs in
  [`permissions.md`](../architecture/permissions.md).

## Done when

- [ ] No account is charged before its notice date, and a pgTAP test proves half price for 12
      months in every channel.
- [ ] Calling the RPCs or the Data API directly cannot activate a sixth let unit on Free; if the
      owner counts Free per owner, nor a sixth by spreading units across portfolios.
- [ ] Duplicate store notifications or PSP IPNs produce exactly one entitlement change; a refund
      revokes it.
- [ ] A lapsed plan gives 14 days of full access, then read-only units; nothing is deleted and
      export works.
- [ ] The Pakistani storefront shows only Free, Pro and Business in rupees; others show only
      Overseas; no app text points to web prices.
- [ ] Web receipts show the tax included and a sequential number.
- [ ] Every early-access account received the notice, logged, at least 60 days before its first
      charge.

## Questions for the owner

1. Where is AR LABS registered for services tax, and is it registered with PSEB?
2. PayFast or Safepay?
3. Does a plan belong to the portfolio (recommended) or the account?
4. Is the Free allowance counted per portfolio, or per owner across portfolios (this plan's
   proposal, not the research's)?
5. Does the half-price year apply in the stores too, after the store's fee?
6. A link out on the US storefront, or one rule everywhere?
7. Web checkout first, then the stores?
8. A subscription service such as RevenueCat, or store verification built in-house?
