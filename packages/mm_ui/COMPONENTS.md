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
  fields draw a `MmSize.focusRing` ring in `colors.focus` on their edge (`MmSegmentedControl`
  keeps the control's outline and rings only the focused segment, so the ring says which one). Filled, elevated and
  icon buttons and the floating action button draw it outside themselves, past
  `MmSize.focusGap` (`MmFocusRingBorder`), because on their edge it would be the colour of the
  fill. A component that gives a filled control its own `shape` keeps the ring with
  `MmFocusRingBorder.whenFocused(shape, color: colors.focus)`; leave 4 dp around filled
  controls so neighbours and clips do not cover the ring. A component that draws its own ring
  (a tile, a card, a field-like box) draws it only for keyboard focus: `MmFocusHighlight` tells
  its state when, and `MmFocusWithin` rings a row whose control has focus.
- **Disabled is muted ink.** The theme's disabled buttons, icon buttons, switches, checkboxes
  and radio buttons use `inkMuted` for text and icons; filled and elevated buttons sit on
  `surfaceSunken` inside a `rule` border, like a disabled outlined button. A filled icon button
  that needs a disabled fill sets it itself (`MmIconButton` does).
- **Overlays have an edge.** The theme's dialog and bottom-sheet shapes carry
  `MmTheme.overlayEdge` (the outline in dark and high-contrast modes, none in light mode), so a
  stock dialog or sheet does not melt into the dimmed page.

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
    do not fit; a below line; centre, baseline or top alignment; stacked at either edge). A
    label and its value (detail rows, receipt rows, meters, a chart legend, list tiles) stack
    the value at the end edge (`stackedAtEnd`), so a card's figures end on one edge whichever
    rows had to move;
  - `MmWrap` (a `Wrap` whose widest intrinsic width counts its spacing, which Flutter's leaves
    out): use it for a wrap that `MmReflow` or another intrinsic layout measures;
  - `MmBalanced` (a paragraph as narrow as it can be without another line, so a centred
    paragraph never ends on a lone word: empty and error states use it);
  - `MmIconLabel` (an icon and words in one paragraph, the icon growing at most 150%, the
    words split by script as `MmScriptText` splits them; with `fitWords`, an amount too wide
    for its line wraps between its figures and its currency word) and `MmLineIcon` (an icon
    centred on the first line of the text beside it, growing at most 150%);
  - `MmIconSize` (public: `MmIconSize.withText(context, size)`, an icon beside words grown
    with the text up to `MmIconSize.maxScale`, 150%; `MmIconLabel.scaledSize` is the same);
  - `MmFitWords` (shows words as they are wherever their longest word fits, and with more
    places to break, `MmFitWords.loosened`, where it does not: status badges, tone chips and
    the receipt's seal use it, so an amount or a receipt number at 200% text breaks between
    its figures and its currency word or after a dash, never inside the figures; the version
    it does not show is laid out unwrapped, so nothing that reads the laid-out lines finds a
    cut word the screen never shows. Give these components an amount or a number as it is;
    `MmListTile` does not loosen its title or subtitle, so a list row loosens an amount
    there itself);
  - `MmScriptText` (text whose Latin letters and figures inside Urdu are set in the Latin face,
    on the Urdu style's lines) and `MmUserText` (text the landlord wrote: `MmScriptText`, also
    kept in its own direction with `MmSemantics.isolated`): use `MmUserText` for names,
    addresses, property names, identifiers and the options a landlord created, and
    `MmScriptText` for the app's own sentences with figures in them. A Latin run takes the
    spaces on either side of it, so the space between an Urdu word and a Latin name is the
    Latin face's. Both show the narrow no-break space `intl` puts before AM and PM as a
    no-break space (`MmSemantics.drawableSpaces`, public, for the app's own `Text`): the
    Latin face does not draw it;
  - `MmTextMetrics` (how much room a label takes as a `Text` sets it: its size, its widest
    word, its line count and how far the marks of Urdu letters reach past its lines);
  - `MmTone` and `MmToneChip` (the colour families of statuses and the chip that shows one
    with an icon and a word);
  - `showMmModalSheet` and `MmSheetHeader` (how every sheet opens, and its title row with a
    close button centred on the title's first line);
  - `MmDateLocale` (day-first dates for English, Sunday-first weeks, and Urdu day names over the
    date picker's columns through `MmUrduMaterialLocalizations`; open a picker from a context
    inside it, as `MmDateField` does);
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
  empty or error state), `avatar` (a list row's avatar and its skeleton), `listRow` (the
  shortest list row), `stroke` (spinners inside controls, chart lines, outlined bars),
  `frame` (the nameplate border, receipt seal and void stamp), `focusRing` and `focusGap`,
  `tabIndicator`, `sheetMax` and `stateMax` (widest a sheet and a state block grow),
  `listPane` (the list column beside its details) and `preview` (the height of a photo's
  preview in a form or sheet); `MmDuration.pulse` is one fade of a
  skeleton's pulse. If a component needs a size the page grid or more than one component
  shares, or one the design language fixes, add a token (`design/tokens/maalik.tokens.json`,
  `make tokens`), not a constant. Two kinds of value stay named, documented constants in the
  component that owns them: the internal geometry of one painter (a chart's plot height, its
  hatch pitch and legend swatch), which no other component or the website's CSS shares; and
  how long a message stays on screen (a snackbar's 4 and 10 seconds), which is reading time,
  not motion: `MmDuration` values drop to zero with reduced motion and would make a message
  vanish.
- **Type.** Text styles come from `Theme.of(context).textTheme`. Amounts use
  `context.mm.amount` or `context.mm.amountLarge` (Latin face, tabular figures, in both
  languages). User data that may be in Latin script (a name typed in English, a CNIC, a phone
  number) goes through `context.mm.styleFor(text, style)` so the Urdu UI sets it in Atkinson.
  The labels of controls (buttons, the floating action button, segments, tabs, chips,
  switch, checkbox and radio rows, navigation destinations, banner, snack bar and section
  actions) go through `MmScriptText` too, so an app word in Latin script in an Urdu label
  ("English", "100%", "PDF") keeps the Latin face rather than the Urdu face's own Latin
  glyphs. So do the hints, helper lines and errors of fields and a stepper's value, so an
  amount in a helper below a money field has the figures of the amount typed in it. The other
  way round needs nothing: every style in the Latin face (the English text theme, Urdu amounts,
  `context.mm.amount`) falls back to the Urdu face (Noto Sans Arabic) for Arabic-script
  letters. A style
  built from `MmTypeScale` directly gets the same fallback from
  `MmSemantics.withUrduFallback(style)`. Figures that count or line up (amounts, counts,
  percentages, receipt numbers, detail-row values) take `MmSemantics.withTabularFigures(style)`.
- **Money.** Amounts are `Money` from `mm_core`, formatted with `MmFormats.moneyOf(context)`
  (the app sets Western or lakh/crore grouping once). Screen readers get the plain number and
  the currency's name, `MmFormats.spokenMoney(context, amount)` ("125000 rupees"), because
  grouped figures are read out unreliably.
  `MoneyFormat` joins the figures and the words beside them (`Rs`, `PKR`, `روپے`, `lakh`) with a
  no-break space (`MoneyFormat.noBreakSpace`), so an amount never wraps away from its unit;
  match formatted amounts in tests with the formatter's own output, not a typed literal.
  It writes a negative amount with a left-to-right mark before its minus
  (`MoneyFormat.leftToRightMark`), so the sign stays on the left of the figures in Urdu: show
  formatted amounts as they come, without adding marks or isolates of your own
  (`parseMoneyInput` ignores the mark).
- **Semantics.** Buttons are buttons, headers are headers (`Semantics(header: true)`), a tile is
  one merged node (`MergeSemantics`), decorative parts are excluded (`ExcludeSemantics`), errors
  and snackbars are live regions, and icon-only controls have a tooltip that is also their
  label. Values that look different from how they read (masked CNIC, amounts, gauges) carry an
  explicit `Semantics(label: …, value: …)`. Parts of one spoken label are joined with
  `MmLocalizations.of(context).joined([...])` ("Monthly rent, 45000 rupees"; the Urdu comma
  "،" in Urdu), never a hard-coded ", ". Content is read in the order it is shown: a
  receipt's void state right after its number, before its amount.
- **Documentation.** Every public member has a dartdoc comment (`public_member_api_docs` is on).
  A widget's class comment says when to use it, when not to, and shows a short example.
- **Stock widgets.** The theme styles the Material widgets the components build on, so use
  them directly: buttons (above), `SegmentedButton` (paper segments, the selected one
  cobalt-tonal with a check, 48 dp tall), chips (framed in `inkMuted`, cobalt when selected,
  room for the marks of Urdu letters, an icon-sized check), `Badge` (Latin caption with tabular figures in both
  languages) and `TabBar` (cobalt label and underline over a hairline rule). A theme cannot
  size tabs or limit a badge's text scale: `MmTabs` makes tabs 48 dp targets, and a badge
  should clamp its text scaling as `MmAdaptiveScaffold` does. Material's `Badge` overlaps its
  icon (and, in Urdu, hangs into it): `MmAdaptiveScaffold` places a destination's count past
  the icon's top end corner itself, clear of the glyph in both directions.
- **Icons.** `MmIcons` only. Icons that point mirror in Urdu, trend arrows included
  (`trendUp`, `trendDown`, `trendFlat`), since time runs from the start edge. Lucide's
  `receipt` glyph carries a dollar sign: for a receipt, a statement or a cheque in a rupee
  app use `receiptText`, which has lines of text instead. Icons beside
  text grow with it, at most 150% (`MmIconSize.withText`), and so do the controls that
  stand for a choice: checkboxes, radio buttons, switches and a chip's check. The icon font
  keeps each glyph where Lucide draws it, centred in its square (`make icons` sets each
  glyph's side bearing, and `make icons-check` fails on a glyph off its place).
- **Analysis.** `very_good_analysis` with `--fatal-infos`: no ignores, no `// ignore:`
  comments.

## Testing conventions

- Shared test code lives in `test/support/`; import it all with
  `import '../../support/testing.dart';`. It holds the harness (`harness.dart`: `MmVariant`,
  `pumpThemed`, `testEveryVariant`, `goldenEveryVariant`, `expectAccessible`), whole screens and
  overlays (`screen.dart`), golden compositions (`golden_page.dart`: `GoldenPage`, `Say`) and
  small helpers (`helpers.dart`: `colorsOf`, `tapped`, `useKeyboardHighlights`,
  `withoutAnimations`, `pumpLargeNarrow`, `expectFitsNarrowLargeText`, `textIn`, `paragraphOf`,
  `styleOf`, `linesOf`, `hasFocus`, `focusedAt`, `labelsIn`, `readingOrder`, `painterIn`), keyboard focus
  (`focus.dart`: `focusOn`, `focusedGoldenEveryVariant`) and the whole-word check (`words.dart`:
  `brokenWords`, `expectWholeWords`). A family's own test files keep only what is particular
  to it.
- Behaviour tests: `test/components/<family>/<name>_test.dart`. Cover every parameter, state
  and callback, keyboard activation and focus, semantics (labels, flags, actions), text scale
  200% on a 320 dp wide surface without overflow and without a line breaking inside a word or
  a number (`expectFitsNarrowLargeText` checks both, in English and Urdu), and right-to-left
  layout. Use `testEveryVariant` where a behaviour must hold in
  every theme and language.
- Golden tests: `test/components/<family>/<name>_golden_test.dart`, tagged `@Tags(['golden'])`,
  using `goldenEveryVariant(name, build)`. It pumps the widget in all six variants (light, dark,
  light and dark high contrast, Urdu right to left, English at 200% text), runs
  `expectAccessible` (tap targets, labels, text contrast) and compares
  `goldens/<name>_<variant>.png`. A golden shows the component's states side by side in one
  compact composition, so each image is reviewable at a glance. The image is the subject on
  its page: the page colour and the 16 dp page gutter around it, on whole pixels, so
  compositions paint no background of their own and need no rounding of their size; Urdu
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
- Fonts are real (`test/flutter_test_config.dart` loads Atkinson, Noto Sans Arabic, Noto
  Nastaliq Urdu, MmIcons and Material's icon font, which stock widgets such as the date picker
  draw their arrows with), so goldens show the true rendering. Look at every golden you record.
- Run `flutter test --no-pub <paths>` (several packages share the workspace lockfile) and
  `dart analyze --fatal-infos <paths>`.
- Coverage: every line of `lib/src/components` and `lib/src/foundation` is exercised. Shared
  building blocks have their own tests in `test/foundation/`.

## Families

| Family     | Components                                                                                                                           |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `actions`  | `MmButton`, `MmIconButton`, `MmFab`, `MmSegmentedControl`                                                                            |
| `inputs`   | `MmTextField`, `MmPasswordField`, `MmMoneyField`, `MmCnicField`, `MmPhoneField`, `MmCnicText` (and `MmValueEntry`)                   |
| `choices`  | `MmDateField`, `MmSelectField`, `MmSwitchTile`, `MmCheckboxTile`, `MmRadioGroup`, `MmSearchField`, `MmFilterChips`, `MmStepperField` |
| `display`  | `MmCard`, `MmListTile`, `MmStatusBadge`, `MmAmount`, `MmStatTile`, `MmAvatar`, `MmSectionHeader`, `MmDetailRow`                      |
| `records`  | `MmMeter`, `MmTimeline`, `MmReceipt`, `MmNameplate`, `MmScoreGauge`                                                                  |
| `feedback` | `MmEmptyState`, `MmErrorState`, `MmSkeleton`, `MmSkeletonList`, `MmBanner`, `showMmSnackbar`, `showMmConfirmDialog`, `showMmSheet`   |
| `layout`   | `MmAdaptiveScaffold`, `MmPage`, `MmListDetail`, `MmResponsiveGrid`, `MmFormSection`, `MmActionBar`, `MmTabs`                         |
| `charts`   | `MmBarChart`, `MmProportionBar`, `MmSparkline`, `MmDataTable`                                                                        |

Notes on composing them:

- **Form sections** (`MmFormSection`) title their group of fields in `titleLarge`, one step
  under a screen's headline, so a long form reads as headed parts.
- **Choice rows line up with fields.** `MmSwitchTile`, `MmCheckboxTile` and the rows of
  `MmRadioGroup` reach 16 dp into the page's gutter on both sides (their ink and focus ring
  do; taps stay inside the column). The visible box, ring or track, not just the touch
  target, sits on the content edge with the fields and headings around them: a checkbox's
  box and a radio's ring start there, a switch's track ends there. A radio option's icon
  sits beside its label, and the radio grows with the text as that icon does.
- **Snack bars need a `Scaffold`.** `MmAdaptiveScaffold` gives its body a `ScaffoldMessenger`
  of its own, so a snack bar shown from a screen appears on that screen's `Scaffold`, above
  its bottom bar. A screen inside it must therefore be (or hold) a `Scaffold`; an `MmPage` is
  one.
- **Badges count, they do not judge.** A count on a destination or an icon is ink on paper,
  not the overdue red: the label beside it says what is counted.
- **Value fields** (`MmMoneyField`, `MmCnicField`, `MmPhoneField`) report the value, or null
  for an empty field and for a typo alike; give an optional field `invalidText` or read
  `onEntryChanged` (`MmValueEntry.isInvalid`) so a mistake is not saved as "none".
- **A rupee field keeps its amount against its currency word.** The money format writes
  "Rs" before the figures in English and "روپے" after them in Urdu, and the field's currency
  sits at its edge as that word's place says: so its amount starts at the start edge in
  English and ends at the end edge (the left) in Urdu, where Urdu amounts sit in lists, rows
  and receipts. Text, CNIC, phone and date fields start at the start edge in both languages.
  This is by design; do not realign one field to match the others.
- **Bar charts of things, not periods,** pass `groupKind: MmBarGroupKind.names`: every bar
  keeps its name, wrapped between words, and the chart shows its table where a name cannot
  fit (large text on a phone). Months may lose every other label; units may not.
- **Two series: nested or side by side.** A measure against the one it is measured by
  (collected against due) keeps the default `MmBarArrangement.nested`: the solid bar inside
  the wide outlined one, readable even for a year on a phone. Two independent measures (money
  in and money out) pass `arrangement: MmBarArrangement.sideBySide`: two bars of one width, the
  first series at the start edge (on the right in Urdu), still solid and outlined so they
  differ without colour.
- **Overdue by age in four buckets** uses `MmSegmentTone.dueSoon`, `overdue`,
  `overdueOlder` (cross-hatched) and `overdueSevere` (solid): ever less paper through the red.
- **Rows that open something** pass `chevron: true` (and `onTap`) to `MmListTile`, never an
  `Icon` in `trailing`: the chevron stays beside the title however the title wraps, while a
  trailing amount or badge moves under the text. The chevron keeps its column (its glyph and
  an 8 dp gap) for the whole height of the row, so the title and subtitle wrap a little sooner
  than in a row without one; give long words their own places to break (an e-mail after its
  "@", a date between its month and year). Like Material's list rows, the chevron is centred
  on a row of one or two lines and sits beside the first line of a taller one, so in a card of
  mixed rows the chevrons are not all at one height: that is the rule, not a fault. Words from
  the app's localisations in a row pass `userData: false`, so a label that starts with a Latin
  word ("PDF رسیدیں") still runs in the UI's direction. `subtitleMaxLines: null` lets a
  subtitle (a member's role and email) run as long as it needs.
- **A passage of the landlord's words** (a description, notes, what was done) goes in
  `MmDetailRow.prose`: the label above, the words under it across the card, in their own
  script's face and direction, every line from the start of that direction (an English note
  in the Urdu UI starts each line at the left edge). The other rows keep their values on the
  end edge.
- **Sheet titles that are the landlord's data** (a member's name or email, a document's name)
  pass `userTitle: true` to `showMmSheet`, so a name typed in English is in the Latin face in
  the Urdu UI.
- **Destructive buttons.** The button that starts removing, voiding or ending a record is
  `MmButtonVariant.destructiveOutlined` wherever it sits, the "Delete" at the foot of a
  record's screen included; the filled `MmButtonVariant.destructive` is for the point of no
  return (a confirm dialog's button, a reason sheet's last button, the last step of deleting
  the account). Clearing a notification removes no record and stays `tertiary`.
  `showMmConfirmDialog(cancelLabel: …)` names the way out when "Cancel" would be ambiguous
  ("Keep the repair" beside "Cancel the repair").
- **A link at the foot of a card** is `MmButtonVariant.link`: its label lines up with the
  card's words and its padding, ink and focus ring reach 16 dp into the card's padding. Give
  it at least 16 dp of unclipped space on its start side (an `MmCard`'s padding is exactly
  that); in a clipping container, or one with less padding, its focus ring would be cut.
- **Text fields follow their text's direction.** `MmTextField` runs its text in the direction
  of its first letter (Urdu typed in the English UI right to left), with the label in the UI's
  direction; `leftToRight` fields stay left to right. A one-line field keeps the text at the
  start edge of the form; a field of several lines (`maxLines` other than 1) starts each line
  at the start of the text's own direction, as `dir="auto"` does.

The gallery app in `example/` shows every component in every variant.
