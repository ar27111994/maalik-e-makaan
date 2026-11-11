# An oversight assistant for owners abroad

Milestone **Money that moves** (`money`), due 30 November 2028. Issue `overseas-oversight` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). Unlike the rest of the milestone it needs no
regulator or partner, so the rules should be built in the second half of 2027, once the residence
fields and [push-notifications](push-notifications.md) exist. Only the evidence pack's legal
review and Munshi's explanations belong in 2028.

## Why it matters

An owner in Riyadh, Dubai or London whose brother or a hired caretaker collects the rent cannot
see from abroad whether cash is piling up, whether a payment was voided, or whether the bank
details tenants pay into have changed. A short list of plain checks, run on the records the
caretaker already keeps, tells the owner when something needs a look, at a sensible hour where
they live. It also gives them a record they can forward to family or a lawyer, which matters
because overseas property disputes are decided on documents.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **Handovers exist, and only owners confirm or void them**
  ([operations.sql](../../supabase/migrations/20261103194151_operations.sql)).
- **Cash in hand is computed per member** by `get_cash_positions`: cash payments received, minus
  handovers, minus cash expenses
  ([reports.sql](../../supabase/migrations/20261103194625_reports.sql)). It subtracts a handover
  as soon as it is recorded, before an owner confirms it, and does not add cash a member received
  from another member. `CashInsight` flags non-owners who hold cash, and a month in which cash is
  half or more of the money received
  ([insight_rules.dart](../../app/lib/src/features/insights/application/insight_rules.dart)).
- **Caretakers can change money records.** Managers may void payments
  ([ledger_jobs_hardening.sql](../../supabase/migrations/20261104143928_ledger_jobs_hardening.sql)),
  waive charges ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)), and add,
  edit and delete expenses
  ([concurrency_findings.sql](../../supabase/migrations/20261105170557_concurrency_findings.sql)).
  Only owners may change the portfolio's Raast ID, IBAN or phone
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **The audit trail and the delivery plumbing exist.** Triggers on 17 tables, `portfolios`,
  `payments`, `expenses` and `cash_handovers` among them, write old and new values to
  `audit_logs`, and `notifications` rows carry a kind, parameters and a de-duplication key
  ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql)).
  `private.run_daily_jobs()` runs every ten minutes
  ([ledger_jobs_hardening.sql](../../supabase/migrations/20261104143928_ledger_jobs_hardening.sql)).
- **Residence is not recorded yet.** `profiles` has no country or time zone, and `portfolios` no
  owner-abroad flag or caretaker; decision 1 adds them.
- **The Overseas plan already promises** "Your caretaker records rent and receipts; you confirm
  cash handovers and read the owner statement", with the monthly e-mailed statement marked as
  planned ([pricing](../../website/src/content/pricing/en.yaml)). The statement PDF exists
  (RPT-02 in [REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)).
