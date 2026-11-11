# Draft a payment from a voice note or a pasted SMS, always confirmed

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `draft-payments` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). The text path is for launch; voice notes
and screenshots may move to **The assistant** (due 30 November 2027).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Most rent now arrives by bank transfer, Raast or a wallet, and the landlord already has an SMS
or a screenshot that says so. Typing it into the app again is where entries are skipped or
mistyped. Sharing the message into the app should give a filled-in payment that the landlord
checks and confirms with one tap: never recorded on its own, and never recorded twice.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **`record_payment` is idempotent per key**
  ([ledger_findings.sql](../../supabase/migrations/20261107181820_ledger_findings.sql)). Keys are
  unique per portfolio ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)). It
  stores a SHA-256 fingerprint of the request: lease, amount, date, method, reference, notes,
  tax withheld and chosen charges
  ([ledger_jobs_hardening.sql](../../supabase/migrations/20261104143928_ledger_jobs_hardening.sql)).
  The same request again returns the original payment; the same key with a different request
  fails with `idempotency_key_reused`. It takes the lease lock, allows owners, managers and
  accountants, and is limited to 60 calls a minute.
- **Payment methods** already include `bank_transfer`, `raast`, `jazzcash` and `easypaisa`
  ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)), and proof photos attach as
  documents of a payment ([documents_storage.sql](../../supabase/migrations/20261103194240_documents_storage.sql)).
- **Nothing drafts yet:** no drafts table and no SMS, speech or OCR code.
- **The deck already promises this design:** drafts go through the same `record_payment`, keyed
  so a resent SMS cannot count twice ([agents slide](../../website/deck/slides/agents.html)).
