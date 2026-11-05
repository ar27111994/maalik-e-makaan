@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'golden_page.dart';

/// A static card, a tappable card and a card grouping rows edge to edge.
void main() {
  goldenEveryVariant(
    'mm_card',
    () => GoldenPage((context, say) {
      final text = Theme.of(context).textTheme;
      final muted = text.bodyMedium!.copyWith(
        color: context.mm.colors.inkMuted,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s3,
        children: [
          MmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(say('Rent due this month', 'اس مہینے کا کرایہ')),
                const MmAmount(
                  amount: Money.fromRupees(125000),
                  size: MmAmountSize.large,
                ),
                Text(
                  say('From 4 tenants in Gulberg', 'گلبرگ کے 4 کرایہ داروں سے'),
                  style: muted,
                ),
              ],
            ),
          ),
          MmCard(
            onTap: tapped,
            child: Row(
              spacing: MmSpace.s3,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        say('Ayesha Khan', 'عائشہ خان'),
                        style: text.titleMedium,
                      ),
                      Text(
                        say(
                          'House 12, DHA Phase 5, Lahore',
                          'مکان 12، ڈی ایچ اے فیز 5، لاہور',
                        ),
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Icon(MmIcons.chevronEnd, color: context.mm.colors.inkMuted),
              ],
            ),
          ),
          MmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MmListTile(
                  title: say('Electricity', 'بجلی'),
                  leading: const Icon(MmIcons.electricity),
                  trailing: const MmAmount(amount: Money.fromRupees(8450)),
                ),
                const Divider(),
                MmListTile(
                  title: say('Gas', 'گیس'),
                  leading: const Icon(MmIcons.gas),
                  trailing: const MmAmount(amount: Money.fromRupees(2300)),
                ),
              ],
            ),
          ),
        ],
      );
    }),
  );
}
