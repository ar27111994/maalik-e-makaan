import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/insights_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';
import '../../../../support/supabase.dart';

void main() {
  late MockSupabase supabase;
  late SupabaseInsightsRepository repository;
  late Map<String, Object? Function(http.Request request)> answers;

  setUp(() {
    answers = {};
    supabase = MockSupabase((request) async {
      final segment = request.url.pathSegments.last;
      final answer = answers[segment];
      if (answer == null) return jsonResponse(<Object?>[]);
      final body = answer(request);
      return body is http.Response ? body : jsonResponse(body);
    });
    repository = SupabaseInsightsRepository(supabase.client);
  });

  final from = CalendarDate(2025, 12, 1);
  final to = CalendarDate(2026, 11, 30);

  test('the dashboard is one call of get_dashboard', () async {
    answers['get_dashboard'] = (_) => dashboardJson();
    final dashboard = await repository.dashboard(gulberg.id);
    expect(dashboard.topArrears, hasLength(2));
    expect(supabase.request.url.path, '/rest/v1/rpc/get_dashboard');
    expect(bodyOf(supabase.request), {'p_portfolio_id': gulberg.id});
  });

  test('the cash flow and performance send their span', () async {
    answers['get_cashflow'] = (_) => [
      cashflowJson(MonthPeriod(2026, 10), 1),
      cashflowJson(MonthPeriod(2026, 11), 2),
    ];
    answers['get_property_performance'] = (_) => performanceJson();
    final months = await repository.cashflow(gulberg.id, from: from, to: to);
    expect(months.map((m) => m.month), [
      MonthPeriod(2026, 10),
      MonthPeriod(2026, 11),
    ]);
    expect(bodyOf(supabase.requests.last), {
      'p_portfolio_id': gulberg.id,
      'p_from': '2025-12-01',
      'p_to': '2026-11-30',
    });
    final properties = await repository.propertyPerformance(
      gulberg.id,
      from: from,
      to: to,
    );
    expect(properties.first.propertyName, 'Gulberg House');
    expect(
      supabase.requests.last.url.path,
      '/rest/v1/rpc/get_property_performance',
    );
    expect(bodyOf(supabase.requests.last), {
      'p_portfolio_id': gulberg.id,
      'p_from': '2025-12-01',
      'p_to': '2026-11-30',
    });
  });

  test('payment facts, the tax year and cash positions', () async {
    answers['get_payment_facts'] = (_) => factsJson();
    answers['get_tax_year_statement'] = (_) => taxYearJson();
    answers['get_cash_positions'] = (_) => [
      {
        'user_id': caretakerId,
        'full_name': 'Bilal Ahmed',
        'role': 'manager',
        'cash_collected': 255000,
        'handed_over': 170000,
        'cash_expenses': 4500,
        'cash_in_hand': 80500,
      },
    ];
    expect(await repository.paymentFacts(gulberg.id), hasLength(7));
    expect(bodyOf(supabase.requests.last), {'p_portfolio_id': gulberg.id});
    final statement = await repository.taxYearStatement(
      gulberg.id,
      TaxYear(2026),
    );
    expect(statement.taxYear, TaxYear(2026));
    expect(statement.properties, hasLength(2));
    expect(bodyOf(supabase.requests.last), {
      'p_portfolio_id': gulberg.id,
      'p_tax_year': 2026,
    });
    final positions = await repository.cashPositions(gulberg.id);
    expect(positions.single.inHand, const Money.fromRupees(80500));
  });

  test('a search finds the property of each unit', () async {
    answers['search_portfolio'] = (_) => searchJson();
    answers['units'] = (_) => [
      {'id': annexe.id, 'property_id': gulbergHouse.id},
    ];
    final results = await repository.search(gulberg.id, 'ali');
    expect(bodyOf(supabase.requests.first), {
      'p_portfolio_id': gulberg.id,
      'p_query': 'ali',
      'p_limit': 20,
    });
    final units = supabase.requests.last.url;
    expect(units.path, '/rest/v1/units');
    expect(units.queryParameters['select'], 'id,property_id');
    expect(units.queryParameters['portfolio_id'], 'eq.${gulberg.id}');
    expect(units.queryParameters['id'], 'in.("${annexe.id}")');
    expect(results.map((r) => r.propertyId), [null, null, gulbergHouse.id]);
  });

  test('a search without units reads nothing more', () async {
    answers['search_portfolio'] = (_) => searchJson().take(2).toList();
    final results = await repository.search(gulberg.id, 'gul');
    expect(results, hasLength(2));
    expect(supabase.requests, hasLength(1));
  });

  test('the rent roll reads active tenancies of the portfolio', () async {
    answers['leases'] = (_) => rentRollJson();
    final roll = await repository.rentRoll(gulberg.id);
    expect(roll.first.askingRent, const Money.fromRupees(100000));
    final url = supabase.request.url;
    expect(url.queryParameters['portfolio_id'], 'eq.${gulberg.id}');
    expect(url.queryParameters['status'], 'eq.active');
    expect(
      url.queryParameters['order'],
      'created_at.asc.nullslast,id.asc.nullslast',
    );
    expect(url.queryParameters['limit'], '$exportPageSize');
  });

  test('exports read every row, a full page at a time', () async {
    final expense = plumberExpense.toRow();
    var page = 0;
    answers['expenses'] = (_) {
      page++;
      // A first full page, then the rest.
      final count = page == 1 ? exportPageSize : 2;
      return [
        for (var i = 0; i < count; i++)
          {
            ...expense,
            'id': 'e-$page-$i',
            'spent_on': page == 1 ? '2026-10-0${i % 9 + 1}' : '2026-09-30',
            'created_at': '2026-10-01T00:00:0${i % 10}+00:00',
          },
      ];
    };
    final expenses = await repository.expensesBetween(
      gulberg.id,
      from: from,
      to: to,
    );
    expect(expenses, hasLength(exportPageSize + 2));
    // Oldest first, whatever order they were read in.
    expect(expenses.first.spentOn, CalendarDate(2026, 9, 30));
    expect(supabase.requests, hasLength(2));
    final first = supabase.requests.first.url;
    expect(first.queryParametersAll['spent_on'], [
      'gte.2025-12-01',
      'lte.2026-11-30',
    ]);
    expect(first.queryParameters['or'], isNull);
    final second = supabase.requests.last.url;
    expect(
      second.queryParameters['or'],
      '(created_at.gt."2026-10-01T00:00:09+00:00",'
      'and(created_at.eq."2026-10-01T00:00:09+00:00",id.gt."e-1-999"))',
    );
  });

  group('every export reads only its portfolio, in recorded order', () {
    final expense = plumberExpense.toRow();
    final ledger = FakeLedgerRepository();
    final charge = ledger.chargesOf[aliLease.id]!.first.toRow();
    final payment = ledger.paymentsOf[aliLease.id]!.first.toRow();
    const tenancy = {
      'tenant': {'full_name': 'Ali Raza'},
      'unit': {
        'label': 'Ground floor',
        'property': {'name': 'Gulberg House'},
      },
    };

    for (final (table, columns, day, row, read) in [
      (
        'charges',
        ExportCharge.columns,
        'due_date',
        {...charge, 'lease': tenancy},
        (SupabaseInsightsRepository r) =>
            r.chargesBetween(gulberg.id, from: from, to: to),
      ),
      (
        'payments',
        ExportPayment.columns,
        'paid_on',
        {...payment, 'lease': tenancy},
        (SupabaseInsightsRepository r) =>
            r.paymentsBetween(gulberg.id, from: from, to: to),
      ),
      (
        'expenses',
        Expense.columns,
        'spent_on',
        expense,
        (SupabaseInsightsRepository r) =>
            r.expensesBetween(gulberg.id, from: from, to: to),
      ),
    ]) {
      test(table, () async {
        var page = 0;
        answers[table] = (_) {
          page++;
          final count = page == 1 ? exportPageSize : 3;
          return [
            for (var i = 0; i < count; i++)
              {
                ...row,
                'id': '$table-$page-${i.toString().padLeft(4, '0')}',
                // Every row of one day: they keep the order they were read
                // in, which is the order they were recorded.
                day: '2026-10-01',
                'created_at': '2026-10-01T00:00:00+00:00',
              },
          ];
        };
        final rows = await read(repository);
        expect(rows, hasLength(exportPageSize + 3));
        expect(supabase.requests, hasLength(2));
        for (final (index, request) in supabase.requests.indexed) {
          final url = request.url;
          expect(url.path, '/rest/v1/$table');
          expect(url.queryParameters['select'], columns);
          expect(url.queryParameters['portfolio_id'], 'eq.${gulberg.id}');
          expect(url.queryParametersAll[day], [
            'gte.2025-12-01',
            'lte.2026-11-30',
          ]);
          expect(
            url.queryParameters['order'],
            'created_at.asc.nullslast,id.asc.nullslast',
          );
          expect(url.queryParameters['limit'], '$exportPageSize');
          expect(
            url.queryParameters['or'],
            index == 0
                ? isNull
                : '(created_at.gt."2026-10-01T00:00:00+00:00",'
                      'and(created_at.eq."2026-10-01T00:00:00+00:00",'
                      'id.gt."$table-1-0999"))',
          );
        }
        final ids = [
          for (final r in rows)
            switch (r) {
              final ExportCharge c => c.charge.id,
              final ExportPayment p => p.payment.id,
              final Expense e => e.id,
              _ => throw StateError('$r'),
            },
        ];
        expect(ids.first, '$table-1-0000');
        expect(ids.last, '$table-2-0002');
        expect(ids, [...ids]..sort());
      });
    }
  });

  test('dues and payments come with their tenancy', () async {
    final ledger = FakeLedgerRepository();
    final charge = ledger.chargesOf[aliLease.id]!.first;
    final payment = ledger.paymentsOf[aliLease.id]!.first;
    final tenancy = {
      'tenant': {'full_name': 'Ali Raza'},
      'unit': {
        'label': 'Ground floor',
        'property': {'name': 'Gulberg House'},
      },
    };
    answers['charges'] = (_) => [
      {...charge.toRow(), 'lease': tenancy},
    ];
    answers['payments'] = (_) => [
      {...payment.toRow(), 'lease': tenancy},
    ];
    final charges = await repository.chargesBetween(
      gulberg.id,
      from: from,
      to: to,
    );
    expect(charges.single.charge, charge);
    final select = supabase.requests.last.url.queryParameters['select']!;
    expect(select, contains('lease:leases!charges_lease_fkey('));
    expect(
      supabase.requests.last.url.query,
      allOf(contains('due_date=gte.2025-12-01'), contains('due_date=lte.')),
    );
    final payments = await repository.paymentsBetween(
      gulberg.id,
      from: from,
      to: to,
    );
    expect(payments.single.tenancy.unitLabel, 'Ground floor');
    expect(
      supabase.requests.last.url.query,
      allOf(contains('paid_on=gte.2025-12-01'), contains('paid_on=lte.')),
    );
  });

  group('failures', () {
    test('a member of another portfolio is forbidden', () async {
      answers['get_dashboard'] = (_) =>
          postgrestError('42501', status: 403, message: 'forbidden');
      await expectLater(
        repository.dashboard(gulberg.id),
        throwsA(isA<Forbidden>()),
      );
    });

    test('refusals keep their reason', () async {
      answers['get_cashflow'] = (_) =>
          postgrestError('22023', message: 'invalid_date');
      answers['get_tax_year_statement'] = (_) =>
          postgrestError('22023', message: 'invalid_tax_year');
      await expectLater(
        repository.cashflow(gulberg.id, from: to, to: from),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'invalid_date',
          ),
        ),
      );
      await expectLater(
        repository.taxYearStatement(gulberg.id, TaxYear(1990)),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'invalid_tax_year',
          ),
        ),
      );
    });

    test('an answer the app cannot read is the server failing', () async {
      answers['get_dashboard'] = (_) => {'as_of': '2026-11-07'};
      answers['get_property_performance'] = (_) => [
        {...performanceJson().first, 'gross_yield': 'high'},
      ];
      answers['search_portfolio'] = (_) => searchJson();
      answers['units'] = (_) => http.Response('oops', 500);
      await expectLater(
        repository.dashboard(gulberg.id),
        throwsA(isA<ServerFailure>()),
      );
      await expectLater(
        repository.propertyPerformance(gulberg.id, from: from, to: to),
        throwsA(isA<ServerFailure>()),
      );
      await expectLater(
        repository.search(gulberg.id, 'ali'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a lost connection is a network failure', () async {
      supabase.respond = (_) async => throw http.ClientException('offline');
      for (final read in <Future<Object?> Function()>[
        () => repository.paymentFacts(gulberg.id),
        () => repository.cashPositions(gulberg.id),
        () => repository.rentRoll(gulberg.id),
        () => repository.chargesBetween(gulberg.id, from: from, to: to),
        () => repository.paymentsBetween(gulberg.id, from: from, to: to),
      ]) {
        await expectLater(read(), throwsA(isA<NetworkFailure>()));
      }
    });
  });

  test('the provider reads through the Supabase client', () {
    final container = ProviderContainer.test(
      overrides: [supabaseClientProvider.overrideWithValue(supabase.client)],
    );
    expect(
      container.read(insightsRepositoryProvider),
      isA<SupabaseInsightsRepository>(),
    );
  });
}
