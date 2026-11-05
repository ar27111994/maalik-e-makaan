@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// Every status with its default icon, one with its own icon, and a long
/// label that wraps in a narrow space.
void main() {
  goldenEveryVariant(
    'mm_status_badge',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          Wrap(
            spacing: MmSpace.s2,
            runSpacing: MmSpace.s2,
            children: [
              MmStatusBadge(
                status: MmStatus.paid,
                label: say('Paid', 'ادا شدہ'),
              ),
              MmStatusBadge(
                status: MmStatus.overdue,
                label: say('Overdue 12 days', '12 دن سے بقایا'),
              ),
              MmStatusBadge(
                status: MmStatus.dueSoon,
                label: say('Due in 3 days', '3 دن میں واجب الادا'),
              ),
              MmStatusBadge(
                status: MmStatus.credit,
                label: say('Advance', 'ایڈوانس'),
              ),
              MmStatusBadge(
                status: MmStatus.neutral,
                label: say('Vacant', 'خالی'),
              ),
              MmStatusBadge(
                status: MmStatus.paid,
                label: say('Receipt sent', 'رسید بھیج دی'),
                icon: MmIcons.receipt,
              ),
            ],
          ),
          SizedBox(
            width: 180,
            child: MmStatusBadge(
              status: MmStatus.overdue,
              label: say(
                'Overdue since 5 October, reminder sent twice',
                '5 اکتوبر سے بقایا، دو بار یاد دہانی بھیجی گئی',
              ),
            ),
          ),
        ],
      ),
    ),
    size: const Size(360, 1000),
  );
}
