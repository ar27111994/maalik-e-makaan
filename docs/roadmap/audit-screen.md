# A screen that shows who changed what

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `audit-screen` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

A landlord who lets a caretaker, an accountant or a relative record rent needs to see who
recorded, changed or voided each payment, and when. For an owner abroad it is the main way to
check a caretaker. The database already keeps this history, but nobody can read it in the app,
and no assistant may write until a person can see what it did.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **The trail exists** ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql)):
  `audit_logs` is append-only and written by triggers on 17 tables (portfolios, members,
  properties, units, tenants, leases, rent changes, occupants, charges, payments, deposit
  refunds, expenses, utility accounts and bills, maintenance, cash handovers, documents). Each
  row holds the action, the table, the record, the actor (`auth.uid()`) and `changes`: the full
  row, or old and new values per changed column. CNICs and `verifier_hash` are redacted. Owners
  and managers can read it; it is indexed by portfolio and time, and by record.
- **Four tables are not audited:** `meter_readings`, `reminder_logs`, `portfolio_invitations`
  and `payment_allocations`.
- **Nothing in the app reads the trail.** TEAM-05 is only partly met
  ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)).
- **The paging cursor reads `id` as a string** ([paging.dart](../../app/lib/src/data/paging.dart)),
  while `audit_logs.id` is a `bigint` identity.
