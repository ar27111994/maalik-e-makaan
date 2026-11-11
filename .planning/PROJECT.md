# Maalik-e-Makaan (مالکِ مکان)

## Vision

A tenant- and property-management app built for **Pakistani landlords**: the individual owner of a
few portions, flats or shops; the overseas Pakistani whose property is run by a relative or
caretaker; and the small hostel or plaza owner. It replaces registers, Excel sheets and WhatsApp
threads with one trustworthy ledger and adds the Pakistan-specific work global tools ignore:

- cash-first rent collection with numbered bilingual receipts, which decide disputes;
- police tenant registration and Punjab Rent Registrar compliance;
- utility connections in the landlord's name, whose arrears stay with the premises;
- an accountability trail for caretakers who handle cash on behalf of overseas owners;
- July–June tax-year statements, including tax withheld by company tenants under s.155;
- English and Urdu (right-to-left), with WhatsApp reminders in English, Urdu and Roman Urdu.

## Users & Segments

| Segment                       | Core job                                                       | What wins them                                               |
| ----------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------ |
| A. Local landlord, 1–10 units | Know who owes what and since when; collect without awkwardness | Auto dues, overdue list, one-tap WhatsApp reminder, receipts |
| B. Overseas owner + caretaker | Trust and visibility from abroad                               | Roles, audit trail, cash-in-hand, monthly statement PDF      |
| C. Hostel/PG/plaza owner      | Many small units, high churn                                   | Unit/bed model, bulk dues, occupancy, vacancy loss           |
| D. Small commercial landlord  | Company tenants, withholding, increments                       | s.155 tracking, increment schedule, tax-year statement       |

## Tech Stack (decided 2026-11-03)

- **App:** Flutter 3.47 / Dart 3.13. Android (API 24+), iOS and web, plus a Linux desktop target
  used for headless integration tests.
- **State and routing:** Riverpod 3 and go_router 18. Models are hand-written immutable classes with
  value equality; the only code generation is `flutter gen-l10n`.
- **Packages:** a Dart pub workspace.
  - `packages/mm_core`: pure-Dart domain logic, 100% unit tested.
  - `packages/mm_ui`: the design system, with tokens, themes, components, a gallery and golden tests.
  - `app/`: the product.
- **Backend:** Supabase (Postgres 17, Auth, Storage, Edge Functions on Deno 2, pg_cron).
  - Project `maalik-e-makaan`, ref `aaifamxzzjspohwksxyr`, region ap-south-1 (Mumbai).
  - Clients use publishable/secret API keys, not the legacy JWT keys.
- **Website:** Astro static site (English and Urdu) for SEO and AI-SEO, hosted on Vercel. The
  Flutter web build is hosted on Vercel too.
- **CI/CD:** GitHub Actions with Dependabot, release-please, CodeQL, gitleaks, OSV-Scanner and
  the Supabase CLI stack.

## Key Decisions

- D-01: **Flutter + Astro**. The app is Flutter. SEO and AI-SEO come from a separate static
  Astro site, because Flutter web output is not indexable. (Confirmed by the user.)
- D-02: **A new Supabase project** in the AR Labs org, ap-south-1, created through MCP. (Confirmed by the user.)
- D-03: **Vercel** hosts both web properties. (Confirmed by the user.)
- D-04: **Authorization lives in Postgres.** Portfolio-scoped RLS checks membership through
  `app.*` security-definer helpers, called as `(select …)` initPlans. Every portfolio-owned table
  carries `portfolio_id`, and composite foreign keys `(x_id, portfolio_id)` make
  cross-portfolio references impossible.
- D-05: **Money is exact.** The database uses `numeric(14,2)`. Dart uses integer paisa with
  BigInt-based rounding. Percentages are stored as `numeric(5,2)` and handled as basis points.
- D-06: **Ledger-first accounting.**
  - Charges are dues and payments are cash in; allocations link the two.
  - Unallocated money becomes credit, which is auto-applied to new dues.
  - Financial rows are never deleted, only voided with a reason.
  - Receipts are numbered without gaps per portfolio per year.
- D-07: **Payments are written only through `record_payment`.**
  - It is idempotent through an idempotency key.
  - It serialises per lease with `FOR UPDATE`, allocates oldest-due-first and returns the receipt.
  - Mobile retries on flaky networks therefore never double-count.
- D-08: **Server-side aggregation, client-side interpretation.**
  - Dashboards come from one RPC.
  - Scoring and insight rules are pure functions over the aggregates, in the app's insights
    feature (`app/lib/src/features/insights/application/`), built on `mm_core`'s money and
    dates.
  - Client previews (proration, increments, late fees, allocation) mirror SQL and are checked
    against shared contract vectors.
- D-09: **Never infer gender from a CNIC.** Mask CNICs by default. Validation warns rather than
  blocks on unknown region digits or mobile prefixes.
- D-10: **Tax: no estimate of final tax.**
  - Rent has been taxed at normal slab rates since TY2022.
  - The app records s.155 withholding and auto-computes the s.15A 1/5 repairs allowance.
  - It produces an accountant-ready statement labelled "not tax advice".
- D-11: **WhatsApp through free `wa.me` links**, sent from the landlord's own number. The Business
  API costs $0.015 a message in Pakistan.
- D-12: **Language is chosen at first launch.** Urdu (RTL; its face is D-19) and English are equal
  citizens. Rupees use Western grouping by default, with lakh/crore available.
