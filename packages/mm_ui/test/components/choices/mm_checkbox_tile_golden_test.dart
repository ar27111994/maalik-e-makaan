@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void _changed(bool? _) {}

void main() {
  goldenEveryVariant(
    'mm_checkbox_tile',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmCheckboxTile(
            label: tr('Rent includes electricity', 'کرایہ میں بجلی شامل ہے'),
            description: tr('Up to Rs 8,000 a month', 'ماہانہ 8,000 روپے تک'),
            value: true,
            onChanged: _changed,
          ),
          MmCheckboxTile(
            label: tr('CNIC copy received', 'شناختی کارڈ کی کاپی مل گئی'),
            value: false,
            onChanged: _changed,
          ),
          MmCheckboxTile(
            label: tr('All units in Gulberg', 'گلبرگ کے تمام یونٹ'),
            value: null,
            tristate: true,
            onChanged: _changed,
          ),
          MmCheckboxTile(
            label: tr('Police verification done', 'پولیس تصدیق ہو گئی'),
            value: true,
            onChanged: null,
          ),
        ],
      ),
    ),
  );
}
