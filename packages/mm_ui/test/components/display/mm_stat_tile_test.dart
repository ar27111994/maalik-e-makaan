import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
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
  caption: Text(_caption),
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
          direction: MmTrendDirection.down,
          label: 'Down',
          favourable: false,
        ).toString(),
        'MmTrend(down, "Down", unfavourable)',
      );
      const flat = MmTrend(direction: MmTrendDirection.flat, label: 'Same');
      expect(flat.favourable, isNull);
      expect(flat.toString(), 'MmTrend(flat, "Same", neutral)');
    });

    test('each direction has its icon', () {
      expect(MmTrendDirection.up.icon, MmIcons.trendUp);
      expect(MmTrendDirection.down.icon, MmIcons.trendDown);
      expect(MmTrendDirection.flat.icon, MmIcons.trendFlat);
      // Time runs from the start edge, so every trend mirrors in Urdu.
      for (final direction in MmTrendDirection.values) {
        expect(direction.icon.matchTextDirection, isTrue);
      }
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

    testEveryVariant('a neutral trend is in muted ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmStatTile(
          label: 'Occupied units',
          value: Text('12 of 14'),
          trend: MmTrend(
            direction: MmTrendDirection.flat,
            label: 'Same as September',
          ),
        ),
        variant: variant,
      );
      final muted = colorsOf(variant).inkMuted;
      expect(styleOf(tester, 'Same as September').color, muted);
      expect(_trendIcon(tester).icon, MmIcons.trendFlat);
      expect(_trendIcon(tester).color, muted);
    });

    testWidgets('a caption may hold an amount that never breaks', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmStatTile(
          label: _label,
          value: Text('Rs 95,000'),
          caption: Wrap(
            spacing: MmSpace.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('of'),
              MmAmount(
                amount: Money.fromRupees(125000),
                size: MmAmountSize.small,
                tone: MmAmountTone.muted,
              ),
              Text('due'),
            ],
          ),
        ),
      );
      expect(styleOf(tester, 'of').color, MmColorModes.light.inkMuted);
      expect(
        styleOf(tester, 'of').fontSize,
        MmVariant.light.theme.textTheme.bodyMedium!.fontSize,
      );
      expect(
        tester.getSemantics(find.byType(MmStatTile)),
        matchesSemantics(label: '$_label\nRs 95,000\nof\n125000 rupees\ndue'),
      );
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
          trend: MmTrend(direction: MmTrendDirection.flat, label: 'ستمبر جتنے'),
        ),
        variant: MmVariant.urdu,
      );
      expect(_trendIcon(tester).icon, MmIcons.trendFlat);
      expect(
        Directionality.of(tester.element(find.byType(Icon))),
        TextDirection.rtl,
      );
    });

    testWidgets('fits 200% text on a 320 dp phone one to a row, in whole '
        'words, its figure above its 100% size', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        const Column(spacing: MmSpace.s3, children: [_tile, _tile]),
        height: 1200,
        then: (_) {
          final figure = tester.getRect(find.byType(MmAmount).first);
          // Large amounts are 32 px at 100% text: drawn no smaller.
          expect(figure.height, greaterThanOrEqualTo(40));
        },
      );
    });

    testWidgets('two to a row at 200% on a 320 dp phone breaks words and '
        'squeezes the figure, and both are caught', (tester) async {
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
      // The figure was squeezed below its 100% size.
      expect(tester.takeException(), isNotNull);
      // And lines break inside words and the caption's amount.
      final broken = brokenWords(tester);
      expect(broken, contains('Collect|ed'));
      expect(broken.any((word) => word.startsWith('1,2')), isTrue);
      expect(() => expectWholeWords(tester), throwsA(isA<TestFailure>()));
    });

    testEveryVariant('inside a card it drops its border and fill', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        MmCard(
          child: MmStatTile(
            label: _label,
            value: const Text('Rs 95,000'),
            onTap: () {},
          ),
        ),
        variant: variant,
      );
      final surface = surfaceOf(tester, find.byType(MmStatTile));
      expect(surface.color, Colors.transparent);
      expect(sideOf(tester, find.byType(MmStatTile)), BorderSide.none);
      // Its keyboard focus still shows.
      useKeyboardHighlights();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        sideOf(tester, find.byType(MmStatTile)),
        BorderSide(color: colorsOf(variant).focus, width: MmSize.focusRing),
      );
    });

    testWidgets('a tappable tile is bounded by the outline colour', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmStatTile(label: _label, value: const Text('Rs 95,000'), onTap: () {}),
      );
      expect(
        sideOf(tester, find.byType(MmStatTile)),
        BorderSide(color: MmColorModes.light.outline),
      );
    });
  });
}
