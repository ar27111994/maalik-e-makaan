import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';

import '../support/testing.dart';

/// The family of the Latin face as the spans name it.
const _latin = 'packages/mm_ui/${MmFontFamily.latin}';

/// The spans of the paragraph that shows [text].
List<InlineSpan> _spansOf(WidgetTester tester, String text) {
  final root = paragraphOf(tester, text).text as TextSpan;
  final spans = <InlineSpan>[];
  root.visitChildren((span) {
    if (span != root) spans.add(span);
    return true;
  });
  return spans;
}

void main() {
  group('MmScriptText.runsOf', () {
    test('cuts Latin letters and figures out of Urdu text', () {
      expect(MmScriptText.runsOf('45,000 روپے'), [
        (text: '45,000 ', latin: true),
        (text: 'روپے', latin: false),
      ]);
      expect(MmScriptText.runsOf('مکان 12، Gulberg III، لاہور'), [
        (text: 'مکان', latin: false),
        (text: ' 12', latin: true),
        (text: '،', latin: false),
        (text: ' Gulberg III', latin: true),
        (text: '، لاہور', latin: false),
      ]);
    });

    test('sets the spaces between Urdu and Latin words in the Latin face, '
        "so they keep the Latin space's width", () {
      // Nastaliq's space is about half as wide as Atkinson's: beside a
      // Latin name it looked like no space at all.
      expect(MmScriptText.runsOf('از Bilal Ahmed بنام'), [
        (text: 'از', latin: false),
        (text: ' Bilal Ahmed ', latin: true),
        (text: 'بنام', latin: false),
      ]);
      // Through the isolate a name is shown in.
      expect(MmScriptText.runsOf('از \u2066Bilal\u2069 بنام'), [
        (text: 'از', latin: false),
        (text: ' \u2066Bilal\u2069 ', latin: true),
        (text: 'بنام', latin: false),
      ]);
      // Punctuation stays with the Urdu, and so does a space after it.
      expect(MmScriptText.runsOf('Gulberg III، لاہور'), [
        (text: 'Gulberg III', latin: true),
        (text: '، لاہور', latin: false),
      ]);
    });

    test("keeps Urdu's own figures and punctuation with the Urdu", () {
      expect(MmScriptText.runsOf('۴۵ دن۔'), [(text: '۴۵ دن۔', latin: false)]);
    });

    test('a text in one script is one run', () {
      expect(MmScriptText.runsOf('Rs 45,000'), [
        (text: 'Rs 45,000', latin: true),
      ]);
      expect(MmScriptText.runsOf('علی رضا'), [(text: 'علی رضا', latin: false)]);
      expect(MmScriptText.runsOf(''), isEmpty);
    });
  });

  group('MmScriptText', () {
    testWidgets('sets the figures inside Urdu text in the Latin face, on '
        'the Urdu lines', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MmScriptText(
            '45,000 روپے',
            style: Theme.of(context).textTheme.bodyLarge!,
          ),
        ),
        variant: MmVariant.urdu,
      );
      final spans = _spansOf(tester, '45,000 روپے');
      expect(spans, hasLength(2));
      expect((spans[0] as TextSpan).text, '45,000 ');
      expect(spans[0].style!.fontFamily, _latin);
      expect((spans[1] as TextSpan).text, 'روپے');
      expect(spans[1].style, isNull);
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.byType(MmScriptText),
          matching: find.byType(RichText),
        ),
      );
      expect(text.strutStyle!.forceStrutHeight, isTrue);
    });

    testWidgets('keeps a whole Latin space between Urdu words and a Latin '
        'name', (tester) async {
      const text = 'از Bilal Ahmed بنام';
      await pumpThemed(
        tester,
        Builder(
          builder: (context) =>
              MmScriptText(text, style: Theme.of(context).textTheme.bodyLarge!),
        ),
        variant: MmVariant.urdu,
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      double widthAt(int index) => paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          )
          .single
          .toRect()
          .width;
      // Nastaliq's own space is about half as wide; the Latin face's
      // metrics shift the last digit of a width by a fraction of a pixel.
      final between = widthAt(text.indexOf(' Ahmed'));
      expect(widthAt(text.indexOf(' Bilal')), closeTo(between, 0.5));
      expect(widthAt(text.indexOf(' بنام')), closeTo(between, 0.5));
    });

    for (final variant in [MmVariant.light, MmVariant.urdu]) {
      testWidgets('draws the narrow no-break space intl puts before AM and '
          'PM as a no-break space (${variant.name})', (tester) async {
        for (final text in ['10:42\u202FAM', 'آج، 10:42\u202FAM']) {
          await pumpThemed(
            tester,
            Builder(
              builder: (context) => MmScriptText(
                text,
                style: Theme.of(context).textTheme.bodyLarge!,
              ),
            ),
            variant: variant,
          );
          final shown = tester
              .renderObject<RenderParagraph>(find.byType(RichText))
              .text
              .toPlainText();
          expect(shown, text.replaceAll('\u202F', '\u00A0'));
        }
      });
    }

    testWidgets('sets Latin-only text whole in the Latin face in Urdu', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MmScriptText(
            'Ali Raza',
            style: Theme.of(context).textTheme.bodyLarge!,
          ),
        ),
        variant: MmVariant.urdu,
      );
      expect(styleOf(tester, 'Ali Raza').fontFamily, _latin);
    });

    testWidgets('leaves English text as it is', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MmScriptText(
            'Rs 45,000 from علی',
            style: Theme.of(context).textTheme.bodyLarge!,
          ),
        ),
      );
      expect(_spansOf(tester, 'Rs 45,000 from علی'), isEmpty);
    });

    for (final variant in [MmVariant.light, MmVariant.urdu]) {
      testWidgets('cuts lines at maxLines and reads its semantics label '
          '(${variant.name})', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpThemed(
          tester,
          Builder(
            builder: (context) => SizedBox(
              width: 80,
              child: MmScriptText(
                'مکان 12، Gulberg III، لاہور، پاکستان',
                style: Theme.of(context).textTheme.bodyLarge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: 'House 12',
              ),
            ),
          ),
          variant: variant,
        );
        final paragraph = paragraphOf(tester, 'مکان');
        expect(paragraph.maxLines, 1);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(find.bySemanticsLabel('House 12'), findsOneWidget);
        semantics.dispose();
      });
    }
  });

  group('MmScriptText.spansOf', () {
    testWidgets('is null outside the Urdu UI and for text in one script', (
      tester,
    ) async {
      ({List<InlineSpan> spans, StrutStyle strut})? english;
      ({List<InlineSpan> spans, StrutStyle strut})? urduOnly;
      ({List<InlineSpan> spans, StrutStyle strut})? mixed;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            english = MmScriptText.spansOf(
              context,
              '45,000 روپے',
              const TextStyle(),
            );
            return const SizedBox();
          },
        ),
      );
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            urduOnly = MmScriptText.spansOf(
              context,
              'علی رضا',
              const TextStyle(),
            );
            mixed = MmScriptText.spansOf(context, '12 دن', const TextStyle());
            return const SizedBox();
          },
        ),
        variant: MmVariant.urdu,
      );
      expect(english, isNull);
      expect(urduOnly, isNull);
      expect(mixed!.spans, hasLength(2));
    });
  });
}
