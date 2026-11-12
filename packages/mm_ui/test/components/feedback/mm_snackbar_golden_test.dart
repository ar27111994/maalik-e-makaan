@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// A tenant list the snack bar shows over.
class _Page extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final say = sayIn(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Text(
            say('Tenants', 'کرایہ دار'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

/// A success, with its icon, a deletion the landlord can undo, and the
/// same with a screen reader on, each at the bottom of a screen over its
/// page.
void main() {
  overlayGoldenEveryVariant('mm_snackbar', (context) {
    final say = sayIn(context);
    unawaited(
      showMmSnackbar(
        context,
        message: say(
          'Rs 45,000 recorded for Ayesha Khan',
          'عائشہ خان کے 45,000 روپے درج ہو گئے',
        ),
        tone: MmBannerTone.success,
      ),
    );
  }, behind: () => const _Page());
  overlayGoldenEveryVariant('mm_snackbar_action', (context) {
    final say = sayIn(context);
    unawaited(
      showMmSnackbar(
        context,
        message: say(
          'Ali Raza’s payment was deleted',
          'علی رضا کی ادائیگی ڈیلیٹ ہو گئی',
        ),
        actionLabel: say('Undo', 'واپس لیں'),
        onAction: tapped,
      ),
    );
  }, behind: () => const _Page());

  // With a screen reader on, the snackbar stays and has a dismiss button;
  // the action, under the message, has keyboard focus and draws the
  // snackbar's own (opposite mode's) focus ring.
  testEveryVariant('mm_snackbar_screen_reader golden', (tester, variant) async {
    useScreenReader(tester);
    useKeyboardHighlights();
    await pumpOverlay(
      tester,
      (context) {
        final say = sayIn(context);
        unawaited(
          showMmSnackbar(
            context,
            message: say(
              'Rs 45,000 from Ayesha Khan was deleted',
              'عائشہ خان کے 45,000 روپے ڈیلیٹ ہو گئے',
            ),
            tone: MmBannerTone.info,
            actionLabel: say('Undo', 'واپس لیں'),
            onAction: tapped,
          ),
        );
      },
      behind: const _Page(),
      variant: variant,
    );
    // Dismiss comes first, on the message's line; then the action.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectScreenGolden('mm_snackbar_screen_reader', variant);
  });
}
