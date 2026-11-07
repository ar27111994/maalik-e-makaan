@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// A static card bounded by the rule, a tappable card focused from the
/// keyboard (its border turned to the focus ring), a tappable card at rest
/// bounded by the outline colour, and a card grouping rows edge to edge
/// whose amounts keep to the end edge.
void main() {
  focusedGoldenEveryVariant(
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
            onTap: tapped,
            child: Row(
              spacing: MmSpace.s3,
              children: [
                Expanded(
                  child: Text(
                    say('Gulberg Heights, 6 units', 'گلبرگ ہائٹس، 6 یونٹ'),
                    style: text.titleMedium,
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
    focused: textIn('Ayesha Khan', 'عائشہ خان'),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );
}
