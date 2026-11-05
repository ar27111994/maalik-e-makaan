@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A property's month at a glance: one meter in each tone, from an empty
/// share to a nearly full one.
Widget meterGolden() => GoldenPage(
  (context, say) => Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(MmSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmMeter(
            value: 0.72,
            label: say('Rent collected', 'وصول شدہ کرایہ'),
            valueLabel: say(
              'Rs\u00A090,000 of Rs\u00A01,25,000',
              '1,25,000 میں سے 90,000\u00A0روپے',
            ),
            tone: MmMeterTone.paid,
          ),
          MmMeter(
            value: 0.8,
            label: say('Units let', 'کرائے پر دیے گئے یونٹ'),
            valueLabel: say('8 of 10', '10 میں سے 8'),
          ),
          MmMeter(
            value: 9 / 11,
            label: say('Lease elapsed', 'معاہدے کی گزری مدت'),
            valueLabel: say('9 of 11 months', '11 میں سے 9 ماہ'),
            tone: MmMeterTone.dueSoon,
          ),
          MmMeter(
            value: 0.36,
            label: say('Overdue', 'بقایا'),
            valueLabel: say(
              'Rs\u00A045,000 of Rs\u00A01,25,000',
              '1,25,000 میں سے 45,000\u00A0روپے',
            ),
            tone: MmMeterTone.overdue,
          ),
          MmMeter(
            value: 0,
            label: say('Bills paid', 'ادا شدہ بل'),
            valueLabel: say('None yet', 'ابھی کوئی نہیں'),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  goldenEveryVariant('mm_meter', meterGolden);
}
