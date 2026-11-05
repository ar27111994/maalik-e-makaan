@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void _changed(bool _) {}

void main() {
  goldenEveryVariant(
    'mm_switch_tile',
    () => Localised(
      (context, tr) => GoldenColumn(
        gap: 0,
        children: [
          MmSwitchTile(
            label: tr('Send rent reminders', 'کرایہ کی یاد دہانی بھیجیں'),
            description: tr(
              'WhatsApp tenants three days before rent is due',
              'کرایہ داروں کو تین دن پہلے واٹس ایپ کریں',
            ),
            value: true,
            onChanged: _changed,
          ),
          MmSwitchTile(
            label: tr('Add late fees', 'تاخیر کی فیس شامل کریں'),
            value: false,
            onChanged: _changed,
          ),
          MmSwitchTile(
            label: tr('Lakh and crore grouping', 'لاکھ اور کروڑ میں دکھائیں'),
            description: 'Rs 1,25,000',
            value: true,
            onChanged: null,
          ),
          MmSwitchTile(
            label: tr('Share receipts by SMS', 'رسیدیں ایس ایم ایس سے بھیجیں'),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    ),
  );
}
