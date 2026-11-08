import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A letter or digit: what a word or a number is made of.
final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The lines of every paragraph under [within] (the whole screen by
/// default) that break inside a word or a number, such as "Collect|ed" or
/// "Rs 1,5|00": each as the text before and after the break, and the
/// paragraph it is in (as mm_ui's own test support finds them).
List<String> brokenWords(WidgetTester tester, {Finder? within}) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(
    within == null
        ? find.byType(RichText)
        : find.descendant(of: within, matching: find.byType(RichText)),
  );
  final broken = <String>[];
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    double lineOf(int offset) =>
        paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
    // Runs in different faces (Latin and Nastaliq) start a few pixels apart
    // on one line; a new line starts at least half a line further down.
    final fontSize = paragraph.text.style?.fontSize ?? kDefaultFontSize;
    final newLine = paragraph.textScaler.scale(fontSize) / 2;
    for (var offset = 1; offset < text.length; offset++) {
      final before = lineOf(offset - 1);
      final after = lineOf(offset);
      if (after < before + newLine || after >= paragraph.size.height) continue;
      final word = paragraph.getWordBoundary(TextPosition(offset: offset));
      if (word.start < offset &&
          offset < word.end &&
          _wordCharacter.hasMatch(word.textInside(text))) {
        broken.add(
          '${text.substring(word.start, offset)}|'
          '${text.substring(offset, word.end)} in "$text"',
        );
      }
    }
  }
  return broken;
}
