import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

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
      expect(_shown(tester), 'Rs\u00A0125,000');
      await pumpThemed(
        tester,
        const MmAmount(amount: Money.fromRupees(125000)),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '125,000\u00A0روپے');
    });

    testWidgets('formats with the money format the app sets', (tester) async {
      await pumpThemed(
        tester,
        const MmFormats(
          money: MoneyFormat(grouping: DigitGrouping.southAsian),
          child: MmAmount(amount: Money.fromRupees(125000)),
        ),
      );
      expect(_shown(tester), 'Rs\u00A01,25,000');
      await pumpThemed(
        tester,
        const MmFormats(
          money: MoneyFormat(notation: MoneyNotation.compact),
          child: MmAmount(amount: Money.fromRupees(12500000)),
        ),
      );
      expect(_shown(tester), 'Rs\u00A01.25\u00A0crore');
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
      expect(_shown(tester), 'Rs\u00A05,000 credit');
      expect(_shown(tester), isNot(contains('-')));
      expect(_style(tester).color, MmColorModes.light.credit);
      expect(_label(tester), '5000 rupees credit');

      await pumpThemed(
        tester,
        const MmAmount(amount: _advance, creditLabel: 'ایڈوانس'),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '5,000\u00A0روپے ایڈوانس');
      expect(_label(tester), '5000 روپے ایڈوانس');
    });

    testWidgets('a positive amount ignores the credit label', (tester) async {
      await pumpThemed(
        tester,
        const MmAmount(amount: _rent, creditLabel: 'credit'),
      );
      expect(_shown(tester), 'Rs\u00A045,000');
      expect(_label(tester), '45000 rupees');
      expect(_style(tester).color, MmColorModes.light.ink);
    });

    testWidgets('shows a negative amount with a minus sign that stays before '
        'the digits right to left', (tester) async {
      await pumpThemed(tester, const MmAmount(amount: _advance));
      expect(_shown(tester), '\u200E-Rs\u00A05,000');
      expect(_label(tester), '-5000 rupees');
      await pumpThemed(
        tester,
        const MmAmount(amount: _advance),
        variant: MmVariant.urdu,
      );
      expect(_shown(tester), '\u200E-5,000\u00A0روپے');
    });

    testWidgets('stays on one line, and at large text scales back down to '
        'fit, as far as its 100% size', (tester) async {
      const amount = MmAmount(amount: _rent, size: MmAmountSize.large);
      await pumpThemed(tester, const SizedBox(width: 200, child: amount));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      // At 100% text it fits at its size: drawn as large as it is laid out.
      final natural = tester.getSize(find.byType(Text));
      expect(natural.width, lessThan(200));
      expect(tester.getRect(find.byType(Text)).size, natural);

      await pumpThemed(
        tester,
        const SizedBox(width: 200, child: amount),
        variant: MmVariant.largeText,
      );
      expect(tester.takeException(), isNull);
      // At 200% it would need twice the width: it keeps its one-line
      // layout and is scaled to fit, but stays larger than at 100%.
      final large = tester.getSize(find.byType(Text));
      expect(large.width, moreOrLessEquals(2 * natural.width, epsilon: 1));
      final shown = tester.getRect(find.byType(Text)).size;
      expect(shown.width, moreOrLessEquals(200, epsilon: 0.01));
      expect(shown.height, greaterThan(natural.height));
    });

    testWidgets('reports being squeezed below its 100% size, once, and '
        'keeps every digit in release', (tester) async {
      const narrow = SizedBox(
        width: 100,
        child: MmAmount(
          amount: Money.fromRupees(12500000),
          size: MmAmountSize.large,
        ),
      );
      await pumpThemed(tester, narrow);
      final message = (tester.takeException()! as FlutterError).toStringDeep();
      expect(
        message,
        contains('An MmAmount was squeezed below its size at 100% text.'),
      );
      expect(message, contains('"Rs\u00A012,500,000"'));
      expect(message, contains('has 100.0 px'));
      expect(message, contains('put stat tiles one to a row'));
      // Release builds keep scaling it down: the whole number, smaller.
      expect(tester.getSize(find.byType(MmAmount)).width, 100);
      expect(tester.getSize(find.byType(Text)).width, greaterThan(100));

      // Laid out again in the same squeeze, it is not reported again.
      await pumpThemed(tester, narrow, variant: MmVariant.dark);
      expect(tester.takeException(), isNull);

      // Given room, and squeezed again, it is.
      await pumpThemed(
        tester,
        const SizedBox(
          width: 300,
          child: MmAmount(
            amount: Money.fromRupees(12500000),
            size: MmAmountSize.large,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await pumpThemed(tester, narrow);
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('a large amount in half of a 320 dp phone at 200% is '
        'reported', (tester) async {
      await pumpLargeNarrow(
        tester,
        const Row(
          spacing: MmSpace.s3,
          children: [
            Expanded(
              child: MmAmount(amount: _rent, size: MmAmountSize.large),
            ),
            Expanded(child: SizedBox()),
          ],
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('follows the text size as it changes', (tester) async {
      var scale = 1.0;
      late StateSetter update;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const SizedBox(
                width: 180,
                child: MmAmount(amount: _rent, size: MmAmountSize.large),
              ),
            );
          },
        ),
      );
      expect(tester.takeException(), isNull);
      // At 300% it needs three times its room at 100%: it shrinks back to
      // fit, still above its 100% size, so nothing is reported.
      update(() => scale = 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      update(() => scale = 1.5);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmAmount)).width, 180);
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmAmount(
          amount: Money.fromRupees(999999999),
          size: MmAmountSize.large,
        ),
        then: (_) => expect(
          tester.getSize(find.byType(MmAmount)).width,
          lessThanOrEqualTo(288),
        ),
      );
    });

    testWidgets('says an amount as MmAmount reads it', (tester) async {
      late BuildContext context;
      await pumpThemed(
        tester,
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox();
          },
        ),
      );
      expect(MmAmount.spokenLabel(context, _rent), '45000 rupees');
      expect(MmAmount.spokenLabel(context, _advance), '-5000 rupees');
      expect(
        MmAmount.spokenLabel(context, _advance, creditLabel: 'credit'),
        '5000 rupees credit',
      );
      expect(
        MmAmount.spokenLabel(context, _rent, creditLabel: 'credit'),
        '45000 rupees',
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
        final fit = tester.renderObject<RenderFittedBox>(
          find.descendant(
            of: find.byType(MmAmount),
            matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_AmountFit',
            ),
          ),
        );
        expect(fit.alignment, alignment, reason: align.name);
        expect(fit.fit, BoxFit.scaleDown);
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
