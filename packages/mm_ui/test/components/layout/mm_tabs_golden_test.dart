@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Three tabs sharing the width with the second selected and the first
/// focused from the keyboard, and five that scroll because their labels do
/// not fit.
/// [english], or [urdu] in the Urdu variant.
String say(String english, String urdu, MmVariant variant) =>
    variant == MmVariant.urdu ? urdu : english;

void main() {
  testEveryVariant('mm_tabs golden', (tester, variant) async {
    useKeyboardHighlights();
    await pumpThemed(tester, _tabs(), variant: variant);
    // Tab, as a keyboard user would, so the bar scrolls the focused tab
    // into view.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusedAt(tester, say('Dues', 'چارجز', variant)), isTrue);
    await expectAccessible(tester);
    await expectGolden('mm_tabs', variant);
  });
}

Widget _tabs() => GoldenPage(
  (context, say) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: MmSpace.s6,
    children: [
      DefaultTabController(
        length: 3,
        initialIndex: 1,
        child: MmTabs(
          labels: [
            say('Dues', 'چارجز'),
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
            say('Documents', 'کاغذات'),
            say('Utilities', 'یوٹیلیٹیز'),
            say('History', 'تاریخچہ'),
          ],
        ),
      ),
    ],
  ),
);
