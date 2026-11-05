import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const _label = 'Collected in October';
const _caption = 'of Rs 1,25,000 due';
const _up = MmTrend(
  direction: MmTrendDirection.up,
  label: 'Up 12% from September',
  favourable: true,
);

const _tile = MmStatTile(
  label: _label,
  value: MmAmount(amount: Money.fromRupees(95000), size: MmAmountSize.large),
  caption: _caption,
  trend: _up,
);

/// The trend icon of the tile.
Icon _trendIcon(WidgetTester tester) => tester.widget(
  find.descendant(of: find.byType(MmStatTile), matching: find.byType(Icon)),
);

void main() {
  group('MmTrend', () {
    test('compares by value', () {
      const same = MmTrend(
        direction: MmTrendDirection.up,
        label: 'Up 12% from September',
        favourable: true,
      );
      expect(same, _up);
      expect(same.hashCode, _up.hashCode);
      const down = MmTrend(
        direction: MmTrendDirection.down,
        label: 'Up 12% from September',
        favourable: true,
      );
      expect(down, isNot(_up));
      expect(
        const MmTrend(
          direction: MmTrendDirection.up,
          label: 'Up 2',
          favourable: true,
        ),
        isNot(_up),
      );
      expect(
        const MmTrend(
          direction: MmTrendDirection.up,
          label: 'Up 12% from September',
          favourable: false,
        ),
        isNot(_up),
      );
      expect(_up, isNot(Object()));
      expect(
        _up.toString(),
        'MmTrend(up, "Up 12% from September", favourable)',
      );
      expect(
        const MmTrend(
          direction: MmTrendDirection.flat,
          label: 'Same',
          favourable: false,
        ).toString(),
        'MmTrend(flat, "Same", unfavourable)',
      );
    });

    test('each direction has its icon', () {
      expect(MmTrendDirection.up.icon, MmIcons.trendUp);
      expect(MmTrendDirection.down.icon, MmIcons.trendDown);
      expect(MmTrendDirection.flat.icon, MmIcons.forward);
      expect(MmIcons.forward.matchTextDirection, isTrue);
    });
  });

  group('MmStatTile', () {
    testEveryVariant('shows its label, value, caption and trend', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _tile, variant: variant);
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final label = styleOf(tester, _label);
      expect(label.fontSize, text.labelLarge!.fontSize);
      expect(label.fontWeight, text.labelLarge!.fontWeight);
      expect(label.color, colors.inkMuted);
      expect(find.byType(MmAmount), findsOneWidget);
      expect(styleOf(tester, _caption).color, colors.inkMuted);
      expect(styleOf(tester, _up.label).color, colors.paid);
      expect(_trendIcon(tester).icon, MmIcons.trendUp);
      expect(_trendIcon(tester).color, colors.paid);
      // Its own flat surface with the card's rule border.
      final surface = surfaceOf(tester, find.byType(MmStatTile));
      expect(surface.color, colors.surface);
      expect(surface.elevation, 0);
      expect(
        sideOf(tester, find.byType(MmStatTile)),
        BorderSide(color: colors.rule),
      );
    });

    testWidgets('lays its parts out top to bottom from the start edge', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(tester, _tile, variant: variant);
        final tile = tester.getRect(find.byType(MmStatTile));
        final label = tester.getRect(find.text(_label));
        final value = tester.getRect(find.byType(MmAmount));
        final caption = tester.getRect(find.text(_caption));
        expect(label.top, tile.top + MmSpace.s4);
        expect(value.top, greaterThan(label.bottom));
        expect(caption.top, greaterThan(value.bottom));
        if (variant == MmVariant.urdu) {
          expect(label.right, tile.right - MmSpace.s4);
        } else {
          expect(label.left, tile.left + MmSpace.s4);
        }
      }
    });

    testWidgets('an unfavourable trend is in the overdue colour', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmStatTile(
          label: 'Overdue',
          value: Text('Rs 30,000'),
          trend: MmTrend(
            direction: MmTrendDirection.down,
            label: 'Down 2 tenants',
            favourable: false,
          ),
        ),
      );
      expect(
        styleOf(tester, 'Down 2 tenants').color,
        MmColorModes.light.overdue,
      );
      expect(_trendIcon(tester).icon, MmIcons.trendDown);
      expect(_trendIcon(tester).color, MmColorModes.light.overdue);
      expect(_trendIcon(tester).size, MmSize.iconMd);
    });

    testWidgets('a plain text value takes the headline style', (tester) async {
      await pumpThemed(
        tester,
        const MmStatTile(label: 'Occupied units', value: Text('12 of 14')),
      );
      final style = DefaultTextStyle.of(tester.element(find.text('12 of 14')))
          .style;
      final headline = MmVariant.light.theme.textTheme.headlineSmall!;
      expect(style.fontSize, headline.fontSize);
      expect(style.fontWeight, headline.fontWeight);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('is one node reading label, value, caption and trend', (
      tester,
    ) async {
      await pumpThemed(tester, _tile);
      expect(
        tester.getSemantics(find.byType(MmStatTile)),
        matchesSemantics(
          label: '$_label\n95000 rupees\n$_caption\n${_up.label}',
        ),
      );
    });

    testWidgets('with onTap it is a button activated by tap and keyboard', (
      tester,
    ) async {
      var taps = 0;
      final tile = find.byType(MmStatTile);
      await pumpThemed(
        tester,
        MmStatTile(
          label: _label,
          value: const Text('Rs 95,000'),
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSemantics(tile),
        matchesSemantics(
          label: '$_label\nRs 95,000',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.tap(tile);
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _label), isTrue);
      expect(
        sideOf(tester, tile),
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 2);
    });

    testWidgets('without onTap it is not a button and takes no focus', (
      tester,
    ) async {
      await pumpThemed(tester, _tile);
      expect(
        tester.getSemantics(find.byType(MmStatTile)),
        isNot(isSemantics(isButton: true)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _label), isFalse);
    });

    testWidgets('mirrors a flat trend right to left', (tester) async {
      await pumpThemed(
        tester,
        const MmStatTile(
          label: 'آباد یونٹ',
          value: Text('14 میں سے 12'),
          trend: MmTrend(
            direction: MmTrendDirection.flat,
            label: 'ستمبر جتنے',
            favourable: true,
          ),
        ),
        variant: MmVariant.urdu,
      );
      expect(_trendIcon(tester).icon, MmIcons.forward);
      expect(
        Directionality.of(tester.element(find.byType(Icon))),
        TextDirection.rtl,
      );
    });

    testWidgets('fits 200% text on a 320 dp phone, two to a row', (
      tester,
    ) async {
      await pumpLargeNarrow(
        tester,
        const Row(
          spacing: MmSpace.s3,
          children: [
            Expanded(child: _tile),
            Expanded(child: _tile),
          ],
        ),
        height: 1000,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
