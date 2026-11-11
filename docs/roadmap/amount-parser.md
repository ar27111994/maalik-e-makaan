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

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

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

- `parseAmount(text)` returns an amount, `ambiguous` or nothing. `parseMoneyInput` keeps its
  behaviour for form fields.
- `findAmounts(text)` returns candidate spans with offsets, anchored on currency markers or unit
  words, so a screen can highlight where an amount came from. It skips balances, transaction
  IDs, dates and phone numbers. A model may point at a span; the amount is always re-parsed from
  the original text.
- `formatAmountWords(money, locale)` writes the amount in English or Urdu words for the
  read-back, for example "پچیس ہزار روپے" beside "Rs 25,000".

**Shared vectors.** `contracts/amount_vectors.json` holds input, locale and expected paisa,
`ambiguous` or nothing. It is written by hand, as `clean_text.json` is, because the vectors are
the contract; `generate.py --check` validates their shape and bounds. Dart, a Deno port in
`supabase/functions/_shared` and the website's TypeScript mirror all run it. SQL needs no parser:
the database only checks `numeric(14,2)` bounds.

**Property tests.** `parse(formatWords(n)) == n` for random amounts up to the `numeric(14,2)`
maximum; the result does not change with digit script, grouping, spacing or direction marks;
never negative, never below a paisa, never above the maximum.

**Read-back widget.** A confirmation component shows the digits and the words together, in both
languages and right to left, for every screen that saves a parsed amount.

### Residence (decision 1)

Owners abroad may type "million" or "m". The recommendation: accept "million" and "mn"
everywhere; accept a bare "m" in a single amount field, as today, but treat it as `ambiguous`
in free text, where it may be a Roman Urdu word or minutes. Decisions 2 and 3 do not apply: the
parser makes no document and sends nothing anywhere.

## Work

1. **S:** the lexicon file: 0 to 99 in three scripts and their spellings, fractions,
   multipliers.
2. **Owner:** a native speaker reviews the lexicon and the fractional rules, within
   [urdu-review](urdu-review.md).
3. **S:** `amount_vectors.json`, with every example from the roadmap and the deck, and the
   harness for three runtimes in `generate.py --check`.
4. **M:** the Dart grammar, `parseAmount` and `formatAmountWords`, with property tests.
5. **M:** `findAmounts` with ambiguity handling, tested on synthetic bank and wallet SMS.
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

- [ ] All vectors pass in Dart, Deno and the website's TypeScript.
- [ ] 10,000 random amounts round-trip through words and back in both languages.
- [ ] Every example in the roadmap and the investor deck ("1.5 lac", "ڈیڑھ لاکھ", "پچاس ہزار",
      "50k", "Rs. 25,000/-") is a vector.
- [ ] Ambiguous inputs in the vectors return `ambiguous`, never a number.
- [ ] The parser uses no floating-point type.
- [ ] No screen saves a parsed amount without showing the read-back.

## Questions for the owner

1. Accept "million" and "m" as recommended above, or refuse them entirely?
2. Add Punjabi or Saraiki number words later, or keep tap-to-confirm for them?
