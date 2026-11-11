@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// Rows with an avatar and an amount (the first focused from the keyboard),
/// a selected row, a long title whose badge moves under the text, a bill
/// whose consumer number keeps its order in Urdu, and a static row whose
/// subtitle ends with an ellipsis.
void main() {
  focusedGoldenEveryVariant(
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
              // The overdue tone emphasises what the words say.
              subtitle: say('Flat 3, overdue 12 days', 'فلیٹ 3، 12 دن لیٹ'),
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
                label: say('Overdue 12 days', '12 دن لیٹ'),
              ),
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              leading: const Icon(MmIcons.water),
              title: say('Water bill, October', 'پانی کا بل، اکتوبر'),
              // The app keeps an identifier left to right inside a sentence.
              subtitle: say(
                'Consumer ${MmSemantics.leftToRight('0412 3345 6789')}',
                'صارف نمبر ${MmSemantics.leftToRight('0412 3345 6789')}',
              ),
              trailing: const MmAmount(
                amount: Money.fromRupees(1250),
                size: MmAmountSize.small,
                tone: MmAmountTone.muted,
              ),
            ),
            const Divider(),
            MmListTile(
              leading: const Icon(MmIcons.gas),
              title: say('Gas bill, October', 'گیس کا بل، اکتوبر'),
              subtitle: say(
                'Paid by the tenant with the rent every month since March',
                'مارچ سے ہر مہینے کرایہ دار کرایے کے ساتھ ادا کرتا ہے',
              ),
              subtitleMaxLines: 1,
              trailing: const MmAmount(
                amount: Money.fromRupees(2300),
                size: MmAmountSize.small,
                tone: MmAmountTone.muted,
              ),
            ),
          ],
        ),
      ),
    ),
    focused: textIn('Ali Raza', 'علی رضا'),
    sizes: {MmVariant.largeText: const Size(360, 1200)},
  );

  // Rows that open something: a chevron stays beside the title however it
  // wraps; a member's role and email run as long as they need; words from
  // the app's localisations keep the UI's direction.
  goldenEveryVariant(
    'mm_list_tile_chevron',
    () => GoldenPage(
      (context, say) => MmCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MmListTile(
              leading: const Icon(MmIcons.calendar),
              title: say(
                'Police registration for Ali Raza, Flat 3, Gulberg Heights',
                'علی رضا، فلیٹ 3، گلبرگ ہائٹس کی پولیس رجسٹریشن',
              ),
              subtitle: say('Due 14 Nov', '14 نومبر تک'),
              trailing: MmStatusBadge(
                status: MmStatus.dueSoon,
                label: say('In 6 days', '6 دن میں'),
              ),
              chevron: true,
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              leading: const MmAvatar(name: 'Kamran Ahmed'),
              title: 'Kamran Ahmed',
              // The app gives an email address a place to break after its
              // "@".
              subtitle: say(
                'Manager · kamran.ahmed@\u200Bexample.com',
                'منیجر · kamran.ahmed@\u200Bexample.com',
              ),
              subtitleMaxLines: null,
              chevron: true,
              onTap: tapped,
            ),
            const Divider(),
            MmListTile(
              leading: const Icon(MmIcons.receiptText),
              title: say('PDF receipts', 'PDF رسیدیں'),
              subtitle: say('Sent on WhatsApp', 'WhatsApp پر بھیجی گئیں'),
              userData: false,
              chevron: true,
              onTap: tapped,
            ),
          ],
        ),
      ),
    ),
    sizes: const {MmVariant.largeText: Size(360, 1100)},
  );
}