- D-13: **The Data API is opt-in.** Default privileges are revoked, every grant is explicit (with
  column-level grants where clients must not write), and `pgrst.db_pre_request` rate-limits writes
  per signed-in user (120 a minute). There is no per-IP limit: Pakistani mobile networks put many
  users behind one carrier-grade NAT address, and every write needs a signed-in user anyway.
- D-14: **The hosted migration history names the migrations.** Migrations are applied to the
  hosted project with the Supabase MCP `apply_migration`, and each local file is renamed to the
  version the platform assigns. `tool/db/schema_fingerprint.sql` and `tool/db/fingerprint_diff.py`
  prove that the hosted schema equals the local chain, object by object.
- D-15: **Write RPCs are SECURITY DEFINER by design; read RPCs are SECURITY INVOKER.** Payments,
  memberships and invitations are written only through RPCs that bypass row-level security, so
  each must authorise its caller first. The 21 reviewed RPCs are pinned by a pgTAP allowlist, which
  covers Supabase lint 0029 under its option 3.
- D-16: **Residence is declared per person and recorded per portfolio.** (Decided by the owner,
  11 November 2026.) Resident and overseas owners are told apart in two places:
  - per person: the country of residence and the time zone, which the person declares and the app
    never infers;
  - per portfolio: whether the owner lives abroad, and who the caretaker is.

  How the app holds and uses this is the research's proposed design, not a decision: the fields,
  the caretaker as a member with the `manager` role, which times stay on Pakistan time and which
  follow the owner's own zone, and keeping residence from tenants. Whether a caretaker can be
  someone who does not use the app is still open. The design and its work are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-1-residence-per-person-and-per-portfolio-d-16).

- D-17: **Letterheads on every generated document.** (Decided by the owner, 11 November 2026.)
  Owners can upload a letterhead, or make one with a simple builder, and it is applied to every PDF
  and image the app generates. An upload is a PDF (its first page for a document's first page, its
  second for the pages after) or a PNG or JPG. Word users save their letterhead as a PDF; there is
  no Word import. The design and its work are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-2-letterheads-on-every-generated-document-d-17).
- D-18: **Privacy-first analytics, support and e-mail.** (Decided by the owner, 11 November 2026.)
  - The website counts visits with PostHog in cookieless, anonymous mode, and says so plainly. Its
    privacy page, FAQ and footer, which promise no analytics in English and Urdu, change to match.
  - The app sends nothing to PostHog or Intercom until the person opts in.
  - Customer.io sends transactional e-mail, and lifecycle e-mail only to people who consented.
- D-19: **Urdu interface text is set in Noto Sans Arabic; Nastaliq stays for the wordmark.**
  (Decided by the owner, 11 November 2026, after seeing five candidates rendered on the real app
  screens and website pages: Noto Nastaliq Urdu as it was, a tighter Nastaliq, Gulzar, Noto Naskh
  Arabic and Noto Sans Arabic.) Nastaliq made the interface read like a printed book: at its line
  height of 2.0 about one pair of body lines in twelve touched, and it sat low in buttons and
  fields. Noto Sans Arabic never collides at line heights from 1.4 up, centres in controls and
  makes app screens about 15% shorter. The name مالکِ مکان keeps Nastaliq where it is the
  wordmark. This revises the "Nastaliq" in D-12; readers in the [pilot](../docs/roadmap/pilot.md)
  confirm it rather than decide it.

  The research recommends an order of work, which is not part of the decision: the new privacy
  text first, reviewed by the lawyer, then consent records, then the SDKs. The design and its work
  are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Open Proposals

Changes that roadmap items would make to an earlier decision. Each stays a proposal until the
owner accepts it; it then becomes a decision entry, recorded in the first pull request of the
item's plan.

- P-01: **Automatic WhatsApp reminders through the WhatsApp Business Platform**, which would
  revisit D-11 (free `wa.me` links sent from the landlord's own number). The free links would stay
  the default; automatic reminders would go only to tenants who opted in, at a cost per message,
  once Meta has verified AR LABS. Plans:
  [`whatsapp-reminders`](../docs/roadmap/whatsapp-reminders.md) and Munshi on WhatsApp,
  [`whatsapp-assistant`](../docs/roadmap/whatsapp-assistant.md).
- P-02: **Collecting rent through licensed partners**, which would end the rule that collection is
  recorded, not processed (Constraints, below). Raast Request-to-Pay would go through a payment
  service provider licensed by the State Bank, with the money settling straight to the landlord's
  account and never through AR LABS; and, once the State Bank's rules are final, credits would be
  read from the landlord's bank account with consent. Plans:
  [`raast-request-to-pay`](../docs/roadmap/raast-request-to-pay.md) and
  [`open-banking`](../docs/roadmap/open-banking.md).

## Constraints

- Supabase free plan: pg_cron jobs must be idempotent and self-healing. The app calls
  `sync_portfolio_billing` when a dashboard loads, so paused or missed cron runs are recovered.
- Low- and mid-range Android dominates (Infinix/Tecno ≈44% of units). Budget: ≤15 MB download
  and <3 s cold start.
- No payment-gateway or WhatsApp API credentials. Collection is recorded, not processed.
  Proposals P-01 and P-02 would change this.

## Current Status

Milestone v1.0 is in progress. See `STATE.md`. What follows it is planned in
[`docs/roadmap/README.md`](../docs/roadmap/README.md).
