import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Picks the English or the Urdu words for the ambient language, as the
/// app's own localisations would.
typedef Say = String Function(String english, String urdu);

/// The [Say] of [context]'s language.
Say sayIn(BuildContext context) {
  final urdu = Localizations.localeOf(context).languageCode == 'ur';
  return (english, inUrdu) => urdu ? inUrdu : english;
}

/// The colour roles of [variant].
MmColorTokens colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

/// A golden composition on the page colour (goldens capture only the
/// subject, so dark modes would otherwise show on transparency), [width]
/// wide. [builder] gets a [Say] for the ambient language.
class GoldenPage extends StatelessWidget {
  /// Lays [builder]'s composition out on the page.
  const new(
    this.builder, {
    this.width = 328,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The composition's width: a phone's content column by default.
  final double width;

  /// Space around the composition, for text that starts at the edge:
  /// Nastaliq glyphs overhang their line, which the page's gutter absorbs
  /// in the app but the golden's boundary would cut.
  final EdgeInsetsGeometry padding;

  /// Builds the composition.
  final Widget Function(BuildContext context, Say say) builder;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.mm.colors.bg,
    child: SizedBox(
      width: width,
      child: Padding(
        padding: padding,
        child: Builder(builder: (context) => builder(context, sayIn(context))),
      ),
    ),
  );
}

/// A framed stand-in for a whole window of [size]: [child] sees a
/// [MediaQuery] of that size (so `MmWindowSize` picks that window's layout)
/// and is laid out at that size.
class WindowPanel extends StatelessWidget {
  /// Shows [child] as a window of [size].
  const new({required this.size, required this.child, super.key});

  /// The size of the window [child] thinks it fills.
  final Size size;

  /// The window's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      border: Border.all(color: context.mm.colors.outline),
    ),
    child: ClipRect(
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          // A window's screen is a Material, as a Scaffold would be.
          child: Material(color: context.mm.colors.bg, child: child),
        ),
      ),
    ),
  );
}

/// A callback for controls that should look enabled.
void tapped() {}

/// Draws focus as when driven from a keyboard, for the rest of the test.
void useKeyboardHighlights() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// Pumps [child] at 200% text on a 320 dp wide phone.
Future<void> pumpLargeNarrow(
  WidgetTester tester,
  Widget child, {
  double height = 740,
}) => pumpThemed(
  tester,
  child,
  variant: MmVariant.largeText,
  size: Size(320, height),
);

/// Pumps [child] filling a window of [size], themed for [variant], without
/// the harness's padding, so it can lay out as a whole screen would.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 740),
  MmVariant variant = MmVariant.light,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_screen(child, variant));
  await tester.pumpAndSettle();
}

/// Rebuilds the screen pumped by [pumpScreen] at a new window [size].
Future<void> resizeScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// An app themed for [variant], like the harness's, whose home is [child].
Widget _screen(Widget child, MmVariant variant) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: variant.theme,
  locale: variant.locale,
  supportedLocales: const [Locale('en'), Locale('ur')],
  localizationsDelegates: const [
    MmLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(variant.textScale)),
    child: app!,
  ),
  home: child,
);

/// Whether the widget found by [finder] has the primary focus.
bool hasFocus(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder)).hasPrimaryFocus;

/// The render box of the first widget found by [finder].
RenderBox boxOf(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderBox>(finder.first);

/// The rectangle the first widget found by [finder] covers on screen.
Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

/// [rupees] as the app shows an amount: lakh grouping, the Latin face with
/// tabular figures, the Urdu currency word in Nastaliq, and on one line,
/// scaled down rather than wrapped when it does not fit.
Widget moneyText(BuildContext context, int rupees, {bool large = false}) {
  final format = MmFormats.moneyOf(context)
      .copyWith(grouping: DigitGrouping.southAsian);
  final style = large ? context.mm.amountLarge : context.mm.amount;
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      format.format(Money.fromRupees(rupees)),
      style: style.copyWith(
        fontFamilyFallback: const [MmFontFamily.urdu],
        package: 'mm_ui',
      ),
    ),
  );
}
