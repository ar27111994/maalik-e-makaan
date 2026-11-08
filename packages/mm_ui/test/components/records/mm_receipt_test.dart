import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';

import '../../support/testing.dart';
import 'support.dart';

const _rows = [
  MmReceiptRow(label: 'Tenant', value: 'Ali Raza'),
  MmReceiptRow(label: 'Period', value: 'October 2026'),
  MmReceiptRow(label: 'Late fee', value: 'Rs 500', semanticValue: '500 rupees'),
];
const _footer = 'Thank you. Keep this receipt for your records.';
const _void = 'VOID: cancelled on 12 Oct 2026';

Widget _receipt({
  Money amount = const Money.fromRupees(45000),
  List<MmReceiptRow> rows = _rows,
  String? footer = _footer,
  String? voidedLabel,
  String issuer = 'Ayesha Khan',
}) => SizedBox(
  width: 328,
  child: MmReceipt(
    issuer: issuer,
    numberLabel: 'Receipt no.',
    receiptNumber: 'R-2026-0142',
    amountLabel: 'Amount received',
    amount: amount,
    rows: rows,
    footer: footer,
    voidedLabel: voidedLabel,
  ),
);

/// Pumps [receipt] on a phone tall enough for a whole receipt at 200%.
Future<void> _pump(
  WidgetTester tester,
  Widget receipt, {
  MmVariant variant = MmVariant.light,
}) =>
    pumpThemed(tester, receipt, variant: variant, size: const Size(360, 1400));

/// The receipt's semantics node, which holds its parts.
SemanticsNode _node(WidgetTester tester) =>
    tester.getSemantics(find.byType(MmReceipt));

