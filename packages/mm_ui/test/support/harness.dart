import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'contrast.dart';

export 'contrast.dart';

/// The ways every component is checked: each theme mode, Urdu (right to
/// left, Nastaliq), and English at 200% text size.
enum MmVariant {
  /// Light mode, English.
  light(Brightness.light, Locale('en'), 1),

  /// Dark mode, English.
  dark(Brightness.dark, Locale('en'), 1),

  /// Light high-contrast mode, English.
  lightHighContrast(Brightness.light, Locale('en'), 1, highContrast: true),

  /// Dark high-contrast mode, English.
  darkHighContrast(Brightness.dark, Locale('en'), 1, highContrast: true),

  /// Light mode, Urdu: right to left, Nastaliq.
  urdu(Brightness.light, Locale('ur'), 1),

  /// Light mode, English, text at 200%.
  largeText(Brightness.light, Locale('en'), 2);

  new(
    this.brightness,
    this.locale,
    this.textScale, {
    this.highContrast = false,
  });

  /// Light or dark.
  final Brightness brightness;

  /// Whether the high-contrast mode is used.
  final bool highContrast;

  /// The app language (and so the text direction and script).
  final Locale locale;

  /// The system text scale.
  final double textScale;

  /// The theme of this variant.
  ThemeData get theme => themeFor(locale);

  /// The theme of this variant's mode with the script of [locale].
  ThemeData themeFor(Locale locale) => MmTheme.data(
    brightness: brightness,
    script: MmScript.of(locale),
    highContrast: highContrast,
  );

  /// The colour roles of this variant.
  MmColorTokens get colors =>
      MmTheme.tokensFor(brightness, highContrast: highContrast);
}

/// The boundary around the component under test and the page gutter around
/// it; [expectGolden] captures it.
const subjectKey = ValueKey<String>('mm-subject');

/// The boundary around the whole app: every route, dialog, sheet and snack
/// bar of the root navigator, on the page colour. [expectScreenGolden]
/// captures it.
const screenKey = ValueKey<String>('mm-screen');

/// An app themed for [variant] whose first page is [home]: English and Urdu
/// localisations, the variant's text scale, the page colour under every
/// route, and [screenKey] around the root navigator.
///
/// [locale] replaces the variant's language (and so its script and
/// direction) while keeping its mode and text scale: Urdu at 200% text, for
/// example.
Widget themedApp(
  Widget home, {
  MmVariant variant = MmVariant.light,
  Locale? locale,
}) {
  final language = locale ?? variant.locale;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: variant.themeFor(language),
    locale: language,
    supportedLocales: const [Locale('en'), Locale('ur')],
    localizationsDelegates: const [
      MmLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(variant.textScale)),
      child: RepaintBoundary(
        key: screenKey,
        child: ColoredBox(color: context.mm.colors.bg, child: app),
      ),
    ),
    home: home,
  );
}

