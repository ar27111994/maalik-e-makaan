@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/choices/mm_choice_box.dart';

import '../../support/testing.dart';

void _changed(String _) {}

/// Three properties: two with icons, one without.
List<MmOption<String>> _properties(Say tr) => [
  MmOption(
    value: 'gulberg',
    label: tr('Gulberg Heights', 'گلبرگ ہائٹس'),
    icon: MmIcons.property,
  ),
  MmOption(
    value: 'dha',
    label: tr('DHA Phase 5 house', 'ڈی ایچ اے فیز 5 کا مکان'),
    description: tr('Lahore Cantt', 'لاہور کینٹ'),
    icon: MmIcons.home,
  ),
  MmOption(value: 'johar', label: tr('Johar Town flats', 'جوہر ٹاؤن فلیٹس')),
];

/// Twelve units, so the sheet has a search field.
List<MmOption<String>> _units(Say tr) => [
  for (var i = 1; i <= 12; i++)
    MmOption(value: 'a$i', label: tr('Flat A-$i', 'فلیٹ اے-$i')),
];

/// A golden of the sheet a select field over [options] opens, as a whole
/// screen in every variant (200% text on a 320 dp phone), after typing
/// [query] into its search field.
void _sheetGolden(
  String name,
  List<MmOption<String>> Function(Say tr) options, {
  required String label,
  required String urduLabel,
  String? value,
  (String, String)? query,
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Builder(
            builder: (context) {
              final tr = sayIn(context);
              return MmSelectField<String>(
                label: tr(label, urduLabel),
                options: options(tr),
                value: value,
                onChanged: _changed,
              );
            },
          ),
        ),
      ),
      size: variant == MmVariant.largeText
          ? const Size(320, 740)
          : const Size(360, 740),
      variant: variant,
    );
    await tester.tap(
      find
          .descendant(
            of: find.byType(MmChoiceBox),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    if (query != null) {
      final (english, urdu) = query;
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        variant == MmVariant.urdu ? urdu : english,
      );
      await tester.pumpAndSettle();
    }
    await expectAccessible(tester);
    await expectScreenGolden(name, variant);
  });
}

void main() {
  _sheetGolden(
    'mm_select_sheet',
    _properties,
    label: 'Property',
    urduLabel: 'جائیداد',
    value: 'dha',
  );
  _sheetGolden(
    'mm_select_sheet_search',
    _units,
    label: 'Unit',
    urduLabel: 'یونٹ',
    value: 'a3',
  );
  _sheetGolden(
    'mm_select_sheet_no_matches',
    _units,
    label: 'Unit',
    urduLabel: 'یونٹ',
    query: ('Flat B', 'فلیٹ بی'),
  );
}
