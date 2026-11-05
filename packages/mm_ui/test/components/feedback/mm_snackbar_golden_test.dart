@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A snackbar showing at the bottom of a small screen of its own.
class _Screen extends StatelessWidget {
  const new({
    required this.message,
    this.tone,
    this.actionLabel,
    this.onAction,
    this.height = 120,
  });

  final String message;
  final double height;
  final MmBannerTone? tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    return SizedBox(
      height: height * scale * (urdu ? 1.4 : 1),
      child: ScaffoldMessenger(
        child: Scaffold(
          body: OverlayHost(
            open: (context) => unawaited(
              showMmSnackbar(
                context,
                message: message,
                tone: tone,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain message, a success with its icon, and an error with an action.
void main() {
  goldenEveryVariant(
    'mm_snackbar',
    () => FeedbackPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s2,
        children: [
          _Screen(message: say('Receipt shared', 'رسید شیئر ہو گئی')),
          _Screen(
            message: say(
              'Rs 45,000 recorded for Ayesha Khan',
              'عائشہ خان کے 45,000 روپے درج ہو گئے',
            ),
            tone: MmBannerTone.success,
          ),
          _Screen(
            message: say(
              'Ali Raza’s payment was deleted',
              'علی رضا کی ادائیگی حذف ہو گئی',
            ),
            tone: MmBannerTone.error,
            actionLabel: say('Undo', 'واپس لیں'),
            onAction: tapped,
            height: 150,
          ),
        ],
      ),
    ),
    size: const Size(360, 1200),
  );
}
