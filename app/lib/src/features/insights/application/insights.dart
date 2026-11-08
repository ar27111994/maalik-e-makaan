import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/failure.dart' show AppFailure;
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/application/payment_scores.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/insights_repository.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

/// A portfolio's dashboard (INS-01), the saved copy first. Owners,
/// managers and accountants first bring the portfolio's dues up to date,
/// as the who-owes-what list does, so the figures include today's rent.
final StreamNotifierProviderFamily<
  DashboardController,
  Snapshot<Dashboard>,
  PortfolioMembership
>
dashboardProvider = StreamNotifierProvider.autoDispose
    .family<DashboardController, Snapshot<Dashboard>, PortfolioMembership>(
      DashboardController.new,
    );

/// Reads the dashboard.
final class DashboardController extends SwrNotifier<Dashboard> {
  new(this.portfolio);

  final PortfolioMembership portfolio;

  @override
  String get query => 'dashboard.${portfolio.id}';

  @override
  Stream<Snapshot<Dashboard>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<Dashboard> fetch() async {
    if (portfolio.role.recordsMoney) {
      final day = ref.read(todayProvider);
      await ref.read(
        billingSyncProvider((portfolioId: portfolio.id, day: day)).future,
      );
    }
    return await ref.read(insightsRepositoryProvider).dashboard(portfolio.id);
  }

  @override
  Dashboard decode(Object? json) => Dashboard.fromJson(json);

  @override
  Object? encode(Dashboard value) => value.toJson();
}

/// What some insight cards need beside the dashboard: the cash each member
/// holds, and the rents of active tenancies beside their asking rents.
@immutable
final class InsightExtras {
  const new({required this.positions, required this.rentRoll});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'insight extras');
    return InsightExtras(
      positions: [
        for (final p in row.list('positions')) CashPosition.fromRow(p),
      ],
      rentRoll: [
        for (final r in row.list('rent_roll')) RentRollEntry.fromRow(r),
      ],
    );
  }

  final List<CashPosition> positions;
  final List<RentRollEntry> rentRoll;

  Map<String, Object?> toJson() => {
    'positions': [for (final p in positions) p.toRow()],
    'rent_roll': [for (final r in rentRoll) r.toRow()],
  };

  @override
  bool operator ==(Object other) =>
      other is InsightExtras &&
      listEquals(other.positions, positions) &&
      listEquals(other.rentRoll, rentRoll);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(positions), Object.hashAll(rentRoll));
}

/// The cash and rent roll of a portfolio, read after the dashboard so it
/// still shows in one round trip; the saved copy first.
final StreamNotifierProviderFamily<
  InsightExtrasController,
  Snapshot<InsightExtras>,
  String
>
insightExtrasProvider = StreamNotifierProvider.autoDispose
    .family<InsightExtrasController, Snapshot<InsightExtras>, String>(
      InsightExtrasController.new,
    );

/// Reads [InsightExtras].
final class InsightExtrasController extends SwrNotifier<InsightExtras> {
  new(this.portfolioId);

  final String portfolioId;

  @override
  String get query => 'insight-extras.$portfolioId';

  @override
  Stream<Snapshot<InsightExtras>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<InsightExtras> fetch() async {
    final repository = ref.read(insightsRepositoryProvider);
    final positions = repository.cashPositions(portfolioId);
    final rentRoll = repository.rentRoll(portfolioId);
    // Side by side; the first failure is the one shown.
    await Future.wait<Object>([positions, rentRoll]);
    return InsightExtras(positions: await positions, rentRoll: await rentRoll);
  }

  @override
  InsightExtras decode(Object? json) => InsightExtras.fromJson(json);

  @override
  Object? encode(InsightExtras value) => value.toJson();
}

/// The rent dues of the last 12 months of a portfolio and when each was
/// settled: what payment scores are made of, the saved copy first.
final StreamNotifierProviderFamily<
  PaymentFactsController,
  Snapshot<List<PaymentFact>>,
  String
>
paymentFactsProvider = StreamNotifierProvider.autoDispose
    .family<PaymentFactsController, Snapshot<List<PaymentFact>>, String>(
      PaymentFactsController.new,
    );

/// Reads the payment facts.
final class PaymentFactsController extends SwrNotifier<List<PaymentFact>> {
  new(this.portfolioId);

  final String portfolioId;

  @override
  String get query => 'payment-facts.$portfolioId';

  @override
  Stream<Snapshot<List<PaymentFact>>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<PaymentFact>> fetch() =>
      ref.read(insightsRepositoryProvider).paymentFacts(portfolioId);

  @override
  List<PaymentFact> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      PaymentFact.fromRow(row),
  ];

  @override
  Object? encode(List<PaymentFact> value) => [
    for (final fact in value) fact.toRow(),
  ];
}

