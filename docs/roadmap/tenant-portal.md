# A read-only link for tenants

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `tenant-portal` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It has few blockers and should start in the
first half of 2027, once letterheaded receipts exist.

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Tenants ask for their receipts, how much they still owe and where to send the rent, and the
landlord answers each time by hand, often with screenshots. A link the landlord sends once lets
the tenant see their own ledger, download receipts and copy the Raast ID, in English, Urdu or
Roman Urdu, without an account. Both sides then look at the same record, which heads off disputes.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **Every page needs a signed-in member.** `anon` holds no table privileges: default privileges
  are revoked and every grant is explicit
  ([foundation.sql](../../supabase/migrations/20261103192528_foundation.sql); D-13 in
  [PROJECT.md](../../.planning/PROJECT.md)).
- **A split-token scheme exists for invitations.** The selector is the invitation's ID, the
  32-byte random verifier is stored only as a SHA-256 hash, and it is compared in constant time
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql),
  [crypto.ts](../../supabase/functions/_shared/crypto.ts)). The link carries the token in the
  URL fragment, `/invite#token=…` ([routes.dart](../../app/lib/src/routing/routes.dart)).
- **No per-IP rate limits**, by decision D-13; per-user and per-action limits exist, and
  `admin_rate_limit_hit` serves Edge Functions
  ([ledger_findings.sql](../../supabase/migrations/20261107181820_ledger_findings.sql)).
- **Tenants have no language column**
  ([properties_units_tenants.sql](../../supabase/migrations/20261103192902_properties_units_tenants.sql)),
  while reminders already come in `en`, `ur` and `roman_ur`
  ([reminder.dart](../../app/lib/src/features/reminders/data/reminder.dart)).
- **Receipts and statements are built only on the device**
  ([ledger_pdfs.dart](../../app/lib/src/features/ledger/presentation/pdf/ledger_pdfs.dart)). The
  document kind `receipt` exists for stored files
  ([documents_storage.sql](../../supabase/migrations/20261103194240_documents_storage.sql)).
- **Portfolios hold** the landlord's name, Raast ID, account title and IBAN
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **The requirements** list a read-only tenant link as future work
  ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)), and the deck names "no tenant portal yet"
  as a gap ([competition slide](../../website/deck/slides/competition.html)).
