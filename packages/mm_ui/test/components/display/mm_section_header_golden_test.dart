@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// A header with an action focused from the keyboard, with a subtitle, with
/// a disabled action under a long title, and on its own. Each action's
/// words line up with the content's edge.
void main() {
  focusedGoldenEveryVariant(
    'mm_section_header',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmSectionHeader(
            title: say('Tenants', 'کرایہ دار'),
            actionLabel: say('See all', 'سب دیکھیں'),
            onAction: tapped,
          ),
          MmSectionHeader(
            title: say('October dues', 'اکتوبر کے واجبات'),
            subtitle: say(
              '3 overdue, Rs 1,25,000 outstanding',
              '3 بقایا، 1,25,000 روپے باقی',
            ),
            actionLabel: say('Remind', 'یاد دلائیں'),
            onAction: tapped,
          ),
          MmSectionHeader(
            title: 'Gulberg Heights, Block C, Main Boulevard',
            actionLabel: say('Edit', 'ترمیم'),
          ),
          MmSectionHeader(title: say('Documents', 'دستاویزات')),
        ],
      ),
    ),
    focused: textIn('See all', 'سب دیکھیں'),
  );
}
