import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';

/// The properties in use of a portfolio and their units, to choose where an
/// expense, a connection or a repair belongs; the saved copy first.
final StreamNotifierProviderFamily<
  PlacesController,
  Snapshot<List<PropertyPlace>>,
  String
>
placesProvider = StreamNotifierProvider.autoDispose
    .family<PlacesController, Snapshot<List<PropertyPlace>>, String>(
      PlacesController.new,
    );

/// Reads the places of a portfolio.
final class PlacesController extends SwrNotifier<List<PropertyPlace>> {
  new(this.portfolioId);

  final String portfolioId;

  @override
  String get query => 'places.$portfolioId';

  @override
  Stream<Snapshot<List<PropertyPlace>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<PropertyPlace>> fetch() =>
      ref.read(operationsRepositoryProvider).places(portfolioId);

  @override
  List<PropertyPlace> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      PropertyPlace.fromRow(row),
  ];

  @override
  Object? encode(List<PropertyPlace> value) => [
    for (final place in value) place.toRow(),
  ];
}

/// Where tenancies are looked for: a unit, or every unit of a property.
typedef TenancyPlace = ({String propertyId, String? unitId});

/// The tenancies of a unit or a property, newest first, the saved copy
/// first: to link a repair or a reading to one, or bill a utility to it.
final StreamNotifierProviderFamily<
  TenanciesController,
  Snapshot<List<Lease>>,
  TenancyPlace
>
tenanciesProvider = StreamNotifierProvider.autoDispose
    .family<TenanciesController, Snapshot<List<Lease>>, TenancyPlace>(
      TenanciesController.new,
    );

/// Reads the tenancies of a place.
final class TenanciesController extends SwrNotifier<List<Lease>> {
  new(this.place);

  final TenancyPlace place;

  @override
  String get query => 'tenancies.${place.propertyId}.${place.unitId ?? '-'}';

  @override
  Stream<Snapshot<List<Lease>>> build() {
    ref.watch(operationsRepositoryProvider);
    return super.build();
  }

  @override
  Future<List<Lease>> fetch() => ref
      .read(operationsRepositoryProvider)
      .tenancies(propertyId: place.propertyId, unitId: place.unitId);

  @override
  List<Lease> decode(Object? json) => [
    for (final row in JsonRow.of({'rows': json}).list('rows'))
      Lease.fromRow(row),
  ];

  @override
  Object? encode(List<Lease> value) => [for (final l in value) l.toRow()];
}
