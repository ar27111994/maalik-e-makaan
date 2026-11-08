import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import 'fakes.dart';

/// Gulberg House's electricity: LESCO, on the ground floor, in the owner's
/// name and on the protected tariff.
final lescoMeter = UtilityAccount(
  id: '0192d0c4-7777-7000-8000-000000000001',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  unitId: groundFloor.id,
  unitLabel: groundFloor.label,
  type: UtilityType.electricity,
  provider: UtilityProvider.lesco,
  referenceNumber: '09269330553008',
  customerId: '4567890',
  meterNumber: 'L-12345',
  accountTitle: 'Ayesha Khan',
  isProtectedConsumer: true,
  createdAt: '2026-01-06T09:00:00+00:00',
);

/// Gulberg House's gas: SNGPL, for the whole house, in the tenant's name.
final sngplMeter = UtilityAccount(
  id: '0192d0c4-7777-7000-8000-000000000002',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  type: UtilityType.gas,
  provider: UtilityProvider.sngpl,
  referenceNumber: '11223344556',
  accountTitle: 'Ali Raza',
  inLandlordName: false,
  createdAt: '2026-01-07T09:00:00+00:00',
);

/// An archived water connection.
final oldWater = UtilityAccount(
  id: '0192d0c4-7777-7000-8000-000000000003',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  type: UtilityType.water,
  provider: UtilityProvider.wasa,
  archivedAt: DateTime.utc(2026, 5, 1, 7),
  createdAt: '2026-01-08T09:00:00+00:00',
);

/// November's electricity bill: overdue, unpaid, over 200 units.
final novemberBill = UtilityBill(
  id: '0192d0c4-8888-7000-8000-000000000002',
  connection: lescoMeter.connection,
  billingMonth: MonthPeriod(2026, 11),
  amount: const Money.fromRupees(9850),
  dueDate: CalendarDate(2026, 11, 5),
  unitsConsumed: const Hundredths(21200),
  createdAt: '2026-11-01T09:00:00+00:00',
);

/// October's electricity bill: paid by the tenant and on their ledger.
final octoberBill = UtilityBill(
  id: '0192d0c4-8888-7000-8000-000000000001',
  connection: lescoMeter.connection,
  billingMonth: MonthPeriod(2026, 10),
  amount: const Money.fromRupees(7420),
  dueDate: CalendarDate(2026, 10, 6),
  unitsConsumed: const Hundredths(18600),
  status: BillStatus.paid,
  paidOn: CalendarDate(2026, 10, 4),
  paidBy: BillPayer.tenant,
  charge: BilledCharge(id: 'ch-elec-10', leaseId: aliLease.id),
  createdAt: '2026-10-01T09:00:00+00:00',
);

/// November's gas bill: due in five days.
final gasBill = UtilityBill(
  id: '0192d0c4-8888-7000-8000-000000000003',
  connection: sngplMeter.connection,
  billingMonth: MonthPeriod(2026, 11),
  amount: const Money.fromRupees(2300),
  dueDate: CalendarDate(2026, 11, 12),
  createdAt: '2026-11-02T09:00:00+00:00',
);

/// The electricity meter at Ali Raza's move-in, and the last two months.
final moveInReading = MeterReading(
  id: '0192d0c4-9999-7000-8000-000000000001',
  accountId: lescoMeter.id,
  reading: const Hundredths(1045000),
  readOn: CalendarDate(2026, 1, 15),
  context: ReadingContext.moveIn,
  leaseId: aliLease.id,
  tenantName: 'Ali Raza',
  createdAt: '2026-01-15T09:00:00+00:00',
);
final octoberReading = MeterReading(
  id: '0192d0c4-9999-7000-8000-000000000002',
  accountId: lescoMeter.id,
  reading: const Hundredths(1201000),
  readOn: CalendarDate(2026, 10, 1),
  context: ReadingContext.monthly,
  createdAt: '2026-10-01T09:00:00+00:00',
);
final novemberReading = MeterReading(
  id: '0192d0c4-9999-7000-8000-000000000003',
  accountId: lescoMeter.id,
  reading: const Hundredths(1220500),
  readOn: CalendarDate(2026, 11, 1),
  context: ReadingContext.monthly,
  notes: 'Read by Bilal.',
  createdAt: '2026-11-01T09:00:00+00:00',
);

