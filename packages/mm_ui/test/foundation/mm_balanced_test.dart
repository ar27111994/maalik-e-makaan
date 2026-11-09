import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_balanced.dart';

import '../support/testing.dart';

const _key = Key('text');

/// [text] at 16 px in a column [width] wide, balanced when [balanced].
Widget _paragraph(String text, {double width = 300, bool balanced = true}) {
  final paragraph = Text(
    text,
    key: _key,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 16),
  );
  return Center(
    child: SizedBox(
      width: width,
      child: Column(
        children: [if (balanced) MmBalanced(child: paragraph) else paragraph],
      ),
    ),
  );
}

/// How many of [text]'s words each line of the paragraph [_key] shows.
List<int> _wordsPerLine(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byKey(_key));
  final lines = <double, int>{};
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final top = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        )
        .first
        .top
        .roundToDouble();
    lines[top] = (lines[top] ?? 0) + 1;
  }
  return [for (final top in lines.keys.toList()..sort()) lines[top]!];
}

void main() {
  group('MmBalanced', () {
    const sentence =
        'We could not reach the server. Check your connection and try '
        'again.';

    testWidgets('never leaves one word on the last line', (tester) async {
      // A column width at which, unbalanced, the last line holds one word.
      var width = 200.0;
      late List<int> ragged;
      for (; width <= 400; width += 2) {
        await pumpThemed(
          tester,
          _paragraph(sentence, width: width, balanced: false),
        );
        ragged = _wordsPerLine(tester, sentence);
        if (ragged.length > 1 && ragged.last == 1) break;
      }
      expect(ragged.last, 1, reason: '$ragged at $width');
      final raggedSize = tester.getSize(find.byKey(_key));

      await pumpThemed(tester, _paragraph(sentence, width: width));
      final balanced = _wordsPerLine(tester, sentence);
      expect(balanced, hasLength(ragged.length));
      expect(balanced.last, greaterThan(1), reason: '$balanced');
      final size = tester.getSize(find.byKey(_key));
      // As many lines, so as tall, but narrower.
      expect(size.height, raggedSize.height);
      expect(size.width, lessThan(raggedSize.width));
      // Its dry layout agrees with its layout.
      final box = tester.renderObject<RenderBox>(find.byType(MmBalanced));
      expect(box.getDryLayout(BoxConstraints(maxWidth: width)), box.size);
    });

    testWidgets('keeps a line that fits as it is', (tester) async {
      await pumpThemed(tester, _paragraph('Try again'));
      final width = tester.getSize(find.byKey(_key)).width;
      await pumpThemed(tester, _paragraph('Try again', balanced: false));
      expect(tester.getSize(find.byKey(_key)).width, width);
    });

    testWidgets('never goes narrower than its widest word', (tester) async {
      // One word wider than the column: nothing to balance.
      const word = 'Counterintuitively';
      await pumpThemed(tester, _paragraph(word, width: 60));
      expect(tester.getSize(find.byKey(_key)).width, 60);
    });

    testWidgets('passes unbounded and tight widths through', (tester) async {
      await pumpThemed(
        tester,
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MmBalanced(child: Text(sentence, key: _key)),
        ),
      );
      expect(_wordsPerLine(tester, sentence), hasLength(1));
      await pumpThemed(
        tester,
        const Center(
          child: SizedBox(
            width: 300,
            child: MmBalanced(child: Text(sentence, key: _key)),
          ),
        ),
      );
      // Held to its width, it fills it; its lines are still balanced.
      expect(tester.getSize(find.byType(MmBalanced)).width, 300);
      expect(_wordsPerLine(tester, sentence).last, greaterThan(1));
    });
  });
}
