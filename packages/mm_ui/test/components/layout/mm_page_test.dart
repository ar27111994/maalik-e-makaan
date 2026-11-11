import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

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

const _longTitle = 'Ayesha Khan, House 12, Gulberg';
const _longUrduTitle = 'عائشہ خان، مکان 12، گلبرگ';

const _edit = IconButton(
  onPressed: tapped,
  tooltip: 'Edit tenant',
  icon: Icon(MmIcons.edit),
);

/// Pumps [child] as the whole screen in [locale] at 200% text on a
/// 320 dp phone.
Future<void> _pumpLarge(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
}) async {
  tester.view
    ..physicalSize = const Size(320, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(child, variant: MmVariant.largeText, locale: locale),
  );
  await tester.pumpAndSettle();
}

/// The insets the body sees.
late EdgeInsets _bodyPadding;

Widget _paddingProbe() => Builder(
  builder: (context) {
    _bodyPadding = MediaQuery.paddingOf(context);
    return _body();
  },
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

    for (final urdu in [false, true]) {
      testWidgets('on a wide window the title starts on the content '
          "column's edge (${urdu ? 'Urdu' : 'English'})", (tester) async {
        final title = urdu ? 'چارجز' : 'Dues';
        final long = urdu ? _longUrduTitle * 3 : _longTitle * 3;
        void expectOnColumnEdge(String text) {
          final body = tester.getRect(find.byKey(_bodyKey));
          final shown = tester.getRect(find.text(text));
          if (urdu) {
            expect(shown.right, moreOrLessEquals(body.right), reason: text);
          } else {
            expect(shown.left, moreOrLessEquals(body.left), reason: text);
          }
        }

        final variant = urdu ? MmVariant.urdu : MmVariant.light;
        const window = Size(1200, 800);
        // Alone in the toolbar, beside an action, after a back button, and
        // moved under the toolbar for its length.
        for (final page in [
          MmPage(title: title, body: _body()),
          MmPage(title: title, actions: const [_edit], body: _body()),
          MmPage(
            title: title,
            leading: const BackButton(),
            actions: const [_edit],
            body: _body(),
          ),
          MmPage(
            title: long,
            leading: const BackButton(),
            actions: const [_edit],
            body: _body(),
          ),
        ]) {
          await pumpScreen(tester, page, size: window, variant: variant);
          await tester.pumpAndSettle();
          expectOnColumnEdge(page.title);
        }
        // A long title under the toolbar wraps within the column.
        final body = tester.getRect(find.byKey(_bodyKey));
        final shown = tester.getRect(find.text(long));
        expect(shown.width, lessThanOrEqualTo(body.width));
        // On a phone the column is the page less its padding, as before.
        await pumpScreen(
          tester,
          MmPage(title: title, leading: const BackButton(), body: _body()),
          variant: variant,
        );
        final phoneTitle = tester.getRect(find.text(title));
        if (urdu) {
          expect(phoneTitle.right, 360 - kToolbarHeight - MmSpace.s4);
        } else {
          expect(phoneTitle.left, kToolbarHeight + MmSpace.s4);
        }
      });
    }

    testWidgets('pads from the start edge in Urdu too', (tester) async {
      await pumpScreen(
        tester,
        MmPage(title: 'چارجز', body: _body()),
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

    for (final (language, title) in [
      ('en', _longTitle),
      ('ur', _longUrduTitle),
    ]) {
      testWidgets('a long title at 200% on a 320 dp phone is set whole, '
          'at full size, under the toolbar ($language)', (tester) async {
        await _pumpLarge(
          tester,
          _opener(
            MmPage(
              title: title,
              actions: const [_edit],
              body: const Text('October rent'),
            ),
          ),
          locale: Locale(language),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final paragraph = paragraphOf(tester, title);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.maxLines, isNull);
        // At the text scale of the rest of the screen, not an app bar's
        // 134%.
        expect(
          MediaQuery.textScalerOf(tester.element(find.text(title))).scale(10),
          20,
        );
        // Under the back button and the action, across the width.
        final rect = tester.getRect(find.text(title));
        final back = tester.getRect(find.byType(BackButton));
        expect(rect.top, greaterThanOrEqualTo(back.bottom));
        expect(rect.left, MmSpace.s4);
        expect(rect.right, 320 - MmSpace.s4);
        // The app bar holds it all, and the body starts below.
        final appBar = tester.getRect(find.byType(AppBar));
        expect(rect.bottom, lessThanOrEqualTo(appBar.bottom - MmSpace.s3));
        expect(
          tester.getRect(find.text('October rent')).top,
          greaterThanOrEqualTo(appBar.bottom),
        );
        expect(
          tester.getSemantics(find.text(title)),
          isSemantics(label: title, isHeader: true),
        );
      });
    }

    testWidgets('a title that fits stays in the toolbar at full size', (
      tester,
    ) async {
      await _pumpLarge(
        tester,
        _opener(const MmPage(title: 'Dues', actions: [_edit], body: Text('x'))),
        locale: const Locale('en'),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text('Dues'));
      final back = tester.getRect(find.byType(BackButton));
      expect(title.center.dy, closeTo(back.center.dy, 1));
      expect(title.left, greaterThan(back.right));
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Dues'))).scale(10),
        20,
      );
      expect(paragraphOf(tester, 'Dues').maxLines, 1);
    });

    testWidgets('a long title with nothing beside it wraps in the toolbar', (
      tester,
    ) async {
      await _pumpLarge(
        tester,
        const MmPage(title: _longTitle, body: Text('October rent')),
        locale: const Locale('en'),
      );
      final title = tester.getRect(find.text(_longTitle));
      final appBar = tester.getRect(find.byType(AppBar));
      expect(paragraphOf(tester, _longTitle).didExceedMaxLines, isFalse);
      expect(title.height, greaterThan(100));
      expect(title.top - appBar.top, MmSpace.s2);
      expect(appBar.bottom - title.bottom, MmSpace.s2);
      expect(
        tester.getSemantics(find.text(_longTitle)),
        isSemantics(label: _longTitle, isHeader: true),
      );
    });

    testWidgets('a title too wide beside a text action moves under it', (
      tester,
    ) async {
      // Taken for an icon button, the text action leaves room for the
      // title; laid out, it does not, and the title moves.
      await pumpScreen(
        tester,
        const MmPage(
          title: 'Ayesha Khan, House 12',
          actions: [TextButton(onPressed: tapped, child: Text('Save changes'))],
          body: Text('x'),
        ),
      );
      final title = tester.getRect(find.text('Ayesha Khan, House 12'));
      final save = tester.getRect(find.text('Save changes'));
      expect(title.top, greaterThanOrEqualTo(save.bottom));
      expect(
        paragraphOf(tester, 'Ayesha Khan, House 12').didExceedMaxLines,
        isFalse,
      );
      // It moves back when the window is wide enough.
      await resizeScreen(tester, const Size(700, 740));
      final wide = tester.getRect(find.text('Ayesha Khan, House 12'));
      expect(
        wide.center.dy,
        closeTo(tester.getRect(find.text('Save changes')).center.dy, 1),
      );
    });

    for (final (variant, title, latin) in [
      (MmVariant.urdu, 'Ayesha Khan', true),
      (MmVariant.urdu, 'عائشہ خان', false),
      (MmVariant.light, 'Ayesha Khan', true),
    ]) {
      testWidgets('the title "$title" keeps its own script\'s face '
          '(${variant.name})', (tester) async {
        await pumpScreen(
          tester,
          MmPage(title: title, body: _body()),
          variant: variant,
        );
        final family = styleOf(tester, title).fontFamily!;
        if (latin) {
          expect(family, contains(MmFontFamily.latin));
        } else {
          expect(family, isNot(contains(MmFontFamily.latin)));
        }
      });
    }

    for (final variant in [MmVariant.light, MmVariant.urdu]) {
      for (final scrollable in [true, false]) {
        testWidgets('keeps the body clear of cut-outs at the sides '
            '(${variant.name}, scrollable: $scrollable)', (tester) async {
          tester.view.padding = const FakeViewPadding(left: 44, right: 30);
          addTearDown(tester.view.resetPadding);
          await pumpScreen(
            tester,
            MmPage(
              title: 'Dues',
              scrollable: scrollable,
              body: _paddingProbe(),
            ),
            size: const Size(560, 360),
            variant: variant,
          );
          final body = tester.getRect(find.byKey(_bodyKey));
          // Physical sides: the device's cut-out is where it is, in either
          // language.
          expect(body.left, 44 + MmSpace.s4);
          expect(body.right, 560 - 30 - MmSpace.s4);
          // Lined up with the title (English) or with its end (Urdu).
          final title = tester.getRect(find.text('Dues'));
          if (variant == MmVariant.urdu) {
            expect(title.right, body.right);
          } else {
            expect(title.left, body.left);
          }
          // The body is not padded for the sides again.
          expect(_bodyPadding.left, 0);
          expect(_bodyPadding.right, 0);
        });
      }
    }

    testWidgets('scrolls the end of the body clear of the gesture bar', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await pumpScreen(
        tester,
        MmPage(
          title: 'Dues',
          body: Column(
            children: [const SizedBox(height: 1200), _paddingProbe()],
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(_bodyKey)).bottom,
        740 - 34 - MmSpace.s4,
      );
      expect(_bodyPadding.bottom, 0);
    });

    testWidgets('leaves the bottom safe area to a body that fills the page', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await pumpScreen(
        tester,
        MmPage(title: 'Dues', scrollable: false, body: _paddingProbe()),
      );
      expect(_bodyPadding.bottom, 34);
      expect(tester.getRect(find.byKey(_bodyKey)).bottom, 740);
    });

    testWidgets('with a bottom bar, the bar takes the bottom safe area', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await pumpScreen(
        tester,
        MmPage(
          title: 'Dues',
          body: Column(
            children: [const SizedBox(height: 1200), _paddingProbe()],
          ),
          bottomBar: const MmActionBar(
            primary: FilledButton(onPressed: tapped, child: Text('Save')),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(MmActionBar));
      expect(tester.getRect(find.byKey(_bodyKey)).bottom, bar.top - MmSpace.s4);
    });

    testWidgets('refreshing needs a scrolling page', (tester) async {
      expect(
        () => MmPage(
          title: 'Dues',
          scrollable: bool.parse('false'),
          onRefresh: () async {},
          body: _body(),
        ),
        throwsAssertionError,
      );
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

    group('keeps the last content clear of the floating action button', () {
      const endKey = ValueKey<String>('end');
      const fabKey = ValueKey<String>('fab');

      /// A page of [length] rows ending in a row keyed [endKey], scrolled to
      /// its end.
      Future<void> pumpScrolledToEnd(
        WidgetTester tester, {
        required Size size,
        MmVariant variant = MmVariant.light,
        double safeBottom = 0,
        bool scrollable = true,
        Widget? bottomBar,
        String label = 'Add tenant',
      }) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1
          ..padding = FakeViewPadding(bottom: safeBottom)
          ..viewPadding = FakeViewPadding(bottom: safeBottom);
        addTearDown(tester.view.reset);
        final rows = [
          for (var row = 0; row < 30; row++)
            SizedBox(
              key: row == 29 ? endKey : null,
              height: MmSize.listRow,
              child: Text('Tenant ${row + 1}'),
            ),
        ];
        await tester.pumpWidget(
          themedApp(
            MmPage(
              title: 'Tenants',
              scrollable: scrollable,
              body: scrollable
                  ? Column(children: rows)
                  : ListView(children: rows),
              bottomBar: bottomBar,
              floatingActionButton: MmFab(
                key: fabKey,
                label: label,
                icon: MmIcons.invite,
                onPressed: tapped,
              ),
            ),
            variant: variant,
          ),
        );
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }

      void expectClear(WidgetTester tester) {
        final end = tester.getRect(find.byKey(endKey));
        final fab = tester.getRect(find.byKey(fabKey));
        // The page's own 16 dp end gap, above the button.
        expect(end.bottom, closeTo(fab.top - MmSpace.s4, 0.01));
      }

      for (final (name, size) in const [
        ('compact', Size(360, 740)),
        ('expanded', Size(1280, 800)),
      ]) {
        testWidgets('in the $name size class', (tester) async {
          await pumpScrolledToEnd(tester, size: size);
          expectClear(tester);
        });

        testWidgets('above the gesture bar in the $name size class', (
          tester,
        ) async {
          await pumpScrolledToEnd(tester, size: size, safeBottom: 34);
          expectClear(tester);
          // The button itself stands 16 dp clear of the safe area.
          expect(
            tester.getRect(find.byKey(fabKey)).bottom,
            size.height - 34 - kFloatingActionButtonMargin,
          );
        });

        testWidgets('above a bottom bar in the $name size class', (
          tester,
        ) async {
          await pumpScrolledToEnd(
            tester,
            size: size,
            safeBottom: 34,
            bottomBar: const SizedBox(key: _barKey, height: 80),
          );
          expectClear(tester);
        });

        testWidgets('in a body that scrolls by itself in the $name size '
            'class', (tester) async {
          await pumpScrolledToEnd(
            tester,
            size: size,
            safeBottom: 34,
            scrollable: false,
          );
          expectClear(tester);
        });
      }

      testWidgets('as the button grows with a wrapped label at 200% text', (
        tester,
      ) async {
        await pumpScrolledToEnd(
          tester,
          size: const Size(320, 640),
          variant: MmVariant.largeText,
          label: 'Record a payment for this tenant',
        );
        expect(
          tester.getSize(find.byKey(fabKey)).height,
          greaterThan(MmSize.fab),
        );
        expectClear(tester);
      });

      testWidgets('and adds nothing without a button', (tester) async {
        tester.view
          ..physicalSize = const Size(360, 740)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          themedApp(MmPage(title: 'Tenants', body: _body(height: 2000))),
        );
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_bodyKey)).bottom, 740 - MmSpace.s4);
      });
    });
  });
}
