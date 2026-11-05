@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'samples.dart';

void _changed(String _) {}

void main() {
  goldenEveryVariant(
    'mm_select_field',
    () => Localised((context, tr) {
      final properties = [
        MmOption(
          value: 'gulberg',
          label: tr('Gulberg Heights', 'گلبرگ ہائٹس'),
          icon: MmIcons.property,
        ),
        MmOption(
          value: 'dha',
          label: tr('DHA Phase 5 house', 'ڈی ایچ اے فیز 5 کا مکان'),
          icon: MmIcons.home,
        ),
      ];
      final noMatches = tr('No matches', 'کوئی نتیجہ نہیں');
      return GoldenColumn(
        children: [
          MmSelectField<String>(
            label: tr('Property', 'جائیداد'),
            options: properties,
            value: 'gulberg',
            required: true,
            helper: tr('Gulberg, Lahore', 'گلبرگ، لاہور'),
            noMatchesText: noMatches,
            onChanged: _changed,
          ),
          MmSelectField<String>(
            label: tr('Unit', 'یونٹ'),
            options: [
              MmOption(value: 'a1', label: tr('Flat A-1', 'فلیٹ اے-1')),
            ],
            placeholder: tr('Choose a unit', 'یونٹ منتخب کریں'),
            optional: true,
            noMatchesText: noMatches,
            onChanged: _changed,
          ),
          MmSelectField<String>(
            label: tr('Tenant', 'کرایہ دار'),
            options: const [MmOption(value: 'ayesha', label: 'Ayesha Khan')],
            placeholder: tr('Choose a tenant', 'کرایہ دار منتخب کریں'),
            required: true,
            errorText: tr('Choose who rents the unit', 'کرایہ دار منتخب کریں'),
            noMatchesText: noMatches,
            onChanged: _changed,
          ),
          MmSelectField<String>(
            label: tr('Payment method', 'ادائیگی کا طریقہ'),
            options: [
              MmOption(
                value: 'bank',
                label: tr('Bank transfer', 'بینک ٹرانسفر'),
                icon: MmIcons.bank,
              ),
            ],
            value: 'bank',
            noMatchesText: noMatches,
            onChanged: null,
          ),
        ],
      );
    }),
    // Four fields with labels, helpers and errors at 200% text.
    size: const Size(360, 880),
  );
}
