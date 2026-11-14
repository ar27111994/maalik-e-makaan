# A tested reader for amounts in Urdu numerals, lakh and crore, and Roman Urdu

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `amount-parser` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Pakistani landlords write and say amounts as "ڈیڑھ لاکھ", "pachas hazar", "2 lakh 50 hazar" or
"Rs. 25,000/-". A misread amount in a ledger is worse than no amount, because it looks right.
This item makes reading amounts deterministic and tested, the same in the app and on the server,
and always read back in words before anything is saved. Every feature that takes an amount from
a message or a voice note rests on it.

## What is true now

Checked on 11 November 2026, and updated on 14 November 2026 when work items 1, 3 and 4 were
done. External facts marked _(summary)_ were read only through search-engine summaries.

- **The lexicon exists and is not yet reviewed**
  ([`contracts/amount_lexicon.json`](../../contracts/amount_lexicon.json), version 1,
  `"reviewed": false`): 0 to 99 in Urdu script, Roman Urdu and English with their spelling
  variants, the five fraction words, the multipliers from سو to کھرب, rupee and paisa words,
  other currencies, `only`, the tokens refused in free text or everywhere, homographs and the
  spellings left out on purpose, each source it was drawn from, and `review.check_first`, the
  entries a native speaker should look at first. It was drafted from Unicode CLDR 49, two
  grammar pages and general knowledge; the dictionaries could not be reached. `generate.py
--check` refuses a copy in which a spelling has two meanings, a refused token has one, a
  fraction leaves part of a paisa or a spelling is not in normal form.
- **The vectors exist** ([`contracts/amount_vectors.json`](../../contracts/amount_vectors.json)):
  306 parse vectors (every example from this plan, the roadmap issue and the deck; digit scripts
  and separators; spacing and direction marks; spelling variants; each refusal; each attack the
  review round found; zero, a paisa, the maximum and one paisa above it) and 33 words vectors
  (eleven amounts in three scripts). `generate.py --check` validates their shape and bounds, that
  every promised example is a vector in both contexts and reads as the amount promised, and that
  every input passes the Unicode guard.
- **`parseAmount` and `formatAmountWords` exist in `mm_core`**
  ([amount_parse.dart](../../packages/mm_core/lib/src/money/amount_parse.dart),
  [amount_words.dart](../../packages/mm_core/lib/src/money/amount_words.dart)), reading the
  lexicon from a generated table (`amount_lexicon.g.dart`, written by `make contracts`), never
  from JSON at run time. They pass every vector; 10,000 random amounts round-trip through words
  in each of the three scripts, another 10,000 through digits in any script, grouping, spacing
  and direction marks, and 10,000 random token strings never give a negative amount, one above
  the maximum or an error, well within the CI budget. A run of a million digits is read in about
  a tenth of a second.
- **A review round** (14 November 2026) tried to make the parser give a wrong number. Each
  attack that worked is now a vector or a unit test that failed before the fix: see "As built".
- **Still to do:** the native-speaker review (work item 2), `findAmounts` (5), the TypeScript and
  Deno ports (6) and the read-back widget (7).

The facts below are as they were on 11 November 2026, before this work:

- **`parseMoneyInput` already reads typed amounts**
  ([money_parse.dart](../../packages/mm_core/lib/src/money/money_parse.dart)): currency markers
  (`Rs`, `Rs.`, `PKR`, `₨`, `rupees`, `روپے`, `روپیہ`, a trailing `/-`), any digit grouping,
  Urdu and Arabic-Indic digits ([digits.dart](../../packages/mm_core/lib/src/text/digits.dart)),
  `٫` and `٬`, and one trailing unit word (`hazar`, `lakh`, `crore`, `arab`, `million`, `k`,
  `m` and their spellings). It ignores direction marks, rounds half up to the paisa and uses
  integers, not floating point. The website has a TypeScript mirror
  ([parse.ts](../../website/src/lib/money/parse.ts)).
- **It cannot read** number words ("پچاس ہزار", "pachas hazar"), fractional words (ڈیڑھ, dhai,
  sawa, sarhe, paune), compound amounts ("2 lakh 50 hazar") or an amount inside free text.
- **No amount vectors exist.** [`contracts/`](../../contracts/) holds `clean_text.json`,
  `identity_vectors.json` and `rent_math_vectors.json`, checked in CI by
  [`generate.py --check`](../../tool/contracts/generate.py).
- **The Edge Functions have no money parser** ([`_shared`](../../supabase/functions/_shared/)),
  which the WhatsApp assistant will need.
