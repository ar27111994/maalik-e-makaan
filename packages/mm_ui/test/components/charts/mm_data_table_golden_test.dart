@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A rent roll that fits its card (a name typed in Urdu among Latin ones,
/// the first column taking the width to spare, rents at the end edge) and a
/// contact list too wide for it, which scrolls sideways with a scrollbar.
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
            caption: say('Rent roll, November', 'نومبر کا کرایہ نامہ'),
            columns: [
              MmDataColumn(label: say('Tenant', 'کرایہ دار')),
              MmDataColumn(label: say('Unit', 'یونٹ')),
              MmDataColumn(label: say('Rent', 'کرایہ'), numeric: true),
            ],
            rows: [
              [
                'Ali Raza',
                say('Flat 2B', 'فلیٹ 2B'),
                say('Rs 45,000', '45,000 روپے'),
              ],
              [
                'Ayesha Khan',
                say('Shop 4', 'دکان 4'),
                say('Rs 1,25,000', '1,25,000 روپے'),
              ],
              [
                'فاطمہ نور',
                say('Flat 1A', 'فلیٹ 1A'),
                say('Rs 52,000', '52,000 روپے'),
              ],
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
              MmDataColumn(label: say('Since', 'از'), numeric: true),
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
  goldenEveryVariant(
    'mm_data_table',
    dataTableGolden,
    size: const Size(360, 900),
  );
}
