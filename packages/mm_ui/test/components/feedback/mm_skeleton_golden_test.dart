@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A stat card and a tenant card while they load: a box for the figure,
/// a circle for the avatar and lines for the text, on cards.
void main() {
  goldenEveryVariant(
    'mm_skeleton',
    () => FeedbackPage(
      (context, say) => const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(MmSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MmSpace.s2,
                children: [
                  MmSkeleton.text(),
                  MmSkeleton.box(width: 180, height: 40),
                  MmSkeleton.text(lines: 2),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(MmSpace.s4),
              child: Row(
                spacing: MmSpace.s3,
                children: [
                  MmSkeleton.circle(diameter: 48),
                  Expanded(child: MmSkeleton.text(lines: 3)),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(MmSpace.s4),
              child: MmSkeleton.box(height: 120),
            ),
          ),
        ],
      ),
    ),
  );
}
