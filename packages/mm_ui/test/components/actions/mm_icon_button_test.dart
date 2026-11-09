import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _edit = 'Edit tenant';

/// The icon button under test.
final Finder _button = find.byType(MmIconButton);

/// The fill the icon button shows on [page]: its own, or the page through a
/// transparent one.
Color _fillOn(WidgetTester tester, Color page) {
  final fill = materialOf(tester, _button).color ?? page;
  return Color.alphaBlend(fill, page);
}

void main() {
  group('MmIconButton', () {
    testWidgets('defaults to a standard action button', (tester) async {
      const button = MmIconButton(
        icon: MmIcons.edit,
        tooltip: _edit,
        onPressed: null,
      );
      expect(button.variant, MmIconButtonVariant.standard);
      expect(button.selected, isNull);
      expect(button.selectedIcon, isNull);
    });

    testWidgets('every variant is a 48 dp IconButton', (tester) async {
      for (final variant in MmIconButtonVariant.values) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.edit,
            tooltip: _edit,
            variant: variant,
            onPressed: tapped,
          ),
        );
        expect(find.byType(IconButton), findsOneWidget);
        expect(tester.getSize(find.byType(MmIconButton)), const Size(48, 48));
        expect(tester.getSize(find.byIcon(MmIcons.edit)), const Size(24, 24));
      }
    });

    testWidgets('the tooltip is its label, announced once', (tester) async {
      await pumpThemed(
        tester,
        const MmIconButton(
          icon: MmIcons.edit,
          tooltip: _edit,
          onPressed: tapped,
        ),
      );
      final node = tester.getSemantics(find.byIcon(MmIcons.edit));
      expect(
        node,
        matchesSemantics(
          label: _edit,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(node.getSemanticsData().tooltip, isEmpty);

      expect(find.text(_edit), findsNothing);
      await tester.longPress(find.byType(MmIconButton));
      await tester.pumpAndSettle();
      expect(find.text(_edit), findsOneWidget);
    });

    testWidgets('calls onPressed on tap and from the keyboard', (tester) async {
      var presses = 0;
      await pumpThemed(
        tester,
        MmIconButton(
          icon: MmIcons.edit,
          tooltip: _edit,
          onPressed: () => presses++,
        ),
      );
      await tester.tap(find.byType(MmIconButton));
      expect(presses, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(presses, 3);
    });

    testWidgets('a null onPressed disables it', (tester) async {
      for (final variant in MmIconButtonVariant.values) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.edit,
            tooltip: _edit,
            variant: variant,
            onPressed: null,
          ),
        );
        expect(
          tester.getSemantics(find.byIcon(MmIcons.edit)),
          matchesSemantics(label: _edit, isButton: true, hasEnabledState: true),
        );
        // Not focusable: Tab finds nothing to focus.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(hasFocus(tester, find.byIcon(MmIcons.edit)), isFalse);
      }
    });

    testEveryVariant('disabled, it is muted ink; on and off still differ', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      final none = colors.bg.withValues(alpha: 0);
      // (fill, edge) while disabled, by variant and `selected`. Filled
      // controls sit on sunken paper inside the rule border; an outlined
      // one keeps a rule outline; a toggle that is on is filled in the rule
      // colour.
      final expected = <(MmIconButtonVariant, bool?), (Color, BorderSide)>{
        for (final selected in [null, false])
          (MmIconButtonVariant.standard, selected): (none, BorderSide.none),
        for (final selected in [null, false])
          (MmIconButtonVariant.outlined, selected): (
            none,
            BorderSide(color: colors.rule),
          ),
        for (final kind in [
          MmIconButtonVariant.filled,
          MmIconButtonVariant.tonal,
        ])
          for (final selected in [null, false])
            (kind, selected): (
              colors.surfaceSunken,
              BorderSide(color: colors.rule),
            ),
        for (final kind in MmIconButtonVariant.values)
          (kind, true): (colors.rule, BorderSide.none),
      };
      for (final MapEntry(key: (kind, selected), value: (fill, edge))
          in expected.entries) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.lock,
            tooltip: 'Lock receipt',
            variant: kind,
            selected: selected,
            onPressed: null,
          ),
          variant: variant,
        );
        final reason = '${kind.name} $selected';
        expect(
          _fillOn(tester, colors.bg),
          Color.alphaBlend(fill, colors.bg),
          reason: reason,
        );
        expect(sideOf(tester, _button), edge, reason: reason);
        expect(iconColorOf(tester, MmIcons.lock), colors.inkMuted);
      }
      for (final kind in MmIconButtonVariant.values) {
        final (offFill, offEdge) = expected[(kind, false)]!;
        final (onFill, onEdge) = expected[(kind, true)]!;
        expect(
          (Color.alphaBlend(offFill, colors.bg), offEdge),
          isNot((Color.alphaBlend(onFill, colors.bg), onEdge)),
          reason: kind.name,
        );
      }
    });

    testWidgets('a toggle reads as toggled and swaps its icon', (tester) async {
      for (final on in [false, true]) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.notificationsOff,
            selectedIcon: MmIcons.notifications,
            tooltip: 'Rent reminders',
            selected: on,
            onPressed: tapped,
          ),
        );
        final shown = on ? MmIcons.notifications : MmIcons.notificationsOff;
        final hidden = on ? MmIcons.notificationsOff : MmIcons.notifications;
        expect(find.byIcon(shown), findsOneWidget);
        expect(find.byIcon(hidden), findsNothing);
        expect(
          tester.getSemantics(find.byIcon(shown)),
          matchesSemantics(
            label: 'Rent reminders',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasToggledState: true,
            isToggled: on,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      }
    });

    testWidgets('a selected toggle without a selectedIcon keeps its icon', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmIconButton(
          icon: MmIcons.lock,
          tooltip: 'Lock receipt',
          selected: true,
          onPressed: tapped,
        ),
      );
      expect(find.byIcon(MmIcons.lock), findsOneWidget);
    });

    testWidgets('a plain button has no toggled state', (tester) async {
      await pumpThemed(
        tester,
        const MmIconButton(
          icon: MmIcons.edit,
          selectedIcon: MmIcons.check,
          tooltip: _edit,
          onPressed: tapped,
        ),
      );
      expect(find.byIcon(MmIcons.edit), findsOneWidget);
      // Strict: no toggled (nor selected) state.
      expect(
        tester.getSemantics(find.byIcon(MmIcons.edit)),
        matchesSemantics(
          label: _edit,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testEveryVariant('the colours of each variant and toggle state', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      final scheme = variant.theme.colorScheme;
      // (fill, icon colour) by variant and `selected`; a null fill is none.
      // A toggle that is on is cobalt in every variant.
      final expected = <(MmIconButtonVariant, bool?), (Color?, Color)>{
        (MmIconButtonVariant.standard, null): (null, scheme.onSurfaceVariant),
        (MmIconButtonVariant.standard, false): (null, colors.inkMuted),
        (MmIconButtonVariant.filled, null): (colors.primary, colors.onPrimary),
        (MmIconButtonVariant.filled, false): (
          colors.primaryContainer,
          colors.primary,
        ),
        (MmIconButtonVariant.tonal, null): (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        (MmIconButtonVariant.tonal, false): (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        (MmIconButtonVariant.outlined, null): (null, scheme.onSurfaceVariant),
        (MmIconButtonVariant.outlined, false): (null, colors.inkMuted),
        for (final kind in MmIconButtonVariant.values)
          (kind, true): (colors.primary, colors.onPrimary),
      };
      for (final MapEntry(key: (kind, selected), value: (fill, ink))
          in expected.entries) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.edit,
            tooltip: _edit,
            variant: kind,
            selected: selected,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final reason = '${kind.name} $selected';
        final material = materialOf(tester, _button);
        if (fill == null) {
          expect(material.color?.a ?? 0, 0, reason: reason);
        } else {
          expect(material.color, fill, reason: reason);
        }
        expect(iconColorOf(tester, MmIcons.edit), ink, reason: reason);
        // Only an outlined button that is not on draws an outline.
        final outlined =
            kind == MmIconButtonVariant.outlined && !(selected ?? false);
        expect(
          sideOf(tester, _button),
          outlined ? BorderSide(color: colors.outline) : BorderSide.none,
          reason: reason,
        );
      }
    });

    testEveryVariant('a toggle that is on stands 3:1 apart from off', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      // On the page and on a card: wherever an icon button sits.
      for (final page in [colors.bg, colors.surface]) {
        for (final kind in MmIconButtonVariant.values) {
          final fills = <bool, Color>{};
          for (final on in [false, true]) {
            await pumpThemed(
              tester,
              MmIconButton(
                icon: MmIcons.lock,
                tooltip: 'Lock receipt',
                variant: kind,
                selected: on,
                onPressed: tapped,
              ),
              variant: variant,
            );
            fills[on] = _fillOn(tester, page);
            // Its icon stands out from its own fill, too.
            expect(
              mmContrastRatio(iconColorOf(tester, MmIcons.lock), fills[on]!),
              greaterThanOrEqualTo(mmMinimumIconContrast),
              reason: '${kind.name} on: $on',
            );
          }
          expect(
            mmContrastRatio(fills[true]!, fills[false]!),
            greaterThanOrEqualTo(mmMinimumIconContrast),
            reason: '${kind.name} on $page',
          );
        }
      }
    });

    testEveryVariant('a focused button shows a ring that stands out', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      // Any icon button may be filled, so the theme draws every ring outside
      // the button, past a gap, in the focus colour: it shows on a cobalt
      // fill too. The button keeps its own edge.
      final edges = <(MmIconButtonVariant, bool?), BorderSide>{
        (MmIconButtonVariant.standard, null): BorderSide.none,
        (MmIconButtonVariant.filled, null): BorderSide.none,
        (MmIconButtonVariant.filled, false): BorderSide.none,
        (MmIconButtonVariant.tonal, null): BorderSide.none,
        (MmIconButtonVariant.outlined, false): BorderSide(
          color: colors.outline,
        ),
        (MmIconButtonVariant.outlined, true): BorderSide.none,
      };
      for (final MapEntry(key: (kind, selected), value: edge)
          in edges.entries) {
        await pumpThemed(
          tester,
          MmIconButton(
            icon: MmIcons.edit,
            tooltip: _edit,
            variant: kind,
            selected: selected,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final reason = '${kind.name} $selected';
        expect(
          materialOf(tester, _button).shape,
          isNot(isA<MmFocusRingBorder>()),
          reason: reason,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final ring = materialOf(tester, _button).shape! as MmFocusRingBorder;
        expect(ring.color, colors.focus, reason: reason);
        expect(ring.width, MmSize.focusRing, reason: reason);
        expect(ring.gap, MmSize.focusGap, reason: reason);
        expect(ring.side, edge, reason: reason);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a pointing icon mirrors in Urdu', (tester) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(
          tester,
          const MmIconButton(
            icon: MmIcons.back,
            tooltip: 'Back',
            onPressed: tapped,
          ),
          variant: variant,
        );
        expect(
          find.descendant(
            of: find.byIcon(MmIcons.back),
            matching: find.byType(Transform),
          ),
          variant == MmVariant.urdu ? findsOneWidget : findsNothing,
        );
      }
    });

    testWidgets('fits 200% text on 320 dp in English and Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Wrap(
          children: [
            for (final kind in MmIconButtonVariant.values)
              for (final selected in [null, false, true])
                MmIconButton(
                  icon: MmIcons.notificationsOff,
                  selectedIcon: MmIcons.notifications,
                  tooltip: 'کرایے کی یاد دہانیاں',
                  variant: kind,
                  selected: selected,
                  onPressed: tapped,
                ),
          ],
        ),
      );
    });

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in MmIconButtonVariant.values)
              MmIconButton(
                icon: MmIcons.share,
                tooltip: 'Share receipt',
                variant: kind,
                selected: kind == MmIconButtonVariant.tonal ? true : null,
                onPressed: tapped,
              ),
          ],
        ),
        variant: variant,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      await expectAccessible(tester);
    });
  });
}
