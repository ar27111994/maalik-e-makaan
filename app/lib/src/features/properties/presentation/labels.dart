import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_ui/mm_ui.dart';

/// The words for the property and unit values the database names.
extension PropertyWords on AppLocalizations {
  String propertyType(PropertyType type) => switch (type) {
    PropertyType.house => propertyTypeHouse,
    PropertyType.apartmentBuilding => propertyTypeApartmentBuilding,
    PropertyType.apartment => propertyTypeApartment,
    PropertyType.plaza => propertyTypePlaza,
    PropertyType.shop => propertyTypeShop,
    PropertyType.office => propertyTypeOffice,
    PropertyType.hostel => propertyTypeHostel,
    PropertyType.farmhouse => propertyTypeFarmhouse,
    PropertyType.warehouse => propertyTypeWarehouse,
    PropertyType.plot => propertyTypePlot,
    PropertyType.other => propertyTypeOther,
  };

  String province(Province province) => switch (province) {
    Province.punjab => provincePunjab,
    Province.sindh => provinceSindh,
    Province.khyberPakhtunkhwa => provinceKhyberPakhtunkhwa,
    Province.balochistan => provinceBalochistan,
    Province.islamabad => provinceIslamabad,
    Province.gilgitBaltistan => provinceGilgitBaltistan,
    Province.azadKashmir => provinceAzadKashmir,
  };

  String areaUnit(AreaUnit unit) => switch (unit) {
    AreaUnit.marla => areaUnitMarla,
    AreaUnit.kanal => areaUnitKanal,
    AreaUnit.squareFeet => areaUnitSquareFeet,
    AreaUnit.squareYards => areaUnitSquareYards,
    AreaUnit.squareMetres => areaUnitSquareMetres,
    AreaUnit.acre => areaUnitAcre,
  };

  String unitType(UnitType type) => switch (type) {
    UnitType.entireProperty => unitTypeEntireProperty,
    UnitType.portion => unitTypePortion,
    UnitType.apartment => unitTypeApartment,
    UnitType.room => unitTypeRoom,
    UnitType.bed => unitTypeBed,
    UnitType.shop => unitTypeShop,
    UnitType.office => unitTypeOffice,
    UnitType.floor => unitTypeFloor,
    UnitType.warehouse => unitTypeWarehouse,
    UnitType.other => propertyTypeOther,
  };

  /// What the law (or the app's reminder) asks about police registration
  /// of tenancies in [province].
  String policeHint(Province province) {
    final rule = province.policeRule;
    final name = this.province(province);
    if (!rule.statutory) return policeHintReminder(name);
    final days = dayCount(rule.days);
    return switch (rule.clock) {
      PoliceClock.possession => policeHintPossession(name, days),
      PoliceClock.agreement => policeHintAgreement(name, days),
    };
  }
}

/// Where [property] is: its area and city.
String propertyPlace(Property property) => [
  if (property.locality case final locality? when locality.isNotEmpty) locality,
  property.city,
].join(', ');

/// A badge saying whether a unit is let, from [occupancy] (null when the
/// server did not report it).
MmStatusBadge occupancyBadge(BuildContext context, Occupancy? occupancy) {
  final l10n = AppLocalizations.of(context);
  final status = occupancy?.status ?? OccupancyStatus.unknown;
  final since = occupancy?.vacantSince;
  return switch (status) {
    OccupancyStatus.occupied => MmStatusBadge(
      status: MmStatus.paid,
      icon: MmIcons.tenants,
      label: l10n.occupancyOccupied,
    ),
    OccupancyStatus.upcoming => MmStatusBadge(
      status: MmStatus.credit,
      icon: MmIcons.calendar,
      label: l10n.occupancyUpcoming,
    ),
    OccupancyStatus.vacant => MmStatusBadge(
      status: MmStatus.dueSoon,
      icon: MmIcons.unit,
      label: since == null
          ? l10n.occupancyVacant
          : l10n.occupancyVacantSince(dateLabel(context, since)),
    ),
    OccupancyStatus.unavailable => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.maintenance,
      label: l10n.occupancyUnavailable,
    ),
    OccupancyStatus.archived => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.archive,
      label: l10n.occupancyArchived,
    ),
    OccupancyStatus.unknown => MmStatusBadge(
      status: MmStatus.neutral,
      label: l10n.occupancyUnknown,
    ),
  };
}
