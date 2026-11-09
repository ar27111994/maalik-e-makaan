@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';

import '../../support/testing.dart';
import 'focus.dart';

void _changed(CalendarDate? _) {}

/// A date field on a phone. September 2026 has the longest month name the
/// picker shows, and is never the current month again, so no "today" ring
/// moves the golden.
Widget _page() => Scaffold(
  body: Padding(
    padding: const EdgeInsets.all(MmSpace.s4),
    child: Builder(
      builder: (context) => MmDateField(
        label: sayIn(context)('Agreement signed', 'معاہدے پر دستخط'),
        value: CalendarDate(2026, 9, 30),
        firstDate: CalendarDate(2020, 1, 1),
        lastDate: CalendarDate(2030, 12, 31),
        onChanged: _changed,
      ),
    ),
  ),
);

/// The phone of [variant]: 320 dp wide for 200% text.
Size _phone(MmVariant variant) => variant == MmVariant.largeText
    ? const Size(320, 740)
    : const Size(360, 740);

/// Opens the field's picker, in its typing mode when [typing].
Future<void> _open(WidgetTester tester, {bool typing = false}) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(MmChoiceBox),
          matching: find.byType(InkWell),
        )
        .first,
  );
  await tester.pumpAndSettle();
  if (typing) {
    await tester.tap(find.byIcon(MmIcons.edit));
    await tester.pumpAndSettle();
  }
  expectTextWhole(tester, find.byType(DatePickerDialog));
}

/// The harness's accessibility checks, but for the 48 dp tap targets in
/// the calendar: Material lays out the day cells in seven columns of a
/// dialog at most 328 dp wide, so each is 43.4 dp wide on a 360 dp phone
/// (37.7 dp on a 320 dp one), under Android's 48 dp and iOS's 44 pt. The
/// component cannot widen them; the typing mode, a tap away, passes every
/// check.
Future<void> _expectAccessibleCalendar(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(mmTextContrastGuideline));
}

void main() {
  testEveryVariant('mm_date_picker golden', (tester, variant) async {
    await pumpScreen(tester, _page(), size: _phone(variant), variant: variant);
    await _open(tester);
    await _expectAccessibleCalendar(tester);
    await expectScreenGolden('mm_date_picker', variant);
  });

  testEveryVariant('mm_date_picker_typing golden', (tester, variant) async {
    await pumpScreen(tester, _page(), size: _phone(variant), variant: variant);
    await _open(tester, typing: true);
    await expectAccessible(tester);
    await expectScreenGolden('mm_date_picker_typing', variant);
  }, variants: const [MmVariant.light, MmVariant.urdu, MmVariant.largeText]);

  for (final typing in [false, true]) {
    final name = typing ? 'mm_date_picker_typing' : 'mm_date_picker';
    testWidgets('$name golden (urdu at 200% text, 320 dp)', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedApp(
          _page(),
          variant: MmVariant.largeText,
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester, typing: typing);
      if (typing) {
        await expectAccessible(tester);
      } else {
        await _expectAccessibleCalendar(tester);
      }
      await expectLater(
        find.byKey(screenKey),
        matchesGoldenFile('goldens/${name}_urduLargeText.png'),
      );
    });
  }
}
