import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/testing.dart';

/// The Material that paints the button found by [button].
Material materialOf(WidgetTester tester, Finder button) => tester.widget(
  find.descendant(of: button, matching: find.byType(Material)).first,
);

/// The edge of the button found by [button].
BorderSide sideOf(WidgetTester tester, Finder button) =>
    (materialOf(tester, button).shape! as OutlinedBorder).side;

/// The colour [icon] is painted in.
Color iconColorOf(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

/// The colour the paragraph showing [text] is painted in.
Color textColorOf(WidgetTester tester, String text) =>
    styleOf(tester, text).color!;

/// Where the letters of [paragraph] are painted, in its own coordinates:
/// the boxes of every character but spaces, so a space a line ends on (in
/// a right-to-left paragraph, past the line's left end) does not count.
Rect inkOfWords(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  return [
    for (var i = 0; i < text.length; i++)
      if (text[i].trim().isNotEmpty)
        ...paragraph.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        ),
  ].map((box) => box.toRect()).reduce((a, b) => a.expandToInclude(b));
}
