# Hostel and PG mode

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `hostel-mode` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

A hostel or PG owner lets dozens of beds, mostly for cash, and residents arrive and leave around
every semester. Today each bed would be set up and each resident's rent recorded one at a time.
Hostel mode creates a building of beds in one step, shows which beds are let, free or overdue,
records a month's rent for every bed that paid in one action with a receipt each, and reminds the
manager to report each new resident to the police.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **The schema already knows hostels and beds:** `property_type` has `hostel`, and `unit_type`
  has `room` and `bed`; units carry a `label` and an `asking_rent`
  ([properties_units_tenants.sql](../../supabase/migrations/20261103192902_properties_units_tenants.sql)).
  Leases have `prorate_first_month`, `billing_starts_on`, police status and channel, and an
  exclusion constraint that stops two running leases on one unit
  ([leases.sql](../../supabase/migrations/20261103193403_leases.sql)).
- **`charge_kind` has no mess or food value**, only `other`
  ([ledger.sql](../../supabase/migrations/20261103193658_ledger.sql)). The police channels are
  `online_portal`, `khidmat_markaz`, `police_station` and `other`
  ([leases.sql](../../supabase/migrations/20261103193403_leases.sql)).
- **The limits a bulk action meets:** `record_payment` allows 60 calls a minute
  ([ledger_jobs_hardening.sql](../../supabase/migrations/20261104143928_ledger_jobs_hardening.sql)),
  and API writes are limited to 120 a minute per user
  ([jobs_and_api_guards.sql](../../supabase/migrations/20261103194829_jobs_and_api_guards.sql)).
  Receipts serialise on a per-portfolio counter; the stress harness measured 271 payments a second
  ([STATE.md](../../.planning/STATE.md)). Supabase stops an `authenticated` statement after 8
  seconds by default ([Supabase timeouts](https://supabase.com/docs/guides/database/postgres/timeouts)).
- **The pricing page promises it.** Business counts every let bed as a unit, empty beds free;
  "A month's rent for every bed in one step" is marked "Planned"; a 40-bed hostel with every bed
  let costs Rs 3,499 a month; the website allows up to 200 let units
  ([pricing](../../website/src/content/pricing/en.yaml)).
- **Punjab made HotelEye registration mandatory for guest houses** from 15 June 2025
  ([APP](https://www.app.com.pk/domestic/punjab-mandates-hotel-eye-registration-for-guest-houses/)).
  HotelEye covers hostels and is linked to NADRA ([PITB](https://pitb.gov.pk/hotel_eye)); no
  public API was found.
- **Hostel managers are reported to have three hours to tell the police** about a new resident
  in Punjab and Sindh; sources conflict _(summary)_
  ([Tribune](https://tribune.com.pk/story/1000770/violating-rent-laws-hotel-manager-among-three-held),
  [Sindh Act](https://www.sindhlaws.gov.pk/Setup/Publications_SindhCode/PUB-NEW-19-000024.pdf)).
- **Punjab's Women Hostels Authority Act 2023** makes registration of women's hostels compulsory
  _(summary)_ ([Punjab Laws](http://punjablaws.gov.pk/laws/2875.html)); no rules or portal were
  found.
- **Islamabad has no hostel registration regime**
  ([APP](https://www.app.com.pk/national/digital-monitoring-in-place-for-hostels-cites-safety-measures-for-working-women/)),
  and in August 2026 a Senate panel told the CDA to close illegal hostels in residential sectors
  _(summary)_
  ([ProPakistani](https://propakistani.pk/2026/08/31/senate-panel-orders-cda-to-close-illegal-hostels-in-islamabad/)).

## Design

**Hostel preset.** A `create_hostel_layout` RPC creates R rooms of B beds in one step, named
"Room 3 · Bed B" (and the Urdu equivalent), with a rent per bed or per room type copied to every
bed. A new nullable `units.room_label` groups beds on the board without parsing names. Each bed is
an ordinary `bed` unit with its own lease, so plan counting and the no-overlap constraint work
unchanged.

**Bed board.** A grid by room, each bed let, vacant, on notice or overdue, from the existing
occupancy view and `get_receivables`.

**Quick check-in and check-out.** Resident, bed, rent, deposit, an optional advance, mess yes or
no, and the first month prorated by `rent_math`. The check-in time is kept in a new
`leases.checked_in_at`, because the police deadline counts hours, not days. CNIC capture uses
[document-reading](document-reading.md) once it exists. Check-out ends the lease and settles the
deposit through the existing deposit RPCs; [move-out](move-out.md)'s inspection is optional for
beds.

**Mess.** A `mess` value in `charge_kind`, added by a new migration, and an optional flat monthly
mess amount on the lease, raised with the rent. Per-meal billing waits for demand.

**One action for the month.** `record_month_payments(property, period, items)` is a definer RPC
taking a list of (lease, amount, method, date). It:

- locks the portfolio, then the leases in ID order, keeping the global lock order;
- re-reads each lease's open dues for the period under the lock, and skips a lease already paid,
  reporting it as such;
- writes one payment, allocation and receipt per lease, keyed on (lease, period), so running it
  again creates nothing;
- has its own rate limit and a cap of 200 items, measured to finish well inside the 8-second
  timeout;
- returns a result per lease.

The screen starts from every open due for the month, the manager unticks those who have not paid,
and a summary ("38 payments, Rs 456,000, cash") is confirmed before the call. A second payment in
the same month for one bed goes through the ordinary single-payment screen.

**Police checklist.** A `hotel_eye` value in `police_registration_channel`; each resident shows
whether their entry is made, when, and a slip photo. A resident without an entry a set number of
hours after check-in (3 by default in Punjab, set per property) appears on the checklist and the
dashboard. At property level: the HotelEye establishment registration and, for women's hostels,
the registration number and expiry. For Islamabad, a neutral note that hostels in residential
sectors are being closed, not legal advice.

**Left out:** attendance, gate logs, per-meal mess, a parent portal and a HotelEye integration.

### Residence (decision 1)

A hostel owner abroad with a warden as caretaker uses the same model: the warden is a `manager`,
records the month and holds the cash; the owner confirms cash handovers as today. Each bulk action
appears in the audit trail and the owner's digest at the owner's own time. Police deadlines stay
in Pakistan time.

### Letterheads (decision 2)

Thirty-eight letterheaded receipts in one action is the performance and file-size test of
letterheads. Receipts are rendered on the device after the call, with the letterhead image
embedded once per document, and shared one per resident or as one combined PDF within a size
budget.

### Analytics (decision 3)

No resident name, CNIC or amount reaches analytics; after opt-in, the number of beds recorded in
one action is enough.

## Work

1. **S:** hostel preset: the layout RPC, `units.room_label`, naming in both languages.
2. **M:** bed board screen, with goldens.
3. **M:** quick check-in and check-out with proration, deposit, advance, `checked_in_at` and the
   police checklist.
4. **M:** `record_month_payments` with pgTAP, a concurrency scenario against a single payment on
   the same lease, a 200-bed stress test and an update to the
   [`LedgerPayments`](../../formal/tla/LedgerPayments/README.md) TLA+ model; the new RPCs added to
   [`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and
   [`permissions.md`](../architecture/permissions.md).
5. **M:** the month screen, the summary confirmation and letterheaded receipts for the batch.
6. **S:** `mess` charge kind and lease mess amount, in the migration, `mm_core` and the contract
   vectors.
7. **S:** `hotel_eye` channel, property registration fields and the deadline alert.
8. **S:** website and pricing copy once shipped, removing "Planned" from the bed feature.

## Depends on / Unblocks

- **Depends on:** [billing](billing.md) (Business counts let beds),
  [push-notifications](push-notifications.md) (the three-hour alert is weak without push),
  [document-reading](document-reading.md) (CNICs at volume), [retention](retention.md) (many
  short tenancies mean many CNICs to delete), [move-out](move-out.md) (deposit settlement) and
  [urdu-review](urdu-review.md).
- **Unblocks:** the Business plan's bed feature on the pricing page. Related:
  [overseas-oversight](overseas-oversight.md), which watches a warden's cash like any caretaker's.

## Risks

- **Without a HotelEye API, every entry is typed twice.** Mitigation: the value is the reminder
  and the record that it was done; look again for an API each year.
- **Recording residents who did not pay.** Mitigation: the summary before the call, and a void
  with a reason afterwards, as for any payment.
- **A large batch holds the portfolio lock.** Mitigation: the 200-item cap and the stress test;
  other writes wait, and none deadlock, because the lock order is kept.
- **Islamabad's legality.** Mitigation: a neutral note, never advice.
- **Many short tenancies mean many CNICs.** Mitigation: retention deletes them on schedule.
- **Per-bed pricing invites under-recorded beds.** Mitigation: none in the app; it is a pricing
  question for the owner.

## Done when

- [ ] A 40-bed hostel (10 rooms of 4 beds) is created in one action, in under two minutes end to
      end on a mid-range Android phone.
- [ ] Recording October for 38 of 40 let beds creates 38 payments and 38 numbered receipts in
      one action, and running it again creates none.
- [ ] A 200-item call finishes well inside the timeout in the stress harness.
- [ ] A resident who joins on the 18th is charged the prorated amount that `rent_math` gives.
- [ ] Vacant beds raise no dues and are not counted against the plan.
- [ ] A resident with no police or HotelEye entry three hours after check-in appears on the
      checklist and the dashboard.
- [ ] Every string exists in English and Urdu, and the design lint and goldens pass.

## Questions for the owner

1. Mess: a flat monthly amount per resident, per meal, or not at all at first?
2. Should an advance (a month paid ahead) be kept apart from the deposit?
3. Rent set per room and split across beds, or per bed only?
4. Are guardian contacts, and notices to them, in scope?
5. Should the app show the note about Islamabad's residential sectors, or stay silent?
6. Is the checklist enough, or should a HotelEye link be pursued with PITB?
