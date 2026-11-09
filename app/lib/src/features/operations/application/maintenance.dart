import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';

/// Which requests a list shows: a portfolio's still to be done, or its
/// closed ones.
typedef MaintenanceList = ({String portfolioId, bool pending});

/// A portfolio's maintenance requests, the latest reported first, the
/// saved copy first, 50 at a time.
final StreamNotifierProviderFamily<
  MaintenanceListController,
  Snapshot<Paged<MaintenanceRequest>>,
  MaintenanceList
>
maintenanceListProvider = StreamNotifierProvider.autoDispose
    .family<
      MaintenanceListController,
      Snapshot<Paged<MaintenanceRequest>>,
      MaintenanceList
    >(MaintenanceListController.new);

/// Reads a list of requests and adds new ones. Commands throw
/// [AppFailure].
final class MaintenanceListController
    extends SwrNotifier<Paged<MaintenanceRequest>> {
  new(this.list);

  final MaintenanceList list;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query =>
      'maintenance.${list.portfolioId}.${list.pending ? 'pending' : 'closed'}';

  @override
  Stream<Snapshot<Paged<MaintenanceRequest>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<MaintenanceRequest>> fetch() =>
      _repository.maintenanceRequests(list.portfolioId, pending: list.pending);

  @override
  Paged<MaintenanceRequest> decode(Object? json) =>
      Paged.fromJson(json, MaintenanceRequest.fromRow);

  @override
  Object? encode(Paged<MaintenanceRequest> value) =>
      value.toJson((r) => r.toRow());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.maintenanceRequests(
      list.portfolioId,
      pending: list.pending,
      before: next,
    );
    await show(current.followedBy(more));
  }

  /// Adds a request ([id] names this attempt: keep it for retries).
  Future<MaintenanceRequest> create(String id, MaintenanceDraft draft) async {
    final created = await _repository.createMaintenanceRequest(
      id: id,
      portfolioId: list.portfolioId,
      draft: draft,
    );
    ref.invalidate(maintenanceListProvider);
    return created;
  }
}

/// One maintenance request, the saved copy first.
final StreamNotifierProviderFamily<
  MaintenanceRequestController,
  Snapshot<MaintenanceRequest>,
  String
>
maintenanceRequestProvider = StreamNotifierProvider.autoDispose
    .family<MaintenanceRequestController, Snapshot<MaintenanceRequest>, String>(
      MaintenanceRequestController.new,
    );

/// Reads a request, saves it, moves it along its status and deletes it.
/// Commands throw [AppFailure].
final class MaintenanceRequestController
    extends SwrNotifier<MaintenanceRequest> {
  new(this.requestId);

  final String requestId;

  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);

  @override
  String get query => 'maintenance_request.$requestId';

  @override
  Stream<Snapshot<MaintenanceRequest>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<MaintenanceRequest> fetch() =>
      _repository.maintenanceRequest(requestId);

  @override
  MaintenanceRequest decode(Object? json) => MaintenanceRequest.fromRow(json);

  @override
  Object? encode(MaintenanceRequest value) => value.toRow();

  /// Saves [draft]; the lists, and the expenses that name the request,
  /// are read again.
  Future<MaintenanceRequest> save(MaintenanceDraft draft) async {
    final saved = await _repository.updateMaintenanceRequest(requestId, draft);
    ref
      ..invalidate(maintenanceListProvider)
      ..invalidate(expensesProvider);
    await show(saved);
    return saved;
  }

  /// Moves the request along its workflow ([move]), changing nothing else;
  /// the lists are read again.
  Future<MaintenanceRequest> move(MaintenanceMove move) async {
    final saved = await _repository.moveMaintenanceRequest(requestId, move);
    ref.invalidate(maintenanceListProvider);
    await show(saved);
    return saved;
  }

  /// Deletes the request (owners and managers); refused while expenses
  /// are recorded against it.
  Future<void> delete() async {
    await _repository.deleteMaintenanceRequest(requestId);
    ref.invalidate(maintenanceListProvider);
  }
}
