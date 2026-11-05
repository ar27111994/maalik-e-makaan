@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Three tabs sharing the width with the second selected, and five that
/// scroll because their labels do not fit.
void main() {
  goldenEveryVariant(
    'mm_tabs',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: MmSpace.s6,
        children: [
          DefaultTabController(
            length: 3,
            initialIndex: 1,
            child: MmTabs(
              labels: [
                say('Dues', 'واجبات'),
                say('Payments', 'ادائیگیاں'),
                say('Notes', 'نوٹس'),
              ],
            ),
          ),
          DefaultTabController(
            length: 5,
            child: MmTabs(
              labels: [
                say('Overview', 'خلاصہ'),
                say('Payments', 'ادائیگیاں'),
                say('Documents', 'دستاویزات'),
                say('Utilities', 'یوٹیلیٹیز'),
                say('History', 'تاریخچہ'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
