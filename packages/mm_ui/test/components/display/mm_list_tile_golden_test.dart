@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Rows with an avatar and an amount, a selected row, a long title whose
/// badge moves under the text, and a static row whose subtitle ends with an
/// ellipsis.
void main() {
  goldenEveryVariant(
    'mm_list_tile',
    () => GoldenPage(
      (context, say) => MmCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmListTile(
              leading: MmAvatar(name: say('Ali Raza', 'علی رضا')),
              title: say('Ali Raza', 'علی رضا'),
              subtitle: say('Flat 3, Gulberg III', 'فلیٹ 3، گلبرگ'),
              trailing: const MmAmount(
                amount: Money.fromRupees(45000),
                tone: MmAmountTone.overdue,
              ),
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              leading: const MmAvatar(name: 'Ayesha Khan'),
              title: 'Ayesha Khan',
              subtitle: say('House 12, DHA Phase 5', 'مکان 12، ڈی ایچ اے'),
              trailing: MmStatusBadge(
                status: MmStatus.paid,
                label: say('Paid', 'ادا شدہ'),
              ),
              selected: true,
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              leading: const Icon(MmIcons.property),
              title: say(
                'Gulberg Heights, Block C, Main Boulevard',
                'گلبرگ ہائٹس، بلاک سی، مین بلیوارڈ',
              ),
              subtitle: say('6 units, 2 vacant', '6 یونٹ، 2 خالی'),
              trailing: MmStatusBadge(
                status: MmStatus.overdue,
                label: say('Overdue 12 days', '12 دن سے بقایا'),
              ),
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              title: say('Water bill, October', 'پانی کا بل، اکتوبر'),
              subtitle: say(
                'WASA Lahore, consumer 0412 3345 6789, paid by the tenant '
                    'with the rent',
                'واسا لاہور، صارف نمبر 0412 3345 6789، کرایہ دار نے کرایے '
                    'کے ساتھ ادا کیا',
              ),
              subtitleMaxLines: 1,
              trailing: const MmAmount(
                amount: Money.fromRupees(1250),
                size: MmAmountSize.small,
                tone: MmAmountTone.muted,
              ),
            ),
          ],
        ),
      ),
    ),
    size: const Size(360, 1000),
  );
}
