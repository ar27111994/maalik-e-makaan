# Questions for the lawyer

Part of the [legal review pack](README.md). This is not legal advice: it is the list of questions
we ask a Pakistani lawyer to answer. It brings together the questions already in
[legal-review](../roadmap/legal-review.md) (LR:74-89, :174-181) and the local research notes, and
adds the ones that decisions 1 to 3 raise and the ones found while building the
[data map](data-map.md).

Each question says **why it matters** and **what the drafts assume** until the lawyer answers, so a
wrong assumption is easy to spot. Questions are numbered within their group, and the numbers do not
change: a new question takes the next free number in its group.

Short names: **PJ**, **RM** and **LR** are [`.planning/PROJECT.md`](../../.planning/PROJECT.md),
[`docs/roadmap/README.md`](../roadmap/README.md) and
[`docs/roadmap/legal-review.md`](../roadmap/legal-review.md) at commit `ae0112c` on `main`,
with LR as this pack's pull request leaves it
([README](README.md#sources-and-conventions)); **RES** is `supabase/migrations/20261112092618_residence.sql` in pull request
[#61](https://github.com/ar27111994/maalik-e-makaan/pull/61) at commit `6608f1e` (not merged);
**PEN** and **TEN** are the live [privacy page](../../website/src/content/pages/en/privacy.md) (as
corrected by #62) and [terms](../../website/src/content/pages/en/terms.md). The research notes
`tenancy_law_and_data.md` (**RT**) and `analytics_support_letterheads.md` (**RA**) are local and
not in the repository. Facts marked _(summary)_ were read only through a search engine's summary.

The groups: [roles](#roles), [transfers and regions](#transfers-and-regions),
[analytics and consent](#analytics-and-consent), [e-mail](#e-mail),
[residence and caretakers](#residence-and-caretakers), [letterheads](#letterheads),
[tenants](#tenants), [retention and deletion](#retention-and-deletion),
[rights, breach and changes to the notice](#rights-breach-and-changes-to-the-notice),
[terms and consumer law](#terms-and-consumer-law), [guides](#guides) and [stores](#stores).

## Roles

- **R1. Is AR LABS the controller of account data and a processor of the tenant and property data
  a landlord enters?**
  - Why it matters: the live notice says AR LABS "decides how this data is used" (PEN:58), which
    over-claims control of tenant data (LR:45-46). Decision 3 adds data AR LABS clearly decides
    about: the website's counts, analytics, support chat and its own e-mail.
  - The drafts assume: AR LABS is controller of account data, privacy choices, website counts,
    usage analytics, support chats and its own e-mail, and handles the landlord's records "on your
    behalf" (draft notice, "Who runs it"). The owner has not yet said whether AR LABS accepts the
    processor role (LR:177; RM:444).
  - Sources: LR:77-78 (a fixed deliverable); RT §1.

- **R2. Is AR LABS a "service provider" under PECA s.32, and must it keep traffic data?**
  - Why it matters: s.32 asks a service provider to keep traffic data for at least a year
    _(summary)_ ([Cyrilla's copy of PECA](https://cyrilla.org/fr/entity/8qdfnvctt13?page=13);
    [DRF policy brief, 2017](https://ifex.org/pakistan/2017/10/26/pakistan-policy-brief-for-moit-digital-rights-foundation.pdf)).
    The statute's definition of "service provider" was not read. The nearest analogues are the reminder log, Edge Function logs, and, under decision
    3, Customer.io's delivery records and Intercom's conversations.
  - The drafts assume: it is not, and no retention for that purpose is stated.
  - Sources: LR:88-89; RT §1 ("PECA s.32 probably does not reach the app").

- **R3. How should the notice describe services that act as their own controllers?**
  - Why it matters: Vercel's notice says it collects visitors' IP addresses and the location
    derived from them as controller _(summary)_; Intercom's DPA makes it an independent controller
    of account data _(summary)_; Supabase is controller of AR LABS's own account with it (primary).
  - The drafts assume: each is named with what it receives, as a service that runs part of the app.
  - Sources: [data map](data-map.md#services-that-handle-the-data).

- **R4. What does AR LABS do when a tenant writes to it directly?**
  - Why it matters: tenants have no accounts, and under R1 the landlord decides about their data.
  - The drafts assume: AR LABS passes the request to the landlord (draft notice, "Your tenants'
    details" and "Your rights").

- **R5. How should the notice describe access by AR LABS's own staff and by its services' support
  staff?**
  - Why it matters: operators can reach the database to delete accounts, restore backups and fix
    faults ([`docs/operations.md`](../operations.md)); Supabase's support staff are "located
    globally" and may access data when asked for help "or when we identify and respond to security
    incidents" (primary).
  - The drafts assume: one sentence on operator access, with the owner to set the rule for when
    staff may look at records.

- **R6. Should the notice name the landlord's duty to tell tenants about the app?**
  - Why it matters: the tenant notice and consent form (work item 5) is printed by the landlord;
    the privacy page is read by account holders.
  - The drafts assume: the privacy page tells landlords to collect only what they need and to
    record consent, and links to the printable notice once it exists.

## Transfers and regions

- **X1. How should the notice disclose hosting in India and the United States, and which
  countries must it name?**
  - Why it matters: the notice will name the US for PostHog and Customer.io (PJ:145-148), so naming
    countries for the rest must be consistent. The repository establishes India (Supabase, Mumbai)
    and, by the owner's decision, the US for PostHog and Customer.io. Supabase's logs are in the EU,
    its support staff are global, Storage content "may be cached or served through a global CDN
    outside your region", and Supabase Pte. Ltd. (Singapore) and Supabase, Inc. (US) are the
    companies involved (primary). Edge Functions, which send invitations and delete accounts and
    would run the fan-out, Intercom's token, the Customer.io sync and letterhead PDFs, may run
    outside Mumbai ([data map](data-map.md#gaps-between-the-code-the-live-notice-and-the-plans), gap
    11). PostHog's sub-processors add Cloudflare's worldwide edge for data in transit, Wiz (Germany,
    France) and its own companies in the United Kingdom and Germany (primary). GitHub stores data
    "in a variety of locations, including … the United States" (primary). Resend's sending domain is recorded in us-east-1
    ([`docs/release-readiness.md`](../release-readiness.md):338), but that all its data stays in the
    US is a summary; Vercel's US location is a summary only.
    Google's country for Google Fonts is not established. Intercom's region is not chosen.
  - The drafts assume: every country that is established is named, with Singapore, the EU and
    "the other countries named above" in the transfer sentence; PostHog's other handlers and
    Supabase's content delivery network are described, not listed by country; the rest carry
    "[To confirm]". Must each sub-processor and country be named?
  - Sources: LR:79 (a fixed deliverable); [data map](data-map.md#services-that-handle-the-data).

- **X2. Are transfers under the services' standard terms enough, and must the DPAs be signed
  first?**
  - Why it matters: the owner decided that the notice names the US "under their standard
    data-transfer terms" (PJ:146-148). The draft Bill would allow transfers only to places with
    comparable protection _(summary)_ (RT §1). Which DPAs AR LABS has accepted is not recorded:
    Supabase's forms part of its terms of service; PostHog's binding copy is generated in its app,
    on any plan (primary); Vercel's covers Pro and Enterprise customers only _(summary)_; GitHub's
    needs "a written and executed agreement".
  - The drafts assume: the standard terms suffice for now, and the DPAs are in place before any
    data flows (RM:314 lists PostHog's).

- **X3. Would the Bill class CNIC copies as critical personal data and so rule out hosting in
  Mumbai?**
  - Why it matters: the 2023 draft kept "critical personal data" in Pakistan and treated CNICs as
    sensitive _(summary)_ (LR:31-35). A move off Mumbai would be large.
  - Also: CNIC images opened through the app may be served through Supabase's content delivery
    network from outside India (primary), and the encrypted weekly backup, which holds every CNIC
    and document, is a workflow artefact of a public repository that any signed-in GitHub user can
    download for 90 days; only the owner's key opens it
    ([data map](data-map.md#live-now), row 18). Is a public, encrypted copy outside Pakistan
    acceptable, under PECA s.16 today and the Bill later?
  - The drafts assume: Mumbai stays; no statute in force forbids it (RT §1). The backup stays where
    it is until the owner decides otherwise ([README](README.md#before-the-pack-goes-out)).
  - Sources: LR:87-88, :155-156, :181 ("Should a Pakistani hosting option be planned now?").

- **X4. Does the draft National Data Governance Policy of 26 June 2026 reach a private app?**
  - Why it matters: it would require hosting in Pakistan, but appears to cover government data
    _(summary)_ (LR:35-37).
  - The drafts assume: it does not.

- **X5. Does the Vercel plan matter?**
  - Why it matters: Vercel's Hobby plan is "for personal or non-commercial use" and its DPA names
    Pro and Enterprise only _(summary)_. The team's plan is not recorded.
  - The drafts assume: the owner confirms the plan before the pack is sent
    ([README](README.md#before-the-pack-goes-out)).

- **X6. PostHog's AI features: disclose their sub-processors, or switch them off?**
  - Why it matters: AI data processing is approved at the organisation level (read through
    PostHog's API on 12 November 2026). PostHog lists ten third-party AI sub-processors, used
    "only if AI features are enabled" ([sub-processors](https://posthog.com/subprocessors);
    `src/data/subprocessors.json` at the pinned commit, primary).
  - The drafts assume: the AI features are not used on this project's data, so these
    sub-processors are not named. If the owner keeps them on, the notice must name them.

## Analytics and consent

- **A1. Is cookieless counting with a notice, an objection switch and Do Not Track enough, for
  visitors from Pakistan, the UK and the EU?**
  - Why it matters: Pakistan has no cookie-consent rule and no data-protection statute in force
    _(summary)_. In the UK, the Data (Use and Access) Act 2025's exemption for statistical cookies,
    in force since 5 February 2026, needs a clear notice and an easy way to object _(summary)_
    ([PolicyPros](https://www.policypros.co.uk/cookie-consent-changes-duaa-guide/),
    [Bratby Law](https://bratby.law/data-use-and-access-act-2025-commencement/)). In the EU, the
    EDPB's Guidelines 2/2023 (version 2.0, 7 October 2024) read ePrivacy Art. 5(3) as reaching some
    IP-based tracking _(summary)_
    ([EDPB, PDF](https://edpb.europa.eu/system/files/2024-10/edpb_guidelines_202302_technical_scope_art_53_eprivacydirective_v2_en_0.pdf),
    not opened), and the counting is done in the US.
  - The drafts assume: the same notice, switch and Do Not Track for everyone, as the owner decided
    (RM:474-475); the lawyer weighs the residual EU risk (LR:117-119). The alternatives are consent
    for EU visitors, or no counting for them (RA §1).

- **A2. Is PostHog's cookieless hash personal data, and does it need notice and a basis?**
  - Why it matters: the IP address and user agent are personal data in transit through Vercel to
    PostHog. PostHog's view that the stored daily hash is not personal data is the vendor's own
    (RA §1).
  - The drafts assume: the notice says what passes and what is kept, and says the code "cannot be
    matched to you later" because the daily salt is deleted. The lawyer confirms that wording, and
    whether the English may call the counting "anonymous": the drafts say "without knowing who you
    are", as the Urdu does. Whether the IP address reaches PostHog through the site's rewrite at all
    is a preview check (RM:316); if it does not, only page views are counted.

- **A3. The objection switch stores the visitor's choice in the browser. Does that need consent,
  and can the page still say "no cookies"?**
  - Why it matters: in PostHog's "always" cookieless mode the SDK ignores its own opt-out
    ("PostHog ignores `opt_in_capturing()` and `opt_out_capturing()`", PostHog's cookieless
    tutorial, l. 35, primary), so the switch must work by not loading the counter, and the choice
    has to be stored somewhere. The research calls it strictly necessary storage that the "no
    cookies" promise should mention (RA §1). Whether it is a cookie or local storage is not decided.
  - The drafts assume: local storage, described as "the only thing this site keeps in your
    browser".

- **A4. Should the site honour Global Privacy Control as well as Do Not Track?**
  - Why it matters: the design names Do Not Track only (RM:285); the research suggests both
    (RA §1).
  - The drafts assume: Do Not Track only.

- **A5. Opt-in app events: may PostHog store city and country?**
  - Why it matters: "discard client IP data" does not stop location being added before the IP is
    removed (PostHog, "Controlling data collection", ll. 181-191, primary). The GeoIP step was
    enabled in project 730301 when read on 12 November 2026.
  - The drafts assume: the notice says so while it is on; the owner may switch it off instead.

- **A6. Is the consent record good enough evidence, and how long is it kept?**
  - Why it matters: one shape for every consent: subject, purpose, text version, granted and
    withdrawn times, method, evidence, who recorded it (RM:302-307).
  - The drafts assume: the shape is enough; the period after withdrawal is left open. Also: must
    consent be asked again when the text version changes?

- **A7. Is the opt-in screen's wording right?** [Placeholder: the consent screen's text is not
  written yet (RM:312). It is added to the pack when it exists.]

- **A8. Support chat: what must the chat and the notice say, given that people may write tenants'
  names or CNICs in it, and who answers for that data?**
  - Why it matters: Intercom holds whatever the person writes (RA §3). Intercom is now owned by
    Salesforce _(summary)_, and its region is not chosen (RM:321, :449).
  - The drafts assume: the notice asks people not to write tenants' CNICs or details in the chat,
    and names Intercom with a placeholder region.

- **A9. How long may PostHog keep counts and events?**
  - Why it matters: no period is set for project 730301, so it keeps events for 84 months (7
    years), read through PostHog's API on 12 November 2026. Setting a period needs a paid plan, up
    to that plan's maximum ("Customizable data retention is not available on the Free plan"), and
    expired events "may be stored longer than your retention period" (PostHog, "Events data
    retention", ll. 17-31, 54-60, 104, primary). The organisation's PostHog plan is not recorded.
  - The drafts assume: the owner sets a shorter period and the notice states it. [Owner: the
    organisation's PostHog plan.]

- **A10. Analytics in the app in a web browser: none, or after opt-in?**
  - Why it matters: the design leaves it open (RM:319). It changes what the notice says about the
    web app.
  - The drafts assume: open; the notice carries a placeholder.

- **A11. May the app's analytics carry the phone's time-zone setting, language, mobile network and
  an IP-derived city and country, given that residence is declared, never inferred and never sent
  to analytics?**
  - Why it matters: `posthog_flutter` wraps PostHog's Android and iOS libraries, which add the
    phone's make, model, system version, app version, screen size, language and time zone to every
    event, and on Android the mobile network (primary;
    [data map](data-map.md#sources-for-the-planned-rows), P6). With GeoIP on, PostHog also stores
    city and country (A5). The time zone and the network can hint at where a person lives.
  - The drafts assume: the analytics wrapper removes the time zone, language and mobile network,
    the notice lists the technical details that remain, and the owner decides on GeoIP (A5). If the
    wrapper does not remove them, the notice names them.

## E-mail

- **E1. Is the notice at least 60 days before billing starts a contractual service message, sent
  whatever the person's marketing choice? Is the notice of this privacy change one too?**
  - Why it matters: the pricing page promises it "by email and in the app"
    ([`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):13). If anyone is charged
    before 28 February 2027, it goes by 30 December 2026
    ([`.planning/STATE.md`](../../.planning/STATE.md):173-174; RM:415), possibly before Customer.io
    is approved for use.
  - The drafts assume: yes to both, sent as service e-mail.
  - Sources: LR:116-118; RM:297-298.

- **E2. E-mailed receipts and service messages go through Customer.io in the US. Do they carry
  tenants' names and amounts, does that fit the processor role, and must tenants be told?**
  - Why it matters: RM:294-297 sends "receipt" messages through Customer.io, while
    [retention](../roadmap/retention.md):114 says tenant data never reaches it. What an e-mailed
    receipt contains is not designed. Under [overseas-oversight](../roadmap/overseas-oversight.md),
    a weekly digest and an e-mailed owner statement would also go through Customer.io, "because it
    carries names and amounts" (:99-102, :129, :134-136).
  - The drafts assume: a receipt the landlord chooses to e-mail carries what the receipt shows, and
    the notice says so; tenant details reach an e-mail service only in e-mails the account holder
    asks for, and the notice names the digest and the statement once they ship.

- **E3. Invitations move from Resend to Customer.io. What is the basis for sending to an invitee
  who is not yet a user, and may Customer.io keep a profile of them?**
  - Why it matters: today invitations go through Resend
    ([`docs/operations.md`](../operations.md):170-171); the design moves them (RM:294-298). The
    research did not read Customer.io's data or deletion documentation (RA §4).
  - The drafts assume: the invitation is a service e-mail sent at a member's request.

- **E4. Tips and news by e-mail: may opens and clicks be counted, and may account events be used?**
  - Why it matters: the design turns link tracking off only for service e-mail (RM:295-296). The
    research proposes sending account events such as a first property or a first payment recorded
    (RA §4).
  - The drafts assume: account events are used only with consent, never tenants' details or
    amounts; whether opens and clicks are counted is left to the owner, and the notice must say so
    if they are.

- **E5. Must the text of each e-mail be kept out of Customer.io's delivery records?**
  - Why it matters: Customer.io's transactional e-mail request has an option named
    `disable_message_retention`
    ([its Node library, l. 28](https://github.com/customerio/customerio-node/blob/909f3891ceb0d77653e8192eb79e895e7e35936b/lib/api/requests.ts#L28),
    primary), which [overseas-oversight](../roadmap/overseas-oversight.md):134-136 plans to use.
    What it keeps out of the delivery records is [To confirm: in Customer.io's API reference, which
    could not be fetched]. It matters for receipts.
  - The drafts assume: open; the notice carries a placeholder.

- **E6. Service e-mail is promised as not tracked. Is that promise right, and what may the notice
  say until the owner confirms that tracking is off?**
  - Why it matters: the design turns off only link tracking on Customer.io's transactional path
    (RM:294-296), which leaves the open pixel. Resend's click and open tracking on
    `news.ar27111994.dev` are off: the owner reported on 12 November 2026 that they had switched
    them off some days before ([`docs/release-readiness.md`](../release-readiness.md):338-341).
  - The drafts assume: "We do not track whether you open these emails or click their links" is
    published only after the owner confirms that open and click tracking are off at Customer.io
    (at Resend they are off); until then the sentence carries an owner bracket in both languages
    ([README](README.md#before-the-pack-goes-out)).

## Residence and caretakers

- **C1. Is a declared country of residence and time zone personal data that needs notice and a
  basis? Is it sensitive, and is "no one else who uses the app can see it" the right promise?**
  - Why it matters: a country can hint at immigration status, though nationality and immigration
    status are never stored (RES:5-8). LR:93-94 calls residence personal data that the notice and
    the data export list.
  - The drafts assume: it is personal data; the notice says it is declared, never inferred, seen
    by no other user (operators can reach it, as they can the whole database: RES:347), never by
    tenants, never audited and never sent to analytics or e-mail tools, and cleared when deletion
    starts (RES:9-13, :261-271). The analytics libraries' own time-zone setting and GeoIP are A11.

- **C2. The owner-abroad answer is often given by a caretaker or relative about the owner. Is it the
  owner's personal data supplied by someone else, and must the owner be told?**
  - Why it matters: every member can read it, and changes are audited with who made them
    (RES:15-24, :32). Once answered, only an owner can change it (RES:546-588).
  - The drafts assume: the notice and the terms say who may answer and who sees it.

- **C3. A caretaker's authority.**
  - Why it matters: a caretaker may act under a power of attorney or as the "manager" whom
    provincial laws name: in Sindh, "a landlord, manager or property dealer must check the tenant's
    CNIC"; in Khyber Pakhtunkhwa and Balochistan, "the landlord, lessee or manager" registers the
    tenant ([police guide](../../website/src/content/guides/en/police-registration.md):80, :90,
    :109). LR:94-95 names only Khyber Pakhtunkhwa and Balochistan.
  - Questions: must a power of attorney to let property be registered? Do rent registrars and the
    police accept NADRA's e-POA? What authority has a caretaker without one (RT §6)? Is the clause
    that AR LABS does not verify any authority enough?
  - Requested: the "for and on behalf of the owner, through attorney" wording for documents a
    caretaker signs (LR:84; RM:243-245).
  - The drafts assume: terms clause 2.2 in [terms-changes.en.md](terms-changes.en.md).

- **C4. When a caretaker records payments, issues receipts or registers tenants, who is
  responsible: the owner, the caretaker, or both?**
  - The drafts assume: as between the owner and AR LABS, the owner (terms clause 2.3).

- **C5. Is it a consumer-law problem that the store's country sets the price while declared
  residence only suggests a plan?**
  - Why it matters: an owner abroad with a Pakistani store account pays rupee prices
    ([`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):112, :121;
    [`billing.md`](../roadmap/billing.md):111).
  - The drafts assume: no problem, if the notice and terms say so.

- **C6. May AR LABS use declared residence for anything else, such as choosing pilot participants?**
  - Why it matters: the pilot plans quotas by declared residence, "asked in the screener and, once
    the residence fields exist, in the app" ([`pilot.md`](../roadmap/pilot.md):97-98).
  - The drafts assume: residence is used only for the person's own alerts and to suggest a plan.
    Any other use is added to the notice first.

- **C7. People who share a portfolio can read each other's name, e-mail and phone. Must the notice
  say so, or should access be narrowed?**
  - Why it matters: a caretaker and an owner abroad see each other's contact details
    (`supabase/migrations/20261103192722_identity_portfolios.sql`:655-657). The live notice is
    silent.
  - The drafts assume: the notice says so.

## Letterheads

- **L1. The owner's warranty for letterhead content. Is a removal route needed for a misused name
  or logo, and an indemnity?**
  - Why it matters: an owner may upload someone else's logo, a company's name or an address
    (LR:101-102).
  - The drafts assume: terms clauses 3.2 and 3.4.

- **L2. Does a letterhead change who issues a receipt? Must the English and Urdu letterheads name
  the same issuer?**
  - Why it matters: the portfolio is the issuer on its receipts (PJ:126-127); a letterhead may name
    a company or a caretaker.
  - The drafts assume: the letterhead must name the issuer, in both versions (terms clause 3.2).

- **L3. How should the notice treat other people's details printed on a letterhead, such as a
  caretaker's phone or a company's address?**
  - The drafts assume: the owner promises they have permission (terms clause 3.2); the notice lists
    letterheads as data the app stores.

- **L4. Must letterhead files be in the backups, and may one be copied between portfolios with
  different co-owners?**
  - Why it matters: the backup downloads only the `documents` bucket
    ([`backup.yml`](../../.github/workflows/backup.yml):157-169). Copying is to "the owner's other
    portfolios" (PJ:126-127), which may have other members.
  - The drafts assume: open; the notice carries a placeholder for the backup.

- **L5. Should the printable tenant notice name AR LABS's role?**
  - Why it matters: it prints on the landlord's letterhead (LR:81, :103-104).
  - The drafts assume: open, for work item 5.

## Tenants

- **T1. What is the exact text of PECA s.16, and does it reach a landlord's or a platform's copies
  of CNICs kept for police registration?**
  - Why it matters: it punishes unauthorised possession or use of identity information with up to
    three years, a fine of Rs 5 million, or both _(summary)_ (LR:28-30).
  - Sources: LR:86-88.

- **T2. Is it acceptable that the app cannot erase a tenant's identifying details today?**
  - Why it matters: a tenant with any tenancy can only be archived
    (`supabase/migrations/20261103193403_leases.sql`:90-91), and the audit trail keeps a deleted
    tenant's phones, addresses and references, everything except the CNIC, until the portfolio is
    deleted (`…_notifications_audit.sql`:294-353). The purge is planned for 2027
    ([retention](../roadmap/retention.md)).
  - The drafts assume: the notice states the limit plainly. Should version 1 gain an erasure path
    before the pilot puts real tenants in?

- **T3. Every role, viewers included, can read full CNICs and open CNIC images through the app's
  server; masking is on screen only. Is that acceptable?**
  - Sources: `supabase/migrations/20261103192902_properties_units_tenants.sql`:288-290; PJ (D-09).
  - The drafts assume: the notice keeps "as far as their role allows" and "masked on screen by
    default", which are true. Should access be narrowed before launch?

- **T4. The reminder log keeps the whole message, up to 1,000 characters, which can hold a bank
  account number. The live notice says so since #62. Should the app keep less, before the
  retention plan cuts it down?**
  - Sources: `supabase/migrations/20261103194151_operations.sql`:451-453; PEN:27 (since #62,
    `fabc088`).
  - The drafts assume: the notice keeps saying what is kept, and adds what the message can hold.

- **T5. What must the tenant notice and consent form say?**
  - Why it matters: tenants' data leaves India only in the encrypted backups on GitHub, and, under
    decision 3, in receipts a landlord e-mails (E2) or details someone writes in a support chat
    (A8).
  - Requested: the form itself is a fixed deliverable (LR:82), for work item 5.
  - Also: the app's checkbox records that the tenant was told what is kept and why ("I told the
    tenant what details are kept and why"), with a note of "What they agreed to"
    ([`app_en.arb`](../../app/lib/l10n/arb/app_en.arb):2282, :2286), while the notice, the terms and
    the app's own status line ("Consent recorded on {date}", :2290) call it the tenant's consent.
    Which is it, and must the notice, the terms or the label change?

- **T6. Will tenants ever have accounts, and what changes if they do?**
  - Sources: LR:179; [tenant-portal](../roadmap/tenant-portal.md) (links first, no analytics on
    the tenant page).

- **T7. Full tenant records, CNICs included, are cached on the landlord's device without
  encryption until sign-out (in the browser's local storage on the web). Must the notice say so,
  and is it an adequate safeguard?**
  - Sources: [`swr_cache.dart`](../../app/lib/src/data/cache/swr_cache.dart);
    [`tenant.dart`](../../app/lib/src/features/tenants/data/tenant.dart):124.

## Retention and deletion

- **D1. The retention schedule's wording.**
  - Questions: the default period for identity documents after a tenancy ends (between 3 and 12
    months is recommended, RM:452) and the holds; whether agreement images are kept as evidence;
    the conditions in ETO s.6; whether tax records include identity documents; how long AR LABS
    keeps account data after deletion.
  - Sources: [retention](../roadmap/retention.md); RT §4; LR:83 (a fixed deliverable).

- **D2. Deleting a portfolio or an account deletes its financial records and audit trail at once,
  inside the six years ITO s.174 asks for. Should the app warn, hold, or offer an export first?**
  - Sources: [retention](../roadmap/retention.md):32;
    [audit-screen](../roadmap/audit-screen.md):81.
  - The drafts assume: the notice describes deletion as it works today.

- **D3. Account deletion asks PostHog, Intercom and Customer.io to delete too, "retried without
  holding up the deletion" (RM:313). What time limit can the notice promise?**
  - The drafts assume: a placeholder for the limit.

- **D4. Must each service's own retention be stated?**
  - Why it matters: LR:111 asks for "every processor with its region and retention". Not recorded:
    Supabase's logs, Vercel's logs, Intercom and Customer.io. Resend keeps e-mail and logs 30 days
    _(summary)_. PostHog: see A9.
  - The drafts assume: yes, with placeholders until each is read from the service's settings or
    terms.

- **D5. What survives account deletion in other people's portfolios: the records the person made
  (with the link to the account removed), audit rows, an accepted invitation with their e-mail, the
  notices the other owners got when they joined (with their e-mail, for up to 180 days) and free
  text. Is saying so enough?**
  - Why it matters: Apple asks that deletion remove "the entire account record, along with
    associated personal data" and, where some data must be kept, that people be told
    ([Apple](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)).
  - The drafts assume: the notice says what stays and why.

## Rights, breach and changes to the notice

- **N1. Which rights to offer, how, and how fast?**
  - Why it matters: no statute in force lists them; the draft Bill would. Work item 4 asks for
    "rights" (LR:129-130). There is no export of a person's own data today, though LR:93-94 assumes
    "the data export", and the pricing page says "You can always take your data out"
    ([`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):113).
  - The drafts assume: seeing, correcting, deleting, withdrawing and objecting, by e-mail where the
    app has no screen for it, with the reply time and any authority to complain to left open.

- **N2. The 72-hour breach commitment: from when, to whom, and how?**
  - Why it matters: work item 4 asks for it (LR:129-130); the 2023 draft Bill asks for 72 hours
    _(summary)_ (LR:31-35). Supabase promises notice "where feasible, within forty-eight (48)
    hours"; PostHog "without undue delay" (both primary).
  - The drafts assume: 72 hours from when AR LABS learns of it, to account holders by e-mail and in
    the app, with landlords telling their tenants.

- **N3. Is a new date at the top enough notice of adding analytics, or must existing users be told
  in the app or by e-mail?**
  - Sources: PEN:21; TEN:33.
  - The drafts assume: open; see also E1.

- **N4. Must "anyone can check what it does" be qualified, since the services' settings are not in
  the code?**
  - Sources: PEN:62; PJ:154-157.
  - The drafts assume: the notice lists the settings that matter.

- **N5. A minimum age, and children.**
  - Why it matters: neither the notice nor the terms say anything (RT §7).

- **N6. What changes when the Bill passes, and when the Islamabad 2025 amendment is enacted?**
  - Why it matters: LR:75-76 asks for a memo. The Bill's status is unclear: LR:25-27 quotes the IT
    minister on 11 November 2026 as saying a law is "nearing completion" _(summary)_, while a
    summary of another report of the same event says only that a law is being "developed", with no
    timeline _(summary)_
    ([Arab News Pakistan](https://www.arabnews.pk/pakistan/pakistan-warns-foreign-ai-could-threaten-cultural-religious-identity-3006727)).
    The Islamabad amendment is on LR's watch list (LR:137-139).

- **N7. The purpose and basis for each use.**
  - Why it matters: work item 4 asks for "purposes and bases" (LR:129-130), and there is no
    statute in force that defines bases.
  - The drafts assume: a plain list of purposes ("Why we use it"), with the bases left to the
    lawyer.

## Terms and consumer law

- **G1. Do the consumer Acts (Islamabad 1995 or the provincial Acts) cover a free or a paid app?**
  (LR:89)
- **G2. Does the MIT licence's "as is" disclaimer hold against consumers?** (LR:80, a fixed
  deliverable)
- **G3. Which language prevails when the English and Urdu terms differ?** (LR:89)
- **G4. Governing law and forum.** The owner chooses the city (LR:178); the lawyer drafts the
  clause (LR:127-128).

## Guides

- **F1. A line-by-line fact-check of the four guides** (LR:81, a fixed deliverable).
  - Known open points: the Sindh duty to check and copy the tenant's CNIC, read in an excerpt that
    did not show its section number
    ([`police-registration.md`](../../website/src/content/guides/en/police-registration.md):80); the
    Khyber Pakhtunkhwa wording and deadline, read in an unofficial copy (:90); Balochistan's three
    days against a secondary source's fifteen (:109); the cap on collection charges, 4% or 6% in two
    secondary sources, and other section 15A items not confirmed from an official text
    ([`rental-income-tax.md`](../../website/src/content/guides/en/rental-income-tax.md):53, :55); the
    s.155 rates for a landlord not on the Active Taxpayers List (LR:52-53).
  - The drafts assume: each point stays labelled unconfirmed until the lawyer confirms it
    (LR:161-162, :172). The terms clause on caretakers (C3) relies on the police guide's lines.

- **F2. Which events should bring the notice, the terms and the guides back for review?** (LR:85, a
  fixed deliverable.)
  - Why it matters: work item 9 keeps a watch list in `docs/` (LR:137-139): the Bill, the Data
    Governance Policy, the Islamabad 2025 amendment, Punjab stamp duty and each July's s.155 rate
    cards. A new processor, country or kind of data would also change the notice
    ([README](README.md#keeping-the-pack-current)).
  - The drafts assume: that list, plus any change the README's "Keeping the pack current" names.

## Stores

- **S1. Will the lawyer review the store declarations as well?**
  - Why it matters: Google Play's Data safety form and Apple's App Privacy details must agree with
    the notice, and even opt-in collection is declared (RM:328-329; LR:56-58).

- **S2. Does Apple's exemption for "product improvement programs" apply to the app's analytics?**
  - Why it matters: it applies only if, among other conditions, the data is not linked to the
    user's identity
    ([App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)). The
    design uses a pseudonymous id that is not the account's id (RM:318).

- **S3. Google Play asks for a web route to request deletion as well as deletion in the app
  _(summary)_. Is the e-mail address on the privacy page enough?**
  - Sources: [Play Console Help 13327111](https://support.google.com/googleplay/android-developer/answer/13327111)
    _(summary)_.

- **S4. Apple asks apps to "secure user consent for the collection, even if such data is considered
  to be anonymous" (guideline 5.1.1(ii)). Does the opt-in design meet it, and does the website's
  counting need anything for the app's listing?**
  - Sources: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

- **S5. Must coarse location and device identifiers be declared for the opt-in analytics and
  support chat, or should GeoIP be switched off and the identifiers kept out?**
  - Why it matters: with GeoIP on, opt-in events store city and country, and Apple asks apps to
    declare data by how they use the IP address
    ([App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)). The
    analytics code and Intercom's device-level identifier are identifiers. The first draft of the
    declarations is in the [data map](data-map.md#what-the-store-forms-would-declare).
  - The drafts assume: the forms declare what the notice says, as optional data collected after
    opt-in; the owner decides on GeoIP (A5).
