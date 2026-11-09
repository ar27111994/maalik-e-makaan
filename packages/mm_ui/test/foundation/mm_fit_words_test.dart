import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/foundation/mm_fit_words.dart';

import '../support/testing.dart';

const _tight = 'Rs\u00A01,25,000\u00A0overdue';
const _loose = 'Rs 1,25,000 overdue';

/// [MmFitWords] with [_tight] and its loosened words, as wide as [width].
Widget _fit({double? width, VoidCallback? onTap}) => SizedBox(
  width: width,
  child: MmFitWords(
    tight: GestureDetector(onTap: onTap, child: const Text(_tight)),
    loose: GestureDetector(
      onTap: onTap,
      child: Text(MmFitWords.loosened(_tight)),
    ),
  ),
);

RenderMmFitWords _render(WidgetTester tester) =>
    tester.renderObject(find.byType(MmFitWords));

/// The child of [MmFitWords] that holds [text].
RenderObject _holding(WidgetTester tester, String text) => tester.renderObject(
  find.ancestor(of: find.text(text), matching: find.byType(GestureDetector)),
);

void main() {
  group('MmFitWords.loosened', () {
    test('lets an amount break between its figures and its currency word', () {
      expect(MmFitWords.loosened(_tight), _loose);
      expect(MmFitWords.loosened('1,25,000 روپے'), '1,25,000 روپے');
    });

    test('lets a number break after its dashes, never before figures', () {
      expect(MmFitWords.loosened('MM-2026-00041'), 'MM-\u200B2026-\u200B00041');
      // A dash on its own, or at the end, is left alone.
      expect(MmFitWords.loosened('A - B-'), 'A - B-');
      expect(MmFitWords.loosened('Ali Raza'), 'Ali Raza');
    });
  });

  group('MmFitWords', () {
    testWidgets('shows the words as they are wherever they fit', (
      tester,
    ) async {
      await pumpThemed(tester, _fit(width: 300));
      final render = _render(tester);
      expect(render.shown, _holding(tester, _tight));
      // Only the words shown are read.
      expect(find.semantics.byLabel(_tight), findsOne);
      expect(find.semantics.byLabel(_loose), findsNothing);
    });

    testWidgets('shows the looser words where the longest word does not fit', (
      tester,
    ) async {
      await pumpThemed(tester, _fit(width: 80));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(_loose));
      expect(_render(tester).shown, _holding(tester, _loose));
      expect(find.semantics.byLabel(_loose), findsOne);
      expect(find.semantics.byLabel(_tight), findsNothing);
      expect(_render(tester).size, paragraph.size);
    });

    testWidgets('reports the natural width of its words and the narrowest '
        'width of the looser ones', (tester) async {
      await pumpThemed(tester, _fit(width: 300));
      final render = _render(tester);
      final tight = tester.renderObject<RenderBox>(find.text(_tight));
      final loose = tester.renderObject<RenderBox>(find.text(_loose));
      expect(
        render.getMaxIntrinsicWidth(double.infinity),
        tight.getMaxIntrinsicWidth(double.infinity),
      );
      expect(
        render.getMinIntrinsicWidth(double.infinity),
        loose.getMinIntrinsicWidth(double.infinity),
      );
      expect(render.getMinIntrinsicHeight(80), loose.getMinIntrinsicHeight(80));
      expect(
        render.getMaxIntrinsicHeight(300),
        tight.getMaxIntrinsicHeight(300),
      );
      expect(
        render.getDryLayout(const BoxConstraints(maxWidth: 80)),
        loose.getDryLayout(const BoxConstraints(maxWidth: 80)),
      );
      expect(
        render.getDryBaseline(
          const BoxConstraints(maxWidth: 300),
          TextBaseline.alphabetic,
        ),
        tight.getDryBaseline(
          const BoxConstraints(maxWidth: 300),
          TextBaseline.alphabetic,
        ),
      );
    });

    testWidgets('has the baseline of the words it shows', (tester) async {
      await pumpThemed(
        tester,
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Due', style: TextStyle(fontSize: 30)),
            _fit(width: 200),
          ],
        ),
      );
      final due = paragraphOf(tester, 'Due');
      final shown = tester.renderObject<RenderParagraph>(find.text(_tight));
      double baselineOf(RenderParagraph paragraph) =>
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      expect(baselineOf(shown), moreOrLessEquals(baselineOf(due)));
    });

    testWidgets('takes taps only on the words it shows', (tester) async {
      var taps = 0;
      await pumpThemed(tester, _fit(width: 80, onTap: () => taps++));
      await tester.tap(find.byType(MmFitWords));
      expect(taps, 1);
    });
  });
}