/// Each tenant's payment score in a portfolio on today's date, by tenant
/// id (INS-03), once the facts are read.
final ProviderFamily<AsyncValue<Map<String, PaymentScore>>, String>
paymentScoresProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, PaymentScore>>, String>((ref, portfolioId) {
      final today = ref.watch(todayProvider);
      return ref
          .watch(paymentFactsProvider(portfolioId))
          .whenData((snapshot) => paymentScores(snapshot.value, today));
    });

/// A portfolio and a span of days, for a report.
typedef ReportSpan = ({String portfolioId, CalendarDate from, CalendarDate to});

/// The twelve months up to and including [month]'s, as a [ReportSpan].
ReportSpan twelveMonthsTo(String portfolioId, MonthPeriod month) => (
  portfolioId: portfolioId,
  from: month.addMonths(-11).first,
  to: month.last,
);

/// Money in and out each month over a span (INS-05), the saved copy first.
final StreamNotifierProviderFamily<
  CashflowController,
  Snapshot<List<CashflowMonth>>,
  ReportSpan
>
cashflowProvider = StreamNotifierProvider.autoDispose
    .family<CashflowController, Snapshot<List<CashflowMonth>>, ReportSpan>(
      CashflowController.new,
    );

/// Reads the cash flow.
final class CashflowController extends SwrNotifier<List<CashflowMonth>> {
  new(this.span);

  final ReportSpan span;

  @override
  String get query =>
      'cashflow.${span.portfolioId}.${span.from.toIso()}.${span.to.toIso()}';

  @override
  Stream<Snapshot<List<CashflowMonth>>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<CashflowMonth>> fetch() => ref
      .read(insightsRepositoryProvider)
      .cashflow(span.portfolioId, from: span.from, to: span.to);

  @override
  List<CashflowMonth> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      CashflowMonth.fromRow(row),
  ];

  @override
  Object? encode(List<CashflowMonth> value) => [
    for (final month in value) month.toRow(),
  ];
}

/// Each property's income, expenses, occupancy and yields over a span
/// (INS-05), the saved copy first.
final StreamNotifierProviderFamily<
  PerformanceController,
  Snapshot<List<PropertyPerformance>>,
  ReportSpan
>
performanceProvider = StreamNotifierProvider.autoDispose
    .family<
      PerformanceController,
      Snapshot<List<PropertyPerformance>>,
      ReportSpan
    >(PerformanceController.new);

/// Reads the property performance.
final class PerformanceController
    extends SwrNotifier<List<PropertyPerformance>> {
  new(this.span);

  final ReportSpan span;

  @override
  String get query =>
      'performance.${span.portfolioId}.${span.from.toIso()}.'
      '${span.to.toIso()}';

  @override
  Stream<Snapshot<List<PropertyPerformance>>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<PropertyPerformance>> fetch() => ref
      .read(insightsRepositoryProvider)
      .propertyPerformance(span.portfolioId, from: span.from, to: span.to);

  @override
  List<PropertyPerformance> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      PropertyPerformance.fromRow(row),
  ];

  @override
  Object? encode(List<PropertyPerformance> value) => [
    for (final property in value) property.toRow(),
  ];
}

/// A portfolio's tax year.
typedef TaxYearOf = ({String portfolioId, TaxYear taxYear});

/// A tax year's statement (RPT-01), the saved copy first.
final StreamNotifierProviderFamily<
  TaxYearController,
  Snapshot<TaxYearStatement>,
  TaxYearOf
>
taxYearProvider = StreamNotifierProvider.autoDispose
    .family<TaxYearController, Snapshot<TaxYearStatement>, TaxYearOf>(
      TaxYearController.new,
    );

/// Reads a tax year's statement.
final class TaxYearController extends SwrNotifier<TaxYearStatement> {
  new(this.of);

  final TaxYearOf of;

  @override
  String get query => 'tax-year.${of.portfolioId}.${of.taxYear.endYear}';

  @override
  Stream<Snapshot<TaxYearStatement>> build() {
    ref.watch(insightsRepositoryProvider);
    return super.build();
  }

  @override
  Future<TaxYearStatement> fetch() => ref
      .read(insightsRepositoryProvider)
      .taxYearStatement(of.portfolioId, of.taxYear);

  @override
  TaxYearStatement decode(Object? json) => TaxYearStatement.fromJson(json);

  @override
  Object? encode(TaxYearStatement value) => value.toJson();
}

/// A search in a portfolio.
typedef SearchOf = ({String portfolioId, String query});