- **Comparable apps:** RentRedi gives tenants a free app _(summary)_
  ([TrustRadius](https://www.trustradius.com/products/rentredi)), NoBroker sends a receipt after
  each payment _(summary)_
  ([NoBroker](https://www.nobroker.in/prophub/property-management/rental-collection-service/)),
  and RentOk offers tenant dashboards _(summary)_
  ([Capterra](https://www.capterra.com/p/10006521/RentOk/)). No Pakistani portal offering tenant
  ledgers was found _(summary)_.
- **Law:** Pakistan's Personal Data Protection Bill was still unpassed in October 2026, and PECA
  2016, amended in 2025, makes unauthorised disclosure of personal data an offence _(summary)_
  ([Chambers](https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2026/pakistan)).
- **A one-time code** through a WhatsApp authentication template costs about US$0.015, against
  about US$0.47 for an SMS through Twilio _(summary)_
  ([textbee](https://textbee.dev/sms-pricing/twilio/pk)). Supabase's Send SMS Hook can route codes
  to WhatsApp _(summary)_
  ([Supabase](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)).

## Design

**Links.** `tenant_links`: lease, selector, SHA-256 hash of a 32-byte verifier, created by,
expiry, revocation, the link it replaced, and last opened. One live link per lease; rotating
revokes the old one, and ending a lease revokes its link after a grace period. Owners and managers
create, rotate and revoke links through definer RPCs, added to the allowlist in
[`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and to
[`permissions.md`](../architecture/permissions.md). The link is `<app>/t#<selector>.<verifier>`.
As with invitations, the token sits in the fragment, so it never reaches server logs, a `Referer`
header or WhatsApp's link-preview fetch.

**Data.** A `tenant-view` Edge Function (auth `none`, checking the token itself). It verifies the
token in constant time, applies a per-link limit through `admin_rate_limit_hit` and a global
ceiling on failed checks, calls one SQL function that returns the view for that lease alone, and
records the open. An Edge Function rather than an RPC open to `anon` keeps D-13 intact and gives
per-link limits.

The view holds: the landlord's display name and the contact the owner chose; the unit, the rent
and the due day; dues and payments with a running balance; receipt numbers; the deposit held; the
Raast ID, account title and IBAN; and a payment reference for the tenancy, which the tenant can
put on transfers. It never holds CNICs, documents other than receipts, notes, phone numbers,
other tenancies, audit data or the details of voided rows, which show only as "voided".

**Page.** A public `/t` route in the Flutter web build, outside the signed-in shell, designed for
phone width first. `package_vercel.py` gives the route `noindex` and
`Referrer-Policy: no-referrer`. On the first visit a notice says who holds the record (the landlord), that AR LABS
processes it for them, how to ask the landlord to correct it and how to report a wrong link. A
language switch offers English, Urdu and Roman Urdu, starting from the tenancy's language.

**Receipts and statements.** Receipts are the letterheaded PDFs stored when each payment was
confirmed, served through short-lived signed URLs. The statement is built in the browser by the
same statement builder the app uses.

**Requests.** "Ask for a receipt or statement" writes a `tenant_requests` row, limited per link
(for example three a day), and notifies the owners and managers in the app and by push. Nothing
is sent to the tenant without the landlord.

**Sharing.** The landlord sends the link with `wa.me` from their own phone, as reminders go today,
and later through the `portal_link` template of [whatsapp-reminders](whatsapp-reminders.md).

**Later.** Before anything more sensitive is shown (the agreement, or a way to pay), a one-time
code through a WhatsApp authentication template, sent by the Send SMS Hook. Not in the first
release.

### Residence (decision 1)

Residence is never shown to tenants. On a portfolio marked `owner_abroad`, the owner chooses
whether the page names the caretaker as the contact. Dates on the page are Pakistan dates. In the
app, "last opened" shows in the landlord's own time zone, with Pakistan time beside it for an
owner abroad.

### Letterheads (decision 2)

Receipts and statements from the page carry the portfolio's letterhead. Letterheads are
rasterised on the device, so the app stores the letterheaded receipt (kind `receipt`) when a
payment is confirmed, and the page serves that file. For payments recorded before letterheads
existed, the page builds the receipt in the browser from the letterhead's stored raster.

### Analytics (decision 3)

No analytics on the tenant page. Tenants are not account holders and have not opted in. The route
never starts PostHog or Intercom, whatever the consent of a landlord who once signed in on the
same browser, and a test fails on any request to their hosts. Opens are recorded only for the
landlord, as `last_opened_at` and a count.

## Work

1. **M:** migration: `tenant_links`, the tenant `preferred_language` column, create, rotate and
   revoke RPCs; pgTAP proving no cross-tenancy access, that revoked and expired links fail, and
   that only owners and managers manage links.
2. **M:** the view's SQL function and the `tenant-view` function with per-link limits and signed
   receipt URLs; Deno tests at 100%, with a fixture check that no identity field is returned.
3. **M:** the `/t` route: ledger, receipts, statement PDF, Raast ID to copy, the first-visit
   notice; English, Urdu and Roman Urdu; headers in `package_vercel.py` with its test; goldens.
4. **S:** landlord screens: create, share through `wa.me`, rotate, revoke, last opened; the tenant
   language field.
5. **S:** the request action with its limit and notification kind; report a wrong link.
6. **S:** store the letterheaded receipt at confirmation, if the letterhead work has not already.
7. **S:** security review (token entropy, limits, headers, enumeration) and a browser UAT journey
   in `app/uat/` and [`uat.md`](../uat.md).
8. **M (later):** one-time code step-up through the Send SMS Hook.

## Depends on / Unblocks

- **Depends on:** letterheads (decision 2), [legal-review](legal-review.md) (the first-visit
  notice and a tenant notice that covers the link), [urdu-review](urdu-review.md) (the Urdu and
  Roman Urdu text) and, for requests, [push-notifications](push-notifications.md) (optional).
- **Unblocks:** [move-out](move-out.md) (a report both sides see),
  [reconciliation](reconciliation.md) (the tenancy's payment reference),
  [document-reading](document-reading.md) (a place a tenant can see what was recorded),
  [raast-request-to-pay](raast-request-to-pay.md) and
  [agent-coordination](agent-coordination.md). Related:
  [whatsapp-reminders](whatsapp-reminders.md).

## Risks

- **A forwarded link shows a tenant's ledger.** Mitigation: no identity data, expiry, revocation
  in one tap, rotation at move-out, and the later one-time code.
- **Guessing or enumerating tokens.** Mitigation: a 256-bit verifier, constant-time checks,
  per-link limits, a global ceiling on failures, and one neutral answer for every failure.
- **Anonymous load with no per-IP limit (D-13).** Mitigation: malformed tokens rejected before the
  database; per-link and global limits.
- **Disputes over a wrong ledger.** Mitigation: the page says how to ask the landlord to correct
  it; no dispute workflow in the first release.
- **A future data-protection law.** Mitigation: design now for the access and correction rights
  the bill would add.

## Done when

- [ ] A link returns only its own tenancy; pgTAP and Deno tests try every other lease in the
      fixtures.
- [ ] Revoked, rotated and expired links show the same neutral page and no data.
- [ ] No response contains a CNIC, phone number, note, document other than a receipt, or another
      tenancy, checked over fixtures.
- [ ] The page works in English, Urdu and Roman Urdu at 360 px wide with no horizontal scroll,
      and passes the design gates.
- [ ] Every receipt downloads as a PDF on the portfolio's letterhead.
- [ ] The landlord revokes a link in one action and sees when it was last opened.
- [ ] A tenant's request reaches the owners and managers, and the limit holds.
- [ ] The page makes no request to an analytics or support host.

## Questions for the owner

1. Link lifetime: until move-out (and how long after), or a fixed period with renewal?
2. Show the deposit, the agreement and utility bills?
3. May a tenant dispute an entry on the page, or only ask the landlord?
4. A one-time code in the first release, or only when documents are added?
5. On every plan, including Free?
6. On an owner-abroad portfolio, show the caretaker as the contact by default?
