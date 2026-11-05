@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The app's destinations in the ambient language.
List<MmDestination> _destinations(Say say) => [
  MmDestination(icon: MmIcons.property, label: say('Properties', 'جائیدادیں')),
  MmDestination(icon: MmIcons.tenants, label: say('Tenants', 'کرایہ دار')),
  MmDestination(
    icon: MmIcons.receipt,
    label: say('Dues', 'واجبات'),
    badgeCount: 3,
  ),
  MmDestination(icon: MmIcons.reports, label: say('Reports', 'رپورٹس')),
];

/// A screen of properties, scrolling so large text never overflows.
Widget _properties(BuildContext context, Say say) {
  final muted = Theme.of(context).textTheme.bodyMedium!
      .copyWith(color: context.mm.colors.inkMuted);
  return ListView(
    padding: const EdgeInsets.all(MmSpace.s4),
    children: [
      Text(
        say('Properties', 'جائیدادیں'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: MmSpace.s3),
      for (final (name, place) in [
        (say('House 12', 'مکان 12'), say('Gulberg, Lahore', 'گلبرگ، لاہور')),
        (say('Shop 4', 'دکان 4'), say('Saddar, Karachi', 'صدر، کراچی')),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: MmSpace.s2),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(MmSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(place, style: muted),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// The scaffold in a window of [size] with [selected] chosen.
Widget _window(Size size, int selected, {bool fab = false}) => WindowPanel(
  size: size,
  child: Builder(
    builder: (context) {
      final say = sayIn(context);
      return MmAdaptiveScaffold(
        destinations: _destinations(say),
        selectedIndex: selected,
        onDestinationSelected: (_) {},
        floatingActionButton: fab
            ? FloatingActionButton(
                onPressed: tapped,
                tooltip: say('Add property', 'جائیداد شامل کریں'),
                child: const Icon(MmIcons.add),
              )
            : null,
        body: Builder(builder: (context) => _properties(context, say)),
      );
    },
  ),
);

/// A phone with the bottom bar, a tablet with the labelled rail, and a
/// desktop window with the extended rail.
void main() {
  goldenEveryVariant(
    'mm_adaptive_scaffold',
    size: const Size(1000, 720),
    () => GoldenPage(
      width: 968,
      (context, say) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: MmSpace.s4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: MmSpace.s4,
            children: [
              _window(const Size(320, 420), 0, fab: true),
              _window(const Size(632, 420), 2),
            ],
          ),
          // Laid out 968 dp wide, but in the large size class.
          WindowPanel(
            size: const Size(968, 240),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: const Size(1280, 240)),
              child: Builder(
                builder: (context) => MmAdaptiveScaffold(
                  destinations: _destinations(say),
                  selectedIndex: 1,
                  onDestinationSelected: (_) {},
                  body: Builder(
                    builder: (context) => _properties(context, say),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