- **The problem is trust.** About 90% of overseas complaints in Punjab concern illegal
  occupation, often by close relatives ([Punjab government](https://punjab.gov.pk/node/2038)).
  Special courts for overseas Pakistanis' property sit in 37 Punjab districts
  ([Dawn](https://www.dawn.com/news/1954351)) and, since May 2026, hear those disputes alone
  _(summary)_ ([Dawn](https://www.dawn.com/news/1998204)); a Khyber Pakhtunkhwa bill of May 2026
  covers rent recovery
  ([ProPakistani](https://propakistani.pk/2026/05/12/kp-assembly-passes-bill-for-special-courts-to-protect-properties-of-overseas-pakistanis/)).
- **The market.** Property managers charge 5 to 10% of rent, a vendor's figure
  ([Chakor](https://chakorventures.com/?p=39494)). No app was found that gives overseas owners a
  caretaker cash ledger with confirmed handovers.

## Design

**Rules, not a model's judgement.** A fixed catalogue of named checks, each with a default
threshold the owner can change per portfolio, written as contract vectors in `contracts/` so that
SQL and Dart agree.

| Rule                      | Raised when                                                                 | Severity |
| ------------------------- | --------------------------------------------------------------------------- | -------- |
| `cash_held`               | a non-owner holds cash above a rupee limit or N days of rent                | medium   |
| `cash_not_handed_over`    | cash collected more than N days ago is not yet handed over                  | medium   |
| `handover_unconfirmed`    | a handover has waited more than N days for an owner                         | low      |
| `changed_by_non_owner`    | a payment voided, or a charge waived or reduced, by anyone but an owner     | medium   |
| `cash_expense_changed`    | a cash expense edited or deleted by a non-owner, or above N with no receipt | medium   |
| `backdated_entry`         | a payment dated more than N days before it was entered                      | medium   |
| `rent_lowered`            | a lease renewed or re-let at a lower rent                                   | medium   |
| `long_vacancy`            | a unit vacant more than N days, more so if its meter readings rise          | medium   |
| `payment_details_changed` | the portfolio's Raast ID, IBAN or landlord phone changed                    | high     |
| `silence`                 | nothing recorded for 30 days on a portfolio with live leases                | medium   |
| `registration_overdue`    | a tenant's police registration is past its deadline                         | medium   |

**Cash that counts.** A new read function splits handovers into confirmed and awaiting
confirmation, and adds cash received from another member to the receiver. Findings count
confirmed handovers only.

**Findings.** `oversight_findings`: portfolio, rule, severity, subject, an amount in
`numeric(14,2)` where one applies, the rows behind it, first and last seen, acknowledgement and
resolution. A partial unique index keeps one open finding per rule and subject. A step in the
ten-minute job evaluates state rules over current rows, and event rules over `audit_logs` since
the last run with an overlap margin, so a late commit is still seen and the overlap cannot
duplicate. A finding resolves itself when its condition clears.

**Delivery.** An owner inbox, where each finding links to its rows and can be acknowledged or
resolved with a note. A weekly digest e-mail at 09:00 in the owner's time zone: cash in hand per
holder, open findings and handovers to confirm. Push for high-severity findings through a new
`oversight_finding` notification kind, within 15 minutes and outside quiet hours.

**Who sees what.** Owners see everything. By default the caretaker sees only to-dos (cash to hand
over, registrations due); the owner can change that. The caretaker's invitation and settings say
plainly that owners see cash in hand and these checks.

**Evidence pack.** A PDF and CSV for one property and date range, extending the owner statement:
payments with receipt numbers, handovers with confirmations, voids and waivers with reasons, rent
and payment-detail changes, who did each and when, and the seal check from
[audit-screen](audit-screen.md). Photos are listed with dates and file hashes and shared beside
it. The wording states what was recorded, never what the law requires, and a lawyer reviews it.

**The model only phrases.** From 2028 Munshi may put a finding into plain words from its fields.
Every amount and date in the text is checked against the finding; the model never decides one.

### Residence (decision 1)

This item is decision 1 at work. The rules are on for portfolios marked `owner_abroad`, and any
owner can switch them on elsewhere. The member in `caretaker_user_id` is the caretaker, though
every non-owner's cash is watched. Day thresholds count Pakistan dates; the digest and pushes
follow each owner's declared time zone and quiet hours and show both times ("3:15 pm in Lahore
(10:15 am in London)"). Amounts stay in rupees, with an indicative total in the owner's currency
labelled with the rate's date.

### Letterheads (decision 2)

The evidence pack and the e-mailed owner statement print on the portfolio's letterhead, through
the same page theme as every other PDF.

### Consent and analytics (decision 3)

The digest is a service message the owner switches on, so it needs no marketing consent. It goes
through Customer.io's transactional path with link tracking and message retention off, because it
carries names and amounts. No finding, amount or name reaches analytics; counts come from server
aggregates. The caretaker's activity history is personal data, listed in the privacy notice and
the data export.

## Work

1. **S:** rule catalogue, default thresholds and contract vectors.
2. **M:** cash position per holder (confirmed and awaiting handovers, cash passed between
   caretakers), with pgTAP over voided rows.
3. **M:** `oversight_findings`, RLS and the job step (de-duplication, auto-resolution, audit
   overlap); pgTAP and a [`concurrency_test.sh`](../../tool/db/concurrency_test.sh) scenario of
   two runs at once and a run racing an acknowledgement.
4. **S:** the notification kind and per-portfolio settings: rules, thresholds, caretaker
   visibility.
5. **M:** owner inbox with acknowledge and resolve, in English and Urdu, with goldens.
6. **M:** weekly digest e-mail at the owner's local time, in both languages.
7. **S:** high-severity push through [push-notifications](push-notifications.md).
8. **S:** caretaker transparency text, privacy notice and data export.
9. **M:** evidence-pack PDF and CSV, and the lawyer's review of its wording.
10. **M (2028):** Munshi phrasing in the inbox and digest, checked against each finding's amounts
    and dates, with a switch back to the fixed text.

No audit work is needed for payment-detail changes: the `portfolios` trigger already records them.

## Depends on / Unblocks

- **Depends on:** the residence fields of decision 1 (`owner_abroad`, `caretaker_user_id`,
  `profiles.time_zone`); [push-notifications](push-notifications.md);
  [audit-screen](audit-screen.md) (the trail and its seals); [retention](retention.md) (photos
  held while a finding is open); [legal-review](legal-review.md) (the pack's wording);
  [agent-limits](agent-limits.md) if an assistant ever records cash; and
  [whatsapp-assistant](whatsapp-assistant.md) for Munshi's phrasing.
- **Unblocks:** [agent-coordination](agent-coordination.md) (the caretaker-to-owner handover).
  Related: [raast-request-to-pay](raast-request-to-pay.md) (payout-account changes),
  [hostel-mode](hostel-mode.md) (a warden's cash) and [move-out](move-out.md) (evidence).

## Risks

- **False alarms hurt a family's trust**, since the caretaker is often a brother or a parent.
  Mitigation: thresholds the owner sets; a weekly digest for all but high severity; wording that
  states facts ("Rs 60,000 collected 15 days ago, not yet handed over") and accuses no one.
- **The caretaker stops using the app.** Mitigation: the `silence` rule.
- **It feels like surveillance.** Mitigation: the caretaker is told, and the to-dos help them too.
- **The pack is read as legal advice.** Mitigation: the lawyer's review; it records, not concludes.
- **A model misstates an amount.** Mitigation: it only phrases, and its text is checked.

## Done when

- [ ] A caretaker holding Rs 60,000 in cash across three leases for 15 days produces exactly one
      `cash_not_handed_over` finding of Rs 60,000.00, linked to the three payments; it resolves
      within one run after an owner confirms a handover of Rs 60,000 (pgTAP).
- [ ] A recorded but unconfirmed handover does not lower the cash the findings use.
- [ ] An IBAN change reaches every owner by push within 15 minutes, never between 22:00 and 08:00
      owner-local time, before and after British Summer Time ends.
- [ ] Re-running the job, or two runs at once, never duplicates a finding.
- [ ] A caretaker sees only the findings the owner allowed (RLS tests).
- [ ] The evidence pack for a property and month reconciles to the ledger to the paisa.
- [ ] Every string exists in English and Urdu, and no finding content reaches analytics.

## Questions for the owner

1. Cash-held thresholds in rupees or days of rent, and after how many days is cash flagged?
2. Should caretakers see every finding, only to-dos, or none?
3. Can several owners abroad, such as siblings, all receive the alerts?
4. Should a "caretaker lives in the property" flag prompt a written caretaker agreement?
5. Which channels: inbox, e-mail, push, or WhatsApp through `wa.me`?
6. May a high-severity finding break quiet hours?
7. When should the evidence pack ship, and who reviews its wording?
