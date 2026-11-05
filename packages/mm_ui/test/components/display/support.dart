import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// The colour roles of [variant].
MmColorTokens colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

/// Draws focus as when driven from a keyboard, for the rest of the test.
void useKeyboardHighlights() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// The paragraph whose text contains [text].
RenderParagraph paragraphOf(WidgetTester tester, String text) =>
    tester.renderObject(find.textContaining(text, findRichText: true).first);

/// The style of the paragraph whose text contains [text].
TextStyle styleOf(WidgetTester tester, String text) {
  final span = paragraphOf(tester, text).text;
  // A Text's paragraph wraps its span in one carrying the effective style.
  return span.style!;
}

/// The Material that paints the surface of the widget found by [widget].
Material surfaceOf(WidgetTester tester, Finder widget) => tester.widget(
  find.descendant(of: widget, matching: find.byType(Material)).first,
);

/// The border of the surface of the widget found by [widget].
BorderSide sideOf(WidgetTester tester, Finder widget) =>
    (surfaceOf(tester, widget).shape! as OutlinedBorder).side;

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

/// Whether the control around [text] has the primary focus.
bool focusedAt(WidgetTester tester, String text) =>
    Focus.of(tester.element(find.text(text))).hasPrimaryFocus;
