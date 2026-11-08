import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

int _count(List<Call> calls, String name) =>
    calls.where((c) => c.$1 == name).length;

void main() {
  test('owners bring the dues up to date before the dashboard', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, dashboardProvider(gulberg));
    await pumpEventQueue();
    expect(app.ledger.syncs, 1);
    final snapshot = container.read(dashboardProvider(gulberg)).value!;
    expect(snapshot.source, SnapshotSource.network);
    expect(snapshot.value.topArrears, hasLength(2));
  });

  test('viewers read the dashboard without bringing dues up to date', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, dashboardProvider(gulbergAsViewer));
    await pumpEventQueue();
    expect(app.ledger.syncs, 0);
    expect(_count(app.insights.calls, 'dashboard'), 1);
  });

  test('the dashboard saved on the device shows first', () async {
    final app = TestApp();
    final first = containerFor(app);
    listen(first, dashboardProvider(gulberg));
    await pumpEventQueue();
    first.dispose();

    app.insights.failure = const NetworkFailure();
    final second = containerFor(app);
    listen(second, dashboardProvider(gulberg));
    await pumpEventQueue();
    final state = second.read(dashboardProvider(gulberg));
    expect(state.value!.fromCache, isTrue);
    expect(state.error, isA<NetworkFailure>());
  });

  test('the extras read cash and rent roll side by side', () async {
    final app = TestApp();
    final container = containerFor(app);
    final provider = insightExtrasProvider(gulberg.id);
    listen(container, provider);
    await pumpEventQueue();
    final extras = container.read(provider).value!.value;
    expect(extras.positions, hasLength(2));
    expect(extras.rentRoll, hasLength(2));
    final again = InsightExtras.fromJson(extras.toJson());
    expect(again, extras);
    expect(again.hashCode, extras.hashCode);

    // Saved on the device: read back while the server is away.
    app.insights.failure = const NetworkFailure();
    final cached = containerFor(app);
    listen(cached, provider);
    await pumpEventQueue();
    expect(cached.read(provider).value!.value, extras);
    expect(cached.read(provider).value!.fromCache, isTrue);

    app.insights.failure = const Forbidden();
    final failing = containerFor(app);
    listen(failing, insightExtrasProvider(plaza.id));
    await pumpEventQueue();
    expect(
      failing.read(insightExtrasProvider(plaza.id)).error,
      isA<Forbidden>(),
    );
  });

  test('payment scores come from the facts, as of today', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, paymentScoresProvider(gulberg.id));
    await pumpEventQueue();
    final scores = container.read(paymentScoresProvider(gulberg.id)).value!;
    expect(scores[aliRaza.id]!.score, 22);
    // Read again from the device.
    final cached = containerFor(app);
    app.insights.failure = const NetworkFailure();
    listen(cached, paymentFactsProvider(gulberg.id));
    await pumpEventQueue();
    expect(
      cached.read(paymentFactsProvider(gulberg.id)).value!.value,
      hasLength(7),
    );
  });

  test('a report span is the twelve months to a month', () {
    final span = twelveMonthsTo(gulberg.id, MonthPeriod(2026, 11));
    expect(span.from, CalendarDate(2025, 12, 1));
    expect(span.to, CalendarDate(2026, 11, 30));
  });

  test(
    'cash flow, performance and a tax year are kept by their span',
    () async {
      final app = TestApp();
      final container = containerFor(app);
      final span = twelveMonthsTo(gulberg.id, MonthPeriod(2026, 11));
      final of = (portfolioId: gulberg.id, taxYear: TaxYear(2026));
      listen(container, cashflowProvider(span));
      listen(container, performanceProvider(span));
      listen(container, taxYearProvider(of));
      await pumpEventQueue();
      expect(
        container.read(cashflowProvider(span)).value!.value,
        hasLength(12),
      );
      expect(
        container.read(performanceProvider(span)).value!.value,
        hasLength(2),
      );
      expect(
        container.read(taxYearProvider(of)).value!.value.properties,
        hasLength(2),
      );
      final keys = await app.store.keys();
      expect(
        keys,
        containsAll([
          for (final query in [
            'cashflow.${gulberg.id}.2025-12-01.2026-11-30',
            'performance.${gulberg.id}.2025-12-01.2026-11-30',
            'tax-year.${gulberg.id}.2026',
          ])
            'mm.swr.v1.$testUserId.$query',
        ]),
      );

      // Each reads back from the device as it was.
      app.insights.failure = const NetworkFailure();
      final cached = containerFor(app);
      listen(cached, cashflowProvider(span));
      listen(cached, performanceProvider(span));
      listen(cached, taxYearProvider(of));
      await pumpEventQueue();
      expect(
        cached.read(cashflowProvider(span)).value!.value,
        container.read(cashflowProvider(span)).value!.value,
      );
      expect(
        cached.read(performanceProvider(span)).value!.value,
        container.read(performanceProvider(span)).value!.value,
      );
      expect(
        cached.read(taxYearProvider(of)).value!.value,
        container.read(taxYearProvider(of)).value!.value,
      );
    },
  );

  test('a search asks the repository', () async {
    final app = TestApp();
    final container = containerFor(app);
    final search = (portfolioId: gulberg.id, query: 'gul');
    listen(container, searchProvider(search));
    final results = await container.read(searchProvider(search).future);
    expect(results.map((r) => r.kind), [SearchKind.property, SearchKind.unit]);
    expect(app.insights.calls.last.$2, [gulberg.id, 'gul']);
  });

  group('report reader', () {
    test('an owner statement gathers the month and today', () async {
      final app = TestApp();
      final container = containerFor(app);
      final statement = await container
          .read(reportReaderProvider)
          .ownerStatement(gulberg, MonthPeriod(2026, 10));
      expect(statement.portfolioName, 'Gulberg Houses');
      expect(statement.flow.month, MonthPeriod(2026, 10));
      expect(statement.properties, hasLength(2));
      expect(statement.arrears, hasLength(2));
      // Only members holding cash.
      expect(statement.cash, hasLength(2));
      expect(statement.asOf, CalendarDate(2026, 11, 7));
      expect(app.insights.calls.firstWhere((c) => c.$1 == 'cashflow').$2, [
        gulberg.id,
        CalendarDate(2026, 10, 1),
        CalendarDate(2026, 10, 31),
      ]);
    });

    test('owners bring the dues up to date before what is owed', () async {
      final app = TestApp();
      final container = containerFor(app);
      app.ledger.gate.close();
      final statement = container
          .read(reportReaderProvider)
          .ownerStatement(gulberg, MonthPeriod(2026, 10));
      await pumpEventQueue();
      // The month is read meanwhile; what is owed today waits for the sync.
      expect(_count(app.insights.calls, 'cashflow'), 1);
      expect(_count(app.insights.calls, 'dashboard'), 0);
      app.ledger.gate.open();
      await statement;
      expect(app.ledger.syncs, 1);
      expect(_count(app.insights.calls, 'dashboard'), 1);
      // Once a day, as the dashboard does.
      await container
          .read(reportReaderProvider)
          .ownerStatement(gulberg, MonthPeriod(2026, 9));
      expect(app.ledger.syncs, 1);
    });

    test('viewers read what is owed without a sync', () async {
      final app = TestApp();
      final container = containerFor(app);
      await container
          .read(reportReaderProvider)
          .ownerStatement(gulbergAsViewer, MonthPeriod(2026, 10));
      expect(app.ledger.syncs, 0);
      expect(_count(app.insights.calls, 'dashboard'), 1);
    });

    test('a month with no row reads as nothing in or out', () async {
      final repository = FakeInsightsRepository()..cashflowMissing = true;
      var syncs = 0;
      final statement = await ReportReader(
        repository,
        (_) async => syncs++,
      ).ownerStatement(plaza, MonthPeriod(2026, 10));
      expect(syncs, plaza.role.recordsMoney ? 1 : 0);
      expect(statement.flow.received, Money.zero);
      expect(statement.flow.month, MonthPeriod(2026, 10));
      expect(statement.cash, hasLength(2));
    });

    test('the first failure is the one shown', () async {
      final app = TestApp()..insights.failure = const Forbidden();
      final container = containerFor(app);
      await expectLater(
        container
            .read(reportReaderProvider)
            .ownerStatement(gulberg, MonthPeriod(2026, 10)),
        throwsA(isA<Forbidden>()),
      );
    });

    test('exports read the span asked for', () async {
      final app = TestApp();
      final container = containerFor(app);
      final reader = container.read(reportReaderProvider);
      final span = (
        portfolioId: gulberg.id,
        from: CalendarDate(2026, 10, 1),
        to: CalendarDate(2026, 10, 31),
      );
      expect(await reader.charges(span), isEmpty);
      expect(await reader.payments(span), isEmpty);
      expect(await reader.expenses(span), hasLength(2));
      expect(
        (await reader.taxYear(gulberg.id, TaxYear(2025))).properties,
        isEmpty,
      );
      expect(app.insights.calls.map((c) => c.$1), [
        'chargesBetween',
        'paymentsBetween',
        'expensesBetween',
        'taxYearStatement',
      ]);
    });
  });
}
