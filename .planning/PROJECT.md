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
- **Website:** Astro static site (English and Urdu) for SEO and AI-SEO, hosted on Vercel at
  `https://mmakaan.app`. The Flutter web build is hosted on Vercel too, at
  `https://app.mmakaan.app` (D-20; the origins are written once, in `contracts/origins.json`).
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
  each must authorise its caller first. The 23 reviewed RPCs are pinned by a pgTAP allowlist, which
  covers Supabase lint 0029 under its option 3.
- D-16: **Residence is declared per person and recorded per portfolio.** (Decided by the owner,
  11 November 2026; the caretaker, the currency and the owner-abroad question decided by the
  owner, 12 November 2026.) Resident and overseas owners are told apart in two places:
  - per person: the country of residence and the time zone, which the person declares and the app
    never infers;
  - per portfolio: whether the owner lives abroad, and who the caretaker is.

  On 12 November 2026 the owner decided:
  - **The caretaker always uses the app.** A portfolio's caretaker is a member with the `manager`
    role. There is no caretaker who is only a name and a phone number, with no account.
  - **Amounts stay in rupees at launch.** Owners abroad see no total converted into another
    currency, indicative or not, and `display_currency` is not added at launch. There is no free
    official API for rupee rates (the ECB publishes no PKR rate, and the State Bank publishes web
    pages, not an API), so conversion waits until a rate source is chosen. The owner's own time
    zone and the dual time are still shown.
  - **The owner-abroad question is always answered.** When a portfolio is created, the app asks
    "Does the owner of these properties live abroad?" with no answer chosen, and the person must
    choose. It is never filled in from the creator's residence, because the creator is often a
    caretaker or a relative.
  - **Existing portfolios start unanswered** (from the review of PR #53): the migration adds
    `owner_abroad` as NULL, meaning "not yet answered", never with a default; the app asks on the
    next open by an owner or manager, and the overseas-owner rules run only when it is true.

  The backend and domain half is built (`20261112092618_residence.sql`, `mm_core`'s residence and
  time-zone types, the app's data layer). Residence is stored in a table of its own,
  `profile_residences`, readable and writable by the person only (not teammates, the caretaker
  included, never tenants), because teammates read `profiles` and column grants are per role, not
  per row: a design choice awaiting the owner's confirmation (Q1 in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md)).

  The rest of how the app holds and uses this is the research's proposed design, not a decision:
  the fields, which times stay on Pakistan time and which follow the owner's own zone, and keeping
  residence from tenants. The design and its work are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-1-residence-per-person-and-per-portfolio-d-16).

- D-17: **Letterheads on every generated document.** (Decided by the owner, 11 November 2026; the
  details below decided by the owner, 12 November 2026.) Owners can upload a letterhead, or make
  one with a simple builder, and it is applied to every PDF and image the app generates. An upload
  is a PDF (its first page for a document's first page, its second for the pages after) or a PNG
  or JPG. Word users save their letterhead as a PDF; there is no Word import.

  On 12 November 2026 the owner decided:
  - **Per portfolio.** A letterhead is set per portfolio, not per account, because the portfolio is
    the issuer on its receipts. One upload can be copied to the owner's other portfolios.
  - **An optional Urdu letterhead.** Each portfolio may add an Urdu version of its letterhead.
    Documents issued in Urdu use it when it exists, and the main letterhead otherwise. The builder
    can make both from the same logo and details.
  - **A5 or A4 receipts.** Each portfolio chooses A5 or A4 receipts, with A5 by default as today.
    An A4 letterhead on an A5 receipt is scaled down, and the preview warns when its text becomes
    too small to read.
  - **On every plan.** Letterheads, both the builder and uploads, are on every plan, Free included.

  The design and its work are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-2-letterheads-on-every-generated-document-d-17).

- D-18: **Privacy-first analytics, support and e-mail.** (Decided by the owner, 11 November 2026;
  the data regions decided by the owner, 12 November 2026.)
  - The website counts visits with PostHog in cookieless, anonymous mode, and says so plainly. Its
    privacy page, FAQ and footer, which promise no analytics in English and Urdu, change to match.
  - The app sends nothing to PostHog or Intercom until the person opts in.
  - Customer.io sends transactional e-mail, and lifecycle e-mail only to people who consented.
  - The existing accounts stay (12 November 2026): PostHog's US Cloud organisation, and
    Customer.io's US workspace, which is on Customer.io's Startup plan. The privacy notice names
    the US as where these processors handle data, under their standard data-transfer terms. This
    replaces the research's suggestion of PostHog's EU Cloud.
  - Maalik-e-Makaan has its own PostHog project in that organisation (project 730301, created at
    the owner's request on 12 November 2026), so its data is kept apart from any other product's.

  The rest of the research's design is unchanged and still applies: cookieless mode on the
  website; opt-in only in the app; no session replay, autocapture, surveys or feature flags; the
  objection switch and Do Not Track. The project was set up that way: session recording, heatmaps,
  console-log capture, dead-click capture, autocapture, web-vitals capture and surveys are off;
  client IP addresses are discarded; cookieless tracking is on; its time zone is Asia/Karachi and
  its currency the rupee. The SDK configuration on the website and in the app turns the same
  features off too, so neither depends on the other.

  The research recommends an order of work, which is not part of the decision: the new privacy
  text first, reviewed by the lawyer, then consent records, then the SDKs. The design and its work
  are in
  [`docs/roadmap/README.md`](../docs/roadmap/README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

- D-19: **Urdu interface text is set in Noto Sans Arabic; Nastaliq stays for the wordmark.**
  (Decided by the owner, 11 November 2026, after seeing five candidates rendered on the real app
  screens and website pages: Noto Nastaliq Urdu as it was, a tighter Nastaliq, Gulzar, Noto Naskh
  Arabic and Noto Sans Arabic. In place since 12 November 2026.) Nastaliq made the interface read
  like a printed book: at its line height of 2.0 about one pair of body lines in twelve touched,
  and it sat low in buttons and fields. Noto Sans Arabic never collides at line heights from 1.4
  up, centres in controls and makes app screens about 15% shorter. The name مالکِ مکان keeps
  Nastaliq where it is the wordmark. This revises the "Nastaliq" in D-12; readers in the
  [pilot](../docs/roadmap/pilot.md) confirm it rather than decide it.

  What is in place: the type tokens (`font.family.urdu` and `urduWordmark`, Urdu lines of whole
  even pixels), `mm_ui` and the app with every Urdu golden re-recorded, the website (Urdu pages
  load about 50 KB of fonts instead of 196 KB, and most are 10–17% shorter on a phone), its Open
  Graph cards, the pitch deck and the e-mails (the three Auth templates in `supabase/templates/`
  and the `invite-member` invitation). An e-mail loads no web font, so its Urdu text names
  Noto Sans Arabic and then sans faces readers already have (Segoe UI and Tahoma on Windows,
  Geeza Pro on Apple devices, the system's own on Android), at the Urdu type roles' sizes (a
  size larger than the English) on lines of whole pixels; `make tokens` writes it from the
  tokens, and `make tokens-check` fails when a template differs. The wordmark appears in the
  app's e-mail-link sign-in and portfolio-loading screens, the website's header and cards, the
  deck's cover, the header of the Auth e-mails and the invitation's footer. Still on Nastaliq:
  the gallery's screenshots, which predate the change.

  What the app bundles (an engineering choice, 12 November 2026): Flutter on the web downloads
  every bundled font before the app starts, so the app does not ship the two upstream files
  whole (845 KB and 690 KB, which would have doubled its fonts). `make fonts` builds its copies
  from `design/fonts/`: Noto Sans Arabic fixed at its normal width, every glyph and weight kept
  (495 KB), and Noto Nastaliq Urdu cut to the letters of the Urdu `appName` (54 KB). The app's
  four fonts come to about 700 KB (375 KB compressed), less than the 838 KB it bundled with
  Nastaliq alone. Text other than the brand name in the wordmark style would fall back to
  another face, which is why the wordmark style is for the brand name only.

- D-20: **The company's domain is `mmakaan.app`.** (Decided by the owner, 13 November 2026.) AR
  LABS bought `mmakaan.app`, registered at Dynadot, whose DNS keeps serving it. The website moves
  to `https://mmakaan.app`, with `www.mmakaan.app` redirecting to it (308), and the web app to
  `https://app.mmakaan.app`. The earlier addresses, `https://maalik-e-makaan-site.vercel.app` and
  `https://maalik-e-makaan.vercel.app`, send people on to the new ones for good, keeping the path
  and the query. The company's mailbox is `hello@mmakaan.app`, on Dynadot's own e-mail (its free
  plan; the owner, 13 November 2026, in place of the Zoho Mail first planned). It is the contact
  address of the website, the privacy pages and the deck, and the only mailbox on the domain that
  a page may name (`make docs-check` C17). It is also the sender of the app's own e-mails (the
  owner, 15 November 2026: the company's address everywhere), so Resend sends from `mmakaan.app`
  itself and not from a sending subdomain; `docs/operations.md`, E-mail, has what that takes. Done by the agent through the Vercel connector on 13
  November 2026: `mmakaan.app` and `www.mmakaan.app` (308 to the apex) on the project
  `maalik-e-makaan-site`, and `app.mmakaan.app` on `maalik-e-makaan`. Done by the owner: the
  records at Dynadot (`A` records `216.198.79.1` and `64.29.17.1` for the apex, `CNAME` records
  for `www` and `app`; 13 November 2026, when Vercel reported the three hosts as correctly
  configured), the new addresses checked over HTTPS, Auth's four redirect URLs and the Edge
  Functions' `ALLOWED_ORIGINS` (all reported on 14 November 2026). The pull request that makes the
  move can be merged, now that the new hosts serve HTTPS. This settles the domain that the App
  Store plan and Meta's verification wait on ([app-store](../docs/roadmap/app-store.md)).

  How it is built (engineering choices, 13 and 14 November 2026; `docs/operations.md`, Domains):
  - **One source.** `contracts/origins.json` names the site's and the web app's origins once
    each, with the earlier addresses under `legacy` and `www` under the site's `aliases`. Code
    reads it: the website's defaults, the deck, the Deploy and Release workflows (the web app's
    `APP_URL`, and the checks below) and the page the web app's earlier address answers with.
    Two files spell the addresses themselves and are checked against it in CI: the Android
    manifest's App Link hosts (`tool/android/check_manifest.py`) and `website/vercel.json`'s
    redirect (the website's unit tests); every other address in the repository is checked by
    `make docs-check` C17.
  - **The addresses travel with the release tag.** No workflow writes an origin and none reads
    one from a repository variable: a site refresh of an older tag builds that tag's addresses,
    and nothing changes in production before the release that carries the move. A Deploy run by
    hand on a tag runs that tag's own workflow, and a tag from before the move reads the
    `APP_URL` repository variable. The owner set that variable to the new address on 14 November
    2026, ahead of the order, so until it is deleted such a run, and any deploy from `main`
    before this pull request is merged, would build for the new address without what the move
    needs. It is deleted right after the move's web deploy, and those runs then stop before
    deploying. Rollbacks across the move go forward instead.
  - **Nothing is deployed to an address that cannot answer for it.** Each check gates the jobs
    that wait for it: that the web app's origin answers over HTTPS with its App Links file
    (Release's builds, and Deploy's web app), and that the site's origin and `www` answer and the
    web app it links to is the deployment built for its origin (Deploy's website; Release also
    deploys the website only after the web app), both with `tool/web/check_live.py`; that Auth
    allows the e-mail links of the release's builds (`tool/web/check_auth_urls.py`, from the
    Management API, in Release's `preflight` job before the builds and Deploy's `supabase` job
    before the backend; a token that may not read Auth's settings only warns); and that the Edge
    Functions accept the origin (a CORS preflight, Deploy's web app only). None of them reads the
    `APP_URL` secret or variable.
  - **What sends people on lives in the repository**, reviewed and tested and rolled back with
    a deployment: `website/vercel.json` (a redirect with a host condition, every path but a
    Google verification file) and the web app's Build Output routes
    (`tool/web/package_vercel.py`). Vercel's domain-level redirect is used only for `www`,
    because on the old app host it would also redirect `/.well-known/assetlinks.json`, which
    Android reads without following redirects.
  - **The old app host clears what the app kept in the browser there** (14 November 2026). A
    browser keeps the session, the lists the app loaded (CNICs among them), the settings and a
    pending invitation for each address apart, and once the old address only sent people on, no
    app would run there to remove them. So every page of the old host answers 200 with one small
    page instead of a redirect: its response carries `Clear-Site-Data: "storage"` (and nothing
    else: no `"cache"`, `"executionContexts"` or `"cookies"`), its same-origin script removes
    the app's own `localStorage` keys and goes to the same path, query and `#fragment` on the
    origin, and without scripts a meta refresh goes to the origin's first page. A redirect with
    the header was not enough: Chromium and Firefox act on the header on a redirect, WebKit only
    on the response a navigation ends on, and Safari before 17 does not know the header at all
    (sources in `docs/operations.md`). People who used the old web address sign in once more on
    the new one.
  - **What the old app host keeps answering:** `/.well-known/assetlinks.json` for good (Android
    builds list both hosts from the release that carries this, older ones only the old host),
    and the app's files, which no page there loads but a tab still open there may fetch; neither
    clears anything. `/auth/callback` was kept too, booting the app, from the move's release
    until the first release at least 24 hours after it (step 12: release 1.4.1, on 16 November
    2026), and since that release answers with the page. What that costs (promised in
    the review of #80): only a link that names the old callback reaches it, and only the app from
    before the move asks for one, since the app gives Auth the callback of the address it was built
    for (`APP_URL`). The move's app, which the old callback booted until that release, was built
    for the new address, so a link asked for in it on the old address names the new callback,
    where its verifier is not: it already cannot finish, and step 12 changes nothing for it. The
    window comes from tabs open on the old address since before the move (loaded before about
    13:45 UTC on 15 November 2026 and never reloaded): such a tab keeps running the app it loaded,
    whose sign-up, reset and e-mail-change links name the old callback, and can ask for one at any
    time, before the release or after it, until it is closed or reloaded. Each link is good for an
    hour. Opened after the release, the old `/auth/callback` answers with the page, which clears
    the storage holding the sign-in verifier before the code can be exchanged, and goes on to the
    same callback on the new address. There the app exchanges nothing and shows "This link did not
    work", telling the person to open the link where they asked for it (which cannot help once
    that storage is gone, until the follow-up in `.planning/STATE.md` lands) and that an e-mail
    being confirmed is confirmed (a sign-up took effect when Auth checked the link; an e-mail
    change only once both of its links have been); in a browser that has not yet chosen a language
    on the new address, it shows the language choice, then the sign-in page, with no word on the
    link. A password reset needs a new link, asked for on the new address, which works. Weighed on
    that basis and kept (`docs/operations.md`, Domains, Where it never clears): finishing the
    exchange on the page would carry a session across addresses in a URL; booting the app on the
    old callback only while a verifier is stored would keep the old address running the full app,
    with the session and the CNICs it loads, for anyone with a link pending (for good, if that link
    is never used or names the new callback), which is the exception this ends, and would give up
    the header, the only clearing that reaches IndexedDB and service workers; dropping the old
    callback from Auth's redirect URLs would also break the links of Android builds from before the
    move; waiting longer or a later release does not shorten the hour, nor close a tab from before
    the move.
  - **The web app is not indexed:** it answers `X-Robots-Tag: noindex` on every path, since every
    path answers with the app's shell and the website is what search engines index (D-01).
  - **Invitations after the move (the owner's choice):** the Edge Functions' `APP_URL` secret
    names the new address, so invitation e-mails show the company's domain. The owner set it on
    14 November 2026, before the release: until the release, an invitation opens the web app
    from before the move on the new address, where a sign-up cannot finish its e-mail link.
    Android builds from before the move list only the old host, so they open such an invitation
    in the browser, on the web app, until the new APK is installed. The owner decided on
    14 November 2026 to leave it there and not set it back before the release, because nobody
    uses the app yet. (Setting it back to the old address would open invitations in every
    build, with e-mails that show the `vercel.app` address.)
  - **Auth and the Edge Functions accept both hosts during the move** (set by the owner,
    reported on 14 November 2026): Auth keeps the old redirect URLs (web and iOS) until builds
    from before the move are out of use, a point the owner sets; `ALLOWED_ORIGINS` names both
    web app origins until the owner sets it to the new origin alone, which step 12's release
    (1.4.1, 16 November 2026) made due, and the Deploy workflow refuses to deploy a web app whose origin the functions
    refuse (it checks only the origin).

- D-21: **Saved records name their portfolio.** (Decided by the owner, 15 November 2026.) The
  pull request that wipes the device at sign-out (#70) waits until every saved entry's key says
  which portfolio it holds, so that each list of portfolios the app loads removes, from the keys
  alone, what the list no longer names; the privacy page keeps its plain sentence, that the app
  removes its copy "the next time it loads your list of portfolios", in English and Urdu. Built in
  `docs/architecture/app.md` (Reading; On the device, Writes after a removal).

- D-22: **Back cancels an account deletion until its request is sent.** (Decided by the owner,
  22 November 2026, in their words "Back cancels until sent", answering a question the device
  wipe's pull request, #70, left open.) Back pressed while the app is still checking the password
  (the sign-in again before the delete request goes out) cancels the deletion and sends nothing;
  once the delete request is on its way, Back is blocked until it is answered, so leaving never
  looks like cancelling. Both hold for every way the screen is left: Android's button and back
  gesture, the app bar's arrow, the browser's back, another section and a link; the router asks the
  deletion each time (`GoRoute.onExit`), and only its own redirect at a sign-out leaves the screen
  while a request is on its way. With another account signed in meanwhile (another tab), the screen
  stays for that account and waits too, and its Delete waits for the earlier request's answer, as
  Cancel does: that account's own deletion starts only once nothing is on its way, so Back and
  Cancel cancel it while its password is checked, as for anyone. Another section cancels as Back
  does, but keeps the screen in its own: shown again, it is no longer busy and says that the
  deletion was cancelled and nothing was sent. Cancel does what Back does (an engineering choice of
  the same day, for consistency): it works while the password is checked and waits once the request
  is sent. The sign-out rules for an answer that deleted or may have deleted are unchanged. Built in
  `docs/architecture/app.md` (On the device, Hooks).

- D-23: **Sheets and dialogs close when the signed-in account changes.** (Decided by the owner,
  22 November 2026, in their words "Close sheets on account change", answering a question #70
  left open.) When another account signs in on the device (in another tab, or by an e-mail link) or
  nobody is signed in any more, every open sheet, dialog and menu closes at once, without its
  closing animation, so the earlier account's details on show (an occupant's CNIC and phone, a
  member's or invitee's e-mail) go, and their buttons cannot act as the next account; a sheet the
  user was already closing finishes its closing animation, with its buttons ignoring taps. Snack
  bars are cleared too (an engineering choice of the same day), as one may name a record. A
  refreshed or new session of the same account changes nothing. The owner's standing rule holds:
  fewer mechanisms, so this is one small change in the app shell, not a check in every sheet;
  screens stay, for the router. Built in `docs/architecture/app.md` (On the device, Writes after a
  removal, The session the cache serves).

- D-24: **Phone backups are full.** (Decided by the owner, 22 November 2026, in their words "Full
  Backup".) The phone's own backups keep the app's data whole: Android's Auto Backup to the person's
  Google account and its transfer to a new phone, and on the iPhone a backup to iCloud or a
  computer, may include the sign-in and the saved records (tenants' CNICs among them). The privacy
  page says so in English and Urdu, in its backups bullet: a backup of the phone's apps ("Google's
  backup on Android, iCloud or a computer on iPhone") "can include your sign-in and the app's copy
  of your records as they were when it was made", and, in a sentence added with this decision, "When
  you get a new phone and bring your old phone's data across, your sign-in and the app's copy of
  your records can be copied to the new phone too". It says "can" because a move between an Android
  phone and an iPhone, either way, brings neither: the Auto Backup page (below) offers a move of an
  app's data to or from an iPhone only through a `<cross-platform-transfer>` section in the app's
  rules file, from Android 16 QPR2, which "must include the `<platform-specific-params>` element"
  naming the iPhone app, or through the app's own backup agent; this decision adds neither, and
  nothing in `app/ios` sets up such a move. The app neither turns the backup off nor leaves its
  preferences out of it. The device wipe's pull request (#70) had left this to the owner with the
  lawyer (question T7 of the legal pack, PR #66); it is now the owner's decision, and the pack's
  data map is to say that backups are full. The manifest writes `android:allowBackup="true"` out
  (Android's default, set so that the choice is seen), and `tool/android/check_manifest.py`
  (`make lint`, and CI on the merged release manifest) keeps it so: it refuses any other value, and
  any `android:fullBackupContent`, `android:dataExtractionRules` or `android:backupAgent` on the
  application, each of which would narrow the backup. If Android lint's DataExtractionRules check
  warns that no `dataExtractionRules` file for Android 12 and later is set, the warning is expected:
  this decision adds no rules file on purpose, as a full backup needs none (below) and the check
  would refuse one; CI runs only lint's fatal checks (`lintVital`, part of a release build). What it
  costs: the copy in Google Drive is end-to-end encrypted only on a phone with a screen lock, as
  that encryption "is enabled on devices running Android 9 or higher as long as the user has enabled
  backup in Android 9 or higher and has set a screen lock (PIN, pattern, or password) for their
  device" (the Auto Backup page, below); without one, the backup, tenants' CNICs among it, is
  "protected by the user's Google Account credentials" alone (the same page). And a sign-in kept in
  a backup made before a sign-out that could not reach the server can still sign in, since refresh
  tokens do not expire by time and `supabase/config.toml` sets no session time-box (a timeout on the
  hosted project stays the owner's open follow-up in `.planning/STATE.md`). What the backups hold,
  read on 22 November 2026:
  - **Android's cloud backup.** "Back up user data with Auto Backup"
    ([source](https://developer.android.com/identity/data/autobackup)): of `android:allowBackup`,
    "The default value is `true`, but we recommend explicitly setting the attribute in your
    manifest"; by default the backup includes "Shared preferences files" and the files under
    `getFilesDir()`, `getDatabasePath()` and `getExternalFilesDir()`, and "excludes files in
    directories returned by `getCacheDir()`, `getCodeCacheDir()`, and `getNoBackupFilesDir()`". It
    goes to "a private folder in the user's Google Drive account, limited to 25 MB per app" (above
    that nothing goes to the cloud until the data is smaller again), only the latest is kept, and it
    "is end-to-end encrypted on devices running Android 9 or higher using the device's PIN, pattern,
    or password" (only with a screen lock set, as what it costs says). A backup runs when the person
    has backup turned on, at least 24 hours after the last, with the phone idle and on Wi-Fi (unless
    they allowed mobile data); it is restored "whenever the app is installed, whether from the Play
    Store, during device setup ..., or by running `adb` install".
  - **Android 12 and later** (the app targets API level 36, Flutter 3.47.9's default). Their rules
    file is the one `android:dataExtractionRules` names, which "Applications can set"
    ([`<application>`](https://developer.android.com/guide/topics/manifest/application-element)),
    and "If there are no rules for a particular backup mode, such as if the `<device-transfer>`
    section is missing, that mode is fully enabled for all content except for `no-backup` and
    `cache` directories" (the Auto Backup page). So a full backup needs no rules file: cloud backups
    and device-to-device transfers ("User data is sent directly to the user's new device from their
    older device, such as by using a cable",
    [Android 12 behaviour changes](https://developer.android.com/about/versions/12/backup-restore))
    both take everything but those folders. Turning the attribute off would not have stopped every
    transfer either: "On devices from some device manufacturers, specifying
    `android:allowBackup="false"` disables cloud-based backup and restore (such as Google Drive
    backups) but doesn't disable device-to-device transfers for the app" (the Auto Backup page).
    `adb backup` leaves out the data of an app that targets Android 12 or later unless the app is
    debuggable (Android 12 behaviour changes), so `adb backup` on a computer does not copy the
    app's data; that page says nothing of a phone maker's own backup tool for a computer.
  - **The iPhone.** Apple's File System Programming Guide
    ([source](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)):
    "The contents of the `Library` directory (with the exception of the `Caches` subdirectory) are
    backed up by iTunes and iCloud", `Library/Preferences` (where `NSUserDefaults` keeps its
    values) and `Library/Application Support` among them, and `Documents/` too; the contents of
    `tmp/` and `Library/Caches` "are not backed up by iTunes or iCloud". "Optimizing your app's data
    for iCloud backup"
    ([source](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)):
    the system purges `/tmp` and `/Library/Caches`, "so iCloud Backup excludes them by default".
  - **Where the app keeps what is backed up** (the packages `pubspec.lock` pins). The session:
    supabase_flutter 2.18.3's `SharedPreferencesLocalStorage` (`SharedPreferences.getInstance()`),
    on Android the shared-preferences file `FlutterSharedPreferences` (shared_preferences_android
    2.5.4, `LegacySharedPreferencesPlugin.kt`:34), on the iPhone `UserDefaults.standard`
    (shared_preferences_foundation 2.6.1). The saved records, the display settings, the portfolio
    last chosen, a pending invitation and the camera's record: `SharedPreferencesAsync` and
    `SharedPreferencesWithCache` (`app/lib/src/bootstrap.dart`), on Android in DataStore by default
    (`shared_preferences_async_android_options.dart`:20), "a file in the "datastore/" subdirectory
    in the application context's files directory"
    ([source](https://developer.android.com/reference/kotlin/androidx/datastore/preferences/package-summary)),
    on the iPhone the standard user defaults. On Android the image and file pickers also keep a
    note of a pick, with paths into the cache folder, in shared-preferences files of their own,
    backed up too: `flutter_image_picker_shared_preference` (image_picker_android 0.8.13+25) and
    `flutter_file_picker_lost_data` (android_file_picker 2.1.4). Photos, picked files and shared
    files stay in the cache folder on Android and in `tmp/` and `Library/Caches` on the iPhone
    (`docs/architecture/app.md`, On the device), which no backup takes.

- D-25: **Only publish jobs of their own put files on a release or sign its provenance
  (release-please creates the release and its tag).** (Decided by the agent, 22 November 2026, under
  the owner's word of 16 November 2026 to make the rules hold more simply, with fewer mechanisms.)
  Release's build jobs, `artefacts` and `ios`, hold a read-only token and no OIDC token, and hand
  their files over as run artifacts. A publish job of its own for each build, `publish-artefacts`
  and `publish-ios`, on a fresh GitHub-hosted runner in the `release` environment, takes them by the
  artifact's id, keeps exactly the release's names, attests them, checks the provenance file against
  each and only then attaches them. release-please keeps its `contents: write` for the tag, the
  changelog and the release itself, and is held to a fixed template like the publish jobs. The check
  in `make lint`, `tool/github/check_release_provenance.py`, is structural: it reads permissions,
  secrets and two fixed templates (the publish jobs and release-please), and never shell. Why: the
  check it replaces read every bash spelling that could reach the upload, in a job that also ran
  Gradle's plugins, CocoaPods, the pub packages and Flutter, and each of its five review rounds
  found a new spelling, the last `bash -co pipefail "$CODE"`; nor could any rule close an earlier
  step of that job replacing the runner's `gh`. A job boundary closes the whole class: nothing a
  build runs reaches the publish runner, its write token or its OIDC token. The structural check
  replaces the bash reader, and the follow-up branch that extended it
  (`claude/release-provenance-followup`) was never pushed and is not merged. Built in
  `docs/operations.md` (Releasing; Release provenance, which also names what the check does not
  cover). It applies from the first release after v1.4.2: release pull request #109 (1.4.3) is
  held until this decision's pull request is merged, so that release-please folds it into that
  release.

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
