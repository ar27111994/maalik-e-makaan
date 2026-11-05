@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// The tenant list while it loads: four rows on a card.
void main() {
  goldenEveryVariant(
    'mm_skeleton_list',
    () => FeedbackPage((context, say) => const MmSkeletonList(itemCount: 4)),
  );
}
