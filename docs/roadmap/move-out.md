# A move-out photo checklist

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `move-out` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Most arguments over a deposit come down to "it was like that when I moved in". Dated photos of
each room, taken at move-in and again at move-out and seen by the tenant both times, settle that
quickly and fairly. Tied to the final meter readings and bills, the same record protects the
landlord from paying a former tenant's electricity dues out of the deposit, as NEPRA ordered in
one 2026 case. The app records what both sides saw; it does not decide what may be deducted.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **No deposit cap, return deadline or inspection duty was confirmed in any province**, and
  secondary sources contradict each other
  ([Commoner Law](https://commoner-law.com/pakistan/housing-rights/security-deposit),
  [Global Property Guide](https://www.globalpropertyguide.com/asia/pakistan/landlord-and-tenant)).
- **In Punjab the agreement records the security, any advance and any pagri**, and an amount not
  recorded cannot later count as pagri
  ([agreement checklist](../../website/src/content/guides/en/tenancy-agreement-checklist.md),
  [LHC bulletin](https://researchcenter.lhc.gov.pk/pdf/CaseLawBulletin/Bulletinfrom16.12.2023to31.12.2023_3d1a.pdf)).
- **Utilities are the hard risk.** In February 2026 NEPRA had the Rs 200,000 deposit an owner
  held recovered from the owner towards a former tenant's electricity dues
  ([NEPRA TCD-05](https://nepra.org.pk/consumer%20affairs/cad/Authority%20Decisions/LESCO/2026/02%20Feb/TCD-05%20740%2018-02-2026%20LESCO.PDF)).
  SNGPL needs the landlord's no-objection certificate for a change of name, and a previous
  tenant's deposit does not transfer
  ([SNGPL](https://www.sngpl.com.pk/page.jsp?pgids=1786&pgname=PAGES_NAME_a&secs=ss7xa852op845&cats=ct456712337&artcl=artuyh709123465)).
  The app's guide already says to settle final bills before returning the deposit
  ([utilities guide](../../website/src/content/guides/en/utilities-in-your-name.md)).
- **Photos and app records are admissible** as electronic evidence (ETO 2002 s.3; Qanun-e-Shahadat
  Articles 73 and 164) _(summary)_
  ([UNODC fiche](https://sherloc.unodc.org/cld/uploads/pdf/El%20Evidence%20Hub/SOUTH_ASIA/eEvidence_Country_Fiche_PAKISTAN.pdf)).
- **Meter readings** already take a `move_in` or `move_out` context
  ([operations.sql](../../supabase/migrations/20261103194151_operations.sql)). Leases hold
  `security_deposit`, `moved_out_on` and `end_reason`
  ([leases.sql](../../supabase/migrations/20261103193403_leases.sql)).
- **Deposit RPCs exist.** `apply_deposit` settles outstanding charges from the deposit as a
  `deposit_adjustment` payment with its own receipt number; `refund_deposit` records money paid
  back in `deposit_refunds`, which can be voided; `charge_kind` includes `damages`
  ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)).
- **There is no inspection entity.** `document_entity`, the storage path check and the bucket's
  path pattern all list entities explicitly; files are limited to 10 MB
  ([documents_storage.sql](../../supabase/migrations/20261103194240_documents_storage.sql)).
  Photos are re-encoded on the device, which drops Exif and GPS
  ([app.md](../architecture/app.md)), but `retrieveLostData` is not handled
  ([document_files.dart](../../app/lib/src/features/documents/data/document_files.dart)).
- **Storage is a plan limit:** 500 MB on Free, 5 GB on Pro, 10 GB on Overseas, 25 GB on Business
  ([pricing](../../website/src/content/pricing/en.yaml)).

## Design

**Tables, in a new migration.** `inspections`: lease, kind (`move_in`, `move_out`), conducted on
and by, tenant present, status (draft, acknowledged, voided), acknowledged at and how
(on-device signature, portal, WhatsApp reply, paper), a report hash, and a void reason.
`inspection_items`: inspection, room or area, item, condition, note, and an optional deduction in
`numeric(14,2)` linked to the charge it raised. Both have RLS by portfolio role and audit
triggers. Once acknowledged, an inspection cannot be edited, only voided with a reason, like a
financial row.

**Photos.** New `document_entity` values `inspection` and `inspection_item`, which also changes
the storage path check, the object-path pattern and the entity check in a new migration. Capture
uses a room template per unit (editable), asks for at least one photo per room, compresses to
about 1 MB at 2,048 pixels, goes through the existing re-encoding that strips Exif and GPS, and
handles `retrieveLostData`.

**Integrity.** Each file's SHA-256 and the server's upload time are stored. On acknowledgement
the report hash covers the items and every photo hash, so neither side can later say a photo was
swapped.

**Comparison.** At move-out each room shows the move-in photo beside the new one.

**Settlement statement.** Deposit held, less each deduction, less unpaid charges, equals the
refund. Each deduction is raised as a `damages` charge (or a utility charge from a final bill)
linked to its inspection item or bill photo. The deductions and unpaid charges are settled
through `apply_deposit`, so they carry a receipt in the gapless series, and the balance is paid
back through `refund_deposit`. Totals are in paisa and tested against the ledger.

**Handover and utilities checklist.** Keys returned (count), final meter readings with photos
(the existing table), final bills paid with a photo, gas no-objection certificate or change of
name, and a disconnection request if the unit stays empty. A warning appears when a connection in
the owner's name has an unpaid bill.

**Prompt at move-in.** Creating a lease offers the move-in inspection, because a move-out record
without one proves little.

**Wording.** The statement records; it does not say what is lawful. A guide "Moving out and the
security deposit", in both languages, states only verified law.

### Residence (decision 1)

For a portfolio whose owner is abroad, a deduction or refund entered by the caretaker stays
pending until an owner confirms it, as cash handovers are confirmed today. Times on the report
show both Pakistan time and the owner's own.

### Letterheads (decision 2)

The inspection report and the settlement statement print on the portfolio's letterhead, in English
and Urdu, through the shared page theme. When a caretaker signs, a block reads "for and on behalf
of the owner, through attorney". Photos make the report large, so it has its own size budget.

### Analytics (decision 3)

No photo, amount or note reaches analytics. A tenant's acknowledgement through the portal or a
WhatsApp reply follows the tenant's consent and messaging records.

## Work

1. **M:** migration: `inspections`, `inspection_items`, the entity values, path check and
   pattern, RLS, audit, void-not-edit; pgTAP; new RPCs added to
   [`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and
   [`permissions.md`](../architecture/permissions.md).
2. **M:** capture flow: room templates, camera with `retrieveLostData`, compression, hashes.
3. **M:** comparison and deductions; settlement through `damages` charges, `apply_deposit` and
   `refund_deposit`, with ledger-tested totals.
4. **M:** bilingual, letterheaded report and acknowledgement: on-device signature first, portal
   and WhatsApp reply when those exist.
5. **S:** handover and utilities checklist; owner confirmation for portfolios whose owner is
   abroad.
6. **S:** move-in prompt at lease creation.
7. **S:** the guide in both languages, after [legal-review](legal-review.md).

## Depends on / Unblocks

- **Depends on:** the letterhead work of decision 2, [legal-review](legal-review.md) (statement
  wording and the guide), [retention](retention.md) (inspection photos kept as evidence),
  [tenant-portal](tenant-portal.md) (acknowledgement by link), [urdu-review](urdu-review.md),
  [push-notifications](push-notifications.md) (reminders to inspect) and [billing](billing.md)
  (storage quotas).
- **Unblocks:** [hostel-mode](hostel-mode.md) (deposit settlement at check-out) and
  [overseas-oversight](overseas-oversight.md) (evidence for an owner abroad). Related:
  [document-reading](document-reading.md), which shares the camera fix.

## Risks

- **A photo's authenticity is disputed.** Mitigation: file hashes, server time and the report
  hash at acknowledgement.
- **Storage cost on small plans.** Mitigation: compression, a photo limit per inspection, and a
  clear message before a quota is reached.
- **People or private papers in photos.** Mitigation: a reminder on the camera screen; GPS
  stripped.
- **Landlords using the statement to justify unlawful deductions.** Mitigation: every deduction
  needs evidence, and the wording says the app records and does not decide.
- **Deposit law turns out to have caps or deadlines.** Mitigation: the guide states only
  verified law and is revised after the lawyer's review.
- **The move-in inspection is skipped.** Mitigation: the prompt at lease creation and a reminder.

## Done when

- [ ] A move-in inspection with at least one photo per room can be completed and acknowledged.
- [ ] Move-out shows each room beside its move-in photo.
- [ ] Every deduction links to a photo, a final bill or an unpaid charge.
- [ ] Settlement totals equal the ledger postings to the paisa, and the deposit adjustment
      carries a receipt in the gapless series.
- [ ] An acknowledged inspection cannot be edited, only voided with a reason (pgTAP).
- [ ] The report renders in English and Urdu with the letterhead, within its size budget.
- [ ] No stored photo carries Exif location.
- [ ] The design lint, goldens and tests pass.

## Questions for the owner

1. How does the tenant acknowledge: a signature on the landlord's phone, the portal link, or a
   WhatsApp reply?
2. Should items carry a condition scale (good, fair, damaged), or notes only?
3. Should a disputed deposit place a retention hold automatically?
4. How many photos per inspection, per plan?
5. Is a short video walk-through wanted as well as photos?
