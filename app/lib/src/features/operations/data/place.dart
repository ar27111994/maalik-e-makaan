import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';

/// A property in use and its units in use, to choose where an expense, a
/// connection or a repair belongs.
@immutable
final class PropertyPlace {
  const new({required this.id, required this.name, this.units = const []});

  /// Reads a `properties` row selected with [PropertyPlace.columns]; units
  /// that are archived are left out.
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'place');
    return PropertyPlace(
      id: row.string('id'),
      name: row.string('name'),
      units: [
        for (final unit in row.list('units'))
          if (JsonRow.of(unit, 'unit').optionalString('archived_at') == null)
            UnitPlace.fromRow(unit),
      ],
    );
  }

  /// The columns [PropertyPlace.fromRow] reads, its units embedded.
  static const columns =
      'id,name,units:units!units_property_fkey(id,label,archived_at)';

  final String id;
  final String name;
  final List<UnitPlace> units;

  /// The label of its unit [unitId], if it has one.
  String? unitLabel(String? unitId) {
    for (final unit in units) {
      if (unit.id == unitId) return unit.label;
    }
    return null;
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'units': [for (final unit in units) unit.toRow()],
  };

  @override
  bool operator ==(Object other) =>
      other is PropertyPlace &&
      other.id == id &&
      other.name == name &&
      listEquals(other.units, units);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(units));
}

/// A unit in use, within a [PropertyPlace].
@immutable
final class UnitPlace {
  const new({required this.id, required this.label});

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'unit');
    return UnitPlace(id: row.string('id'), label: row.string('label'));
  }

  final String id;
  final String label;

  Map<String, Object?> toRow() => {
    'id': id,
    'label': label,
    'archived_at': null,
  };

  @override
  bool operator ==(Object other) =>
      other is UnitPlace && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// The place named by [propertyId] in [places], if it is there.
PropertyPlace? placeOf(List<PropertyPlace> places, String? propertyId) {
  for (final place in places) {
    if (place.id == propertyId) return place;
  }
  return null;
}
