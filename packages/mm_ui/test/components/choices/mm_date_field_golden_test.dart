@Tags(['golden'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

void _changed(CalendarDate? _) {}

final _first = CalendarDate(2020, 1, 1);
final _last = CalendarDate(2030, 12, 31);

void main() {
  tearDown(resetFocusHighlights);
  goldenEveryVariant(
    'mm_date_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmDateField(
            label: tr('Lease start', 'لیز کا آغاز'),
            value: CalendarDate(2026, 11, 5),
            firstDate: _first,
            lastDate: _last,
            required: true,
            helper: tr('The day Ali Raza moves in', 'جس دن علی رضا آئیں گے'),
            onChanged: _changed,
          ),
          // Keyboard focus on the clear button: its ring sits inside the box.
          KeyboardFocused(
            index: 1,
            child: MmDateField(
              label: tr('Lease end', 'لیز کا اختتام'),
              value: CalendarDate(2027, 10, 31),
              firstDate: _first,
              lastDate: _last,
              optional: true,
              onChanged: _changed,
            ),
          ),
          MmDateField(
            label: tr('Rent due date', 'کرایہ کی آخری تاریخ'),
            firstDate: _first,
            lastDate: _last,
            required: true,
            errorText: tr(
              'Choose the date rent is due',
              'کرایہ کی تاریخ منتخب کریں',
            ),
            onChanged: _changed,
          ),
          MmDateField(
            label: tr('Agreement signed', 'معاہدے پر دستخط'),
            value: CalendarDate(2026, 10, 28),
            firstDate: _first,
            lastDate: _last,
            enabled: false,
            onChanged: _changed,
          ),
        ],
      ),
    ),
    // Four fields with labels, helpers and errors at 200% text.
    size: const Size(360, 880),
  );

  // A mouse over the calendar button: the whole box takes the hover tint,
  // with no seam at the button, as a text field does.
  testEveryVariant('mm_date_field_hover golden', (tester, variant) async {
    await pumpThemed(
      tester,
      GoldenPage(
        (context, tr) => MmDateField(
          label: tr('Lease start', 'لیز کا آغاز'),
          value: CalendarDate(2026, 7, 1),
          firstDate: _first,
          lastDate: _last,
          onChanged: _changed,
        ),
      ),
      variant: variant,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(
        find.widgetWithIcon(IconButton, MmIcons.calendar),
      ),
    );
    await tester.pumpAndSettle();
    await expectGolden('mm_date_field_hover', variant);
  }, variants: const [MmVariant.light, MmVariant.dark, MmVariant.urdu]);
}
