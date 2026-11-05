@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'testing.dart';

/// A page of stock widgets in the harness: the golden shows the page colour
/// painted under the subject in every mode, ink drawn on the page (a
/// selected tile), and the surface each variant is pumped on.
Widget _page() => GoldenPage((context, say) {
  final text = Theme.of(context).textTheme;
  final size = MediaQuery.sizeOf(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: MmSpace.s3,
    children: [
      Text(say('Gulberg Heights', 'گلبرگ ہائٹس'), style: text.titleLarge),
      Text(
        say('Rent is due on the 5th.', 'کرایہ 5 تاریخ کو واجب ہے۔'),
        style: text.bodySmall!.copyWith(color: context.mm.colors.inkMuted),
      ),
      ListTile(
        selected: true,
        selectedTileColor: context.mm.colors.primaryContainer,
        title: Text(say('Ali Raza', 'علی رضا')),
        subtitle: Text(say('Flat 2B', 'فلیٹ 2 بی')),
        onTap: tapped,
      ),
      Wrap(
        spacing: MmSpace.s3,
        runSpacing: MmSpace.s3,
        children: [
          FilledButton(
            onPressed: tapped,
            child: Text(say('Record payment', 'ادائیگی درج کریں')),
          ),
          OutlinedButton(
            onPressed: tapped,
            child: Text(say('Remind', 'یاد دلائیں')),
          ),
        ],
      ),
      Text(
        say(
          'Surface ${size.width.round()} × ${size.height.round()}',
          'سطح ${size.width.round()} × ${size.height.round()}',
        ),
        style: text.labelMedium,
      ),
    ],
  );
});

/// A tenants page with a confirmation dialog pushed on the root navigator.
Widget _tenants() => Builder(
  builder: (context) {
    final say = sayIn(context);
    return Scaffold(
      appBar: AppBar(title: Text(say('Tenants', 'کرایہ دار'))),
      body: ListView(
        children: [
          for (final (name, place) in [
            (say('Ali Raza', 'علی رضا'), say('Flat 2B', 'فلیٹ 2 بی')),
            (say('Ayesha Khan', 'عائشہ خان'), say('Shop 4', 'دکان 4')),
          ])
            ListTile(title: Text(name), subtitle: Text(place)),
        ],
      ),
    );
  },
);

void _confirm(BuildContext context) {
  final say = sayIn(context);
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(say('Remove Ali Raza?', 'علی رضا کو ہٹائیں؟')),
        content: Text(
          say(
            'Their payment history stays in the ledger.',
            'ان کی ادائیگیوں کا ریکارڈ کھاتے میں رہے گا۔',
          ),
        ),
        actions: [
          TextButton(onPressed: tapped, child: Text(say('Cancel', 'منسوخ'))),
          FilledButton(onPressed: tapped, child: Text(say('Remove', 'ہٹائیں'))),
        ],
      ),
    ),
  );
}

void main() {
  goldenEveryVariant(
    'harness_page',
    _page,
    sizes: const {MmVariant.largeText: Size(360, 900)},
  );
  overlayGoldenEveryVariant('harness_dialog', _confirm, behind: _tenants);
}
