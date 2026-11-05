@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// The tenants list, with Ayesha Khan selected.
Widget _tenants(Say say) => ListView(
  children: [
    for (final (name, unit, selected) in [
      (
        say('Ali Raza', 'علی رضا'),
        say('Flat 3, Gulberg', 'فلیٹ 3، گلبرگ'),
        false,
      ),
      (
        say('Ayesha Khan', 'عائشہ خان'),
        say('House 12, DHA Phase 5', 'مکان 12، ڈی ایچ اے فیز 5'),
        true,
      ),
      (
        say('Bilal Ahmed', 'بلال احمد'),
        say('Shop 4, Saddar', 'دکان 4، صدر'),
        false,
      ),
    ])
      ListTile(
        selected: selected,
        onTap: tapped,
        title: Text(name),
        subtitle: Text(unit),
      ),
  ],
);

/// Ayesha Khan's details.
Widget _ayesha(BuildContext context, Say say) {
  final text = Theme.of(context).textTheme;
  return ListView(
    padding: const EdgeInsets.all(MmSpace.s4),
    children: [
      Text(say('Ayesha Khan', 'عائشہ خان'), style: text.titleLarge),
      Text(
        say('House 12, DHA Phase 5, Lahore', 'مکان 12، ڈی ایچ اے فیز 5، لاہور'),
        style: text.bodyMedium!.copyWith(color: context.mm.colors.inkMuted),
      ),
      const SizedBox(height: MmSpace.s3),
      Text(say('Rent due', 'واجب الادا کرایہ'), style: text.bodyMedium),
      moneyText(context, 45000, large: true),
    ],
  );
}

/// The layout in a window of [size], showing the detail when [selected].
Widget _window(Size size, {required bool selected}) => WindowPanel(
  size: size,
  child: Builder(
    builder: (context) {
      final say = sayIn(context);
      return MmListDetail(
        list: _tenants(say),
        detail: selected
            ? Builder(builder: (context) => _ayesha(context, say))
            : null,
        emptyDetail: Builder(
          builder: (context) => Center(
            child: Padding(
              padding: const EdgeInsets.all(MmSpace.s4),
              child: Text(
                say(
                  'Choose a tenant to see their ledger.',
                  'کھاتہ دیکھنے کے لیے کرایہ دار منتخب کریں۔',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(color: context.mm.colors.inkMuted),
              ),
            ),
          ),
        ),
      );
    },
  ),
);

/// On a phone the list, or the detail over it; on a wide window the list
/// beside the detail, or beside the empty detail.
void main() {
  goldenEveryVariant(
    'mm_list_detail',
    size: const Size(1000, 940),
    () => GoldenPage(
      width: 968,
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: MmSpace.s4,
        children: [
          Row(
            spacing: MmSpace.s4,
            children: [
              _window(const Size(320, 280), selected: false),
              _window(const Size(320, 280), selected: true),
            ],
          ),
          _window(const Size(968, 280), selected: true),
          _window(const Size(968, 280), selected: false),
        ],
      ),
    ),
  );
}
