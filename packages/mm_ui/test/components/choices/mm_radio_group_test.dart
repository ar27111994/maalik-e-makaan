import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

enum _Method { cash, bank, card }

const List<MmOption<_Method>> _methods = [
  MmOption(value: _Method.cash, label: 'Cash', icon: MmIcons.cash),
  MmOption(
    value: _Method.bank,
    label: 'Bank transfer',
    description: 'Meezan Bank, Gulberg',
    icon: MmIcons.bank,
  ),
  MmOption(value: _Method.card, label: 'Card'),
];

/// A group whose value follows what it reports, as an app's would.
class _Controlled extends StatefulWidget {
  const new({required this.log, this.initial});

  final List<_Method?> log;
  final _Method? initial;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  late _Method? _value = widget.initial;

  @override
  Widget build(BuildContext context) => MmRadioGroup<_Method>(
    label: 'Received by',
    options: _methods,
    value: _value,
    onChanged: (method) {
      widget.log.add(method);
      setState(() => _value = method);
    },
  );
}

/// The row showing [label].
Finder _row(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(RadioListTile<_Method>),
);

void main() {
  group('MmRadioGroup', () {
    testWidgets('shows the label and every option with its details', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmRadioGroup<_Method>(
          label: 'Received by',
          options: _methods,
          value: _Method.bank,
          onChanged: (_) {},
        ),
      );
      expect(find.text('Received by'), findsOneWidget);
      for (final option in _methods) {
        expect(find.text(option.label), findsOneWidget);
      }
      expect(find.text('Meezan Bank, Gulberg'), findsOneWidget);
      expect(find.byIcon(MmIcons.cash), findsOneWidget);
      expect(find.byIcon(MmIcons.bank), findsOneWidget);
      expect(find.byType(RadioGroup<_Method>), findsOneWidget);
    });

    testWidgets('the group is named by its label; each row is a radio', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmRadioGroup<_Method>(
          label: 'Received by',
          options: _methods,
          value: _Method.bank,
          onChanged: (_) {},
        ),
      );
      final group = tester.getSemantics(find.byType(RadioGroup<_Method>));
      expect(group.label, 'Received by');
      expect(group.role, SemanticsRole.radioGroup);
      expect(group.childrenCount, _methods.length);
      expect(find.bySemanticsLabel('Received by'), findsOneWidget);
      expect(
        tester.getSemantics(_row('Bank transfer')),
        matchesSemantics(
          label: 'Bank transfer\nMeezan Bank, Gulberg',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(_row('Cash')),
        matchesSemantics(
          label: 'Cash',
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('the label sits as a field label does, with its marker', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmSelectField<String>(
              label: 'Property',
              options: const [MmOption(value: 'g', label: 'Gulberg Heights')],
              onChanged: (_) {},
            ),
            MmRadioGroup<_Method>(
              label: 'Received by',
              options: _methods,
              value: null,
              required: true,
              helper: 'As written on the receipt',
              onChanged: (_) {},
            ),
          ],
        ),
      );
      // The same inset and gap as a field's label.
      final field = tester.getRect(find.text('Property', findRichText: true));
      final group = tester.getRect(
        find.text('Received by  Required', findRichText: true),
      );
      expect(group.left, field.left);
      final firstRow = tester.getRect(_row('Cash'));
      expect(firstRow.top - group.bottom, MmSpace.s2);
      expect(find.text('As written on the receipt'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(RadioGroup<_Method>));
      expect(semantics.label, 'Received by');
      expect(semantics.hint, 'Required');
    });

    testWidgets('an error replaces the helper, with an icon, live', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmRadioGroup<_Method>(
          label: 'Received by',
          options: _methods,
          value: null,
          optional: true,
          helper: 'As written on the receipt',
          errorText: 'Choose how the rent was paid',
          onChanged: (_) {},
        ),
      );
      expect(find.text('As written on the receipt'), findsNothing);
      expect(find.byIcon(MmIcons.error), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Choose how the rent was paid'),
        ),
        isSemantics(label: 'Choose how the rent was paid', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.byType(RadioGroup<_Method>)).hint,
        'Optional',
      );
    });

    testWidgets('tapping anywhere on a row chooses it', (tester) async {
      final log = <_Method?>[];
      await pumpThemed(tester, _Controlled(log: log));
      await tester.tap(find.text('Meezan Bank, Gulberg'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(MmIcons.cash));
      await tester.pumpAndSettle();
      // The chosen row again does nothing.
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      expect(log, [_Method.bank, _Method.cash]);
    });

    testWidgets('Tab enters at the choice; arrows move it; Space chooses', (
      tester,
    ) async {
      final log = <_Method?>[];
      await pumpThemed(tester, _Controlled(log: log, initial: _Method.bank));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringShown(tester, 'Bank transfer'), isTrue);
      expect(ringShown(tester, 'Cash'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(log, [_Method.card]);
      expect(ringShown(tester, 'Card'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(log, [_Method.card, _Method.bank, _Method.cash]);
    });

    testWidgets('Space chooses the focused row when nothing is chosen', (
      tester,
    ) async {
      final log = <_Method?>[];
      await pumpThemed(tester, _Controlled(log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [_Method.cash]);
    });

    testWidgets('a null onChanged disables every row, readably', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmRadioGroup<_Method>(
          label: 'Received by',
          options: _methods,
          value: _Method.bank,
          onChanged: null,
        ),
      );
      await tester.tap(find.text('Cash'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_row('Cash')),
        matchesSemantics(
          label: 'Cash',
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Received by')).style!.color,
        MmColorModes.light.inkMuted,
      );
      expect(
        tester.widget<Text>(find.text('Cash')).style!.color,
        MmColorModes.light.inkMuted,
      );
    });

    testWidgets('right to left: radios at the right, icons at the left', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmRadioGroup<_Method>(
          label: 'وصولی کا طریقہ',
          options: const [
            MmOption(value: _Method.cash, label: 'نقد', icon: MmIcons.cash),
          ],
          value: _Method.cash,
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      final text = tester.getRect(find.text('نقد'));
      expect(
        tester.getRect(find.byType(Radio<_Method>)).left,
        greaterThan(text.right),
      );
      expect(
        tester.getRect(find.byIcon(MmIcons.cash)).right,
        lessThan(text.left),
      );
      expect(
        tester.getTopRight(find.text('وصولی کا طریقہ')).dx,
        greaterThan(text.right),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final tr = sayIn(context);
            return MmRadioGroup<_Method>(
              label: tr(
                'How Ali Raza paid the rent',
                'علی رضا نے کرایہ کیسے دیا',
              ),
              options: [
                MmOption(
                  value: _Method.bank,
                  label: tr(
                    'Bank transfer to Meezan Bank',
                    'میزان بینک میں ٹرانسفر',
                  ),
                  description: tr(
                    'Rs 1,25,000 on 5 November',
                    '5 نومبر کو 1,25,000 روپے',
                  ),
                  icon: MmIcons.bank,
                ),
                MmOption(value: _Method.cash, label: tr('Cash', 'نقد')),
              ],
              value: _Method.bank,
              onChanged: (_) {},
            );
          },
        ),
      );
    });
  });
}
