import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../support/testing.dart';

/// The family of the Latin face as the spans name it.
const _latin = 'packages/mm_ui/${MmFontFamily.latin}';

Widget _label(String label) => Builder(
  builder: (context) => MmIconLabel(
    icon: MmIcons.warning,
    label: label,
    style: Theme.of(context).textTheme.labelLarge!,
    iconColor: context.mm.colors.overdue,
  ),
);

/// The words' paragraph of the [MmIconLabel] (the icon is a paragraph of
/// its own, inside it).
RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byType(MmIconLabel),
            matching: find.byType(RichText),
          )
          .first,
    );

/// The text spans of the label's words, after the icon.
List<TextSpan> _words(WidgetTester tester) {
  final words = <TextSpan>[];
  _paragraph(tester).text.visitChildren((span) {
    if (span is TextSpan && span.text != null) words.add(span);
    return true;
  });
  return words;
}

void main() {
  group('MmIconLabel by script', () {
    testWidgets('sets the figures among Urdu words in the Latin face, on the '
        'Urdu lines', (tester) async {
      await pumpThemed(
        tester,
        _label('12 دن سے واجب'),
        variant: MmVariant.urdu,
      );
      final words = _words(tester);
      expect(words.map((span) => span.text), ['12 ', 'دن سے واجب']);
      expect(words.first.style!.fontFamily, _latin);
      expect(words.last.style, isNull);
      expect(_paragraph(tester).text.style!.fontFamily, isNot(_latin));
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(MmIconLabel),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.strutStyle!.forceStrutHeight, isTrue);
    });

    testWidgets('sets a Latin-only label in the Latin face in Urdu', (
      tester,
    ) async {
      await pumpThemed(tester, _label('CNIC'), variant: MmVariant.urdu);
      expect(_words(tester).single.text, 'CNIC');
      expect(_paragraph(tester).text.style!.fontFamily, _latin);
    });

    testWidgets('leaves English labels whole', (tester) async {
      await pumpThemed(tester, _label('Overdue 12 days'));
      expect(_words(tester).single.text, 'Overdue 12 days');
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(MmIconLabel),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.strutStyle, isNull);
    });

    testWidgets('is still read as its words', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpThemed(
        tester,
        _label('12 دن سے واجب'),
        variant: MmVariant.urdu,
      );
      expect(find.bySemanticsLabel('12 دن سے واجب'), findsOneWidget);
      semantics.dispose();
    });
  });
}
