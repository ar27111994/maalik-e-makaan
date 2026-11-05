@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void _changed(CalendarDate? _) {}

final _first = CalendarDate(2020, 1, 1);
final _last = CalendarDate(2030, 12, 31);

void main() {
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
          MmDateField(
            label: tr('Lease end', 'لیز کا اختتام'),
            value: CalendarDate(2027, 10, 31),
            firstDate: _first,
            lastDate: _last,
            optional: true,
            onChanged: _changed,
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
}
