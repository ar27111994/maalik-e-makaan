import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/money_fakes.dart';
import '../../../../support/operations_fakes.dart';
import '../../../../support/supabase.dart';

/// The rows of each table the mock serves.
Map<String, Object?> _rowOf(String table) => switch (table) {
  'expenses' => plumberExpense.toRow(),
  'utility_accounts' => lescoMeter.toRow(),
  'utility_bills' => novemberBill.toRow(),
  'meter_readings' => {
    ...novemberReading.toRow(),
    'account': lescoMeter.connection.toRow(),
  },
  'maintenance_requests' => seepageJob.toRow(),
  'leases' => aliLease.toRow(),
  'units' => {'id': groundFloor.id},
  'properties' => {
    'id': gulbergHouse.id,
    'name': gulbergHouse.name,
    'units': [
      {'id': groundFloor.id, 'label': groundFloor.label, 'archived_at': null},
    ],
  },
  _ => throw StateError(table),
};

String _table(http.Request request) => request.url.pathSegments.last;

bool _single(http.Request request) =>
    request.headers['accept'] == 'application/vnd.pgrst.object+json';

http.Response _serve(http.Request request) {
  if (request.url.path.contains('/rpc/')) {
    return jsonResponse(aliCharges().first.toRow());
  }
  final row = _rowOf(_table(request));
  return jsonResponse(_single(request) ? row : [row]);
}

