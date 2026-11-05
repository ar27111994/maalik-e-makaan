import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';

import '../../support/testing.dart';

final _first = CalendarDate(2020, 1, 1);
final _last = CalendarDate(2030, 12, 31);

/// A date field that records every date it reports in [log].
Widget _field({
  List<CalendarDate?>? log,
  CalendarDate? value,
  CalendarDate? firstDate,
  CalendarDate? lastDate,
  String label = 'Lease start',
  String? helper,
  String? errorText,
  bool required = false,
  bool optional = false,
  bool enabled = true,
}) => MmDateField(
  label: label,
  value: value,
  firstDate: firstDate ?? _first,
  lastDate: lastDate ?? _last,
  helper: helper,
  errorText: errorText,
  required: required,
  optional: optional,
  enabled: enabled,
  onChanged: (date) => log?.add(date),
);

/// A date field whose value follows what it reports, as an app's would.
class _Controlled extends StatefulWidget {
  const new({this.initial, this.log});

  final CalendarDate? initial;
  final List<CalendarDate?>? log;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  late CalendarDate? _value = widget.initial;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MmDateField(
        label: 'Lease end',
        value: _value,
        firstDate: _first,
        lastDate: _last,
        optional: true,
        onChanged: (date) {
          widget.log?.add(date);
          setState(() => _value = date);
        },
      ),
      const TextField(),
    ],
  );
}

/// The tappable part of the field (before the box's buttons).
Finder get _box => find
    .descendant(of: find.byType(MmChoiceBox), matching: find.byType(InkWell))
    .first;

/// The outline of the field's box.
BorderSide _outline(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(MmChoiceBox),
          matching: find.byType(Material),
        )
        .first,
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

