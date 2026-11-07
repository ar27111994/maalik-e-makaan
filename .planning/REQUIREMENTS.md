# Requirements: Maalik-e-Makaan v1.0

## Core Goal

A Pakistani landlord can record properties, units, tenants and tenancies, and then run monthly
operations from a phone in Urdu or English:

- dues are generated automatically;
- payments are recorded with receipts;
- reminders go out through WhatsApp;
- utilities and compliance are tracked;
- the dashboard shows who owes what and since when.

All of this sits on a secure, multi-user Supabase backend.

Status legend: ☐ pending · ◐ in progress · ☑ done (verified by tests or UAT).

## Must-Have (v1.0)

### Accounts & access (AUTH)

- ☐ AUTH-01: Email + password sign-up and sign-in, with email verification and password reset.
- ☐ AUTH-02: The session persists, tokens refresh automatically, and signing out clears local
  caches.
- ☐ AUTH-03: In-app account deletion. It removes the user and every portfolio where they are the
  sole owner, and removes their memberships elsewhere.
- ☐ AUTH-04: A language chooser (English or Urdu) on first launch, persisted to the profile. The
  Urdu UI is fully RTL.

### Portfolios & team (TEAM)

- ☐ TEAM-01: A user creates portfolios and becomes their owner. There is a per-user limit to
  prevent abuse.
- ☐ TEAM-02: Four roles: owner, manager (caretaker), accountant and viewer. The permission
  matrix is enforced by RLS and RPC checks (see `docs/architecture/permissions.md`).
- ☐ TEAM-03: Owners invite by email and role through a single-use share link.
  - The link expires after 7 days.
  - Only the invited, verified email can accept it.
  - The link is a split selector/verifier token, verified in constant time.
- ☐ TEAM-04: Owners change roles or remove members, and members can leave. The last owner can
  never be removed or demoted.
- ☐ TEAM-05: An audit trail of structural and financial changes, with actor and timestamp, readable
  by owners and managers. CNIC values are redacted in the trail.

### Properties & units (PROP)

- ☐ PROP-01: Create, edit and archive properties with:
  - type, address, locality, city and province (jurisdiction);
  - plot size (marla, kanal, sq ft, sq yd) and covered area;
  - purchase price and estimated value.
- ☐ PROP-02: Create, edit and archive units of each type: entire property, portion, flat, room,
  bed, shop, office, floor, warehouse. Each unit has an asking rent, beds and baths, area,
  furnished flag and availability.
- ☐ PROP-03: Occupancy derived from active leases: occupied, vacant (with days vacant) or
  unavailable.

### Tenants (TEN)

- ☐ TEN-01: Tenant profiles with:
  - name and S/O, D/O or W/O name;
  - CNIC (validated, masked by default) and CNIC expiry;
  - phone in E.164, alternate phone and email;
  - occupation and employer;
  - permanent and previous addresses;
  - emergency contact and two references;
  - household size and notes.
- ☐ TEN-02: Duplicate CNIC or phone detection within a portfolio.
- ☐ TEN-03: Data-collection consent recorded with a date and a note on its purpose.
- ☐ TEN-04: Tenant identity documents (CNIC front and back, photo) kept in private storage and
  served through short-lived signed URLs.

### Tenancies (LEASE)

- ☐ LEASE-01: Create a lease with:
  - start date and term (11 months, 12 months, custom or periodic);
  - rent, due day and grace days;
  - security deposit;
  - increment % and interval (default 10% / 12 months);
  - late-fee policy (none, flat, percent, or daily with a cap);
  - notice period, first-month proration and billing start date (for onboarding existing
    tenancies).
- ☐ LEASE-02: Active leases on the same unit can never overlap. A database exclusion constraint
  enforces this.
- ☐ LEASE-03: Agreement record: signed date, e-stamp number and amount, Punjab Rent Registrar
  status, registration number and date, permitted use, subletting consent.
- ☐ LEASE-04: Police registration per lease:
  - status, channel, reference number, date and fee;
  - a deadline by jurisdiction, from `app.police_registration_rule` (sources:
    `research/website-facts.md` §1): Punjab 15 days and Sindh 48 hours from possession; KP 7 days
    (the law excludes public holidays; the app counts calendar days) and Balochistan 3 days from
    signing the agreement (the lease start when no agreement date is recorded); ICT,
    Gilgit-Baltistan and Azad Kashmir a 1-day app reminder from possession, flagged as not
    statutory;
  - deep links to Punjab TRS, Sindh TRUST and ICT TRS.
- ☐ LEASE-05: Co-occupants (adults) with name, relation, CNIC and phone.
- ☐ LEASE-06: Rent-change history. On the anniversary, suggest an increment rounded to Rs 100 and
  apply it from a chosen month.
