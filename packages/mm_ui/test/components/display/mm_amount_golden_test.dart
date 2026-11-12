@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The three sizes, every tone, a credit, a negative balance, lakh/crore
/// grouping, the compact notation, the end alignment, and a large amount in
/// a box that holds it at 100% text, scaled back down to fit at 200%.
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
            creditLabel: say('credit', 'کریڈٹ'),
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
              width: 200,
              child: MmAmount(
                amount: Money.fromRupees(45000),
                size: MmAmountSize.large,
              ),
            ),
          ),
        ],
      );
    }),
  );
}
