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
- **Focus rings come from the theme.** Outlined and text buttons, segmented buttons, chips and
  fields draw a `MmSize.focusRing` ring in `colors.focus` on their edge. Filled, elevated and
  icon buttons and the floating action button draw it outside themselves, past
  `MmSize.focusGap` (`MmFocusRingBorder`), because on their edge it would be the colour of the
  fill. A component that gives a filled control its own `shape` keeps the ring with
  `MmFocusRingBorder.whenFocused(shape, color: colors.focus)`; leave 4 dp around filled
  controls so neighbours and clips do not cover the ring. A component that draws its own ring
  (a tile, a card, a field-like box) draws it only for keyboard focus: `MmFocusHighlight` tells
  its state when, and `MmFocusWithin` rings a row whose control has focus.
- **Disabled is muted ink.** The theme's disabled buttons use `inkMuted` for text and icons;
  filled and elevated ones sit on `surfaceSunken` inside a `rule` border, like a disabled
  outlined button.

## Code conventions

- **Names.** Every public widget starts with `Mm`; one widget per file, named after it in
  snake case (`MmStatusBadge` lives in `mm_status_badge.dart`). Supporting enums and value
  types live in the file of the widget that owns them.
- **Layout.** Components live in `lib/src/components/<family>/`. Each family has a barrel,
  `lib/src/components/<family>/<family>.dart`, that exports its public files; `lib/mm_ui.dart`
  exports the barrels.
- **Families never import each other.** A family imports only its own files and the shared
  layers: `lib/src/foundation/`, the theme, tokens, icons and `MmLocalizations`. What two
  families need goes into `lib/src/foundation/` (internal unless `lib/mm_ui.dart` exports it),
  never into one family for another to borrow:
  - `MmFormats` (money format, `spokenNumber`, `spokenMoney`) and `MmCleanTextFormatter`
    (public);
  - `MmFocusHighlight` (draw focus only for the keyboard) and `MmFocusWithin` (ring a row);
  - `MmReflow` (a label or title and its value side by side, the value moving under it when they
    do not fit; a below line; centre, baseline or top alignment; stacked at either edge);
  - `MmIconLabel` (an icon and words in one paragraph, the icon growing at most 150%);
  - `MmFieldLabel` (a field's label with "Required" or "Optional") and `MmFieldError` (its error
    line);
  - `MmButtonStyles` (what labelled buttons add to the theme: room for wrapped labels, the icon
    size, the destructive colours).
- **Constructors.** This Dart version declares constructors with `new` (`const new({...})`,
  `const new _()`, `factory from()`); the analyzer flags the old `ClassName()` form. Pass
  `super.key` in every widget constructor.
- **Callbacks.** A `null` callback means disabled (`onPressed: null`), as in Material.
- **Words.** A component never hard-codes text a user sees or hears. Text about the landlord's
  data (labels, messages, status words) is a constructor parameter that the app fills from its
  own localisations. Words a component adds by itself (retry, close, show password, loading,
  "No matches", the spoken "7 hidden digits" of a masked CNIC) come from
  `MmLocalizations.of(context)`. If a component needs a built-in word that `MmLocalizations`
  lacks, take it as a required parameter instead of adding one, and report it.
- **Tokens only.** Colours from `context.mm.colors` (`MmColorTokens`) or the theme's
  `ColorScheme`; spacing from `MmSpace`; radii from `MmRadius`; sizes from `MmSize`; durations
  from `MmDuration` through `MmMotion.of(context, …)`, which is zero when the platform asks for
  reduced motion; curves from `MmEasing`. No literal colours, and no literal sizes where a
  token exists. `MmSize` names the recurring sizes: `fab`, `iconXl` (the icon that leads an
  empty or error state), `stroke` (spinners inside controls, chart lines, outlined bars),
  `frame` (the nameplate border, receipt seal and void stamp), `focusRing` and `focusGap`,
  `tabIndicator`, `sheetMax` and `stateMax` (widest a sheet and a state block grow);
  `MmDuration.pulse` is one fade of a skeleton's pulse. If a component needs a value the tokens
  lack, add a token (`design/tokens/maalik.tokens.json`, `make tokens`), not a constant.
- **Type.** Text styles come from `Theme.of(context).textTheme`. Amounts use
  `context.mm.amount` or `context.mm.amountLarge` (Latin face, tabular figures, in both
  languages). User data that may be in Latin script (a name typed in English, a CNIC, a phone
  number) goes through `context.mm.styleFor(text, style)` so the Urdu UI sets it in Atkinson.
  The other way round needs nothing: every style in the Latin face (the English text theme,
  Urdu amounts, `context.mm.amount`) falls back to Nastaliq for Arabic-script letters. A style
  built from `MmTypeScale` directly gets the same fallback from
  `MmSemantics.withUrduFallback(style)`.
- **Money.** Amounts are `Money` from `mm_core`, formatted with `MmFormats.moneyOf(context)`
  (the app sets Western or lakh/crore grouping once). Screen readers get the plain number and
  the currency's name, `MmFormats.spokenMoney(context, amount)` ("125000 rupees"), because
  grouped figures are read out unreliably.
  `MoneyFormat` writes a negative amount with a left-to-right mark before its minus
  (`MoneyFormat.leftToRightMark`), so the sign stays on the left of the figures in Urdu: show
  formatted amounts as they come, without adding marks or isolates of your own
  (`parseMoneyInput` ignores the mark).
