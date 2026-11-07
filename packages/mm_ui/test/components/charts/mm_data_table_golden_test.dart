@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A rent roll that fits its card (a name typed in Urdu among Latin ones,
/// the first column taking the width to spare, rents lined up at the end
/// edge with the currency in their header) and a contact list too wide for
/// it, which scrolls sideways with a scrollbar and has keyboard focus.
Widget dataTableGolden() => GoldenPage(
  (context, say) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MmSpace.s3,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(MmSpace.s4),
          child: MmDataTable(
            caption: say('Rent roll, November', 'کرایوں کی فہرست، نومبر'),
            columns: [
              MmDataColumn(label: say('Tenant', 'کرایہ دار')),
              MmDataColumn(label: say('Unit', 'یونٹ')),
              MmDataColumn(
                label: say('Rent (Rs)', 'کرایہ (روپے)'),
                numeric: true,
              ),
            ],
            rows: [
              ['Ali Raza', say('Flat 2B', 'فلیٹ 2B'), '45,000'],
              ['Ayesha Khan', say('Shop 4', 'دکان 4'), '1,25,000'],
              ['فاطمہ نور', say('Flat 1A', 'فلیٹ 1A'), '52,000'],
            ],
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(MmSpace.s4),
          child: MmDataTable(
            caption: say('Tenant contacts', 'کرایہ داروں کے رابطے'),
            columns: [
              MmDataColumn(label: say('Tenant', 'کرایہ دار')),
              MmDataColumn(label: say('Phone', 'فون')),
              MmDataColumn(label: say('CNIC', 'شناختی کارڈ')),
              MmDataColumn(label: say('Since', 'کب سے'), numeric: true),
            ],
            rows: const [
              ['Ali Raza', '0300 1234567', '35202-1234567-1', '2021'],
              ['Ayesha Khan', '0321 7654321', '35201-7654321-2', '2023'],
            ],
          ),
        ),
      ),
    ],
  ),
);

void main() {
  testEveryVariant('mm_data_table golden', (tester, variant) async {
    useKeyboardHighlights();
    await pumpThemed(
      tester,
      dataTableGolden(),
      variant: variant,
      size: const Size(360, 900),
    );
    // The rent roll fits, so Tab goes straight to the contacts.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectGolden('mm_data_table', variant);
  });
}
