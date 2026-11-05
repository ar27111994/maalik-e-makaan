import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

enum _Status { overdue, dueSoon, paid }

const List<MmFilterOption<_Status>> _statuses = [
  MmFilterOption(value: _Status.overdue, label: 'Overdue', count: 3),
  MmFilterOption(value: _Status.dueSoon, label: 'Due soon', count: 1234),
  MmFilterOption(value: _Status.paid, label: 'Paid'),
];

Widget _chips({
  Set<_Status> selected = const {},
  List<Set<_Status>>? log,
  bool multiSelect = true,
  bool enabled = true,
}) => MmFilterChips<_Status>(
  options: _statuses,
  selected: selected,
  multiSelect: multiSelect,
  onChanged: enabled ? (value) => log?.add(value) : null,
);

/// The chip showing [label].
Finder _chip(String label) => find.ancestor(
  of: find.textContaining(label, findRichText: true),
  matching: find.byType(FilterChip),
);

void main() {
  group('MmFilterOption', () {
    test('compares by value, label and count', () {
      const a = MmFilterOption(value: 1, label: 'Paid', count: 3);
      final same = MmFilterOption(
        value: int.parse('1'),
        label: 'Paid',
        count: 3,
      );
      expect(same, a);
      expect(same.hashCode, a.hashCode);
      expect(a, isNot(const MmFilterOption(value: 2, label: 'Paid', count: 3)));
      expect(a, isNot(const MmFilterOption(value: 1, label: 'Due', count: 3)));
      expect(a, isNot(const MmFilterOption(value: 1, label: 'Paid')));
      expect(a, isNot('Paid'));
    });
  });

  group('MmFilterChips', () {
    testWidgets('shows labels with grouped counts; checks the selected', (
      tester,
    ) async {
      await pumpThemed(tester, _chips(selected: {_Status.overdue}));
      expect(find.text('Overdue · 3', findRichText: true), findsOneWidget);
      expect(find.text('Due soon · 1,234', findRichText: true), findsOneWidget);
      expect(find.text('Paid', findRichText: true), findsOneWidget);
      expect(find.byIcon(MmIcons.check), findsOneWidget);
      expect(
        find.descendant(
          of: _chip('Overdue'),
          matching: find.byIcon(MmIcons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('each chip is a button with its selection', (tester) async {
      await pumpThemed(tester, _chips(selected: {_Status.overdue}));
      expect(
        tester.getSemantics(_chip('Overdue')),
        matchesSemantics(
          label: 'Overdue 3',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(_chip('Paid')),
        matchesSemantics(
          label: 'Paid',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('several chips toggle independently', (tester) async {
      final log = <Set<_Status>>[];
      await pumpThemed(tester, _chips(selected: {_Status.overdue}, log: log));
      // The row scrolls the last chip into view.
      await tester.ensureVisible(_chip('Paid'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Paid'));
      await tester.ensureVisible(_chip('Overdue'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Overdue'));
      expect(log, [
        {_Status.overdue, _Status.paid},
        <_Status>{},
      ]);
    });

    testWidgets('single select replaces the choice and can clear it', (
      tester,
    ) async {
      final log = <Set<_Status>>[];
      await pumpThemed(
        tester,
        _chips(selected: {_Status.overdue}, multiSelect: false, log: log),
      );
      // The row scrolls the last chip into view.
      await tester.ensureVisible(_chip('Paid'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Paid'));
      await tester.ensureVisible(_chip('Overdue'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Overdue'));
      expect(log, [
        {_Status.paid},
        <_Status>{},
      ]);
      expect(
        tester.getSemantics(_chip('Paid')),
        matchesSemantics(
          label: 'Paid',
          isButton: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('Enter and Space toggle the focused chip, which is ringed', (
      tester,
    ) async {
      final log = <Set<_Status>>[];
      await pumpThemed(tester, _chips(log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // The theme rings a focused chip; the chip adds no border of its own.
      final chip = tester.widget<FilterChip>(_chip('Overdue'));
      expect(chip.side, isNull);
      final side =
          ChipTheme.of(tester.element(_chip('Overdue'))).side!
              as WidgetStateBorderSide;
      expect(
        side.resolve({WidgetState.focused}),
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [
        {_Status.overdue},
        {_Status.dueSoon},
      ]);
    });

    testWidgets('outlines: muted ink, cobalt when selected, rule disabled', (
      tester,
    ) async {
      await pumpThemed(tester, _chips());
      expect(tester.widget<FilterChip>(_chip('Paid')).side, isNull);
      final side =
          ChipTheme.of(tester.element(_chip('Paid'))).side!
              as WidgetStateBorderSide;
      const colors = MmColorModes.light;
      expect(side.resolve({}), BorderSide(color: colors.inkMuted));
      expect(
        side.resolve({WidgetState.selected}),
        BorderSide(color: colors.primary),
      );
      expect(
        side.resolve({WidgetState.disabled, WidgetState.focused}),
        BorderSide(color: colors.rule),
      );
    });

    testWidgets('a null onChanged disables every chip', (tester) async {
      final log = <Set<_Status>>[];
      await pumpThemed(
        tester,
        _chips(selected: {_Status.paid}, enabled: false, log: log),
      );
      await tester.tap(_chip('Overdue'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(
        tester.getSemantics(_chip('Paid')),
        matchesSemantics(
          label: 'Paid',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
        ),
      );
    });

    testWidgets('scrolls sideways on a phone, wraps on a tablet', (
      tester,
    ) async {
      await pumpThemed(tester, _chips());
      expect(
        find.descendant(
          of: find.byType(MmFilterChips<_Status>),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.byType(Wrap), findsNothing);

      await pumpThemed(tester, _chips(), size: const Size(700, 600));
      expect(find.byType(Wrap), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MmFilterChips<_Status>),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });

    testWidgets('in Urdu, counts and Latin labels are set in Atkinson', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmFilterChips<int>(
          options: const [
            MmFilterOption(value: 1, label: 'واجب الادا', count: 3),
            MmFilterOption(value: 2, label: 'DHA'),
          ],
          selected: const {},
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      final spans = <String, TextStyle?>{};
      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        text.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) {
            spans[span.text!] = span.style;
          }
          return true;
        });
      }
      expect(spans['واجب الادا']!.fontFamily, isNull);
      expect(spans[' · 3']!.fontFamily, contains(MmFontFamily.latin));
      expect(spans['DHA']!.fontFamily, contains(MmFontFamily.latin));
    });

    testWidgets('right to left: the first chip sits at the right', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _chips(selected: {_Status.overdue}),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getRect(_chip('Overdue')).left,
        greaterThan(tester.getRect(_chip('Due soon')).right),
      );
      // The check mark leads the label.
      expect(
        tester.getRect(find.byIcon(MmIcons.check)).left,
        greaterThan(
          tester
              .getRect(find.textContaining('Overdue', findRichText: true))
              .right,
        ),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone, and wraps when wider', (
      tester,
    ) async {
      final chips = Builder(
        builder: (context) {
          final tr = sayIn(context);
          return MmFilterChips<_Status>(
            options: [
              MmFilterOption(
                value: _Status.overdue,
                label: tr('Overdue more than a month', 'ایک ماہ سے زیادہ واجب'),
                count: 3,
              ),
              MmFilterOption(
                value: _Status.dueSoon,
                label: tr('Due this week', 'اس ہفتے واجب'),
                count: 5,
              ),
              MmFilterOption(
                value: _Status.paid,
                label: tr('Paid', 'ادا شدہ'),
                count: 12,
              ),
            ],
            selected: const {_Status.overdue},
            onChanged: (_) {},
          );
        },
      );
      await expectFitsNarrowLargeText(tester, chips);
      await expectFitsNarrowLargeText(tester, chips, width: 640);
      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