- **The product already promises this:** "No amount from model text alone. Urdu numerals, lakh
  and crore, and Roman Urdu are parsed by tested code, then read back"
  ([agent-safety slide](../../website/deck/slides/agentsafe.html)); Punjabi and Saraiki fall back
  to tap-to-confirm ([agents slide](../../website/deck/slides/agents.html)).
- **The numbers 1 to 99 in Hindustani are "nearly all irregular"**, so each is a word to list,
  not a rule _(summary)_ ([Wikipedia](https://en.wikipedia.org/wiki/Hindustani_numerals)).
- **No words-to-number library was found;** existing packages convert numbers to Urdu words,
  not the other way _(summary)_ ([urdu-number-words](https://www.pkgstats.com/pkg:urdu-number-words)).

## Design

**A reviewed lexicon, not a model.** `contracts/amount_lexicon.json` lists the numbers 0 to 99
in Urdu script, Roman Urdu spellings and English; the fractional words; the multipliers (سو
sau 10², ہزار hazar 10³, لاکھ lakh 10⁵, million 10⁶, کروڑ crore 10⁷, ارب arab 10⁹); and the
currency markers. A native speaker reviews it in [urdu-review](urdu-review.md); the fractional
rules below come from general knowledge until then.

**Tokenise, then evaluate.** After digit normalisation, direction-mark removal and lower-casing,
the text becomes numbers, fractional prefixes, multipliers and currency markers. An amount is a
sum of groups, each a quantity times a multiplier, in strictly descending order, computed in
exact integer paisa:

| Input                 | Rupees  |
| --------------------- | ------- |
| ek lakh pachas hazar  | 150,000 |
| 2 lakh 50 hazar       | 250,000 |
| pachees sau           | 2,500   |
| ڈیڑھ لاکھ             | 150,000 |
| sawa do lakh (+¼)     | 225,000 |
| sarhe teen hazar (+½) | 3,500   |
| paune do lakh (−¼)    | 175,000 |

A quantity before a large multiplier may itself be a compound ("ek sau pachas crore").

**Refuse rather than guess.** Groups that do not descend, two numbers with no multiplier between
them, or a bare `m` that could be a word all return `ambiguous`, never a number.

**Three entry points in `mm_core`.**

- `parseAmount(text, context:)` returns an amount (`AmountFound`), `ambiguous`
  (`AmountAmbiguous`, with the reason) or nothing (`AmountNotFound`, with the reason).
  `context` is `field` (a single amount field) or `text` (free text, the default, which refuses
  words with a second everyday meaning). `parseMoneyInput` keeps its behaviour for form fields.
- `findAmounts(text)` returns candidate spans with offsets, anchored on currency markers or unit
  words, so a screen can highlight where an amount came from. It skips balances, transaction
  IDs, dates and phone numbers. A model may point at a span; the amount is always re-parsed from
  the original text.
- `formatAmountWords(money, script)` writes the amount in Urdu script, Roman Urdu or British
  English words for the read-back, for example "پچیس ہزار روپے" beside "Rs 25,000". Urdu and
  Roman Urdu use lakh and crore; English uses thousands and millions, with "and" before the last
  number. It writes no fraction words, so its words are never ambiguous.

**As built (14 November 2026).** The grammar follows this design, with these rules made exact:

- The whole text must be one amount, with rupee markers and `only` around it. The highest
  multiplier must be the only one of its power; its quantity is everything before it and the
  rest must be less than one of it. So there is at most one reading, and `pachas hazar do lakh`
  has none.
- Inside a quantity, a group with more after it must be hundreds from one to nine
  (`ek sau pachas crore`, `one hundred and fifty thousand`); a single group may stand alone
  (`teen hazar crore`, `lakh crore`). `pachas hazar do lakh` and `do hazar do lakh` are
  ambiguous.
- After a group, the rest must start with a number. A multiplier there would stand for an
  implied one, so `5 hazar sau` and `5 crore sau hazar` are ambiguous, not 5 crore and 1 lakh;
  `5 crore ek sau hazar` is read. On its own, `sau hazar` is still 100,000 in a field.
- A fraction or a decimal quantity must be the whole amount, followed only by multipliers in
  rising order (`sawa do lakh`, `1.5 lac`, `derh sau hazar`); with any other group it is
  ambiguous, since the fraction could cover the rest or not.
- Paise are read only at the end, after a rupee marker and a number from 1 to 99 (`pachas
rupay bees paise`); the lexicon's `paisa` section says so, and elsewhere the paisa words still
  mean "money" and make the amount ambiguous. More than two decimal places with no multiplier
  (`1.500`) is ambiguous, since it may be a thousands separator.
- A multiplier with no number is read as one only at the start, never for a one- or two-letter
  abbreviation (`k`, `m`, `mn`, `cr`), and in free text only beside a rupee marker
  (`lakh rupay`).
- **A dropped lower unit is ambiguous.** People often leave out the next unit down: "ek lakh
  bees" and "1 lakh 20" usually mean 1,20,000, "1 crore 20" 1.2 crore. So a lakh, million, crore,
  arab or kharab followed only by a number that would fit the next unit down (below 100 for lakh,
  crore and kharab; below 1,000 for million and for arab or billion, which share a power) is
  `ambiguous` (`elidedMultiplier`); "ek lakh 500" is read as 100,500, and "do lakh pachas hazar"
  as 250,000. A rupee word straight after the number pins it as rupees: "ek lakh bees rupay" is
  100,020, which is how `formatAmountWords` writes that amount, so its words still read back.
  The reviewer is asked to confirm this, and whether hazar needs the same rule ("do hazar
  paanch": 2,005 or 2,500).
- In free text, `do` and `دو` are read after a fraction word (`sawa do lakh`), or after `Rs`,
  `PKR` or `₨` when a multiplier follows (`Rs do hazar`), where "give" cannot be meant; `سوا` is
  read after those signs too. A rupee word does not cue them, and nor does a sign with no
  multiplier after it: "rupay do", "روپے دو" and "rs do" mean "give the money". The lexicon's
  `read_after` lists the cue, and its `currency.markers` the signs.
- At the start of free text, `do`, `دو`, `سوا` and the other words with a second meaning are
  still refused ("do hazar rupay"), on purpose: `parseAmount` also reads spans cut out of a longer
  message, where "bhej" may come just before the span. This costs some readings and is safe.
- `mn` and `bn` are read like `k`: joined to digits anywhere (`5mn`, `2bn`), spaced only in a
  field, since in chat they also spell main or mein and ban ("50 hazar mn" is not 50 billion).
  "nawasi" and "نواسی" (also "granddaughter") are refused in free text, as "انیس" is.
- In a field, `cr` after two decimal places or with a rupee marker before the amount
  (`Rs 25,000.00 Cr`, a pasted bank line's "credit") is ambiguous; `2.5 cr` is read.
- A fraction prefix before a digit number of 100 or more is ambiguous: a voice-note transcript
  writes "sawa sau hazar" (125,000) as "sawa 100 hazar".
- Western and South Asian multipliers may be combined when the groups descend ("1 million 5
  lakh" is 1,500,000, "1 crore 1 million" 11,000,000, "5 sau k" in a field 500,000); the vectors
  pin these sums. The same amount said in both systems ("ek million das lakh", "1 crore 10
  million") is refused, because the second group is not less than one of the first.
- Zero is read only as the whole rupee amount: on its own, or as sifar or صفر rupees before
  paise (`sifar rupay pachas paise`); a zero inside an amount (`ek hazar sifar`) is ambiguous.
  Leading zeros are ambiguous in free text (`0300`), and a first digit group of zero (`0,500`,
  more likely a decimal comma) everywhere.
- The direction marks and joiners, and the invisible characters that copying from chat apps and
  right-to-left text carries (zero-width space, word joiner, soft hyphen, the byte-order mark,
  the bidi embeddings, overrides and isolates), are removed before reading; the full-width comma
  and full stop are read as `,` and `.`; `/=` after an amount is read as `/-` is.
- A hyphen joined to a rupee marker (`Rs-500`) is ambiguous, not negative, so the amount is shown
  to the person instead of dropped. A trailing full stop (`Rs 500.`) stays ambiguous: in a field
  it may be a decimal still being typed.
- Every number is read exactly, and no digit run costs more than a short one. Leading zeros of
  the whole part and trailing zeros of the decimals are skipped without parsing; what is left is
  parsed in full, never cut short or stood in for, within a bound that keeps it short. A whole
  part of more than 14 digits is out of range wherever it stands (even as paise, 10^14 paisa is
  above the maximum), and a number with more than 45 decimal places is below a paisa, because
  45 is two plus the powers of every multiplier, and a decimal takes each power at most once
  (`0.000…01 sau hazar lakh million crore billion کھرب`, with 45 places, is one paisa). Inside
  the bound a number has at most 59 digits, so `9` repeated a million times is out of range in
  about a tenth of a second, not 40. An earlier version kept the first 14 decimal places and
  stood a 1 in for the rest, which read `0.0000000000000001 sau hazar lakh crore` (Rs 10) as
  Rs 100; the vectors pin it.

**Shared vectors.** `contracts/amount_vectors.json` holds input, context (`field` or `text`) and
expected paisa, `ambiguous` or nothing, and the words `formatAmountWords` writes for some
amounts. It is written by hand, as `clean_text.json` is, because the vectors are the contract;
`generate.py --check` validates their shape and bounds. Dart runs it today; the Deno port in
`supabase/functions/_shared` and the website's TypeScript mirror will run it with work item 6.
SQL needs no parser: the database only checks `numeric(14,2)` bounds.

**Property tests.** `parse(formatWords(n)) == n` for random amounts up to the `numeric(14,2)`
maximum; the result does not change with digit script, grouping, spacing or direction marks;
never negative, never below a paisa, never above the maximum.

**Read-back widget.** A confirmation component shows the digits and the words together, in both
languages and right to left, for every screen that saves a parsed amount.

### Residence (decision 1)

Owners abroad may type "million" or "m". The recommendation: accept "million" and "mn"
everywhere; accept a bare "m" in a single amount field, as today, but treat it as `ambiguous`
in free text, where it may be a Roman Urdu word or minutes. **Built as recommended** on
14 November 2026 (`AmountContext.field` reads `5m` and `5 m`, `AmountContext.text` refuses them;
`million` and `billion` are read in both), pending the owner's answer to question 1. The review
round found that `mn` and `bn` also have chat meanings (main or mein, and ban), so they are read
as `k` is: joined to digits in both contexts (`5mn`), spaced only in a field.
Decisions 2 and 3 do not apply: the parser makes no document and sends nothing anywhere.

## Work

1. **S, done 14 November 2026:** the lexicon file: 0 to 99 in three scripts and their
   spellings, fractions, multipliers. Not yet reviewed; its `review.check_first` lists what a
   reviewer should look at first: the fraction rules, sarhe misspelt as sare, the paisa rule, the
   Urdu spelling variants where the sources disagree, the first Roman spelling of each irregular
   number, the collisions refused in free text, the large multipliers, the currency words, `aur`
   between groups and `do` after a cue.
2. **Owner:** a native speaker reviews the lexicon and the fractional rules, within
   [urdu-review](urdu-review.md).
3. **S, done 14 November 2026:** `amount_vectors.json`, with every example from the roadmap and
   the deck, and its checks in `generate.py --check`. The Deno and website runners come with
   work item 6.
4. **M, done 14 November 2026:** the Dart grammar, `parseAmount` and `formatAmountWords`, with
   property tests.
5. **M:** `findAmounts` with ambiguity handling, tested on synthetic bank and wallet SMS. Note:
   `formatAmountWords` output reads back in a field for every script, but in free text the Roman
   words with `arab` and the English words with `and` are refused (both have a second meaning),
   so the read-back words are not free-text input; and a span must keep the words before it, or
   the start-of-span refusal of `do` stays.
6. **M:** the TypeScript port for Edge Functions and the website mirror; Deno and website
   contract tests.
7. **S:** the read-back widget, with goldens in all six variants.

## Depends on / Unblocks

- **Depends on:** the lexicon review in [urdu-review](urdu-review.md). Work items 1, 3 and 4 can
  start before it.
- **Unblocks:** [draft-payments](draft-payments.md) (hard),
  [whatsapp-assistant](whatsapp-assistant.md) and [reconciliation](reconciliation.md).

## Risks

- **Silent misreads**, such as "sawa" applied to the wrong group. Mitigation: return
  `ambiguous` whenever two readings are possible, and always read back.
- **Dart and TypeScript drift apart.** Mitigation: one vector file, run in CI by every runtime.
- **Roman Urdu spelling varies** by region and person. Mitigation: grow the spelling table from
  pilot feedback, each addition with a vector.
- **"m" read as minutes, "k" confused with lakh.** Mitigation: the free-text rule above, and
  vectors for each confusion.
- **Vectors with hidden characters.** Mitigation: the Unicode guard runs on `contracts/`; only
  the direction marks it allows may appear.

## Done when

- [ ] All vectors pass in Dart, Deno and the website's TypeScript. (Dart: yes.)
- [x] 10,000 random amounts round-trip through words and back in both languages (and in
      English).
- [x] Every example in the roadmap and the investor deck ("1.5 lac", "ڈیڑھ لاکھ", "پچاس ہزار",
      "50k", "Rs. 25,000/-") is a vector.
- [x] Ambiguous inputs in the vectors return `ambiguous`, never a number.
- [x] The parser uses no floating-point type.
- [ ] No screen saves a parsed amount without showing the read-back.

## Questions for the owner

1. Accept "million" and "m" as recommended above, or refuse them entirely? Built as recommended
   until you answer, with "mn" and "bn" read like "k" (joined to digits anywhere, spaced only in a
   field), since in chat they also spell main or mein and ban.
2. Add Punjabi or Saraiki number words later, or keep tap-to-confirm for them?
