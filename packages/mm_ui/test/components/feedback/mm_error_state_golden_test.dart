@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A failed load with a title, retry and collapsed technical details, and
/// a bare error message on a card; then the details open.
void main() {
  goldenEveryVariant(
    'mm_error_state',
    () => withoutAnimations(
      GoldenPage(
        (context, say) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MmSpace.s3,
          children: [
            MmErrorState(
              title: say('Ledger unavailable', 'کھاتہ دستیاب نہیں'),
              message: say(
                'The ledger for Ali Raza could not be loaded. Check your '
                    'connection and try again.',
                'علی رضا کا کھاتہ لوڈ نہیں ہو سکا۔ انٹرنیٹ دیکھ کر دوبارہ '
                    'کوشش کریں۔',
              ),
              onRetry: tapped,
              details: 'HTTP 503: ledger_entries timed out after 30 s',
              detailsLabel: say('Technical details', 'تکنیکی تفصیلات'),
            ),
            Card(
              child: MmErrorState(
                message: say(
                  'Receipts could not be shared.',
                  'رسیدیں شیئر نہیں ہو سکیں۔',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    size: const Size(360, 1100),
  );

  // The technical details open: a sunken, selectable well, left to right.
  testEveryVariant('mm_error_state_details golden', (tester, variant) async {
    await pumpThemed(
      tester,
      withoutAnimations(
        GoldenPage(
          (context, say) => MmErrorState(
            title: say('Ledger unavailable', 'کھاتہ دستیاب نہیں'),
            message: say(
              'The ledger for Ali Raza could not be loaded. Check your '
                  'connection and try again.',
              'علی رضا کا کھاتہ لوڈ نہیں ہو سکا۔ انٹرنیٹ دیکھ کر دوبارہ '
                  'کوشش کریں۔',
            ),
            onRetry: tapped,
            details:
                'HTTP 503: ledger_entries timed out after 30 s '
                '(request 7f3a-41c2, Lahore edge)',
            detailsLabel: say('Technical details', 'تکنیکی تفصیلات'),
          ),
        ),
      ),
      variant: variant,
      size: variant == MmVariant.largeText
          ? const Size(360, 1300)
          : const Size(360, 740),
    );
    await tester.tap(find.byIcon(MmIcons.expand));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectGolden('mm_error_state_details', variant);
  });
}
