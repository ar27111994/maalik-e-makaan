import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The runs of the paragraph whose text contains [text] that are set in
/// the Latin face, in order: the figures and Latin words of an Urdu line.
List<String> latinRunsIn(WidgetTester tester, String text) => [
  for (final run in _runsIn(tester, text))
    if (run.style.fontFamily!.contains(MmFontFamily.latin)) run.text,
];

/// The runs of the paragraph whose text contains [text] that are set in
/// Nastaliq, in order.
List<String> urduRunsIn(WidgetTester tester, String text) => [
  for (final run in _runsIn(tester, text))
    if (run.style.fontFamily!.contains(MmFontFamily.urdu)) run.text,
];

/// The effective style of each run of text in the paragraph whose text
/// contains [text]: every span's style merged into its parent's.
List<({String text, TextStyle style})> _runsIn(
  WidgetTester tester,
  String text,
) {
  final runs = <({String text, TextStyle style})>[];
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is! TextSpan) return;
    final own = span.text;
    if (own != null && own.isNotEmpty) runs.add((text: own, style: style));
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(paragraphOf(tester, text).text, const TextStyle());
  return runs;
}

/// Whether [part] of the paragraph whose text contains [text] is laid out
/// on a single line.
bool onOneLine(WidgetTester tester, String text, String part) {
  final paragraph = paragraphOf(tester, text);
  final plain = paragraph.text.toPlainText();
  final start = plain.indexOf(part);
  expect(start, isNonNegative, reason: '"$part" is not in "$plain"');
  double lineOf(int offset) =>
      paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
  // Runs in different faces (Latin and Nastaliq) start a few pixels apart
  // on one line; a new line starts at least half a line further down.
  final newLine =
      paragraph.textScaler.scale(paragraph.text.style!.fontSize!) / 2;
  final first = lineOf(start);
  return [
    for (var offset = start + 1; offset < start + part.length; offset++)
      lineOf(offset),
  ].every((line) => (line - first).abs() < newLine);
}
