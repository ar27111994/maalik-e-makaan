@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Every variant (the primary one with keyboard focus), an icon, a wrapped
/// label, the busy and disabled states.
Widget _buttons() => GoldenPage(
  // Reduced motion holds the busy ring still, so the image is stable.
  (context, say) => withoutAnimations(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: MmSpace.s3,
      children: [
        MmButton(
          label: say('Record payment', 'ادائیگی درج کریں'),
          icon: MmIcons.payment,
          expand: true,
          onPressed: tapped,
        ),
        MmButton(
          label: say('Send reminder', 'یاد دہانی بھیجیں'),
          icon: MmIcons.reminder,
          variant: MmButtonVariant.secondary,
          onPressed: tapped,
        ),
        MmButton(
          label: say('View ledger', 'کھاتہ دیکھیں'),
          variant: MmButtonVariant.tertiary,
          onPressed: tapped,
        ),
        MmButton(
          label: say('Remove Ali Raza', 'علی رضا کو ہٹائیں'),
          icon: MmIcons.delete,
          variant: MmButtonVariant.destructive,
          onPressed: tapped,
        ),
        MmButton(
          label: say(
            'Send the October rent reminder to Ayesha Khan',
            'عائشہ خان کو اکتوبر کے کرایے کی یاد دہانی بھیجیں',
          ),
          icon: MmIcons.reminder,
          variant: MmButtonVariant.secondary,
          onPressed: tapped,
        ),
        Wrap(
          spacing: MmSpace.s3,
          runSpacing: MmSpace.s3,
          children: [
            MmButton(
              label: say('Save receipt', 'رسید محفوظ کریں'),
              icon: MmIcons.receipt,
              busy: true,
              onPressed: tapped,
            ),
            MmButton(
              label: say('Export', 'برآمد کریں'),
              variant: MmButtonVariant.secondary,
              busy: true,
              onPressed: tapped,
            ),
          ],
        ),
        Wrap(
          spacing: MmSpace.s3,
          runSpacing: MmSpace.s3,
          children: [
            MmButton(
              label: say('Record payment', 'ادائیگی درج کریں'),
              icon: MmIcons.payment,
              onPressed: null,
            ),
            MmButton(
              label: say('Send reminder', 'یاد دہانی بھیجیں'),
              variant: MmButtonVariant.secondary,
              onPressed: null,
            ),
          ],
        ),
      ],
    ),
  ),
);

void main() {
  focusedGoldenEveryVariant(
    'mm_button',
    _buttons,
    focused: textIn('Record payment', 'ادائیگی درج کریں'),
  );
}
