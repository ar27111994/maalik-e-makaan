import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

/// A stepper whose value follows what it reports, as an app's would.
class _Controlled extends StatefulWidget {
  const new({required this.initial, required this.max, this.log});

  final int initial;
  final int max;
  final List<int>? log;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) => MmStepperField(
    label: 'Advance rent',
    value: _value,
    min: 0,
    max: widget.max,
    decreaseLabel: 'Fewer months',
    increaseLabel: 'More months',
    format: (months) => '$months months',
    onChanged: (value) {
      widget.log?.add(value);
      setState(() => _value = value);
    },
  );
}

Widget _stepper({
  int value = 3,
  int min = 0,
  int max = 12,
  int step = 1,
  List<int>? log,
  bool enabled = true,
  String? helper,
  String Function(int)? format,
}) => MmStepperField(
  label: 'Rooms',
  value: value,
  min: min,
  max: max,
  step: step,
  helper: helper,
  format: format,
  decreaseLabel: 'Fewer rooms',
  increaseLabel: 'More rooms',
  onChanged: enabled ? (value) => log?.add(value) : null,
);

Finder get _value => find.bySemanticsLabel('Rooms');

bool _enabled(WidgetTester tester, String tooltip) =>
    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  group('MmStepperField', () {
    testWidgets('shows the label, the value and the helper', (tester) async {
      await pumpThemed(
        tester,
        _stepper(value: 1234, max: 2000, helper: 'Per floor'),
      );
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.text('1,234'), findsOneWidget);
      expect(find.text('Per floor'), findsOneWidget);
      expect(find.byIcon(MmIcons.add), findsOneWidget);
      // Figures are tabular, in the Latin face.
      final style = tester.widget<Text>(find.text('1,234')).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(
        tester.getSize(find.byType(Material).at(1)).height,
        greaterThanOrEqualTo(MmSize.fieldHeight),
      );
    });

    testWidgets('the buttons step the value and stop at the limits', (
      tester,
    ) async {
      final log = <int>[];
      await pumpThemed(tester, _stepper(value: 9, max: 10, step: 2, log: log));
      await tester.tap(find.byTooltip('More rooms'));
      await tester.tap(find.byTooltip('Fewer rooms'));
      expect(log, [10, 7]);

      await pumpThemed(tester, _stepper(value: 10, max: 10, log: log));
      expect(_enabled(tester, 'More rooms'), isFalse);
      expect(_enabled(tester, 'Fewer rooms'), isTrue);
      await pumpThemed(tester, _stepper(value: 0, log: log));
      expect(_enabled(tester, 'Fewer rooms'), isFalse);
      expect(_enabled(tester, 'More rooms'), isTrue);
      await pumpThemed(tester, _stepper(value: 1, step: 5, log: log));
      await tester.tap(find.byTooltip('Fewer rooms'));
      expect(log, [10, 7, 0]);
    });

    testWidgets('the value is adjustable by assistive technology', (
      tester,
    ) async {
      final log = <int>[];
      await pumpThemed(tester, _stepper(log: log));
      expect(
        tester.getSemantics(_value),
        matchesSemantics(
          label: 'Rooms',
          value: '3',
          increasedValue: '4',
          decreasedValue: '2',
          hasEnabledState: true,
          isEnabled: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Rooms'));
      tester.semantics.decrease(find.semantics.byLabel('Rooms'));
      expect(log, [4, 2]);
      expect(
        tester.getSemantics(find.byTooltip('More rooms')),
        matchesSemantics(
          tooltip: 'More rooms',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      // At a limit, only the other direction is offered.
      await pumpThemed(tester, _stepper(value: 12));
      expect(
        tester.getSemantics(_value),
        matchesSemantics(
          label: 'Rooms',
          value: '12',
          decreasedValue: '11',
          hasEnabledState: true,
          isEnabled: true,
          hasDecreaseAction: true,
        ),
      );
    });

    testWidgets('on the web the name carries the value too', (tester) async {
      // Flutter's web engine leaves the value of an adjustable element out
      // of its name and does not set aria-valuetext until the value changes
      // (docs/uat.md, D7).
      expect(MmStepperField.nameCarriesValue, isFalse);
      MmStepperField.nameCarriesValue = true;
      addTearDown(() => MmStepperField.nameCarriesValue = false);
      await pumpThemed(tester, _stepper());
      expect(
        tester.getSemantics(find.bySemanticsLabel('Rooms, 3')),
        matchesSemantics(
          label: 'Rooms, 3',
          value: '3',
          increasedValue: '4',
          decreasedValue: '2',
          hasEnabledState: true,
          isEnabled: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
    });

    testWidgets('formats the value in words', (tester) async {
      await pumpThemed(tester, const _Controlled(initial: 3, max: 12));
      expect(find.text('3 months'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Advance rent')),
        matchesSemantics(
          label: 'Advance rent',
          value: '3 months',
          increasedValue: '4 months',
          decreasedValue: '2 months',
          hasEnabledState: true,
          isEnabled: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
    });

    testWidgets('Urdu words stay in Nastaliq; Urdu figures in Atkinson', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmStepperField(
          label: 'پیشگی کرایہ',
          value: 3,
          min: 0,
          max: 12,
          decreaseLabel: 'کم مہینے',
          increaseLabel: 'زیادہ مہینے',
          format: (months) => '$months مہینے',
          onChanged: (_) {},
        ),
        variant: MmVariant.urdu,
      );
      expect(
        tester.widget<Text>(find.text('3 مہینے')).style!.fontFamily,
        contains(MmFontFamily.urdu),
      );
      await pumpThemed(tester, _stepper(), variant: MmVariant.urdu);
      expect(
        tester.widget<Text>(find.text('3')).style!.fontFamily,
        contains(MmFontFamily.latin),
      );
    });

    testWidgets('Enter presses the focused button; at a limit focus moves '
        'to the other one', (tester) async {
      final log = <int>[];
      await pumpThemed(tester, _Controlled(initial: 10, max: 11, log: log));
      // Tab past the minus button to the plus button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'MmStepperField +',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, [11]);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'MmStepperField -',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, [11, 10]);
      // Away from a limit, focus stays put.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'MmStepperField -',
      );
    });

    testWidgets('a press without focus leaves focus alone', (tester) async {
      final log = <int>[];
      await pumpThemed(tester, _Controlled(initial: 11, max: 12, log: log));
      await tester.tap(find.byTooltip('More months'));
      await tester.pumpAndSettle();
      expect(log, [12]);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('MmStepperField -'),
      );
    });

    testWidgets('a null onChanged disables both buttons and the value', (
      tester,
    ) async {
      await pumpThemed(tester, _stepper(enabled: false));
      expect(_enabled(tester, 'More rooms'), isFalse);
      expect(_enabled(tester, 'Fewer rooms'), isFalse);
      expect(
        tester.getSemantics(_value),
        // Announced as disabled, with nothing to adjust.
        matchesSemantics(label: 'Rooms', value: '3', hasEnabledState: true),
      );
      expect(
        tester.widget<Text>(find.text('3')).style!.color,
        MmColorModes.light.inkMuted,
      );
    });

    testWidgets('the minus button shows the minus icon in its colour', (
      tester,
    ) async {
      await pumpThemed(tester, _stepper(value: 0));
      final minus = find.descendant(
        of: find.byTooltip('Fewer rooms'),
        matching: find.byIcon(MmIcons.minus),
      );
      expect(minus, findsOneWidget);
      final glyph = tester.renderObject<RenderParagraph>(
        find.descendant(of: minus, matching: find.byType(RichText)),
      );
      // Disabled at the lower limit: muted ink, still readable; the plus
      // beside it, which can still be pressed, is ink.
      expect(glyph.text.style!.color, MmColorModes.light.inkMuted);
      expect(iconColorOf(tester, MmIcons.add), MmColorModes.light.ink);
      expect(tester.getSize(minus), const Size.square(MmSize.iconLg));
    });

    testEveryVariant('a sign at its limit is muted ink, readable', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _stepper(value: 0), variant: variant);
      final colors = variant.colors;
      expect(iconColorOf(tester, MmIcons.minus), colors.inkMuted);
      expect(iconColorOf(tester, MmIcons.add), colors.ink);
      expect(
        mmContrastRatio(colors.inkMuted, colors.surface),
        greaterThanOrEqualTo(mmMinimumIconContrast),
      );
    });

    testWidgets('keyboard focus rings a button on its edge, inside the box', (
      tester,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, _stepper());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final plus = find.widgetWithIcon(IconButton, MmIcons.add);
      final material = tester.widget<Material>(
        find.descendant(of: plus, matching: find.byType(Material)),
      );
      expect(
        (material.shape! as StadiumBorder).side,
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      // The ring stays clear of the box's outline and clip.
      final box = tester.getRect(
        find.ancestor(of: plus, matching: find.byType(Material)).last,
      );
      final button = tester.getRect(plus);
      expect(box.right - button.right, greaterThanOrEqualTo(MmSpace.s1));
      expect(button.top - box.top, greaterThanOrEqualTo(MmSpace.s1));
    });

    testWidgets('a mouse over a button lights it, not at its limit', (
      tester,
    ) async {
      await pumpThemed(tester, _stepper(value: 0));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      for (final (icon, active) in [
        (MmIcons.add, true),
        (MmIcons.minus, false),
      ]) {
        final button = find.widgetWithIcon(IconButton, icon);
        await mouse.moveTo(tester.getCenter(button));
        await tester.pumpAndSettle();
        final states = tester
            .widget<ButtonStyleButton>(
              find.descendant(
                of: button,
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              ),
            )
            .statesController!
            .value;
        expect(states.contains(WidgetState.hovered), active, reason: '$icon');
      }
    });

    test('checks its limits', () {
      expect(() => _stepper(min: 5, max: 4, value: 5), throwsAssertionError);
      expect(() => _stepper(step: 0), throwsAssertionError);
      expect(() => _stepper(value: 13), throwsAssertionError);
      expect(() => _stepper(value: -1), throwsAssertionError);
    });

    testWidgets('right to left: minus at the right, plus at the left', (
      tester,
    ) async {
      await pumpThemed(tester, _stepper(), variant: MmVariant.urdu);
      expect(
        tester.getRect(find.byTooltip('Fewer rooms')).left,
        greaterThan(tester.getRect(find.byTooltip('More rooms')).right),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final tr = sayIn(context);
            return MmStepperField(
              label: tr(
                'Months of advance rent from Ali Raza',
                'علی رضا سے پیشگی کرایہ کے مہینے',
              ),
              value: 12,
              min: 0,
              max: 24,
              decreaseLabel: tr('Fewer months', 'کم مہینے'),
              increaseLabel: tr('More months', 'زیادہ مہینے'),
              format: (months) => tr('$months months', '$months مہینے'),
              helper: tr(
                'Rs 5,40,000 at Rs 45,000 a month',
                '45,000 روپے ماہانہ پر 5,40,000 روپے',
              ),
              onChanged: (_) {},
            );
          },
        ),
      );
    });
  });
}
