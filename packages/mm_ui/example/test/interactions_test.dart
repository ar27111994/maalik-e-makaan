import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui_gallery/src/settings.dart';

import 'support/gallery_harness.dart';

/// What testers do in the gallery: change the display settings, move
/// between pages, and open its overlays.
void main() {
  group('GallerySettings.fromQuery', () {
    test('reads every setting from the address', () {
      expect(
        GallerySettings.fromQuery(const {
          'theme': 'dark',
          'contrast': 'high',
          'lang': 'ur',
          'text': '150',
          'grouping': 'western',
        }),
        const GallerySettings(
          brightness: Brightness.dark,
          highContrast: true,
          locale: Locale('ur'),
          textScale: 1.5,
          grouping: DigitGrouping.western,
        ),
      );
    });

    test('keeps the defaults for missing or unknown values', () {
      expect(
        GallerySettings.fromQuery(const {'theme': 'sepia', 'text': '175'}),
        const GallerySettings(),
      );
      expect(GalleryFamily.named('charts'), GalleryFamily.charts);
      expect(GalleryFamily.named('colours'), isNull);
    });
  });

  testWidgets('the display settings change the whole gallery', (tester) async {
    await pumpGallery(tester, family: GalleryFamily.display);
    expect(moneyFormatOf(tester).grouping, DigitGrouping.southAsian);

    await tester.tap(find.byTooltip('Display settings'));
    await settle(tester);
    expect(find.text('Display settings'), findsWidgets);
    await expectAccessible(tester);

    await tester.tap(find.text('Dark'));
    await settle(tester);
    expect(
      Theme.of(tester.element(find.byType(MmPage))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('High contrast'));
    await settle(tester);
    expect(
      Theme.of(tester.element(find.byType(MmPage)))
          .extension<MmSemantics>()!
          .highContrast,
      isTrue,
    );

    await tester.tap(find.text('Lakh and crore grouping'));
    await settle(tester);
    expect(moneyFormatOf(tester).grouping, DigitGrouping.western);

    await tester.tap(find.text('150%'));
    await settle(tester);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(MmPage))).scale(10),
      15,
    );

    await tester.tap(find.text('اردو'));
    await settle(tester);
    expect(
      Directionality.of(tester.element(find.byType(MmPage))),
      TextDirection.rtl,
    );
    // A new language closes the sheet: the gallery behind it starts afresh
    // in that language.
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.widgetWithText(MmPage, 'نمائش'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });

  testWidgets('a phone keeps four families in its bar and the rest under '
      'More', (tester) async {
    await pumpGallery(tester);
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    expect(tester.widget<NavigationBar>(bar).destinations, hasLength(5));

    await tester.tap(find.text('More'));
    await settle(tester);
    expect(find.text('More components'), findsOneWidget);
    await expectAccessible(tester);

    await tester.tap(find.text('Charts'));
    await settle(tester);
    expect(find.widgetWithText(MmPage, 'Charts'), findsOneWidget);
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 4);

    await tester.tap(find.byTooltip('More components'));
    await settle(tester);
    expect(find.text('More components'), findsOneWidget);

    await tester.tap(find.text('Inputs'));
    await settle(tester);
    expect(find.widgetWithText(MmPage, 'Inputs'), findsOneWidget);
    expect(find.byTooltip('More components'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a desktop window shows every family in the rail', (
    tester,
  ) async {
    await pumpGallery(tester, size: desktop);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(GalleryFamily.values.length));
    expect(rail.extended, isTrue);

    await tester.tap(find.text('Records'));
    await settle(tester);
    expect(find.widgetWithText(MmPage, 'Records'), findsOneWidget);
    expect(find.byTooltip('More components'), findsNothing);
  });

  group('the feedback page opens its overlays', () {
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await settle(tester);
    }

    testWidgets('a destructive confirmation, cancelled', (tester) async {
      await pumpGallery(tester, family: GalleryFamily.feedback);
      final remove = find.widgetWithText(MmButton, 'Remove tenant');
      await scrollTo(tester, remove);
      await tester.tap(remove);
      await settle(tester);
      expect(find.text('Remove Ali Raza?'), findsOneWidget);
      await expectAccessible(tester);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Answer: cancelled.'), findsOneWidget);
    });

    testWidgets('a typed confirmation', (tester) async {
      await pumpGallery(tester, family: GalleryFamily.feedback);
      final delete = find.widgetWithText(MmButton, 'Delete property');
      await scrollTo(tester, delete);
      await tester.tap(delete);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Raza Manzil');
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Delete property'),
        ),
      );
      await settle(tester);
      expect(find.text('Answer: confirmed.'), findsOneWidget);
    });

    testWidgets('a snack bar with an action', (tester) async {
      await pumpGallery(tester, family: GalleryFamily.feedback);
      final undo = find.widgetWithText(MmButton, 'With undo');
      await scrollTo(tester, undo);
      await tester.tap(undo);
      await settle(tester);
      expect(find.text('Payment deleted'), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('a sheet', (tester) async {
      await pumpGallery(tester, family: GalleryFamily.feedback);
      final dues = find.widgetWithText(MmButton, 'Show dues');
      await scrollTo(tester, dues);
      await tester.tap(dues);
      await settle(tester);
      expect(find.text('October dues'), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('a dismissed banner comes back', (tester) async {
      await pumpGallery(tester, family: GalleryFamily.feedback);
      await tester.tap(find.byTooltip('Dismiss'));
      await settle(tester);
      expect(find.text('Lease ending'), findsNothing);
      await tester.tap(find.text('Show the warning again'));
      await settle(tester);
      expect(find.text('Lease ending'), findsOneWidget);
    });
  });

  testWidgets('the layout page opens a tenant page with an action bar', (
    tester,
  ) async {
    await pumpGallery(tester, family: GalleryFamily.layout);
    await tester.tap(find.text('Open tenant page'));
    await settle(tester);
    expect(
      find.widgetWithText(MmPage, 'Ayesha Khan, House 12, DHA Phase 5'),
      findsOneWidget,
    );
    expect(find.byType(MmActionBar), findsWidgets);
    // The phone number in the national format MmPhoneField writes.
    expect(find.textContaining('0300 5550192'), findsOneWidget);
    expect(find.textContaining('0300-5550192'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);

    await tester.pageBack();
    await settle(tester);
    expect(find.widgetWithText(MmPage, 'Layout'), findsOneWidget);
  });

  testWidgets('the list and detail specimen opens and closes a tenant', (
    tester,
  ) async {
    await pumpGallery(tester, family: GalleryFamily.layout);
    final bilal = find.descendant(
      of: find.byType(MmListDetail),
      matching: find.text('Bilal Ahmed'),
    );
    await tester.ensureVisible(bilal);
    await settle(tester);
    await tester.tap(bilal);
    await settle(tester);
    expect(find.text('Shop 7, Tariq Road, Karachi'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Back to tenants'));
    await settle(tester);
    await tester.tap(find.byTooltip('Back to tenants'));
    await settle(tester);
    expect(find.text('Shop 7, Tariq Road, Karachi'), findsNothing);
  });
}
