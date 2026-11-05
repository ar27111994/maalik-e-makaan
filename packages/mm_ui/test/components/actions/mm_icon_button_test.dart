import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _edit = 'Edit tenant';

/// The Material that paints the icon button.
Material _material(WidgetTester tester) => tester.widget(
  find
      .descendant(
        of: find.byType(MmIconButton),
        matching: find.byType(Material),
      )
      .first,
);

/// The side of the icon button's outline.
BorderSide _side(WidgetTester tester) =>
    (_material(tester).shape! as OutlinedBorder).side;

/// The colour [icon] is painted in.
Color _iconColor(WidgetTester tester, IconData icon) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

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
            onPressed: () {},
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
        MmIconButton(icon: MmIcons.edit, tooltip: _edit, onPressed: () {}),
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
        final side = _side(tester);
        if (variant == MmIconButtonVariant.outlined) {
          expect(side.color, MmColorModes.light.rule);
        } else {
          expect(side.style, BorderStyle.none);
        }
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
            onPressed: () {},
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
        MmIconButton(
          icon: MmIcons.lock,
          tooltip: 'Lock receipt',
          selected: true,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(MmIcons.lock), findsOneWidget);
    });

    testWidgets('a plain button has no toggled state', (tester) async {
      await pumpThemed(
        tester,
        MmIconButton(
          icon: MmIcons.edit,
          selectedIcon: MmIcons.check,
          tooltip: _edit,
          onPressed: () {},
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
      final expected = <(MmIconButtonVariant, bool?), (Color?, Color)>{
        (MmIconButtonVariant.standard, null): (null, scheme.onSurfaceVariant),
        (MmIconButtonVariant.standard, false): (null, colors.inkMuted),
        (MmIconButtonVariant.standard, true): (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        (MmIconButtonVariant.filled, null): (colors.primary, colors.onPrimary),
        (MmIconButtonVariant.filled, false): (
          colors.surfaceSunken,
          colors.primary,
        ),
        (MmIconButtonVariant.filled, true): (colors.primary, colors.onPrimary),
        (MmIconButtonVariant.tonal, null): (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        (MmIconButtonVariant.tonal, false): (
          colors.surfaceSunken,
          colors.inkMuted,
        ),
        (MmIconButtonVariant.tonal, true): (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        (MmIconButtonVariant.outlined, null): (null, scheme.onSurfaceVariant),
        (MmIconButtonVariant.outlined, false): (null, colors.inkMuted),
        (MmIconButtonVariant.outlined, true): (
          colors.primary,
          colors.onPrimary,
        ),
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
            onPressed: () {},
          ),
          variant: variant,
        );
        final reason = '${kind.name} $selected';
        final material = _material(tester);
        if (fill == null) {
          expect(material.color?.a ?? 0, 0, reason: reason);
        } else {
          expect(material.color, fill, reason: reason);
        }
        expect(_iconColor(tester, MmIcons.edit), ink, reason: reason);
        // Only an unselected outlined button draws an outline.
        final outlined =
            kind == MmIconButtonVariant.outlined && !(selected ?? false);
        expect(
          _side(tester),
          outlined ? BorderSide(color: colors.outline) : BorderSide.none,
          reason: reason,
        );
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
            onPressed: () {},
          ),
          variant: variant,
        );
        final reason = '${kind.name} $selected';
        expect(
          _material(tester).shape,
          isNot(isA<MmFocusRingBorder>()),
          reason: reason,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final ring = _material(tester).shape! as MmFocusRingBorder;
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
          MmIconButton(icon: MmIcons.back, tooltip: 'Back', onPressed: () {}),
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
                onPressed: () {},
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
