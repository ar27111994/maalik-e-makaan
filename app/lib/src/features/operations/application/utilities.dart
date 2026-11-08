import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';

/// Which connections a list shows: a portfolio's in use, or its archived.
typedef UtilityAccountList = ({String portfolioId, bool archived});

/// A portfolio's connections, the saved copy first, 50 at a time.
final StreamNotifierProviderFamily<
  UtilityAccountsController,
  Snapshot<Paged<UtilityAccount>>,
  UtilityAccountList
>
utilityAccountsProvider = StreamNotifierProvider.autoDispose
    .family<
      UtilityAccountsController,
      Snapshot<Paged<UtilityAccount>>,
      UtilityAccountList
    >(UtilityAccountsController.new);

/// Reads a list of connections and adds new ones. Commands throw
/// [AppFailure].
final class UtilityAccountsController
    extends SwrNotifier<Paged<UtilityAccount>> {
  new(this.list);

  final UtilityAccountList list;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query =>
      'utilities.${list.portfolioId}.${list.archived ? 'archived' : 'active'}';

  @override
  Stream<Snapshot<Paged<UtilityAccount>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<UtilityAccount>> fetch() =>
      _repository.utilityAccounts(list.portfolioId, archived: list.archived);

  @override
  Paged<UtilityAccount> decode(Object? json) =>
      Paged.fromJson(json, UtilityAccount.fromRow);

  @override
  Object? encode(Paged<UtilityAccount> value) => value.toJson((a) => a.toRow());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.utilityAccounts(
      list.portfolioId,
      archived: list.archived,
      after: next,
    );
    await show(current.followedBy(more));
  }

  /// Adds a connection ([id] names this attempt: keep it for retries).
  Future<UtilityAccount> create(String id, UtilityAccountDraft draft) async {
    final created = await _repository.createUtilityAccount(
      id: id,
      portfolioId: list.portfolioId,
      draft: draft,
    );
    ref.invalidate(utilityAccountsProvider);
    return created;
  }
}

/// The unpaid bills of a portfolio, the earliest due first (UTIL-03's
/// alerts), the saved copy first.
final StreamNotifierProviderFamily<
  UnpaidBillsController,
  Snapshot<List<UtilityBill>>,
  String
>
unpaidBillsProvider = StreamNotifierProvider.autoDispose
    .family<UnpaidBillsController, Snapshot<List<UtilityBill>>, String>(
      UnpaidBillsController.new,
    );

/// Reads the unpaid bills.
final class UnpaidBillsController extends SwrNotifier<List<UtilityBill>> {
  new(this.portfolioId);

  final String portfolioId;

  @override
  String get query => 'unpaid_bills.$portfolioId';

  @override
  Stream<Snapshot<List<UtilityBill>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<UtilityBill>> fetch() =>
      ref.read(operationsRepositoryProvider).unpaidBills(portfolioId);

  @override
  List<UtilityBill> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      UtilityBill.fromRow(row),
  ];

  @override
  Object? encode(List<UtilityBill> value) => [
    for (final bill in value) bill.toRow(),
  ];
}

/// A connection with its bills and readings, the saved copy first.
final StreamNotifierProviderFamily<
  UtilityAccountController,
  Snapshot<UtilityAccountDetail>,
  String
>
utilityAccountProvider = StreamNotifierProvider.autoDispose
    .family<UtilityAccountController, Snapshot<UtilityAccountDetail>, String>(
      UtilityAccountController.new,
    );

/// Reads a connection and changes it, its bills and readings. Commands
/// throw [AppFailure] and, once the server has answered, show what it
/// stored.
final class UtilityAccountController extends SwrNotifier<UtilityAccountDetail> {
  new(this.accountId);

  final String accountId;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'utility.$accountId';

  @override
  Stream<Snapshot<UtilityAccountDetail>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<UtilityAccountDetail> fetch() => _repository.utilityAccount(accountId);

  @override
  UtilityAccountDetail decode(Object? json) =>
      UtilityAccountDetail.fromJson(json);

  @override
  Object? encode(UtilityAccountDetail value) => value.toJson();

  Future<void> loadMoreBills() async {
    final current = state.value?.value;
    final next = current?.bills.next;
    if (current == null || next == null) return;
    final more = await _repository.bills(accountId, before: next);
    await show(current.copyWith(bills: current.bills.followedBy(more)));
  }

  Future<void> loadMoreReadings() async {
    final current = state.value?.value;
    final next = current?.readings.next;
    if (current == null || next == null) return;
    final more = await _repository.readings(accountId, before: next);
    await show(current.copyWith(readings: current.readings.followedBy(more)));
  }

  /// The lists that name the connection, and its bills, read again.
  Future<void> _changed() async {
    ref
      ..invalidate(utilityAccountsProvider)
      ..invalidate(unpaidBillsProvider);
    await reload();
  }

  Future<UtilityAccount> save(UtilityAccountDraft draft) async {
    final saved = await _repository.updateUtilityAccount(accountId, draft);
    await _changed();
    return saved;
  }

