import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Properties and their units. Every method throws [AppFailure].
///
/// Owners and managers add, edit and archive; only owners delete, and only
/// what no tenancy or expense refers to (`still_in_use`; archive instead).
abstract interface class PropertyRepository {
  /// A page of [portfolioId]'s properties, archived or in use, oldest first.
  Future<Paged<Property>> properties(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  });

  Future<Property> property(String propertyId);

  /// Adds [property] to [portfolioId] under the id the caller chose for
  /// this attempt, so a retry returns the same property. Refusals:
  /// `duplicate_property_name`, `constraint_violation`.
  Future<Property> createProperty(String portfolioId, Property property);

  /// Saves [property]'s editable fields and returns it as stored.
  Future<Property> updateProperty(Property property);

  /// Archives the property (or puts it back in use when [archived] is false).
  Future<Property> archiveProperty(String propertyId, {required bool archived});

  /// Deletes a property added by mistake, with its units.
  Future<void> deleteProperty(String propertyId);

  /// A page of [propertyId]'s units, with their occupancy, oldest first.
  Future<Paged<UnitSummary>> units(String propertyId, {PageCursor? after});

  Future<UnitSummary> unit(String unitId);

  /// Adds [unit] (to `unit.propertyId`) in [portfolioId]. Refusals:
  /// `duplicate_unit_label`, `constraint_violation`.
  Future<Unit> createUnit(String portfolioId, Unit unit);

  Future<Unit> updateUnit(Unit unit);

  Future<Unit> archiveUnit(String unitId, {required bool archived});

  Future<void> deleteUnit(String unitId);
}

/// [PropertyRepository] over `properties`, `units` and `unit_occupancy`.
final class SupabasePropertyRepository implements PropertyRepository {
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
  /// returns the row already there, or a clash with another row's name,
  /// which is refused as [duplicate].
  Future<Map<String, dynamic>> _insert(
    String table,
    Map<String, Object?> row,
    String columns,
    String duplicate,
  ) async {
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
      throw RejectedFailure(duplicate);
    }
  }

  /// Updates [id] of [table] with [values] and reads it back. A unique
  /// violation is refused as [duplicate].
  Future<Map<String, dynamic>> _update(
    String table,
    String id,
    Map<String, Object?> values,
    String columns,
    String duplicate,
  ) async {
    try {
      return await _client
          .from(table)
          .update(values)
          .eq('id', id)
          .select(columns)
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw RejectedFailure(duplicate);
      rethrow;
    }
  }

  /// Deletes [id] of [table]. A row something still refers to is refused
  /// with `still_in_use`; a row the caller may not delete (row security
  /// hides it from the delete) is [Forbidden].
  Future<void> _delete(String table, String id) async {
    try {
      final deleted = await _client
          .from(table)
          .delete()
          .eq('id', id)
          .select('id');
      if (deleted.isEmpty) throw const Forbidden();
    } on PostgrestException catch (error) {
      if (error.code == '23503') throw const RejectedFailure('still_in_use');
      rethrow;
    }
  }

  String? _archivedAt({required bool archived}) =>
      archived ? _clock().toUtc().toIso8601String() : null;

  @override
  Future<Paged<Property>> properties(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  }) => _guard(() async {
    final query = _client
        .from('properties')
        .select(Property.columns)
        .eq('portfolio_id', portfolioId);
    final filtered = archived
        ? query.not('archived_at', 'is', null)
        : query.isFilter('archived_at', null);
    final rows = await filtered
        .after(after)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(pageSize);
    return Paged.page(rows.map(Property.fromRow).toList(), (p) => p.cursor);
  });

  @override
  Future<Property> property(String propertyId) => _guard(() async {
    final row = await _client
        .from('properties')
        .select(Property.columns)
        .eq('id', propertyId)
        .single();
    return Property.fromRow(row);
  });

  @override
  Future<Property> createProperty(String portfolioId, Property property) =>
      _guard(() async {
        final row = await _insert(
          'properties',
          {
            'id': property.id,
            'portfolio_id': portfolioId,
            ...property.toWrite(),
          },
          Property.columns,
          'duplicate_property_name',
        );
        return Property.fromRow(row);
      });

  @override
  Future<Property> updateProperty(Property property) => _guard(() async {
    final row = await _update(
      'properties',
      property.id,
      property.toWrite(),
      Property.columns,
      'duplicate_property_name',
    );
    return Property.fromRow(row);
  });

  @override
  Future<Property> archiveProperty(
    String propertyId, {
    required bool archived,
  }) => _guard(() async {
    final row = await _update(
      'properties',
      propertyId,
      {'archived_at': _archivedAt(archived: archived)},
      Property.columns,
      'duplicate_property_name',
    );
    return Property.fromRow(row);
  });

  @override
  Future<void> deleteProperty(String propertyId) =>
      _guard(() => _delete('properties', propertyId));

  @override
  Future<Paged<UnitSummary>> units(String propertyId, {PageCursor? after}) =>
      _guard(() async {
        final rows = await _client
            .from('units')
            .select(Unit.columns)
            .eq('property_id', propertyId)
            .after(after)
            .order('created_at', ascending: true)
            .order('id', ascending: true)
            .limit(pageSize);
        final units = rows.map(Unit.fromRow).toList();
        final occupancy = await _occupancy([for (final u in units) u.id]);
        return Paged.page([
          for (final unit in units) UnitSummary(unit, occupancy[unit.id]),
        ], (summary) => summary.unit.cursor);
      });

  Future<Map<String, Occupancy>> _occupancy(List<String> unitIds) async {
    if (unitIds.isEmpty) return const {};
    final rows = await _client
        .from('unit_occupancy')
        .select(Occupancy.columns)
        .inFilter('unit_id', unitIds);
    return {
      for (final row in rows) row['unit_id'] as String: Occupancy.fromRow(row),
    };
  }

  @override
  Future<UnitSummary> unit(String unitId) => _guard(() async {
    final row = await _client
        .from('units')
        .select(Unit.columns)
        .eq('id', unitId)
        .single();
    final unit = Unit.fromRow(row);
    return UnitSummary(unit, (await _occupancy([unit.id]))[unit.id]);
  });

  @override
  Future<Unit> createUnit(String portfolioId, Unit unit) => _guard(() async {
    final row = await _insert(
      'units',
      {
        'id': unit.id,
        'portfolio_id': portfolioId,
        'property_id': unit.propertyId,
        ...unit.toWrite(),
      },
      Unit.columns,
      'duplicate_unit_label',
    );
    return Unit.fromRow(row);
  });

  @override
  Future<Unit> updateUnit(Unit unit) => _guard(() async {
    final row = await _update(
      'units',
      unit.id,
      unit.toWrite(),
      Unit.columns,
      'duplicate_unit_label',
    );
    return Unit.fromRow(row);
  });

  @override
  Future<Unit> archiveUnit(String unitId, {required bool archived}) =>
      _guard(() async {
        final row = await _update(
          'units',
          unitId,
          {'archived_at': _archivedAt(archived: archived)},
          Unit.columns,
          'duplicate_unit_label',
        );
        return Unit.fromRow(row);
      });

  @override
  Future<void> deleteUnit(String unitId) =>
      _guard(() => _delete('units', unitId));
}

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => SupabasePropertyRepository(ref.watch(supabaseClientProvider)),
);
