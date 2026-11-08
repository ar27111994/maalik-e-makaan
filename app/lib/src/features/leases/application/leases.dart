import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease_repository.dart';
import 'package:maalik_e_makaan/src/features/properties/application/properties.dart';
import 'package:mm_core/mm_core.dart';

/// Whose tenancies a list shows: a unit's or a tenant's.
typedef LeaseList = ({String? unitId, String? tenantId});

/// A unit's or a tenant's tenancies, newest first, the saved copy first.
final StreamNotifierProviderFamily<
  LeasesController,
  Snapshot<List<Lease>>,
  LeaseList
>
leasesProvider = StreamNotifierProvider.autoDispose
    .family<LeasesController, Snapshot<List<Lease>>, LeaseList>(
      LeasesController.new,
    );

/// Reads a list of tenancies and starts new ones. Commands throw
/// [AppFailure].
final class LeasesController extends SwrNotifier<List<Lease>> {
  new(this.list);

  final LeaseList list;

  LeaseRepository get _repository => ref.read(leaseRepositoryProvider);

  @override
  String get query => 'leases.${list.unitId ?? '-'}.${list.tenantId ?? '-'}';

  @override
  Stream<Snapshot<List<Lease>>> build() {
    ref.watch(leaseRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<Lease>> fetch() =>
      _repository.leases(unitId: list.unitId, tenantId: list.tenantId);

  @override
  List<Lease> decode(Object? json) {
    final rows = JsonRow.of({'rows': json}).list('rows');
    return [for (final row in rows) Lease.fromRow(row)];
  }

  @override
  Object? encode(List<Lease> value) => [for (final l in value) l.toRow()];

  /// Starts a tenancy (its [id] names this attempt: keep it for retries).
  Future<Lease> start({
    required String id,
    required String portfolioId,
    required String unitId,
    required String tenantId,
    required LeaseTerms terms,
  }) async {
    final lease = await _repository.createLease(
      id: id,
      portfolioId: portfolioId,
      unitId: unitId,
      tenantId: tenantId,
      terms: terms,
    );
    _occupancyChanged(ref, lease);
    return lease;
  }
}

/// Whatever shows a unit's occupancy or a list of tenancies is read again.
void _occupancyChanged(Ref ref, Lease lease) {
  ref
    ..invalidate(leasesProvider)
    ..invalidate(unitProvider(lease.unitId))
    ..invalidate(unitsProvider(lease.propertyId));
}

/// One tenancy with its occupants and rent history, the saved copy first.
final StreamNotifierProviderFamily<
  LeaseController,
  Snapshot<LeaseDetail>,
  String
>
leaseProvider = StreamNotifierProvider.autoDispose
    .family<LeaseController, Snapshot<LeaseDetail>, String>(
      LeaseController.new,
    );

/// Reads a tenancy and changes it. Commands throw [AppFailure] and, once
/// the server has answered, show the tenancy as it now is.
final class LeaseController extends SwrNotifier<LeaseDetail> {
  new(this.leaseId);

  final String leaseId;

  LeaseRepository get _repository => ref.read(leaseRepositoryProvider);

  @override
  String get query => 'lease.$leaseId';

  @override
  Stream<Snapshot<LeaseDetail>> build() {
    ref.watch(leaseRepositoryProvider);
    return super.build();
  }

  @override
  Future<LeaseDetail> fetch() => _repository.lease(leaseId);

  @override
  LeaseDetail decode(Object? json) => LeaseDetail.fromJson(json);

  @override
  Object? encode(LeaseDetail value) => value.toJson();

  Future<void> _changed() async {
    ref.invalidate(leasesProvider);
    await reload();
  }

  /// Saves the editable terms.
  Future<Lease> save(LeaseTerms terms) async {
    final lease = await _repository.updateLease(leaseId, terms);
    await _changed();
    return lease;
  }

  Future<void> changeRent({
    required MonthPeriod from,
    required Money rent,
    required RentChangeReason reason,
    String? note,
  }) async {
    await _repository.changeRent(
      leaseId,
      from: from,
      rent: rent,
      reason: reason,
      note: note,
    );
    await _changed();
  }

  /// Ends the tenancy; the unit becomes vacant.
  Future<void> end({
    required CalendarDate movedOutOn,
    required EndReason reason,
  }) async {
    final lease = state.value?.value.lease;
    await _repository.endLease(leaseId, movedOutOn: movedOutOn, reason: reason);
    if (lease != null) _occupancyChanged(ref, lease);
    await reload();
  }

  /// Deletes the tenancy (owners, for mistakes).
  Future<void> delete() async {
    final lease = state.value?.value.lease;
    await _repository.deleteLease(leaseId);
    if (lease != null) _occupancyChanged(ref, lease);
  }

  Future<void> addOccupant(String portfolioId, Occupant occupant) async {
    await _repository.addOccupant(
      portfolioId: portfolioId,
      leaseId: leaseId,
      occupant: occupant,
    );
    await reload();
  }

  Future<void> saveOccupant(Occupant occupant) async {
    await _repository.updateOccupant(occupant);
    await reload();
  }

  Future<void> removeOccupant(String occupantId) async {
    await _repository.deleteOccupant(occupantId);
    await reload();
  }
}
