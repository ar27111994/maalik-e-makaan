# mm_ui

The **Maalik-e-Makaan** design system: tokens, themes, typography and the shared component
library. Read [`DESIGN.md`](../../DESIGN.md) for the rationale behind every visual decision.

Typefaces are bundled as variable fonts under the SIL Open Font License (see `assets/fonts/`):

- **Atkinson Hyperlegible Next** (Braille Institute). It keeps easily confused glyphs distinct
  (1/l/I, 0/O, 5/S), which matters in rupee amounts, CNICs, phone and receipt numbers.
- **Noto Nastaliq Urdu** (Google). The calligraphic Nastaliq style Urdu readers expect.

Icons are a subset of [Lucide](https://lucide.dev) (ISC licence, `assets/fonts/LICENSE-lucide.txt`),
built into `assets/fonts/MmIcons.ttf` from `design/icons/icons.json` by `make icons`; use them
through `MmIcons`. Colours, spacing, radii, motion and type come from
`design/tokens/maalik.tokens.json` through `make tokens` (`MmColorModes`, `MmSpace`, …).