- **Semantics.** Buttons are buttons, headers are headers (`Semantics(header: true)`), a tile is
  one merged node (`MergeSemantics`), decorative parts are excluded (`ExcludeSemantics`), errors
  and snackbars are live regions, and icon-only controls have a tooltip that is also their
  label. Values that look different from how they read (masked CNIC, amounts, gauges) carry an
  explicit `Semantics(label: …, value: …)`.
- **Documentation.** Every public member has a dartdoc comment (`public_member_api_docs` is on).
  A widget's class comment says when to use it, when not to, and shows a short example.
- **Stock widgets.** The theme styles the Material widgets the components build on, so use
  them directly: buttons (above), `SegmentedButton` (paper segments, the selected one
  cobalt-tonal with a check, 48 dp tall), chips (framed in `inkMuted`, cobalt when selected,
  room for Nastaliq, an icon-sized check), `Badge` (Latin caption with tabular figures in both
  languages) and `TabBar` (cobalt label and underline over a hairline rule). A theme cannot
  size tabs or limit a badge's text scale: `MmTabs` makes tabs 48 dp targets, and a badge
  should clamp its text scaling as `MmAdaptiveScaffold` does.
- **Icons.** `MmIcons` only. Icons that point mirror in Urdu, trend arrows included
  (`trendUp`, `trendDown`, `trendFlat`), since time runs from the start edge.
- **Analysis.** `very_good_analysis` with `--fatal-infos`: no ignores, no `// ignore:`
  comments.

## Testing conventions

- Shared test code lives in `test/support/`; import it all with
  `import '../../support/testing.dart';`. It holds the harness (`harness.dart`: `MmVariant`,
  `pumpThemed`, `testEveryVariant`, `goldenEveryVariant`, `expectAccessible`), whole screens and
  overlays (`screen.dart`), golden compositions (`golden_page.dart`: `GoldenPage`, `Say`) and
  small helpers (`helpers.dart`: `colorsOf`, `tapped`, `useKeyboardHighlights`,
  `withoutAnimations`, `pumpLargeNarrow`, `expectFitsNarrowLargeText`, `paragraphOf`, `styleOf`,
  `hasFocus`, `focusedAt`, `labelsIn`, `readingOrder`, `painterIn`). A family's own test
  files keep only what is particular to it.
- Behaviour tests: `test/components/<family>/<name>_test.dart`. Cover every parameter, state
  and callback, keyboard activation and focus, semantics (labels, flags, actions), text scale
  200% on a 320 dp wide surface without overflow (`expectFitsNarrowLargeText` checks English
  and Urdu), and right-to-left layout. Use `testEveryVariant` where a behaviour must hold in
  every theme and language.
- Golden tests: `test/components/<family>/<name>_golden_test.dart`, tagged `@Tags(['golden'])`,
  using `goldenEveryVariant(name, build)`. It pumps the widget in all six variants (light, dark,
  light and dark high contrast, Urdu right to left, English at 200% text), runs
  `expectAccessible` (tap targets, labels, text contrast) and compares
  `goldens/<name>_<variant>.png`. A golden shows the component's states side by side in one
  compact composition, so each image is reviewable at a glance. The image is the subject on
  its page: the page colour and the 16 dp page gutter around it, on whole pixels, so
  compositions paint no background of their own and need no rounding of their size; Nastaliq
  overhang and focus rings outside filled controls stay in the picture. A composition that
  outgrows the phone at 200% text gets a taller surface for that variant alone:
  `sizes: {MmVariant.largeText: Size(360, 1000)}`.
- Whole screens and overlays: `pumpScreen` makes a widget the app's first page with no padding
  (`resizeScreen` changes the window), `WindowPanel` shows a window of another size inside a
  golden, and `pumpOverlay` opens a dialog, sheet or snack bar on the root navigator.
  `screenGoldenEveryVariant` and `overlayGoldenEveryVariant` compare the whole screen, scrim
  included.
- Text contrast is checked by `mmTextContrastGuideline` (`test/support/contrast.dart`), not
  Flutter's pixel guess: it takes each run's colour from the render tree (with its alpha and any
  opacity above it) and the background from the rendered frame, so the result does not depend
  on how strokes fall on the pixel grid. It checks every visible run of text, including text in
  merged tiles and text excluded from semantics, and leaves out disabled controls and text
  under a modal barrier. Large text (3:1) is 24 dp, or 18.67 dp bold, at the size the style
  sets. Text a `CustomPainter` draws is not a paragraph: test its colours against the theme
  roles directly.
- Fonts are real (`test/flutter_test_config.dart` loads Atkinson, Nastaliq and MmIcons), so
  goldens show the true rendering. Look at every golden you record.
- Run `flutter test --no-pub <paths>` (several packages share the workspace lockfile) and
  `dart analyze --fatal-infos <paths>`.
- Coverage: every line of `lib/src/components` and `lib/src/foundation` is exercised. Shared
  building blocks have their own tests in `test/foundation/`.

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
