import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _rent = Money.fromRupees(45000);
const _advance = Money.fromRupees(-5000);

/// The text MmAmount paints.
String _shown(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byType(MmAmount), matching: find.byType(Text)),
    )
    .data!;

/// The style MmAmount paints in.
TextStyle _style(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byType(MmAmount), matching: find.byType(Text)),
    )
    .style!;

String _label(WidgetTester tester) =>
    tester.getSemantics(find.byType(MmAmount)).label;

void main() {
  group('MmAmount', () {
    testWidgets('formats with the default money format of the language', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmAmount(amount: Money.fromRupees(125000)),
      );
      expect(_shown(tester), 'Rs 125,000');
      await pumpThemed(
        tester,
        const MmAmount(amount: Money.fromRupees(125000)),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '125,000 روپے');
    });

    testWidgets('formats with the money format the app sets', (tester) async {
      await pumpThemed(
        tester,
        const MmFormats(
          money: MoneyFormat(grouping: DigitGrouping.southAsian),
          child: MmAmount(amount: Money.fromRupees(125000)),
        ),
      );
      expect(_shown(tester), 'Rs 1,25,000');
      await pumpThemed(
        tester,
        const MmFormats(
          money: MoneyFormat(notation: MoneyNotation.compact),
          child: MmAmount(amount: Money.fromRupees(12500000)),
        ),
      );
      expect(_shown(tester), 'Rs 1.25 crore');
      expect(_label(tester), '12500000 rupees');
    });

    testEveryVariant('sets each size in the Latin face with tabular figures', (
      tester,
      variant,
    ) async {
      final semantics = variant.theme.extension<MmSemantics>()!;
      final sizes = {
        MmAmountSize.large: semantics.amountLarge,
        MmAmountSize.regular: semantics.amount,
        MmAmountSize.small: MmTypeScale.latinBodySmall,
      };
      for (final MapEntry(key: size, value: expected) in sizes.entries) {
        await pumpThemed(
          tester,
          MmAmount(amount: _rent, size: size),
          variant: variant,
        );
        final style = _style(tester);
        expect(style.fontSize, expected.fontSize, reason: size.name);
        expect(style.fontWeight, expected.fontWeight, reason: size.name);
        expect(style.fontFamily, contains(MmFontFamily.latin));
        expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
        // The Urdu currency word falls back to Nastaliq.
        expect(style.fontFamilyFallback, [
          'packages/mm_ui/${MmFontFamily.urdu}',
        ]);
      }
      expect(const MmAmount(amount: _rent).size, MmAmountSize.regular);
    });

    testEveryVariant('sets each tone in its colour', (tester, variant) async {
      final colors = colorsOf(variant);
      final tones = {
        MmAmountTone.ink: colors.ink,
        MmAmountTone.muted: colors.inkMuted,
        MmAmountTone.paid: colors.paid,
        MmAmountTone.overdue: colors.overdue,
        MmAmountTone.credit: colors.credit,
      };
      for (final MapEntry(key: tone, value: color) in tones.entries) {
        expect(tone.colorIn(colors), color);
        await pumpThemed(
          tester,
          MmAmount(amount: _rent, tone: tone),
          variant: variant,
        );
        expect(_style(tester).color, color, reason: tone.name);
      }
      expect(const MmAmount(amount: _rent).tone, MmAmountTone.ink);
    });

    testWidgets('is read as the plain number and rupees', (tester) async {
      await pumpThemed(
        tester,
        const MmAmount(amount: Money.fromRupees(125000)),
      );
      expect(
        tester.getSemantics(find.byType(MmAmount)),
        matchesSemantics(label: '125000 rupees'),
      );
      await pumpThemed(
        tester,
        const MmAmount(amount: Money.fromRupees(125000)),
        variant: MmVariant.urdu,
      );
      expect(_label(tester), '125000 روپے');
    });

    testWidgets('shows a credit as the amount and the word, in credit', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmAmount(
          amount: _advance,
          creditLabel: 'credit',
          tone: MmAmountTone.overdue,
        ),
      );
      expect(_shown(tester), 'Rs 5,000 credit');
      expect(_shown(tester), isNot(contains('-')));
      expect(_style(tester).color, MmColorModes.light.credit);
      expect(_label(tester), '5000 rupees credit');

      await pumpThemed(
        tester,
        const MmAmount(amount: _advance, creditLabel: 'ایڈوانس'),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '5,000 روپے ایڈوانس');
      expect(_label(tester), '5000 روپے ایڈوانس');
    });

    testWidgets('a positive amount ignores the credit label', (tester) async {
      await pumpThemed(
        tester,
        const MmAmount(amount: _rent, creditLabel: 'credit'),
      );
      expect(_shown(tester), 'Rs 45,000');
      expect(_label(tester), '45000 rupees');
      expect(_style(tester).color, MmColorModes.light.ink);
    });

    testWidgets('shows a negative amount with a minus sign that stays before '
        'the digits right to left', (tester) async {
      await pumpThemed(tester, const MmAmount(amount: _advance));
      expect(_shown(tester), '\u200E-Rs 5,000');
      expect(_label(tester), '-5000 rupees');
      await pumpThemed(
        tester,
        const MmAmount(amount: _advance),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '\u200E-5,000 روپے');
    });

    test('says paisa only when the format shows them', () {
      const format = MoneyFormat();
      expect(
        MmAmount.spokenNumber(const Money.fromPaisa(150050), format),
        '1500.50',
      );
      expect(MmAmount.spokenNumber(_rent, format), '45000');
      expect(
        MmAmount.spokenNumber(
          const Money.fromPaisa(150050),
          format.copyWith(paisa: PaisaDisplay.never),
        ),
        '1501',
      );
      expect(
        MmAmount.spokenNumber(
          _rent,
          format.copyWith(paisa: PaisaDisplay.always),
        ),
        '45000',
      );
      expect(MmAmount.spokenNumber(_advance, format), '-5000');
    });

    testWidgets('stays on one line and scales down when too narrow', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 100,
          child: MmAmount(
            amount: Money.fromRupees(12500000),
            size: MmAmountSize.large,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.scaleDown);
      expect(tester.getSize(find.byType(MmAmount)).width, 100);
      // The text keeps its natural one-line size and is scaled to fit.
      expect(tester.getSize(find.byType(Text)).width, greaterThan(100));
      expect(tester.getSize(find.byType(Text)).height, 40);
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmAmount(
          amount: Money.fromRupees(999999999),
          size: MmAmountSize.large,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(MmAmount)).width,
        lessThanOrEqualTo(288),
      );
    });

    testWidgets('sits where textAlign puts it in a wider box', (tester) async {
      final expected = {
        TextAlign.start: AlignmentDirectional.centerStart,
        TextAlign.justify: AlignmentDirectional.centerStart,
        TextAlign.end: AlignmentDirectional.centerEnd,
        TextAlign.center: Alignment.center,
        TextAlign.left: Alignment.centerLeft,
        TextAlign.right: Alignment.centerRight,
      };
      for (final MapEntry(key: align, value: alignment) in expected.entries) {
        await pumpThemed(
          tester,
          SizedBox(
            width: 300,
            child: MmAmount(amount: _rent, textAlign: align),
          ),
        );
        expect(
          tester.widget<FittedBox>(find.byType(FittedBox)).alignment,
          alignment,
          reason: align.name,
        );
      }
      await pumpThemed(
        tester,
        const SizedBox(width: 300, child: MmAmount(amount: _rent)),
      );
      final box = tester.getRect(find.byType(MmAmount));
      expect(tester.getRect(find.byType(Text)).left, box.left);

      await pumpThemed(
        tester,
        const SizedBox(
          width: 300,
          child: MmAmount(amount: _rent, textAlign: TextAlign.end),
        ),
        variant: MmVariant.urdu,
      );
      final rtl = tester.getRect(find.byType(MmAmount));
      expect(tester.getRect(find.byType(Text)).left, rtl.left);
    });
  });
}
