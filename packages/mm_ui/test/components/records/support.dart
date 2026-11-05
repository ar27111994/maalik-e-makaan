import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/testing.dart';

/// The distance from the top of the screen to [text]'s first baseline.
double baselineOf(WidgetTester tester, String text) {
  final paragraph = paragraphOf(tester, text);
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

/// [node]'s children in the order a screen reader reads them.
List<SemanticsNode> childrenInOrder(SemanticsNode node) =>
    node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);
