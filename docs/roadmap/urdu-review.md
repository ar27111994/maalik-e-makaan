# A native speaker's review of every Urdu string

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `urdu-review` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Many landlords, caretakers and tenants will read the app, the receipts and the reminders in Urdu. If
the Urdu is stiff, formal or wrong, they stop trusting the numbers beside it, and a receipt a tenant
cannot read easily is a poor receipt. A native editor's review, against one agreed glossary of
everyday words, makes the Urdu as plain and respectful as the English (NFR-03).

## What is true now

Facts marked _(summary)_ were read only through a search engine's summary.

- **The app.** [`app_ur.arb`](../../app/lib/l10n/arb/app_ur.arb) holds 1,523 strings, about 9,400 to
  10,000 words depending on whether placeholders and plural syntax are counted (11 November 2026).
- **The glossary.** In November 2026 the owner asked for everyday Urdu that ordinary landlords and
  tenants understand, with an English word in Urdu script where that is what people say (the
  security deposit is `سیکیورٹی`). The result is
  [`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json): 209 formal words and
  phrases to avoid, each with the plain word to write instead, the sentence rules and the words
  that stay.
  [`tool/check_urdu_words.py`](../../tool/check_urdu_words.py) fails `make lint` when an avoided
  word returns to any tracked file.
- **Other surfaces.** The website's Urdu content files hold about 5,800 words
  ([website/src/content](../../website/src/content/)), and there are three bilingual Auth e-mail
  templates ([supabase/templates](../../supabase/templates/)). No store listing text exists yet.
- **Who reviews.** The planning notes say the owner, a native speaker, reviews the app's and the
  website's Urdu with "one glossary for the app and the site"
  ([STATE.md](../../.planning/STATE.md)); NFR-03 stays open until then
  ([REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)).
- **Length matters on paper.** The browser UAT found the Urdu receipt spilling onto a second A5 page
  (D8, [uat.md](../../docs/uat.md)), and a voided Urdu receipt with tax withheld, a certificate and
  a note still takes two pages ([release-readiness.md](../../docs/release-readiness.md)). Longer
  wording can push more receipts over.
- **Font.** The UI's Urdu face was Noto Nastaliq Urdu
  ([mm_ui pubspec](../../packages/mm_ui/pubspec.yaml)). On 11 November 2026 the owner moved the
  interface to Noto Sans Arabic, keeping Nastaliq for the wordmark (decision D-19 in
  [PROJECT.md](../../.planning/PROJECT.md)), after seeing five candidates on the real screens.
  Developers report that Nastaliq needs much more
  vertical space
  ([ProAndroidDev](https://proandroiddev.com/taming-noto-nastaliq-fixing-urdu-font-rendering-issues-in-android-c65e83b40b34)),
  and the font has no ASCII digits
  ([language report](https://typosetting.linuxfromscratch.org/files/PDF-languages/NotoNastaliqUrdu-languages.pdf)).
  No controlled study comparing how fast Urdu readers read Nastaliq and Naskh on phones was found;
  the nearest is an Arabic eye-tracking thesis
  ([Leiden](https://scholarlypublications.universiteitleiden.nl/access/item%3A2937098/download)).
- **Style guides lean formal.** Microsoft's Urdu style guide makes formal terminology normative
  _(summary)_
  ([Microsoft](https://download.microsoft.com/download/d/a/0/da076f1d-0fc1-4336-9b9b-97159456bae9/urd-pak-StyleGuide.pdf));
  Mozilla's prefers Urdu names to English ones in many cases
  ([Mozilla](https://mozilla-l10n.github.io/styleguides/ur)). The owner's everyday-Urdu rule
  overrides both.
- **Cost.** Freelance Urdu editing is quoted at about US$0.01 to US$0.03 a word, and translation at
  US$0.05 to US$0.07, all self-reported _(summary for ProZ)_
  ([ProZ](https://www.proz.com/translator/3058922),
  [Upwork](https://www.upwork.com/services/product/writing-translation-translation-in-english-urdu-and-sindhi-1701522498367320064)).
  Editing the app's strings would therefore cost roughly US$100 to US$300, or US$470 to US$660 at
  translation rates (an inference from those quotes).

## Design

- **Glossary first, before an editor touches a string.** The glossary
  ([`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json)) gives each rejected word
  with the chosen Urdu, the English and a usage note. English loanwords stay where people actually
  say them, written in Urdu script. It settles, among others: the security deposit, advance rent
  and credit, a charge, due, overdue and arrears, void, delete and edit, the agreement, settings
  and the statement. The word for a portfolio is still the owner's to choose.
- **A style sheet in the same file.** Its `sentenceRules` cover `آپ` with plural verbs, short
  sentences in the active voice, buttons, error messages, empty states, messages to tenants and
  spelling. Still to settle there:
  - gender-neutral phrasing where Urdu allows;
  - Urdu punctuation (`۔ ، ؟`);
  - one choice of digits per surface, and `Rs` or `روپے` for amounts;
  - how English words, numbers and amounts sit inside right-to-left sentences;
  - Gregorian month and day names, as the date picker shows them.
- **Review in context.** `tool/l10n/export_review.py` (to be created) writes key, English, Urdu and
  the `@key` description, plus the website's English and Urdu pairs, to one CSV. The editor works
  from it beside screenshots from the design-system gallery and the store-screenshot harness in
  [app-icon](app-icon.md), so no string is judged alone.
