@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

void main() {
  goldenEveryVariant(
    'mm_money_field',
    () => GoldenPage(
      (context, tr) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          MmMoneyField(
            label: tr('Monthly rent', 'ماہانہ کرایہ'),
            value: const Money.fromRupees(45000),
            required: true,
            helper: tr('As agreed in the lease', 'جیسا کرایہ نامے میں طے ہے'),
            onChanged: (_) {},
          ),
          MmFormats(
            money: MmFormats.defaultFor(Localizations.localeOf(context))
                .copyWith(grouping: DigitGrouping.southAsian),
            // Focused, as when the landlord has just moved to it.
            child: MmMoneyField(
              label: tr('Security deposit', 'سیکیورٹی'),
              value: const Money.fromRupees(125000),
              optional: true,
              autofocus: true,
              onChanged: (_) {},
            ),
          ),
          MmMoneyField(
            label: tr('Amount received', 'کتنی رقم ملی'),
            required: true,
            errorText: tr('Enter the amount received', 'رقم درج کریں'),
            onChanged: (_) {},
          ),
          MmMoneyField(
            label: tr('Electricity bill', 'بجلی کا بل'),
            value: Money.parseDecimal('2350.50'),
            enabled: false,
            onChanged: (_) {},
          ),
        ],
      ),
    ),
    sizes: const {MmVariant.largeText: Size(360, 800)},
  );
}
