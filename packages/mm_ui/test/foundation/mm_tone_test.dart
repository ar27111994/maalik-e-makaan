import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_tone.dart';
import 'package:mm_ui/src/foundation/mm_tone_chip.dart';

import '../support/testing.dart';

void main() {
  group('MmTone', () {
    for (final variant in MmVariant.values) {
      test('maps every tone to its colour roles (${variant.name})', () {
        final c = variant.colors;
        final expected = {
          MmTone.neutral: (c.inkMuted, c.surfaceSunken, c.ink),
          MmTone.primary: (c.primary, c.primaryContainer, c.onPrimaryContainer),
          MmTone.paid: (c.paid, c.paidContainer, c.onPaidContainer),
          MmTone.dueSoon: (c.dueSoon, c.dueSoonContainer, c.onDueSoonContainer),
          MmTone.overdue: (c.overdue, c.overdueContainer, c.onOverdueContainer),
          MmTone.credit: (c.credit, c.creditContainer, c.onCreditContainer),
        };
        expect(expected.keys, unorderedEquals(MmTone.values));
        for (final MapEntry(key: tone, value: colors) in expected.entries) {
          expect(tone.colorIn(c), colors.$1, reason: tone.name);
          expect(tone.containerIn(c), colors.$2, reason: tone.name);
          expect(tone.onContainerIn(c), colors.$3, reason: tone.name);
        }
      });
    }
  });

  group('MmToneChip', () {
    Widget chip({String label = 'Overdue 12 days'}) => Align(
      alignment: AlignmentDirectional.topStart,
      child: MmToneChip(
        tone: MmTone.overdue,
        icon: MmIcons.warning,
        label: label,
      ),
    );

    testEveryVariant('is the tone container with words and icon in its '
        'on-container colour', (tester, variant) async {
      await pumpThemed(tester, chip(), variant: variant);
      final colors = colorsOf(variant);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(MmToneChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, colors.overdueContainer);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.xs)),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(MmToneChip),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(paragraph.text.style!.color, colors.onOverdueContainer);
      final glyph = tester.widget<Icon>(find.byIcon(MmIcons.warning));
      expect(glyph.color, colors.onOverdueContainer);
    });

    testWidgets('keeps as wide as its longest line once its words wrap', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 120,
          child: chip(label: 'Overdue since the fifth of October'),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(MmToneChip),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
      expect(tester.getSize(find.byType(MmToneChip)).width, lessThan(120));
    });

    testWidgets('adds no semantics node of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpThemed(
        tester,
        Semantics(container: true, label: 'Rent', child: chip()),
      );
      final node = tester.getSemantics(find.byType(MmToneChip));
      expect(node.label, contains('Overdue 12 days'));
      expect(node.label, contains('Rent'));
      semantics.dispose();
    });
  });
}