  /// Archives the connection, or puts it back in use.
  Future<UtilityAccount> archive({required bool archived}) async {
    final saved = await _repository.archiveUtilityAccount(
      accountId,
      archived: archived,
    );
    await _changed();
    return saved;
  }

  /// Deletes the connection with its bills and readings (owners).
  Future<void> delete() async {
    await _repository.deleteUtilityAccount(accountId);
    ref
      ..invalidate(utilityAccountsProvider)
      ..invalidate(unpaidBillsProvider);
  }

  /// Adds a month's bill ([id] names this attempt).
  Future<UtilityBill> addBill({
    required String id,
    required String portfolioId,
    required BillDraft draft,
  }) async {
    final bill = await _repository.createBill(
      id: id,
      portfolioId: portfolioId,
      accountId: accountId,
      draft: draft,
    );
    ref.invalidate(unpaidBillsProvider);
    await reload();
    return bill;
  }

  /// Adds a reading ([id] names this attempt).
  Future<MeterReading> addReading({
    required String id,
    required String portfolioId,
    required ReadingDraft draft,
  }) async {
    final reading = await _repository.createReading(
      id: id,
      portfolioId: portfolioId,
      accountId: accountId,
      draft: draft,
    );
    await reload();
    return reading;
  }
}

/// One bill with its connection, the saved copy first.
final StreamNotifierProviderFamily<
  UtilityBillController,
  Snapshot<UtilityBill>,
  String
>
utilityBillProvider = StreamNotifierProvider.autoDispose
    .family<UtilityBillController, Snapshot<UtilityBill>, String>(
      UtilityBillController.new,
    );

/// Reads a bill and changes it: saves it, marks it paid or unpaid, bills
/// it to a tenant and deletes it. Commands throw [AppFailure].
final class UtilityBillController extends SwrNotifier<UtilityBill> {
  new(this.billId);

  final String billId;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'bill.$billId';

  @override
  Stream<Snapshot<UtilityBill>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<UtilityBill> fetch() => _repository.bill(billId);

  @override
  UtilityBill decode(Object? json) => UtilityBill.fromRow(json);

  @override
  Object? encode(UtilityBill value) => value.toRow();

  void _listsChanged(String accountId) => ref
    ..invalidate(utilityAccountProvider(accountId))
    ..invalidate(unpaidBillsProvider);

  /// Saves the bill's details; whether it is paid is left as stored.
  Future<UtilityBill> save(BillDraft draft) async {
    final saved = await _repository.updateBill(billId, draft);
    _listsChanged(saved.connection.id);
    await show(saved);
    return saved;
  }

  /// Marks the bill paid or unpaid, and changes nothing else.
  Future<UtilityBill> setPayment(BillPayment payment) async {
    final saved = await _repository.setBillPayment(billId, payment);
    _listsChanged(saved.connection.id);
    await show(saved);
    return saved;
  }

  /// Puts the bill on [leaseId]'s ledger; that tenancy's money, and the
  /// lists that show the bill with its charge, are read again.
  Future<Charge> billToTenant(String leaseId) async {
    final charge = await _repository.billToTenant(billId, leaseId);
    ref
      ..invalidate(tenancyLedgerProvider(leaseId))
      ..invalidate(receivablesProvider)
      ..invalidate(unpaidBillsProvider);
    final accountId = state.value?.value.connection.id;
    if (accountId != null) ref.invalidate(utilityAccountProvider(accountId));
    await reload();
    return charge;
  }

  /// Deletes the bill (owners and managers). A charge it was billed to a
  /// tenant as stays on their ledger.
  Future<void> delete() async {
    final accountId = state.value?.value.connection.id;
    await _repository.deleteBill(billId);
    if (accountId != null) _listsChanged(accountId);
    ref.invalidate(unpaidBillsProvider);
  }
}

/// One reading with its connection and the reading before it, the saved
/// copy first.
final StreamNotifierProviderFamily<
  MeterReadingController,
  Snapshot<ReadingDetail>,
  String
>
meterReadingProvider = StreamNotifierProvider.autoDispose
    .family<MeterReadingController, Snapshot<ReadingDetail>, String>(
      MeterReadingController.new,
    );

/// Reads a reading, saves and deletes it. Commands throw [AppFailure].
final class MeterReadingController extends SwrNotifier<ReadingDetail> {
  new(this.readingId);

  final String readingId;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'reading.$readingId';

  @override
  Stream<Snapshot<ReadingDetail>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<ReadingDetail> fetch() => _repository.reading(readingId);

  @override
  ReadingDetail decode(Object? json) => ReadingDetail.fromJson(json);

  @override
  Object? encode(ReadingDetail value) => value.toJson();

  Future<MeterReading> save(ReadingDraft draft) async {
    final saved = await _repository.updateReading(readingId, draft);
    ref.invalidate(utilityAccountProvider(saved.accountId));
    await reload();
    return saved;
  }

  /// Deletes the reading (owners and managers).
  Future<void> delete() async {
    final accountId = state.value?.value.reading.accountId;
    await _repository.deleteReading(readingId);
    if (accountId != null) ref.invalidate(utilityAccountProvider(accountId));
  }
}
