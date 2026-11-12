# Design QA

Every surface people see — the design system (`packages/mm_ui`), the app and the
website — passes two kinds of design QA before it ships: automated gates on every
change, and a reviewed checklist when a surface is built or substantially changed.
The checklist follows the design-systems-engineering QA reference (scope, visual
quality, accessibility, interaction, content, data visualisation, token integrity
and delivery), applied to this product's constraints: English and Urdu (right to
left), phones first, WCAG 2.2 AA.

## Automated gates

These run in CI and, where fast enough, in the git hooks.

| Gate                              | What it catches                                                                                                                                 | Where                                                |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Token build and lint              | Invalid tokens, stale generated outputs, component colour pairs under 4.5:1, e-mail Urdu not in the tokens' type (Nastaliq beyond the wordmark) | `make tokens-check`                                  |
| `DESIGN.md` lint                  | An agent-facing design file that drifted from its schema                                                                                        | CI hygiene job                                       |
| Design lint                       | Colours, font sizes, spacing, radii and durations written in code instead of tokens; left/right geometry that breaks right to left              | `make design-lint` (`tool/design/lint_hardcoded.py`) |
| Accessibility guidelines in tests | Tap targets under 48 dp (Android) or 44 pt (iOS), unlabelled targets, text contrast, in every theme variant                                     | `packages/mm_ui/test/support/harness.dart`           |
| Golden tests                      | Visual regressions in light, dark, both high-contrast themes, Urdu and large text                                                               | `make test-ui`, `make test-app`                      |
| Icons                             | Icons that drifted from `design/icons/icons.json`                                                                                               | `make icons-check`                                   |
| App fonts                         | The app's Urdu fonts drifted from `design/fonts/` or from the Urdu `appName` the wordmark font holds                                            | `make fonts-check`                                   |
| App icons                         | Launcher icons that are damaged or drifted from the mark or the colour tokens, or a house that leaves the adaptive or maskable safe zone        | `make app-icons-check`                               |
| Website checks                    | WCAG violations (axe), Lighthouse scores under 95, broken links, bad structured data, missing glyphs, Nastaliq beyond the wordmark              | `make test-web`                                      |

## Review checklist

A reviewer works through each block, notes evidence (screenshots, golden files,
test output, file and line) and gives a verdict.

1. **Scope**: every requested component, page or screen exists, with all its
   states (default, hover, focus, pressed, disabled, loading, empty, error,
   success) and both languages.
2. **Visual quality**: hierarchy reads at a glance; spacing follows the scale;
   type is legible at the target size in Atkinson Hyperlegible Next and Noto
   Sans Arabic (on taller lines, so its dots and marks never touch); colour carries
   meaning, not decoration.
3. **Accessibility**: AA contrast in every theme; visible focus; targets of at
   least 48 dp; meaning never by colour alone (status pairs an icon or a word
   with its colour); reduced motion honoured; screen-reader labels and reading
   order correct in both directions; text scales to 200% without clipping.
4. **Interaction**: the main task is obvious; errors say what happened and how to
   recover; loading, empty, success and error states exist; destructive actions
   confirm.
5. **Content**: labels use landlords' words, not ours; amounts read as rupees
   with the chosen digit grouping; dates follow Pakistan conventions; Urdu reads
   naturally.
6. **Charts** (where present): the chart type fits the question; axes are
   honest; a text summary carries the takeaway for screen readers.
7. **Tokens**: no hard-coded values where a token exists; variants follow the
   system's conventions; generated outputs are current.
8. **Right to left**: layouts, icons that point, progress and swipe directions
   mirror; numbers, CNICs, phone numbers and IBANs stay left to right inside
   Urdu text.
9. **Delivery**: the gallery or screenshots show every state; known trade-offs
   and follow-ups are written down.

Verdicts: **PASS**, **PASS WITH NOTES** (usable; follow-ups recorded below) or
**BLOCKED** (a quality, accessibility or integrity problem that must be fixed
first).

## Verdicts

