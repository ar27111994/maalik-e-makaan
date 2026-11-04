# mm_ui components

How the component library is built, and what is in it. Read `DESIGN.md` at the repository root
first: it is the source of the visual rules this file turns into code conventions.

## Principles

- **The raseed book.** Paper and ink: flat surfaces separated by tone, spacing and hairline rules;
  shadows only on true overlays (sheets, dialogs, menus, the floating action button). Cobalt for
  the one main action, ink for reading, brass at most once per screen and only through
  `context.mm.colors.brass`.
- **Status is never colour alone.** Every status carries an icon and a word.
- **Mirrors for Urdu.** Start and end, never left and right: `EdgeInsetsDirectional`,
  `AlignmentDirectional`, `BorderRadiusDirectional`, `PositionedDirectional`. Icons that point
  mirror (the `MmIcons` constants already set `matchTextDirection`). Amounts keep Western digit
  order in both languages.
- **Text scales to 200%.** Layouts reflow and wrap. Nothing truncates a name or an amount
  silently, and a rupee amount never breaks inside its number.
- **Touch targets of 48 dp**, visible focus, complete states: default, hover, focus, pressed,
  disabled, plus busy, error and success where they apply.

## Code conventions

- **Names.** Every public widget starts with `Mm`; one widget per file, named after it in
  snake case (`MmStatusBadge` lives in `mm_status_badge.dart`). Supporting enums and value
  types live in the file of the widget that owns them.
- **Layout.** Components live in `lib/src/components/<family>/`. Each family has a barrel,
  `lib/src/components/<family>/<family>.dart`, that exports its public files; `lib/mm_ui.dart`
  exports the barrels.
- **Constructors.** This Dart version declares constructors with `new` (`const new({...})`,
  `const new _()`, `factory from()`); the analyzer flags the old `ClassName()` form. Pass
  `super.key` in every widget constructor.
- **Callbacks.** A `null` callback means disabled (`onPressed: null`), as in Material.
- **Words.** A component never hard-codes text a user sees or hears. Text about the landlord's
  data (labels, messages, status words) is a constructor parameter that the app fills from its
  own localisations. Words a component adds by itself (retry, close, show password, loading)
  come from `MmLocalizations.of(context)`. If a component needs a built-in word that
  `MmLocalizations` lacks, take it as a required parameter instead of adding one.
- **Tokens only.** Colours from `context.mm.colors` (`MmColorTokens`) or the theme's
  `ColorScheme`; spacing from `MmSpace`; radii from `MmRadius`; sizes from `MmSize`; durations
  from `MmDuration` through `MmMotion.of(context, …)`, which is zero when the platform asks for
  reduced motion; curves from `MmEasing`. No literal colours, and no literal sizes where a
  token exists.
- **Type.** Text styles come from `Theme.of(context).textTheme`. Amounts use
  `context.mm.amount` or `context.mm.amountLarge` (Latin face, tabular figures, in both
  languages). User data that may be in Latin script (a name typed in English, a CNIC, a phone
  number) goes through `context.mm.styleFor(text, style)` so the Urdu UI sets it in Atkinson.
- **Money.** Amounts are `Money` from `mm_core`, formatted with `MmFormats.moneyOf(context)`
  (the app sets Western or lakh/crore grouping once). Screen readers get the plain number and
  `MmLocalizations.rupees` ("125000 rupees"), because grouped figures are read out unreliably.
- **Semantics.** Buttons are buttons, headers are headers (`Semantics(header: true)`), a tile is
  one merged node (`MergeSemantics`), decorative parts are excluded (`ExcludeSemantics`), errors
  and snackbars are live regions, and icon-only controls have a tooltip that is also their
  label. Values that look different from how they read (masked CNIC, amounts, gauges) carry an
  explicit `Semantics(label: …, value: …)`.
- **Documentation.** Every public member has a dartdoc comment (`public_member_api_docs` is on).
  A widget's class comment says when to use it, when not to, and shows a short example.
- **Analysis.** `very_good_analysis` with `--fatal-infos`: no ignores, no `// ignore:`
  comments.

## Testing conventions

- Behaviour tests: `test/components/<family>/<name>_test.dart`. Cover every parameter, state
  and callback, keyboard activation and focus, semantics (labels, flags, actions), text scale
  200% on a 320 dp wide surface without overflow, and right-to-left layout. Use
  `testEveryVariant` from `test/support/harness.dart` where a behaviour must hold in every theme
  and language.
- Golden tests: `test/components/<family>/<name>_golden_test.dart`, tagged `@Tags(['golden'])`,
  using `goldenEveryVariant(name, build)`. It pumps the widget in all six variants (light, dark,
  light and dark high contrast, Urdu right to left, English at 200% text), runs
  `expectAccessible` (tap targets, labels, text contrast) and compares
  `goldens/<name>_<variant>.png`. A golden shows the component's states side by side in one
  compact composition, so each image is reviewable at a glance.
- Fonts are real (`test/flutter_test_config.dart` loads Atkinson, Nastaliq and MmIcons), so
  goldens show the true rendering. Look at every golden you record.
- Run `flutter test --no-pub <paths>` (several packages share the workspace lockfile) and
  `dart analyze --fatal-infos <paths>`.
- Coverage: every line of `lib/src/components` is exercised.

## Families

| Family     | Components                                                                                                                           |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `actions`  | `MmButton`, `MmIconButton`, `MmFab`, `MmSegmentedControl`                                                                            |
| `inputs`   | `MmTextField`, `MmPasswordField`, `MmMoneyField`, `MmCnicField`, `MmPhoneField`                                                      |
| `choices`  | `MmDateField`, `MmSelectField`, `MmSwitchTile`, `MmCheckboxTile`, `MmRadioGroup`, `MmSearchField`, `MmFilterChips`, `MmStepperField` |
| `display`  | `MmCard`, `MmListTile`, `MmStatusBadge`, `MmAmount`, `MmStatTile`, `MmAvatar`, `MmSectionHeader`, `MmDetailRow`                      |
| `records`  | `MmMeter`, `MmTimeline`, `MmReceipt`, `MmNameplate`, `MmScoreGauge`                                                                  |
| `feedback` | `MmEmptyState`, `MmErrorState`, `MmSkeleton`, `MmBanner`, `showMmSnackbar`, `showMmConfirmDialog`, `showMmSheet`                     |
| `layout`   | `MmAdaptiveScaffold`, `MmPage`, `MmListDetail`, `MmResponsiveGrid`, `MmFormSection`, `MmActionBar`, `MmTabs`                         |
| `charts`   | `MmBarChart`, `MmProportionBar`, `MmSparkline`, `MmDataTable`                                                                        |

The gallery app in `example/` shows every component in every variant.
