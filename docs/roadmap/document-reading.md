# Read CNICs and agreements on the phone, with masking and consent

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `document-reading` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Typing a tenant's CNIC number, father's name and the agreement's rent and dates is slow, and a
wrong digit stays wrong for years. Most tenants already hand over a photo of the card. Reading
that photo on the phone fills the form, while masking the number before anything else sees it
and recording the tenant's consent keep the landlord within NADRA's advice. Every field read from
a photo stays a suggestion until the landlord confirms it.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **Tenants carry one generic consent:** a date and a note (`consent_recorded_at`,
  `consent_note`). `tenants.cnic` is 13 digits, unique per portfolio among tenants not archived
  ([properties_units_tenants.sql](../../supabase/migrations/20261103192902_properties_units_tenants.sql)),
  and the audit trail redacts it
  ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql)).
- **`mm_core` parses and masks CNICs** (`Cnic.tryParse`, `masked`)
  ([cnic.dart](../../packages/mm_core/lib/src/identity/cnic.dart)). Decision D-09: never infer
  gender from a CNIC, and mask CNICs by default ([PROJECT.md](../../.planning/PROJECT.md)).
- **Document kinds** `cnic_front`, `cnic_back` and `tenancy_agreement` exist
  ([documents_storage.sql](../../supabase/migrations/20261103194240_documents_storage.sql)).
  Photos are re-encoded on the device before upload, which drops Exif and GPS
  ([app.md](../architecture/app.md)).
- **The app has no OCR or machine-learning dependency**
  ([pubspec.yaml](../../app/pubspec.yaml)), and the download budget is 15 MB
  ([PROJECT.md](../../.planning/PROJECT.md)).
- **A camera capture can be lost on Android:** `ImagePicker.retrieveLostData` is not handled, so
  a photo is lost if Android kills the app while the camera is open
  ([document_files.dart](../../app/lib/src/features/documents/data/document_files.dart)).
- **ML Kit reads Latin, Chinese, Devanagari, Japanese and Korean text, not Urdu script**
  _(summary)_
  ([ML Kit](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages)).
