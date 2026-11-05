@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The tenant list while it loads: four rows on a card.
void main() {
  goldenEveryVariant(
    'mm_skeleton_list',
    () => withoutAnimations(
      GoldenPage((context, say) => const MmSkeletonList(itemCount: 4)),
    ),
  );
}
