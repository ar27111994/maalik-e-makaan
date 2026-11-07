@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A receipt's rows: a name typed in English, a CNIC with a copy button, a
/// long address that moves under its label, an amount with a badge, and an
/// emphasized total, in lakh grouping.
void main() {
  goldenEveryVariant(
    'mm_detail_row',
    () => GoldenPage(
      (context, say) => MmFormats(
        money: MmFormats.moneyOf(context)
            .copyWith(grouping: DigitGrouping.southAsian),
        child: MmCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(label: say('Tenant', 'کرایہ دار'), value: 'Ali Raza'),
              MmDetailRow(
                label: say('CNIC', 'شناختی کارڈ'),
                value: '35202-1234567-1',
                action: IconButton(
                  tooltip: say('Copy CNIC', 'شناختی کارڈ نقل کریں'),
                  onPressed: tapped,
                  icon: const Icon(MmIcons.copy),
                ),
              ),
              MmDetailRow(
                label: say('Property', 'جائیداد'),
                value: say(
                  'House 12, Street 4, Gulberg III, Lahore',
                  'مکان 12، گلی 4، گلبرگ III، لاہور',
                ),
              ),
              MmDetailRow.amount(
                label: say('October rent', 'اکتوبر کا کرایہ'),
                amount: const Money.fromRupees(45000),
                trailing: MmStatusBadge(
                  status: MmStatus.paid,
                  label: say('Paid', 'ادا شدہ'),
                ),
              ),
              MmDetailRow.amount(
                label: say('Advance', 'ایڈوانس'),
                amount: const Money.fromRupees(-5000),
                creditLabel: say('credit', 'جمع'),
              ),
              const Divider(),
              MmDetailRow.amount(
                label: say('Total due', 'کل واجب الادا'),
                amount: const Money.fromRupees(125000),
                emphasized: true,
              ),
            ],
          ),
        ),
      ),
    ),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );
}
