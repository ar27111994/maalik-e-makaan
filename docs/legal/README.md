# Legal review pack

The papers we send to the Pakistani lawyer the owner will engage to review Maalik-e-Makaan's
privacy notice, terms and guides. It is work item 1 of
[legal-review](../roadmap/legal-review.md) (LR:123-125): "the review pack, with first drafts of the
privacy changes for decisions 1 to 3 in both languages, the data map and the question list".

> **This is not legal advice, and none of it is live.** The drafts are proposals for the lawyer to
> mark up. The live [privacy page](../../website/src/content/pages/en/privacy.md) and
> [terms](../../website/src/content/pages/en/terms.md) stay as they are until the lawyer approves
> new text and the features it describes ship. The live privacy page promises no analytics, and
> that stays true until then: no analytics SDK ships before the lawyer approves the new notice
> (LR:108-110; RM:327; the research's order of work at PJ:160-161, which this plan adopts). Once
> approved, each part of the new text is published with the feature it describes (the "Ships with"
> column of [the notice's table](privacy-notice.en.md#changes-from-the-live-notice)).

## Who it is for

- **The lawyer:** an advocate with data-law and rent-litigation experience, able to review Urdu
  (LR:65-68). The pack holds no real personal data (LR:67-68): the only contact detail in it is the
  company's public e-mail address from the live privacy page.
- **The owner of AR LABS (SMC-PRIVATE) LIMITED,** who settles the facts listed under
  [Before the pack goes out](#before-the-pack-goes-out) and answers the questions that are theirs.
- **Whoever changes the app or the website later,** who keeps the pack true
  ([below](#keeping-the-pack-current)).

## What is in it, and the order to read it

| #   | File                                                                                     | What it is                                                                                                                                                                                                                                                     |
| --- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | This README                                                                              | What the pack is, the status of each decision, how to return the mark-up                                                                                                                                                                                       |
| 2   | [data-map.md](data-map.md)                                                               | The data map: a one-page summary; every data class, where it is stored, who sees it, whether tenants see it, how long it stays, and the services that handle it, live and planned separately; a first draft of the store forms; and a draft retention schedule |
| 3   | [privacy-notice.en.md](privacy-notice.en.md)                                             | The whole proposed privacy page in English, then a table of every change from the live page with its reason and the feature it ships with                                                                                                                      |
| 4   | [website-copy.md](website-copy.md)                                                       | Proposed English and Urdu for every other place that makes a privacy promise: the FAQ, the footer, the page description, the READMEs                                                                                                                           |
| 5   | [terms-changes.en.md](terms-changes.en.md)                                               | Draft terms clauses for decisions 1 to 3: caretakers' authority, the owner's warranty for letterheads, and the messages we send                                                                                                                                |
| 6   | [questions.md](questions.md)                                                             | The questions for the lawyer, grouped, each with why it matters and what the drafts assume                                                                                                                                                                     |
| 7   | [privacy-notice.ur.md](privacy-notice.ur.md), [terms-changes.ur.md](terms-changes.ur.md) | The Urdu twins of files 3 and 5, with the words chosen for legal terms. The Urdu of file 4 is in that file                                                                                                                                                     |

The lawyer also reads, from the repository as it stands (LR:71-73):

- the live texts in both languages: the privacy page
  ([English](../../website/src/content/pages/en/privacy.md),
  [Urdu](../../website/src/content/pages/ur/privacy.md)), the terms
  ([English](../../website/src/content/pages/en/terms.md),
  [Urdu](../../website/src/content/pages/ur/terms.md)) and the FAQ
  ([English](../../website/src/content/faq/en.yaml), [Urdu](../../website/src/content/faq/ur.yaml));
- the four guides ([English](../../website/src/content/guides/en/),
  [Urdu](../../website/src/content/guides/ur/)), for the line-by-line fact-check, with their known
  open points in [F1](questions.md#guides);
- the tenant consent text in the app: "I told the tenant what details are kept and why" and "What
  they agreed to" ([`app_en.arb`](../../app/lib/l10n/arb/app_en.arb):2282-2299, and the Urdu in
  [`app_ur.arb`](../../app/lib/l10n/arb/app_ur.arb));
- the receipt and statement templates
  ([`ledger_pdfs.dart`](../../app/lib/src/features/ledger/presentation/pdf/ledger_pdfs.dart),
  [`report_pdfs.dart`](../../app/lib/src/features/insights/presentation/report_pdfs.dart)), with
  the letterhead design in RM:181-249. [To add: sample PDFs made from made-up data.]
- the [draft retention schedule](data-map.md#draft-retention-schedule) in the data map, built on
  the three classes in [retention](../roadmap/retention.md):58-99. Its default period is not decided
  (RM:452).

## Status of the three decisions

Decided by the owner on 11 November 2026, with details decided on 12 November 2026.

| Decision                                                                                                                                         | Decided                                                                                                                                               | Built                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Live |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| **1. Residence** (D-16): country and time zone per person; whether the owner lives abroad, and the caretaker, per portfolio                      | Yes (PJ:94-117): the caretaker is always a manager who uses the app; amounts stay in rupees; the owner-abroad question is asked with no answer chosen | The database (`public.profile_residences`, readable and writable only by its person; `owner_abroad`, `caretaker_user_id` and `caretaker_since` on portfolios; the `set_owner_abroad` and `set_caretaker` functions), the domain types and the app's data layer, in pull request [#61](https://github.com/ar27111994/maalik-e-makaan/pull/61) (PR #61's `.planning/STATE.md`:22-31): not merged, and not applied to the hosted project, which only the owner changes ([`docs/operations.md`](../operations.md#after-every-migration)). The screens, the privacy page and the data export are not built                                                              | No   |
| **2. Letterheads** (D-17): uploaded or built letterheads on every generated document                                                             | Yes (PJ:119-137): per portfolio, copyable to the owner's other portfolios, an optional Urdu letterhead, A5 (default) or A4 receipts, on every plan    | No: design only (RM:203-240)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | No   |
| **3. Privacy-first analytics, support and e-mail** (D-18): PostHog cookieless on the website and opt-in in the app; Intercom opt-in; Customer.io | Yes (PJ:139-163): the existing US accounts stay, and the notice names the US                                                                          | Maalik-e-Makaan's own PostHog project (730301) is set up, with recording, heatmaps, console logs, dead clicks, autocapture, web vitals and surveys off, client IP discarded and cookieless counting on (PJ:149-157). Customer.io's US workspace exists. No SDK, consent table or e-mail sync exists. Intercom's workspace region is not chosen (RM:321). Service e-mail tracking: Resend's click and open tracking are off (the owner's report, 12 November 2026: [`docs/release-readiness.md`](../release-readiness.md):338-341); Customer.io's open and click tracking are still to confirm before the notice's promise is published ([E6](questions.md#e-mail)) | No   |

## How the lawyer returns the mark-up

- **The texts.** Mark up the drafts in files 3 to 5 and their Urdu twins, in the format the
  engagement letter agrees (for example Word with tracked changes, made from these files, or
  comments on a PDF of them). Keep the clause and row numbers, so each change can be traced. Review
  each English text with its Urdu twin, since they must say the same thing and are published with
  one `lastUpdated` (LR:159-160, :171).
- **The square brackets.** Every `[Owner: …]`, `[Lawyer: …]` or `[To confirm: …]` in the drafts is
  open. Answer the `[Lawyer: …]` ones, or say what the text must say in each case.
- **The questions.** Answer each question in [questions.md](questions.md) by its number (R1, X2 and
  so on), or defer it with a reason (LR:167). The memo also says what changes when the Personal
  Data Protection Bill passes (LR:75-76).
- **The fixed deliverables** are listed in LR:74-85 and are not repeated here.
- **No real personal data** in the mark-up or its examples (LR:67-68).

We then apply the mark-up in pull requests, record each answer next to its question (answered, with
the date and the memo's reference, or deferred), and tick the Done-when list in LR:164-172.

## Before the pack goes out

Facts and choices the owner settles first. Most are not legal questions, but the drafts carry a
placeholder until each is settled.

- [ ] **PostHog project 730301** (read through PostHog's API on 12 November 2026; confirm in its
      settings):
  - [ ] set an events retention period; today the project keeps events for 84 months, and
        setting a period needs a paid plan, so record the organisation's plan
        ([A9](questions.md#analytics-and-consent));
  - [ ] decide whether the GeoIP step stays on; it is on, so opt-in app events would store city
        and country ([A5](questions.md#analytics-and-consent));
  - [ ] decide whether PostHog's AI data processing stays approved for the organisation
        ([X6](questions.md#transfers-and-regions));
  - [ ] generate and sign PostHog's DPA (RM:314);
  - [ ] decide whether the app's analytics wrapper removes the phone's time zone, language and
        mobile network, which PostHog's libraries add to every event
        ([A11](questions.md#analytics-and-consent));
  - [ ] after the website's rewrite is built, run RM:316's preview check that PostHog sees the
        visitor's IP address; if it does not, the notice and the FAQ say that only page views are
        counted ([A2](questions.md#analytics-and-consent)).
- [ ] **Intercom:** the workspace region, or a decision to leave support chat out of this review
      (RM:321, :449).
- [ ] **Customer.io:** what an e-mailed receipt carries ([E2](questions.md#e-mail)); whether
      message bodies are kept in delivery records ([E5](questions.md#e-mail)); whether tips and
      news count opens and clicks ([E4](questions.md#e-mail)); whether open and click tracking are
      off on transactional messages, since RM:294-296 turns off link tracking only
      ([E6](questions.md#e-mail)); its DPA.
- [x] **Resend's tracking:** click and open tracking on `news.ar27111994.dev` are off. The owner
      reported on 12 November 2026 that they had switched them off some days before
      ([`docs/release-readiness.md`](../release-readiness.md):338-341, Owner actions, item 5;
      [`.planning/STATE.md`](../../.planning/STATE.md):195-196), so the live "no trackers" promise
      holds for the e-mails Resend sends. The drafts' "We do not track whether you open these
      emails or click their links" (both languages) still waits for Customer.io's open and click
      tracking (the item above; [E6](questions.md#e-mail)).
- [ ] **Resend for Supabase Auth:** confirm that Supabase Auth sends its e-mails through Resend:
      reported done, not checked ([`.planning/STATE.md`](../../.planning/STATE.md):197-199).
- [ ] **Vercel:** the team's plan, and whether its DPA covers it ([X5](questions.md#transfers-and-regions)).
- [ ] **GitHub:** whether its DPA covers the account that runs the backups
      ([X2](questions.md#transfers-and-regions)).
- [x] **Supabase Auth:** what it keeps about each sign-in: the IP address of each session and
      sign-in log entries with the user agent (Supabase's own documentation;
      [data map](data-map.md#sources-for-the-live-rows), row 2).
- [ ] **Supabase Edge Functions:** where they run, since they send invitations and delete accounts
      ([X1](questions.md#transfers-and-regions); data map, gap 11).
- [ ] **The contact mailbox:** who receives mail for the address on the privacy page, in which
      country, and how long it keeps it (data map, row 20).
- [ ] **The weekly backup:** keep it as a workflow artefact of the public repository, which any
      signed-in GitHub user can download though only the owner's key opens it, or store it
      elsewhere (data map, row 18; [X3](questions.md#transfers-and-regions)).
- [ ] **Each service's retention:** Supabase's logs, Vercel's logs, Resend, Intercom and
      Customer.io ([D4](questions.md#retention-and-deletion)).
- [ ] **The processor role:** whether AR LABS accepts it for tenant data, and says so (LR:177;
      [R1](questions.md#roles)).
- [ ] **Staff access:** the rule for when AR LABS's staff may look at records
      ([R5](questions.md#roles)).
- [ ] **A personal data export:** build one, or do not promise it
      ([N1](questions.md#rights-breach-and-changes-to-the-notice)).
- [x] **The calculators with JavaScript off:** fixed by #62 (`fabc088`): the form uses
      `method="dialog"`, with a browser test, released in 1.1.1 (data map, gap 17).
- [x] **The Urdu drafts,** so both languages go together.
- [ ] **Which feature ships first,** and so which parts of the notice go live when (the "Ships
      with" column; LR:180, "Will any analytics run at launch?").
- [ ] **Sample receipts and statements** made from made-up data.

## Keeping the pack current

The pack is a description of the code, so it goes stale when the code changes. Until the lawyer's
review is closed (LR:164-172):

- **Who:** whoever makes the change, in the same pull request, as for any document the change makes
  wrong ([AGENTS.md](../../AGENTS.md), "Keep the documentation current").
- **When:** any change to
  - a service that handles personal data (added, removed, or its plan, terms or settings changed);
  - a region or country where data is stored or handled;
  - a data class: a new table or column holding personal data, who may see it, or how long it stays;
  - decisions 1 to 3 (D-16 to D-18 in [`PROJECT.md`](../../.planning/PROJECT.md)), or their design in
    [the roadmap](../roadmap/README.md);
  - the live privacy page, terms or FAQ.
- **What:** update the [data map](data-map.md) first, then the drafts and the questions it affects.
  New questions take the next free number in their group; numbers are never reused.
- **Versions:** each time the pack is sent, record the date and the commit in the list below, so
  the lawyer's mark-up can be matched to what they read. Changes made after a version is sent are
  listed under it, for the lawyer's next round.

Versions sent: none yet.

## Sources and conventions

- **Line numbers** are at commit `ae0112c` on `main`, which includes #62 (released in 1.1.1), #63
  and #65. The pack was first written against `7679373` (release 1.1.1); #63 and #65 moved lines
  in `.planning/STATE.md`, `docs/release-readiness.md`, `docs/operations.md` and the root
  `README.md`, so every citation into a file that changed between the two commits was checked
  again and re-pinned to `ae0112c`. The live privacy page's lines are the same as at `415ce29`.
  LR's lines are as this pack's pull request leaves them: it adds one line to LR's item 1
  (LR:123-125), so every later line is one more than at `ae0112c`. Lines in files that change
  later must be checked again before a version is sent.
- **Decision 1's code** is cited in pull request
  [#61](https://github.com/ar27111994/maalik-e-makaan/pull/61), not merged:
  `supabase/migrations/20261112092618_residence.sql` at commit `6608f1e`, called RES.
- **Short names:** PJ is [`.planning/PROJECT.md`](../../.planning/PROJECT.md), RM is
  [`docs/roadmap/README.md`](../roadmap/README.md), LR is
  [`docs/roadmap/legal-review.md`](../roadmap/legal-review.md), PEN and TEN are the live privacy page
  and terms in English.
- **Outside facts** are marked by how they were read. (primary): the vendor's own text, fetched from
  its public source on GitHub at a pinned commit, because the vendors' websites could not be
  reached from the research sessions. _(summary)_: read only through a search engine's summary, as
  in [legal-review](../roadmap/legal-review.md); confirm before relying on it. Facts about PostHog
  project 730301 were read through PostHog's API on 12 November 2026.
- **The local research notes** `tenancy_law_and_data.md` and `analytics_support_letterheads.md` are
  not in the repository; where a draft relies on one, it says so.
- **Writing:** British English in plain, short sentences. The Urdu follows the plain-Urdu rules and
  the glossary ([`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json)), and says
  exactly what the English says about amounts, dates, deadlines, warnings and legal effect.
