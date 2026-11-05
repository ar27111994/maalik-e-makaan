import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

enum _Period { month, quarter, year }

const _periods = <MmSegment<_Period>>[
  MmSegment(value: _Period.month, label: 'Monthly'),
  MmSegment(value: _Period.quarter, label: 'Quarterly'),
  MmSegment(value: _Period.year, label: 'Yearly'),
];

/// A control over [_periods] (or [segments]) with [selected] chosen.
Widget _control({
  _Period selected = _Period.month,
  ValueChanged<_Period>? onChanged,
  List<MmSegment<_Period>> segments = _periods,
}) => MmSegmentedControl<_Period>(
  segments: segments,
  selected: selected,
  onChanged: onChanged,
);

/// Sets [child] at twice the ambient text size.
Widget _doubleText(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

/// The segment button showing [label].
Finder _segment(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextButton));

/// The Material that paints the segment showing [label].
Material _material(WidgetTester tester, String label) => tester.widget(
  find.descendant(of: _segment(label), matching: find.byType(Material)).first,
);

/// The colour [label] is painted in.
Color _textColor(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!.color!;

/// The control's sideways scroll position.
ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(MmSegmentedControl<_Period>),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Whether all of [label] is inside the control's viewport.
bool _inView(WidgetTester tester, String label) {
  final viewport = tester.getRect(
    find.descendant(
      of: find.byType(MmSegmentedControl<_Period>),
      matching: find.byType(Scrollable),
    ),
  );
  final text = tester.getRect(find.text(label));
  return text.left >= viewport.left - 0.5 && text.right <= viewport.right + 0.5;
}

void main() {
  group('MmSegment', () {
    test('compares by value, label and icon', () {
      const a = MmSegment(value: 1, label: 'Cash', icon: MmIcons.cash);
      // Built at run time, so it is not the same instance as [a].
      final same = MmSegment(
        value: int.parse('1'),
        label: 'Cash',
        icon: MmIcons.cash,
      );
      expect(same, a);
      expect(same.hashCode, a.hashCode);
      expect(
        a,
        isNot(const MmSegment(value: 2, label: 'Cash', icon: MmIcons.cash)),
      );
      expect(
        a,
        isNot(const MmSegment(value: 1, label: 'Bank', icon: MmIcons.cash)),
      );
      expect(a, isNot(const MmSegment(value: 1, label: 'Cash')));
      expect(a, isNot('Cash'));
    });
  });

  group('MmSegmentedControl', () {
    testWidgets('shows every label; a check mark marks the selected one', (
      tester,
    ) async {
      await pumpThemed(tester, _control(onChanged: (_) {}));
      for (final segment in _periods) {
        expect(find.text(segment.label), findsOneWidget);
      }
      expect(find.byType(SegmentedButton<_Period>), findsOneWidget);
      expect(find.byIcon(MmIcons.check), findsOneWidget);
      final check = tester.getCenter(find.byIcon(MmIcons.check));
      expect(tester.getRect(_segment('Monthly')).contains(check), isTrue);
    });

    testWidgets("the check mark replaces the selected segment's icon", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmSegmentedControl<String>(
          segments: const [
            MmSegment(value: 'cash', label: 'Cash', icon: MmIcons.cash),
            MmSegment(value: 'bank', label: 'Bank', icon: MmIcons.bank),
          ],
          selected: 'bank',
          onChanged: (_) {},
        ),
      );
      expect(find.byIcon(MmIcons.cash), findsOneWidget);
      expect(find.byIcon(MmIcons.bank), findsNothing);
      expect(find.byIcon(MmIcons.check), findsOneWidget);
    });

    testWidgets('reports the chosen value, never the selected one', (
      tester,
    ) async {
      final chosen = <_Period>[];
      await pumpThemed(tester, _control(onChanged: chosen.add));
      await tester.tap(find.text('Quarterly'));
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(chosen, [_Period.quarter]);
    });

    testWidgets('Tab reaches each segment; Enter and Space choose it', (
      tester,
    ) async {
      final chosen = <_Period>[];
      await pumpThemed(tester, _control(onChanged: chosen.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Quarterly'))).hasPrimaryFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(chosen, [_Period.quarter, _Period.year]);
    });

    testWidgets('each segment is a button in a mutually exclusive group', (
      tester,
    ) async {
      await pumpThemed(tester, _control(onChanged: (_) {}));
      for (final segment in _periods) {
        final selected = segment.value == _Period.month;
        expect(
          tester.getSemantics(find.text(segment.label)),
          matchesSemantics(
            label: segment.label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasSelectedState: true,
            isSelected: selected,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
          reason: segment.label,
        );
      }
    });

    testWidgets('a null onChanged disables every segment', (tester) async {
      await pumpThemed(tester, _control());
      await tester.tap(find.text('Quarterly'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Quarterly')),
        matchesSemantics(
          label: 'Quarterly',
          isButton: true,
          hasEnabledState: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(find.byIcon(MmIcons.check), findsOneWidget);
    });

    testEveryVariant('the selected segment is tonal cobalt, the rest paper', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpThemed(tester, _control(onChanged: (_) {}), variant: variant);
      expect(_material(tester, 'Monthly').color, colors.primaryContainer);
      expect(_textColor(tester, 'Monthly'), colors.onPrimaryContainer);
      expect(_material(tester, 'Yearly').color, colors.surface);
      expect(_textColor(tester, 'Yearly'), colors.ink);
    });

    testEveryVariant('disabled segments stay readable in muted ink', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpThemed(tester, _control(), variant: variant);
      expect(_material(tester, 'Monthly').color, colors.surfaceSunken);
      expect(_textColor(tester, 'Monthly'), colors.inkMuted);
      expect(_material(tester, 'Yearly').color, colors.surface);
      expect(_textColor(tester, 'Yearly'), colors.inkMuted);
    });

    testWidgets('outlines the control; a ring shows while it has focus', (
      tester,
    ) async {
      await pumpThemed(tester, _control(onChanged: (_) {}));
      const colors = MmColorModes.light;
      final button = find.byType(SegmentedButton<_Period>);
      // The theme styles the control; it adds no style of its own.
      expect(tester.widget<SegmentedButton<_Period>>(button).style, isNull);
      final side = SegmentedButtonTheme.of(tester.element(button)).style!.side!;
      expect(side.resolve({}), BorderSide(color: colors.outline));
      expect(
        side.resolve({WidgetState.focused}),
        BorderSide(color: colors.focus, width: MmSize.focusRing),
      );
      expect(
        side.resolve({WidgetState.disabled}),
        BorderSide(color: colors.rule),
      );
    });

    testWidgets('segments are 48 dp tall targets in English and Urdu', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        await pumpThemed(tester, _control(onChanged: (_) {}), variant: variant);
        for (final segment in _periods) {
          expect(tester.getSize(_segment(segment.label)).height, 48);
        }
        expect(
          tester.getSize(find.byType(MmSegmentedControl<_Period>)).height,
          48,
        );
      }
    });

    testWidgets('labels wrap inside their segments before it scrolls', (
      tester,
    ) async {
      const segments = [
        MmSegment(value: _Period.month, label: 'Rent due'),
        MmSegment(value: _Period.quarter, label: 'Paid in full'),
      ];
      await pumpThemed(
        tester,
        _control(segments: segments, onChanged: (_) {}),
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      expect(_scroll(tester).maxScrollExtent, 0);
      expect(
        tester.getSize(find.byType(MmSegmentedControl<_Period>)).width,
        lessThanOrEqualTo(288),
      );
      final wrapped = tester.renderObject<RenderParagraph>(
        find.text('Paid in full'),
      );
      expect(wrapped.size.height, greaterThan(40));
      expect(_inView(tester, 'Paid in full'), isTrue);
    });

    testWidgets('scrolls, keeping the selection in view, when wrapping fails', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _control(selected: _Period.year, onChanged: (_) {}),
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      final scroll = _scroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(_inView(tester, 'Yearly'), isTrue);
      expect(_inView(tester, 'Monthly'), isFalse);
    });

    testWidgets('follows a new selection, animating the least distance', (
      tester,
    ) async {
      var selected = _Period.month;
      late StateSetter update;
      // At 200% text, two of the three segments fit 400 dp.
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _control(
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            );
          },
        ),
        variant: MmVariant.largeText,
        size: const Size(400, 740),
      );
      final scroll = _scroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      expect(scroll.pixels, 0);
      expect(_inView(tester, 'Yearly'), isFalse);

      // A segment already in view moves nothing.
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();
      expect(selected, _Period.quarter);
      expect(scroll.pixels, 0);

      // One out of view slides in, just far enough.
      update(() => selected = _Period.year);
      await tester.pump();
      // The animation's first frame is its start; look a little later.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scroll.pixels, inExclusiveRange(0, scroll.maxScrollExtent));
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(_inView(tester, 'Yearly'), isTrue);

      // Back to one in view: nothing moves (the check mark moving to a
      // longer label may widen every segment, but not the scroll offset).
      final before = scroll.pixels;
      update(() => selected = _Period.quarter);
      await tester.pumpAndSettle();
      expect(scroll.pixels, before);
      expect(_inView(tester, 'Quarterly'), isTrue);

      update(() => selected = _Period.month);
      await tester.pumpAndSettle();
      expect(scroll.pixels, 0);
      expect(_inView(tester, 'Monthly'), isTrue);
    });

    testWidgets('jumps instead of animating when motion is reduced', (
      tester,
    ) async {
      var selected = _Period.month;
      late StateSetter update;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return _control(selected: selected, onChanged: (_) {});
              },
            ),
          ),
        ),
        variant: MmVariant.largeText,
        size: const Size(320, 740),
      );
      update(() => selected = _Period.year);
      await tester.pump();
      // One frame later it is already there.
      final scroll = _scroll(tester);
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(_inView(tester, 'Yearly'), isTrue);
    });

    testWidgets('scrolls the other way in Urdu', (tester) async {
      const segments = [
        MmSegment(value: _Period.month, label: 'ادائیگیاں'),
        MmSegment(value: _Period.quarter, label: 'بقایاجات'),
        MmSegment(value: _Period.year, label: 'کرایہ‌داران'),
      ];
      var selected = _Period.month;
      late StateSetter update;
      await pumpThemed(
        tester,
        _doubleText(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _control(
                segments: segments,
                selected: selected,
                onChanged: (_) {},
              );
            },
          ),
        ),
        variant: MmVariant.urdu,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      final scroll = _scroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      // The first segment sits at the right, in view from the start.
      expect(scroll.pixels, 0);
      final first = tester.getRect(find.text('ادائیگیاں'));
      final last = tester.getRect(find.text('کرایہ‌داران'));
      expect(first.left, greaterThan(last.left));
      expect(_inView(tester, 'ادائیگیاں'), isTrue);

      update(() => selected = _Period.year);
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(_inView(tester, 'کرایہ‌داران'), isTrue);
    });

    testWidgets('a selection that matches no segment selects none', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _control(
          segments: _periods.sublist(0, 2),
          selected: _Period.year,
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(MmIcons.check), findsNothing);
    });

    testWidgets('keeps its segments while they stay equal', (tester) async {
      await pumpThemed(tester, _control(segments: [..._periods]));
      List<ButtonSegment<_Period>> current() => tester
          .widget<SegmentedButton<_Period>>(
            find.byType(SegmentedButton<_Period>),
          )
          .segments;
      final before = current();
      await pumpThemed(tester, _control(segments: [..._periods]));
      expect(current(), same(before));

      await pumpThemed(
        tester,
        _control(
          segments: const [
            MmSegment(value: _Period.month, label: 'This month'),
            MmSegment(value: _Period.year, label: 'This year'),
          ],
        ),
      );
      expect(current(), isNot(same(before)));
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);
    });

    testWidgets('re-fits when the window narrows', (tester) async {
      await pumpThemed(
        tester,
        _control(selected: _Period.year, onChanged: (_) {}),
        variant: MmVariant.largeText,
        size: const Size(800, 740),
      );
      expect(_scroll(tester).maxScrollExtent, 0);
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_scroll(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('its dry layout agrees with its layout', (tester) async {
      for (final size in [const Size(360, 740), const Size(320, 740)]) {
        await pumpThemed(
          tester,
          _control(onChanged: (_) {}),
          variant: MmVariant.largeText,
          size: size,
        );
        final button = tester.renderObject<RenderBox>(
          find.byType(SegmentedButton<_Period>),
        );
        final fit = button.parent! as RenderBox;
        expect(fit.getDryLayout(fit.constraints), fit.size);
      }
    });

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        MmSegmentedControl<String>(
          segments: const [
            MmSegment(value: 'cash', label: 'Cash', icon: MmIcons.cash),
            MmSegment(
              value: 'bank',
              label: 'Bank transfer',
              icon: MmIcons.bank,
            ),
            MmSegment(value: 'card', label: 'Card', icon: MmIcons.card),
          ],
          selected: 'bank',
          onChanged: (_) {},
        ),
        variant: variant,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      await expectAccessible(tester);
    });
  });
}
