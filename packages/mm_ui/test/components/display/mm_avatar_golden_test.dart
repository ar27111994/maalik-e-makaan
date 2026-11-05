@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// Latin and Urdu initials, a single word, an icon and an empty name, at
/// four sizes.
void main() {
  goldenEveryVariant(
    'mm_avatar',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          for (final size in [24.0, 32.0, 40.0, 56.0])
            Wrap(
              spacing: MmSpace.s2,
              children: [
                MmAvatar(name: 'Ali Raza', size: size),
                MmAvatar(name: 'ayesha khan', size: size),
                MmAvatar(name: 'Bilal', size: size),
                MmAvatar(name: 'علی رضا', size: size),
                MmAvatar(name: 'عائشہ خان', size: size),
                MmAvatar(
                  name: say('Gulberg Heights', 'گلبرگ ہائٹس'),
                  size: size,
                  icon: MmIcons.property,
                ),
                MmAvatar(name: '', size: size),
              ],
            ),
        ],
      ),
    ),
  );
}
