@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// The three sizes, every tone, a credit, a negative balance, lakh/crore
/// grouping, the compact notation, the end alignment and an amount scaled
/// down to fit a narrow space.
void main() {
  goldenEveryVariant(
    'mm_amount',
    () => GoldenPage((context, say) {
      final rule = context.mm.colors.rule;
      final lakhs = MmFormats.moneyOf(context)
          .copyWith(grouping: DigitGrouping.southAsian);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s2,
        children: [
          const MmAmount(
            amount: Money.fromRupees(125000),
            size: MmAmountSize.large,
          ),
          const MmAmount(amount: Money.fromRupees(45000)),
          const MmAmount(
            amount: Money.fromPaisa(845050),
            size: MmAmountSize.small,
          ),
          const Wrap(
            spacing: MmSpace.s4,
            runSpacing: MmSpace.s1,
            children: [
              MmAmount(
                amount: Money.fromRupees(45000),
                tone: MmAmountTone.muted,
              ),
              MmAmount(
                amount: Money.fromRupees(45000),
                tone: MmAmountTone.paid,
              ),
              MmAmount(
                amount: Money.fromRupees(45000),
                tone: MmAmountTone.overdue,
              ),
              MmAmount(
                amount: Money.fromRupees(45000),
                tone: MmAmountTone.credit,
              ),
            ],
          ),
          MmAmount(
            amount: const Money.fromRupees(-5000),
            creditLabel: say('credit', 'ایڈوانس'),
          ),
          const MmAmount(amount: Money.fromRupees(-5000)),
          MmFormats(
            money: lakhs,
            child: const MmAmount(amount: Money.fromRupees(12500000)),
          ),
          MmFormats(
            money: lakhs.copyWith(notation: MoneyNotation.compact),
            child: const MmAmount(amount: Money.fromRupees(12500000)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: rule)),
            child: const SizedBox(
              width: double.infinity,
              child: MmAmount(
                amount: Money.fromRupees(45000),
                textAlign: TextAlign.end,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: rule)),
            child: const SizedBox(
              width: 120,
              child: MmAmount(
                amount: Money.fromRupees(12500000),
                size: MmAmountSize.large,
              ),
            ),
          ),
        ],
      );
    }),
  );
}
