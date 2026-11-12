@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'focus.dart';

void _changed(int _) {}

void main() {
  tearDown(resetFocusHighlights);
  goldenEveryVariant(
    'mm_stepper_field',
    () => GoldenPage(
      (context, tr) => _lakh(
        context,
        (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MmSpace.s4,
          children: [
            MmStepperField(
              label: tr('Advance rent', 'ایڈوانس کرایہ'),
              value: 3,
              min: 0,
              max: 12,
              decreaseLabel: tr('Fewer months', 'کم مہینے'),
              increaseLabel: tr('More months', 'زیادہ مہینے'),
              format: (months) => tr('$months months', '$months مہینے'),
              helper: tr(
                '${_rupees(context, 135000)} at ${_rupees(context, 45000)} '
                    'a month',
                '${_rupees(context, 45000)} ماہانہ پر '
                    '${_rupees(context, 135000)}',
              ),
              onChanged: _changed,
            ),
            // Keyboard focus on the plus (the minus is at its limit): its
            // ring sits inside the box.
            KeyboardFocused(
              child: MmStepperField(
                label: tr('Rooms', 'کمرے'),
                value: 1,
                min: 1,
                max: 10,
                decreaseLabel: tr('Fewer rooms', 'کم کمرے'),
                increaseLabel: tr('More rooms', 'زیادہ کمرے'),
                onChanged: _changed,
              ),
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
    ),
  );
}

/// [build]'s composition with amounts in lakh and crore, as a landlord who
/// chose that grouping sees them.
Widget _lakh(BuildContext context, WidgetBuilder build) => MmFormats(
  money: MmFormats.defaultFor(Localizations.localeOf(context))
      .copyWith(grouping: DigitGrouping.southAsian),
  child: Builder(builder: build),
);

/// [rupees] as the app formats them, kept on one line: the marker and the
/// figures do not part.
String _rupees(BuildContext context, int rupees) =>
    MmFormats.moneyOf(context)
        .format(Money.fromRupees(rupees))
        .replaceAll(' ', '\u00A0');
