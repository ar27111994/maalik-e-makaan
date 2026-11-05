@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A plain confirmation, and a destructive one that waits for the
/// property's name to be typed, each over its page, scrim included.
void main() {
  overlayGoldenEveryVariant('mm_confirm_dialog', (context) {
    final say = sayIn(context);
    unawaited(
      showMmConfirmDialog(
        context,
        title: say('Mark October as paid?', 'اکتوبر کو ادا شدہ کریں؟'),
        message: say(
          'Rs 45,000 from Ayesha Khan will be recorded as cash.',
          'عائشہ خان کے 45,000 روپے نقد کے طور پر درج ہوں گے۔',
        ),
        confirmLabel: say('Mark as paid', 'ادا شدہ کریں'),
      ),
    );
  });
  overlayGoldenEveryVariant('mm_confirm_dialog_destructive', (context) {
    final say = sayIn(context);
    unawaited(
      showMmConfirmDialog(
        context,
        title: say('Delete Gulberg House?', 'گلبرگ ہاؤس حذف کریں؟'),
        message: say(
          'Its 4 units and Rs 1,25,000 of history will be removed.',
          'اس کے 4 یونٹ اور 1,25,000 روپے کا ریکارڈ ختم ہو جائے گا۔',
        ),
        confirmLabel: say('Delete property', 'جائیداد حذف کریں'),
        destructive: true,
        typedConfirmation: 'Gulberg House',
        typedConfirmationLabel: say(
          'Type Gulberg House to confirm',
          'تصدیق کے لیے Gulberg House لکھیں',
        ),
      ),
    );
  });
}
