@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// A receipt's rows: a name typed in English, a CNIC, a long address that
/// moves under its label, an amount with a badge, and an emphasized total.
void main() {
  goldenEveryVariant(
    'mm_detail_row',
    () => GoldenPage(
      (context, say) => MmCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmDetailRow(label: say('Tenant', 'کرایہ دار'), value: 'Ali Raza'),
            MmDetailRow(
              label: say('CNIC', 'شناختی کارڈ'),
              value: '35202-1234567-1',
            ),
            MmDetailRow(
              label: say('Property', 'جائیداد'),
              value: say(
                'House 12, Street 4, Gulberg III, Lahore',
                'مکان 12، گلی 4، گلبرگ III، لاہور',
              ),
            ),
            MmDetailRow(
              label: say('October rent', 'اکتوبر کا کرایہ'),
              value: say('Rs 45,000', '45,000 روپے'),
              trailing: MmStatusBadge(
                status: MmStatus.paid,
                label: say('Paid', 'ادا شدہ'),
              ),
            ),
            const Divider(),
            MmDetailRow(
              label: say('Total due', 'کل واجب الادا'),
              value: say('Rs 1,25,000', '1,25,000 روپے'),
              emphasized: true,
              userData: false,
            ),
          ],
        ),
      ),
    ),
  );
}
