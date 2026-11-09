import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

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
  EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
}) => MmFilterChips<_Status>(
  options: _statuses,
  selected: selected,
  multiSelect: multiSelect,
  padding: padding,
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

    testEveryVariant('the check grows with the label as icons do, up to '
        '150%', (tester, variant) async {
      await pumpThemed(
        tester,
        _chips(selected: {_Status.paid}),
        variant: variant,
      );
      final scale = variant.textScale > 1.5 ? 1.5 : variant.textScale;
      expect(
        tester.getSize(find.byIcon(MmIcons.check)),
        Size.square(MmSize.iconMd * scale),
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

    testWidgets('a focused, selected chip rings itself outside, uncut', (
      tester,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, _chips(selected: {_Status.overdue}));
      final theme = ChipTheme.of(tester.element(_chip('Overdue')));
      final shape = theme.shape! as WidgetStateOutlinedBorder;
      const colors = MmColorModes.light;
      // Selected and focused: a ring past a gap, the cobalt frame kept.
      final focused = shape.resolve({
        WidgetState.focused,
        WidgetState.selected,
      })!;
      expect(focused, isA<MmFocusRingBorder>());
      expect((focused as MmFocusRingBorder).color, colors.focus);
      final side = theme.side! as WidgetStateBorderSide;
      expect(
        side.resolve({WidgetState.focused, WidgetState.selected}),
        BorderSide(color: colors.primary),
      );
      // Unselected and focused: the ring on the edge, as before.
      expect(
        shape.resolve({WidgetState.focused}),
        isNot(isA<MmFocusRingBorder>()),
      );
      // The scrolling row leaves the ring room at its ends.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final clip = tester.renderObject<RenderClipRect>(
        find
            .descendant(
              of: find.byType(MmFilterChips<_Status>),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      final room = clip.clipper!.getClip(clip.size);
      // The room depends on the row's size alone.
      expect(clip.clipper!.shouldReclip(clip.clipper!), isFalse);
      final chip = tester.getRect(_chip('Overdue'));
      final row = tester.getRect(find.byType(MmFilterChips<_Status>));
      expect(
        chip.left - (row.left + room.left),
        greaterThanOrEqualTo(MmSize.focusGap + MmSize.focusRing),
      );
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
      // Painted as enabled, a disabled chip still reports nothing.
      tester.widget<FilterChip>(_chip('Overdue')).onSelected!(true);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      // Not reachable from the keyboard either.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FilterChip>(),
        isNull,
      );
    });

    testEveryVariant('disabled chips stay readable', (tester, variant) async {
      await pumpThemed(
        tester,
        _chips(selected: {_Status.paid}, enabled: false),
        variant: variant,
      );
      final colors = variant.colors;
      for (final label in ['Overdue', 'Paid']) {
        final chip = tester.widget<FilterChip>(_chip(label));
        // Painted as enabled, so Material does not fade the label to 38%.
        expect(chip.onSelected, isNotNull);
        expect(chip.labelStyle!.color, colors.inkMuted);
        expect(chip.backgroundColor, colors.surfaceSunken);
        expect(chip.selectedColor, colors.surfaceSunken);
        expect(chip.side, BorderSide(color: colors.rule));
        expect(
          mmContrastRatio(colors.inkMuted, colors.surfaceSunken),
          greaterThanOrEqualTo(mmMinimumTextContrast),
        );
      }
      expect(iconColorOf(tester, MmIcons.check), colors.inkMuted);
      // The label is painted in muted ink at full strength, not faded.
      final label = paragraphOf(tester, 'Paid');
      expect(label.text.style!.color, colors.inkMuted);
      expect(
        find.ancestor(
          of: find.textContaining('Paid', findRichText: true),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('padding lets the row run edge to edge, lined up', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: _chips(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MmSpace.s4,
              ),
            ),
          ),
        ),
      );
      final row = tester.getRect(find.byType(MmFilterChips<_Status>));
      expect(row.left, 0);
      expect(row.width, 360);
      // The first chip lines up with the page's 16 dp margin; the row
      // scrolls to the screen's edge.
      expect(tester.getRect(_chip('Overdue')).left, MmSpace.s4);
      await tester.drag(_chip('Due soon'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(_chip('Paid')).right, 360 - MmSpace.s4);
      // Wrapped on a wide window, the chips sit inside the padding too.
      await resizeScreen(tester, const Size(700, 600));
      expect(tester.getRect(_chip('Overdue')).left, MmSpace.s4);
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