- ☐ LEASE-07: End a lease with a move-out date and reason. Future dues stop, and the deposit
  settlement flow opens.

### Ledger (LEDGER)

- ☐ LEDGER-01: Monthly rent dues are generated automatically for active leases.
  - Generation is idempotent and backfills from the billing start.
  - The first month is optionally prorated.
  - A daily job does the work, and the app self-heals missed runs.
- ☐ LEDGER-02: Manual charges: electricity, gas, water, internet, maintenance, society charges,
  damages and other.
- ☐ LEDGER-03: Record payments by every Pakistani method:
  - methods: cash, bank transfer, Raast, JazzCash, Easypaisa, cheque, card and other;
  - each with a reference, notes and a proof photo;
  - partial, full or advance; allocated oldest-first or explicitly;
  - credit is auto-applied to future dues.
- ☐ LEDGER-04: Payment recording is idempotent, so retries never duplicate. Concurrent payments on
  one lease never double-allocate.
- ☐ LEDGER-05: Gapless receipt numbers per portfolio per year, and a bilingual PDF receipt shared
  through WhatsApp or the share sheet.
- ☐ LEDGER-06: Void a payment (with a reason; allocations are reversed), waive or void charges.
  Everything is audited.
- ☐ LEDGER-07: Late fees follow each lease's policy after the grace period, at most once per
  overdue rent due.
- ☐ LEDGER-08: Security deposit: due, received, applied to dues at move-out and refunded, with a
  running deposit-held balance.
- ☐ LEDGER-09: A tenant statement PDF ("dispute pack") with every due, payment and receipt number
  and the balance.
- ☐ LEDGER-10: s.155 tax withheld by tenants is recorded on payments, with the certificate or CPR
  number. The cash plus the tax withheld settles the gross due.
- ☐ LEDGER-11: Cash handovers from a caretaker to an owner, and cash in hand per member.

### Expenses (EXP)

- ☐ EXP-01: Expenses by portfolio, property or unit and category, with payee, method and a receipt
  photo. They can be linked to a maintenance job.

### Utilities (UTIL)

- ☐ UTIL-01: Utility connections per property or unit:
  - type and provider (12 DISCOs including K-Electric and HAZECO, SNGPL, SSGC, water, internet,
    other);
  - reference or account number with length hints;
  - customer ID, name on the bill and meter number;
  - sub-meter flag and responsibility.
- ☐ UTIL-02: Monthly bills: amount, due date, units used, status and who paid, and a photo. A bill
  can be charged to the tenant's ledger.
- ☐ UTIL-03: Meter readings at move-in and move-out, with alerts for unpaid bills on
  landlord-named connections and for the 200-unit protected-tariff threshold.

### Maintenance (MAINT)

- ☐ MAINT-01: Requests with category, priority, a status workflow, vendor and phone, estimate,
  resolution and photos.

### Documents (DOC)

- ☐ DOC-01: Attach photos and PDFs to any entity.
  - They live in a private bucket with path-scoped RLS.
  - Images up to 10 MB are accepted, as JPEG, PNG, WebP, HEIC or PDF.
  - Access is through signed URLs.
- ☐ DOC-02: Images are compressed on device before upload (target ≤ ~300 KB).

### Reminders & notifications (REM)

- ☐ REM-01: A WhatsApp reminder composer.
  - Templates for upcoming, due today, overdue, payment received and utility bill.
  - Each template in English, Urdu and Roman Urdu.
  - It opens wa.me with the tenant's number, and every reminder is logged.
- ☐ REM-02: An etiquette guard that suggests waiting during late night or Friday prayers.
- ☐ REM-03: A daily notification centre covering:
  - rent due soon and overdue;
  - lease expiring (90 and 30 days);
  - increment due;
  - police registration pending or overdue;
  - CNIC expiring;
  - utility bill unpaid.

### Dashboard & insights (INS)

- ☐ INS-01: Dashboard: this month's expected vs collected rent, collection rate, outstanding and
  overdue amounts, aging buckets (not due, 1–30, 31–60, 61–90, 90+ days), occupancy, vacant
  units and the upcoming timeline.
- ☐ INS-02: A who-owes-what list sorted by days overdue, with one-tap remind and record-payment
  actions.
- ☐ INS-03: Tenant payment score from 0 to 100, with label and explanation:
  `50·onTime + 30·(1 − min(avgDaysLate,30)/30) + 20·(1 − min(arrears/rent,3)/3)`.
- ☐ INS-04: Insight cards:
  - collection rate and 90+ arrears;
  - increment due and expiring leases;
  - police registration pending;
  - vacancy loss and deposit cover below 1;
  - utility arrears risk and expense spikes;
  - underpriced units;
  - caretaker cash in hand and cash share.