/// Seepage in Ali Raza's bedroom, being fixed.
final seepageJob = MaintenanceRequest(
  id: '0192d0c4-aaaa-7000-8000-000000000002',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  unitId: groundFloor.id,
  unitLabel: groundFloor.label,
  leaseId: aliLease.id,
  tenantName: 'Ali Raza',
  title: 'Seepage in the bedroom wall',
  description: 'Damp patch under the bathroom, spreading since the rains.',
  category: MaintenanceCategory.seepage,
  priority: MaintenancePriority.urgent,
  status: MaintenanceStatus.inProgress,
  reportedBy: 'Ali Raza',
  reportedOn: CalendarDate(2026, 11, 2),
  assignedTo: 'Aslam Plumber',
  vendorPhone: PhoneNumber.fromE164('+923001112233'),
  estimatedCost: const Money.fromRupees(12000),
  createdAt: '2026-11-02T09:00:00+00:00',
);

/// The gate light, just reported.
final gateLightJob = MaintenanceRequest(
  id: '0192d0c4-aaaa-7000-8000-000000000003',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  title: 'Gate light not working',
  category: MaintenanceCategory.electrical,
  priority: MaintenancePriority.low,
  reportedOn: CalendarDate(2026, 11, 6),
  createdAt: '2026-11-06T09:00:00+00:00',
);

/// A leaking tap, fixed in September.
final tapJob = MaintenanceRequest(
  id: '0192d0c4-aaaa-7000-8000-000000000001',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  unitId: firstFloor.id,
  unitLabel: firstFloor.label,
  title: 'Kitchen tap leaking',
  category: MaintenanceCategory.plumbing,
  status: MaintenanceStatus.resolved,
  reportedOn: CalendarDate(2026, 9, 10),
  resolvedOn: CalendarDate(2026, 9, 12),
  resolutionNote: 'Washer replaced.',
  createdAt: '2026-09-10T09:00:00+00:00',
);

/// The plumber's first visit for the seepage.
final plumberExpense = Expense(
  id: '0192d0c4-6666-7000-8000-000000000003',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  unitId: groundFloor.id,
  unitLabel: groundFloor.label,
  maintenanceRequestId: seepageJob.id,
  maintenanceTitle: seepageJob.title,
  category: ExpenseCategory.repairsMaintenance,
  amount: const Money.fromRupees(4500),
  spentOn: CalendarDate(2026, 11, 5),
  payee: 'Aslam Plumber',
  paidBy: testUserId,
  createdAt: '2026-11-05T09:00:00+00:00',
);

/// The year's property tax, paid by bank transfer.
final taxExpense = Expense(
  id: '0192d0c4-6666-7000-8000-000000000002',
  propertyId: gulbergHouse.id,
  propertyName: gulbergHouse.name,
  category: ExpenseCategory.propertyTax,
  amount: const Money.fromRupees(18000),
  spentOn: CalendarDate(2026, 9, 30),
  payee: 'Excise and Taxation, Lahore',
  method: PaymentMethod.bankTransfer,
  reference: 'PT-2026-7781',
  notes: 'Paid before the rebate deadline.',
  paidBy: testUserId,
  createdAt: '2026-10-01T09:00:00+00:00',
);

/// The accountant's fee, for the whole portfolio.
final accountantExpense = Expense(
  id: '0192d0c4-6666-7000-8000-000000000001',
  category: ExpenseCategory.legalProfessional,
  amount: const Money.fromRupees(15000),
  spentOn: CalendarDate(2026, 8, 15),
  payee: 'Khan & Co.',
  method: PaymentMethod.cheque,
  paidBy: testUserId,
  createdAt: '2026-08-15T09:00:00+00:00',
);

/// An [OperationsRepository] over in-memory expenses, connections, bills,
/// readings and repairs of [gulberg].
final class FakeOperationsRepository implements OperationsRepository {
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads with this when set.
  AppFailure? readFailure;

  /// Fail the next commands, one each.
  final writeFailures = <AppFailure>[];

  /// How many rows a page holds (the real one reads 50).
  int pageLimit = pageSize;

  /// Loses the reply to the next add: the row is stored, then the
  /// connection drops. Adding the same id again returns the row stored,
  /// as the real repository does.
  bool loseNextReply = false;