- **The brief** tells the editor that the glossary overrides formal guides, that placeholders and
  ICU plurals must survive untouched, and that the readers include older landlords and tenants with
  little schooling. On legal texts the lawyer's meaning wins, and the editor only makes it readable.
- **A guardrail.** `tool/check_urdu_words.py`, run by `make lint` and so in CI, fails when a form
  the glossary avoids appears in any tracked file. Words that depend on meaning are left to review,
  and an official name that must keep a formal word is listed as an exception with its reason.
- **The font is decided; readers confirm it.** D-19 moved interface text to Noto Sans Arabic, with
  new line-height tokens and every Urdu golden re-recorded; Nastaliq stays for the wordmark. The
  [pilot](pilot.md) asks readers whether the new face reads easily and looks like Urdu to them; a
  clear "no" would reopen D-19.
- **A lighter review per milestone**, because every later item adds strings.

### Residence (decision 1)

New strings for the caretaker context ("Your caretaker recorded…", "Confirm the cash you received
from…", "while you are abroad"), the onboarding question about where the person lives, the
question asked when a portfolio is created ("Does the owner of these properties live abroad?"),
country and time-zone names and the dual time ("3:15 pm in Lahore (10:15 am in London)"). They
keep the respectful forms. Amounts stay in rupees at launch, so no label for a converted total is
needed (D-16).

### Letterheads (decision 2)

The builder's field labels, the upload checks and their bilingual error messages, the business
name in both scripts, the optional Urdu letterhead that the builder makes from the same details,
and the preview's warning when a letterhead's text becomes too small to read on an A5 receipt. The
"for and on behalf of the owner, through attorney" block comes from the lawyer and is only made
readable.

### Analytics (decision 3)

The consent screen and the Privacy settings switches, the rewritten privacy notice, the Customer.io
e-mail templates (right to left, amounts kept left to right) and an Urdu Help Center for support.
Intercom's own Messenger interface appears not to offer Urdu _(summary)_
([Fin FAQ](https://www.intercom.com/help/en/articles/7837535-fin-ai-agent-faqs)), so the Help Center
articles carry the Urdu.

## Work

1. **Owner + S:** glossary and style sheet in `contracts/urdu_glossary.json`, signed off by the
   owner.
2. **S:** the review export tool and its test.
3. **Owner:** shortlist three editors; a paid 300-word test (one screen, one receipt, one error
   message), judged for plainness and respect.
4. **M:** apply the corrections to the ARB files; re-record the Urdu goldens on Linux; check that
   the common Urdu receipt still fits one A5 page.
5. **M:** the website's Urdu, the e-mail templates and both store listings.
6. **S:** the glossary guardrail across every tracked file, `tool/check_urdu_words.py` in
   `make lint` (in place since November 2026).
7. **M:** the font change of D-19 (Noto Sans Arabic for interface text, Nastaliq for the wordmark,
   new line-height tokens, Urdu goldens re-recorded; in place since November 2026 in the app, the
   website, the pitch deck and the e-mails, whose Urdu type `make tokens` writes from the tokens);
   then a check with pilot readers.

## Depends on / Unblocks

- **Depends on:** owner time for the glossary, an external editor, and [pilot](pilot.md) readers to
  confirm the font.
- **Unblocks:** [play-store](play-store.md) and [app-store](app-store.md) (the Urdu listings),
  [legal-review](legal-review.md) (the Urdu legal texts go through the glossary), [pilot](pilot.md)
  (round 1 should start on reviewed Urdu), and [amount-parser](amount-parser.md), whose lexicon of
  Urdu number words follows the glossary.

## Risks

- **An editor "corrects" plain words back into formal ones.** The brief says the glossary overrides,
  and the paid test checks for it.
- **Strings reviewed out of context** get the wrong sense or gender. Always send the CSV with
  screenshots.
- **A sans face whose Urdu letters look foreign** to some Urdu readers. Ask pilot readers early, and
  keep the editor's view in the record.
- **Golden churn.** A font or wording change moves every Urdu golden; re-record on Linux and look at
  each image.
- **The English and Urdu legal texts drift apart.** Review them together, with one `lastUpdated`.

## Done when

- [ ] The glossary and style sheet are in the repository, signed off by the owner.
- [ ] Every Urdu surface (app, receipts and statements, website, e-mail templates, store listings)
      has been reviewed by a native editor and accepted by the owner.
- [ ] The guardrail test passes, and no rejected term remains.
- [ ] Placeholders and plurals pass the existing localisation tests.
- [ ] Nothing is clipped at 200% text size in the Urdu goldens, and the common Urdu receipt fits one
      A5 page.
- [ ] NFR-03 is marked done in `.planning/REQUIREMENTS.md`.

## Questions for the owner

- Western digits (123) or Urdu digits (۱۲۳) for amounts, dates and phone numbers, and the same on
  receipts?
- Which loanwords to accept beyond those the glossary takes (for example `بیلنس`)?
- Keep `پورٹ فولیو`, explained once where a portfolio is created and in the invitation e-mail, or
  rename it?
- Beyond the wordmark, keep Nastaliq anywhere else, such as large headings or letterheads?
- One editor for everything, or a second for the legal texts?
- Will you review yourself after the editor, or accept the editor's text with spot checks?
