import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Expenses, utility connections with their bills and meter readings, and
/// maintenance requests. Every method throws [AppFailure].
///
/// Who may do what (docs/architecture/permissions.md, Operations): owners,
/// managers and accountants add and edit expenses, bills and readings, and
/// bill a utility to a tenant; owners and managers delete them, and add,
/// edit and delete connections and maintenance requests; only owners
/// delete a connection. Row security has the last word.
abstract interface class OperationsRepository {
  /// The properties in use of [portfolioId] and their units in use, by
  /// name, to choose from.
  Future<List<PropertyPlace>> places(String portfolioId);

  /// The tenancies of [unitId], or of every unit of [propertyId] when it is
  /// null, the newest first.
  Future<List<Lease>> tenancies({required String propertyId, String? unitId});

  /// A page of [portfolioId]'s expenses (only [maintenanceRequestId]'s when
  /// given) before [before], the latest recorded first.
  Future<Paged<Expense>> expenses(
    String portfolioId, {
    String? maintenanceRequestId,
    PageCursor? before,
  });

  Future<Expense> expense(String expenseId);

  /// Adds [draft] under the id chosen for this attempt, so a retry adds
  /// nothing more. Refusal: `constraint_violation`.
  Future<Expense> createExpense({
    required String id,
    required String portfolioId,
    required ExpenseDraft draft,
  });

  Future<Expense> updateExpense(String expenseId, ExpenseDraft draft);

  Future<void> deleteExpense(String expenseId);

  /// A page of [portfolioId]'s connections, archived or in use, oldest
  /// first.
  Future<Paged<UtilityAccount>> utilityAccounts(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  });

  /// The unpaid bills of [portfolioId], the earliest due first (at most
  /// [pageSize]).
  Future<List<UtilityBill>> unpaidBills(String portfolioId);

  /// A connection with the first pages of its bills and readings.
  Future<UtilityAccountDetail> utilityAccount(String accountId);

  /// Refusals: `duplicate_utility_reference` (another connection in use of
  /// this type has the number), `constraint_violation`.
  Future<UtilityAccount> createUtilityAccount({
    required String id,
    required String portfolioId,
    required UtilityAccountDraft draft,
  });

  Future<UtilityAccount> updateUtilityAccount(
    String accountId,
    UtilityAccountDraft draft,
  );

  /// Archives the connection (or puts it back in use).
  Future<UtilityAccount> archiveUtilityAccount(
    String accountId, {
    required bool archived,
  });

  /// Deletes a connection added by mistake, with its bills and readings.
  Future<void> deleteUtilityAccount(String accountId);

  /// A page of [accountId]'s bills before [before], the latest recorded
  /// first.
  Future<Paged<UtilityBill>> bills(String accountId, {PageCursor? before});

  Future<UtilityBill> bill(String billId);

  /// Refusals: `duplicate_bill_month` (the connection has that month's
  /// bill), `constraint_violation`.
  Future<UtilityBill> createBill({
    required String id,
    required String portfolioId,
    required String accountId,
    required BillDraft draft,
  });

  /// Saves the bill's details; whether it is paid is left as stored.
  Future<UtilityBill> updateBill(String billId, BillDraft draft);

  /// Marks the bill paid or unpaid, writing only that.
  Future<UtilityBill> setBillPayment(String billId, BillPayment payment);

  Future<void> deleteBill(String billId);

  /// Puts the bill on [leaseId]'s ledger (`bill_utility_to_tenant`), or
  /// returns the live charge it is already on. Refusals:
  /// `lease_not_on_this_connection`, `invalid_amount` (a bill of zero).
  Future<Charge> billToTenant(String billId, String leaseId);

  /// A page of [accountId]'s readings before [before], the latest recorded
  /// first.
  Future<Paged<MeterReading>> readings(String accountId, {PageCursor? before});

  /// A reading with its connection and the reading before it in time.
  Future<ReadingDetail> reading(String readingId);

  Future<MeterReading> createReading({
    required String id,
    required String portfolioId,
    required String accountId,
    required ReadingDraft draft,
  });

  Future<MeterReading> updateReading(String readingId, ReadingDraft draft);

  Future<void> deleteReading(String readingId);

  /// A page of [portfolioId]'s requests still to be done ([pending]) or
  /// closed, before [before], the latest reported first.
  Future<Paged<MaintenanceRequest>> maintenanceRequests(
    String portfolioId, {
    required bool pending,
    PageCursor? before,
  });

  Future<MaintenanceRequest> maintenanceRequest(String requestId);

  Future<MaintenanceRequest> createMaintenanceRequest({
    required String id,
    required String portfolioId,
    required MaintenanceDraft draft,
  });

  Future<MaintenanceRequest> updateMaintenanceRequest(
    String requestId,
    MaintenanceDraft draft,
  );

  /// Moves the request along its workflow, writing only its status (and
  /// when and how it was resolved).
  Future<MaintenanceRequest> moveMaintenanceRequest(
    String requestId,
    MaintenanceMove move,
  );

  /// Deletes a request; one with expenses recorded against it is refused
  /// (`request_has_expenses`).
  Future<void> deleteMaintenanceRequest(String requestId);
}

