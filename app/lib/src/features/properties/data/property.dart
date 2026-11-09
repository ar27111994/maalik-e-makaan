import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// What a property is (`public.property_type`).
enum PropertyType with DbEnum {
  house('house'),
  apartmentBuilding('apartment_building'),
  apartment('apartment'),
  plaza('plaza'),
  shop('shop'),
  office('office'),
  hostel('hostel'),
  farmhouse('farmhouse'),
  warehouse('warehouse'),
  plot('plot'),
  other('other');

  new(this.db);

  @override
  final String db;

  static PropertyType parse(String name) => parseDbEnum(values, name);
}

/// A jurisdiction (`public.province`): it decides the police-registration
/// deadline of a tenancy, among other rules.
enum Province with DbEnum {
  punjab('punjab'),
  sindh('sindh'),
  khyberPakhtunkhwa('khyber_pakhtunkhwa'),
  balochistan('balochistan'),
  islamabad('islamabad'),
  gilgitBaltistan('gilgit_baltistan'),
  azadKashmir('azad_kashmir');

  new(this.db);

  @override
  final String db;

  static Province parse(String name) => parseDbEnum(values, name);

  /// When a tenancy here must be registered with the police.
  PoliceRule get policeRule => PoliceRule.of(this);
}

/// What starts the police-registration clock.
enum PoliceClock {
  /// The tenant takes possession: the tenancy's start.
  possession,

  /// The agreement is signed (the start when no signing date is recorded).
  agreement,
}

/// The police tenant-registration rule of a jurisdiction, as
/// `app.police_registration_rule` decides it
/// (`supabase/migrations/20261107172908_police_registration_rules.sql`,
/// sources in `.planning/research/website-facts.md` §1): Punjab 15 days and
/// Sindh 48 hours from possession, Khyber Pakhtunkhwa 7 days and
/// Balochistan 3 days from signing the agreement. Islamabad, Gilgit-
/// Baltistan and Azad Kashmir have no statutory deadline the app knows of:
/// it reminds a day after possession, and says it is only a reminder.
@immutable
final class PoliceRule {
  const new({required this.days, required this.clock, required this.statutory});

  factory of(Province province) => switch (province) {
    Province.punjab => const PoliceRule(
      days: 15,
      clock: PoliceClock.possession,
      statutory: true,
    ),
    Province.sindh => const PoliceRule(
      days: 2,
      clock: PoliceClock.possession,
      statutory: true,
    ),
    Province.khyberPakhtunkhwa => const PoliceRule(
      days: 7,
      clock: PoliceClock.agreement,
      statutory: true,
    ),
    Province.balochistan => const PoliceRule(
      days: 3,
      clock: PoliceClock.agreement,
      statutory: true,
    ),
    Province.islamabad ||
    Province.gilgitBaltistan ||
    Province.azadKashmir => const PoliceRule(
      days: 1,
      clock: PoliceClock.possession,
      statutory: false,
    ),
  };

  /// Days after the clock starts.
  final int days;
  final PoliceClock clock;

  /// Whether a law fixes the deadline; otherwise it is the app's reminder.
  final bool statutory;

  /// The day the clock starts for a tenancy that [start]s then and whose
  /// agreement was signed on [agreementSignedOn] (when recorded).
  CalendarDate clockStartsOn(
    CalendarDate start,
    CalendarDate? agreementSignedOn,
  ) => clock == PoliceClock.agreement ? agreementSignedOn ?? start : start;

  /// The last day to register such a tenancy.
  CalendarDate deadline(CalendarDate start, CalendarDate? agreementSignedOn) =>
      clockStartsOn(start, agreementSignedOn).addDays(days);

  @override
  bool operator ==(Object other) =>
      other is PoliceRule &&
      other.days == days &&
      other.clock == clock &&
      other.statutory == statutory;

  @override
  int get hashCode => Object.hash(days, clock, statutory);
}

/// The unit of a plot's size (`public.area_unit`).
enum AreaUnit with DbEnum {
  marla('marla'),
  kanal('kanal'),
  squareFeet('sq_ft'),
  squareYards('sq_yd'),
  squareMetres('sq_m'),
  acre('acre');

  new(this.db);