- ☐ INS-05: A 12-month cash-flow chart, plus per-property income, expenses, NOI, occupancy, and
  gross and net yield.

### Reports & exports (RPT)

- ☐ RPT-01: A tax-year (Jul–Jun) statement per property, as PDF and CSV, labelled "not tax
  advice". It shows gross rent, tax withheld, the 1/5 repairs allowance, other deductible
  expenses and net property income.
- ☐ RPT-02: A monthly owner statement PDF (for overseas owners).
- ☐ RPT-03: CSV exports of the ledger, payments and expenses. Cells are guarded against formula
  injection, and files carry a UTF-8 BOM.

### Search (SRCH)

- ☐ SRCH-01: Global fuzzy search across properties, units and tenants (trigram-indexed).

### Website (WEB)

- ☐ WEB-01: A bilingual static site (English, plus Urdu RTL) with:
  - home, features and how it works;
  - guides on police registration by province, the agreement checklist, rental tax and
    withholding, and utilities;
  - tools: an increment calculator, a proration calculator and an s.155 withholding calculator
    (TY2026/27 FBR card, with a disclaimer);
  - FAQ, privacy, terms and an app link.
- ☐ WEB-02: SEO:
  - semantic HTML, canonical and hreflang tags, sitemap and robots;
  - OG and Twitter images;
  - JSON-LD for Organization, WebSite, SoftwareApplication, FAQPage, BreadcrumbList and Article;
  - Lighthouse ≥ 95 in every category.
- ☐ WEB-03: AI-SEO: `llms.txt` and `llms-full.txt`, AI crawlers explicitly allowed, and factual,
  cited, well-structured content.

### Non-functional (NFR)

- ☐ NFR-01: Mobile-first and responsive from a 320 dp phone to desktop web, with adaptive
  navigation (bottom bar, rail or drawer).
- ☐ NFR-02: The design-system package provides:
  - tokens and themes (light, dark, high contrast);
  - Latin and Urdu Nastaliq typography;
  - a component library and gallery, with golden tests.

  The UI meets WCAG 2.2 AA: contrast, 48 dp targets, semantics, 200% text scale, reduced motion.

- ☐ NFR-03: Full English and Urdu localisation with RTL, and locale-aware dates, numbers and
  currency.
- ☐ NFR-04: Performance:
  - cold start under 3 s on mid-range Android;
  - smooth 60 fps lists;
  - one round trip per dashboard;
  - stale-while-revalidate local cache so the last-known data shows instantly.
- ☐ NFR-05: Security:
  - RLS on every exposed table, and tenant isolation through composite foreign keys;
  - explicit, column-level grants;
  - hardened `SECURITY DEFINER` functions;
  - per-user write limits plus per-action limits (no per-IP limit, which would throttle
    everyone behind a mobile carrier's shared NAT address);
  - constant-time token checks;
  - text sanitisation of control and bidi characters;
  - private storage; no secrets in the client.
- ☐ NFR-06: Reliability: idempotent writes and jobs, database invariants, a self-healing billing
  sync, and structured error mapping.
- ☐ NFR-07: Testing: unit, widget, golden, integration/e2e, pgTAP (RLS matrix, RPCs, concurrency,
  stress), edge-function and website e2e/a11y/Lighthouse suites, with coverage gates.
- ☐ NFR-08: CI/CD:
  - quality, security and coverage gates;
  - Dependabot;
  - conventional commits and release-please;
  - deploys to Vercel and Supabase.
- ☐ NFR-09: Privacy: CNIC masking, consent capture, account deletion and minimal collection.

## Should-Have (v1.x)

- Hostel/PG mode with a HotelEye checklist; a bulk "record month" for beds.
- Read-only tenant portal link (ledger, receipts, Raast ID).
- Scheduled reminder automation through the WhatsApp Business API, once credentials exist.
- Push notifications (FCM/APNs) through the `device_tokens` table and an edge function.
- Automated retention purge of identity documents N months after a tenancy ends.
- Move-out photo checklist.

## Out of Scope (v1.0)

- Processing online payments (JazzCash, Easypaisa or Raast collection APIs). Payments are recorded only.
- Property listings or a marketplace, tenant credit scoring by third parties, NADRA Verisys
  integration (no public API).
- Computing final income tax liability.

## Constraints

- Free Supabase tier: no reliance on paid add-ons. Cron must be self-healing.
- No third-party credentials: WhatsApp API, FCM, SMTP and payment gateways are optional
  integrations behind configuration.

## Open Questions

- Custom SMTP for auth e-mails. The default Supabase SMTP is rate-limited, so the user needs to
  configure a provider before launch. This is documented in the runbook.
