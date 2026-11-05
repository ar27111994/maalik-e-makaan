import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';

import '../../support/testing.dart';
import 'support.dart';

const _label = 'Add tenant';

/// The Material that paints the filled button.
Material _material(WidgetTester tester) => tester.widget(
  find
      .descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      )
      .first,
);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  group('MmFilledAction', () {
    testEveryVariant('is a cobalt filled button with its on-colour text', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFilledAction(label: _label, onPressed: tapped),
        variant: variant,
      );
      final colors = colorsOf(variant);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(_material(tester).color, colors.primary);
      expect(styleOf(tester, _label).color, colors.onPrimary);
    });

    testEveryVariant('a destructive action is overdue with readable text', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmFilledAction(
          label: 'Delete property',
          icon: MmIcons.delete,
          destructive: true,
          onPressed: tapped,
        ),
        variant: variant,
      );
      final colors = colorsOf(variant);
      final fill = _material(tester).color!;
      final ink = styleOf(tester, 'Delete property').color!;
      expect(fill, colors.overdue);
      // The theme's on-error colour: the surface role.
      expect(ink, colors.surface);
      expect(_contrast(fill, ink), greaterThanOrEqualTo(4.5));
      expect(iconColorOf(tester, MmIcons.delete), ink);
    });

    testWidgets('a disabled action takes the theme disabled colours', (
      tester,
    ) async {
      for (final destructive in [false, true]) {
        await pumpThemed(
          tester,
          MmFilledAction(
            label: _label,
            destructive: destructive,
            onPressed: null,
          ),
        );
        final color = _material(tester).color;
        expect(color, isNot(MmColorModes.light.primary));
        expect(color, isNot(MmColorModes.light.overdue));
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          isSemantics(isButton: true, isEnabled: false),
        );
      }
    });

    testWidgets('shows its icon before the label, mirrored for Urdu', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmFilledAction(
          label: _label,
          icon: MmIcons.add,
          onPressed: tapped,
        ),
      );
      expect(
        tester.getCenter(find.byIcon(MmIcons.add)).dx,
        lessThan(tester.getCenter(find.text(_label)).dx),
      );
      expect(tester.getSize(find.byIcon(MmIcons.add)).width, MmSize.iconMd);
      await pumpThemed(
        tester,
        const MmFilledAction(
          label: _label,
          icon: MmIcons.add,
          onPressed: tapped,
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getCenter(find.byIcon(MmIcons.add)).dx,
        greaterThan(tester.getCenter(find.text(_label)).dx),
      );
    });

    testEveryVariant('keyboard focus draws the ring outside the fill', (
      tester,
      variant,
    ) async {
      useKeyboardHighlights();
      for (final destructive in [false, true]) {
        await pumpThemed(
          tester,
          MmFilledAction(
            key: ValueKey(destructive),
            label: _label,
            destructive: destructive,
            onPressed: tapped,
          ),
          variant: variant,
        );
        final colors = colorsOf(variant);
        final shape = _material(tester).shape! as OutlinedBorder;
        expect(shape, isNot(isA<MmFocusRingBorder>()));
        expect(shape.side, BorderSide.none);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, _label), isTrue);
        final focused = _material(tester).shape! as MmFocusRingBorder;
        expect(focused.color, colors.focus);
        expect(focused.width, MmSize.focusRing);
        expect(focused.side, BorderSide.none);
      }
    });

    testWidgets('activates on tap, Enter and Space', (tester) async {
      var presses = 0;
      await pumpThemed(
        tester,
        MmFilledAction(label: _label, onPressed: () => presses++),
      );
      await tester.tap(find.text(_label));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(presses, 3);
    });

    testWidgets('a long label wraps at 200% text without overflow', (
      tester,
    ) async {
      const long = 'Send the October rent reminder to Ayesha Khan';
      await pumpLargeNarrow(
        tester,
        const MmFilledAction(
          label: long,
          icon: MmIcons.send,
          onPressed: tapped,
        ),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(long)).height, greaterThan(60));
    });
  });
}
