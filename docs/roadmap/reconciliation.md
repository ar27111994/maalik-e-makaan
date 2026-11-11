# Suggested matches between incoming payments and open dues

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `reconciliation` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

A landlord with twenty tenants paying by Raast, bank transfer and wallet ends each month with a
statement full of credits and no quick way to see which tenant paid which month. Matching them by
hand is slow, and it is where payments are missed or entered twice. The app should read the
statement or the alerts the landlord shares, put each credit beside the due it most likely pays,
and let the landlord approve it with a tap. Nothing is recorded without that approval, and the
landlord's other transactions never leave the phone.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **The ledger is ready to receive matches.** `payment_method` already has `bank_transfer`,
  `raast`, `jazzcash`, `easypaisa` and `cheque`; `payments.reference` holds up to 80 characters
  ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)). `record_payment` takes an
  idempotency key, a reference and an explicit list of charges (`p_charge_ids`), replays the same
  request and refuses a reused key with a different request, and is limited to 60 calls a minute
  ([ledger_jobs_hardening.sql](../../supabase/migrations/20261104143928_ledger_jobs_hardening.sql)).
- **Open dues can be read per lease** through `get_receivables` (outstanding, overdue, oldest
  overdue date) ([reports.sql](../../supabase/migrations/20261103194625_reports.sql)).
- **Nothing imports.** The app exports CSV (RPT-03 in
  [REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)) but reads no statement, file or message.
- **The extractors and the key are planned elsewhere.** [draft-payments](draft-payments.md)
  plans transfer-message extractors in `mm_core` and a UUIDv5 idempotency key derived from the
  transfer's own reference.