Future<void> _pickDay(WidgetTester tester, String day) async {
  await tester.tap(find.text(day));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

MmColorTokens _colors(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

void main() {
  group('MmDateField date conversion', () {
    test('a date becomes local midnight of the same day', () {
      for (final date in [
        CalendarDate(2025, 12, 31),
        CalendarDate(2026, 1, 1),
        CalendarDate(2026, 1, 31),
        CalendarDate(2026, 2, 1),
        CalendarDate(2026, 2, 28),
        CalendarDate(2026, 3, 1),
        CalendarDate(2028, 2, 29),
        CalendarDate(2026, 6, 30),
        CalendarDate(2026, 7, 1),
      ]) {
        final dateTime = MmDateField.toDateTime(date);
        expect(dateTime.isUtc, isFalse, reason: '$date');
        expect(
          [dateTime.year, dateTime.month, dateTime.day],
          [date.year, date.month, date.day],
          reason: '$date',
        );
        expect(
          [dateTime.hour, dateTime.minute, dateTime.second],
          [0, 0, 0],
          reason: '$date',
        );
        expect(MmDateField.toCalendarDate(dateTime), date, reason: '$date');
      }
    });

    test('every day of a leap year round-trips without drifting', () {
      var date = CalendarDate(2027, 12, 31);
      final end = CalendarDate(2029, 1, 1);
      while (date.isOnOrBefore(end)) {
        final dateTime = MmDateField.toDateTime(date);
        expect(MmDateField.toCalendarDate(dateTime), date);
        // The next local midnight is the next calendar date.
        final next = MmDateField.toCalendarDate(
          DateTime(dateTime.year, dateTime.month, dateTime.day + 1),
        );
        expect(next, date.addDays(1));
        date = date.addDays(1);
      }
    });

    test('a UTC midnight is read by its own fields, never shifted', () {
      for (final date in [
        CalendarDate(2025, 12, 31),
        CalendarDate(2026, 1, 1),
        CalendarDate(2026, 2, 28),
        CalendarDate(2028, 2, 29),
      ]) {
        expect(MmDateField.toCalendarDate(date.toDateTimeUtc()), date);
      }
      // The last moment of a day is still that day.
      expect(
        MmDateField.toCalendarDate(DateTime(2025, 12, 31, 23, 59, 59)),
        CalendarDate(2025, 12, 31),
      );
    });
  });

  group('MmDateField', () {
    testWidgets('shows the label, the marker and the date with its year', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5), required: true),
      );
      expect(find.text('Lease start  Required', findRichText: true), findsOne);
      expect(find.text('Nov 5, 2026'), findsOneWidget);
      expect(find.byIcon(MmIcons.calendar), findsOneWidget);
      expect(find.byIcon(MmIcons.close), findsNothing);
      expect(
        tester.getSize(_box).height,
        greaterThanOrEqualTo(MmSize.fieldHeight),
      );
    });

    testWidgets('Urdu shows Urdu month names', (tester) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5), label: 'لیز کا آغاز'),
        variant: MmVariant.urdu,
      );
      expect(find.textContaining('نومبر'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('is one button named by its label, with the full date', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5), required: true),
      );
      expect(
        tester.getSemantics(_box),
        matchesSemantics(
          label: 'Lease start',
          value: 'Thursday, November 5, 2026',
          hint: 'Required',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasRequiredState: true,
          isRequired: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byIcon(MmIcons.calendar)),
        matchesSemantics(
          tooltip: 'Choose a date',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('an empty optional field has no value and says Optional', (
      tester,
    ) async {
      await pumpThemed(tester, _field(optional: true));
      expect(
        tester.getSemantics(_box),
        matchesSemantics(
          label: 'Lease start',
          hint: 'Optional',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasRequiredState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('tapping opens the picker on the date, within the range', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(
          value: CalendarDate(2026, 11, 5),
          firstDate: CalendarDate(2026, 1, 1),
          lastDate: CalendarDate(2027, 6, 30),
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.initialDate, DateTime(2026, 11, 5));
      expect(dialog.firstDate, DateTime(2026));
      expect(dialog.lastDate, DateTime(2027, 6, 30));
      expect(dialog.helpText, 'Lease start');
      expect(
        dialog.currentDate,
        MmDateField.toDateTime(CalendarDate.todayInPakistan()),
      );
    });

    testWidgets('picking a day reports it; the same day or Cancel do not', (
      tester,
    ) async {
      final log = <CalendarDate?>[];
      await pumpThemed(
        tester,
        _field(log: log, value: CalendarDate(2026, 11, 5)),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await _pickDay(tester, '18');
      expect(log, [CalendarDate(2026, 11, 18)]);

      await tester.tap(_box);
      await tester.pumpAndSettle();
      await _pickDay(tester, '5');
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(log, [CalendarDate(2026, 11, 18)]);
    });

    testWidgets('picks across a year boundary', (tester) async {
      final log = <CalendarDate?>[];
      await pumpThemed(
        tester,
        _field(
          log: log,
          value: CalendarDate(2025, 12, 31),
          firstDate: CalendarDate(2025, 12, 1),
          lastDate: CalendarDate(2026, 1, 31),
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await _pickDay(tester, '1');
      expect(log, [CalendarDate(2026, 1, 1)]);
    });

    testWidgets('picks the last day of a leap February', (tester) async {
      final log = <CalendarDate?>[];
      await pumpThemed(
        tester,
        _field(
          log: log,
          value: CalendarDate(2028, 3, 1),
          firstDate: CalendarDate(2028, 2, 1),
          lastDate: CalendarDate(2028, 3, 31),
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await _pickDay(tester, '29');
      expect(log, [CalendarDate(2028, 2, 29)]);
    });

    testWidgets('opens on the nearest allowed date when there is none', (
      tester,
    ) async {
      // A range wholly before today: the picker opens on its last day.
      await pumpThemed(
        tester,
        _field(
          firstDate: CalendarDate(2001, 1, 1),
          lastDate: CalendarDate(2001, 3, 31),
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2001, 3, 31),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // A date before the range: the picker opens on its first day.
      await pumpThemed(
        tester,
        _field(
          value: CalendarDate(2019, 5, 5),
          firstDate: CalendarDate(2026, 1, 1),
        ),
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2026),
      );
    });

    testWidgets('the calendar button opens the picker too', (tester) async {
      await pumpThemed(tester, _field(value: CalendarDate(2026, 11, 5)));
      await tester.tap(find.byTooltip('Choose a date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('Enter and Space open the picker; focus comes back', (
      tester,
    ) async {
      await pumpThemed(tester, _field(value: CalendarDate(2026, 11, 5)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focus = Focus.of(tester.element(find.text('Nov 5, 2026')));
      expect(focus.hasPrimaryFocus, isTrue);
      // The focused field draws the focus ring.
      expect(_outline(tester).width, MmSize.focusRing);
      expect(_outline(tester).color, MmColorModes.light.focus);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('Tab skips the calendar button, which repeats the field', (
      tester,
    ) async {
      await pumpThemed(tester, const _Controlled());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('a tap leaves no focus ring; an error outlines in overdue', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(errorText: 'Choose the date rent is due', required: true),
      );
      expect(_outline(tester).color, MmColorModes.light.overdue);
      expect(_outline(tester).width, MmSize.hairline);
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // Focus is back in the field, but the last input was touch.
      expect(_outline(tester).width, MmSize.hairline);
      // A key press shows the ring, in overdue while there is an error.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_outline(tester).width, MmSize.focusRing);
      expect(_outline(tester).color, MmColorModes.light.overdue);
    });

    testWidgets('an error replaces the helper, with an icon, live', (
      tester,
    ) async {
      await pumpThemed(tester, _field(helper: 'The day Ali Raza moves in'));
      expect(find.text('The day Ali Raza moves in'), findsOneWidget);
      expect(find.byIcon(MmIcons.error), findsNothing);

      await pumpThemed(
        tester,
        _field(
          helper: 'The day Ali Raza moves in',
          errorText: 'Choose the date rent is due',
        ),
      );
      expect(find.text('The day Ali Raza moves in'), findsNothing);
      expect(find.byIcon(MmIcons.error), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Choose the date rent is due'),
        ),
        isSemantics(label: 'Choose the date rent is due', isLiveRegion: true),
      );
    });

    testWidgets('an optional field clears; focus stays in the field', (
      tester,
    ) async {
      final log = <CalendarDate?>[];
      await pumpThemed(
        tester,
        _Controlled(initial: CalendarDate(2027, 10, 31), log: log),
      );
      expect(
        tester.getSemantics(find.byIcon(MmIcons.close)),
        matchesSemantics(
          tooltip: 'Clear',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      // Keyboard: the field, then the clear button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, [null]);
      expect(find.byIcon(MmIcons.close), findsNothing);
      expect(find.text('Oct 31, 2027'), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MmDateField');
      expect(_outline(tester).width, MmSize.focusRing);
    });

    testWidgets('only an optional, enabled field with a date can be cleared', (
      tester,
    ) async {
      for (final field in [
        _field(value: CalendarDate(2026, 11, 5), required: true),
        _field(value: CalendarDate(2026, 11, 5)),
        _field(optional: true),
        _field(
          value: CalendarDate(2026, 11, 5),
          optional: true,
          enabled: false,
        ),
      ]) {
        await pumpThemed(tester, field);
        expect(find.byIcon(MmIcons.close), findsNothing);
      }
    });

    testWidgets('a disabled field is muted, announced and does nothing', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 10, 28), enabled: false),
      );
      await tester.tap(_box);
      await tester.tap(find.byIcon(MmIcons.calendar));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(_outline(tester).color, MmColorModes.light.rule);
      final label = tester.widget<RichText>(
        find.text('Lease start', findRichText: true),
      );
      expect(label.text.style!.color, MmColorModes.light.inkMuted);
      expect(
        tester.getSemantics(_box),
        matchesSemantics(
          label: 'Lease start',
          value: 'Wednesday, October 28, 2026',
          isButton: true,
          hasEnabledState: true,
        ),
      );
    });

    test('is either required or optional', () {
      expect(
        () => MmDateField(
          label: 'Lease start',
          firstDate: _first,
          lastDate: _last,
          required: true,
          optional: true,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('a range that ends before it starts is a programming error', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(_field(firstDate: CalendarDate(2027, 1, 1), lastDate: _first)),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testEveryVariant('the outline follows the theme', (tester, variant) async {
      await pumpThemed(tester, _field(), variant: variant);
      expect(_outline(tester).color, _colors(variant).outline);
    });

    testWidgets('right to left: the buttons sit at the left end', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(
          label: 'لیز کا اختتام',
          value: CalendarDate(2027, 10, 31),
          optional: true,
        ),
        variant: MmVariant.urdu,
      );
      final text = tester.getRect(find.textContaining('2027'));
      final calendar = tester.getRect(find.byIcon(MmIcons.calendar));
      final clear = tester.getRect(find.byIcon(MmIcons.close));
      expect(calendar.right, lessThan(clear.left));
      expect(clear.right, lessThan(text.left));
      expect(
        tester
            .getTopRight(
              find.textContaining('لیز کا اختتام', findRichText: true),
            )
            .dx,
        closeTo(tester.getTopRight(_box).dx, 1),
      );
    });

    testWidgets('fits 200% text on a 320 dp phone', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final tr = sayIn(context);
            return Column(
              children: [
                _field(
                  label: tr('Agreement signed on', 'معاہدے پر دستخط کی تاریخ'),
                  value: CalendarDate(2026, 9, 30),
                  optional: true,
                  helper: tr(
                    'The day Ayesha Khan signed the lease',
                    'جس دن عائشہ خان نے دستخط کیے',
                  ),
                ),
                _field(
                  label: tr('Rent due date', 'کرایہ کی آخری تاریخ'),
                  required: true,
                  errorText: tr(
                    'Choose the date rent is due',
                    'کرایہ کی تاریخ منتخب کریں',
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  });
}
