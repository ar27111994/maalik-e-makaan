# Remove identity documents automatically after a tenancy ends

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `retention` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

## Why it matters

A landlord who keeps the CNIC copies of every past tenant holds exactly what identity fraud runs
on, and no law found asks them to keep it once the tenancy is over. Deleting it on a schedule
lowers that risk. The payments, the receipts and the tenant's name on them stay for the six years
the tax law asks for, so nothing a landlord needs to prove rent is lost. The landlord is told a
month ahead and can hold a file while there is a dispute or unpaid rent.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **The police-registration laws require collecting CNIC copies, not keeping them.** No statute
  was found that requires a landlord to keep them after a tenancy ends
  ([police-registration guide](../../website/src/content/guides/en/police-registration.md)).
- **NADRA advises destroying a CNIC copy once its purpose is fulfilled** _(summary)_
  ([ARY](https://arynews.tv/nadra-issues-advisory-on-essential-documents-photocopies/)).
- **PECA s.16 punishes unauthorised possession or use of identity information** _(summary)_
  ([NHIMG](https://nhimg.org/pakistan-peca-guide)).
- **Financial records must be kept six years after the end of the tax year** under ITO s.174
  ([Business Recorder](https://www.brecorder.com/news/40168577/taxpayer-cant-be-forced-to-produce-record-for-tax-year-beyond-six-years-sc)).
- **Arrears claims expire after three years** under Limitation Act Article 110, or possibly six
  under Article 116 for a registered lease _(summary)_
  ([Sindh High Court](https://caselaw.shc.gov.pk/caselaw/view-file/MTA3NjQzY2Ztcy1kYzgz)).
- **Electronic records satisfy retention duties** under ETO 2002 s.6, subject to conditions
  _(summary)_
  ([ETO](https://pkcert.gov.pk/wp-content/uploads/2023/07/Electronic-Transaction-Ordinance-2002.pdf)).
- **Identity data in the schema:** `tenants` holds the CNIC and its expiry, phones, e-mail,
  addresses, employer, an emergency contact, two references and the guardian's name
  ([properties_units_tenants.sql](../../supabase/migrations/20261103192902_properties_units_tenants.sql));
  `lease_occupants` holds CNICs and phones ([leases.sql](../../supabase/migrations/20261103193403_leases.sql));
  documents of kind `cnic_front`, `cnic_back` and `photo` sit in the private `documents` bucket
  ([documents_storage.sql](../../supabase/migrations/20261103194240_documents_storage.sql));
  `reminder_logs.message_preview` keeps up to 1,000 characters of each reminder
  ([operations.sql](../../supabase/migrations/20261103194151_operations.sql)).
- **Deleting a `documents` row already queues its file** for the storage-cleanup function
  ([membership_deletion_storage.sql](../../supabase/migrations/20261105072426_membership_deletion_storage.sql)).
- **The audit trail keeps what a purge would remove.** Triggers on 17 tables, including
  `tenants`, `lease_occupants` and `documents`, store whole rows on insert and delete and redact
  only `cnic` and `verifier_hash`, so phones and references survive there
  ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql)).
- **The promise today:** version 1.0 deletes no identity document automatically, and backups last
  90 days ([privacy](../../website/src/content/pages/en/privacy.md)). The purge is listed as a
  later requirement ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)).

## Design

**Three classes of data.**

| Class               | What it holds                                                                                                                                                                         | When it goes                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| A, identity media   | Tenant documents of kind `cnic_front`, `cnic_back` and `photo`                                                                                                                        | N months after the tenant's last move-out                                                   |
| B, identifying data | CNIC and expiry, phones, e-mail, addresses, employer, emergency contact, references, guardian's name; occupants' CNICs and phones; reminder previews                                  | Blanked at the same time as A                                                               |
| C, the record       | Payments, receipts, charges, voids, deposit refunds, withholding certificates, the tenant's name and NTN as on receipts, agreement and police reference numbers, move-out inspections | Never by this job; at least six years after the tax year, and while any arrears claim lives |

**Schema, in a new migration.** `portfolios.identity_retention_months` (default N, within set
bounds); `tenants.identity_purge_due_on`, set from the last lease's `moved_out_on` plus N and
cleared if a new lease starts; `retention_hold_reason` and `retention_hold_until`; and a
`retention_events` log holding counts and kinds only, never values. An outstanding balance on any
of the tenant's leases holds the purge automatically, checked at run time.

**The purge.** A definer function takes the portfolio, then the leases, then the tenant rows, in
the global lock order. It deletes class A `documents` rows (the existing trigger queues their
files), blanks class B fields, truncates reminder previews, and redacts the same keys inside
`audit_logs.changes` for that tenant and their occupants. The tenant row stays, archived, with its
name as the anchor for receipts. No financial row is touched, so "voided, never deleted" holds and
the receipt series stays gapless.

**Audit seals.** The redaction must not break the tamper evidence planned in
[audit-screen](audit-screen.md). The two items agree one mechanism before either ships: for
example, seals computed over a form of each row in which identifying values are already replaced
by keyed digests, which the redaction keeps.

**Notice, hold and export.** Thirty days before the purge, the owners get an inbox notification
(a new `notification_kind`), and a push once [push-notifications](push-notifications.md) exists.
One tap holds the file, with a reason (dispute, arrears, police matter) and an end date. Before
the purge, the owner can export the tenant's class A files and class B fields from the device.

**Running it.** A daily step in the existing pg_cron jobs (`run_daily_jobs`), idempotent and
batched, with the first release in a dry-run mode that only reports counts. Tenancies that ended
before the feature ships get a grace period before their first purge.

**Erasure on request.** "Delete identity data now" runs the same function for one tenant, by an
owner only, respecting holds unless the owner overrides one with a reason.

**Out of scope.** Archiving financial records after six years and the limitation period. If it
ever comes, an owner starts it; it never runs on its own.

### Residence (decision 1)

The notice goes to every owner of the portfolio, not only the caretaker, at the owner's own time.
A caretaker may place a hold; only an owner may release one early or purge at once. Due dates are
Pakistan dates.

### Letterheads (decision 2)

Letterhead files belong to the portfolio, not to a tenant: they follow the portfolio's own
deletion, not this schedule.

### Analytics (decision 3)

Tenant data never reaches PostHog, Intercom or Customer.io, so this purge has nothing to send
them. Decision 3 adds the sibling duty: deleting an account fans out to those three services.
`retention_events` never leaves the database.

## Work

1. **S:** the retention schedule as a decision entry in
   [PROJECT.md](../../.planning/PROJECT.md): classes, default N, bounds, hold reasons, notice
   lead time, reviewed by the lawyer.
2. **M:** migration: retention setting, purge-due date and its triggers on lease end and start,
   holds, `retention_events`, the notification kind; pgTAP and an upgrade test for tenancies
   already ended.
3. **M:** purge function, audit redaction, storage deletion through the queue; pgTAP proving
   receipts unchanged and a concurrency scenario against a payment on the same lease.
4. **S:** the daily job with dry-run mode; the 30-day notice; the hold screen in both languages.
5. **S:** export before purge, on the device.
6. **S:** privacy notice, tenant consent text and FAQ in both languages ("and up to 90 days more
   in backups").

## Depends on / Unblocks

- **Depends on:** [legal-review](legal-review.md) (N, the class boundaries, the wording),
  [push-notifications](push-notifications.md) (the notice; the inbox until then),
  [audit-screen](audit-screen.md) (seal compatibility) and [urdu-review](urdu-review.md).
- **Unblocks:** [document-reading](document-reading.md), which may keep an image only if it is
  deleted on schedule, and [hostel-mode](hostel-mode.md), whose short tenancies multiply CNICs.
  Related: [move-out](move-out.md), whose inspection photos are class C and whose disputes place
  holds.

## Risks

- **Deleting evidence needed in a rent claim or a police inquiry.** Mitigation: automatic holds
  for arrears, manual holds, the notice and the export.
- **Deleted values surviving in the audit trail.** Mitigation: the redaction pass, tested by
  pgTAP on `audit_logs.changes`.
- **A purge bug deleting too much.** Mitigation: dry-run first, class C untouched by design, and
  digests of the ledger compared before and after in tests.
- **Copies outside the app** (WhatsApp, galleries, exports). Mitigation: say plainly in the app
  and the privacy notice that these are not reached.
- **Backups keep deleted data for 90 days.** Mitigation: stated in the notice.
- **A returning tenant meets the unique CNIC index.** Mitigation: purged tenants are archived and
  their CNIC blank, so a new record can be made.
- **A future erasure right.** Mitigation: the manual path above.

## Done when

For a tenant whose last lease ended more than N months ago, with no hold:

- [ ] No class A object remains in storage or in `documents`.
- [ ] Class B fields are blank in `tenants`, `lease_occupants`, reminder previews and
      `audit_logs.changes`.
- [ ] Receipt numbers, amounts, voids and balances are byte-identical before and after.
- [ ] The owner was notified at least 30 days earlier, a hold stops the purge, and an
      outstanding balance holds it automatically.
- [ ] `retention_events` holds counts only, and the audit seals still verify.
- [ ] The privacy notice states the schedule in English and Urdu.
- [ ] `make test` passes with the new pgTAP suites.

## Questions for the owner

1. Default N: 3, 6 or 12 months?
2. May owners set N per portfolio, and within what bounds?
3. Keep agreement images, which contain CNIC numbers, as part of the record, or redact them?
4. Keep police registration images, or only the reference number?
5. May a caretaker place a hold?
6. How long a grace period for tenancies that ended before the feature ships?
