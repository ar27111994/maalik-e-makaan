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

| Gate                              | What it catches                                                                                                                    | Where                                                |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Token build and lint              | Invalid tokens, stale generated outputs, component colour pairs under 4.5:1                                                        | `make tokens-check`                                  |
| `DESIGN.md` lint                  | An agent-facing design file that drifted from its schema                                                                           | CI hygiene job                                       |
| Design lint                       | Colours, font sizes, spacing, radii and durations written in code instead of tokens; left/right geometry that breaks right to left | `make design-lint` (`tool/design/lint_hardcoded.py`) |
| Accessibility guidelines in tests | Tap targets under 48 dp (Android) or 44 pt (iOS), unlabelled targets, text contrast, in every theme variant                        | `packages/mm_ui/test/support/harness.dart`           |
| Golden tests                      | Visual regressions in light, dark, both high-contrast themes, Urdu and large text                                                  | `make test-ui`, `make test-app`                      |
| Icons                             | Icons that drifted from `design/icons/icons.json`                                                                                  | `make icons-check`                                   |
| Website checks                    | WCAG violations (axe), Lighthouse scores under 95, broken links, invalid structured data                                           | `make test-web`                                      |

## Review checklist

A reviewer works through each block, notes evidence (screenshots, golden files,
test output, file and line) and gives a verdict.

1. **Scope**: every requested component, page or screen exists, with all its
   states (default, hover, focus, pressed, disabled, loading, empty, error,
   success) and both languages.
2. **Visual quality**: hierarchy reads at a glance; spacing follows the scale;
   type is legible at the target size in Atkinson Hyperlegible Next and Noto
   Nastaliq Urdu (whose tall ascenders need more line height); colour carries
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

| Surface                  | Date | Verdict | Notes                                                 |
| ------------------------ | ---- | ------- | ----------------------------------------------------- |
| Design system components |      | pending | Review runs when the component families are complete. |
| Website                  |      | pending | Review runs when the site is built.                   |
| App screens              |      | pending | Reviewed per feature as screens land.                 |
