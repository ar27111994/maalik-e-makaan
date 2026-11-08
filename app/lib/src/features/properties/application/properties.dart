import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property_repository.dart';

/// Which properties a list shows: a portfolio's in use, or its archived.
typedef PropertyList = ({String portfolioId, bool archived});

/// The properties of a portfolio, the saved copy first, then the server's,
/// 50 at a time.
final StreamNotifierProviderFamily<
  PropertiesController,
  Snapshot<Paged<Property>>,
  PropertyList
>
propertiesProvider = StreamNotifierProvider.autoDispose
    .family<PropertiesController, Snapshot<Paged<Property>>, PropertyList>(
      PropertiesController.new,
    );

/// Reads a list of properties and adds new ones. Commands throw
/// [AppFailure].
final class PropertiesController extends SwrNotifier<Paged<Property>> {
  new(this.list);

  final PropertyList list;

  PropertyRepository get _repository => ref.read(propertyRepositoryProvider);

  @override
  String get query =>
      'properties.${list.portfolioId}.${list.archived ? 'archived' : 'active'}';

  @override
  Stream<Snapshot<Paged<Property>>> build() {
    ref.watch(propertyRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<Property>> fetch() =>
      _repository.properties(list.portfolioId, archived: list.archived);

  @override
  Paged<Property> decode(Object? json) =>
      Paged.fromJson(json, Property.fromRow);

  @override
  Object? encode(Paged<Property> value) => value.toJson((p) => p.toRow());

  /// Reads the next page and shows it after the rows already shown.
  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.properties(
      list.portfolioId,
      archived: list.archived,
      after: next,
    );
    await show(current.followedBy(more));
  }

  /// Adds [property] (its id names this attempt: keep it for retries).
  Future<Property> create(Property property) async {
    final created = await _repository.createProperty(
      list.portfolioId,
      property,
    );
    ref.invalidate(propertiesProvider);
    return created;
  }
}

/// One property, the saved copy first.
final StreamNotifierProviderFamily<
  PropertyController,
  Snapshot<Property>,
  String
>
propertyProvider = StreamNotifierProvider.autoDispose
    .family<PropertyController, Snapshot<Property>, String>(
      PropertyController.new,
    );

/// Reads a property and changes it. Commands throw [AppFailure] and, once
/// the server has answered, refresh the property lists.
final class PropertyController extends SwrNotifier<Property> {
  new(this.propertyId);

  final String propertyId;

  PropertyRepository get _repository => ref.read(propertyRepositoryProvider);

  @override
  String get query => 'property.$propertyId';

  @override
  Stream<Snapshot<Property>> build() {
    ref.watch(propertyRepositoryProvider);
    return super.build();
  }

  @override
  Future<Property> fetch() => _repository.property(propertyId);

  @override
  Property decode(Object? json) => Property.fromRow(json);

  @override
  Object? encode(Property value) => value.toRow();

  Future<void> _saved(Property property) async {
    ref.invalidate(propertiesProvider);
    await show(property);
  }

  Future<Property> save(Property property) async {
    final saved = await _repository.updateProperty(property);
    await _saved(saved);
    return saved;
  }

  /// Archives the property, or puts it back in use.
  Future<Property> archive({required bool archived}) async {
    final saved = await _repository.archiveProperty(
      propertyId,
      archived: archived,
    );
    await _saved(saved);
    return saved;
  }

  /// Deletes the property (owners, for mistakes).
  Future<void> delete() async {
    await _repository.deleteProperty(propertyId);
    ref.invalidate(propertiesProvider);
  }
}

/// The units of a property with their occupancy, the saved copy first.
final StreamNotifierProviderFamily<
  UnitsController,
  Snapshot<Paged<UnitSummary>>,
  String
>
unitsProvider = StreamNotifierProvider.autoDispose
    .family<UnitsController, Snapshot<Paged<UnitSummary>>, String>(
      UnitsController.new,
    );

/// Reads a property's units and adds new ones.
final class UnitsController extends SwrNotifier<Paged<UnitSummary>> {
  new(this.propertyId);

  final String propertyId;

  PropertyRepository get _repository => ref.read(propertyRepositoryProvider);

  @override
  String get query => 'units.$propertyId';

  @override
  Stream<Snapshot<Paged<UnitSummary>>> build() {
    ref.watch(propertyRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<UnitSummary>> fetch() => _repository.units(propertyId);

  @override
  Paged<UnitSummary> decode(Object? json) =>
      Paged.fromJson(json, UnitSummary.fromJson);

  @override
  Object? encode(Paged<UnitSummary> value) =>
      value.toJson((unit) => unit.toJson());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.units(propertyId, after: next);
    await show(current.followedBy(more));
  }

  /// Adds [unit] to the property in [portfolioId].
  Future<Unit> create(String portfolioId, Unit unit) async {
    final created = await _repository.createUnit(portfolioId, unit);
    await reload();
    return created;
  }
}

/// One unit with its occupancy, the saved copy first.
final StreamNotifierProviderFamily<
  UnitController,
  Snapshot<UnitSummary>,
  String
>
unitProvider = StreamNotifierProvider.autoDispose
    .family<UnitController, Snapshot<UnitSummary>, String>(UnitController.new);

/// Reads a unit and changes it.
final class UnitController extends SwrNotifier<UnitSummary> {
  new(this.unitId);

  final String unitId;

  PropertyRepository get _repository => ref.read(propertyRepositoryProvider);

  @override
  String get query => 'unit.$unitId';

  @override
  Stream<Snapshot<UnitSummary>> build() {
    ref.watch(propertyRepositoryProvider);
    return super.build();
  }

  @override
  Future<UnitSummary> fetch() => _repository.unit(unitId);

  @override
  UnitSummary decode(Object? json) => UnitSummary.fromJson(json);

  @override
  Object? encode(UnitSummary value) => value.toJson();

  Future<Unit> save(Unit unit) async {
    final saved = await _repository.updateUnit(unit);
    ref.invalidate(unitsProvider(saved.propertyId));
    await reload();
    return saved;
  }

  Future<Unit> archive({required bool archived}) async {
    final saved = await _repository.archiveUnit(unitId, archived: archived);
    ref.invalidate(unitsProvider(saved.propertyId));
    await reload();
    return saved;
  }

  /// Deletes the unit (owners, for mistakes).
  Future<void> delete(String propertyId) async {
    await _repository.deleteUnit(unitId);
    ref.invalidate(unitsProvider(propertyId));
  }
}
