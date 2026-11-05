import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _label = 'Monthly rent';
const _value = 'Rs 45,000';
const _address = 'House 12, Street 4, Gulberg III, Lahore';

/// The distance from the top of the screen to [text]'s first baseline.
double _baseline(WidgetTester tester, String text) {
  final paragraph = paragraphOf(tester, text);
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

void main() {
  group('MmDetailRow', () {
    testEveryVariant('sets the label muted and the value in ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: _label, value: _value),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final label = styleOf(tester, _label);
      expect(label.color, colors.inkMuted);
      expect(label.fontSize, text.bodyMedium!.fontSize);
      final value = styleOf(tester, _value);
      expect(value.color, colors.ink);
      expect(value.fontSize, text.bodyLarge!.fontSize);
      expect(value.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    testWidgets('an emphasized row is a total in the title style', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(
          label: 'Total due',
          value: 'Rs 1,25,000',
          emphasized: true,
        ),
      );
      final titleMedium = MmVariant.light.theme.textTheme.titleMedium!;
      for (final text in ['Total due', 'Rs 1,25,000']) {
        final style = styleOf(tester, text);
        expect(style.color, MmColorModes.light.ink);
        expect(style.fontSize, titleMedium.fontSize);
        expect(style.fontWeight, titleMedium.fontWeight);
      }
    });

    testWidgets('puts the value at the end on the label baseline', (
      tester,
    ) async {
      await pumpThemed(tester, const MmDetailRow(label: _label, value: _value));
      final row = tester.getRect(find.byType(MmDetailRow));
      expect(tester.getRect(find.text(_label)).left, row.left);
      expect(tester.getRect(find.text(_value)).right, row.right);
      expect(
        _baseline(tester, _value),
        moreOrLessEquals(_baseline(tester, _label), epsilon: 0.01),
      );
      // The taller value starts at the top padding; the label drops to its
      // baseline.
      expect(tester.getRect(find.text(_value)).top, row.top + MmSpace.s2);
      expect(
        tester.getRect(find.text(_label)).top,
        greaterThan(row.top + MmSpace.s2),
      );
    });

    testWidgets('mirrors right to left', (tester) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: 'ماہانہ کرایہ', value: '45,000 روپے'),
        variant: MmVariant.urdu,
      );
      final row = tester.getRect(find.byType(MmDetailRow));
      expect(tester.getRect(find.text('ماہانہ کرایہ')).right, row.right);
      expect(tester.getRect(find.text('45,000 روپے')).left, row.left);
    });

    testWidgets('moves a value that does not fit under its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: 'Property', value: _address),
      );
      final label = tester.getRect(find.text('Property'));
      final value = tester.getRect(find.text(_address));
      expect(value.top, label.bottom + MmSpace.s1);
      expect(value.left, label.left);
    });

    testWidgets('at 200% on a 320 dp phone, wraps without overflowing', (
      tester,
    ) async {
      await pumpLargeNarrow(
        tester,
        const MmDetailRow(
          label: 'Property',
          value: _address,
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmDetailRow)).width, 288);
    });

    testWidgets('a trailing widget that does not fit goes under the value, '
        'which never breaks for it', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmDetailRow(
          label: 'October rent',
          value: _value,
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      final value = tester.getRect(find.text(_value));
      final badge = tester.getRect(find.byType(MmStatusBadge));
      // One line of 32 px text: the amount is not split.
      expect(value.height, lessThan(2 * 32));
      expect(badge.top, greaterThanOrEqualTo(value.top));

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: _label,
          value: _value,
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      final row = tester.getRect(find.byType(MmDetailRow));
      final beside = tester.getRect(find.byType(MmStatusBadge));
      expect(beside.right, row.right);
      expect(beside.left, greaterThan(tester.getRect(find.text(_value)).right));
    });

    testWidgets('is one node reading "label, value"', (tester) async {
      await pumpThemed(tester, const MmDetailRow(label: _label, value: _value));
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: '$_label, $_value'),
      );

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: _label,
          value: _value,
          semanticValue: '45000 rupees',
          trailing: MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MmDetailRow)),
        matchesSemantics(label: '$_label, 45000 rupees\nPaid'),
      );
    });

    testWidgets('sets Latin user data in the Latin face in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmDetailRow(label: 'کرایہ دار', value: 'Ali Raza'),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.latin),
      );

      await pumpThemed(
        tester,
        const MmDetailRow(
          label: 'کرایہ دار',
          value: 'Ali Raza',
          userData: false,
        ),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.urdu),
      );
    });
  });
}