| Surface                  | Date       | Verdict         | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------ | ---------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Design system components | 2026-11-07 | PASS WITH NOTES | Independent design QA (PASS WITH NOTES); its 12 findings were fixed or answered: count badges sit past the icon's end edge in both directions; the Urdu date picker names its days in Urdu; label and value rows that reflow keep values on the end edge, so a card's figures share one edge; named bar groups keep every label (wrapped) or switch to the table; the date field takes its hover tint whole; the desktop page title starts on the reading column; checkboxes, radios, switches, chip checks and error-state icons grow to 150% with text; visible checkbox and radio glyphs start on the content edge; the Urdu money field's end alignment is documented; goldens load Material Icons; the gallery phone uses the national format; centred state text is balanced. 2,494 tests, 100% line coverage; gallery 84 tests, screenshots retaken.                                                                                                                                                         |
| Website                  | 2026-11-07 | PASS WITH NOTES | Two independent reviews (PASS WITH NOTES); their 32 findings were fixed or answered: Urdu numbers isolated from the bidi algorithm (with an e2e scan of every Urdu page), step numbers, header Tab order and phone header, home buttons that work before release, a fall in rent said in words, decimal-comma input, sources and wording in the guides. Open before launch: a native Urdu editor, a lawyer on privacy and terms, the official .gov.pk texts (unreachable here), one Urdu glossary shared with the app, and a home layout of its own.                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| App screens              | 2026-11-08 | PASS WITH NOTES | Two independent reviews of the app stage (PASS WITH NOTES); their 12 findings were fixed or answered: every button that starts deleting, voiding or ending a record is outlined red (a notification's "Delete" stays tertiary: it removes no record and asks nothing); the dashboard's overdue bar holds the four INS-01 buckets in four tones (`MmSegmentTone.overdueOlder`), with no split under it; a message of several lines in the other language, and a prose row, start every line at the start of their own direction (`reminder_other_language` goldens); a sentence whose only letters are isolated runs with the paragraph; badges and the receipt seal no longer lay their unshown words out wrapped, so the money badges and the seal take amounts and numbers as they are; document thumbnails are signed once per photo and again before they expire; the fonts' and icons' licences reach a licence page in Settings; the identity-checks migration locks its tables from its count to its commit. |

## Follow-ups

Website (from the D-19 change, 2026-11-12, measured but not yet independently reviewed):

- Urdu text moved to Noto Sans Arabic; Nastaliq sets only the header's wordmark. Measured on the
  built site: no two lines touch in 858 multi-line Urdu blocks at 320 px (713 at 390 px, 465 at
  1280 px); Urdu words sit within 1.25 px of the middle of buttons, section links, chips and the
  language switch; icons beside Urdu text are centred on its first line. A reviewer should look
  at the Urdu pages in both themes and at 200% text, and at the header's wordmark beside the
  mark.

App screens (from the 2026-11-08 reviews):

- `MmListTile` does not loosen an amount or a receipt number in its title or
  subtitle: the ledger's rows keep `wrappableAmount` and `breakableNumber`.
  An `MmListTile` option that does what `MmFitWords` does for badges would let
  the app drop them.
- With a chevron, a row's text column is narrower, so at 200% a subtitle date
  may wrap before its year ("Until 14 Nov" / "2099"). That is the date rule
  (the day stays with its month, the year may wrap, a number never breaks);
  letting the subtitle run under the chevron would give the width back.
- `MmButtonVariant.link` needs 16 dp of unclipped space on its start side for
  its focus ring (`COMPONENTS.md`); a clipping container would cut it.
- `MmIcons.ttf` still has empty copyright fields (`THIRD_PARTY_NOTICES.md`,
  Gaps, now lists only this one as open).

Design system components (from the 2026-11-07 review):

- Add a saved-phone display widget or formatter to `mm_ui` (additive, beside
  `MmCnicText`) so apps do not format phone numbers by hand; the gallery uses
  `PhoneNumber.national` for now.
- A native Urdu editor should confirm the date picker's Urdu day names and the
  money field's end-edge alignment in Urdu forms.
- At 200% text on a phone, a named bar chart that falls back to its table
  scrolls sideways and can cut a figure at the visible edge; consider wrapping
  the table's headers or stacking its columns.
- `MmUrduMaterialLocalizations` implements `MaterialLocalizations` member by
  member, so a Flutter upgrade that adds members needs it updated.
