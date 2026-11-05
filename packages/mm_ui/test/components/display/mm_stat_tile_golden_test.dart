@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// Two tiles side by side (a favourable and an unfavourable trend) and a
/// tappable tile with a caption and a flat trend.
void main() {
  goldenEveryVariant(
    'mm_stat_tile',
    () => GoldenPage(
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MmSpace.s3,
              children: [
                Expanded(
                  child: MmStatTile(
                    label: say('Collected', 'وصولی'),
                    value: const MmAmount(
                      amount: Money.fromRupees(95000),
                      size: MmAmountSize.large,
                    ),
                    trend: MmTrend(
                      direction: MmTrendDirection.up,
                      label: say('Up 12%', '12% زیادہ'),
                      favourable: true,
                    ),
                  ),
                ),
                Expanded(
                  child: MmStatTile(
                    label: say('Overdue', 'بقایا'),
                    value: const MmAmount(
                      amount: Money.fromRupees(30000),
                      size: MmAmountSize.large,
                      tone: MmAmountTone.overdue,
                    ),
                    trend: MmTrend(
                      direction: MmTrendDirection.up,
                      label: say('Up 2 tenants', '2 کرایہ دار زیادہ'),
                      favourable: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          MmStatTile(
            label: say('Occupied units', 'آباد یونٹ'),
            value: Text(say('12 of 14', '14 میں سے 12')),
            caption: say('Gulberg Heights, Lahore', 'گلبرگ ہائٹس، لاہور'),
            trend: MmTrend(
              direction: MmTrendDirection.flat,
              label: say('Same as September', 'ستمبر جتنے'),
              favourable: true,
            ),
            onTap: tapped,
          ),
        ],
      ),
    ),
  );
}
