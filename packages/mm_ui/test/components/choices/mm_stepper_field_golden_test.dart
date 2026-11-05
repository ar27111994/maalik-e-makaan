@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void _changed(int _) {}

void main() {
  goldenEveryVariant(
    'mm_stepper_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmStepperField(
            label: tr('Advance rent', 'پیشگی کرایہ'),
            value: 3,
            min: 0,
            max: 12,
            decreaseLabel: tr('Fewer months', 'کم مہینے'),
            increaseLabel: tr('More months', 'زیادہ مہینے'),
            format: (months) => tr('$months months', '$months مہینے'),
            helper: tr(
              'Rs 1,35,000 at Rs 45,000 a month',
              '45,000 روپے ماہانہ پر 1,35,000 روپے',
            ),
            onChanged: _changed,
          ),
          MmStepperField(
            label: tr('Rooms', 'کمرے'),
            value: 1,
            min: 1,
            max: 10,
            decreaseLabel: tr('Fewer rooms', 'کم کمرے'),
            increaseLabel: tr('More rooms', 'زیادہ کمرے'),
            onChanged: _changed,
          ),
          MmStepperField(
            label: tr('Reminder days', 'یاد دہانی کے دن'),
            value: 7,
            min: 1,
            max: 7,
            decreaseLabel: tr('Fewer days', 'کم دن'),
            increaseLabel: tr('More days', 'زیادہ دن'),
            onChanged: null,
          ),
        ],
      ),
    ),
  );
}
