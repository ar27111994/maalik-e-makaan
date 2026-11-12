# A lawyer's review of the privacy notice and terms

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `legal-review` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Landlords put their tenants' names, phone numbers and CNIC copies into the app, and rely on its
guides for police-registration deadlines and tax. They need to know who answers for that data, and
that the guides are right. Both app stores also ask for a privacy policy and data declarations that
must agree with it, so a Pakistani lawyer's review is a condition of launch, not a polish (WEB-01).

## What is true now

This is a summary of research, not legal advice. Facts marked _(summary)_ were read only through a
search engine's summary, because the pages (including `pakistancode.gov.pk` and the legal
directories) could not be fetched.

- **No comprehensive data-protection statute is in force.** The Personal Data Protection Bill is
  still a draft; on 11 November 2026 the federal IT minister said a law is "nearing completion"
  _(summary)_ ([Arab News](https://www.arabnews.com/node/2636032/pakistan)).
- **PECA 2016 is the law that bites today.** Section 16 punishes unauthorised possession or use of
  another person's identity information with up to three years, a fine of Rs 5 million, or both
  _(summary)_ ([NHIMG](https://nhimg.org/pakistan-peca-guide)).
- **What the drafts would add** _(summary)_
  ([Chambers](https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2026/pakistan),
  [US Chamber](https://uschamber.com/international/submission-on-the-draft-pakistan-personal-data-protection-bill-2023)):
  breach notice within 72 hours, "critical personal data" kept in Pakistan, and CNICs treated as
  sensitive (2023 draft). The draft National Data Governance Policy of 26 June 2026 would require
  hosting in Pakistan, but appears to cover government data _(summary)_
  ([The Standard](https://thestandard.com.pk/i-t-ministry-makes-public-draft-data-governance-policy/)).
- **The privacy notice** ([privacy.md](../../website/src/content/pages/en/privacy.md), last updated
  11 November 2026):
  - names Supabase in Mumbai, Resend, Vercel, encrypted GitHub backups kept 90 days, and Google
    Fonts;
  - promises "no analytics or trackers" on the website and "no advertising, no analytics and no
    trackers" in the app;
  - says identity documents are not deleted automatically in version 1.0;
  - says AR LABS "decides how this data is used", which over-claims control of the tenant data that
    landlords enter.
- **The terms** say they "are a first version and will be completed after a legal review"
  ([terms.md](../../website/src/content/pages/en/terms.md)).
- **The guides.** Four guides, last reviewed on 5 November 2026, cite official texts this project
  could not reach, and say so where a point is unconfirmed
  ([guides](../../website/src/content/guides/en/)). Open points include provincial
  police-registration deadlines read from unofficial copies and the s.155 rates for a landlord not
  on the Active Taxpayers List.
- **Consent fields exist.** `tenants` has `consent_recorded_at` and a 300-character `consent_note`
  ([migration](../../supabase/migrations/20261103192902_properties_units_tenants.sql)).
- **The stores check consistency.** Google Play's Data safety form must agree with the privacy
  policy and disclose deletion _(summary)_
  ([Play Console Help 13327111](https://support.google.com/googleplay/android-developer/answer/13327111)).
- **Cost.** No published PKR fee scales were found for this kind of review; firms quote by "nature,
  complexity, urgency, and scope" _(summary)_
  ([example firm policy](https://naichlaw.pages.dev/services-policy.html)).

## Design

- **A fixed-fee request for quotation** to two or three firms that have both data-law and
  rent-litigation experience. Selection: an advocate of the High Court; PECA or data matters; rent
  cases in at least Punjab or Sindh; able to review Urdu; and agreement that review materials
  contain no real personal data.
- **A deadline at least six weeks before the first store submission**, so the store forms can be
  filled from the final text.
- **A review pack** (texts in both languages, the four guides, the tenant consent text, the receipt
  and statement templates, a one-page data map of data classes, processors and regions, a draft
  retention schedule, and the question list).
- **Fixed deliverables:**
  - a marked-up privacy notice and terms in English and Urdu, with a memo on what changes when the
    Bill passes;
  - an opinion on the controller and processor split: AR LABS as controller of account data and
    processor of the tenant data a landlord enters;
  - how to disclose hosting in India and the US;
  - whether the MIT licence's "as is" disclaimer holds under consumer law;
  - a line-by-line fact-check of the four guides;
  - a tenant information notice and consent form that landlords can print, on their letterhead;
  - the retention schedule's wording;
  - "for and on behalf of the owner, through attorney" wording for caretakers;
  - a list of triggers for a re-review.
- **Questions for the lawyer,** sent with the pack: does PECA s.16 reach a landlord's or a
  platform's copies of CNICs kept for police registration; would the current Bill classify CNIC
  copies as critical and so rule out Mumbai hosting; is AR LABS a "service provider" under s.32; do
  the consumer Acts cover a free or paid app; which language prevails when bilingual terms differ.

### Residence (decision 1)

Declared country of residence and time zone are personal data: the notice and the data export list
them, and say they are never shown to tenants. The terms describe a caretaker's authority, whether
under a power of attorney or as the "manager" whom the KP and Balochistan security Acts make
responsible for police registration, and say AR LABS does not verify it. The second new guide covers
powers of attorney for owners abroad.

### Letterheads (decision 2)

The terms carry the owner's warranty that they may use what they upload (logos, names, addresses)
and that it is accurate. The notice says letterhead files, including a portfolio's Urdu
letterhead, are stored privately, per portfolio, and deleted with the portfolio. The tenant notice
is designed to print on a letterhead.

### Analytics (decision 3)

The owner's decision withdraws the live promise of "no analytics" (D-18 in
[PROJECT.md](../../.planning/PROJECT.md)). The research recommends that its replacement, in both
languages, is reviewed here before any analytics SDK ships, and this plan follows it. The new
notice names every processor with its region and retention: PostHog (the existing US Cloud
project, cookieless on the website, opt-in in the app), Intercom (opt-in support chat, now owned by
Salesforce _(summary)_), and Customer.io (transactional e-mail, lifecycle e-mail only with consent,
on the existing US workspace). The owner decided on 12 November 2026 to keep both US accounts, so
the notice names the US as where PostHog and Customer.io handle data, under their standard
data-transfer terms. It says how to object or withdraw. The lawyer also confirms that the 60-day
notice before billing starts is a contractual service message, sent whatever the marketing consent,
and weighs the residual risk of cookieless counting for EU visitors, now done in the US.

## Work

1. **S:** the review pack, with first drafts of the privacy changes for decisions 1 to 3 in both
   languages, the data map and the question list.
2. **Owner:** the request for quotation; choose a firm; set the deadline.
3. **M:** terms rewrite: governing law and forum; the roles of AR LABS, owner, caretaker and tenant;
   the owner's warranty; liability; paid-plan clauses; the prevailing language.
4. **M:** privacy rewrite: controller and processor; purposes and bases; every recipient and
   country; retention; rights; a 72-hour breach commitment; opt-in analytics.
5. **S:** the model tenant notice and consent form in both languages, its version recorded in
   `consent_note`.
6. **M:** guide corrections from the fact-check, and `lastReviewed` updated.
7. **M:** new guide, "Moving out and the security deposit", written against verified law only (first
   half of the former L item).
8. **M:** new guide, "Owners abroad: powers of attorney and caretakers" (second half).
9. **S:** store forms filled from the final notice; a watch list in `docs/` of re-review triggers
   (the Bill, the Data Governance Policy, the Islamabad 2025 amendment, Punjab stamp duty, each
   July's s.155 rate cards).

## Depends on / Unblocks

- **Depends on:** [urdu-review](urdu-review.md) (the Urdu legal text is reviewed by both the editor
  and the lawyer), a draft schedule from [retention](retention.md), the paid terms from
  [billing](billing.md), and [move-out](move-out.md) for the deposit guide.
- **Unblocks:** [play-store](play-store.md) and [app-store](app-store.md) (privacy URL and store
  forms), [pilot](pilot.md) (a notice that covers tenants before real data goes in),
  [billing](billing.md), every analytics SDK under decision 3, [retention](retention.md) and
  [document-reading](document-reading.md).

## Risks

- **The Bill passes mid-review.** Ask for the memo on what changes, and budget a re-review within
  three months of enactment.
- **A localisation clause covers CNICs,** forcing a move away from Mumbai. Ask the lawyer early, and
  keep a Pakistani hosting option in view.
- **A lawyer strong in only one of data law and property law.** Make both a selection criterion, or
  engage two.
- **English and Urdu texts drift apart.** Review them together and publish both with one
  `lastUpdated`.
- **Landlords act on a wrong deadline in a guide.** Label every unverified claim as unverified until
  the fact-check confirms it.

## Done when

- [ ] A signed review memo or letter exists, dated after November 2026.
- [ ] Every question for the lawyer is answered or explicitly deferred.
- [ ] The notice names every processor and country, matching the infrastructure and both store
      forms.
- [ ] The terms state governing law, the parties' roles and the prevailing language.
- [ ] Both languages are published with the same `lastUpdated`, and the website checks pass.
- [ ] Every guide claim is verified against an official source or labelled unverified.

## Questions for the owner

- What is the budget, and by when must the memo arrive?
- Will AR LABS accept the processor role for tenant data, and say so?
- Which city's courts for the forum clause?
- Will tenants ever have accounts of their own?
- Will any analytics run at launch?
- Should a Pakistani hosting option be planned now?