/// Properties, units and tenants matching a search (SRCH-01). A search is
/// asked for as it is typed, so it is not saved on the device.
final FutureProviderFamily<List<SearchResult>, SearchOf> searchProvider =
    FutureProvider.autoDispose.family<List<SearchResult>, SearchOf>(
      (ref, search) => ref
          .watch(insightsRepositoryProvider)
          .search(search.portfolioId, search.query),
    );

/// The fewest letters a search runs with (as `search_portfolio` says).
const minSearchLength = 2;

/// The most letters a search runs with.
const maxSearchLength = 100;

/// A month's statement for an owner who lives away (RPT-02): the money in
/// and out, each property's income and expenses, and, as of the day it is
/// made, what tenants owe, who owes most, and the cash each member holds.
@immutable
final class OwnerStatement {
  const new({
    required this.portfolioName,
    required this.month,
    required this.flow,
    required this.properties,
    required this.outstanding,
    required this.arrears,
    required this.cash,
    required this.asOf,
  });

  final String portfolioName;
  final MonthPeriod month;
  final CashflowMonth flow;
  final List<PropertyPerformance> properties;

  /// What is owed today, by age.
  final Ageing outstanding;

  /// The tenancies owing most today.
  final List<Arrear> arrears;

  /// Cash each member holds today.
  final List<CashPosition> cash;

  /// The day the figures owed and held are for.
  final CalendarDate asOf;
}

/// Reads what the reports' documents and exports are made of. Every
/// method throws [AppFailure].
final class ReportReader {
  /// A reader of [_repository] that brings a portfolio's dues up to date
  /// with [_syncDues] before reading what is owed.
  new(this._repository, this._syncDues);

  final InsightsRepository _repository;
  final Future<void> Function(String portfolioId) _syncDues;

  /// [portfolio]'s statement for [month] (RPT-02).
  Future<OwnerStatement> ownerStatement(
    PortfolioMembership portfolio,
    MonthPeriod month,
  ) async {
    final flow = _repository.cashflow(
      portfolio.id,
      from: month.first,
      to: month.last,
    );
    final properties = _repository.propertyPerformance(
      portfolio.id,
      from: month.first,
      to: month.last,
    );
    // What is owed today, as the dashboard says it: owners, managers and
    // accountants first bring the dues up to date (see
    // [DashboardController]), so a missed daily run does not leave today's
    // rent out of the statement.
    final today = () async {
      if (portfolio.role.recordsMoney) await _syncDues(portfolio.id);
      return await _repository.dashboard(portfolio.id);
    }();
    final positions = _repository.cashPositions(portfolio.id);
    // Side by side; the first failure is the one shown.
    await Future.wait<Object>([flow, properties, today, positions]);
    final months = await flow;
    final dashboard = await today;
    return OwnerStatement(
      portfolioName: portfolio.name,
      month: month,
      flow: months.isEmpty ? _emptyMonth(month) : months.single,
      properties: await properties,
      outstanding: dashboard.outstanding,
      arrears: dashboard.topArrears,
      cash: [
        for (final p in await positions)
          if (p.inHand.isPositive) p,
      ],
      asOf: dashboard.asOf,
    );
  }

  /// The dues of [span], oldest first (RPT-03).
  Future<List<ExportCharge>> charges(ReportSpan span) => _repository
      .chargesBetween(span.portfolioId, from: span.from, to: span.to);

  /// The payments of [span], oldest first (RPT-03).
  Future<List<ExportPayment>> payments(ReportSpan span) => _repository
      .paymentsBetween(span.portfolioId, from: span.from, to: span.to);

  /// The expenses of [span], oldest first (RPT-03).
  Future<List<Expense>> expenses(ReportSpan span) => _repository
      .expensesBetween(span.portfolioId, from: span.from, to: span.to);

  /// [taxYear]'s statement (RPT-01).
  Future<TaxYearStatement> taxYear(String portfolioId, TaxYear taxYear) =>
      _repository.taxYearStatement(portfolioId, taxYear);

  static CashflowMonth _emptyMonth(MonthPeriod month) => CashflowMonth(
    month: month,
    received: Money.zero,
    rent: Money.zero,
    deposits: Money.zero,
    other: Money.zero,
    taxWithheld: Money.zero,
    expenses: Money.zero,
    depositRefunds: Money.zero,
  );
}

final Provider<ReportReader> reportReaderProvider = Provider.autoDispose((ref) {
  // The reader is used after this provider is read (a sheet makes a
  // statement on a tap), so it reaches the day's sync through the
  // container, where the sync is kept for the day.
  final container = ref.container;
  return ReportReader(
    ref.watch(insightsRepositoryProvider),
    (portfolioId) => container.read(
      billingSyncProvider((
        portfolioId: portfolioId,
        day: container.read(todayProvider),
      )).future,
    ),
  );
});
