@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Every variant, an icon, a wrapped label, the busy and disabled states.
class _Buttons extends StatelessWidget {
  const new();

  static void _pressed() {}

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    // The page colour behind the buttons: the golden captures only the
    // subject, so dark modes would otherwise show on transparency. Reduced
    // motion holds the busy ring still, so the image is stable.
    return ColoredBox(
      color: context.mm.colors.bg,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: SizedBox(
          width: 328,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: MmSpace.s3,
            children: [
              MmButton(
                label: say('Record payment', 'ادائیگی درج کریں'),
                icon: MmIcons.payment,
                expand: true,
                onPressed: _pressed,
              ),
              MmButton(
                label: say('Send reminder', 'یاد دہانی بھیجیں'),
                icon: MmIcons.reminder,
                variant: MmButtonVariant.secondary,
                onPressed: _pressed,
              ),
              MmButton(
                label: say('View ledger', 'کھاتہ دیکھیں'),
                variant: MmButtonVariant.tertiary,
                onPressed: _pressed,
              ),
              MmButton(
                label: say('Remove Ali Raza', 'علی رضا کو ہٹائیں'),
                icon: MmIcons.delete,
                variant: MmButtonVariant.destructive,
                onPressed: _pressed,
              ),
              MmButton(
                label: say(
                  'Send the October rent reminder to Ayesha Khan',
                  'عائشہ خان کو اکتوبر کے کرایے کی یاد دہانی بھیجیں',
                ),
                variant: MmButtonVariant.secondary,
                onPressed: _pressed,
              ),
              Wrap(
                spacing: MmSpace.s3,
                runSpacing: MmSpace.s3,
                children: [
                  MmButton(
                    label: say('Save receipt', 'رسید محفوظ کریں'),
                    icon: MmIcons.receipt,
                    busy: true,
                    onPressed: _pressed,
                  ),
                  MmButton(
                    label: say('Export', 'برآمد کریں'),
                    variant: MmButtonVariant.secondary,
                    busy: true,
                    onPressed: _pressed,
                  ),
                ],
              ),
              MmButton(
                label: say('Record payment', 'ادائیگی درج کریں'),
                icon: MmIcons.payment,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  goldenEveryVariant('mm_button', () => const _Buttons());
}
