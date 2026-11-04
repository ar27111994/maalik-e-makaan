import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

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
  ThemeData get theme => MmTheme.data(
    brightness: brightness,
    script: MmScript.of(locale),
    highContrast: highContrast,
  );
}

/// The boundary around the component under test; goldens capture it alone.
const subjectKey = ValueKey<String>('mm-subject');

/// Wraps [child] in an app themed for [variant], centred on a page.
Widget themed(Widget child, {MmVariant variant = MmVariant.light}) {
  return MaterialApp(
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
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Center(
            child: RepaintBoundary(key: subjectKey, child: child),
          ),
        ),
      ),
    ),
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

/// Asserts the accessibility guidelines Flutter can check: 48 dp tap targets
/// (Android) and 44 pt (iOS), a label on every tappable element, and text
/// contrast of at least 4.5:1 (3:1 for large text).
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Compares the component under test with the approved image
/// `goldens/<name>_<variant>.png`.
Future<void> expectGolden(String name, MmVariant variant) => expectLater(
  find.byKey(subjectKey),
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
/// Call it from a file tagged `@Tags(['golden'])` so `make goldens` can
/// re-record just the images.
void goldenEveryVariant(
  String name,
  Widget Function() build, {
  Size size = const Size(360, 740),
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    await pumpThemed(tester, build(), variant: variant, size: size);
    await expectAccessible(tester);
    await expectGolden(name, variant);
  }, variants: variants);
}