- **Server OCR reads Urdu.** Cloud Vision lists Urdu, at US$1.50 per 1,000 pages after 1,000 free
  a month _(summary)_ ([Cloud Vision pricing](https://cloud.google.com/vision/pricing?hl=hu)); Azure
  Read lists printed Urdu _(summary)_
  ([Azure](https://learn.microsoft.com/en-us/azure/ai-services/computer-vision/language-support)).
  Large language models beat classic OCR on Nastaliq in an Urdu newspaper benchmark _(summary)_
  ([arXiv 2505.13943](https://arxiv.org/html/2505.13943v3)).
- **NADRA advises against unnecessary CNIC copies**; where one is unavoidable, write the purpose
  on it and destroy it afterwards _(summary)_
  ([ARY](https://arynews.tv/nadra-issues-advisory-on-essential-documents-photocopies/)).
- **Police registration needs CNIC copies** in every province's procedure
  ([police-registration guide](../../website/src/content/guides/en/police-registration.md)).
- **No data-protection statute is in force;** the Personal Data Protection Bill is still a draft
  _(summary)_ ([CyberSilo](https://cybersilo.tech/pakistan-personal-data-protection-bill)).
- **Apple asks for explicit consent** before personal data is shared with a third-party AI
  service (guideline 5.1.2(i),
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

## Design

**Capture.** The camera flow handles `retrieveLostData`, keeps the image in app-private
temporary storage and uploads nothing by default.

**Latin OCR on the device.** ML Kit text recognition reads the card and English documents on the
phone. The spike measures the Android Play-services and bundled variants against the 15 MB
budget.

**Mask first.** Before any other step, the app finds every 13-digit CNIC pattern (with or without
dashes or spaces) and blurs its box in the image and replaces it in the text. Anything that leaves
the device carries no CNIC digit at all. On screen the number appears in the existing masked form,
with a hold-to-reveal for checking it against the card.

**Suggestions, confirmed one by one.** Name, father's or husband's name as printed, CNIC number
and expiry become suggestions in the tenant form, each confirmed by a tap. The relation comes
only from the printed label, never from the number (D-09). The full number is confirmed by a
person and stored only in the existing `tenants.cnic` column.

**English agreements, bills and receipts** use templates on the device: rent, deposit, start date
and term; bill reference and amount. Every amount goes through
[amount-parser](amount-parser.md) and is read back in words.

**Urdu agreements go to a server, masked.** The landlord sees the masked image before it is sent
and can blur more (Urdu-numeral CNICs, signatures, thumbprints). A `document-ocr` Edge Function
sends it to the chosen OCR vendor with no retention, returns text, and keeps nothing. An optional
model pass maps the OCR text to a fixed set of fields and is told nothing else; its output is a
suggestion like any other.

**Consent before saving.** A `tenant_consents` row, in the shared consent shape (subject,
purpose, text version, granted and withdrawn times, method, evidence, recorded by), is written
before any extracted field is saved, with purposes `identity_capture`, `agreement_reading` and
`server_ocr`. The existing consent date and note are carried over. Until tenants can confirm
through [tenant-portal](tenant-portal.md), the landlord attests the tenant's consent; afterwards
the tenant confirms.

**Images.** None are kept by default. An owner who keeps a CNIC copy for police registration
stores it as a `cnic_front` or `cnic_back` document with its purpose, and [retention](retention.md)
deletes it after the tenancy.

### Residence (decision 1)

A caretaker usually captures. An owner abroad sees on the audit screen which tenant records were
filled from a document, by whom and when, with both times shown, and the attester of each consent.

### Analytics and AI providers (decision 3)

No image, text or field value reaches analytics. The consent rows share their shape with the
account holders' `consents` table. A server OCR vendor or model is a processor: it needs the
tenant's `server_ocr` consent, a line in the privacy notice naming the vendor and region, and
no-retention terms. Masked images would be processed in Google or Microsoft regions outside
Pakistan, which the owner must accept first.

## Work

1. **S:** `retrieveLostData` handling, routing a recovered photo into the flow that was open
   (also needed by [move-out](move-out.md)).
2. **S:** spike on synthetic specimen CNICs and agreements: accuracy, masking boxes, download
   size.
3. **M:** capture, OCR, CNIC detection and masking of image and text on Android and iOS, with a
   network-capture test.
4. **M:** `tenant_consents` migration carrying over the existing consent fields, RLS, pgTAP and
   an upgrade test in `tool/db/upgrade/`.
5. **M:** suggestion and confirmation UI in both languages, with goldens.
6. **M:** English agreement, bill and receipt templates through the amount parser.
7. **M:** `document-ocr` Edge Function for Urdu: vendor, region, a monthly cost cap per account,
   no stored image.
8. **S:** evaluation set of synthetic Nastaliq agreements, printed and photographed, with field
   accuracy per vendor.
9. **S:** the optional field-mapping model pass with a fixed schema; privacy and consent text in
   both languages.

## Depends on / Unblocks

- **Depends on:** [retention](retention.md) (any kept image must be deleted on schedule),
  [legal-review](legal-review.md) (consent text, server OCR in the notice),
  [tenant-portal](tenant-portal.md) (tenant-side consent), [audit-screen](audit-screen.md),
  [amount-parser](amount-parser.md) and [urdu-review](urdu-review.md).
- **Unblocks:** [hostel-mode](hostel-mode.md) (check-in at volume) and
  [reconciliation](reconciliation.md) (scanned statements). Related:
  [draft-payments](draft-payments.md), whose screenshots share the on-device OCR, and
  [move-out](move-out.md), which shares the camera fix.

## Risks

- **A masking bug leaks numbers to a vendor.** Mitigation: masking runs before any other step,
  tested by network capture on every synthetic specimen; nothing unmasked is ever queued.
- **Urdu-numeral CNICs in an Urdu agreement are not detected by Latin OCR.** Mitigation: the
  landlord's preview with manual blur, and a server-side check that refuses text containing a
  13-digit run in either script.
- **The download budget.** Mitigation: measure in the spike; prefer the Play-services model on
  Android.
- **Instructions planted in a photographed document.** Mitigation: the model only fills fixed
  fields, and a person confirms every field.
- **Landlord-attested consent is weak evidence.** Mitigation: the attester is recorded, and the
  tenant confirms through the portal once it exists.
- **A photo is mistaken for verification.** Mitigation: the app says it reads the card and does
  not check it with NADRA.

## Done when

- [ ] Network capture on Android and iOS shows no unmasked CNIC digit leaving the device for any
      synthetic specimen.
- [ ] No extracted field is saved without a person's confirmation and a `tenant_consents` row for
      its purpose.
- [ ] With image storage off, nothing but the confirmed fields remains after the flow, in storage
      or in temporary files.
- [ ] Field accuracy on the synthetic evaluation set meets the owner's threshold per document
      type.
- [ ] Existing consent dates and notes survive the migration (upgrade test).
- [ ] The release stays within the download budget, or the measured increase is accepted.
- [ ] Every string exists in English and Urdu, and the design lint passes.

## Questions for the owner

1. Which document first: the CNIC, an English agreement, an Urdu agreement or a utility bill?
2. Keep CNIC images for police registration at all, or only the number and the police reference?
3. Allow server OCR for Urdu agreements, with masked images processed outside Pakistan?
4. Who may attest consent before tenants confirm it: the owner only, or a caretaker too?
5. What field accuracy is good enough to offer each document type?