  @override
  final String db;

  static AreaUnit parse(String name) => parseDbEnum(values, name);
}

/// A number with at most two decimals (`numeric(10,2)`, a plot's size),
/// kept exactly as hundredths.
@immutable
final class Hundredths implements Comparable<Hundredths> {
  const new(this.value);

  /// Reads a JSON number or numeric string exactly, as money is read.
  factory fromJson(Object? json) => Hundredths(Money.fromJson(json).paisa);

  /// [text] as typed (Urdu digits too), or null when it is not a number
  /// with at most two decimals.
  static Hundredths? tryParse(String text) {
    final money = Money.tryParseDecimal(normalizeDigits(text).trim());
    return money == null ? null : Hundredths(money.paisa);
  }

  /// The number times 100.
  final int value;

  bool get isPositive => value > 0;

  /// The plain number, without trailing zeros: `5`, `5.5`, `5.25`.
  @override
  String toString() {
    final whole = value ~/ 100;
    final fraction = value.abs() % 100;
    if (fraction == 0) return '$whole';
    final digits = fraction.toString().padLeft(2, '0');
    return '$whole.${digits.endsWith('0') ? digits[0] : digits}';
  }

  @override
  int compareTo(Hundredths other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Hundredths && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// A building or plot in a portfolio (PROP-01).
@immutable
final class Property {
  const new({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.province,
    this.addressLine,
    this.locality,
    this.plotSize,
    this.plotSizeUnit,
    this.coveredAreaSqft,
    this.yearBuilt,
    this.purchasePrice,
    this.purchasedOn,
    this.estimatedValue,
    this.valueEstimatedOn,
    this.propertyTaxRef,
    this.notes,
    this.archivedAt,
    this.createdAt = '',
  });

  /// Reads a `properties` row selected with [Property.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'property');
    final plot = row.optionalString('plot_size_unit');
    final size = row.optionalMoney('plot_size');
    return Property(
      id: row.string('id'),
      name: row.string('name'),
      type: row.choice('type', PropertyType.parse),
      addressLine: row.optionalString('address_line'),
      locality: row.optionalString('locality'),
      city: row.string('city'),
      province: row.choice('province', Province.parse),
      plotSize: size == null ? null : Hundredths(size.paisa),
      plotSizeUnit: plot == null ? null : AreaUnit.parse(plot),
      coveredAreaSqft: row.optionalInteger('covered_area_sqft'),
      yearBuilt: row.optionalInteger('year_built'),
      purchasePrice: row.optionalMoney('purchase_price'),
      purchasedOn: row.optionalDate('purchased_on'),
      estimatedValue: row.optionalMoney('estimated_value'),
      valueEstimatedOn: row.optionalDate('value_estimated_on'),
      propertyTaxRef: row.optionalString('property_tax_ref'),
      notes: row.optionalString('notes'),
      archivedAt: row.optionalTimestamp('archived_at'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [Property.fromRow] reads.
  static const columns =
      'id,name,type,address_line,locality,city,province,plot_size,'
      'plot_size_unit,covered_area_sqft,year_built,purchase_price,'
      'purchased_on,estimated_value,value_estimated_on,property_tax_ref,'
      'notes,archived_at,created_at';

  static const maxNameLength = 100;
  static const maxAddressLength = 200;
  static const maxLocalityLength = 100;
  static const maxCityLength = 60;
  static const maxTaxRefLength = 60;
  static const maxNotesLength = 2000;
  static const maxCoveredArea = 9999999;
  static const firstYear = 1850;
  static const lastYear = 2100;

  /// The largest plot size `numeric(10,2)` holds.
  static const maxPlotSize = Hundredths(9999999999);

  final String id;
  final String name;
  final PropertyType type;
  final String? addressLine;
  final String? locality;
  final String city;
  final Province province;
  final Hundredths? plotSize;
  final AreaUnit? plotSizeUnit;
  final int? coveredAreaSqft;
  final int? yearBuilt;
  final Money? purchasePrice;
  final CalendarDate? purchasedOn;
  final Money? estimatedValue;
  final CalendarDate? valueEstimatedOn;
  final String? propertyTaxRef;
  final String? notes;

  /// When it was archived; null while in use.
  final DateTime? archivedAt;

  /// When it was added, exactly as the server wrote it (the page cursor).
  final String createdAt;

  bool get archived => archivedAt != null;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// The editable columns, as the database stores them.
  Map<String, Object?> toWrite() => {
    'name': singleLineWithin(name, maxNameLength),
    'type': type.db,
    'address_line': optionalText(addressLine, maxAddressLength),
    'locality': optionalText(locality, maxLocalityLength),
    'city': singleLineWithin(city, maxCityLength),
    'province': province.db,
    'plot_size': plotSize?.toString(),
    'plot_size_unit': plotSize == null ? null : plotSizeUnit?.db,
    'covered_area_sqft': coveredAreaSqft,
    'year_built': yearBuilt,
    'purchase_price': purchasePrice?.toJson(),
    'purchased_on': purchasedOn?.toJson(),
    'estimated_value': estimatedValue?.toJson(),
    'value_estimated_on': valueEstimatedOn?.toJson(),
    'property_tax_ref': optionalText(propertyTaxRef, maxTaxRefLength),
    'notes': notes == null
        ? null
        : _blankToNull(linesWithin(notes!, maxNotesLength)),
  };

  /// The row [Property.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    ...toWrite(),
    'name': name,
    'city': city,
    'archived_at': archivedAt?.toIso8601String(),
    'created_at': createdAt,
  };

  @override
  bool operator ==(Object other) =>
      other is Property && listEquals(_list(other), _list(this));

  static List<Object?> _list(Property p) => [
    p.id,
    p.name,
    p.type,
    p.addressLine,
    p.locality,
    p.city,
    p.province,
    p.plotSize,
    p.plotSizeUnit,
    p.coveredAreaSqft,
    p.yearBuilt,
    p.purchasePrice,
    p.purchasedOn,
    p.estimatedValue,
    p.valueEstimatedOn,
    p.propertyTaxRef,
    p.notes,
    p.archivedAt,
    p.createdAt,
  ];

  @override
  int get hashCode => Object.hashAll(_list(this));
}

String? _blankToNull(String value) => value.isEmpty ? null : value;

/// What a unit is (`public.unit_type`).
enum UnitType with DbEnum {
  entireProperty('entire_property'),
  portion('portion'),
  apartment('apartment'),
  room('room'),
  bed('bed'),
  shop('shop'),
  office('office'),
  floor('floor'),
  warehouse('warehouse'),
  other('other');

  new(this.db);

  @override
  final String db;

  static UnitType parse(String name) => parseDbEnum(values, name);
}

/// A rentable part of a property (PROP-02).
@immutable
final class Unit {
  const new({
    required this.id,
    required this.propertyId,
    required this.label,
    required this.type,
    this.floorLabel,
    this.bedrooms,
    this.bathrooms,
    this.coveredAreaSqft,
    this.furnished = false,
    this.askingRent,
    this.isAvailable = true,
    this.notes,
    this.archivedAt,
    this.createdAt = '',
  });

  /// Reads a `units` row selected with [Unit.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'unit');
    return Unit(
      id: row.string('id'),
      propertyId: row.string('property_id'),
      label: row.string('label'),
      type: row.choice('type', UnitType.parse),
      floorLabel: row.optionalString('floor_label'),
      bedrooms: row.optionalInteger('bedrooms'),
      bathrooms: row.optionalInteger('bathrooms'),
      coveredAreaSqft: row.optionalInteger('covered_area_sqft'),
      furnished: row.boolean('furnished'),
      askingRent: row.optionalMoney('asking_rent'),
      isAvailable: row.boolean('is_available'),
      notes: row.optionalString('notes'),
      archivedAt: row.optionalTimestamp('archived_at'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [Unit.fromRow] reads.
  static const columns =
      'id,property_id,label,type,floor_label,bedrooms,bathrooms,'
      'covered_area_sqft,furnished,asking_rent,is_available,notes,'
      'archived_at,created_at';

  static const maxLabelLength = 60;
  static const maxFloorLength = 30;
  static const maxRooms = 50;

  final String id;
  final String propertyId;
  final String label;
  final UnitType type;
  final String? floorLabel;
  final int? bedrooms;
  final int? bathrooms;
  final int? coveredAreaSqft;
  final bool furnished;
  final Money? askingRent;

  /// False while it is renovated or the owner lives in it.
  final bool isAvailable;
  final String? notes;
  final DateTime? archivedAt;
  final String createdAt;

  bool get archived => archivedAt != null;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// The editable columns, as the database stores them.
  Map<String, Object?> toWrite() => {
    'label': singleLineWithin(label, maxLabelLength),
    'type': type.db,
    'floor_label': optionalText(floorLabel, maxFloorLength),
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'covered_area_sqft': coveredAreaSqft,
    'furnished': furnished,
    'asking_rent': askingRent?.toJson(),
    'is_available': isAvailable,
    'notes': notes == null
        ? null
        : _blankToNull(linesWithin(notes!, Property.maxNotesLength)),
  };

  /// The row [Unit.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    'property_id': propertyId,
    ...toWrite(),
    'label': label,
    'archived_at': archivedAt?.toIso8601String(),
    'created_at': createdAt,
  };

  static List<Object?> _list(Unit u) => [
    u.id,
    u.propertyId,
    u.label,
    u.type,
    u.floorLabel,
    u.bedrooms,
    u.bathrooms,
    u.coveredAreaSqft,
    u.furnished,
    u.askingRent,
    u.isAvailable,
    u.notes,
    u.archivedAt,
    u.createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is Unit && listEquals(_list(other), _list(this));

  @override
  int get hashCode => Object.hashAll(_list(this));
}

/// Whether a unit is let (PROP-03), from `public.unit_occupancy`.
enum OccupancyStatus with DbEnum {
  occupied('occupied'),

  /// A tenancy starts later.
  upcoming('upcoming'),
  vacant('vacant'),

  /// Not offered (renovation, the owner lives there).
  unavailable('unavailable'),
  archived('archived'),

  /// A status a newer server sends that this app does not know.
  unknown('unknown');

  new(this.db);

  @override
  final String db;

  static OccupancyStatus parse(String name) {
    for (final value in values) {
      if (value.db == name && value != unknown) return value;
    }
    return unknown;
  }
}

/// A unit's occupancy: its status, since when it is empty, and its current
/// tenancy.
@immutable
final class Occupancy {
  const new({
    required this.status,
    this.vacantSince,
    this.leaseId,
    this.tenantId,
  });

  /// Reads a `unit_occupancy` row selected with [Occupancy.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'occupancy');
    return Occupancy(
      status: row.choice('status', OccupancyStatus.parse),
      vacantSince: row.optionalDate('vacant_since'),
      leaseId: row.optionalString('lease_id'),
      tenantId: row.optionalString('tenant_id'),
    );
  }

  static const columns = 'unit_id,status,vacant_since,lease_id,tenant_id';

  final OccupancyStatus status;
  final CalendarDate? vacantSince;
  final String? leaseId;
  final String? tenantId;

  Map<String, Object?> toRow() => {
    'status': status.db,
    'vacant_since': vacantSince?.toJson(),
    'lease_id': leaseId,
    'tenant_id': tenantId,
  };

  @override
  bool operator ==(Object other) =>
      other is Occupancy &&
      other.status == status &&
      other.vacantSince == vacantSince &&
      other.leaseId == leaseId &&
      other.tenantId == tenantId;

  @override
  int get hashCode => Object.hash(status, vacantSince, leaseId, tenantId);
}

/// A unit with its occupancy.
@immutable
final class UnitSummary {
  const new(this.unit, this.occupancy);

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'unit');
    final occupancy = row.optionalObject('occupancy');
    return UnitSummary(
      Unit.fromRow(row.object('unit')),
      occupancy == null ? null : Occupancy.fromRow(occupancy),
    );
  }

  final Unit unit;

  /// Null when the server did not report it.
  final Occupancy? occupancy;

  Map<String, Object?> toJson() => {
    'unit': unit.toRow(),
    'occupancy': occupancy?.toRow(),
  };

  @override
  bool operator ==(Object other) =>
      other is UnitSummary &&
      other.unit == unit &&
      other.occupancy == occupancy;

  @override
  int get hashCode => Object.hash(unit, occupancy);
}
