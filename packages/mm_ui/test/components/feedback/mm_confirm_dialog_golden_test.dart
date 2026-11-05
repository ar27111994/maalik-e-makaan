@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/components/feedback/mm_confirm_dialog.dart';

import '../../support/harness.dart';
import 'support.dart';

/// The dialog in a box of its own, as a dialog route lays it out (the
/// route itself would cover the whole golden surface).
class _Dialog extends StatelessWidget {
  const new({required this.height, required this.dialog});

  final double height;
  final MmConfirmDialog dialog;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    return SizedBox(height: height * scale * (urdu ? 1.5 : 1), child: dialog);
  }
}

/// A plain confirmation, and a destructive one that waits for the
/// property's name to be typed.
void main() {
  goldenEveryVariant(
    'mm_confirm_dialog',
    () => FeedbackPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Dialog(
            height: 250,
            dialog: MmConfirmDialog(
              title: say('Mark October as paid?', 'اکتوبر کو ادا شدہ کریں؟'),
              message: say(
                'Rs 45,000 from Ayesha Khan will be recorded as cash.',
                'عائشہ خان کے 45,000 روپے نقد کے طور پر درج ہوں گے۔',
              ),
              confirmLabel: say('Mark as paid', 'ادا شدہ کریں'),
              destructive: false,
              typedConfirmation: null,
              typedConfirmationLabel: null,
            ),
          ),
          _Dialog(
            height: 400,
            dialog: MmConfirmDialog(
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
          ),
        ],
      ),
    ),
    size: const Size(360, 1500),
  );
}
