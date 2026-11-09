import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

enum _Period { month, quarter, year }

const _periods = <MmSegment<_Period>>[
  MmSegment(value: _Period.month, label: 'Monthly'),
  MmSegment(value: _Period.quarter, label: 'Quarterly'),
  MmSegment(value: _Period.year, label: 'Yearly'),
];

const _urduPeriods = <MmSegment<_Period>>[
  MmSegment(value: _Period.month, label: 'ماہانہ'),
  MmSegment(value: _Period.quarter, label: 'سہ ماہی'),
  MmSegment(value: _Period.year, label: 'سالانہ'),
];

const _methods = <MmSegment<String>>[
  MmSegment(value: 'cash', label: 'Cash', icon: MmIcons.cash),
  MmSegment(value: 'bank', label: 'Bank', icon: MmIcons.bank),
  MmSegment(value: 'card', label: 'Card', icon: MmIcons.card),
];

/// A control over [_periods] (or [segments]) with [selected] chosen.
Widget _control({
  _Period selected = _Period.month,
  ValueChanged<_Period>? onChanged,
  List<MmSegment<_Period>> segments = _periods,
  bool expand = false,
  String? semanticLabel,
}) => MmSegmentedControl<_Period>(
  segments: segments,
  selected: selected,
  onChanged: onChanged,
  expand: expand,
  semanticLabel: semanticLabel,
);

void _ignore(Object? _) {}

/// The segment button showing [label].
Finder _segment(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextButton));

/// The widget that paints the focus ring over the segments.
Finder _ring<T>() => find
    .ancestor(
      of: find.byType(SegmentedButton<T>),
      matching: find.byType(CustomPaint),
    )
    .first;

/// The direction the segments run in.
Axis _axis<T>(WidgetTester tester) => tester
    .widget<SegmentedButton<T>>(find.byType(SegmentedButton<T>))
    .direction;

/// Pumps [child] in Urdu at 200% text on a 320 dp wide phone.
Future<void> _pumpUrduLarge(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(320, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
      variant: MmVariant.largeText,
      locale: const Locale('ur'),
    ),
  );
  await tester.pumpAndSettle();
}

