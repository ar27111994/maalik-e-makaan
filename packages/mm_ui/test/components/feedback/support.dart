import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The colour [icon] is painted in.
Color iconColorOf(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find
          .descendant(of: find.byIcon(icon), matching: find.byType(RichText))
          .first,
    )
    .text
    .style!
    .color!;

/// The effective style [run] is drawn in, inside the paragraph that holds
/// [text]: the paragraph's style merged with the styles of the spans down
/// to the one that holds [run].
TextStyle runStyleIn(WidgetTester tester, String text, String run) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains(text),
        )
        .first,
  );
  TextStyle? found;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (found != null) return;
    if (span is TextSpan) {
      if (span.text?.contains(run) ?? false) {
        found = style;
        return;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  visit(paragraph.text, const TextStyle());
  expect(found, isNotNull, reason: '"$run" in "$text"');
  return found!;
}

/// Whether [style] sets its text in the Latin face (Atkinson).
bool isLatinFace(TextStyle style) =>
    style.fontFamily?.contains(MmFontFamily.latin) ?? false;

/// Pumps [home] as the whole screen at 200% text in Urdu on a phone [width]
/// wide, and returns a context inside it from which overlays open.
Future<BuildContext> pumpUrduLargeNarrow(
  WidgetTester tester, {
  Widget home = const Scaffold(),
  double width = 320,
  double height = 740,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final page = GlobalKey();
  await tester.pumpWidget(
    themedApp(
      KeyedSubtree(key: page, child: home),
      variant: MmVariant.largeText,
      locale: const Locale('ur'),
    ),
  );
  await tester.pumpAndSettle();
  return page.currentContext!;
}

/// Turns on the platform's screen reader navigation
/// (`MediaQuery.accessibleNavigation`) for the rest of the test.
void useScreenReader(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(accessibleNavigation: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
