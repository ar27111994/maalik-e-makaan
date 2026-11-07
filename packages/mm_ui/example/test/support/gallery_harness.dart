import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui_gallery/src/app.dart';
import 'package:mm_ui_gallery/src/settings.dart';

// The text contrast check of mm_ui's own test harness, shared rather than
// copied so the gallery is held to exactly the same bar.
import '../../../test/support/contrast.dart';

/// The ways every gallery page is checked: each theme mode, Urdu (right to
/// left, Nastaliq) and English at 200% text, as mm_ui's harness checks each
/// component, and Urdu at 200% text.
enum GalleryVariant {
  light(GallerySettings()),
  dark(GallerySettings(brightness: Brightness.dark)),
  lightHighContrast(GallerySettings(highContrast: true)),
  darkHighContrast(
    GallerySettings(brightness: Brightness.dark, highContrast: true),
  ),
  urdu(GallerySettings(locale: Locale('ur'))),
  largeText(GallerySettings(textScale: 2)),

  /// Beyond mm_ui's harness: Urdu at 200% text, the tallest and widest
  /// the gallery's words get.
  urduLargeText(GallerySettings(locale: Locale('ur'), textScale: 2));

  new(this.settings);

  /// The gallery settings of this variant.
  final GallerySettings settings;
}

/// A phone in portrait, as the gallery's screenshots are taken.
const phone = Size(390, 844);

/// A laptop browser window.
const desktop = Size(1280, 800);

/// Pumps the gallery app on [family]'s page with [settings], in a window of
/// [size] at one device pixel per logical pixel.
Future<void> pumpGallery(
  WidgetTester tester, {
  GalleryFamily family = GalleryFamily.actions,
  GallerySettings settings = const GallerySettings(),
  Size size = phone,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GalleryApp(settings: settings, family: family));
  await settle(tester);
}

/// Lets the gallery finish its transitions. Busy buttons and skeletons
/// animate for ever, so this pumps a fixed time instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Asserts what mm_ui's harness asserts of every component: 48 dp tap
/// targets (Android) and 44 pt (iOS), a label on every tappable element,
/// and WCAG AA text contrast measured from the render tree.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(mmTextContrastGuideline));
}

/// The scroll position of the page on screen: its [MmPage]'s own scroll
/// view, the outermost scrollable inside it.
ScrollPosition pagePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(MmPage).last,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Checks the page on screen whole: first in its window as pumped, then in
/// a window grown tall enough to show all of it at once (the same width, so
/// the same layout), so that every control and every run of text is on
/// screen for the checks rather than cut by the edge of the scroll view.
/// At each, nothing may have thrown (a layout overflow is reported as an
/// exception) and everything must be accessible. Returns how much taller
/// than its window the page is.
Future<double> checkWholePage(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await expectAccessible(tester);
  final window = tester.view.physicalSize;
  final overflow = pagePosition(tester).maxScrollExtent;
  var height = window.height;
  // The page's content does not depend on the window's height, so one
  // step is enough; a second covers anything that does.
  for (var step = 0; step < 2; step++) {
    final rest = pagePosition(tester).maxScrollExtent;
    if (rest <= 0) break;
    height += rest;
    tester.view.physicalSize = Size(window.width, height);
    await settle(tester);
  }
  expect(pagePosition(tester).maxScrollExtent, 0);
  expect(tester.takeException(), isNull);
  await expectAccessible(tester);
  return overflow;
}

/// The money format the gallery shows amounts in, read from the screen.
MoneyFormat moneyFormatOf(WidgetTester tester) =>
    MmFormats.moneyOf(tester.element(find.byType(MmPage).last));
