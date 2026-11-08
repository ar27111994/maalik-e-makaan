import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/search_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

Widget _search() => const SearchScreen();

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(SearchScreen.searchDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for a name, and for two letters at least', (tester) async {
    final app = await pumpScreen(tester, _search);
    expect(
      find.text(
        'Find a property, unit or tenant by name, locality, phone or CNIC.',
      ),
      findsOneWidget,
    );
    await _type(tester, 'a');
    expect(find.text('Type at least 2 letters or digits.'), findsOneWidget);
    expect(app.insights.calls, isEmpty);
  });

  testWidgets('counts letters as the server does', (tester) async {
    final app = await pumpScreen(tester, _search);
    // One letter on screen, two code points (alef and a madda above): the
    // server counts two, so the search runs.
    await _type(tester, '\u0627\u0653');
    expect(find.text('Type at least 2 letters or digits.'), findsNothing);
    expect(app.insights.calls.single.$2.last, '\u0627\u0653');
  });

  testWidgets('waits for typing to pause', (tester) async {
    final app = await pumpScreen(tester, _search);
    await tester.enterText(find.byType(TextField), 'al');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump(SearchScreen.searchDelay);
    await tester.pumpAndSettle();
    expect(app.insights.calls.single.$2, [gulberg.id, 'ali']);
    expect(find.text('Ali Raza'), findsOneWidget);
    expect(find.text('Tenant: 0300 1112233'), findsOneWidget);
  });

  testWidgets('searching at once when submitted', (tester) async {
    final app = await pumpScreen(tester, _search);
    await tester.enterText(find.byType(TextField), 'gul');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(app.insights.calls.single.$2, [gulberg.id, 'gul']);
    expect(find.text('Gulberg House'), findsOneWidget);
    expect(find.text('Annexe room'), findsOneWidget);
  });

  for (final (query, title, route) in [
    ('ali', 'Ali Raza', Routes.tenant(aliRaza.id)),
    ('gulberg', 'Gulberg House', Routes.property(gulbergHouse.id)),
    ('annexe', 'Annexe room', Routes.unit(gulbergHouse.id, annexe.id)),
  ]) {
    testWidgets('$title opens its screen', (tester) async {
      await pumpScreen(tester, _search);
      await _type(tester, query);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(routeShown(route), findsOneWidget);
    });
  }

  testWidgets('a long search is cut to what the server reads', (tester) async {
    final app = await pumpScreen(tester, _search);
    await _type(tester, 'x' * 150);
    expect(app.insights.calls.single.$2.last, 'x' * 100);
  });

  test('a search is cut by code points, as the server counts', () {
    // 60 letters with a diacritic each: 60 on screen, 120 code points.
    final marked = '\u0628\u064E' * 60;
    final query = searchQuery(marked);
    expect(query.runes.length, 100);
    expect(query, '\u0628\u064E' * 50);
    expect(searchQuery('  ali  '), 'ali');
    // A letter beyond the basic plane is never split.
    expect(searchQuery('\u{1F3E0}' * 120).runes.length, 100);
  });

  testWidgets('says how many it found, as screen readers hear it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, _search);
    await _type(tester, 'gul');
    expect(find.text('2 results'), findsOneWidget);
    final live = find.ancestor(
      of: find.text('2 results'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
    );
    expect(live, findsOneWidget);
    await _type(tester, 'zzz');
    expect(
      find.ancestor(
        of: find.text('Nothing matches zzz.'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('says when nothing matches', (tester) async {
    await pumpScreen(tester, _search);
    await _type(tester, 'zzz');
    expect(find.text('Nothing matches zzz.'), findsOneWidget);
  });

  testWidgets('says when the search failed, and tries again', (tester) async {
    final app = TestApp()..insights.failure = const NetworkFailure();
    await pumpScreen(tester, _search, app: app);
    await _type(tester, 'ali');
    expect(find.text('The search did not finish'), findsOneWidget);
    app.insights.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Raza'), findsOneWidget);
  });

  testWidgets('shows a skeleton while it searches', (tester) async {
    final app = TestApp()..insights.gate.close();
    await pumpScreen(tester, _search, app: app);
    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump(SearchScreen.searchDelay);
    await tester.pump();
    expect(find.byType(MmSkeletonList), findsOneWidget);
    app.insights.gate.open();
    await tester.pumpAndSettle();
  });

  testWidgets('waits for a portfolio', (tester) async {
    await pumpScreen(tester, _search, app: TestApp(portfolios: const []));
    await _type(tester, 'ali');
    expect(find.text('Ali Raza'), findsNothing);
  });

  group('a result', () {
    Future<void> show(WidgetTester tester, SearchResult result) => pumpScreen(
      tester,
      () => MmPage(title: 'x', body: SearchResultTile(result)),
    );

    testWidgets('without a line names only what it is', (tester) async {
      await show(
        tester,
        const SearchResult(kind: SearchKind.property, id: 'p', title: 'Plot'),
      );
      expect(find.text('Property'), findsOneWidget);
    });

    testWidgets('a tenant line that is not a phone is shown as it is', (
      tester,
    ) async {
      await show(
        tester,
        const SearchResult(
          kind: SearchKind.tenant,
          id: 't',
          title: 'Sana',
          subtitle: 'no phone',
        ),
      );
      expect(find.text('Tenant: no phone'), findsOneWidget);
    });

    testWidgets('a unit whose property is unknown cannot be opened', (
      tester,
    ) async {
      await show(
        tester,
        const SearchResult(
          kind: SearchKind.unit,
          id: 'u',
          title: 'Room 4',
          subtitle: 'Hostel',
        ),
      );
      expect(find.byIcon(MmIcons.chevronEnd), findsNothing);
      await tester.tap(find.text('Room 4'));
      await tester.pumpAndSettle();
      expect(find.text('Room 4'), findsOneWidget);
    });
  });

  testEveryVariant('fits and reads well', (tester, variant) async {
    await pumpScreen(
      tester,
      _search,
      variant: variant,
      size: const Size(320, 640),
      app: TestApp()..insights.searchFilters = false,
    );
    await _type(tester, 'ali');
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}
