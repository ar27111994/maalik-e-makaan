import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A letter or digit: what a word or a number is made of.
final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The lines of every paragraph under [within] (the whole screen by
/// default) that break inside a word or a number, such as "Collect|ed" or
/// "Rs 1,2|5,000": each as the text before and after the break.
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
    // Runs in different faces (Latin and Urdu) start a few pixels apart
    // on one line; a new line starts at least half a line further down.
    final fontSize = paragraph.text.style?.fontSize ?? kDefaultFontSize;
    final newLine = paragraph.textScaler.scale(fontSize) / 2;
    for (var offset = 1; offset < text.length; offset++) {
      final before = lineOf(offset - 1);
      final after = lineOf(offset);
      // A new line starts here, within what the paragraph shows (an
      // ellipsis hides the rest).
      if (after < before + newLine || after >= paragraph.size.height) continue;
      final word = paragraph.getWordBoundary(TextPosition(offset: offset));
      if (word.start < offset &&
          offset < word.end &&
          _wordCharacter.hasMatch(word.textInside(text))) {
        broken.add(
          '${text.substring(word.start, offset)}|'
          '${text.substring(offset, word.end)}',
        );
      }
    }
  }
  return broken;
}

/// Fails when a paragraph under [within] breaks a line inside a word or a
/// number: text at large sizes must wrap between words, never mid-word,
/// and an amount never mid-number.
void expectWholeWords(WidgetTester tester, {Finder? within}) {
  final broken = brokenWords(tester, within: within);
  expect(broken, isEmpty, reason: 'lines break inside words: $broken');
}
