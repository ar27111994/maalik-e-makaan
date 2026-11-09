import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The portfolio's figures: the dashboard, reports, scores, search and the
/// rows of CSV exports. Every member may read them all
/// (`docs/architecture/permissions.md`). Every method throws [AppFailure].
abstract interface class InsightsRepository {
  /// The dashboard (`get_dashboard`), in one round trip.
  Future<Dashboard> dashboard(String portfolioId);

  /// Money in and out each month from [from]'s month to [to]'s
  /// (`get_cashflow`). Refusal: `invalid_date` (a span over ten years).
  Future<List<CashflowMonth>> cashflow(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  });

  /// Each property's income, expenses and yields from [from] to [to]
  /// (`get_property_performance`). Refusal: `invalid_date`.
  Future<List<PropertyPerformance>> propertyPerformance(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  });

  /// The rent dues of the last 12 months and when each was settled
  /// (`get_payment_facts`), for payment scores.
  Future<List<PaymentFact>> paymentFacts(String portfolioId);

  /// The rental income of [taxYear] per property
  /// (`get_tax_year_statement`). Refusal: `invalid_tax_year`.
  Future<TaxYearStatement> taxYearStatement(
    String portfolioId,
    TaxYear taxYear,
  );

  /// Cash each member holds (`get_cash_positions`).
  Future<List<CashPosition>> cashPositions(String portfolioId);

  /// Active tenancies' rent beside their unit's asking rent.
  Future<List<RentRollEntry>> rentRoll(String portfolioId);

  /// Properties, units and tenants matching [query] (`search_portfolio`),
  /// the best first; nothing for fewer than 2 or more than 100 letters.
  Future<List<SearchResult>> search(String portfolioId, String query);

  /// The dues that fell due from [from] to [to], oldest first.
  Future<List<ExportCharge>> chargesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  });

  /// The payments received from [from] to [to], oldest first.
  Future<List<ExportPayment>> paymentsBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  });

  /// The expenses spent from [from] to [to], oldest first.
  Future<List<Expense>> expensesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  });
}

/// How many rows an export reads at a time: the most PostgREST returns
/// (`max_rows` in `supabase/config.toml`).
const exportPageSize = 1000;

