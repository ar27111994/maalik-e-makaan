@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

void _changed(bool? _) {}

void main() {
  tearDown(resetFocusHighlights);
  goldenEveryVariant(
    'mm_checkbox_tile',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmCheckboxTile(
            label: tr('Rent includes electricity', 'کرایہ میں بجلی شامل ہے'),
            description: tr(
              'Up to ${_rupees(context, 8000)} a month',
              'ماہانہ ${_rupees(context, 8000)} تک',
            ),
            value: true,
            onChanged: _changed,
          ),
          // Keyboard focus: the row is ringed.
          KeyboardFocused(
            child: MmCheckboxTile(
              label: tr('CNIC copy received', 'شناختی کارڈ کی کاپی مل گئی'),
              value: false,
              onChanged: _changed,
            ),
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

/// [rupees] as the app formats them, kept on one line.
String _rupees(BuildContext context, int rupees) =>
    MmFormats.moneyOf(context)
        .format(Money.fromRupees(rupees))
        .replaceAll(' ', '\u00A0');
