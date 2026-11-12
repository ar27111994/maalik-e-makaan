@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

/// The app's destinations in the ambient language.
List<MmDestination> _destinations(Say say) => [
  MmDestination(icon: MmIcons.property, label: say('Properties', 'جائیدادیں')),
  MmDestination(icon: MmIcons.tenants, label: say('Tenants', 'کرایہ دار')),
  MmDestination(
    icon: MmIcons.receipt,
    label: say('Dues', 'چارجز'),
    badgeCount: 3,
  ),
  MmDestination(icon: MmIcons.reports, label: say('Reports', 'رپورٹس')),
];

/// A screen titled [title] listing [rows] (a name and a place), scrolling
/// so large text never overflows.
Widget _list(BuildContext context, String title, List<(String, String)> rows) {
  final muted = Theme.of(context).textTheme.bodyMedium!
      .copyWith(color: context.mm.colors.inkMuted);
  return ListView(
    padding: const EdgeInsets.all(MmSpace.s4),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: MmSpace.s3),
      for (final (name, place) in rows)
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

/// The properties screen.
Widget _properties(BuildContext context, Say say) =>
    _list(context, say('Properties', 'جائیدادیں'), [
      (say('House 12', 'مکان 12'), say('Gulberg, Lahore', 'گلبرگ، لاہور')),
      (say('Shop 4', 'دکان 4'), say('Saddar, Karachi', 'صدر، کراچی')),
    ]);

/// The tenants screen.
Widget _tenants(BuildContext context, Say say) =>
    _list(context, say('Tenants', 'کرایہ دار'), [
      (say('Ayesha Khan', 'عائشہ خان'), say('House 12', 'مکان 12')),
      (say('Ali Raza', 'علی رضا'), say('Flat 3', 'فلیٹ 3')),
    ]);

/// The dues screen as the app builds it: an `MmPage` with its action bar.
Widget _dues(BuildContext context, Say say) => MmPage(
  title: say('Dues', 'چارجز'),
  body: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MmSpace.s2,
    children: [
      Text(
        say('Ayesha Khan, House 12', 'عائشہ خان، مکان 12'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      moneyText(context, 45000, large: true),
    ],
  ),
  bottomBar: MmActionBar(
    primary: FilledButton(
      onPressed: tapped,
      child: Text(say('Record payment', 'ادائیگی درج کریں')),
    ),
  ),
);

/// The scaffold with [selected] chosen, showing that destination's screen.
Widget _scaffold(Say say, int selected, {bool fab = false}) =>
    MmAdaptiveScaffold(
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
      body: Builder(
        builder: (context) => switch (selected) {
          0 => _properties(context, say),
          1 => _tenants(context, say),
          _ => _dues(context, say),
        },
      ),
    );

/// The scaffold in a window of [size] with [selected] chosen.
Widget _window(Size size, int selected, {bool fab = false}) => WindowPanel(
  size: size,
  child: Builder(
    builder: (context) => _scaffold(sayIn(context), selected, fab: fab),
  ),
);

/// A phone with the bottom bar (the Tenants destination focused from the
/// keyboard), a tablet with the labelled rail around the dues page and its
/// action bar, and a desktop window with the extended rail.
void main() {
  testEveryVariant('mm_adaptive_scaffold golden', (tester, variant) async {
    useKeyboardHighlights();
    await pumpThemed(
      tester,
      GoldenPage(
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
                child: _scaffold(say, 1),
              ),
            ),
          ],
        ),
      ),
      variant: variant,
      size: const Size(1000, 720),
    );
    // The phone's Tenants destination, the first in the tree.
    Focus.of(tester.element(find.byIcon(MmIcons.tenants).first)).requestFocus();
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectGolden('mm_adaptive_scaffold', variant);
  });

  // No variant combines Urdu with large text: the Urdu labels of the bar
  // and a long Urdu title are the tallest the frame holds.
  testWidgets('mm_adaptive_scaffold Urdu at 200% golden', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedApp(
        Builder(
          builder: (context) {
            final say = sayIn(context);
            return MmAdaptiveScaffold(
              destinations: _destinations(say),
              selectedIndex: 2,
              onDestinationSelected: (_) {},
              body: MmPage(
                title: 'عائشہ خان، مکان 12، گلبرگ',
                actions: const [
                  IconButton(
                    onPressed: tapped,
                    tooltip: 'ایڈٹ کریں',
                    icon: Icon(MmIcons.edit),
                  ),
                ],
                body: Builder(builder: (context) => moneyText(context, 45000)),
              ),
            );
          },
        ),
        variant: MmVariant.largeText,
        locale: const Locale('ur'),
      ),
    );
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/mm_adaptive_scaffold_urduLargeText.png'),
    );
  });
}
