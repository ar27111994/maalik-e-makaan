@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// Nameplates as property headers: with an address and a house icon, a
/// shop with no address, and a name written in English with no icon.
Widget nameplateGolden() => GoldenPage(
  (context, say) => Padding(
    padding: const EdgeInsetsDirectional.all(MmSpace.s2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: MmSpace.s4,
      children: [
        MmNameplate(
          name: say('Raza Manzil', 'رضا منزل'),
          subtitle: say(
            'House 12, Street 4, Gulberg III, Lahore',
            'مکان 12، گلی 4، گلبرگ III، لاہور',
          ),
          icon: MmIcons.home,
        ),
        MmNameplate(
          name: say('Khan Plaza, Shop 3', 'خان پلازہ، دکان 3'),
          icon: MmIcons.shop,
        ),
        MmNameplate(
          name: 'Gulberg Heights',
          subtitle: say(
            'Flat 7B, Main Boulevard, Lahore',
            'فلیٹ 7B، مین بلیوارڈ، لاہور',
          ),
        ),
      ],
    ),
  ),
);

void main() {
  goldenEveryVariant('mm_nameplate', nameplateGolden);
}
