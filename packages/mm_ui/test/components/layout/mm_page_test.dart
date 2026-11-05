import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const ValueKey<String> _bodyKey = ValueKey('body');
const ValueKey<String> _barKey = ValueKey('bar');

Widget _body({double height = 200}) =>
    SizedBox(key: _bodyKey, height: height, child: const Text('Rent due'));

/// A home screen with a button that opens [page] (as a full-screen dialog
/// when [dialog]).
Widget _opener(Widget page, {bool dialog = false}) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: dialog,
            builder: (_) => page,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

void main() {
  group('MmPage', () {
    testWidgets('shows its title in the app bar, read as a heading', (
      tester,
    ) async {
      await pumpScreen(tester, MmPage(title: 'Ayesha Khan', body: _body()));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ayesha Khan'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Ayesha Khan')),
        isSemantics(label: 'Ayesha Khan', isHeader: true),
      );
      // Nothing to go back to: no back button.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('puts actions at the end of the app bar, 4 dp in', (
      tester,
    ) async {
      var edits = 0;
      final page = MmPage(
        title: 'Ayesha Khan',
        actions: [
          IconButton(
            onPressed: () => edits++,
            tooltip: 'Edit tenant',
            icon: const Icon(MmIcons.edit),
          ),
        ],
        body: _body(),
      );
      await pumpScreen(tester, page);
      final action = tester.getRect(find.byType(IconButton));
      expect(action.right, 360 - MmSpace.s1);
      await tester.tap(find.byType(IconButton));
      expect(edits, 1);

      await pumpScreen(tester, page, variant: MmVariant.urdu);
      expect(tester.getRect(find.byType(IconButton)).left, MmSpace.s1);
    });

    testWidgets('a leading widget replaces the back button', (tester) async {
      await pumpScreen(
        tester,
        _opener(
          MmPage(
            title: 'Receipts',
            leading: const IconButton(
              onPressed: tapped,
              tooltip: 'Menu',
              icon: Icon(MmIcons.menu),
            ),
            body: _body(),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(MmIcons.menu), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('goes back with the design system back arrow', (tester) async {
      await pumpScreen(
        tester,
        _opener(MmPage(title: 'Ayesha Khan', body: _body())),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(MmIcons.back), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(BackButton)),
        isSemantics(tooltip: 'Back', isButton: true),
      );
      expect(tester.getRect(find.byType(BackButton)).left, lessThan(180));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('the back arrow sits on the right and points right in Urdu', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _opener(MmPage(title: 'عائشہ خان', body: _body())),
        variant: MmVariant.urdu,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final arrow = find.byIcon(MmIcons.back);
      expect(tester.getRect(arrow).left, greaterThan(180));
      expect(tester.widget<Icon>(arrow).icon!.matchTextDirection, isTrue);
      expect(Directionality.of(tester.element(arrow)), TextDirection.rtl);
    });

    testWidgets('a full-screen dialog page closes with the close icon', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _opener(MmPage(title: 'New tenant', body: _body()), dialog: true),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(MmIcons.close), findsOneWidget);
    });

    testWidgets("keeps an app's own back and close icons", (tester) async {
      await pumpScreen(
        tester,
        ActionIconTheme(
          data: ActionIconThemeData(
            backButtonIconBuilder: (_) => const Icon(MmIcons.chevronStart),
          ),
          child: MmPage(
            title: 'Ayesha Khan',
            leading: const BackButton(),
            body: _body(),
          ),
        ),
      );
      expect(find.byIcon(MmIcons.chevronStart), findsOneWidget);
      expect(find.byIcon(MmIcons.back), findsNothing);
    });

    testWidgets('pads the body 16 dp on a phone', (tester) async {
      await pumpScreen(tester, MmPage(title: 'Dues', body: _body()));
      final body = tester.getRect(find.byKey(_bodyKey));
      final bar = tester.getRect(find.byType(AppBar));
      expect(body.left, MmSpace.s4);
      expect(body.width, 360 - 2 * MmSpace.s4);
      expect(body.top, bar.bottom + MmSpace.s4);
    });

    testWidgets('centres the body in a 720 dp column on wide windows', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MmPage(title: 'Dues', body: _body()),
        size: const Size(1200, 800),
      );
      final body = tester.getRect(find.byKey(_bodyKey));
      expect(body.width, MmSize.contentMax);
      expect(body.center.dx, 600);

      await pumpScreen(
        tester,
        MmPage(title: 'Dues', scrollable: false, body: _body()),
        size: const Size(1200, 800),
      );
      final filled = tester.getRect(find.byKey(_bodyKey));
      expect(filled.width, MmSize.contentMax);
      expect(filled.center.dx, 600);
    });

    testWidgets('pads from the start edge in Urdu too', (tester) async {
      await pumpScreen(
        tester,
        MmPage(title: 'واجبات', body: _body()),
        variant: MmVariant.urdu,
      );
      final body = tester.getRect(find.byKey(_bodyKey));
      expect(body.right, 360 - MmSpace.s4);
      expect(body.left, MmSpace.s4);
    });

    testWidgets('scrolls by default', (tester) async {
      await pumpScreen(
        tester,
        MmPage(title: 'Dues', body: _body(height: 2000)),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsNothing);
      final before = tester.getRect(find.byKey(_bodyKey)).top;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_bodyKey)).top, lessThan(before));
    });

    testWidgets('without scrolling, the body fills the height', (tester) async {
      await pumpScreen(
        tester,
        MmPage(title: 'Dues', scrollable: false, body: _body()),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      final body = tester.getRect(find.byKey(_bodyKey));
      final bar = tester.getRect(find.byType(AppBar));
      expect(body.top, bar.bottom);
      expect(body.bottom, 740);
      expect(body.left, MmSpace.s4);
    });

    testWidgets('pulling down refreshes, even a short page', (tester) async {
      var refreshes = 0;
      await pumpScreen(
        tester,
        MmPage(
          title: 'Dues',
          onRefresh: () async => refreshes++,
          body: _body(),
        ),
      );
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      expect(indicator.color, MmColorModes.light.primary);
      expect(indicator.backgroundColor, MmColorModes.light.surface);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );
      await tester.fling(find.byKey(_bodyKey), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });

    testWidgets('pins the bottom bar under the body', (tester) async {
      await pumpScreen(
        tester,
        MmPage(
          title: 'Dues',
          scrollable: false,
          body: _body(),
          bottomBar: const SizedBox(key: _barKey, height: 80),
        ),
      );
      final bar = tester.getRect(find.byKey(_barKey));
      expect(bar.bottom, 740);
      expect(tester.getRect(find.byKey(_bodyKey)).bottom, bar.top);
    });

    testWidgets('shows the floating action button', (tester) async {
      await pumpScreen(
        tester,
        MmPage(
          title: 'Tenants',
          body: _body(),
          floatingActionButton: const FloatingActionButton(
            onPressed: tapped,
            tooltip: 'Add tenant',
            child: Icon(MmIcons.add),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testEveryVariant('the app bar is tall enough for the title line', (
      tester,
      variant,
    ) async {
      await pumpScreen(
        tester,
        MmPage(title: 'Dues', body: _body()),
        variant: variant,
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final title = tester.getRect(find.text('Dues'));
      expect(appBar.toolbarHeight, greaterThanOrEqualTo(MmSize.appBar));
      expect(appBar.toolbarHeight, greaterThanOrEqualTo(title.height));
      if (variant == MmVariant.largeText) {
        // 20 px at 200% on a 1.4 line, plus 8 dp above and below.
        expect(appBar.toolbarHeight, closeTo(40 * 1.4 + 2 * MmSpace.s2, 1));
      } else {
        expect(appBar.toolbarHeight, MmSize.appBar);
      }
    });

    testWidgets("sizes the bar for the theme's title style by default", (
      tester,
    ) async {
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Theme(
            // An app bar theme without a title style of its own.
            data: Theme.of(context).copyWith(appBarTheme: const AppBarTheme()),
            child: MmPage(title: 'Dues', body: _body()),
          ),
        ),
        variant: MmVariant.largeText,
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, closeTo(40 * 1.4 + 2 * MmSpace.s2, 1));
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpScreen(
        tester,
        _opener(
          const MmPage(
            title: 'Ayesha Khan, House 12, Gulberg',
            actions: [
              IconButton(
                onPressed: tapped,
                tooltip: 'Edit tenant',
                icon: Icon(MmIcons.edit),
              ),
            ],
            body: Text(
              'October rent of Rs 45,000 was due on the 5th and is now '
              'twelve days overdue.',
            ),
            bottomBar: SizedBox(height: 80),
          ),
        ),
        size: const Size(320, 640),
        variant: MmVariant.largeText,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab reaches the back button and the actions', (tester) async {
      var edits = 0;
      await pumpScreen(
        tester,
        _opener(
          MmPage(
            title: 'Ayesha Khan',
            actions: [
              IconButton(
                onPressed: () => edits++,
                tooltip: 'Edit tenant',
                icon: const Icon(MmIcons.edit),
              ),
            ],
            body: _body(),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.byIcon(MmIcons.back)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.byIcon(MmIcons.edit)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(edits, 1);
    });
  });
}
