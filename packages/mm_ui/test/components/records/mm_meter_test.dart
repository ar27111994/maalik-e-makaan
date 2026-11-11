import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _label = 'Rent collected';
const _value = 'Rs 90,000 of Rs 1,25,000';

Widget _meter({
  double value = 0.72,
  String label = _label,
  String valueLabel = _value,
  String? semanticValue,
  MmMeterTone tone = MmMeterTone.primary,
}) => SizedBox(
  width: 296,
  child: MmMeter(
    value: value,
    label: label,
    valueLabel: valueLabel,
    semanticValue: semanticValue,
    tone: tone,
  ),
);

Finder get _fillBox => find.descendant(
  of: find.byType(FractionallySizedBox),
  matching: find.byType(DecoratedBox),
);

Finder get _track => find
    .ancestor(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    )
    .first;

Color _colorOf(WidgetTester tester, Finder box) =>
    (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color!;

void main() {
  group('MmMeterTone', () {
    test('fills with the tone colour on its container in every mode', () {
      for (final colors in [
        MmColorModes.light,
        MmColorModes.dark,
        MmColorModes.lightHighContrast,
        MmColorModes.darkHighContrast,
      ]) {
        expect(MmMeterTone.primary.fillIn(colors), colors.primary);
        expect(MmMeterTone.primary.trackIn(colors), colors.primaryContainer);
        expect(MmMeterTone.paid.fillIn(colors), colors.paid);
        expect(MmMeterTone.paid.trackIn(colors), colors.paidContainer);
        expect(MmMeterTone.dueSoon.fillIn(colors), colors.dueSoon);
        expect(MmMeterTone.dueSoon.trackIn(colors), colors.dueSoonContainer);
        expect(MmMeterTone.overdue.fillIn(colors), colors.overdue);
        expect(MmMeterTone.overdue.trackIn(colors), colors.overdueContainer);
      }
    });

    test('agrees with the status colours of the same name', () {
      const colors = MmColorModes.light;
      for (final (tone, status) in [
        (MmMeterTone.paid, MmStatus.paid),
        (MmMeterTone.dueSoon, MmStatus.dueSoon),
        (MmMeterTone.overdue, MmStatus.overdue),
      ]) {
        expect(tone.fillIn(colors), status.colorIn(colors));
        expect(tone.trackIn(colors), status.containerIn(colors));
      }
    });
  });

  group('MmMeter', () {
    testEveryVariant('sets the label in ink above a bar in the tone', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        _meter(tone: MmMeterTone.paid),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final label = styleOf(tester, _label);
      expect(label.color, colors.ink);
      expect(label.fontSize, text.labelLarge!.fontSize);
      final value = styleOf(tester, _value);
      expect(value.color, colors.inkMuted);
      expect(value.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(_colorOf(tester, _fillBox), colors.paid);
      expect(_colorOf(tester, _track), colors.paidContainer);
      final bar = tester.getRect(_track);
      expect(bar.height, MmMeter.barHeight);
      expect(bar.top, greaterThan(tester.getRect(find.text(_label)).bottom));
      final decoration =
          tester.widget<DecoratedBox>(_track).decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.xs)),
      );
      expect(decoration.boxShadow, isNull);
      // A hairline in the outline colour shows the whole the fill is a
      // share of: the tonal track alone is barely distinct from the paper.
      expect(decoration.border, Border.all(color: colors.outline));
    });

    testWidgets('puts the value at the end of the label line', (tester) async {
      await pumpThemed(tester, _meter(valueLabel: '8 of 10'));
      final meter = tester.getRect(find.byType(MmMeter));
      expect(tester.getRect(find.text(_label)).left, meter.left);
      expect(tester.getRect(find.text('8 of 10')).right, meter.right);
    });

    testWidgets('fills from the start edge', (tester) async {
      await pumpThemed(tester, _meter());
      final track = tester.getRect(_track);
      final fill = tester.getRect(_fillBox);
      expect(fill.left, track.left);
      expect(fill.width, moreOrLessEquals(track.width * 0.72, epsilon: 0.01));
    });

    testWidgets('fills from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _meter(label: 'جو کرایہ ملا', valueLabel: '10 میں سے 8'),
        variant: MmVariant.urdu,
      );
      final track = tester.getRect(_track);
      final fill = tester.getRect(_fillBox);
      expect(fill.right, track.right);
      expect(fill.width, moreOrLessEquals(track.width * 0.72, epsilon: 0.01));
      final meter = tester.getRect(find.byType(MmMeter));
      expect(tester.getRect(find.text('جو کرایہ ملا')).right, meter.right);
    });

    testWidgets('clamps values outside 0 to 1, and shows nothing for NaN', (
      tester,
    ) async {
      double widthFactor() => tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;
      await pumpThemed(tester, _meter(value: 1.4));
      expect(widthFactor(), 1);
      await pumpThemed(tester, _meter(value: -0.3));
      expect(widthFactor(), 0);
      await pumpThemed(tester, _meter(value: double.nan));
      expect(widthFactor(), 0);
    });

    testWidgets('animates a change of value', (tester) async {
      await pumpThemed(tester, _meter(value: 0.2));
      final track = tester.getRect(_track);
      await tester.pumpWidget(themed(_meter(value: 0.8)));
      await tester.pump(MmDuration.standard ~/ 4);
      final midway = tester.getRect(_fillBox).width;
      expect(midway, greaterThan(track.width * 0.2));
      expect(midway, lessThan(track.width * 0.8));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_fillBox).width,
        moreOrLessEquals(track.width * 0.8, epsilon: 0.01),
      );
    });

    testWidgets('jumps to a new value when motion is reduced', (tester) async {
      await pumpThemed(tester, withoutAnimations(_meter(value: 0.2)));
      final track = tester.getRect(_track);
      await tester.pumpWidget(themed(withoutAnimations(_meter(value: 0.8))));
      await tester.pump();
      expect(
        tester.getRect(_fillBox).width,
        moreOrLessEquals(track.width * 0.8, epsilon: 0.01),
      );
    });

    testWidgets('is one node reading the label and the value', (tester) async {
      await pumpThemed(tester, _meter());
      expect(
        tester.getSemantics(find.byType(MmMeter)),
        matchesSemantics(label: _label, value: _value),
      );
    });

    testWidgets('reads the semantic value in place of the shown one', (
      tester,
    ) async {
      const spoken = '90000 rupees of 125000 rupees';
      await pumpThemed(tester, _meter(semanticValue: spoken));
      expect(
        tester.getSemantics(find.byType(MmMeter)),
        matchesSemantics(label: _label, value: spoken),
      );
      // The figures as shown stay on screen.
      expect(find.text(_value), findsOneWidget);
    });

    testWidgets('moves a value that does not fit under its label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _meter(valueLabel: 'Rs 45,000 of Rs 1,25,000 this month'),
      );
      final label = tester.getRect(find.text(_label));
      final value = tester.getRect(find.textContaining('this month'));
      expect(value.top, greaterThan(label.bottom));
      // Under its label the value keeps to the end edge, where values
      // beside their labels end.
      expect(value.right, tester.getRect(find.byType(MmMeter)).right);
    });

    testWidgets('at 200% a column of meters ends its values on one edge', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const Column(
          children: [
            MmMeter(value: 0.8, label: 'Units', valueLabel: '8 of 10'),
            MmMeter(value: 0.72, label: _label, valueLabel: _value),
          ],
        ),
        then: (locale) {
          final meter = tester.getRect(find.byType(MmMeter).first);
          final short = tester.getRect(find.text('8 of 10'));
          final long = tester.getRect(find.text(_value));
          // One value fits beside its label, the other moves under it.
          expect(
            short.top,
            lessThan(tester.getRect(find.text('Units')).bottom),
          );
          expect(
            long.top,
            greaterThanOrEqualTo(tester.getRect(find.text(_label)).bottom),
          );
          for (final value in [short, long]) {
            if (locale.languageCode == 'ur') {
              expect(value.left, moreOrLessEquals(meter.left));
            } else {
              expect(value.right, moreOrLessEquals(meter.right));
            }
          }
        },
      );
    });

    testWidgets('at 200% on a 320 dp phone, wraps without overflowing', (
      tester,
    ) async {
      await pumpLargeNarrow(
        tester,
        const MmMeter(
          value: 0.36,
          label: 'Overdue rent this month',
          valueLabel: _value,
          tone: MmMeterTone.overdue,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmMeter)).width, 288);
      expect(tester.getRect(_fillBox).width, closeTo(288 * 0.36, 0.01));
    });

    testWidgets('at 200% on a 320 dp phone, fits long words in English and '
        'Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final say = sayIn(context);
            return MmMeter(
              value: 0.36,
              label: say(
                'Overdue rent across all properties this month',
                'اس مہینے سب جائیدادوں کا لیٹ کرایہ',
              ),
              valueLabel: say(
                'Rs\u00A045,000 of Rs\u00A01,25,000',
                '1,25,000\u00A0روپے میں سے 45,000\u00A0روپے',
              ),
              tone: MmMeterTone.overdue,
            );
          },
        ),
      );
    });

    testWidgets('sets the figures inside an Urdu value in the Latin face', (
      tester,
    ) async {
      const value = '1,25,000 میں سے 90,000\u00A0روپے';
      await pumpThemed(
        tester,
        _meter(label: 'جو کرایہ ملا', valueLabel: value),
        variant: MmVariant.urdu,
      );
      expect(latinRunsIn(tester, value), ['1,25,000 ', ' 90,000\u00A0']);
      expect(urduRunsIn(tester, value), ['میں سے', 'روپے']);
      // Tabular figures, on the Urdu style's line: figures do not make the
      // line taller.
      expect(styleOf(tester, value).fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
      final body = MmVariant.urdu.theme.textTheme.bodyMedium!;
      expect(
        tester.getSize(find.textContaining(value, findRichText: true)).height,
        moreOrLessEquals(body.fontSize! * body.height!, epsilon: 0.01),
      );
    });

    testWidgets('sets Latin figures in the Latin face in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _meter(label: 'کرائے پر دیے گئے یونٹ', valueLabel: '8/10'),
        variant: MmVariant.urdu,
      );
      expect(styleOf(tester, '8/10').fontFamily, contains(MmFontFamily.latin));
      expect(
        styleOf(tester, 'کرائے پر دیے گئے یونٹ').fontFamily,
        contains(MmFontFamily.urdu),
      );
    });

    testWidgets('falls back to Nastaliq for Urdu words in the English UI', (
      tester,
    ) async {
      await pumpThemed(tester, _meter(valueLabel: 'رضا منزل'));
      expect(styleOf(tester, 'رضا منزل').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
      // The theme gives Latin text the same fallback.
      expect(styleOf(tester, _label).fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
    });
  });
}