/// [InsightsRepository] over the report functions and the ledger tables.
final class SupabaseInsightsRepository implements InsightsRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<List<Map<String, dynamic>>> _rows(
    String function,
    Map<String, Object?> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(function, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Dashboard> dashboard(String portfolioId) => _guard(() async {
    final json = await _client.rpc<Object?>(
      'get_dashboard',
      params: {'p_portfolio_id': portfolioId},
    );
    return Dashboard.fromJson(json);
  });

  @override
  Future<List<CashflowMonth>> cashflow(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) => _guard(() async {
    final rows = await _rows('get_cashflow', {
      'p_portfolio_id': portfolioId,
      'p_from': from.toIso(),
      'p_to': to.toIso(),
    });
    return rows.map(CashflowMonth.fromRow).toList();
  });

  @override
  Future<List<PropertyPerformance>> propertyPerformance(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) => _guard(() async {
    final rows = await _rows('get_property_performance', {
      'p_portfolio_id': portfolioId,
      'p_from': from.toIso(),
      'p_to': to.toIso(),
    });
    return rows.map(PropertyPerformance.fromRow).toList();
  });

  @override
  Future<List<PaymentFact>> paymentFacts(String portfolioId) =>
      _guard(() async {
        final rows = await _rows('get_payment_facts', {
          'p_portfolio_id': portfolioId,
        });
        return rows.map(PaymentFact.fromRow).toList();
      });

  @override
  Future<TaxYearStatement> taxYearStatement(
    String portfolioId,
    TaxYear taxYear,
  ) => _guard(() async {
    final rows = await _rows('get_tax_year_statement', {
      'p_portfolio_id': portfolioId,
      'p_tax_year': taxYear.endYear,
    });
    return TaxYearStatement(
      taxYear: taxYear,
      properties: rows.map(TaxYearProperty.fromRow).toList(),
    );
  });

  @override
  Future<List<CashPosition>> cashPositions(String portfolioId) =>
      _guard(() async {
        final rows = await _rows('get_cash_positions', {
          'p_portfolio_id': portfolioId,
        });
        return rows.map(CashPosition.fromRow).toList();
      });

  /// Every row of [table] that [filter] keeps, read [exportPageSize] at a
  /// time in the order of `created_at, id`, so no row is read twice or
  /// missed however many there are.
  Future<List<Map<String, dynamic>>> _all(
    String table,
    String columns,
    PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    )
    filter,
  ) async {
    final rows = <Map<String, dynamic>>[];
    PageCursor? cursor;
    while (true) {
      final page = await filter(_client.from(table).select(columns))
          .after(cursor)
          .order('created_at', ascending: true)
          .order('id', ascending: true)
          .limit(exportPageSize);
      rows.addAll(page);
      if (page.length < exportPageSize) return rows;
      cursor = PageCursor(
        createdAt: page.last['created_at'] as String,
        id: page.last['id'] as String,
      );
    }
  }

  @override
  Future<List<RentRollEntry>> rentRoll(String portfolioId) => _guard(() async {
    final rows = await _all(
      'leases',
      RentRollEntry.columns,
      (query) => query.eq('portfolio_id', portfolioId).eq('status', 'active'),
    );
    return rows.map(RentRollEntry.fromRow).toList();
  });

  @override
  Future<List<SearchResult>> search(String portfolioId, String query) => _guard(
    () async {
      final rows = await _rows('search_portfolio', {
        'p_portfolio_id': portfolioId,
        'p_query': query,
        'p_limit': 20,
      });
      final results = rows.map(SearchResult.fromRow).toList();
      final unitIds = [
        for (final r in results)
          if (r.kind == SearchKind.unit) r.id,
      ];
      if (unitIds.isEmpty) return results;
      // A unit's screen is found under its property.
      final units = await _client
          .from('units')
          .select('id,property_id')
          .eq('portfolio_id', portfolioId)
          .inFilter('id', unitIds);
      final propertyOf = {
        for (final unit in units)
          unit['id'] as String: unit['property_id'] as String,
      };
      return [
        for (final r in results)
          if (r.kind == SearchKind.unit) r.inProperty(propertyOf[r.id]) else r,
      ];
    },
  );

  @override
  Future<List<ExportCharge>> chargesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) => _guard(() async {
    final rows = await _all(
      'charges',
      ExportCharge.columns,
      (query) => query
          .eq('portfolio_id', portfolioId)
          .gte('due_date', from.toIso())
          .lte('due_date', to.toIso()),
    );
    return _sortedBy(rows.map(ExportCharge.fromRow), (c) => c.charge.dueDate);
  });

  @override
  Future<List<ExportPayment>> paymentsBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) => _guard(() async {
    final rows = await _all(
      'payments',
      ExportPayment.columns,
      (query) => query
          .eq('portfolio_id', portfolioId)
          .gte('paid_on', from.toIso())
          .lte('paid_on', to.toIso()),
    );
    return _sortedBy(rows.map(ExportPayment.fromRow), (p) => p.payment.paidOn);
  });

  @override
  Future<List<Expense>> expensesBetween(
    String portfolioId, {
    required CalendarDate from,
    required CalendarDate to,
  }) => _guard(() async {
    final rows = await _all(
      'expenses',
      Expense.columns,
      (query) => query
          .eq('portfolio_id', portfolioId)
          .gte('spent_on', from.toIso())
          .lte('spent_on', to.toIso()),
    );
    return _sortedBy(rows.map(Expense.fromRow), (e) => e.spentOn);
  });
}

/// [rows] by [day], oldest first; rows of one day keep the order they were
/// read in (when they were recorded), so an export is the same every time.
/// `List.sort` alone may reorder equal rows.
List<T> _sortedBy<T>(Iterable<T> rows, CalendarDate Function(T row) day) {
  final indexed = [...rows.indexed]
    ..sort((a, b) {
      final order = day(a.$2).compareTo(day(b.$2));
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, row) in indexed) row];
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => SupabaseInsightsRepository(ref.watch(supabaseClientProvider)),
);