  void _maybeLoseReply() {
    if (loseNextReply) {
      loseNextReply = false;
      throw const NetworkFailure();
    }
  }

  final placeList = <String, List<PropertyPlace>>{
    gulberg.id: [
      PropertyPlace(
        id: gulbergHouse.id,
        name: gulbergHouse.name,
        units: [
          for (final unit in [groundFloor, firstFloor, annexe])
            UnitPlace(id: unit.id, label: unit.label),
        ],
      ),
    ],
    plaza.id: [PropertyPlace(id: saddarPlaza.id, name: saddarPlaza.name)],
  };

  /// Newest first.
  final expenseList = <Expense>[plumberExpense, taxExpense, accountantExpense];

  /// Oldest first.
  final accountList = <UtilityAccount>[lescoMeter, sngplMeter, oldWater];

  /// Newest first.
  final billList = <UtilityBill>[gasBill, novemberBill, octoberBill];

  /// Newest first.
  final readingList = <MeterReading>[
    novemberReading,
    octoberReading,
    moveInReading,
  ];

  /// Newest first.
  final requestList = <MaintenanceRequest>[gateLightJob, seepageJob, tapJob];

  final leaseList = <Lease>[aliLease, endedLease];

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
    if (!read && writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
  }

  Paged<T> _page<T>(
    List<T> all,
    PageCursor? cursor,
    PageCursor Function(T) cursorOf,
  ) {
    var start = 0;
    if (cursor != null) {
      start = all.indexWhere((item) => cursorOf(item) == cursor) + 1;
    }
    final items = all.skip(start).take(pageLimit).toList();
    final more = start + items.length < all.length;
    return Paged(items, next: more ? cursorOf(items.last) : null);
  }

  T _find<T>(List<T> list, bool Function(T) test) =>
      list.firstWhere(test, orElse: () => throw const NotFoundFailure());

  void _replace<T>(List<T> list, bool Function(T) test, T value) =>
      list[list.indexWhere(test)] = value;

  static const _now = '2026-11-07T10:00:00+00:00';

  @override
  Future<List<PropertyPlace>> places(String portfolioId) async {
    await _call('places', [portfolioId], read: true);
    return placeList[portfolioId] ?? const [];
  }

  @override
  Future<List<Lease>> tenancies({
    required String propertyId,
    String? unitId,
  }) async {
    await _call('tenancies', [propertyId, unitId], read: true);
    return [
      for (final lease in leaseList)
        if (lease.propertyId == propertyId &&
            (unitId == null || lease.unitId == unitId))
          lease,
    ];
  }

  @override
  Future<Paged<Expense>> expenses(
    String portfolioId, {
    String? maintenanceRequestId,
    PageCursor? before,
  }) async {
    await _call('expenses', [
      portfolioId,
      maintenanceRequestId,
      before,
    ], read: true);
    if (portfolioId != gulberg.id) return const Paged([]);
    return _page(
      [
        for (final e in expenseList)
          if (maintenanceRequestId == null ||
              e.maintenanceRequestId == maintenanceRequestId)
            e,
      ],
      before,
      (e) => e.cursor,
    );
  }

  @override
  Future<Expense> expense(String expenseId) async {
    await _call('expense', [expenseId], read: true);
    return _find<Expense>(expenseList, (e) => e.id == expenseId);
  }

  Expense _storedExpense(String id, ExpenseDraft draft, String createdAt) {
    final place = placeOf(placeList[gulberg.id]!, draft.propertyId);
    final job = draft.maintenanceRequestId;
    return Expense.fromRow({
      'id': id,
      ...draft.toWrite(),
      'property': place == null ? null : {'name': place.name},
      'unit': draft.unitId == null
          ? null
          : {'label': place?.unitLabel(draft.unitId)},
      'request': job == null
          ? null
          : {'title': _find(requestList, (r) => r.id == job).title},
      'paid_by': testUserId,
      'created_at': createdAt,
    });
  }

  @override
  Future<Expense> createExpense({
    required String id,
    required String portfolioId,
    required ExpenseDraft draft,
  }) async {
    await _call('createExpense', [id, portfolioId, draft]);
    for (final e in expenseList) {
      if (e.id == id) return e;
    }
    final stored = _storedExpense(id, draft, _now);
    expenseList.insert(0, stored);
    _maybeLoseReply();
    return stored;
  }

