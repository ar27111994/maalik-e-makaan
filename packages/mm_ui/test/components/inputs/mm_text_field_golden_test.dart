@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void main() {
  goldenEveryVariant(
    'mm_text_field',
    () => Localised(
      (context, tr) => GoldenColumn(
        children: [
          MmTextField(
            label: tr('Tenant name', 'کرایہ دار کا نام'),
            initialValue: 'Ali Raza',
            required: true,
            maxLength: 40,
            helper: tr('As on the CNIC', 'جیسا شناختی کارڈ پر لکھا ہے'),
          ),
          MmTextField(
            label: tr("Father's name", 'والد کا نام'),
            optional: true,
            hint: tr('Muhammad Raza', 'محمد رضا'),
          ),
          MmTextField(
            label: tr('Unit', 'یونٹ'),
            prefixIcon: MmIcons.unit,
            required: true,
            errorText: tr('Enter the unit number', 'یونٹ کا نمبر درج کریں'),
          ),
          MmTextField(
            label: tr('Property', 'جائیداد'),
            initialValue: tr('Gulberg Heights', 'گلبرگ ہائٹس'),
            enabled: false,
          ),
        ],
      ),
    ),
    size: const Size(360, 900),
  );
}