/// [OperationsRepository] over `expenses`, `utility_accounts`,
/// `utility_bills`, `meter_readings`, `maintenance_requests` and
/// `bill_utility_to_tenant`.
final class SupabaseOperationsRepository implements OperationsRepository {
  new(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// Inserts [row] (with its client-chosen `id`) into [table] and reads it
  /// back. A unique violation is either a retry of the same insert, which
  /// returns the row already there, or a clash with another row, refused
  /// as [duplicate].
  Future<Map<String, dynamic>> _insert(
    String table,
    Map<String, Object?> row,
    String columns, {
    String? duplicate,
  }) async {
    try {
      return await _client.from(table).insert(row).select(columns).single();
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await _client
          .from(table)
          .select(columns)
          .eq('id', row['id']!)
          .maybeSingle();
      if (existing != null) return existing;
      throw RejectedFailure(duplicate ?? 'constraint_violation');
    }
  }

  /// Updates [id] of [table] with [values] and reads it back; a unique
  /// violation is refused as [duplicate].
  Future<Map<String, dynamic>> _update(
    String table,
    String id,
    Map<String, Object?> values,
    String columns, {
    String? duplicate,
  }) async {
    try {
      return await _client
          .from(table)
          .update(values)
          .eq('id', id)
          .select(columns)
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw RejectedFailure(duplicate ?? 'constraint_violation');
      }
      rethrow;
    }
  }

  /// Deletes [id] of [table]. A row something still refers to is refused
  /// as [inUse]; a row the caller may not delete (row security hides it
  /// from the delete) is [Forbidden].
  Future<void> _delete(String table, String id, {String? inUse}) async {
    try {
      final deleted = await _client
          .from(table)
          .delete()
          .eq('id', id)
          .select('id');
      if (deleted.isEmpty) throw const Forbidden();
    } on PostgrestException catch (error) {
      if (error.code == '23503' && inUse != null) {
        throw RejectedFailure(inUse);
      }
      rethrow;
    }
  }

  @override
  Future<List<PropertyPlace>> places(String portfolioId) => _guard(() async {
    final rows = await _client
        .from('properties')
        .select(PropertyPlace.columns)
        .eq('portfolio_id', portfolioId)
        .isFilter('archived_at', null)
        .order('name', ascending: true)
        .order('id', ascending: true)
        .order('label', ascending: true, referencedTable: 'units');
    return rows.map(PropertyPlace.fromRow).toList();
  });

