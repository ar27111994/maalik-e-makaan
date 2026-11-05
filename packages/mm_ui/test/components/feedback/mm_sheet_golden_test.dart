@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A small screen of its own, with a navigator the sheet opens in, so the
/// golden shows the sheet over its page.
class _Screen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 600 * scale,
      child: ClipRect(
        child: Navigator(
          onGenerateRoute: (settings) =>
              MaterialPageRoute<void>(builder: (context) => const _Page()),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: context.mm.colors.bg,
      child: OverlayHost(
        open: (context) => unawaited(
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
                  style: text.bodyMedium!.copyWith(
                    color: context.mm.colors.inkMuted,
                  ),
                ),
                Text('Rs\u00A045,000', style: context.mm.amountLarge),
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
        ),
        child: Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: Text(
            say('Ayesha Khan', 'عائشہ خان'),
            style: text.headlineMedium,
          ),
        ),
      ),
    );
  }
}

/// The payment sheet open over a tenant's page.
void main() {
  goldenEveryVariant(
    'mm_sheet',
    () => FeedbackPage((context, say) => const _Screen()),
    size: const Size(360, 1300),
  );
}
