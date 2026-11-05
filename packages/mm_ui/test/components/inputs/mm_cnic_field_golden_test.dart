@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void main() {
  goldenEveryVariant(
    'mm_cnic_field',
    () => Localised(
      (context, tr) => GoldenColumn(
        children: [
          MmCnicField(
            label: tr("Tenant's CNIC", 'کرایہ دار کا شناختی کارڈ'),
            value: Cnic.parse('35202-1234567-1'),
            required: true,
            helper: tr('13 digits, as on the card', '۱۳ ہندسے'),
            onChanged: (_) {},
          ),
          MmCnicField(
            label: tr("Guarantor's CNIC", 'ضامن کا شناختی کارڈ'),
            optional: true,
            onChanged: (_) {},
          ),
          MmCnicField(
            label: tr('CNIC', 'شناختی کارڈ'),
            value: Cnic.parse('42101-7654321-2'),
            errorText: tr(
              'Already on another tenant',
              'یہ شناختی کارڈ پہلے سے درج ہے',
            ),
            onChanged: (_) {},
          ),
          MmCnicField(
            label: tr("Owner's CNIC", 'مالک کا شناختی کارڈ'),
            value: Cnic.parse('61101-2345678-9'),
            enabled: false,
            onChanged: (_) {},
          ),
        ],
      ),
    ),
    size: const Size(360, 860),
  );
}
