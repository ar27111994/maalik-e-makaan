@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A failed load with a title, retry and collapsed technical details, and
/// a bare error message on a card.
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
}