  @override
  Future<Expense> updateExpense(String expenseId, ExpenseDraft draft) async {
    await _call('updateExpense', [expenseId, draft]);
    final old = _find(expenseList, (e) => e.id == expenseId);
    final stored = _storedExpense(expenseId, draft, old.createdAt);
    _replace(expenseList, (e) => e.id == expenseId, stored);
    return stored;
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _call('deleteExpense', [expenseId]);
    expenseList.removeWhere((e) => e.id == expenseId);
  }

  @override
  Future<Paged<UtilityAccount>> utilityAccounts(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  }) async {
    await _call('utilityAccounts', [portfolioId, archived, after], read: true);
    if (portfolioId != gulberg.id) return const Paged([]);
    return _page(
      [
        for (final a in accountList)
          if (a.archived == archived) a,
      ],
      after,
      (a) => a.cursor,
    );
  }

  @override
  Future<List<UtilityBill>> unpaidBills(String portfolioId) async {
    await _call('unpaidBills', [portfolioId], read: true);
    if (portfolioId != gulberg.id) return const [];
    return [
      for (final b in billList)
        if (!b.paid) b,
    ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  @override
  Future<UtilityAccountDetail> utilityAccount(String accountId) async {
    await _call('utilityAccount', [accountId], read: true);
    return UtilityAccountDetail(
      account: _find(accountList, (a) => a.id == accountId),
      bills: _page(
        [
          for (final b in billList)
            if (b.connection.id == accountId) b,
        ],
        null,
        (b) => b.cursor,
      ),
      readings: _page(
        [
          for (final r in readingList)
            if (r.accountId == accountId) r,
        ],
        null,
        (r) => r.cursor,
      ),
    );
  }

  UtilityAccount _storedAccount(
    String id,
    UtilityAccountDraft draft, {
    required String createdAt,
    DateTime? archivedAt,
  }) {
    final place = placeOf(placeList[gulberg.id]!, draft.propertyId)!;
    return UtilityAccount.fromRow({
      'id': id,
      ...draft.toInsert(),
      'property': {'name': place.name},
      'unit': draft.unitId == null
          ? null
          : {'label': place.unitLabel(draft.unitId)},
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt,
    });
  }

  @override
  Future<UtilityAccount> createUtilityAccount({
    required String id,
    required String portfolioId,
    required UtilityAccountDraft draft,
  }) async {
    await _call('createUtilityAccount', [id, portfolioId, draft]);
    for (final a in accountList) {
      if (a.id == id) return a;
    }
    final stored = _storedAccount(id, draft, createdAt: _now);
    accountList.add(stored);
    _maybeLoseReply();
    return stored;
  }

  @override
  Future<UtilityAccount> updateUtilityAccount(
    String accountId,
    UtilityAccountDraft draft,
  ) async {
    await _call('updateUtilityAccount', [accountId, draft]);
    final old = _find(accountList, (a) => a.id == accountId);
    final stored = _storedAccount(
      accountId,
      draft,
      createdAt: old.createdAt,
      archivedAt: old.archivedAt,
    );
    _replace(accountList, (a) => a.id == accountId, stored);
    return stored;
  }

  @override
  Future<UtilityAccount> archiveUtilityAccount(
    String accountId, {
    required bool archived,
  }) async {
    await _call('archiveUtilityAccount', [accountId, archived]);
    final old = _find(accountList, (a) => a.id == accountId);
    final stored = UtilityAccount.fromRow({
      ...old.toRow(),
      'archived_at': archived ? '2026-11-07T05:00:00Z' : null,
    });
    _replace(accountList, (a) => a.id == accountId, stored);
    return stored;
  }

  @override
  Future<void> deleteUtilityAccount(String accountId) async {
    await _call('deleteUtilityAccount', [accountId]);
    accountList.removeWhere((a) => a.id == accountId);
    billList.removeWhere((b) => b.connection.id == accountId);
    readingList.removeWhere((r) => r.accountId == accountId);
  }

  @override
  Future<Paged<UtilityBill>> bills(
    String accountId, {
    PageCursor? before,
  }) async {
    await _call('bills', [accountId, before], read: true);
    return _page(
      [
        for (final b in billList)
          if (b.connection.id == accountId) b,
      ],
      before,
      (b) => b.cursor,
    );
  }

  @override
  Future<UtilityBill> bill(String billId) async {
    await _call('bill', [billId], read: true);
    return _find<UtilityBill>(billList, (b) => b.id == billId);
  }

  UtilityBill _storedBill(
    String id,
    UtilityConnection connection,
    BillDraft draft, {
    required String createdAt,
  }) => UtilityBill.fromRow({
    'id': id,
    'account': connection.toRow(),
    ...draft.toInsert(connection.id),
    'charge': null,
    'created_at': createdAt,
  });

  @override
  Future<UtilityBill> createBill({
    required String id,
    required String portfolioId,
    required String accountId,
    required BillDraft draft,
  }) async {
    await _call('createBill', [id, portfolioId, accountId, draft]);
    for (final b in billList) {
      if (b.id == id) return b;
    }
    final account = _find(accountList, (a) => a.id == accountId);
    final stored = _storedBill(id, account.connection, draft, createdAt: _now);
    billList.insert(0, stored);
    _maybeLoseReply();
    return stored;
  }

  @override
  Future<UtilityBill> updateBill(String billId, BillDraft draft) async {
    await _call('updateBill', [billId, draft]);
    final old = _find(billList, (b) => b.id == billId);
    // Only the details change; whether it is paid stays as stored.
    final stored = UtilityBill.fromRow({...old.toRow(), ...draft.toWrite()});
    _replace(billList, (b) => b.id == billId, stored);
    return stored;
  }

  @override
  Future<UtilityBill> setBillPayment(String billId, BillPayment payment) async {
    await _call('setBillPayment', [billId, payment]);
    final old = _find(billList, (b) => b.id == billId);
    final stored = UtilityBill.fromRow({...old.toRow(), ...payment.toWrite()});
    _replace(billList, (b) => b.id == billId, stored);
    return stored;
  }

  @override
  Future<void> deleteBill(String billId) async {
    await _call('deleteBill', [billId]);
    billList.removeWhere((b) => b.id == billId);
  }

  @override
  Future<Charge> billToTenant(String billId, String leaseId) async {
    await _call('billToTenant', [billId, leaseId]);
    final old = _find(billList, (b) => b.id == billId);
    final charge = Charge(
      id: 'ch-bill-$billId',
      leaseId: leaseId,
      kind: ChargeKind.electricity,
      source: ChargeSource.utilityBill,
      periodMonth: old.billingMonth,
      dueDate: old.dueDate ?? CalendarDate(2026, 11, 7),
      amount: old.amount,
      createdAt: _now,
    );
    _replace(
      billList,
      (b) => b.id == billId,
      UtilityBill.fromRow({
        ...old.toRow(),
        'charge': BilledCharge(id: charge.id, leaseId: leaseId).toRow(),
      }),
    );
    return charge;
  }

  @override
  Future<Paged<MeterReading>> readings(
    String accountId, {
    PageCursor? before,
  }) async {
    await _call('readings', [accountId, before], read: true);
    return _page(
      [
        for (final r in readingList)
          if (r.accountId == accountId) r,
      ],
      before,
      (r) => r.cursor,
    );
  }

  @override
  Future<ReadingDetail> reading(String readingId) async {
    await _call('reading', [readingId], read: true);
    final reading = _find(readingList, (r) => r.id == readingId);
    final account = _find(accountList, (a) => a.id == reading.accountId);
    MeterReading? previous;
    for (final other in readingList) {
      if (other.accountId != reading.accountId || other.id == reading.id) {
        continue;
      }
      final earlier =
          other.readOn.isBefore(reading.readOn) ||
          (other.readOn == reading.readOn &&
              other.createdAt.compareTo(reading.createdAt) < 0);
      final later = previous == null || other.readOn.isAfter(previous.readOn);
      if (earlier && later) {
        previous = other;
      }
    }
    return ReadingDetail(
      reading: reading,
      connection: account.connection,
      previous: previous,
    );
  }

  MeterReading _storedReading(
    String id,
    String accountId,
    ReadingDraft draft, {
    required String createdAt,
    String? leaseId,
  }) {
    final lease = leaseId ?? draft.leaseId;
    return MeterReading.fromRow({
      'id': id,
      ...draft.toInsert(accountId),
      'lease_id': lease,
      'lease': lease == null
          ? null
          : {
              'tenant': {
                'full_name': _find(leaseList, (l) => l.id == lease).tenantName,
              },
            },
      'created_at': createdAt,
    });
  }

  @override
  Future<MeterReading> createReading({
    required String id,
    required String portfolioId,
    required String accountId,
    required ReadingDraft draft,
  }) async {
    await _call('createReading', [id, portfolioId, accountId, draft]);
    for (final r in readingList) {
      if (r.id == id) return r;
    }
    final stored = _storedReading(id, accountId, draft, createdAt: _now);
    readingList.insert(0, stored);
    _maybeLoseReply();
    return stored;
  }

  @override
  Future<MeterReading> updateReading(
    String readingId,
    ReadingDraft draft,
  ) async {
    await _call('updateReading', [readingId, draft]);
    final old = _find(readingList, (r) => r.id == readingId);
    final stored = _storedReading(
      readingId,
      old.accountId,
      draft,
      createdAt: old.createdAt,
      leaseId: old.leaseId,
    );
    _replace(readingList, (r) => r.id == readingId, stored);
    return stored;
  }

  @override
  Future<void> deleteReading(String readingId) async {
    await _call('deleteReading', [readingId]);
    readingList.removeWhere((r) => r.id == readingId);
  }

  @override
  Future<Paged<MaintenanceRequest>> maintenanceRequests(
    String portfolioId, {
    required bool pending,
    PageCursor? before,
  }) async {
    await _call('maintenanceRequests', [
      portfolioId,
      pending,
      before,
    ], read: true);
    if (portfolioId != gulberg.id) return const Paged([]);
    return _page(
      [
        for (final r in requestList)
          if (r.status.pending == pending) r,
      ],
      before,
      (r) => r.cursor,
    );
  }

  @override
  Future<MaintenanceRequest> maintenanceRequest(String requestId) async {
    await _call('maintenanceRequest', [requestId], read: true);
    return _find<MaintenanceRequest>(requestList, (r) => r.id == requestId);
  }

  MaintenanceRequest _storedRequest(
    String id,
    MaintenanceDraft draft,
    String createdAt,
  ) {
    final place = placeOf(placeList[gulberg.id]!, draft.propertyId)!;
    final lease = draft.leaseId;
    return MaintenanceRequest.fromRow({
      'id': id,
      ...draft.toInsert(),
      'property': {'name': place.name},
      'unit': draft.unitId == null
          ? null
          : {'label': place.unitLabel(draft.unitId)},
      'lease': lease == null
          ? null
          : {
              'tenant': {
                'full_name': _find(leaseList, (l) => l.id == lease).tenantName,
              },
            },
      'created_at': createdAt,
    });
  }

  @override
  Future<MaintenanceRequest> createMaintenanceRequest({
    required String id,
    required String portfolioId,
    required MaintenanceDraft draft,
  }) async {
    await _call('createMaintenanceRequest', [id, portfolioId, draft]);
    for (final r in requestList) {
      if (r.id == id) return r;
    }
    final stored = _storedRequest(id, draft, _now);
    requestList.insert(0, stored);
    _maybeLoseReply();
    return stored;
  }

  @override
  Future<MaintenanceRequest> updateMaintenanceRequest(
    String requestId,
    MaintenanceDraft draft,
  ) async {
    await _call('updateMaintenanceRequest', [requestId, draft]);
    final old = _find(requestList, (r) => r.id == requestId);
    final stored = _storedRequest(requestId, draft, old.createdAt);
    _replace(requestList, (r) => r.id == requestId, stored);
    return stored;
  }

  @override
  Future<MaintenanceRequest> moveMaintenanceRequest(
    String requestId,
    MaintenanceMove move,
  ) async {
    await _call('moveMaintenanceRequest', [requestId, move]);
    final old = _find(requestList, (r) => r.id == requestId);
    final stored = MaintenanceRequest.fromRow({
      ...old.toRow(),
      ...move.toWrite(),
    });
    _replace(requestList, (r) => r.id == requestId, stored);
    return stored;
  }

  @override
  Future<void> deleteMaintenanceRequest(String requestId) async {
    await _call('deleteMaintenanceRequest', [requestId]);
    if (expenseList.any((e) => e.maintenanceRequestId == requestId)) {
      throw const RejectedFailure('request_has_expenses');
    }
    requestList.removeWhere((r) => r.id == requestId);
  }
}