  @override
  Future<List<Lease>> tenancies({required String propertyId, String? unitId}) =>
      _guard(() async {
        final List<String> units;
        if (unitId != null) {
          units = [unitId];
        } else {
          final rows = await _client
              .from('units')
              .select('id')
              .eq('property_id', propertyId);
          units = [for (final row in rows) row['id'] as String];
        }
        if (units.isEmpty) return const [];
        final rows = await _client
            .from('leases')
            .select(Lease.columns)
            .inFilter('unit_id', units)
            .order('start_date', ascending: false)
            .order('id', ascending: false)
            .limit(pageSize);
        return rows.map(Lease.fromRow).toList();
      });

  // Expenses -------------------------------------------------------------

  @override
  Future<Paged<Expense>> expenses(
    String portfolioId, {
    String? maintenanceRequestId,
    PageCursor? before,
  }) => _guard(() async {
    var query = _client
        .from('expenses')
        .select(Expense.columns)
        .eq('portfolio_id', portfolioId);
    if (maintenanceRequestId != null) {
      query = query.eq('maintenance_request_id', maintenanceRequestId);
    }
    final rows = await query
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(Expense.fromRow).toList(), (e) => e.cursor);
  });

  @override
  Future<Expense> expense(String expenseId) => _guard(() async {
    final row = await _client
        .from('expenses')
        .select(Expense.columns)
        .eq('id', expenseId)
        .single();
    return Expense.fromRow(row);
  });

  @override
  Future<Expense> createExpense({
    required String id,
    required String portfolioId,
    required ExpenseDraft draft,
  }) => _guard(() async {
    final row = await _insert('expenses', {
      'id': id,
      'portfolio_id': portfolioId,
      ...draft.toWrite(),
    }, Expense.columns);
    return Expense.fromRow(row);
  });

  @override
  Future<Expense> updateExpense(String expenseId, ExpenseDraft draft) =>
      _guard(() async {
        final row = await _update(
          'expenses',
          expenseId,
          draft.toWrite(),
          Expense.columns,
        );
        return Expense.fromRow(row);
      });

  @override
  Future<void> deleteExpense(String expenseId) =>
      _guard(() => _delete('expenses', expenseId));

  // Utility connections --------------------------------------------------

  @override
  Future<Paged<UtilityAccount>> utilityAccounts(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  }) => _guard(() async {
    final query = _client
        .from('utility_accounts')
        .select(UtilityAccount.columns)
        .eq('portfolio_id', portfolioId);
    final filtered = archived
        ? query.not('archived_at', 'is', null)
        : query.isFilter('archived_at', null);
    final rows = await filtered
        .after(after)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(pageSize);
    return Paged.page(
      rows.map(UtilityAccount.fromRow).toList(),
      (a) => a.cursor,
    );
  });

  @override
  Future<List<UtilityBill>> unpaidBills(String portfolioId) => _guard(() async {
    final rows = await _client
        .from('utility_bills')
        .select(UtilityBill.columns)
        .eq('portfolio_id', portfolioId)
        .eq('status', BillStatus.unpaid.db)
        .order('due_date', ascending: true)
        .order('billing_month', ascending: true)
        .order('id', ascending: true)
        .limit(pageSize);
    return rows.map(UtilityBill.fromRow).toList();
  });

  Future<Paged<UtilityBill>> _bills(
    String accountId,
    PageCursor? before,
  ) async {
    final rows = await _client
        .from('utility_bills')
        .select(UtilityBill.columns)
        .eq('utility_account_id', accountId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(UtilityBill.fromRow).toList(), (b) => b.cursor);
  }

  Future<Paged<MeterReading>> _readings(
    String accountId,
    PageCursor? before,
  ) async {
    final rows = await _client
        .from('meter_readings')
        .select(MeterReading.columns)
        .eq('utility_account_id', accountId)
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(rows.map(MeterReading.fromRow).toList(), (r) => r.cursor);
  }

  @override
  Future<UtilityAccountDetail> utilityAccount(String accountId) =>
      _guard(() async {
        final (row, bills, readings) = await (
          _client
              .from('utility_accounts')
              .select(UtilityAccount.columns)
              .eq('id', accountId)
              .single(),
          _bills(accountId, null),
          _readings(accountId, null),
        ).wait;
        return UtilityAccountDetail(
          account: UtilityAccount.fromRow(row),
          bills: bills,
          readings: readings,
        );
      });

  @override
  Future<UtilityAccount> createUtilityAccount({
    required String id,
    required String portfolioId,
    required UtilityAccountDraft draft,
  }) => _guard(() async {
    final row = await _insert(
      'utility_accounts',
      {'id': id, 'portfolio_id': portfolioId, ...draft.toInsert()},
      UtilityAccount.columns,
      duplicate: 'duplicate_utility_reference',
    );
    return UtilityAccount.fromRow(row);
  });

  @override
  Future<UtilityAccount> updateUtilityAccount(
    String accountId,
    UtilityAccountDraft draft,
  ) => _guard(() async {
    final row = await _update(
      'utility_accounts',
      accountId,
      draft.toWrite(),
      UtilityAccount.columns,
      duplicate: 'duplicate_utility_reference',
    );
    return UtilityAccount.fromRow(row);
  });

  @override
  Future<UtilityAccount> archiveUtilityAccount(
    String accountId, {
    required bool archived,
  }) => _guard(() async {
    final row = await _update(
      'utility_accounts',
      accountId,
      {'archived_at': archived ? _clock().toUtc().toIso8601String() : null},
      UtilityAccount.columns,
      // Putting it back in use while another in use has its number.
      duplicate: 'duplicate_utility_reference',
    );
    return UtilityAccount.fromRow(row);
  });

  @override
  Future<void> deleteUtilityAccount(String accountId) =>
      _guard(() => _delete('utility_accounts', accountId));

  // Bills ----------------------------------------------------------------

  @override
  Future<Paged<UtilityBill>> bills(String accountId, {PageCursor? before}) =>
      _guard(() => _bills(accountId, before));

  @override
  Future<UtilityBill> bill(String billId) => _guard(() async {
    final row = await _client
        .from('utility_bills')
        .select(UtilityBill.columns)
        .eq('id', billId)
        .single();
    return UtilityBill.fromRow(row);
  });

  @override
  Future<UtilityBill> createBill({
    required String id,
    required String portfolioId,
    required String accountId,
    required BillDraft draft,
  }) => _guard(() async {
    final row = await _insert(
      'utility_bills',
      {'id': id, 'portfolio_id': portfolioId, ...draft.toInsert(accountId)},
      UtilityBill.columns,
      duplicate: 'duplicate_bill_month',
    );
    return UtilityBill.fromRow(row);
  });

  @override
  Future<UtilityBill> updateBill(String billId, BillDraft draft) =>
      _guard(() async {
        final row = await _update(
          'utility_bills',
          billId,
          draft.toWrite(),
          UtilityBill.columns,
        );
        return UtilityBill.fromRow(row);
      });

  @override
  Future<UtilityBill> setBillPayment(String billId, BillPayment payment) =>
      _guard(() async {
        final row = await _update(
          'utility_bills',
          billId,
          payment.toWrite(),
          UtilityBill.columns,
        );
        return UtilityBill.fromRow(row);
      });

  @override
  Future<void> deleteBill(String billId) =>
      _guard(() => _delete('utility_bills', billId));

  @override
  Future<Charge> billToTenant(String billId, String leaseId) =>
      _guard(() async {
        final row = await _client.rpc<Object?>(
          'bill_utility_to_tenant',
          params: {'p_bill_id': billId, 'p_lease_id': leaseId},
        );
        return Charge.fromRow(row);
      });

  // Readings -------------------------------------------------------------

  @override
  Future<Paged<MeterReading>> readings(
    String accountId, {
    PageCursor? before,
  }) => _guard(() => _readings(accountId, before));

  @override
  Future<ReadingDetail> reading(String readingId) => _guard(() async {
    final row = await _client
        .from('meter_readings')
        .select(
          '${MeterReading.columns},'
          'account:utility_accounts!meter_readings_account_fkey'
          '(${UtilityConnection.columns})',
        )
        .eq('id', readingId)
        .single();
    final reading = MeterReading.fromRow(row);
    // The reading before it in time: an earlier day, or the same day
    // recorded before it.
    final at = '"${reading.readOn.toJson()}"';
    final made = '"${reading.createdAt}"';
    final previous = await _client
        .from('meter_readings')
        .select(MeterReading.columns)
        .eq('utility_account_id', reading.accountId)
        .neq('id', reading.id)
        .or('read_on.lt.$at,and(read_on.eq.$at,created_at.lt.$made)')
        .order('read_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return ReadingDetail(
      reading: reading,
      connection: UtilityConnection.fromRow(row['account']),
      previous: previous == null ? null : MeterReading.fromRow(previous),
    );
  });

  @override
  Future<MeterReading> createReading({
    required String id,
    required String portfolioId,
    required String accountId,
    required ReadingDraft draft,
  }) => _guard(() async {
    final row = await _insert('meter_readings', {
      'id': id,
      'portfolio_id': portfolioId,
      ...draft.toInsert(accountId),
    }, MeterReading.columns);
    return MeterReading.fromRow(row);
  });

  @override
  Future<MeterReading> updateReading(String readingId, ReadingDraft draft) =>
      _guard(() async {
        final row = await _update(
          'meter_readings',
          readingId,
          draft.toWrite(),
          MeterReading.columns,
        );
        return MeterReading.fromRow(row);
      });

  @override
  Future<void> deleteReading(String readingId) =>
      _guard(() => _delete('meter_readings', readingId));

  // Maintenance ----------------------------------------------------------

  @override
  Future<Paged<MaintenanceRequest>> maintenanceRequests(
    String portfolioId, {
    required bool pending,
    PageCursor? before,
  }) => _guard(() async {
    final rows = await _client
        .from('maintenance_requests')
        .select(MaintenanceRequest.columns)
        .eq('portfolio_id', portfolioId)
        .inFilter('status', [
          for (final status in MaintenanceStatus.where(pending: pending))
            status.db,
        ])
        .before(before)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return Paged.page(
      rows.map(MaintenanceRequest.fromRow).toList(),
      (r) => r.cursor,
    );
  });

  @override
  Future<MaintenanceRequest> maintenanceRequest(String requestId) =>
      _guard(() async {
        final row = await _client
            .from('maintenance_requests')
            .select(MaintenanceRequest.columns)
            .eq('id', requestId)
            .single();
        return MaintenanceRequest.fromRow(row);
      });

  @override
  Future<MaintenanceRequest> createMaintenanceRequest({
    required String id,
    required String portfolioId,
    required MaintenanceDraft draft,
  }) => _guard(() async {
    final row = await _insert('maintenance_requests', {
      'id': id,
      'portfolio_id': portfolioId,
      ...draft.toInsert(),
    }, MaintenanceRequest.columns);
    return MaintenanceRequest.fromRow(row);
  });

  @override
  Future<MaintenanceRequest> updateMaintenanceRequest(
    String requestId,
    MaintenanceDraft draft,
  ) => _guard(() async {
    final row = await _update(
      'maintenance_requests',
      requestId,
      draft.toWrite(),
      MaintenanceRequest.columns,
    );
    return MaintenanceRequest.fromRow(row);
  });

  @override
  Future<MaintenanceRequest> moveMaintenanceRequest(
    String requestId,
    MaintenanceMove move,
  ) => _guard(() async {
    final row = await _update(
      'maintenance_requests',
      requestId,
      move.toWrite(),
      MaintenanceRequest.columns,
    );
    return MaintenanceRequest.fromRow(row);
  });

  @override
  Future<void> deleteMaintenanceRequest(String requestId) => _guard(
    () => _delete(
      'maintenance_requests',
      requestId,
      inUse: 'request_has_expenses',
    ),
  );
}

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => SupabaseOperationsRepository(ref.watch(supabaseClientProvider)),
);
