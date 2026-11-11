@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A rent receipt with every part, and a void one with fewer rows, both
/// with lakh/crore grouping as a landlord would set it.
Widget receiptGolden() => GoldenPage(
  (context, say) => MmFormats(
    money: MmFormats.defaultFor(Localizations.localeOf(context))
        .copyWith(grouping: DigitGrouping.southAsian),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MmSpace.s4,
      children: [
        MmReceipt(
          issuer: 'Ayesha Khan',
          numberLabel: say('Receipt no.', 'رسید نمبر'),
          receiptNumber: 'R-2026-0142',
          amountLabel: say('Amount received', 'کتنی رقم ملی'),
          amount: const Money.fromRupees(45000),
          rows: [
            MmReceiptRow(label: say('Tenant', 'کرایہ دار'), value: 'Ali Raza'),
            MmReceiptRow(
              label: say('Property', 'جائیداد'),
              value: say(
                'House 12, Gulberg III, Lahore',
                'مکان 12، گلبرگ III، لاہور',
              ),
            ),
            MmReceiptRow(
              label: say('Period', 'مدت'),
              value: say('October 2026', 'اکتوبر 2026'),
            ),
            MmReceiptRow(
              label: say('Method', 'طریقہ'),
              value: say('Bank transfer', 'بینک ٹرانسفر'),
            ),
          ],
          footer: say(
            'Thank you. Keep this receipt for your records.',
            'شکریہ۔ یہ رسید اپنے ریکارڈ کے لیے سنبھال کر رکھیں۔',
          ),
        ),
        MmReceipt(
          issuer: 'Ayesha Khan',
          numberLabel: say('Receipt no.', 'رسید نمبر'),
          receiptNumber: 'R-2026-0139',
          amountLabel: say('Amount received', 'کتنی رقم ملی'),
          amount: const Money.fromRupees(125000),
          rows: [
            MmReceiptRow(
              label: say('Tenant', 'کرایہ دار'),
              value: 'Bilal Ahmed',
            ),
            MmReceiptRow(
              label: say('Period', 'مدت'),
              value: say('Jul to Sep 2026', 'جولائی سے ستمبر 2026 تک'),
            ),
          ],
          voidedLabel: say(
            'VOID: cancelled on 12 Oct 2026',
            'کینسل: 12 اکتوبر 2026 کو کینسل ہوئی',
          ),
        ),
      ],
    ),
  ),
);

void main() {
  // Two receipts outgrow the phone in Urdu (870 dp tall) and at 200% text
  // (1435 dp).
  goldenEveryVariant(
    'mm_receipt',
    receiptGolden,
    sizes: const {
      MmVariant.urdu: Size(360, 900),
      MmVariant.largeText: Size(360, 1480),
    },
  );
}
