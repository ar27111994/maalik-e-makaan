@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// An empty list with its one action, and empty search results without an
/// action, on a card.
void main() {
  goldenEveryVariant(
    'mm_empty_state',
    () => FeedbackPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          MmEmptyState(
            icon: MmIcons.tenants,
            title: say('No tenants yet', 'ابھی کوئی کرایہ دار نہیں'),
            message: say(
              'Add your first tenant to start tracking rent in Gulberg.',
              'گلبرگ میں کرایہ درج کرنے کے لیے پہلا کرایہ دار شامل کریں۔',
            ),
            actionLabel: say('Add tenant', 'کرایہ دار شامل کریں'),
            onAction: tapped,
          ),
          Card(
            child: MmEmptyState(
              icon: MmIcons.search,
              title: say('No matches for "Ayesha"', '"عائشہ" سے کچھ نہیں ملا'),
              message: say(
                'Check the spelling or search by phone number.',
                'ہجے دیکھیں یا فون نمبر سے تلاش کریں۔',
              ),
            ),
          ),
        ],
      ),
    ),
    size: const Size(360, 1000),
  );
}