- **Version 1 records payments and does not process them**
  ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)). This item moves no money, so it is data
  processing, not a payment service. Agent payment standards have no Pakistani deployment
  _(summary)_ ([IMF](https://www.elibrary.imf.org/view/journals/068/2026/004/article-A001-en.xml)).
- **Google Play** lets an app read SMS only if it is the default SMS handler _(summary)_
  ([Play policy](https://support.google.com/googleplay/android-developer/answer/10208820?hl=en)).
  iOS gives apps no access to SMS at all.
- **A Raast QR code encodes the payee, not proof of payment** _(summary)_
  ([State Bank QR annex](https://www.sbp.org.pk/disd/2022/CL2-Annex.pdf)).
- **The Android manifest check** already fails a release that lacks a required permission
  ([check_manifest.py](../../tool/android/check_manifest.py)); it checks nothing forbidden yet.

## Design

**Intake.** Text arrives through the Android share sheet (`ACTION_SEND`), an iOS share extension
or paste. The app never asks for `READ_SMS`, and the manifest check fails the build on any SMS or
call-log permission, including one a plugin adds to the merged manifest.

**Extraction, deterministic.** Extractors in `mm_core` read known transfer messages (JazzCash,
Easypaisa, Raast, interbank transfers) and return the amount (through
[amount-parser](amount-parser.md)), the date, the transfer's reference (Raast transaction ID,
interbank STAN or wallet TID) and a masked counterparty. They are tested with synthetic messages
only. A model may suggest which lease a payment belongs to; the amount, date and reference come
only from these parsers.

**Matching.** The lease is suggested from the expected amount, open dues and the payer's name.
The landlord can change any field.

**One transfer, one payment.** The idempotency key is a UUIDv5 of the transfer's own reference
where there is one, and of the normalised message text otherwise. Keying on the reference means
an SMS and a screenshot of the same transfer produce the same key. Because the fingerprint
includes the notes, the notes are built only from the reference, never from the source type, so
the second copy replays instead of failing. If the second copy is matched to another lease or
amount, `idempotency_key_reused` is shown as "this transfer is already recorded", with a link.

**`payment_drafts`.** Portfolio, suggested lease, amount (`numeric(14,2)`), method, reference,
date, source (`text`, `sms`, `screenshot`, `voice`), a redacted excerpt, a hash of the source,
status (`draft`, `confirmed`, `discarded`) and the payment it became. It is not a financial
table, so a draft may be discarded. It is readable and writable by the roles that may call
`record_payment`. The raw text is purged on confirmation or discard; CNICs and full account
numbers are masked in the excerpt.

**Confirmation screen.** The amount in digits and read back in words in the user's language,
the source text with the amount highlighted, and a line saying "check your bank or wallet
balance first". Nothing is saved without the Confirm tap.

**Audit.** The payment's audit entry says "confirmed from a draft (source: SMS)", using the
`source` attribution from [audit-screen](audit-screen.md).

**Voice notes and screenshots** follow the text path: on-device OCR or speech-to-text produce
text, which then goes through the same extractors and read-back.

### Residence (decision 1)

A caretaker can draft and confirm within their manager role. An owner abroad sees confirmed
drafts, with their source, in the audit screen and their digest. The payment date stays a
Pakistan date; the confirmation time is shown in the owner's own time zone too.

### Letterheads (decision 2)

The receipt produced on confirmation is the ordinary receipt, so it carries the portfolio's
letterhead.

### Analytics and AI providers (decision 3)

No message text, amount or name is sent to analytics. On-device recognition is preferred. A cloud
speech-to-text or OCR provider is a processor: it needs explicit consent (Apple guideline
5.1.2(i), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)), a
line in the privacy notice, and no retention.

## Work

1. **S:** UUIDv5 key derivation in Dart, TypeScript and SQL, with contract vectors.
2. **M:** transfer-message extractors in `mm_core`, with synthetic vectors.
3. **M:** `payment_drafts` migration, RPCs to create, discard and confirm, pgTAP (the same
   transfer from SMS and screenshot records once); the new definer RPCs added to
   [`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and
   [`permissions.md`](../architecture/permissions.md).
4. **M:** paste and share flow (Android intent, iOS share extension) with the read-back
   confirmation screen in both languages, with goldens.
5. **S:** audit source marking; raw-text purge; forbidden permissions in the manifest check.
6. **M:** screenshots through on-device OCR into the text path.
7. **M:** voice notes through speech-to-text into the text path, after the provider decision.

## Depends on / Unblocks

- **Depends on:** [amount-parser](amount-parser.md) (hard), [audit-screen](audit-screen.md),
  [legal-review](legal-review.md) (any provider in the privacy notice),
  [urdu-review](urdu-review.md), and the consent records of decision 3.
- **Unblocks:** [whatsapp-assistant](whatsapp-assistant.md), which reuses the drafts table, and
  [reconciliation](reconciliation.md), which reuses the extractors. Related:
  [agent-limits](agent-limits.md).

## Risks

- **Fake "payment received" SMS or edited screenshots.** Mitigation: never auto-confirm; the
  screen asks the landlord to check the balance first.
- **A transfer without a reference counts twice** (one SMS and a differently cropped screenshot).
  Mitigation: warn when a draft matches an existing payment by lease, amount and date.
- **SMS permissions creep into the manifest** through a plugin. Mitigation: the manifest check
  in CI on the merged release manifest.
- **Third parties' data in messages** (a relative who paid). Mitigation: excerpts masked, raw
  text purged.
- **Urdu speech recognition misreads numbers.** Mitigation: the deterministic parser and the
  read-back; refusing beats guessing.

## Done when

- [ ] Nothing is recorded without a Confirm tap.
- [ ] Sharing a message twice, or the SMS and then a screenshot of the same transfer, yields one
      payment, in Dart and SQL tests.
- [ ] Every amount comes from `mm_core` and is read back in words in both languages.
- [ ] The release manifest has no SMS or call-log permission.
- [ ] No raw message text remains after confirmation or discard.
- [ ] Every confirmed draft appears on the audit screen with its source.

## Questions for the owner

1. Drafts on the server (needed later for WhatsApp) or only on the device until confirmed?
2. On-device speech-to-text only, or a cloud service with no retention?
3. Allow a draft without a transfer reference, with a duplicate warning?
