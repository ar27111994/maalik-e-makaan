@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The tenant's page the sheet opens over.
class _Page extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final say = sayIn(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Text(
            say('Ayesha Khan', 'عائشہ خان'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

/// Opens the payment sheet over the page.
void _open(BuildContext context) {
  final say = sayIn(context);
  unawaited(
    showMmSheet<void>(
      context,
      title: say('Record payment', 'ادائیگی درج کریں'),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s2,
        children: [
          Text(
            say(
              'Ayesha Khan · Flat 3, Gulberg III, Lahore',
              'عائشہ خان · فلیٹ 3، گلبرگ III، لاہور',
            ),
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: context.mm.colors.inkMuted),
          ),
          Text(
            MmFormats.moneyOf(context).format(const Money.fromRupees(45000)),
            style: context.mm.amountLarge,
          ),
          ListTile(
            leading: const Icon(MmIcons.cash),
            title: Text(say('Cash', 'نقد')),
            onTap: tapped,
          ),
          ListTile(
            leading: const Icon(MmIcons.bank),
            title: Text(say('Bank transfer', 'بینک ٹرانسفر')),
            onTap: tapped,
          ),
          FilledButton(
            onPressed: tapped,
            child: Text(say('Record payment', 'ادائیگی درج کریں')),
          ),
        ],
      ),
    ),
  );
}

/// The payment sheet open over a tenant's page, scrim included.
void main() {
  overlayGoldenEveryVariant('mm_sheet', _open, behind: () => const _Page());
}
