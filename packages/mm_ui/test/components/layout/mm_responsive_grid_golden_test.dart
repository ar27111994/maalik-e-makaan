@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// A dashboard tile: a muted label over a figure.
Widget _tile(BuildContext context, String label, Widget figure) => Card(
  child: Padding(
    padding: const EdgeInsets.all(MmSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: MmSpace.s1,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: context.mm.colors.inkMuted),
        ),
        figure,
      ],
    ),
  ),
);

/// Five tiles in two columns (one column at 200% text, where the column
/// width scales with the text): each row as tall as its tallest tile, the
/// last row short.
void main() {
  goldenEveryVariant(
    'mm_responsive_grid',
    () => GoldenPage((context, say) {
      final count = context.mm.amount;
      return MmResponsiveGrid(
        // Text-heavy tiles get wider columns as the text grows.
        minItemWidth: MediaQuery.textScalerOf(context).scale(140),
        children: [
          _tile(
            context,
            say('Rent due this month', 'اس مہینے کا کرایہ'),
            moneyText(context, 95000),
          ),
          _tile(context, say('Collected', 'وصول'), moneyText(context, 80000)),
          _tile(context, say('Overdue', 'لیٹ'), moneyText(context, 15000)),
          _tile(
            context,
            say('Vacant units in Gulberg', 'گلبرگ میں خالی یونٹ'),
            Text('2', style: count),
          ),
          _tile(
            context,
            say('Properties', 'جائیدادیں'),
            Text('4', style: count),
          ),
        ],
      );
    }),
  );
}
