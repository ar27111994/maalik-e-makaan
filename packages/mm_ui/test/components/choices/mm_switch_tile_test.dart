import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';
import 'page_edge.dart';

Widget _tile({
  bool value = false,
  List<bool>? log,
  bool enabled = true,
  String? description,
}) => MmSwitchTile(
  label: 'Send rent reminders',
  description: description,
  value: value,
  onChanged: enabled ? (on) => log?.add(on) : null,
);

void main() {
  group('MmSwitchTile', () {
    testWidgets('the whole row toggles', (tester) async {
      final log = <bool>[];
      await pumpThemed(
        tester,
        _tile(log: log, description: 'Three days before rent is due'),
      );
      await tester.tap(find.text('Send rent reminders'));
      await tester.tap(find.text('Three days before rent is due'));
      await tester.tap(find.byType(Switch));
      expect(log, [true, true, true]);
    });

    testWidgets('is one switch with its label, description and state', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _tile(value: true, description: 'Three days before rent is due'),
      );
      expect(
        tester.getSemantics(find.byType(ListTile)),
        matchesSemantics(
          label: 'Send rent reminders\nThree days before rent is due',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          // ListTile reports its (unused) selection state.
          hasSelectedState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('the thumb carries a check mark while on', (tester) async {
      await pumpThemed(tester, _tile(value: true));
      final thumb = SwitchTheme.of(tester.element(find.byType(Switch)))
          .thumbIcon!;
      expect(thumb.resolve({WidgetState.selected})!.icon, MmIcons.check);
      expect(thumb.resolve({}), isNull);
    });

    testEveryVariant('disabled, the switch stays readable', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        Column(
          children: [_tile(value: true, enabled: false), _tile(enabled: false)],
        ),
        variant: variant,
      );
      final colors = variant.colors;
      final theme = SwitchTheme.of(tester.element(find.byType(Switch).first));
      for (final on in [true, false]) {
        final states = {WidgetState.disabled, if (on) WidgetState.selected};
        final thumb = theme.thumbColor!.resolve(states)!;
        final track = theme.trackColor!.resolve(states)!;
        final outline = theme.trackOutlineColor!.resolve(states)!;
        // Muted ink, not cobalt or ink at 38%, on sunken paper.
        expect(thumb, colors.inkMuted, reason: 'on: $on');
        expect(outline, colors.inkMuted, reason: 'on: $on');
        expect(track, colors.surfaceSunken, reason: 'on: $on');
        expect(
          mmContrastRatio(thumb, track),
          greaterThanOrEqualTo(mmMinimumIconContrast),
          reason: 'on: $on',
        );
        expect(
          mmContrastRatio(outline, colors.surface),
          greaterThanOrEqualTo(mmMinimumIconContrast),
          reason: 'on: $on',
        );
      }
      // The check mark on a disabled thumb is paper on muted ink.
      final icon = theme.thumbIcon!.resolve({
        WidgetState.disabled,
        WidgetState.selected,
      })!;
      expect(
        mmContrastRatio(icon.color!, colors.inkMuted),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      // Enabled, the switch is ink (off) or cobalt (on), unlike disabled.
      expect(theme.thumbColor!.resolve({}), colors.ink);
      expect(theme.trackColor!.resolve({WidgetState.selected}), colors.primary);
    });

    testWidgets('Enter and Space toggle; keyboard focus draws a ring', (
      tester,
    ) async {
      final log = <bool>[];
      await pumpThemed(tester, _tile(log: log));
      expect(ringShown(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringShown(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [true, true]);
      // Touching the screen hides the ring; focus stays.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(ringShown(tester), isFalse);
    });

    testWidgets('a null onChanged disables the row, readably', (tester) async {
      final log = <bool>[];
      await pumpThemed(tester, _tile(value: true, enabled: false, log: log));
      await tester.tap(find.text('Send rent reminders'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(
        tester.getSemantics(find.byType(ListTile)),
        matchesSemantics(
          label: 'Send rent reminders',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          // ListTile reports its (unused) selection state.
          hasSelectedState: true,
        ),
      );
      final text = tester.widget<Text>(find.text('Send rent reminders'));
      expect(text.style!.color, MmColorModes.light.inkMuted);
    });

    testWidgets('Latin text in the Urdu UI is set in Atkinson', (tester) async {
      await pumpThemed(
        tester,
        const MmSwitchTile(
          label: 'WhatsApp',
          description: 'یاد دہانی',
          value: false,
          onChanged: null,
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.widget<Text>(find.text('WhatsApp')).style!.fontFamily,
        contains(MmFontFamily.latin),
      );
      expect(
        tester.widget<Text>(find.text('یاد دہانی')).style!.fontFamily,
        contains(MmFontFamily.urdu),
      );
    });

    testWidgets('right to left: the switch sits at the left', (tester) async {
      await pumpThemed(
        tester,
        MmSwitchTile(
          label: 'کرایہ کی یاد دہانی بھیجیں',
          value: true,
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getRect(find.byType(Switch)).right,
        lessThan(tester.getRect(find.text('کرایہ کی یاد دہانی بھیجیں')).left),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final tr = sayIn(context);
            return MmSwitchTile(
              label: tr(
                'Add a late fee after the grace period',
                'رعایتی مدت کے بعد تاخیر کی فیس شامل کریں',
              ),
              description: tr(
                'Rs 500 a day, up to Rs 5,000',
                'روزانہ 500 روپے، زیادہ سے زیادہ 5,000 روپے',
              ),
              value: true,
              onChanged: (_) {},
            );
          },
        ),
      );
    });

    group('lines its switch up with the page content', () {
      for (final (variant, width) in const [
        (MmVariant.light, 360.0),
        (MmVariant.urdu, 360.0),
        (MmVariant.light, 1280.0),
        (MmVariant.largeText, 360.0),
      ]) {
        testWidgets('${variant.name}, ${width.toInt()} dp', (tester) async {
          final content = await pumpOnPage(
            tester,
            MmSwitchTile(
              label: 'Send rent reminders',
              value: true,
              onChanged: (_) {},
            ),
            width: width,
            variant: variant,
          );
          final control = find.byType(Switch);
          final label = tester.getRect(find.text('Send rent reminders'));
          final box = tester.getRect(control);
          if (variant == MmVariant.urdu) {
            expect(label.right, content.right);
          } else {
            expect(label.left, content.left);
          }
          // The visible track, not just the switch's box, ends on the
          // content edge, where the heading and the field end.
          await expectInkOnEdge(
            tester,
            box,
            content,
            variant: variant,
            atStart: false,
          );
          // The switch grows with the text as icons do: about half again
          // at 200% (a little less where the row's trailing slot is
          // shorter), never more.
          final track = await inkIn(tester, box);
          if (variant == MmVariant.largeText) {
            expect(track.width, inInclusiveRange(52 * 1.35, 52 * 1.5 + 1));
          } else {
            expect(track.width, closeTo(52, 1));
          }
          expectTileInGutter(tester, control, content);
        });
      }
    });
  });
}
