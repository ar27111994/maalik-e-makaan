@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void main() {
  goldenEveryVariant(
    'mm_text_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmTextField(
            label: tr('Tenant name', 'کرایہ دار کا نام'),
            initialValue: 'Ali Raza',
            required: true,
            maxLength: 40,
            helper: tr('As on the CNIC', 'جیسا شناختی کارڈ پر لکھا ہے'),
          ),
          // Focused, as when the landlord has just moved to it.
          MmTextField(
            label: tr("Father's name", 'والد کا نام'),
            optional: true,
            autofocus: true,
            hint: tr('For example, Muhammad Raza', 'مثلاً محمد رضا'),
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
    sizes: const {MmVariant.largeText: Size(360, 768)},
  );

  // Words typed in the other language run in their own direction, under
  // labels in the UI's direction: a message of several lines from the start
  // of its own direction, a one-line name at the start edge of the form.
  goldenEveryVariant(
    'mm_text_field_direction',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmTextField(
            label: tr('Reminder', 'یاد دہانی'),
            initialValue: tr(
              'اکتوبر کا کرایہ 45,000 روپے واجب ہے۔',
              'October rent of Rs 45,000 is due.',
            ),
            minLines: 2,
            maxLines: 4,
          ),
          MmTextField(
            label: tr('Tenant name', 'کرایہ دار کا نام'),
            initialValue: tr('علی رضا', 'Ali Raza'),
          ),
        ],
      ),
    ),
  );
}
