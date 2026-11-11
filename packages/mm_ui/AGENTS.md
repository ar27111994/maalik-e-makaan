# packages/mm_ui/AGENTS.md

The design system: tokens, light, dark and high-contrast themes, Latin and Nastaliq type, the
`MmIcons` font and the component library, with a gallery app in `example/`. The root
[`AGENTS.md`](../../AGENTS.md) rules apply; this file adds what is specific here.

Read first: [`DESIGN.md`](../../DESIGN.md) (the visual rules) and [`COMPONENTS.md`](COMPONENTS.md)
(how components are built and what exists). Design QA verdicts and open follow-ups:
[`docs/design-qa.md`](../../docs/design-qa.md).

## Where things are

| Path                                | What                                                                                                        |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `lib/src/tokens/`                   | `mm_tokens.g.dart`, generated from `design/tokens/maalik.tokens.json` by `make tokens`                      |
| `lib/src/icons/`                    | `mm_icons.g.dart`, generated with `assets/fonts/MmIcons.ttf` by `make icons`                                |
| `lib/src/theme/`                    | `MmTheme` (light, dark, high contrast), `MmMotion`, focus rings, `MmSemantics`                              |
| `lib/src/foundation/`               | Shared building blocks: `MmLicenses`, `MmIconSize`, `MmReflow`, `MmFitWords`, `MmUrduMaterialLocalizations` |
| `lib/src/components/<family>/`      | `actions`, `charts`, `choices`, `display`, `feedback`, `inputs`, `layout`, `records`                        |
| `lib/src/l10n/`                     | The package's own strings (`mm_localizations.dart`)                                                         |
| `assets/fonts/`                     | Atkinson Hyperlegible Next, Noto Nastaliq Urdu, `MmIcons.ttf`, and their licence texts                      |
| `test/support/harness.dart`         | `MmVariant` (six variants), golden and accessibility helpers                                                |
| `test/components/<family>/goldens/` | Golden images, `<name>_<variant>.png`                                                                       |
| `example/`                          | The gallery; `example/screenshots/` is the UAT record (English light, Urdu dark)                            |

## Rules here

- Never edit the `.g.dart` files or `MmIcons.ttf`: change `design/tokens/maalik.tokens.json` or
  `design/icons/icons.json` and run `make tokens` or `make icons` (icons need `npm ci`).
- Keep public APIs additive: the app depends on them, and its goldens catch visual leaks.
- Start and end, never left and right; status never by colour alone; 48 dp targets; text that
  reflows at 200% and never breaks inside an amount (`COMPONENTS.md`, Principles).
- Every component gets widget tests, goldens in all six variants and the accessibility checks
  from `test/support/harness.dart`, and a place on its family's gallery page.

## Commands

```sh
make test-ui                     # tests, goldens, accessibility; at least 95% line coverage
make test-gallery                # every gallery page in every theme, Urdu and 200% text
make goldens                     # re-record (also the app's); Linux only, review every image
make tokens tokens-check         # rebuild or check the token outputs
make icons icons-check           # rebuild or check the icon font and constants
make app-icons app-icons-check   # the app's launcher icons, after a change to primary, onPrimary or bg
cd packages/mm_ui/example && flutter run -d chrome   # the gallery
```
