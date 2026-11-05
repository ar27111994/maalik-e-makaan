@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

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

/// A success, with its icon, and an error with an action, each at the
/// bottom of a screen over its page.
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
          'علی رضا کی ادائیگی حذف ہو گئی',
        ),
        tone: MmBannerTone.error,
        actionLabel: say('Undo', 'واپس لیں'),
        onAction: tapped,
      ),
    );
  }, behind: () => const _Page());
}
