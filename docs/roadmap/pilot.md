# A pilot with the first landlords

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `pilot` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

The app has passed its tests, but no landlord has yet run a month's rent through it. A pilot with
real landlords at home and owners abroad with their caretakers, over at least two rent days, shows
whether recording a payment and sending a receipt is quicker than the notebook it replaces. It also
shows what to fix before the public launch and what to build next.

## What is true now

- **No comparable pilot.** No published pilot of a Pakistani rent-management app was found;
  Pakistani proptech has centred on property dealing, not rent collection
  ([ProPakistani, 2023](https://propakistani.pk/2023/02/28/how-proptech-is-changing-the-real-estate-game/)).
- **Method evidence.**
  - Nielsen Norman Group recommends five users per qualitative round, three to four per group when
    two groups overlap, at least 20 for quantitative measures, and more small rounds rather than
    bigger ones ([NN/g](https://nngroup.com/articles/how-many-test-users)).
  - A University of Washington and ITU Lahore study of mobile-money apps in Pakistan, with 118
    participants across phases, found that parallel audio helped users with lower literacy
    ([UW and ITU, 2017](https://dfs.cs.washington.edu/docs/research_briefs/smartphone_learnability_july2017.pdf)).
- **The overseas segment is large.** Remittances reached a record US$41.6bn in FY2025-26
  ([Tribune](https://tribune.com.pk/story/2617335/pm-shehbaz-hails-overseas-pakistanis-as-remittances-hit-416b-in-fy2025-26)).
  October 2026 inflows came mostly from Saudi Arabia, the UAE, the UK and the US
  ([Business Recorder](https://www.brecorder.com/news/40448227/pakistan-records-39bn-in-remittances-for-october-2026)).
- **Repository.**
  - The browser UAT covers 14 journeys from sign-up to account deletion, in English and Urdu
    ([uat.md](../../docs/uat.md)).
  - The app has no feedback entry point, no analytics and no feature flags; bug and feature issue
    forms exist ([ISSUE_TEMPLATE](../../.github/ISSUE_TEMPLATE/)).
  - The privacy notice promises no analytics, and its section on tenants' details tells landlords to
    record consent, but offers nothing a landlord can hand to a tenant
    ([privacy.md](../../website/src/content/pages/en/privacy.md)).
  - Caretaker cash handovers are confirmed or voided only by owners
    ([operations migration](../../supabase/migrations/20261103194151_operations.sql)), which is the
    trail an owner abroad relies on.
- **Channels, 11 November 2026.** There is no Play listing and no Apple membership; Android testers
  can install the release APK, and iPhone users can use only the web app
  ([download page](../../website/src/content/download/en.yaml),
  [operations.md](../../docs/operations.md), "iOS builds").

## Design

- **Size and mix.** 15 to 25 landlord accounts:
  - about 10 residents in Karachi, Lahore and Islamabad or Rawalpindi, some with 1 to 3 units and
    some with 4 to 15;
  - about 8 owners abroad, in the Gulf, the UK and North America, each with their caretaker in
    Pakistan;
  - at least 5 tenants who receive receipts;
  - a mix of Urdu-first and English-first users, on Android and iPhone.
- **Timing.** Recruit from late November; run from December 2026 to February 2027, so the January
  and February rent days fall inside it.
  - **Week 0:** moderated first-run sessions in Urdu, 5 resident and 5 overseas: sign up, add a
    property and a tenant, record a payment, send a receipt, invite a caretaker.
  - **Weeks 1 to 8:** real use, with a one-to-one check-in each week.
  - **Weeks 9 and 10:** exit interviews, a UMUX-Lite or SUS questionnaire, and the font and glossary
    check from [urdu-review](urdu-review.md).
- **Recruitment** through the owner's network, overseas Pakistani community groups and referrals
  from each pilot landlord. Screen for at least one let unit with monthly rent. Never recruit
  through estate agents, and cap the number from one family or network.
- **Channels.** TestFlight and a closed Play track when they exist; until then the release APK and
  the web app.
- **Consent.** A short bilingual consent form: what is recorded, that session recordings are
  optional, that findings improve the product, and how to withdraw and have data deleted. Landlords
  will enter real tenants' data, so the privacy notice and the model tenant notice from
  [legal-review](legal-review.md) must cover tenants before the pilot uses production.
- **Evidence without personal data.** Session notes, issues and screenshots never carry real names,
  CNICs or phone numbers; findings are paraphrased and filed with a severity.
- **Feedback.** A "Send feedback" entry in the app that opens an e-mail to the product mailbox with
  the app version, platform and language filled in, and nothing else. Crashes come from Play's
  pre-launch and vitals reports and TestFlight's crash reports.
- **Metrics from the database, not trackers.** SQL views that aggregate over a service-role-only
  list of pilot accounts, never readable by clients, and suppress any group smaller than five:
  - the activation funnel (account, portfolio, property and unit, tenant, tenancy, first charge,
    first payment, first receipt) and the time to the first receipt;
  - payments recorded per active tenancy per month, and the share of due rent recorded within seven
    days of the due date;
  - caretaker activity: who records payments, and how many handovers the owner confirmed;
  - still recording in the second rent cycle, and the language each account uses.
- **Incentives.** Free use through early access and a stated free period after [billing](billing.md)
  starts, plus a modest thank-you for each moderated session; no source on typical amounts in
  Pakistan was found.
- **A report** at the end: what to fix before the public launch, what to build next, and a go or
  no-go.

### Residence (decision 1)

Quotas follow declared residence, asked in the screener and, once the residence fields exist, in the
app's onboarding. Sessions are scheduled in the participant's own time: in December to February the
Gulf is 1 to 2 hours behind Pakistan, the UK 5 hours, and North America 10 to 13 hours. Each
overseas owner joins with their caretaker, so both sides of a cash handover are seen. If the
onboarding fork and dual times ship before round 2, round 2 tests them.

### Letterheads (decision 2)

If builder and image letterheads are ready during the pilot, owners try them, and tenants are asked
whether a letterheaded receipt changes how they see it.

### Analytics (decision 3)

The funnel comes from server-side aggregates of the pilot accounts' rows, and the consent form says
so. PostHog runs only for those who opt in, after the privacy notice has been rewritten; Intercom
only after support-chat consent, so support defaults to e-mail and the weekly check-in. There is no
session replay.

## Work

1. **S:** pilot plan, screener, consent form and session guide in both languages, and a runbook in
   `docs/` (to be created).
2. **S:** the in-app "Send feedback" entry, in both languages.
3. **S:** pilot metric views (a migration with pgTAP tests that clients cannot read them and that
   small groups are suppressed).
4. **Owner:** recruitment and onboarding through TestFlight, the closed Play track, or the APK and
   the web app.
5. **Owner + M:** two moderated rounds of 10 sessions; weekly triage of findings into issues and
   fixes.
6. **S:** the pilot report, with the go or no-go for the public launch.

## Depends on / Unblocks

- **Depends on:** [legal-review](legal-review.md) (a notice that covers tenants, and the consent
  form), [urdu-review](urdu-review.md) (the glossary before round 1), [play-store](play-store.md)
  and [app-store](app-store.md) for the store channels (the APK and web app are the fallback), and
  the residence fields and consent table from decisions 1 and 3.
- **Unblocks:** the public launch on [play-store](play-store.md) and [app-store](app-store.md), the
  readers' check of the font decided in [urdu-review](urdu-review.md), and the order of the assistant milestone, starting
  with [overseas-oversight](overseas-oversight.md).
- **Related:** [billing](billing.md), whose plans and prices the pilot informs without holding up
  its code.

## Risks

- **Overseas owners are slow to recruit and hard to schedule.** Start in late November, use a public
  TestFlight link, and offer evening and weekend slots in their time.
- **Caretakers are less comfortable with apps.** Onboard them in the same session as the owner, and
  note where audio or voice help would have helped.
- **Real tenant data from day one.** Use production only once the notice covers tenants; until then,
  run Week 0 on fictional data.
- **Enthusiasm inflated by a friendly sample.** Cap each network, measure behaviour from the views,
  and ask about what people did, not what they think.
- **A late start captures one rent cycle.** Recruit before December; if the start slips, extend the
  pilot past the milestone rather than judge on one cycle.
- **Ramadan 2027 is expected around early February** (not verified). Hold the exit interviews before
  it or after Eid.

## Done when

- [ ] At least 15 landlords are onboarded, at least 5 of them abroad with a caretaker.
- [ ] At least 10 moderated sessions have run in Urdu.
- [ ] The metric views cover two rent cycles, against a target the owner sets (an illustrative one:
      60% record rent in both cycles).
- [ ] Every finding is filed as an issue with a severity and no personal data.
- [ ] The pilot report, with its go or no-go, is in the repository.

## Questions for the owner

- What size and split: 15 to 25 landlords, about a third abroad?
- Which cities and countries?
- What incentives are acceptable?
- Who runs the Urdu sessions: you, or a hired researcher?
- Production with real data, or a separate pilot environment?
- Can recruitment start in late November?
