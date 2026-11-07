import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

Widget _tile({
  bool? value = false,
  List<bool?>? log,
  bool enabled = true,
  bool tristate = false,
  String? description,
}) => MmCheckboxTile(
  label: 'Rent includes electricity',
  description: description,
  value: value,
  tristate: tristate,
  onChanged: enabled ? (checked) => log?.add(checked) : null,
);

void main() {
  group('MmCheckboxTile', () {
    testWidgets('the whole row toggles; the box sits at the start', (
      tester,
    ) async {
      final log = <bool?>[];
      await pumpThemed(
        tester,
        _tile(log: log, description: 'Up to Rs 8,000 a month'),
      );
      await tester.tap(find.text('Rent includes electricity'));
      await tester.tap(find.text('Up to Rs 8,000 a month'));
      await tester.tap(find.byType(Checkbox));
      expect(log, [true, true, true]);
      expect(
        tester.getRect(find.byType(Checkbox)).right,
        lessThan(tester.getRect(find.text('Rent includes electricity')).left),
      );
    });

    testWidgets('is one checkbox with its label, description and state', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _tile(value: true, description: 'Up to Rs 8,000 a month'),
      );
      expect(
        tester.getSemantics(find.byType(CheckboxListTile)),
        matchesSemantics(
          label: 'Rent includes electricity\nUp to Rs 8,000 a month',
          hasCheckedState: true,
          isChecked: true,
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

    testWidgets('a tristate box cycles unchecked, checked, mixed', (
      tester,
    ) async {
      final log = <bool?>[];
      for (final value in [false, true, null]) {
        await pumpThemed(tester, _tile(value: value, tristate: true, log: log));
        await tester.tap(find.byType(MmCheckboxTile));
      }
      expect(log, [true, null, false]);
      await pumpThemed(tester, _tile(value: null, tristate: true));
      expect(
        tester.getSemantics(find.byType(CheckboxListTile)),
        matchesSemantics(
          label: 'Rent includes electricity',
          hasCheckedState: true,
          isCheckStateMixed: true,
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

    test('only a tristate box can be mixed', () {
      expect(
        () => MmCheckboxTile(label: 'All units', value: null, onChanged: null),
        throwsAssertionError,
      );
    });

    testWidgets('Enter and Space toggle; keyboard focus draws a ring', (
      tester,
    ) async {
      final log = <bool?>[];
      await pumpThemed(tester, _tile(value: true, log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringShown(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [false, false]);
    });

    testWidgets('a null onChanged disables the row, readably', (tester) async {
      final log = <bool?>[];
      await pumpThemed(tester, _tile(value: true, enabled: false, log: log));
      await tester.tap(find.text('Rent includes electricity'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(
        tester.getSemantics(find.byType(CheckboxListTile)),
        matchesSemantics(
          label: 'Rent includes electricity',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          // ListTile reports its (unused) selection state.
          hasSelectedState: true,
        ),
      );
      final text = tester.widget<Text>(find.text('Rent includes electricity'));
      expect(text.style!.color, MmColorModes.light.inkMuted);
    });

    testEveryVariant('disabled, the box stays readable', (
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
      final theme = CheckboxTheme.of(
        tester.element(find.byType(Checkbox).first),
      );
      const checked = {WidgetState.disabled, WidgetState.selected};
      const unchecked = {WidgetState.disabled};
      BorderSide side(Set<WidgetState> states) =>
          WidgetStateProperty.resolveAs<BorderSide?>(theme.side, states)!;
      // A muted-ink frame either way; checked, sunken paper with a
      // muted-ink check instead of cobalt.
      expect(side(unchecked).color, colors.inkMuted);
      expect(side(checked).color, colors.inkMuted);
      expect(theme.fillColor!.resolve(checked), colors.surfaceSunken);
      expect(theme.checkColor!.resolve(checked), colors.inkMuted);
      expect(
        mmContrastRatio(colors.inkMuted, colors.surface),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      expect(
        mmContrastRatio(colors.inkMuted, colors.surfaceSunken),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
      // Enabled, the frame is ink and a checked box cobalt.
      expect(side({}).color, colors.ink);
      expect(theme.fillColor!.resolve({WidgetState.selected}), colors.primary);
    });

    testWidgets('right to left: the box sits at the right', (tester) async {
      await pumpThemed(
        tester,
        MmCheckboxTile(
          label: 'کرایہ میں بجلی شامل ہے',
          value: true,
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getRect(find.byType(Checkbox)).left,
        greaterThan(tester.getRect(find.text('کرایہ میں بجلی شامل ہے')).right),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final tr = sayIn(context);
            return MmCheckboxTile(
              label: tr(
                'Police verification of Ayesha Khan is done',
                'عائشہ خان کی پولیس تصدیق ہو گئی ہے',
              ),
              description: tr(
                'Form submitted at Gulberg police station',
                'گلبرگ تھانے میں فارم جمع ہو گیا',
              ),
              value: false,
              onChanged: (_) {},
            );
          },
        ),
      );
    });
  });
}
