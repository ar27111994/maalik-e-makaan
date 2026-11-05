import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';

import '../../support/testing.dart';

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

/// Whether the tile draws its focus ring.
bool _ringShown(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(MmFocusWithin),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).border != null;
}

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
        tester.getSemantics(find.byType(SwitchListTile)),
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
      final thumb = tester.widget<Switch>(find.byType(Switch)).thumbIcon!;
      expect(thumb.resolve({WidgetState.selected})!.icon, MmIcons.check);
      expect(thumb.resolve({}), isNull);
    });

    testWidgets('Enter and Space toggle; keyboard focus draws a ring', (
      tester,
    ) async {
      final log = <bool>[];
      await pumpThemed(tester, _tile(log: log));
      expect(_ringShown(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_ringShown(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [true, true]);
      // Touching the screen hides the ring; focus stays.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(_ringShown(tester), isFalse);
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
        tester.getSemantics(find.byType(SwitchListTile)),
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
  });
}
