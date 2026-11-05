@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Sparklines beside the words that state their trend: rising, falling,
/// flat, a single month and a larger one, with the row's words beside it.
Widget sparklineGolden() => GoldenPage((context, say) {
  final mm = context.mm;
  final text = Theme.of(context).textTheme;
  Widget row(String label, String trend, MmSparkline line) => Row(
    spacing: MmSpace.s3,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelLarge),
            Text(
              trend,
              style: text.bodyMedium!.copyWith(color: mm.colors.inkMuted),
            ),
          ],
        ),
      ),
      line,
    ],
  );
  return Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(MmSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          row(
            say('Collected', 'وصولی'),
            say('Up 14% since June', 'جون سے 14% زیادہ'),
            const MmSparkline(values: [110, 125, 125, 95, 125, 145]),
          ),
          row(
            say('Overdue', 'بقایا'),
            say('Down from Rs 45,000', '45,000 روپے سے کم'),
            const MmSparkline(values: [45, 40, 42, 30, 20, 15]),
          ),
          row(
            say('Units let', 'کرائے پر یونٹ'),
            say('Same since June', 'جون سے یکساں'),
            const MmSparkline(values: [8, 8, 8, 8, 8, 8]),
          ),
          row(
            say('Gulberg flat', 'گلبرگ فلیٹ'),
            say('First month', 'پہلا مہینہ'),
            const MmSparkline(values: [45]),
          ),
          row(
            say('Electricity bills', 'بجلی کے بل'),
            say('Highest in July', 'جولائی میں سب سے زیادہ'),
            const MmSparkline(
              values: [18, 26, 24, 15, 9, 7],
              width: 120,
              height: 40,
            ),
          ),
        ],
      ),
    ),
  );
});

void main() {
  goldenEveryVariant('mm_sparkline', sparklineGolden);
}