void main() {
  late MockSupabase supabase;
  late SupabaseOperationsRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async => _serve(request));
    repository = SupabaseOperationsRepository(
      supabase.client,
      clock: () => DateTime.utc(2026, 11, 7, 5),
    );
  });

  Map<String, String> query([int back = 1]) =>
      supabase.requests[supabase.requests.length - back].url.queryParameters;

  test('places are the properties in use with their units, by name', () async {
    final places = await repository.places(gulberg.id);
    expect(places.single.units.single.label, groundFloor.label);
    expect(query(), {
      'select': PropertyPlace.columns,
      'portfolio_id': 'eq.${gulberg.id}',
      'archived_at': 'is.null',
      'order': 'name.asc.nullslast,id.asc.nullslast',
      'units.order': 'label.asc.nullslast',
    });
  });

  test('tenancies of a unit, or of every unit of a property', () async {
    final ofUnit = await repository.tenancies(
      propertyId: gulbergHouse.id,
      unitId: groundFloor.id,
    );
    expect(ofUnit.single.id, aliLease.id);
    expect(supabase.requests, hasLength(1));
    expect(query(), {
      'select': Lease.columns,
      'unit_id': 'in.("${groundFloor.id}")',
      'order': 'start_date.desc.nullslast,id.desc.nullslast',
      'limit': '50',
    });
    await repository.tenancies(propertyId: gulbergHouse.id);
    expect(query(2), {'select': 'id', 'property_id': 'eq.${gulbergHouse.id}'});
    supabase.respond = (request) async =>
        _table(request) == 'units' ? jsonResponse([]) : _serve(request);
    expect(await repository.tenancies(propertyId: 'empty'), isEmpty);
    expect(_table(supabase.requests.last), 'units');
  });

  group('expenses', () {
    test('are read a page at a time, newest first, by job too', () async {
      final page = await repository.expenses(gulberg.id);
      expect(page.items.single, plumberExpense);
      expect(page.hasMore, isFalse);
      expect(query(), {
        'select': Expense.columns,
        'portfolio_id': 'eq.${gulberg.id}',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      await repository.expenses(
        gulberg.id,
        maintenanceRequestId: seepageJob.id,
        before: const PageCursor(createdAt: 'x', id: 'y'),
      );
      expect(query()['maintenance_request_id'], 'eq.${seepageJob.id}');
      expect(
        query()['or'],
        '(created_at.lt."x",and(created_at.eq."x",id.lt."y"))',
      );
      expect(await repository.expense(plumberExpense.id), plumberExpense);
      expect(query()['id'], 'eq.${plumberExpense.id}');
    });

    test('are added once, saved and deleted', () async {
      final draft = ExpenseDraft.of(plumberExpense);
      await repository.createExpense(
        id: 'e1',
        portfolioId: gulberg.id,
        draft: draft,
      );
      final insert = supabase.requests.last;
      expect(insert.method, 'POST');
      // The insert grant's columns: who paid is the database's to record.
      final columns = {
        'property_id': gulbergHouse.id,
        'unit_id': groundFloor.id,
        'maintenance_request_id': seepageJob.id,
        'category': 'repairs_maintenance',
        'amount': '4500.00',
        'spent_on': '2026-11-05',
        'payee': 'Aslam Plumber',
        'method': 'cash',
        'reference': null,
        'notes': null,
      };
      expect(bodyOf(insert), {
        'id': 'e1',
        'portfolio_id': gulberg.id,
        ...columns,
      });
      expect(insert.url.queryParameters['select'], Expense.columns);
      // A retry that reached the server returns what it stored.
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : _serve(request);
      expect(
        (await repository.createExpense(
          id: 'e1',
          portfolioId: gulberg.id,
          draft: draft,
        )).id,
        plumberExpense.id,
      );
      // A clash with no row of that id is refused.
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse([]);
      await expectLater(
        repository.createExpense(
          id: 'e2',
          portfolioId: gulberg.id,
          draft: draft,
        ),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
      expect(supabase.requests.last.method, 'GET');
      expect(query()['id'], 'eq.e2');
      supabase.respond = (request) async => _serve(request);
      await repository.updateExpense(plumberExpense.id, draft);
      expect(supabase.requests.last.method, 'PATCH');
      expect(bodyOf(supabase.requests.last), columns);
      expect(query()['id'], 'eq.${plumberExpense.id}');
      await repository.deleteExpense(plumberExpense.id);
      expect(supabase.requests.last.method, 'DELETE');
      expect(query(), {'id': 'eq.${plumberExpense.id}', 'select': 'id'});
      // Row security hid it from the delete.
      supabase.respond = (_) async => jsonResponse([]);
      await expectLater(
        repository.deleteExpense('x'),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async => postgrestError('42501', status: 403);
      await expectLater(
        repository.updateExpense('x', draft),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async => postgrestError('23514');
      await expectLater(
        repository.createExpense(
          id: 'e3',
          portfolioId: gulberg.id,
          draft: draft,
        ),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
    });
  });

  group('utilities', () {
    test('connections are read in use or archived, oldest first', () async {
      await repository.utilityAccounts(gulberg.id, archived: false);
      expect(query(), {
        'select': UtilityAccount.columns,
        'portfolio_id': 'eq.${gulberg.id}',
        'archived_at': 'is.null',
        'order': 'created_at.asc.nullslast,id.asc.nullslast',
        'limit': '50',
      });
      await repository.utilityAccounts(
        gulberg.id,
        archived: true,
        after: const PageCursor(createdAt: 'x', id: 'y'),
      );
      expect(query()['archived_at'], 'not.is.null');
      expect(
        query()['or'],
        '(created_at.gt."x",and(created_at.eq."x",id.gt."y"))',
      );
    });

    test('unpaid bills come earliest due first', () async {
      final bills = await repository.unpaidBills(gulberg.id);
      expect(bills.single, novemberBill);
      expect(query(), {
        'select': UtilityBill.columns,
        'portfolio_id': 'eq.${gulberg.id}',
        'status': 'eq.unpaid',
        'order':
            'due_date.asc.nullslast,billing_month.asc.nullslast,'
            'id.asc.nullslast',
        'limit': '50',
      });
    });

    test('a connection comes with its first bills and readings', () async {
      final detail = await repository.utilityAccount(lescoMeter.id);
      expect(detail.account, lescoMeter);
      expect(detail.bills.items.single, novemberBill);
      expect(detail.readings.items.single, novemberReading);
      final tables = [for (final r in supabase.requests) _table(r)];
      expect(tables, containsAll(['utility_accounts', 'utility_bills']));
      final bills = supabase.requests.firstWhere(
        (r) => _table(r) == 'utility_bills',
      );
      expect(bills.url.queryParameters, {
        'select': UtilityBill.columns,
        'utility_account_id': 'eq.${lescoMeter.id}',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      const cursor = PageCursor(createdAt: 'x', id: 'y');
      await repository.bills(lescoMeter.id, before: cursor);
      expect(
        query()['or'],
        '(created_at.lt."x",and(created_at.eq."x",id.lt."y"))',
      );
      await repository.readings(lescoMeter.id, before: cursor);
      expect(query()['select'], MeterReading.columns);
    });

    test('connections are added, saved, archived and deleted; a number in '
        'use is refused', () async {
      const draft = UtilityAccountDraft(
        propertyId: 'p',
        type: UtilityType.electricity,
        provider: UtilityProvider.lesco,
        referenceNumber: '09269330553008',
      );
      await repository.createUtilityAccount(
        id: 'a1',
        portfolioId: gulberg.id,
        draft: draft,
      );
      final columns = {
        'unit_id': null,
        'type': 'electricity',
        'provider': 'lesco',
        'provider_other': null,
        'reference_number': '09269330553008',
        'customer_id': null,
        'meter_number': null,
        'account_title': null,
        'in_landlord_name': true,
        'is_sub_meter': false,
        'is_protected_consumer': false,
        'responsibility': 'tenant',
        'notes': null,
      };
      expect(bodyOf(supabase.requests.last), {
        'id': 'a1',
        'portfolio_id': gulberg.id,
        'property_id': 'p',
        ...columns,
      });
      // The property is fixed once added (no update grant on it).
      await repository.updateUtilityAccount('a1', draft);
      expect(bodyOf(supabase.requests.last), columns);
      await repository.archiveUtilityAccount('a1', archived: true);
      expect(bodyOf(supabase.requests.last), {
        'archived_at': '2026-11-07T05:00:00.000Z',
      });
      await repository.archiveUtilityAccount('a1', archived: false);
      expect(bodyOf(supabase.requests.last), {'archived_at': null});
      await repository.deleteUtilityAccount('a1');
      expect(supabase.requests.last.method, 'DELETE');
      Matcher refused(String reason) => throwsA(
        isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
      );
      // The retry's read finds no row of this id: another row's number.
      supabase.respond = (request) async => switch (request.method) {
        'POST' || 'PATCH' => postgrestError('23505', status: 409),
        _ => jsonResponse([]),
      };
      await expectLater(
        repository.createUtilityAccount(
          id: 'a2',
          portfolioId: gulberg.id,
          draft: draft,
        ),
        refused('duplicate_utility_reference'),
      );
      await expectLater(
        repository.updateUtilityAccount('a2', draft),
        refused('duplicate_utility_reference'),
      );
      await expectLater(
        repository.archiveUtilityAccount('a2', archived: false),
        refused('duplicate_utility_reference'),
      );
    });

    test('bills are added once per month, saved, deleted and billed to a '
        'tenant', () async {
      final draft = BillDraft(
        billingMonth: MonthPeriod(2026, 11),
        amount: const Money.fromRupees(9850),
      );
      await repository.createBill(
        id: 'b1',
        portfolioId: gulberg.id,
        accountId: lescoMeter.id,
        draft: draft,
      );
      expect(bodyOf(supabase.requests.last), {
        'id': 'b1',
        'portfolio_id': gulberg.id,
        'utility_account_id': lescoMeter.id,
        'billing_month': '2026-11-01',
        'amount': '9850.00',
        'due_date': null,
        'units_consumed': null,
        'status': 'unpaid',
        'paid_on': null,
        'paid_by': null,
        'notes': null,
      });
      expect(await repository.bill(novemberBill.id), novemberBill);
      // Saving writes the details; the month and whether it is paid stay.
      await repository.updateBill('b1', draft);
      expect(bodyOf(supabase.requests.last), {
        'amount': '9850.00',
        'due_date': null,
        'units_consumed': null,
        'notes': null,
      });
      // Marking it paid or unpaid writes only that, whatever the screen's
      // copy of the bill held.
      final paid = await repository.setBillPayment(
        'b1',
        BillPayment(
          paidOn: CalendarDate(2026, 11, 6),
          paidBy: BillPayer.tenant,
        ),
      );
      expect(paid, novemberBill);
      expect(supabase.requests.last.method, 'PATCH');
      expect(query(), {'id': 'eq.b1', 'select': UtilityBill.columns});
      expect(bodyOf(supabase.requests.last), {
        'status': 'paid',
        'paid_on': '2026-11-06',
        'paid_by': 'tenant',
      });
      await repository.setBillPayment('b1', const BillPayment.unpaid());
      expect(bodyOf(supabase.requests.last), {
        'status': 'unpaid',
        'paid_on': null,
        'paid_by': null,
      });
      await repository.deleteBill('b1');
      expect(supabase.requests.last.method, 'DELETE');
      final charge = await repository.billToTenant('b1', aliLease.id);
      expect(charge.id, aliCharges().first.id);
      expect(
        supabase.requests.last.url.path,
        endsWith('/rpc/bill_utility_to_tenant'),
      );
      expect(bodyOf(supabase.requests.last), {
        'p_bill_id': 'b1',
        'p_lease_id': aliLease.id,
      });
      supabase.respond = (request) async => switch (request.method) {
        'POST' => postgrestError('23505', status: 409),
        _ => jsonResponse([]),
      };
      await expectLater(
        repository.createBill(
          id: 'b2',
          portfolioId: gulberg.id,
          accountId: lescoMeter.id,
          draft: draft,
        ),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_bill_month',
          ),
        ),
      );
      supabase.respond = (_) async =>
          postgrestError('22023', message: 'lease_not_on_this_connection');
      await expectLater(
        repository.billToTenant('b1', endedLease.id),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'lease_not_on_this_connection',
          ),
        ),
      );
      supabase.respond = (_) async => postgrestError('23505', status: 409);
      await expectLater(
        repository.updateBill('b1', draft),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
    });

    test('a reading comes with its connection and the one before it', () async {
      final detail = await repository.reading(novemberReading.id);
      expect(detail.reading, novemberReading);
      expect(detail.connection, lescoMeter.connection);
      expect(detail.previous, novemberReading);
      final previous = supabase.requests.last.url.queryParameters;
      expect(previous['utility_account_id'], 'eq.${lescoMeter.id}');
      expect(previous['id'], 'neq.${novemberReading.id}');
      expect(
        previous['or'],
        '(read_on.lt."2026-11-01",'
        'and(read_on.eq."2026-11-01",'
        'created_at.lt."${novemberReading.createdAt}"))',
      );
      expect(
        previous['order'],
        'read_on.desc.nullslast,created_at.desc.nullslast',
      );
      expect(previous['limit'], '1');
      supabase.respond = (request) async =>
          request.url.queryParameters.containsKey('or')
          ? jsonResponse([])
          : _serve(request);
      expect((await repository.reading(novemberReading.id)).previous, isNull);
    });

    test('readings are added, saved and deleted', () async {
      final draft = ReadingDraft(
        reading: const Hundredths(1220500),
        readOn: CalendarDate(2026, 11, 1),
      );
      await repository.createReading(
        id: 'r1',
        portfolioId: gulberg.id,
        accountId: lescoMeter.id,
        draft: draft,
      );
      expect(bodyOf(supabase.requests.last), {
        'id': 'r1',
        'portfolio_id': gulberg.id,
        'utility_account_id': lescoMeter.id,
        'lease_id': null,
        'reading': '12205',
        'read_on': '2026-11-01',
        'context': 'other',
        'notes': null,
      });
      // Its connection and tenancy are fixed once added.
      await repository.updateReading('r1', draft);
      expect(bodyOf(supabase.requests.last), {
        'reading': '12205',
        'read_on': '2026-11-01',
        'context': 'other',
        'notes': null,
      });
      await repository.deleteReading('r1');
      expect(supabase.requests.last.method, 'DELETE');
    });
  });

  group('maintenance', () {
    test('requests are read to do or closed, newest first', () async {
      await repository.maintenanceRequests(gulberg.id, pending: true);
      expect(query(), {
        'select': MaintenanceRequest.columns,
        'portfolio_id': 'eq.${gulberg.id}',
        'status': 'in.("open","in_progress","on_hold")',
        'order': 'created_at.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      await repository.maintenanceRequests(
        gulberg.id,
        pending: false,
        before: const PageCursor(createdAt: 'x', id: 'y'),
      );
      expect(query()['status'], 'in.("resolved","cancelled")');
      expect(
        query()['or'],
        '(created_at.lt."x",and(created_at.eq."x",id.lt."y"))',
      );
      expect(await repository.maintenanceRequest(seepageJob.id), seepageJob);
    });

    test('requests are added, saved and deleted unless expenses name '
        'them', () async {
      final draft = MaintenanceDraft.of(seepageJob);
      await repository.createMaintenanceRequest(
        id: 'm1',
        portfolioId: gulberg.id,
        draft: draft,
      );
      final columns = {
        'unit_id': groundFloor.id,
        'lease_id': aliLease.id,
        'title': 'Seepage in the bedroom wall',
        'description':
            'Damp patch under the bathroom, spreading since the rains.',
        'category': 'seepage',
        'priority': 'urgent',
        'status': 'in_progress',
        'reported_by': 'Ali Raza',
        'reported_on': '2026-11-02',
        'assigned_to': 'Aslam Plumber',
        'vendor_phone': '+923001112233',
        'estimated_cost': '12000.00',
        'resolved_on': null,
        'resolution_note': null,
      };
      expect(bodyOf(supabase.requests.last), {
        'id': 'm1',
        'portfolio_id': gulberg.id,
        'property_id': gulbergHouse.id,
        ...columns,
      });
      // The property is fixed once added (no update grant on it).
      await repository.updateMaintenanceRequest('m1', draft);
      expect(bodyOf(supabase.requests.last), columns);
      // A move writes only the status, and when and how it was resolved.
      final moved = await repository.moveMaintenanceRequest(
        'm1',
        MaintenanceMove(
          MaintenanceStatus.resolved,
          resolvedOn: CalendarDate(2026, 11, 7),
          resolutionNote: 'Wall sealed',
        ),
      );
      expect(moved, seepageJob);
      expect(supabase.requests.last.method, 'PATCH');
      expect(query(), {'id': 'eq.m1', 'select': MaintenanceRequest.columns});
      expect(bodyOf(supabase.requests.last), {
        'status': 'resolved',
        'resolved_on': '2026-11-07',
        'resolution_note': 'Wall sealed',
      });
      await repository.moveMaintenanceRequest(
        'm1',
        const MaintenanceMove(MaintenanceStatus.onHold),
      );
      expect(bodyOf(supabase.requests.last), {
        'status': 'on_hold',
        'resolved_on': null,
        'resolution_note': null,
      });
      await repository.deleteMaintenanceRequest('m1');
      expect(supabase.requests.last.method, 'DELETE');
      supabase.respond = (_) async => postgrestError('23503', status: 409);
      await expectLater(
        repository.deleteMaintenanceRequest('m1'),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'request_has_expenses',
          ),
        ),
      );
      // Elsewhere a foreign key is a plain constraint violation.
      await expectLater(
        repository.deleteExpense('e1'),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
    });
  });

  test('a lost connection is a network failure', () async {
    supabase.respond = (_) async => throw http.ClientException('offline');
    await expectLater(
      repository.places(gulberg.id),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      repository.expenses(gulberg.id),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('a malformed row is the server and the app disagreeing', () async {
    supabase.respond = (_) async => jsonResponse([
      {'id': 'x'},
    ]);
    await expectLater(
      repository.maintenanceRequests(gulberg.id, pending: true),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('the provider builds the Supabase repository', () {
    expect(operationsRepositoryProvider, isNotNull);
  });
}
