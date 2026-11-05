@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void main() {
  goldenEveryVariant(
    'mm_phone_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmPhoneField(
            label: tr('Mobile number', 'موبائل نمبر'),
            value: PhoneNumber.tryParse('+923001234567'),
            required: true,
            helper: tr(
              'Rent reminders are sent to this number',
              'کرایے کی یاد دہانی اسی نمبر پر جائے گی',
            ),
            onChanged: (_) {},
          ),
          MmPhoneField(
            label: tr('Home number', 'گھر کا نمبر'),
            value: PhoneNumber.tryParse('042 35761234'),
            optional: true,
            onChanged: (_) {},
          ),
          MmPhoneField(
            label: tr('Number abroad', 'بیرونِ ملک نمبر'),
            value: PhoneNumber.tryParse('+447700900123'),
            errorText: tr('Not a mobile number', 'یہ نمبر موبائل نہیں'),
            onChanged: (_) {},
          ),
          MmPhoneField(
            label: tr("Owner's number", 'مالک کا نمبر'),
            value: PhoneNumber.tryParse('03214567890'),
            enabled: false,
            onChanged: (_) {},
          ),
        ],
      ),
    ),
    size: const Size(360, 860),
  );
}