/// Wraps [child] in an app themed for [variant], centred on a page.
///
/// The boundary [expectGolden] captures ([subjectKey]) holds the subject on
/// its page: a [Material] in the page colour with the page's
/// [MmSpace.s4] gutter around the subject. So a golden shows the subject as
/// it looks on the page in every mode, along with what it draws past its
/// own box (Nastaliq glyphs overhang their line; filled controls draw their
/// focus ring outside themselves). Ink the subject draws on its nearest
/// Material (ink decorations, splashes, focus highlights) lands on that
/// page, under the subject.
///
/// The boundary sits on whole pixels and is a whole number of pixels in
/// size, so thin strokes are not blurred across a half pixel and the image
/// has no half-covered edge.
Widget themed(Widget child, {MmVariant variant = MmVariant.light}) {
  return themedApp(
    Scaffold(
      body: SafeArea(
        child: _PixelCenter(
          child: RepaintBoundary(
            key: subjectKey,
            child: Builder(
              builder: (context) => Material(
                color: context.mm.colors.bg,
                child: Padding(
                  padding: const EdgeInsets.all(MmSpace.s4),
                  child: _WholePixels(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    variant: variant,
  );
}

/// Pumps [child] for [variant] on a phone-sized surface (360 x 740 dp, 1x).
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  MmVariant variant = MmVariant.light,
  Size size = const Size(360, 740),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themed(child, variant: variant));
  await tester.pumpAndSettle();
}

/// Asserts the accessibility guidelines: 48 dp tap targets (Android) and
/// 44 pt (iOS), a label on every tappable element, and text contrast of at
/// least 4.5:1 (3:1 for large text), measured by [mmTextContrastGuideline]
/// from the text's own colour and the background painted behind it.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(mmTextContrastGuideline));
}

/// Compares the component under test with the approved image
/// `goldens/<name>_<variant>.png`.
Future<void> expectGolden(String name, MmVariant variant) => expectLater(
  find.byKey(subjectKey),
  matchesGoldenFile('goldens/${name}_${variant.name}.png'),
);

/// Compares the whole screen, overlays included, with the approved image
/// `goldens/<name>_<variant>.png`.
Future<void> expectScreenGolden(String name, MmVariant variant) => expectLater(
  find.byKey(screenKey),
  matchesGoldenFile('goldens/${name}_${variant.name}.png'),
);

/// Registers one widget test per variant, named `<description> (<variant>)`.
void testEveryVariant(
  String description,
  Future<void> Function(WidgetTester tester, MmVariant variant) body, {
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  for (final variant in variants) {
    testWidgets(
      '$description (${variant.name})',
      (tester) => body(tester, variant),
    );
  }
}

/// Registers, for every variant, a test that pumps [build]'s widget on a
/// phone-sized surface, checks the accessibility guidelines and compares it
/// with the approved golden `goldens/<name>_<variant>.png`.
///
/// The surface is [size], or the size [sizes] gives a variant: a
/// composition that grows past the phone at 200% text can have a taller
/// surface for [MmVariant.largeText] alone.
///
/// Call it from a file tagged `@Tags(['golden'])` so `make goldens` can
/// re-record just the images.
void goldenEveryVariant(
  String name,
  Widget Function() build, {
  Size size = const Size(360, 740),
  Map<MmVariant, Size> sizes = const {},
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    await pumpThemed(
      tester,
      build(),
      variant: variant,
      size: sizes[variant] ?? size,
    );
    await expectAccessible(tester);
    await expectGolden(name, variant);
  }, variants: variants);
}

/// Centres its child on whole device pixels.
///
/// [Center] puts a child of odd size half a pixel off the grid, where every
/// stroke is drawn blurred; this rounds the offset instead. It assumes its
/// own origin is on the grid, as the harness's page keeps it.
class _PixelCenter extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPixelCenter(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPixelCenter renderObject,
  ) => renderObject.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
}

class _RenderPixelCenter extends RenderShiftedBox {
  new(this._devicePixelRatio) : super(null);

  double _devicePixelRatio;

  /// The device pixels per logical pixel whose grid this aligns to.
  double get devicePixelRatio => _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  double _snap(double logical) =>
      (logical * _devicePixelRatio).roundToDouble() / _devicePixelRatio;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(constraints.loosen(), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(
      _snap((size.width - child.size.width) / 2),
      _snap((size.height - child.size.height) / 2),
    );
  }
}

/// Sizes itself to its child's size rounded up to whole device pixels, so a
/// boundary around it captures no half-covered edge.
class _WholePixels extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWholePixels(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWholePixels renderObject,
  ) => renderObject.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
}

class _RenderWholePixels extends RenderProxyBox {
  new(this._devicePixelRatio);

  double _devicePixelRatio;

  /// The device pixels per logical pixel whose grid this aligns to.
  double get devicePixelRatio => _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  /// Rounds [size] up to whole device pixels, ignoring a rounding error of
  /// a thousandth of a pixel.
  Size _snap(Size size) {
    double up(double logical) =>
        ((logical * _devicePixelRatio) - 1e-3).ceilToDouble() /
        _devicePixelRatio;
    return Size(up(size.width), up(size.height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(_snap(child.getDryLayout(constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_snap(child.size));
  }
}