- **Former members have no readable name:** profiles are readable only for current teammates
  (`app.my_teammate_ids`, [identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **Deleting a portfolio deletes its trail.** On 5 November 2026 the foreign key from
  `audit_logs` to `portfolios` was dropped, because its check took the portfolio key after the
  audited row and deadlocked against deletions. A deletion now removes the trail explicitly and
  the daily cleanup removes rows written during a race
  ([membership_deletion_storage.sql](../../supabase/migrations/20261105072426_membership_deletion_storage.sql)).
- **Scale:** the stress harness's largest portfolio has 32,716 audit rows
  ([permissions.md](../architecture/permissions.md)).
- **Redaction is by column name only**, so tenant phone numbers and notes appear in `changes`.
- **Retention:** the Income Tax Ordinance (s.174) requires records to be kept for six years after
  the end of the tax year _(summary)_
  ([Business Recorder](https://www.brecorder.com/news/40168577/taxpayer-cant-be-forced-to-produce-record-for-tax-year-beyond-six-years-sc)).
- **Tamper evidence:** the usual pattern is a hash chain written by an insert trigger, which has
  to serialise inserts to keep the chain in order _(summary)_
  ([AppMaster](https://appmaster.io/blog/tamper-evident-audit-trails-postgresql)).

## Design

**Feed.** A `SECURITY INVOKER` read RPC, `audit_feed(portfolio, before_created_at, before_id,
limit)`, pages by keyset on the existing index and returns display-ready rows: actor name and
role, or "former member", and the assistant name when there is one. The app gets a cursor
variant that keeps `id` as a `bigint`.

**Screen.** One feed per portfolio, newest first and grouped by day, with filters for person,
assistant, kind (money, tenancies, properties, team) and date. Each entry is one sentence in
English or Urdu, such as "Rs 25,000 recorded for Flat 2", with old and new values for money and
dates, the void reason, and a link to the record. Lease, payment, tenant and unit screens get a
"History" link that uses the record index. Phone numbers in old values are masked, as CNICs are
elsewhere.

**Attribution.** New columns `source` (`app`, `whatsapp`, `mcp`, `system`), `via_client_id` and
`mandate_id`, filled by the trigger from the token's `client_id` and a transaction-local
setting. `actor_id` stays the human on whose behalf the write happened. Agent entries carry a
badge; reads by an assistant, logged by [mcp-read](mcp-read.md), appear as one collapsed line
per day.

**Tamper evidence without breaking the lock order.** A per-insert chain would take a
portfolio-wide lock after lease rows are already locked, reversing the account, portfolio,
lease order. Instead a pg_cron job seals rows asynchronously: in `id` order, it hashes rows
older than the longest allowed transaction into per-portfolio `audit_seals` (last ID, SHA-256
digest, previous digest, time). `verify_audit(portfolio)` recomputes the chain, and daily
digests are copied into the off-site backup. The job locks no business rows.

**Retention.** Before a portfolio is deleted, the owner is offered an export of its trail (CSV
and PDF). Whether the financial part of the trail outlives deletion, for the six-year rule, is
the owner's decision, recorded in `docs/` with the [retention](retention.md) item.

### Residence (decision 1)

Managers can read the full trail today, including the owner's own actions. For an owner abroad
watching a caretaker, that is the question that matters most, so it is put to the owner below.
Changes to the residence fields (`owner_abroad`, the caretaker) are audited like any other.
Times show in the viewer's own time zone, with Pakistan time beside them for an owner abroad.

### Letterheads (decision 2)

The `letterheads` table gets the audit trigger, so uploads, replacements and rejections appear
in the feed.

### Analytics (decision 3)

The screen sends no analytics event that carries a name, an amount or a record. Opening it may
count as a screen view only for people who opted in.

## Work

1. **S:** `audit_feed` RPC and the `bigint` cursor; pgTAP (owner and manager can read,
   accountant and viewer cannot).
2. **M:** the feed screen with filters, right-to-left Urdu, empty and error states, goldens in
   all six variants.
3. **M:** sentence templates and column and enum labels for the 17 tables in both languages;
   History links on lease, payment, tenant and unit screens; phone masking.
4. **S:** decide, and audit by migration, the four unaudited tables.
5. **M:** attribution columns and the trigger change, with [agent-limits](agent-limits.md).
6. **M:** sealing job, `verify_audit`, and a CI test that a manual edit is detected.
7. **S:** export before portfolio deletion; the retention decision in `docs/`; a UAT journey in
   [`docs/uat.md`](../uat.md); the screen in [`permissions.md`](../architecture/permissions.md).

## Depends on / Unblocks

- **Depends on:** nothing that blocks a start. Strings go through
  [urdu-review](urdu-review.md).
- **Unblocks:** every assistant write: [agent-limits](agent-limits.md),
  [draft-payments](draft-payments.md) and [whatsapp-assistant](whatsapp-assistant.md); and
  [mcp-read](mcp-read.md), whose read log it shows. Related: [retention](retention.md) and
  [overseas-oversight](overseas-oversight.md), which reads the same trail.

## Risks

- **Personal data in `changes`.** Phone numbers and notes are stored in full. Mitigation: mask
  them on screen now; decide with [legal-review](legal-review.md) whether to redact them when
  stored.
- **Wide JSON diffs** on large rows. Mitigation: render only the columns that have labels; show
  the rest as "other details changed".
- **The six-year rule against deletion.** Mitigation: the export, and an owner decision on
  keeping the financial trail.
- **Seals and late commits.** A transaction that commits after its rows' IDs were passed would
  break the chain. Mitigation: seal only rows older than a margin well beyond the longest write
  transaction, and alert when a row appears below a seal.
- **Large portfolios.** Mitigation: keyset paging on the existing index, tested on the stress
  harness's 32,716-row portfolio.

## Done when

- [ ] Every change in the pgTAP fixtures appears in the feed with actor, time and readable text
      in English and Urdu.
- [ ] No CNIC appears on the screen, and phone numbers are masked.
- [ ] A former member's entries show "former member", never an empty name.
- [ ] Writes by an assistant and reads through MCP are visibly marked.
- [ ] `verify_audit` fails after a manual edit in a test database, in CI.
- [ ] An accountant and a viewer cannot read the feed, through the app or the Data API.
- [ ] The first page loads in under a second on the 32,716-row stress portfolio.

## Questions for the owner

1. Should managers (caretakers) see the full trail, including the owner's own actions?
2. Should the financial trail outlive portfolio deletion, for six years, or be exported and
   deleted?
3. Should the four unaudited tables be audited?
4. Is pgaudit wanted on the hosted project for administrator access, beyond this trail?