/// The seal's frame.
BoxDecoration _seal(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.text('Receipt no.'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('MmReceiptRow', () {
    test('is equal to a row with the same fields', () {
      const copy = MmReceiptRow(
        label: 'Late fee',
        value: 'Rs 500',
        semanticValue: '500 rupees',
      );
      expect(copy, _rows[2]);
      expect(copy.hashCode, _rows[2].hashCode);
      expect(copy, isNot(_rows[0]));
      expect(_rows[0].semanticValue, isNull);
    });
  });

  group('MmReceipt', () {
    testEveryVariant('is flat paper with a brass seal', (
      tester,
      variant,
    ) async {
      await _pump(tester, _receipt(), variant: variant);
      final colors = colorsOf(variant);
      final seal = _seal(tester);
      expect(seal.color, colors.brassContainer);
      expect(seal.border, Border.all(color: colors.brass, width: MmSize.frame));
      expect(seal.boxShadow, isNull);
      expect(styleOf(tester, 'R-2026-0142').color, colors.onBrassContainer);
      expect(styleOf(tester, 'Receipt no.').color, colors.onBrassContainer);
      // No shadow anywhere: paper does not float.
      for (final type in [PhysicalModel, PhysicalShape, Material]) {
        expect(
          find.descendant(
            of: find.byType(MmReceipt),
            matching: find.byType(type),
          ),
          findsNothing,
        );
      }
      expect(
        tester.renderObject(find.byType(MmReceipt)),
        paints
          ..path(color: colors.surface, style: PaintingStyle.fill)
          ..path(color: colors.rule, style: PaintingStyle.stroke),
      );
    });

    testWidgets('perforates the top edge and keeps the corners square', (
      tester,
    ) async {
      await _pump(tester, _receipt());
      final width = tester.getSize(find.byType(MmReceipt)).width;
      const r = MmReceipt.notchRadius;
      expect(
        tester.renderObject(find.byType(MmReceipt)),
        paints..path(
          color: MmColorModes.light.surface,
          // The corners are paper; the middle of the top edge is a notch
          // or the paper beside one.
          includes: [const Offset(0.5, 0.5), Offset(width - 0.5, 0.5)],
          excludes: [
            // The first notch is centred 3r in from the left edge (the
            // row of notches is centred, with a notch's width to spare).
            for (var i = 0; i < 3; i++)
              Offset(MmSpace.s2 + r + i * 4 * r, r / 2),
          ],
        ),
      );
    });

    testEveryVariant('shows the issuer, the number, the amount, the rows and '
        'the footer', (tester, variant) async {
      await _pump(tester, _receipt(), variant: variant);
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      expect(
        styleOf(tester, 'Ayesha Khan').fontSize,
        text.titleMedium!.fontSize,
      );
      final amount = styleOf(tester, '45,000');
      final semantics = variant.theme.extension<MmSemantics>()!;
      expect(amount.fontSize, semantics.amountLarge.fontSize);
      expect(amount.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(amount.decoration, isNot(TextDecoration.lineThrough));
      for (final row in _rows) {
        expect(styleOf(tester, row.label).color, colors.inkMuted);
        expect(styleOf(tester, row.value).color, colors.ink);
      }
      final footer = styleOf(tester, _footer);
      expect(footer.color, colors.inkMuted);
      expect(footer.fontSize, text.bodySmall!.fontSize);
      // The caption of the type scale, weight and all.
      expect(footer.fontWeight, text.bodySmall!.fontWeight);
      expect(footer.fontWeight, FontWeight.w400);
      expect(find.text(_void), findsNothing);
    });

    testWidgets('formats the amount as the landlord set it', (tester) async {
      await _pump(tester, _receipt(amount: const Money.fromRupees(125000)));
      expect(find.text('Rs\u00A0125,000'), findsOneWidget);

      await _pump(
        tester,
        MmFormats(
          money: const MoneyFormat(grouping: DigitGrouping.southAsian),
          child: _receipt(amount: const Money.fromRupees(125000)),
        ),
      );
      expect(find.text('Rs\u00A01,25,000'), findsOneWidget);

      await _pump(tester, _receipt(), variant: MmVariant.urdu);
      expect(find.text('45,000\u00A0روپے'), findsOneWidget);
      expect(styleOf(tester, '45,000').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
    });

    testWidgets('keeps a minus sign before the digits in Urdu', (tester) async {
      await _pump(
        tester,
        _receipt(amount: const Money.fromRupees(-5000)),
        variant: MmVariant.urdu,
      );
      expect(find.text('‎-5,000\u00A0روپے'), findsOneWidget);
    });

    testWidgets('reads issuer, number, amount, rows and footer in order', (
      tester,
    ) async {
      await _pump(tester, _receipt());
      expect(readingOrder(_node(tester)), [
        'Ayesha Khan',
        'Receipt no. R-2026-0142',
        'Amount received, 45000 rupees',
        'Tenant, Ali Raza',
        'Period, October 2026',
        'Late fee, 500 rupees',
        _footer,
      ]);
      expect(
        tester.getSemantics(find.textContaining('Ayesha Khan')),
        matchesSemantics(label: 'Ayesha Khan', isHeader: true),
      );
      expect(
        tester.getSemantics(find.textContaining('R-2026-0142')),
        matchesSemantics(label: 'Receipt no. R-2026-0142'),
      );
    });

    testWidgets('reads the voided state right after the receipt number, '
        'where it is shown, before the amount', (tester) async {
      await _pump(tester, _receipt(voidedLabel: _void));
      expect(readingOrder(_node(tester)), [
        'Ayesha Khan',
        'Receipt no. R-2026-0142',
        _void,
        'Amount received, 45000 rupees',
        'Tenant, Ali Raza',
        'Period, October 2026',
        'Late fee, 500 rupees',
        _footer,
      ]);
      expect(
        tester.getRect(find.textContaining(_void, findRichText: true)).bottom,
        lessThan(tester.getRect(find.text('Amount received')).top),
      );
    });

    testWidgets('says amounts as plain numbers, with paisa when shown', (
      tester,
    ) async {
      await _pump(tester, _receipt(amount: const Money.fromPaisa(4500050)));
      expect(find.text('Rs\u00A045,000.50'), findsOneWidget);
      expect(
        readingOrder(_node(tester)),
        contains('Amount received, 45000.50 rupees'),
      );

      await _pump(
        tester,
        MmFormats(
          money: const MoneyFormat(paisa: PaisaDisplay.never),
          child: _receipt(amount: const Money.fromPaisa(4500050)),
        ),
      );
      expect(find.text('Rs\u00A045,001'), findsOneWidget);
      expect(
        readingOrder(_node(tester)),
        contains('Amount received, 45001 rupees'),
      );

      await _pump(tester, _receipt(), variant: MmVariant.urdu);
      expect(
        readingOrder(_node(tester)),
        contains('Amount received، 45000 روپے'),
      );
    });

    testEveryVariant('a void receipt shows a banner in words and strikes '
        'the amount through', (tester, variant) async {
      await _pump(tester, _receipt(voidedLabel: _void), variant: variant);
      final colors = colorsOf(variant);
      final banner =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.textContaining(_void, findRichText: true),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(banner.color, colors.overdueContainer);
      expect(
        banner.border,
        Border.all(color: colors.overdue, width: MmSize.frame),
      );
      expect(find.byIcon(MmIcons.error), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(MmIcons.error)).color,
        colors.onOverdueContainer,
      );
      final amount = styleOf(tester, '45,000');
      expect(amount.decoration, TextDecoration.lineThrough);
      expect(amount.decorationColor, colors.overdue);
      final banded = tester.getRect(
        find.textContaining(_void, findRichText: true),
      );
      expect(
        banded.top,
        greaterThan(tester.getRect(find.textContaining('Ayesha Khan')).bottom),
      );
    });

    testWidgets('puts the seal at the top end, mirrored in Urdu', (
      tester,
    ) async {
      await _pump(tester, _receipt());
      var receipt = tester.getRect(find.byType(MmReceipt));
      var seal = tester.getRect(
        find
            .ancestor(
              of: find.text('Receipt no.'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(seal.right, receipt.right - MmSpace.s4);
      expect(seal.top, tester.getRect(find.textContaining('Ayesha Khan')).top);
      expect(
        tester.getRect(find.textContaining('Ayesha Khan')).left,
        receipt.left + MmSpace.s4,
      );

      await _pump(tester, _receipt(), variant: MmVariant.urdu);
      receipt = tester.getRect(find.byType(MmReceipt));
      seal = tester.getRect(
        find
            .ancestor(
              of: find.text('Receipt no.'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(seal.left, receipt.left + MmSpace.s4);
      expect(
        tester.getRect(find.textContaining('Ayesha Khan')).right,
        receipt.right - MmSpace.s4,
      );
      expect(
        tester.getRect(find.textContaining('Ali Raza')).left,
        receipt.left + MmSpace.s4,
      );
    });

    testWidgets('moves a long value under its label', (tester) async {
      await _pump(
        tester,
        _receipt(
          rows: const [
            MmReceiptRow(
              label: 'Property',
              value: 'House 12, Street 4, Gulberg III, Lahore',
            ),
          ],
        ),
      );
      final label = tester.getRect(find.text('Property'));
      final value = tester.getRect(
        find.text('House 12, Street 4, Gulberg III, Lahore'),
      );
      expect(value.top, greaterThan(label.bottom));
      // Under its label the value keeps to the end edge, where values
      // beside their labels end.
      final row = tester.getRect(
        find.ancestor(
          of: find.text('Property'),
          matching: find.byType(MmReflow),
        ),
      );
      expect(value.right, row.right);
    });

    testWidgets("at 200% the rows' values end on one edge", (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        _receipt(
          rows: const [
            MmReceiptRow(label: 'Tenant', value: 'Ali Raza'),
            MmReceiptRow(label: 'Period', value: 'October 2026'),
            MmReceiptRow(label: 'Late fee', value: 'Rs\u00A0500'),
          ],
        ),
        height: 1400,
        then: (locale) {
          final row = tester.getRect(
            find
                .ancestor(
                  of: find.text('Tenant'),
                  matching: find.byType(MmReflow),
                )
                .first,
          );
          final values = [
            for (final value in ['Ali Raza', 'October 2026', 'Rs\u00A0500'])
              tester.getRect(find.textContaining(value)),
          ];
          final labels = [
            for (final label in ['Tenant', 'Period', 'Late fee'])
              tester.getRect(find.text(label)),
          ];
          expect([
            for (final (index, value) in values.indexed)
              value.top >= labels[index].bottom,
          ], containsAll([true, false]));
          for (final value in values) {
            if (locale.languageCode == 'ur') {
              expect(value.left, moreOrLessEquals(row.left));
            } else {
              expect(value.right, moreOrLessEquals(row.right));
            }
          }
        },
      );
    });

    testWidgets('without rows or a footer, shows just the amount', (
      tester,
    ) async {
      await _pump(tester, _receipt(rows: const [], footer: null));
      expect(readingOrder(_node(tester)), [
        'Ayesha Khan',
        'Receipt no. R-2026-0142',
        'Amount received, 45000 rupees',
      ]);
      final receipt = tester.getRect(find.byType(MmReceipt));
      expect(
        receipt.bottom,
        tester.getRect(find.text('Rs\u00A045,000')).bottom + MmSpace.s4,
      );
    });

    testWidgets('with a footer and no rows, ends with the footer', (
      tester,
    ) async {
      await _pump(tester, _receipt(rows: const []));
      expect(readingOrder(_node(tester)), [
        'Ayesha Khan',
        'Receipt no. R-2026-0142',
        'Amount received, 45000 rupees',
        _footer,
      ]);
      final receipt = tester.getRect(find.byType(MmReceipt));
      final footer = tester.getRect(find.text(_footer));
      expect(receipt.bottom, footer.bottom + MmSpace.s4);
      expect(
        tester.getRect(find.text('Rs\u00A045,000')).bottom,
        lessThan(footer.top),
      );
    });

    testWidgets('at 200% on a 320 dp phone, fits long words in English and '
        'Urdu, with rows or with only a footer', (tester) async {
      Widget receipt({required bool rows}) => Builder(
        builder: (context) {
          final say = sayIn(context);
          return MmReceipt(
            issuer: say(
              'Gulberg Residency Management',
              'گلبرگ ریزیڈنسی مینجمنٹ',
            ),
            numberLabel: say('Receipt no.', 'رسید نمبر'),
            receiptNumber: 'R-2026-0142',
            amountLabel: say('Amount received', 'وصول شدہ رقم'),
            amount: const Money.fromRupees(12500000),
            rows: [
              if (rows) ...[
                MmReceiptRow(
                  label: say('Property', 'جائیداد'),
                  value: say(
                    'House 12, Street 4, Gulberg III, Lahore',
                    'مکان 12، گلی 4، گلبرگ III، لاہور',
                  ),
                ),
                MmReceiptRow(
                  label: say('Period', 'مدت'),
                  value: say('July to September 2026', 'جولائی تا ستمبر 2026'),
                ),
              ],
            ],
            footer: say(
              'Thank you. Keep this receipt for your records.',
              'شکریہ۔ یہ رسید اپنے ریکارڈ کے لیے سنبھال کر رکھیں۔',
            ),
            voidedLabel: say(
              'VOID: cancelled on 12 Oct 2026',
              'کالعدم: 12 اکتوبر 2026 کو منسوخ',
            ),
          );
        },
      );
      await expectFitsNarrowLargeText(
        tester,
        receipt(rows: true),
        height: 1600,
      );
      await expectFitsNarrowLargeText(tester, receipt(rows: false));
    });

    testWidgets('sets the figures inside an Urdu row value in the Latin face', (
      tester,
    ) async {
      const value = 'مکان 12، گلبرگ III، لاہور';
      await _pump(
        tester,
        _receipt(
          rows: const [
            MmReceiptRow(label: 'جائیداد', value: value),
            MmReceiptRow(label: 'جرمانہ', value: '500\u00A0روپے'),
          ],
          footer: 'رسید 12 ماہ تک سنبھال کر رکھیں۔',
        ),
        variant: MmVariant.urdu,
      );
      expect(latinRunsIn(tester, value), ['12', 'III']);
      expect(latinRunsIn(tester, '500\u00A0روپے'), ['500']);
      expect(latinRunsIn(tester, 'رسید 12 ماہ'), ['12']);
      expect(styleOf(tester, value).fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
    });

    testWidgets('at 200% on a 320 dp phone, stacks and wraps without '
        'overflowing, and the amount stays on one line', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmReceipt(
          issuer: 'Gulberg Residency Management',
          numberLabel: 'Receipt no.',
          receiptNumber: 'R-2026-0142',
          amountLabel: 'Amount received',
          amount: Money.fromRupees(12500000),
          rows: [
            MmReceiptRow(
              label: 'Property',
              value: 'House 12, Street 4, Gulberg III, Lahore',
            ),
            ..._rows,
          ],
          footer: _footer,
          voidedLabel: _void,
        ),
        height: 1600,
      );
      expect(tester.takeException(), isNull);
      final receipt = tester.getRect(find.byType(MmReceipt));
      expect(receipt.width, 288);
      final amount = tester.getRect(find.text('Rs\u00A012,500,000'));
      expect(amount.width, lessThanOrEqualTo(288 - 2 * MmSpace.s4));
      expect(amount.height, lessThan(2 * 40 * 2));
      // The seal moves under the issuer, still at the end.
      final seal = tester.getRect(
        find
            .ancestor(
              of: find.text('Receipt no.'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        seal.top,
        greaterThan(
          tester.getRect(find.text('Gulberg Residency Management')).bottom,
        ),
      );
      expect(seal.right, receipt.right - MmSpace.s4);
    });

    testWidgets('repaints its paper when the theme changes', (tester) async {
      await _pump(tester, _receipt());
      await _pump(tester, _receipt(), variant: MmVariant.dark);
      expect(
        tester.renderObject(find.byType(MmReceipt)),
        paints..path(color: MmColorModes.dark.surface),
      );
    });

    testWidgets('sets an issuer written in Urdu with Nastaliq in the '
        'English UI', (tester) async {
      await _pump(tester, _receipt(issuer: 'عائشہ خان'));
      expect(styleOf(tester, 'عائشہ خان').fontFamilyFallback, [
        'packages/mm_ui/${MmFontFamily.urdu}',
      ]);
      await _pump(tester, _receipt(), variant: MmVariant.urdu);
      expect(
        styleOf(tester, 'Ayesha Khan').fontFamily,
        contains(MmFontFamily.latin),
      );
      expect(
        styleOf(tester, 'R-2026-0142').fontFamily,
        contains(MmFontFamily.latin),
      );
    });
  });
}