/// The ring [painter] draws on a control of [size], as a recording.
void Function(Canvas) _painting(CustomPainter painter, Size size) =>
    (canvas) => painter.paint(canvas, size);

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
    test('defaults: as wide as its labels, with no group label', () {
      const control = MmSegmentedControl<_Period>(
        segments: _periods,
        selected: _Period.month,
        onChanged: null,
      );
      expect(control.expand, isFalse);
      expect(control.semanticLabel, isNull);
    });

    testWidgets('shows every label; a check mark marks the selected one', (
      tester,
    ) async {
      await pumpThemed(tester, _control(onChanged: _ignore));
      for (final segment in _periods) {
        expect(find.text(segment.label), findsOneWidget);
      }
      expect(find.byType(SegmentedButton<_Period>), findsOneWidget);
      expect(find.byIcon(MmIcons.check), findsOneWidget);
      final check = tester.getCenter(find.byIcon(MmIcons.check));
      expect(tester.getRect(_segment('Monthly')).contains(check), isTrue);
      // The check leads the label: on its left in English.
      expect(check.dx, lessThan(tester.getRect(find.text('Monthly')).left));
    });

    testWidgets("the check mark replaces the selected segment's icon", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmSegmentedControl<String>(
          segments: _methods,
          selected: 'bank',
          onChanged: _ignore,
        ),
      );
      expect(find.byIcon(MmIcons.cash), findsOneWidget);
      expect(find.byIcon(MmIcons.bank), findsNothing);
      expect(find.byIcon(MmIcons.card), findsOneWidget);
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
      expect(focusedAt(tester, 'Quarterly'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(chosen, [_Period.quarter, _Period.year]);
    });

    testWidgets('arrow keys move between segments in both directions', (
      tester,
    ) async {
      for (final (variant, segments, next, back) in [
        (
          MmVariant.light,
          _periods,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowLeft,
        ),
        (
          MmVariant.urdu,
          _urduPeriods,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
        ),
      ]) {
        await pumpThemed(
          tester,
          _control(segments: segments, onChanged: _ignore),
          variant: variant,
        );
        final labels = [for (final segment in segments) segment.label];
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, labels[0]), isTrue, reason: variant.name);
        await tester.sendKeyEvent(next);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, labels[1]), isTrue, reason: variant.name);
        await tester.sendKeyEvent(next);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, labels[2]), isTrue, reason: variant.name);
        await tester.sendKeyEvent(back);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, labels[1]), isTrue, reason: variant.name);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('each segment is a button in a mutually exclusive group', (
      tester,
    ) async {
      await pumpThemed(tester, _control(onChanged: _ignore));
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

    testWidgets('a semantic label names the group, read before its options', (
      tester,
    ) async {
      for (final (variant, segments) in [
        (MmVariant.light, _periods),
        (MmVariant.urdu, _urduPeriods),
      ]) {
        await pumpThemed(
          tester,
          _control(
            segments: segments,
            semanticLabel: 'Report period',
            onChanged: _ignore,
          ),
          variant: variant,
        );
        final group = tester.getSemantics(
          find.byType(MmSegmentedControl<_Period>),
        );
        expect(group.label, 'Report period');
        // The options in reading order, the first one first in both
        // languages (on the right in Urdu).
        expect(labelsIn(group), [
          for (final segment in segments) segment.label,
        ], reason: variant.name);
      }

      // Without one, the control adds no node of its own.
      await pumpThemed(tester, _control(onChanged: _ignore));
      expect(
        find.descendant(
          of: find.byType(MmSegmentedControl<_Period>),
          matching: find.bySemanticsLabel('Report period'),
        ),
        findsNothing,
      );
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
      await pumpThemed(tester, _control(onChanged: _ignore), variant: variant);
      expect(
        materialOf(tester, _segment('Monthly')).color,
        colors.primaryContainer,
      );
      expect(textColorOf(tester, 'Monthly'), colors.onPrimaryContainer);
      expect(iconColorOf(tester, MmIcons.check), colors.onPrimaryContainer);
      expect(materialOf(tester, _segment('Yearly')).color, colors.surface);
      expect(textColorOf(tester, 'Yearly'), colors.ink);
    });

    testEveryVariant('disabled segments stay readable in muted ink', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpThemed(tester, _control(), variant: variant);
      expect(
        materialOf(tester, _segment('Monthly')).color,
        colors.surfaceSunken,
      );
      expect(textColorOf(tester, 'Monthly'), colors.inkMuted);
      expect(iconColorOf(tester, MmIcons.check), colors.inkMuted);
      expect(materialOf(tester, _segment('Yearly')).color, colors.surface);
      expect(textColorOf(tester, 'Yearly'), colors.inkMuted);
    });

    group('keyboard focus', () {
      testWidgets('keeps the resting outline: the theme ring would frame '
          'every segment', (tester) async {
        await pumpThemed(tester, _control(onChanged: _ignore));
        const colors = MmColorModes.light;
        final button = tester.widget<SegmentedButton<_Period>>(
          find.byType(SegmentedButton<_Period>),
        );
        final side = button.style!.side!;
        expect(side.resolve({}), BorderSide(color: colors.outline));
        expect(
          side.resolve({WidgetState.focused}),
          BorderSide(color: colors.outline),
        );
        expect(
          side.resolve({WidgetState.disabled, WidgetState.focused}),
          BorderSide(color: colors.rule),
        );
      });

      testEveryVariant('rings the focused segment, 3:1 against its fills', (
        tester,
        variant,
      ) async {
        useKeyboardHighlights();
        final colors = colorsOf(variant);
        final segments = variant == MmVariant.urdu ? _urduPeriods : _periods;
        await pumpThemed(
          tester,
          _control(segments: segments, onChanged: _ignore),
          variant: variant,
        );
        expect(
          tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter,
          isNull,
        );
        await focusOn(tester, find.text(segments[1].label));
        final painter = tester
            .widget<CustomPaint>(_ring<_Period>())
            .foregroundPainter!;
        final size = tester.getSize(_ring<_Period>());
        // At 200% text the segments stack; otherwise they share the width.
        final stacked = variant == MmVariant.largeText;
        expect(
          _axis<_Period>(tester),
          stacked ? Axis.vertical : Axis.horizontal,
        );
        final segment = tester
            .getRect(_segment(segments[1].label))
            .shift(-tester.getTopLeft(_ring<_Period>()));
        // The ring frames exactly the focused (middle) segment: square,
        // centred on the dividers on either side, and over the control's
        // outline (1 dp inside its edge) along the other two.
        final rect = stacked
            ? Rect.fromLTRB(1, segment.top, size.width - 1, segment.bottom)
            : Rect.fromLTRB(segment.left, 1, segment.right, size.height - 1);
        expect(
          _painting(painter, size),
          paints..rrect(
            rrect: RRect.fromRectAndCorners(rect),
            color: colors.focus,
            strokeWidth: MmSize.focusRing,
            style: PaintingStyle.stroke,
          ),
        );
        // Against the paper and tonal fills it frames, and the page.
        for (final fill in [
          colors.surface,
          colors.primaryContainer,
          colors.bg,
        ]) {
          expect(
            mmContrastRatio(colors.focus, fill),
            greaterThanOrEqualTo(mmMinimumIconContrast),
          );
        }
      });

      testWidgets('the end segments are rounded with the control', (
        tester,
      ) async {
        useKeyboardHighlights();
        const corner = Radius.circular(MmRadius.sm - MmSize.focusRing / 2);
        // In Urdu the first segment is on the right.
        for (final (variant, segments) in [
          (MmVariant.light, _periods),
          (MmVariant.urdu, _urduPeriods),
        ]) {
          await pumpThemed(
            tester,
            _control(segments: segments, onChanged: _ignore),
            variant: variant,
          );
          await focusOn(tester, find.text(segments[0].label));
          final size = tester.getSize(_ring<_Period>());
          final third = size.width / 3;
          final rrect = variant == MmVariant.urdu
              ? RRect.fromRectAndCorners(
                  Rect.fromLTRB(2 * third, 1, size.width - 1, size.height - 1),
                  topRight: corner,
                  bottomRight: corner,
                )
              : RRect.fromRectAndCorners(
                  Rect.fromLTRB(1, 1, third, size.height - 1),
                  topLeft: corner,
                  bottomLeft: corner,
                );
          expect(
            _painting(
              tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter!,
              size,
            ),
            paints..rrect(rrect: rrect),
            reason: variant.name,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('stacked, the first and last are rounded top and bottom', (
        tester,
      ) async {
        useKeyboardHighlights();
        const corner = Radius.circular(MmRadius.sm - MmSize.focusRing / 2);
        await pumpLargeNarrow(tester, _control(onChanged: _ignore));
        final size = tester.getSize(_ring<_Period>());
        final third = size.height / 3;
        void Function(Canvas) ring() => _painting(
          tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter!,
          size,
        );

        await focusOn(tester, find.text('Monthly'));
        expect(
          ring(),
          paints..rrect(
            rrect: RRect.fromRectAndCorners(
              Rect.fromLTRB(1, 1, size.width - 1, third),
              topLeft: corner,
              topRight: corner,
            ),
          ),
        );
        await focusOn(tester, find.text('Yearly'));
        expect(
          ring(),
          paints..rrect(
            rrect: RRect.fromRectAndCorners(
              Rect.fromLTRB(1, 2 * third, size.width - 1, size.height - 1),
              bottomLeft: corner,
              bottomRight: corner,
            ),
          ),
        );
      });

      testWidgets('follows focus, and leaves with it', (tester) async {
        useKeyboardHighlights();
        await pumpThemed(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _control(onChanged: _ignore),
              const MmButton(label: 'Record payment', onPressed: tapped),
            ],
          ),
        );
        CustomPainter? ring() =>
            tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final first = ring();
        expect(first, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final second = ring()!;
        expect(second.shouldRepaint(first!), isTrue);
        expect(second.shouldRepaint(second), isFalse);
        // On to the next control: no segment is ringed.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusedAt(tester, 'Record payment'), isTrue);
        expect(ring(), isNull);
      });

      testWidgets('is drawn only for the keyboard, never after a touch', (
        tester,
      ) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        await pumpThemed(tester, _control(onChanged: _ignore));
        await focusOn(tester, find.text('Quarterly'));
        expect(focusedAt(tester, 'Quarterly'), isTrue);
        CustomPainter? ring() =>
            tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter;
        expect(ring(), isNull);
        // Switching to the keyboard shows it at once.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pumpAndSettle();
        expect(ring(), isNotNull);
      });

      testWidgets('forgets a focused segment that is removed', (tester) async {
        useKeyboardHighlights();
        await pumpThemed(tester, _control(onChanged: _ignore));
        await focusOn(tester, find.text('Yearly'));
        await pumpThemed(
          tester,
          _control(segments: _periods.sublist(0, 2), onChanged: _ignore),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Yearly'), findsNothing);
        expect(
          tester.widget<CustomPaint>(_ring<_Period>()).foregroundPainter,
          isNull,
        );
      });
    });

    group('size', () {
      testWidgets('segments are 48 dp tall targets in English and Urdu', (
        tester,
      ) async {
        for (final (variant, segments) in [
          (MmVariant.light, _periods),
          (MmVariant.urdu, _urduPeriods),
        ]) {
          await pumpThemed(
            tester,
            _control(segments: segments, onChanged: _ignore),
            variant: variant,
          );
          for (final segment in segments) {
            expect(
              tester.getSize(_segment(segment.label)).height,
              48,
              reason: '${variant.name} ${segment.label}',
            );
          }
          expect(
            tester.getSize(find.byType(MmSegmentedControl<_Period>)).height,
            48,
          );
        }
      });

      testWidgets('segments with icons are 48 dp too, and grow with the text', (
        tester,
      ) async {
        const urdu = <MmSegment<String>>[
          MmSegment(value: 'cash', label: 'نقد', icon: MmIcons.cash),
          MmSegment(value: 'bank', label: 'بینک', icon: MmIcons.bank),
          MmSegment(value: 'card', label: 'کارڈ', icon: MmIcons.card),
        ];
        for (final (variant, segments, height) in [
          (MmVariant.light, _methods, 48.0),
          (MmVariant.urdu, urdu, 48.0),
          // Two 20 dp lines of text at 200% inside the same padding.
          (MmVariant.largeText, _methods, 68.0),
        ]) {
          await pumpThemed(
            tester,
            MmSegmentedControl<String>(
              segments: segments,
              selected: 'bank',
              onChanged: _ignore,
            ),
            variant: variant,
          );
          for (final segment in segments) {
            expect(
              tester.getSize(_segment(segment.label)).height,
              height,
              reason: '${variant.name} ${segment.label}',
            );
          }
          await expectAccessible(tester);
        }
      });

      testWidgets('icons and the check grow with the text, at most 150%', (
        tester,
      ) async {
        for (final (scale, size) in [(1.0, 20.0), (1.25, 25.0), (2.0, 30.0)]) {
          await pumpThemed(
            tester,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: const MmSegmentedControl<String>(
                  segments: _methods,
                  selected: 'bank',
                  onChanged: _ignore,
                ),
              ),
            ),
            size: const Size(800, 740),
          );
          expect(tester.getSize(find.byIcon(MmIcons.cash)).width, size);
          expect(tester.getSize(find.byIcon(MmIcons.check)).width, size);
        }
      });

      testWidgets('expand shares the parent width equally', (tester) async {
        await pumpThemed(tester, _control(expand: true, onChanged: _ignore));
        expect(
          tester.getSize(find.byType(MmSegmentedControl<_Period>)).width,
          328,
        );
        for (final segment in _periods) {
          expect(
            tester.getSize(_segment(segment.label)).width,
            closeTo(328 / 3, 0.01),
          );
        }
        // Without it, the control is as wide as its labels need.
        await pumpThemed(tester, _control(onChanged: _ignore));
        expect(
          tester.getSize(find.byType(SegmentedButton<_Period>)).width,
          lessThan(328),
        );
      });
    });

    group('narrow space', () {
      testWidgets('labels wrap inside their segments while words fit', (
        tester,
      ) async {
        const segments = [
          MmSegment(value: _Period.month, label: 'Rent due'),
          MmSegment(value: _Period.quarter, label: 'Paid in full'),
        ];
        await pumpLargeNarrow(
          tester,
          _control(segments: segments, onChanged: _ignore),
        );
        expect(tester.takeException(), isNull);
        expect(_axis<_Period>(tester), Axis.horizontal);
        expect(
          tester.getSize(find.byType(MmSegmentedControl<_Period>)).width,
          lessThanOrEqualTo(288),
        );
        final wrapped = paragraphOf(tester, 'Paid in full');
        expect(wrapped.size.height, greaterThan(40));
        // As wide as its longest line, beside nothing but its padding.
        expect(
          wrapped.size.width,
          lessThan(
            tester.getSize(_segment('Paid in full')).width -
                2 * MmSpace.s2 +
                0.01,
          ),
        );
      });

      testWidgets('stacks the segments when their words cannot sit side by '
          'side, the first on top', (tester) async {
        await pumpLargeNarrow(
          tester,
          _control(selected: _Period.year, onChanged: _ignore),
        );
        expect(tester.takeException(), isNull);
        expect(_axis<_Period>(tester), Axis.vertical);
        final rects = [
          for (final segment in _periods)
            tester.getRect(_segment(segment.label)),
        ];
        for (final (index, rect) in rects.indexed) {
          // Each as wide as the page's column, one under the other, every
          // label whole and in view.
          expect(rect.width, 288, reason: _periods[index].label);
          expect(rect.height, greaterThanOrEqualTo(48));
          if (index > 0) expect(rect.top, rects[index - 1].bottom);
          final label = paragraphOf(tester, _periods[index].label);
          expect(
            label.size.width,
            greaterThanOrEqualTo(label.getMinIntrinsicWidth(double.infinity)),
          );
          expect(
            rect.contains(
              tester.getRect(find.text(_periods[index].label)).center,
            ),
            isTrue,
          );
        }
        expect(
          tester.getSize(find.byType(MmSegmentedControl<_Period>)).width,
          288,
        );
      });

      testWidgets('stacked in Urdu, the first is on top, its label right to '
          'left', (tester) async {
        await _pumpUrduLarge(
          tester,
          _control(
            segments: _urduPeriods,
            semanticLabel: 'مدت',
            onChanged: _ignore,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(_axis<_Period>(tester), Axis.vertical);
        final tops = [
          for (final segment in _urduPeriods)
            tester.getRect(_segment(segment.label)).top,
        ];
        expect(tops, orderedEquals([...tops]..sort()));
        // The check leads the selected label: on its right in Urdu.
        expect(
          tester.getCenter(find.byIcon(MmIcons.check)).dx,
          greaterThan(tester.getRect(find.text('ماہانہ')).right),
        );
        expect(
          labelsIn(
            tester.getSemantics(find.byType(MmSegmentedControl<_Period>)),
          ),
          [for (final segment in _urduPeriods) segment.label],
        );
      });

      testWidgets('long labels wrap inside stacked segments', (tester) async {
        const segments = [
          MmSegment(value: _Period.month, label: 'Rent due this month'),
          MmSegment(
            value: _Period.quarter,
            label: 'Paid in full by bank transfer',
          ),
        ];
        await pumpLargeNarrow(
          tester,
          _control(segments: segments, onChanged: _ignore),
        );
        expect(tester.takeException(), isNull);
        expect(_axis<_Period>(tester), Axis.vertical);
        final label = paragraphOf(tester, 'Paid in full by bank transfer');
        expect(label.size.height, greaterThan(2 * 40 - 0.01));
        // Every segment is as tall as the tallest label needs.
        expect(
          tester.getSize(_segment('Rent due this month')).height,
          tester.getSize(_segment('Paid in full by bank transfer')).height,
        );
        expect(
          tester.getRect(_segment('Paid in full by bank transfer')),
          predicate<Rect>(
            (segment) =>
                segment.contains(
                  tester
                      .getRect(find.text('Paid in full by bank transfer'))
                      .topLeft,
                ) &&
                segment.contains(
                  tester
                      .getRect(find.text('Paid in full by bank transfer'))
                      .bottomRight,
                ),
          ),
        );
      });

      testWidgets('the side-by-side threshold is what Material lays out', (
        tester,
      ) async {
        // With an icon in every segment, Material's own narrowest row is
        // what the control allows for; one dp less and it stacks.
        for (final (name, scale, bold, segments) in [
          ('English', 1.0, false, _methods),
          ('200%', 2.0, false, _methods),
          ('bold text', 1.0, true, _methods),
          (
            'Urdu',
            1.0,
            false,
            const <MmSegment<String>>[
              MmSegment(value: 'cash', label: 'نقد رقم', icon: MmIcons.cash),
              MmSegment(value: 'bank', label: 'بینک', icon: MmIcons.bank),
              MmSegment(value: 'card', label: 'کارڈ', icon: MmIcons.card),
            ],
          ),
        ]) {
          final urdu = name == 'Urdu';
          Widget sized(double? width) => Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
              child: SizedBox(
                width: width,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmSegmentedControl<String>(
                    segments: segments,
                    selected: 'none',
                    onChanged: _ignore,
                  ),
                ),
              ),
            ),
          );
          final variant = urdu ? MmVariant.urdu : MmVariant.light;
          await pumpThemed(
            tester,
            sized(null),
            variant: variant,
            size: const Size(1000, 740),
          );
          final row = tester
              .renderObject<RenderBox>(find.byType(SegmentedButton<String>))
              .getMinIntrinsicWidth(double.infinity);
          await pumpThemed(
            tester,
            sized(row.ceilToDouble()),
            variant: variant,
            size: const Size(1000, 740),
          );
          expect(_axis<String>(tester), Axis.horizontal, reason: name);
          await pumpThemed(
            tester,
            sized(row.ceilToDouble() - 1),
            variant: variant,
            size: const Size(1000, 740),
          );
          expect(_axis<String>(tester), Axis.vertical, reason: name);
        }
      });

      testWidgets('choosing a segment never restacks the control', (
        tester,
      ) async {
        // 328 dp: a 360 dp phone's column, where the three sit side by side
        // whichever is selected.
        for (final width in [300.0, 310.0, 320.0, 328.0, 340.0]) {
          final axes = <Axis>{};
          for (final selected in _Period.values) {
            await pumpThemed(
              tester,
              SizedBox(
                width: width,
                child: _control(selected: selected, onChanged: _ignore),
              ),
              size: const Size(400, 740),
            );
            axes.add(_axis<_Period>(tester));
          }
          expect(axes, hasLength(1), reason: '$width');
          if (width >= 328) expect(axes.single, Axis.horizontal);
        }
      });

      testWidgets('re-fits when the window changes', (tester) async {
        await pumpThemed(
          tester,
          _control(selected: _Period.year, onChanged: _ignore),
          variant: MmVariant.largeText,
          size: const Size(800, 740),
        );
        expect(_axis<_Period>(tester), Axis.horizontal);
        tester.view.physicalSize = const Size(320, 740);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_axis<_Period>(tester), Axis.vertical);
        // Narrower still, the stacked labels narrow with it.
        tester.view.physicalSize = const Size(300, 740);
        await tester.pumpAndSettle();
        expect(tester.getSize(_segment('Quarterly')).width, 268);
        tester.view.physicalSize = const Size(800, 740);
        await tester.pumpAndSettle();
        expect(_axis<_Period>(tester), Axis.horizontal);
      });

      testWidgets('tabbing to a stacked segment below the fold scrolls to it', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 320)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          themedApp(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(MmSpace.s4),
                child: Column(
                  children: [
                    const SizedBox(height: 200),
                    _control(onChanged: _ignore),
                  ],
                ),
              ),
            ),
            variant: MmVariant.largeText,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(_segment('Yearly')).bottom, greaterThan(320));
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(focusedAt(tester, 'Yearly'), isTrue);
        expect(
          tester.getRect(_segment('Yearly')).bottom,
          lessThanOrEqualTo(320),
        );
      });

      testWidgets("a stacked label's layout and intrinsic sizes agree", (
        tester,
      ) async {
        await pumpLargeNarrow(tester, _control(onChanged: _ignore));
        final label = tester.renderObject<RenderBox>(
          find
              .ancestor(
                of: find.text('Quarterly'),
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_FixedWidth',
                ),
              )
              .first,
        );
        const width = 288 - 2 * MmSpace.s2;
        expect(label.size.width, width);
        // Asked about any width, it answers with its own.
        expect(label.getMinIntrinsicWidth(10), width);
        expect(label.getMaxIntrinsicWidth(10), width);
        expect(label.getMinIntrinsicHeight(double.infinity), label.size.height);
        expect(label.getMaxIntrinsicHeight(double.infinity), label.size.height);
        expect(label.getDryLayout(label.constraints), label.size);
      });
    });

    testWidgets('a selection that matches no segment selects none', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _control(
          segments: _periods.sublist(0, 2),
          selected: _Period.year,
          onChanged: _ignore,
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
      await pumpThemed(
        tester,
        _control(segments: [..._periods], selected: _Period.year),
      );
      expect(current(), same(before));
      // The check mark follows the selection all the same.
      final check = tester.getCenter(find.byIcon(MmIcons.check));
      expect(tester.getRect(_segment('Yearly')).contains(check), isTrue);

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

    testEveryVariant('fits a 320 dp surface in every variant', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmSegmentedControl<String>(
          segments: [
            MmSegment(value: 'cash', label: 'Cash', icon: MmIcons.cash),
            MmSegment(
              value: 'bank',
              label: 'Bank transfer',
              icon: MmIcons.bank,
            ),
            MmSegment(value: 'card', label: 'Card', icon: MmIcons.card),
          ],
          selected: 'bank',
          onChanged: _ignore,
        ),
        variant: variant,
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      await expectAccessible(tester);
    });

    testWidgets('fits 200% text on 320 dp in English and Urdu', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Column(
          children: [
            _control(onChanged: _ignore, semanticLabel: 'Report period'),
            _control(segments: _urduPeriods, onChanged: _ignore, expand: true),
          ],
        ),
      );
    });
  });
}
