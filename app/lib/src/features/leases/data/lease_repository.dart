import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tenancies, their occupants and rent history. Every method throws
/// [AppFailure].
///
/// Owners and managers start and edit tenancies, change the rent
/// (`change_rent`) and end them (`end_lease`); only owners delete one, and
/// only while it holds no money of its own (`lease_has_records`).
abstract interface class LeaseRepository {
  /// The tenancies of a unit (or of a tenant), newest first.
  Future<List<Lease>> leases({String? unitId, String? tenantId});

  Future<LeaseDetail> lease(String leaseId);

  /// Starts a tenancy of [unitId] by [tenantId] on [terms], under the id
  /// chosen for this attempt. Refusals: `lease_overlap` (the unit is let
  /// then), `unit_archived`, `tenant_archived`, `constraint_violation`.
  Future<Lease> createLease({
    required String id,
    required String portfolioId,
    required String unitId,
    required String tenantId,
    required LeaseTerms terms,
  });

  /// Saves the editable terms (not the rent or the start).
  Future<Lease> updateLease(String leaseId, LeaseTerms terms);

  /// Sets the rent from [from] (`change_rent`). Refusals:
  /// `lease_not_active`, `invalid_amount`, `invalid_date`,
  /// `invalid_reason`.
  Future<void> changeRent(
    String leaseId, {
    required MonthPeriod from,
    required Money rent,
    required RentChangeReason reason,
    String? note,
  });

  /// Ends the tenancy on [movedOutOn] (`end_lease`). Refusals:
  /// `lease_not_active`, `invalid_date`, `reason_required`.
  Future<void> endLease(
    String leaseId, {
    required CalendarDate movedOutOn,
    required EndReason reason,
  });

  /// Deletes a tenancy entered by mistake.
  Future<void> deleteLease(String leaseId);

  Future<Occupant> addOccupant({
    required String portfolioId,
    required String leaseId,
    required Occupant occupant,
  });

  Future<Occupant> updateOccupant(Occupant occupant);

  Future<void> deleteOccupant(String occupantId);
}

/// [LeaseRepository] over `leases`, `lease_occupants`, `rent_changes` and
/// their functions.
final class SupabaseLeaseRepository implements LeaseRepository {
  new(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      // The exclusion constraint that keeps tenancies of a unit apart.
      if (error.code == '23P01') throw const RejectedFailure('lease_overlap');
      throw AppFailure.from(error);
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<Lease>> leases({String? unitId, String? tenantId}) =>
      _guard(() async {
        var query = _client.from('leases').select(Lease.columns);
        if (unitId != null) query = query.eq('unit_id', unitId);
        if (tenantId != null) query = query.eq('tenant_id', tenantId);
        final rows = await query
            .order('start_date', ascending: false)
            .order('id', ascending: false)
            .limit(50);
        return rows.map(Lease.fromRow).toList();
      });

  @override
  Future<LeaseDetail> lease(String leaseId) => _guard(() async {
    final row = await _client
        .from('leases')
        .select(Lease.columns)
        .eq('id', leaseId)
        .single();
    final occupants = await _client
        .from('lease_occupants')
        .select(Occupant.columns)
        .eq('lease_id', leaseId)
        .order('created_at', ascending: true);
    final changes = await _client
        .from('rent_changes')
        .select(RentChange.columns)
        .eq('lease_id', leaseId)
        .order('effective_from', ascending: false);
    return LeaseDetail(
      lease: Lease.fromRow(row),
      occupants: occupants.map(Occupant.fromRow).toList(),
      rentChanges: changes.map(RentChange.fromRow).toList(),
    );
  });

  @override
  Future<Lease> createLease({
    required String id,
    required String portfolioId,
    required String unitId,
    required String tenantId,
    required LeaseTerms terms,
  }) => _guard(() async {
    try {
      final row = await _client
          .from('leases')
          .insert({
            'id': id,
            'portfolio_id': portfolioId,
            'unit_id': unitId,
            'tenant_id': tenantId,
            ...terms.toWrite(),
          })
          .select(Lease.columns)
          .single();
      return Lease.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A retry of an insert that reached the server: the tenancy exists.
      final row = await _client
          .from('leases')
          .select(Lease.columns)
          .eq('id', id)
          .single();
      return Lease.fromRow(row);
    }
  });

  @override
  Future<Lease> updateLease(String leaseId, LeaseTerms terms) =>
      _guard(() async {
        final row = await _client
            .from('leases')
            .update(terms.toWrite(editable: true))
            .eq('id', leaseId)
            .select(Lease.columns)
            .single();
        return Lease.fromRow(row);
      });

  @override
  Future<void> changeRent(
    String leaseId, {
    required MonthPeriod from,
    required Money rent,
    required RentChangeReason reason,
    String? note,
  }) => _guard(() async {
    await _client.rpc<Object?>(
      'change_rent',
      params: {
        'p_lease_id': leaseId,
        'p_effective_month': from.first.toJson(),
        'p_monthly_rent': rent.toJson(),
        'p_reason': reason.db,
        'p_note': sanitizeOptional(note, maxLength: RentChange.maxNoteLength),
      },
    );
  });

  @override
  Future<void> endLease(
    String leaseId, {
    required CalendarDate movedOutOn,
    required EndReason reason,
  }) => _guard(() async {
    await _client.rpc<Object?>(
      'end_lease',
      params: {
        'p_lease_id': leaseId,
        'p_moved_out_on': movedOutOn.toJson(),
        'p_reason': reason.db,
      },
    );
  });

  @override
  Future<void> deleteLease(String leaseId) => _guard(() async {
    final deleted = await _client
        .from('leases')
        .delete()
        .eq('id', leaseId)
        .select('id');
    if (deleted.isEmpty) throw const Forbidden();
  });

  @override
  Future<Occupant> addOccupant({
    required String portfolioId,
    required String leaseId,
    required Occupant occupant,
  }) => _guard(() async {
    final row = await _client
        .from('lease_occupants')
        .insert({
          'id': occupant.id,
          'portfolio_id': portfolioId,
          'lease_id': leaseId,
          ...occupant.toWrite(),
        })
        .select(Occupant.columns)
        .single();
    return Occupant.fromRow(row);
  });

  @override
  Future<Occupant> updateOccupant(Occupant occupant) => _guard(() async {
    final row = await _client
        .from('lease_occupants')
        .update(occupant.toWrite())
        .eq('id', occupant.id)
        .select(Occupant.columns)
        .single();
    return Occupant.fromRow(row);
  });

  @override
  Future<void> deleteOccupant(String occupantId) => _guard(() async {
    final deleted = await _client
        .from('lease_occupants')
        .delete()
        .eq('id', occupantId)
        .select('id');
    if (deleted.isEmpty) throw const Forbidden();
  });
}

final leaseRepositoryProvider = Provider<LeaseRepository>(
  (ref) => SupabaseLeaseRepository(ref.watch(supabaseClientProvider)),
);
