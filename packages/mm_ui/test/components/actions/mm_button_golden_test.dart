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

/// A link at the foot of a card, its label lined up with the words above
/// it and its focus ring reaching into the card's padding.
Widget _link() => GoldenPage(
  (context, say) => MmCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          say('Rent is 12 days late', 'کرایہ 12 دن سے واجب ہے'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(say('Flat 3, Gulberg Heights', 'فلیٹ 3، گلبرگ ہائٹس')),
        const SizedBox(height: MmSpace.s2),
        MmButton(
          label: say("Open Ali Raza's tenancy", 'علی رضا کی کرایہ داری کھولیں'),
          variant: MmButtonVariant.link,
          onPressed: tapped,
        ),
      ],
    ),
  ),
);

/// The foot of a member's sheet: the main action, and the outlined red
/// button that starts removing the member (its confirmation has the filled
/// red one); and the same button disabled.
Widget _removal() => GoldenPage(
  (context, say) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MmSpace.s3,
    children: [
      MmButton(
        label: say('Change role', 'کردار بدلیں'),
        expand: true,
        onPressed: tapped,
      ),
      MmButton(
        label: say('Remove member', 'رکن ہٹائیں'),
        icon: MmIcons.delete,
        variant: MmButtonVariant.destructiveOutlined,
        expand: true,
        onPressed: tapped,
      ),
      MmButton(
        label: say('Remove member', 'رکن ہٹائیں'),
        variant: MmButtonVariant.destructiveOutlined,
        onPressed: null,
      ),
    ],
  ),
);

void main() {
  goldenEveryVariant('mm_button_removal', _removal);

  // The link at rest, as a card shows it: its label in line with the words
  // above, nothing drawn in the card's padding.
  goldenEveryVariant('mm_button_link_rest', _link);

  focusedGoldenEveryVariant(
    'mm_button_link',
    _link,
    focused: textIn("Open Ali Raza's tenancy", 'علی رضا کی کرایہ داری کھولیں'),
  );

  focusedGoldenEveryVariant(
    'mm_button',
    _buttons,
    focused: textIn('Record payment', 'ادائیگی درج کریں'),
  );
}