- **Raast person-to-person transfers** ran at 535 million in the first quarter of FY26
  ([INP](https://www.inp.net.pk/news-detail/inp-wealthpk/raast-processes-544-million-transactions-in-q1-fy26))
  and 664 million in a later quarter _(summary)_
  ([State Bank press release](https://www.sbp.org.pk/press/2026/Pr-25-Jun-2026.pdf)).
- **Every Raast credit advice must name the counterparty** _(summary)_
  ([SBP DISD Circular 1 of 2022](https://www.sbp.org.pk/disd/2022/C1.htm)).
- **No published SMS format** for Raast or interbank credit alerts was found. One unofficial,
  possibly dated FAQ says HBL statements download as CSV, Excel or PDF
  ([HBL FAQ](https://www.scribd.com/document/459398926/HBL-InternetBanking-FAQs-pdf)).
- **Google Play** allows SMS permissions only to the default SMS handler or a declared exception,
  and forbids "alternative methods" of deriving SMS data _(summary)_
  ([Play policy](https://support.google.com/googleplay/android-developer/answer/10208820?hl=en)).
- **No consent-based bank-data API exists yet.** The State Bank published draft Open Banking
  Regulations on 30 October 2026, with comments due on 30 November 2026 _(summary)_
  ([SBP press release](https://www.sbp.org.pk/assets/documents/press-release/PR-30-October-2026.pdf)).

## Design

**Inputs, in this order.**

1. Text the landlord shares or pastes: the Android share sheet, an iOS share extension or the
   clipboard. No SMS or notification-listener permission, ever.
2. CSV and Excel statements, through a column-mapping step saved as a profile per bank, rather
   than a hard-coded parser per bank.
3. Text PDFs (bank and wallet e-statements), read on the device. Scanned statements wait for
   [document-reading](document-reading.md).
4. Later: Request-to-Pay references and open-banking feeds.

**Parse on the phone, upload only what is kept.** Each line becomes a normalised credit: date,
amount in paisa, direction, counterparty, reference, channel and a hash of the source line.
Debits and dismissed lines never leave the device, and raw files are never stored. Kept credits
go to `incoming_credits` (amount in `numeric(14,2)`, masked counterparty, reference, source hash,
status, the payment it became), deleted a set number of days after they are resolved.

**Matching is pure Dart in `mm_core`, and it only suggests.** Candidates are the portfolio's open
charges. A suggestion scores:

- the amount: exact paisa against one due, against up to three consecutive dues of one lease, or
  against a lease's whole balance;
- the date: from 10 days before to 45 days after the due date, configurable;
- the payer name, compared tolerantly across Urdu and Latin script, with the tenant's name, the
  guardian's name and learned payer aliases;
- the reference, when it contains the unit label, a receipt prefix or the tenant's payment code.

Suggestions fall into three tiers: strong (amount and name), possible (amount and date) and weak
(name only, for part payments). Two equally strong candidates are both shown; neither is picked.

**Approval records through the existing path.** An `approve_incoming_credit` RPC takes the
portfolio lock, then the lease, and records the payment with `record_payment`'s rules: the method
from the channel, the reference from the bank or Raast transaction ID, and the charges chosen.
The key uses the same derivation as [draft-payments](draft-payments.md): the transfer's reference
where there is one, the source-line hash otherwise. The notes are built only from that reference,
so the fingerprint matches, and an SMS confirmed as a draft and the same transfer later found in a
statement record one payment. A credit split across two leases records two payments, keyed on the
credit and the lease. Approving also offers to save the payer's name as an alias for that tenant;
aliases are visible and editable.

**Duplicates across sources** are removed on date (within one day), amount and reference, before
any suggestion is shown.

**References help.** Receipts and the [tenant-portal](tenant-portal.md) link show the tenant a
short payment code for the transfer's reference field.

### Residence (decision 1)

A caretaker with the `manager` role may approve suggestions. Importing the owner's own bank
statement on a caretaker's phone would show the caretaker the owner's other transactions, so by
default only the account holder imports their own statement, and the debits are dropped on that
device whoever imports. An owner abroad can import their Pakistani account's statement from
abroad. Credit dates stay Pakistan dates; approvals appear in the audit trail and in the owner's
digest at their own time.

### Letterheads (decision 2)

An approved credit produces the ordinary receipt, which carries the portfolio's letterhead. This
item adds no new document.

### Analytics (decision 3)

No amount, name, reference or statement line reaches analytics. After opt-in, an import may send
only counts (lines read, suggestions made, suggestions approved). Parsing is on the device; no
third-party service reads a statement.

## Work

1. **S:** contracts for a normalised credit and for match scoring, with synthetic vectors in
   `contracts/` for Dart and SQL; no real statements.
2. **M:** the matching engine in `mm_core`, with property tests (amount, up to three dues, date
   window, names across scripts).
3. **M:** share-target and paste parser for message text, reusing the extractors from
   [draft-payments](draft-payments.md), on Android and iOS.
4. **M:** CSV and XLSX import with column mapping and saved bank profiles.
5. **M:** text-PDF import for bank and wallet statements; split by layout family if it grows
   past a week.
6. **M:** `incoming_credits` and `payer_aliases` migration, the deletion job, the approval RPC,
   pgTAP and a concurrency scenario (an approval racing a manual payment on the same lease); the
   new RPC added to
   [`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and
   [`permissions.md`](../architecture/permissions.md).
7. **M:** review inbox (approve, split across dues, dismiss as not rent) in English and Urdu,
   with goldens.
8. **S:** privacy text and data export: debits never leave the device; kept credits are deleted
   after resolution.

## Depends on / Unblocks

- **Depends on:** [amount-parser](amount-parser.md) (every amount),
  [draft-payments](draft-payments.md) (extractors and the key derivation),
  [tenant-portal](tenant-portal.md) (the payment code), [audit-screen](audit-screen.md)
  (approvals shown with their source), and [urdu-review](urdu-review.md) for the strings.
- **Unblocks:** [raast-request-to-pay](raast-request-to-pay.md), which reconciles by reference,
  and [open-banking](open-banking.md), which becomes one more input. Related:
  [push-notifications](push-notifications.md) for an optional "new credits to match" nudge.

## Risks

- **Formats change and SMS formats are unpublished.** Mitigation: column mapping and saved
  profiles instead of fixed parsers; a line that does not parse is shown, never guessed.
- **The payer is often not the tenant, and branch cash deposits carry no name.** Mitigation:
  aliases, and amount-and-date suggestions shown as "possible", never "strong".
- **A statement holds the landlord's other transactions.** Mitigation: debits dropped on the
  device, proved by a network test.
- **Play treats a share target as SMS-derived data.** Mitigation: the user shares text
  explicitly; confirm against Google's current policy text before release.
- **People expect it to be automatic.** Mitigation: the inbox says plainly that nothing is
  recorded until approved; a wrong approval is voided with a reason, as any payment.

## Done when

- [ ] On a synthetic month of 60 credits, 25 of them rent from 20 leases (with three two-month
      lump sums and two payers who are not the tenant), the right match is the top suggestion
      for at least 90% of the rent credits.
- [ ] No payment is recorded without a person's approval.
- [ ] Importing the same file twice, or a credit shared as an SMS and then found in a statement,
      creates no duplicate suggestion or payment, in Dart and pgTAP tests.
- [ ] A network-layer test shows that no debit or dismissed line leaves the device.
- [ ] A 500-line CSV parses offline in under 2 seconds on a mid-range Android phone.
- [ ] Kept credits are deleted the set number of days after resolution (pgTAP).
- [ ] Every string exists in English and Urdu, and the design lint passes.

## Questions for the owner

1. Which banks and wallets first, and may friendly users share their own export layouts with the
   data replaced?
2. Keep unmatched credits on the server, or on the device until they are matched?
3. May a caretaker import the owner's statement?
4. Match debits too (utility bills, expenses), or only rent credits?
5. How many days should resolved credits stay on the server: 30?
6. Send comments on the State Bank's open-banking draft by 30 November 2026, asking for the
   remitter's name and reference in transaction data?
