import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

const _add = 'Add tenant';

/// The Material that paints the floating action button.
Material _material(WidgetTester tester) => tester.widget(
  find
      .descendant(of: find.byType(MmFab), matching: find.byType(Material))
      .first,
);

/// The side of the button's outline.
BorderSide _side(WidgetTester tester) =>
    (_material(tester).shape! as OutlinedBorder).side;

MmColorTokens _colorsOf(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

void main() {
  group('MmFab', () {
    testWidgets('is extended by default', (tester) async {
      const fab = MmFab(label: _add, icon: MmIcons.invite, onPressed: null);
      expect(fab.extended, isTrue);
    });

    testWidgets('extended, shows its icon and label, read as one button', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmFab(label: _add, icon: MmIcons.invite, onPressed: () {}),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(MmIcons.invite), findsOneWidget);
      expect(find.text(_add), findsOneWidget);
      final node = tester.getSemantics(find.text(_add));
      expect(
        node,
        matchesSemantics(
          label: _add,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      final size = tester.getSize(find.byType(MmFab));
      expect(size.height, 56);
      expect(size.width, greaterThan(56));
    });

    testWidgets('compact, shows the icon; the label is tooltip and label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmFab(
          label: _add,
          icon: MmIcons.invite,
          extended: false,
          onPressed: () {},
        ),
      );
      expect(find.text(_add), findsNothing);
      expect(tester.getSize(find.byType(MmFab)), const Size(56, 56));
      final node = tester.getSemantics(find.byIcon(MmIcons.invite));
      expect(
        node,
        matchesSemantics(
          label: _add,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(node.getSemanticsData().tooltip, isEmpty);

      await tester.longPress(find.byType(MmFab));
      await tester.pumpAndSettle();
      expect(find.text(_add), findsOneWidget);
    });

    testWidgets('calls onPressed on tap and from the keyboard', (tester) async {
      for (final extended in [true, false]) {
        var presses = 0;
        await pumpThemed(
          tester,
          MmFab(
            label: _add,
            icon: MmIcons.invite,
            extended: extended,
            onPressed: () => presses++,
          ),
        );
        await tester.tap(find.byType(MmFab));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(presses, 3, reason: 'extended: $extended');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testEveryVariant('enabled, it is cobalt and floats', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        MmFab(label: _add, icon: MmIcons.invite, onPressed: () {}),
        variant: variant,
      );
      final colors = _colorsOf(variant);
      final material = _material(tester);
      expect(material.color, colors.primary);
      expect(material.elevation, greaterThan(0));
      expect(_side(tester), BorderSide(color: colors.primary));
    });

    testEveryVariant('disabled, it is flat, muted and out of reach', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFab(label: _add, icon: MmIcons.invite, onPressed: null),
        variant: variant,
      );
      final colors = _colorsOf(variant);
      final material = _material(tester);
      expect(material.color, colors.surfaceSunken);
      expect(material.elevation, 0);
      expect(_side(tester), BorderSide(color: colors.rule));
      expect(
        tester.getSemantics(find.text(_add)),
        matchesSemantics(label: _add, isButton: true, hasEnabledState: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_side(tester), BorderSide(color: colors.rule));
    });

    testEveryVariant('a focused button draws a ring in its icon colour', (
      tester,
      variant,
    ) async {
      final colors = _colorsOf(variant);
      for (final extended in [true, false]) {
        await pumpThemed(
          tester,
          MmFab(
            label: _add,
            icon: MmIcons.invite,
            extended: extended,
            onPressed: () {},
          ),
          variant: variant,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          _side(tester),
          BorderSide(color: colors.onPrimary, width: MmSize.focusRing),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(_side(tester), BorderSide(color: colors.primary));
      }
    });

    testWidgets('a long label wraps at 200% text on a 320 dp surface', (
      tester,
    ) async {
      const label = 'Record the October payment for the Gulberg, Lahore flat';
      await pumpThemed(
        tester,
        MmFab(label: label, icon: MmIcons.payment, onPressed: () {}),
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(MmFab));
      expect(size.width, lessThanOrEqualTo(288));
      expect(size.height, greaterThan(56));
      final text = tester.getRect(find.text(label));
      final fab = tester.getRect(find.byType(MmFab));
      expect(
        fab.contains(text.topLeft) && fab.contains(text.bottomRight),
        true,
      );
    });

    testWidgets('the icon leads the label, on the right in Urdu', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        final label = variant == MmVariant.urdu ? 'کرایہ دار شامل کریں' : _add;
        await pumpThemed(
          tester,
          MmFab(label: label, icon: MmIcons.invite, onPressed: () {}),
          variant: variant,
        );
        final icon = tester.getCenter(find.byIcon(MmIcons.invite)).dx;
        final text = tester.getCenter(find.text(label)).dx;
        expect(
          variant == MmVariant.urdu ? icon > text : icon < text,
          isTrue,
          reason: variant.name,
        );
      }
    });

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: MmSpace.s4,
          children: [
            MmFab(
              label: 'Add a tenant to Gulberg House',
              icon: MmIcons.invite,
              onPressed: () {},
            ),
            MmFab(
              label: 'Add property',
              icon: MmIcons.add,
              extended: false,
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
