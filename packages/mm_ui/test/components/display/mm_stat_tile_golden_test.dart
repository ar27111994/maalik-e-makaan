@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The screen's one large figure, a tappable tile focused from the keyboard
/// with an amount in its caption and a favourable trend; then a card
/// holding two count tiles (a neutral and an unfavourable trend), side by
/// side at 100% text and one to a row at large text, as the layout should
/// put them.
void main() {
  focusedGoldenEveryVariant(
    'mm_stat_tile',
    () => GoldenPage((context, say) {
      final large = MediaQuery.textScalerOf(context).scale(1) > 1;
      const due = MmAmount(
        amount: Money.fromRupees(125000),
        size: MmAmountSize.small,
        tone: MmAmountTone.muted,
      );
      final counts = [
        Expanded(
          flex: large ? 0 : 1,
          child: MmStatTile(
            label: say('Occupied units', 'آباد یونٹ'),
            value: const Text('12'),
            caption: Text(say('of 14 units', '14 یونٹ میں سے')),
            trend: MmTrend(
              direction: MmTrendDirection.flat,
              label: say('Same as September', 'ستمبر جتنے'),
            ),
          ),
        ),
        Expanded(
          flex: large ? 0 : 1,
          child: MmStatTile(
            label: say('Overdue tenants', 'بقایا دار کرایہ دار'),
            value: const Text('3'),
            trend: MmTrend(
              direction: MmTrendDirection.up,
              label: say('Up 1 from September', 'ستمبر سے 1 زیادہ'),
              favourable: false,
            ),
          ),
        ),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          MmStatTile(
            label: say('Collected in October', 'اکتوبر کی وصولی'),
            value: const MmAmount(
              amount: Money.fromRupees(95000),
              size: MmAmountSize.large,
            ),
            caption: Wrap(
              // A word space, which grows with the text.
              spacing: MediaQuery.textScalerOf(context).scale(MmSpace.s1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: say('en', 'ur') == 'en'
                  ? [const Text('of'), due, const Text('due')]
                  : [due, const Text('میں سے')],
            ),
            trend: MmTrend(
              direction: MmTrendDirection.up,
              label: say('Up 12% from September', 'ستمبر سے 12% زیادہ'),
              favourable: true,
            ),
            onTap: tapped,
          ),
          MmCard(
            padding: EdgeInsets.zero,
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      counts.first.child,
                      const Divider(),
                      counts.last.child,
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        counts.first,
                        const VerticalDivider(),
                        counts.last,
                      ],
                    ),
                  ),
          ),
        ],
      );
    }),
    focused: textIn('Collected in October', 'اکتوبر کی وصولی'),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );
}
