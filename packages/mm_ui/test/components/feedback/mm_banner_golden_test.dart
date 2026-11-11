@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Every tone: information with a title, a dismissible success, a warning
/// with an action and a dismiss button, and an error with an action.
void main() {
  goldenEveryVariant(
    'mm_banner',
    () => withoutAnimations(
      GoldenPage(
        (context, say) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MmSpace.s3,
          children: [
            MmBanner(
              tone: MmBannerTone.info,
              title: say('Reminders on the 1st', 'یکم تاریخ کو یاد دہانی'),
              message: say(
                'Tenants in Gulberg get a rent reminder by SMS.',
                'گلبرگ کے کرایہ داروں کو ایس ایم ایس سے یاد دہانی جاتی ہے۔',
              ),
            ),
            MmBanner(
              tone: MmBannerTone.success,
              message: say(
                'Rs 45,000 received from Ayesha Khan.',
                'عائشہ خان سے 45,000 روپے مل گئے۔',
              ),
              onDismiss: tapped,
            ),
            MmBanner(
              tone: MmBannerTone.warning,
              title: say('Lease ending', 'کرایہ نامہ ختم ہو رہا ہے'),
              message: say(
                'Ali Raza’s lease for Flat 3 ends in 14 days.',
                'علی رضا کا فلیٹ 3 کا کرایہ نامہ 14 دن میں ختم ہو گا۔',
              ),
              actionLabel: say('Renew lease', 'کرایہ نامہ رینیو کریں'),
              onAction: tapped,
              onDismiss: tapped,
            ),
            MmBanner(
              tone: MmBannerTone.error,
              message: say(
                'Rs 1,25,000 is overdue from 3 tenants.',
                '3 کرایہ داروں کے ذمے 1,25,000 روپے باقی ہیں۔',
              ),
              actionLabel: say('Send reminders', 'یاد دہانی بھیجیں'),
              onAction: tapped,
            ),
          ],
        ),
      ),
    ),
    size: const Size(360, 1300),
  );
}
