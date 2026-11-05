@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A tenant's page: a back button, the title, an action, the scrolling
/// content in the reading column and the action bar pinned at the bottom.
void main() {
  goldenEveryVariant(
    'mm_page',
    () => GoldenPage((context, say) {
      final text = Theme.of(context).textTheme;
      final muted = text.bodyMedium!.copyWith(
        color: context.mm.colors.inkMuted,
      );
      return SizedBox(
        height: 600,
        child: MmPage(
          leading: const BackButton(),
          title: say('Ayesha Khan', 'عائشہ خان'),
          actions: [
            IconButton(
              onPressed: tapped,
              tooltip: say('Edit tenant', 'کرایہ دار میں ترمیم کریں'),
              icon: const Icon(MmIcons.edit),
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MmSpace.s3,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(MmSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(say('Rent due', 'واجب الادا کرایہ'), style: muted),
                      moneyText(context, 45000, large: true),
                      Text(
                        say(
                          'House 12, Gulberg, Lahore',
                          'مکان 12، گلبرگ، لاہور',
                        ),
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                say(
                  'October rent was due on the 5th.',
                  'اکتوبر کا کرایہ 5 تاریخ کو واجب الادا تھا۔',
                ),
                style: text.bodyLarge,
              ),
            ],
          ),
          bottomBar: MmActionBar(
            primary: FilledButton(
              onPressed: tapped,
              child: Text(say('Record payment', 'ادائیگی درج کریں')),
            ),
          ),
        ),
      );
    }),
  );
}
