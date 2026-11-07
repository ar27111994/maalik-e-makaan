import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../../support/testing.dart';
import 'focus.dart';

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
  await tester.tap(find.text('Choose a date'));
  await tester.pumpAndSettle();
}

MmColorTokens _colors(MmVariant variant) =>
    MmTheme.tokensFor(variant.brightness, highContrast: variant.highContrast);

/// The open picker.
Finder get _picker => find.byType(DatePickerDialog);

/// The Material of the icon button showing [icon].
Material _buttonOf(WidgetTester tester, IconData icon) => tester.widget(
  find.descendant(
    of: find.widgetWithIcon(IconButton, icon),
    matching: find.byType(Material),
  ),
);

/// Opens the picker of a field in [locale] at 200% text on a 320 dp phone.
Future<void> _openLargeNarrow(WidgetTester tester, Locale locale) async {
  tester.view
    ..physicalSize = const Size(320, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(
      Scaffold(
        body: _field(
          label: locale.languageCode == 'ur' ? 'لیز کا آغاز' : 'Lease start',
          value: CalendarDate(2026, 9, 30),
        ),
      ),
      variant: MmVariant.largeText,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(_box);
  await tester.pumpAndSettle();
}

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
      expect(find.text('5 Nov 2026'), findsOneWidget);
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

    testWidgets('English dates put the day first, as Pakistan writes them', (
      tester,
    ) async {
      final log = <CalendarDate?>[];
      await pumpThemed(
        tester,
        _field(log: log, value: CalendarDate(2026, 11, 5)),
      );
      expect(find.text('5 Nov 2026'), findsOneWidget);
      await tester.tap(_box);
      await tester.pumpAndSettle();
      final dates = MaterialLocalizations.of(tester.element(_picker));
      expect(
        Localizations.localeOf(tester.element(_picker)).toString(),
        'en_IN',
      );
      // Weeks start on Sunday, as in the Urdu calendar.
      expect(dates.firstDayOfWeekIndex, 0);
      expect(find.text('Thu, 5 Nov'), findsOneWidget);
      // Typed dates are day first: 03/11/2026 is 3 November, not 11 March.
      await tester.tap(find.byIcon(MmIcons.edit));
      await tester.pumpAndSettle();
      expect(find.text('5/11/2026'), findsOneWidget);
      expect(find.text('dd/mm/yyyy'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '03/11/2026');
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      expect(log, [CalendarDate(2026, 11, 3)]);
    });

    testWidgets('the Urdu picker keeps Urdu, also day first', (tester) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5), label: 'لیز کا آغاز'),
        variant: MmVariant.urdu,
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(_picker)).languageCode,
        'ur',
      );
      expect(
        MaterialLocalizations.of(tester.element(_picker)).firstDayOfWeekIndex,
        0,
      );
      expect(find.text('منسوخ کریں'), findsOneWidget);
      expect(find.text('تاریخ منتخب کریں'), findsOneWidget);
    });

    testWidgets('Urdu dates set their figures in the Latin face', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5), label: 'لیز کا آغاز'),
        variant: MmVariant.urdu,
      );
      final date = tester.widget<Text>(find.textContaining('نومبر'));
      final runs = (date.textSpan! as TextSpan).children!.cast<TextSpan>();
      String? family(String text) =>
          runs.firstWhere((run) => run.text!.contains(text)).style?.fontFamily;
      expect(family('5'), contains(MmFontFamily.latin));
      expect(family('2026'), contains(MmFontFamily.latin));
      expect(family('نومبر'), contains(MmFontFamily.urdu));
    });

    testWidgets('the picker speaks the system: words, icons, corners', (
      tester,
    ) async {
      await pumpThemed(tester, _field(value: CalendarDate(2026, 11, 5)));
      await tester.tap(_box);
      await tester.pumpAndSettle();
      // A verb confirms, not "OK"; the entry modes switch with MmIcons.
      expect(find.text('OK'), findsNothing);
      expect(find.text('Choose a date'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Lease start'), findsWidgets);
      expect(find.byIcon(MmIcons.edit), findsOneWidget);
      await tester.tap(find.byIcon(MmIcons.edit));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _picker, matching: find.byIcon(MmIcons.calendar)),
        findsOneWidget,
      );
      final shape =
          DatePickerTheme.of(tester.element(_picker)).shape!
              as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(MmRadius.lg)),
      );
    });

    testEveryVariant('the picker has an edge where the page is dark', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        _field(value: CalendarDate(2026, 11, 5)),
        variant: variant,
      );
      await tester.tap(_box);
      await tester.pumpAndSettle();
      final side =
          (DatePickerTheme.of(tester.element(_picker)).shape!
                  as RoundedRectangleBorder)
              .side;
      final framed =
          variant.brightness == Brightness.dark || variant.highContrast;
      expect(
        side,
        framed ? BorderSide(color: variant.colors.outline) : BorderSide.none,
      );
      // Days that cannot be chosen are muted ink, chosen ones on cobalt.
      final theme = DatePickerTheme.of(tester.element(_picker));
      expect(
        theme.dayForegroundColor!.resolve({WidgetState.disabled}),
        variant.colors.inkMuted,
      );
      expect(
        theme.dayBackgroundColor!.resolve({WidgetState.selected}),
        variant.colors.primary,
      );
    });

    for (final locale in const [Locale('en'), Locale('ur')]) {
      testWidgets('at 200% text on a 320 dp phone the picker fits '
          '(${locale.languageCode})', (tester) async {
        await _openLargeNarrow(tester, locale);
        final scaler = MediaQuery.textScalerOf(
          tester.element(find.byType(CalendarDatePicker)),
        );
        expect(scaler.scale(10), 10 * MmDateField.pickerTextScale);
        expectTextWhole(tester, _picker);
        // The typing mode fits too.
        await tester.tap(find.byIcon(MmIcons.edit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectTextWhole(tester, _picker);
      });
    }

    testWidgets('below the limit the picker keeps the text size', (
      tester,
    ) async {
      await pumpThemed(tester, _field(value: CalendarDate(2026, 11, 5)));
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(CalendarDatePicker)))
            .scale(10),
        10,
      );
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
          value: 'Thursday, 5 November 2026',
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
      final focus = Focus.of(tester.element(find.text('5 Nov 2026')));
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
      // The field itself is marked invalid while it has an error.
      expect(
        tester.getSemantics(_box),
        isSemantics(
          label: 'Lease start',
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      await pumpThemed(tester, _field(helper: 'The day Ali Raza moves in'));
      expect(
        tester.getSemantics(_box),
        isSemantics(
          label: 'Lease start',
          validationResult: SemanticsValidationResult.none,
        ),
      );
    });

    testWidgets('keyboard focus rings a button inside the box, uncut', (
      tester,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(
        tester,
        _Controlled(initial: CalendarDate(2027, 10, 31)),
      );
      expect(_buttonOf(tester, MmIcons.close).shape, isA<StadiumBorder>());
      expect(
        (_buttonOf(tester, MmIcons.close).shape! as StadiumBorder).side,
        BorderSide.none,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // The ring is on the button's own edge, inside the box's outline.
      final ring =
          (_buttonOf(tester, MmIcons.close).shape! as StadiumBorder).side;
      expect(
        ring,
        BorderSide(color: MmColorModes.light.focus, width: MmSize.focusRing),
      );
      final button = tester.getRect(
        find.widgetWithIcon(IconButton, MmIcons.close),
      );
      final box = tester.getRect(find.byType(MmChoiceBox));
      expect(button.top - box.top, greaterThanOrEqualTo(MmSpace.s1));
      expect(box.bottom - button.bottom, greaterThanOrEqualTo(MmSpace.s1));
      // No tint on the field's tappable part: the ring shows focus.
      expect(tester.widget<InkWell>(_box).focusColor, Colors.transparent);
    });

    testEveryVariant('its icons are muted ink, readable when disabled', (
      tester,
      variant,
    ) async {
      final colors = variant.colors;
      for (final enabled in [true, false]) {
        await pumpThemed(
          tester,
          _field(
            value: CalendarDate(2026, 11, 5),
            optional: true,
            enabled: enabled,
          ),
          variant: variant,
        );
        expect(iconColorOf(tester, MmIcons.calendar), colors.inkMuted);
        expect(
          mmContrastRatio(colors.inkMuted, colors.surface),
          greaterThanOrEqualTo(mmMinimumIconContrast),
        );
      }
    });

    testWidgets('its icons grow with the text, up to half again', (
      tester,
    ) async {
      await pumpLargeNarrow(
        tester,
        _field(value: CalendarDate(2026, 11, 5), optional: true),
      );
      for (final icon in [MmIcons.calendar, MmIcons.close]) {
        expect(
          tester.getSize(find.byIcon(icon)),
          const Size.square(MmSize.iconLg * MmIconLabel.maxIconScale),
        );
      }
    });

    testWidgets('a mouse over the field lights it, not when disabled', (
      tester,
    ) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      for (final enabled in [true, false]) {
        await pumpThemed(tester, _field(enabled: enabled));
        final hover = Theme.of(tester.element(_box)).hoverColor;
        final ink = Material.of(tester.element(_box));
        await mouse.moveTo(tester.getCenter(_box));
        await tester.pumpAndSettle();
        expect(
          ink,
          enabled
              ? (paints..rect(color: hover))
              : isNot(paints..rect(color: hover)),
          reason: 'enabled: $enabled',
        );
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
      }
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
      expect(find.text('31 Oct 2027'), findsNothing);
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
          value: 'Wednesday, 28 October 2026',
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
