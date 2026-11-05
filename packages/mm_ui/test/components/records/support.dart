import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// The colour roles of [variant].
MmColorTokens colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

/// The paragraph whose text contains [text].
RenderParagraph paragraphOf(WidgetTester tester, String text) =>
    tester.renderObject(find.textContaining(text, findRichText: true).first);

/// The effective style of the paragraph whose text contains [text].
TextStyle styleOf(WidgetTester tester, String text) =>
    paragraphOf(tester, text).text.style!;

/// The distance from the top of the screen to [text]'s first baseline.
double baselineOf(WidgetTester tester, String text) {
  final paragraph = paragraphOf(tester, text);
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
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

/// [child] with animations turned off, as when the platform asks for
/// reduced motion.
Widget withoutAnimations(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// The semantics node of the widget found by [finder]: the nearest node at
/// or above its render object.
SemanticsNode nodeOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder);

/// [node]'s children in the order a screen reader reads them.
List<SemanticsNode> childrenInOrder(SemanticsNode node) =>
    node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);

/// The labels of [node]'s children in the order a screen reader reads
/// them.
List<String> readingOrder(SemanticsNode node) => [
  for (final child in childrenInOrder(node)) child.label,
];

/// The painter of the [CustomPaint] inside the widget found by [widget].
T painterIn<T extends CustomPainter>(WidgetTester tester, Finder widget) =>
    tester
        .widgetList<CustomPaint>(
          find.descendant(of: widget, matching: find.byType(CustomPaint)),
        )
        .map((paint) => paint.painter)
        .whereType<T>()
        .first;
