import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _overdue = 'Overdue 12 days';

/// The icon drawn inside the badge.
Icon _icon(WidgetTester tester) => tester.widget(
  find.descendant(of: find.byType(MmStatusBadge), matching: find.byType(Icon)),
);

void main() {
  group('MmStatus', () {
    for (final variant in MmVariant.values) {
      test('maps its colour roles in ${variant.name}', () {
        final c = colorsOf(variant);
        final expected = {
          MmStatus.paid: (c.paid, c.paidContainer, c.onPaidContainer),
          MmStatus.overdue: (
            c.overdue,
            c.overdueContainer,
            c.onOverdueContainer,
          ),
          MmStatus.dueSoon: (
            c.dueSoon,
            c.dueSoonContainer,
            c.onDueSoonContainer,
          ),
          MmStatus.credit: (c.credit, c.creditContainer, c.onCreditContainer),
          MmStatus.neutral: (c.inkMuted, c.surfaceSunken, c.ink),
        };
        for (final MapEntry(key: status, value: roles) in expected.entries) {
          expect(status.colorIn(c), roles.$1, reason: status.name);
          expect(status.containerIn(c), roles.$2, reason: status.name);
          expect(status.onContainerIn(c), roles.$3, reason: status.name);
        }
      });
    }

    test('has a default icon each', () {
      expect(MmStatus.paid.icon, MmIcons.success);
      expect(MmStatus.overdue.icon, MmIcons.error);
      expect(MmStatus.dueSoon.icon, MmIcons.dueDate);
      expect(MmStatus.credit.icon, MmIcons.deposit);
      expect(MmStatus.neutral.icon, MmIcons.info);
    });
  });

  group('MmStatusBadge', () {
    testEveryVariant('is the container colour, an icon and the word', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      for (final status in MmStatus.values) {
        await pumpThemed(
          tester,
          MmStatusBadge(status: status, label: status.name),
          variant: variant,
        );
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(MmStatusBadge),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, status.containerIn(colors));
        expect(
          decoration.borderRadius,
          const BorderRadius.all(Radius.circular(MmRadius.xs)),
        );
        final icon = _icon(tester);
        expect(icon.icon, status.icon);
        expect(icon.color, status.onContainerIn(colors));
        final style = styleOf(tester, status.name);
        expect(style.color, status.onContainerIn(colors));
        expect(
          style.fontWeight,
          variant.theme.textTheme.labelLarge!.fontWeight,
        );
        expect(style.fontSize, variant.theme.textTheme.labelLarge!.fontSize);
      }
    });

    testWidgets('takes its own icon in place of the default', (tester) async {
      await pumpThemed(
        tester,
        const MmStatusBadge(
          status: MmStatus.paid,
          label: 'Receipt sent',
          icon: MmIcons.receipt,
        ),
      );
      expect(_icon(tester).icon, MmIcons.receipt);
    });

    testWidgets('pads compactly', (tester) async {
      await pumpThemed(
        tester,
        const MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
      );
      final badge = tester.getRect(find.byType(MmStatusBadge));
      final text = tester.getRect(
        find
            .descendant(
              of: find.byType(MmStatusBadge),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.left - badge.left, MmSpace.s2);
      expect(text.top - badge.top, MmSpace.sHalf);
    });

    testWidgets('reads only its word', (tester) async {
      await pumpThemed(
        tester,
        const MmStatusBadge(status: MmStatus.overdue, label: _overdue),
      );
      expect(
        tester.getSemantics(find.byType(MmStatusBadge)),
        matchesSemantics(label: _overdue),
      );
    });

    testWidgets('puts the icon at the start edge, mirrored right to left', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmStatusBadge(status: MmStatus.overdue, label: '12 دن سے بقایا'),
        variant: MmVariant.urdu,
      );
      final badge = tester.getRect(find.byType(MmStatusBadge));
      final icon = tester.getRect(find.byType(Icon));
      expect(icon.right, moreOrLessEquals(badge.right - MmSpace.s2));
    });

    testWidgets('wraps a long label at 200% in whole words instead of '
        'overflowing', (tester) async {
      const label = 'Overdue since 5 October, reminder sent twice';
      await expectWholeAtLargeText(
        tester,
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: MmStatusBadge(status: MmStatus.overdue, label: label),
        ),
        then: (_) {
          final badge = tester.getSize(find.byType(MmStatusBadge));
          expect(badge.width, lessThanOrEqualTo(288));
          // Several lines of 28 px text.
          expect(badge.height, greaterThan(3 * 28));
          final icon = tester.getRect(find.byType(Icon));
          expect(
            icon.top - tester.getRect(find.byType(MmStatusBadge)).top,
            lessThan(28),
          );
        },
      );
    });

    testWidgets('is as wide as its longest line once its words wrap', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 130,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: MmStatusBadge(
              status: MmStatus.overdue,
              label: 'Overdue 12 days',
            ),
          ),
        ),
        variant: MmVariant.largeText,
      );
      // The badge's words (the icon inside them is a paragraph too).
      final paragraph = paragraphOf(tester, 'Overdue 12 days');
      expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
      // Two lines, and no empty fill after the longer of them.
      expect(paragraph.size.height, greaterThan(28 * 1.5));
      final badge = tester.getSize(find.byType(MmStatusBadge));
      expect(badge.width, lessThan(130));
      expect(badge.width, paragraph.size.width + 2 * MmSpace.s2);
    });

    testWidgets('grows its icon with the text, up to one and a half times', (
      tester,
    ) async {
      for (final (scale, size) in [(1.0, 16.0), (1.3, 20.8), (2.0, 24.0)]) {
        await pumpThemed(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const MmStatusBadge(status: MmStatus.paid, label: 'Paid'),
            ),
          ),
        );
        expect(
          tester.getRect(find.byType(Icon)).width,
          moreOrLessEquals(size),
          reason: 'at $scale',
        );
      }
    });
  });
}
