import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';

/// Whose a due or payment is: the tenant, the unit and its property, read
/// through the tenancy (`leases`).
@immutable
final class ExportTenancy {
  const new({
    required this.tenantName,
    required this.unitLabel,
    required this.propertyName,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'tenancy');
    final unit = row.object('unit');
    return ExportTenancy(
      tenantName: row.object('tenant').string('full_name'),
      unitLabel: unit.string('label'),
      propertyName: unit.object('property').string('name'),
    );
  }

  /// The tenancy's columns, embedded under `lease`.
  static const columns =
      'tenant:tenants!leases_tenant_fkey(full_name),'
      'unit:units!leases_unit_fkey(label,'
      'property:properties!units_property_fkey(name))';

  final String tenantName;
  final String unitLabel;
  final String propertyName;

  @override
  bool operator ==(Object other) =>
      other is ExportTenancy &&
      other.tenantName == tenantName &&
      other.unitLabel == unitLabel &&
      other.propertyName == propertyName;

  @override
  int get hashCode => Object.hash(tenantName, unitLabel, propertyName);
}

/// A due, with whose it is, for the ledger export (RPT-03).
@immutable
final class ExportCharge {
  const new({required this.charge, required this.tenancy});

  factory fromRow(Object? json) => ExportCharge(
    charge: Charge.fromRow(json),
    tenancy: ExportTenancy.fromRow(JsonRow.of(json).object('lease')),
  );

  static const columns =
      '${Charge.columns},'
      'lease:leases!charges_lease_fkey(${ExportTenancy.columns})';

  final Charge charge;
  final ExportTenancy tenancy;

  @override
  bool operator ==(Object other) =>
      other is ExportCharge &&
      other.charge == charge &&
      other.tenancy == tenancy;

  @override
  int get hashCode => Object.hash(charge, tenancy);
}

/// A payment, with whose it is, for the payments export (RPT-03).
@immutable
final class ExportPayment {
  const new({required this.payment, required this.tenancy});

  factory fromRow(Object? json) => ExportPayment(
    payment: Payment.fromRow(json),
    tenancy: ExportTenancy.fromRow(JsonRow.of(json).object('lease')),
  );

  static const columns =
      '${Payment.columns},'
      'lease:leases!payments_lease_fkey(${ExportTenancy.columns})';

  final Payment payment;
  final ExportTenancy tenancy;

  @override
  bool operator ==(Object other) =>
      other is ExportPayment &&
      other.payment == payment &&
      other.tenancy == tenancy;

  @override
  int get hashCode => Object.hash(payment, tenancy);
}

/// An active tenancy's rent beside its unit's asking rent, to find units
/// let for less than the landlord asks for them (INS-04).
@immutable
final class RentRollEntry {
  const new({
    required this.leaseId,
    required this.tenantName,
    required this.unitLabel,
    required this.propertyName,
    required this.monthlyRent,
    this.askingRent,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'rent roll');
    final unit = row.object('unit');
    return RentRollEntry(
      leaseId: row.string('id'),
      tenantName: row.object('tenant').string('full_name'),
      unitLabel: unit.string('label'),
      propertyName: unit.object('property').string('name'),
      monthlyRent: row.money('monthly_rent'),
      askingRent: unit.optionalMoney('asking_rent'),
    );
  }

  static const columns =
      'id,monthly_rent,created_at,'
      'tenant:tenants!leases_tenant_fkey(full_name),'
      'unit:units!leases_unit_fkey(label,asking_rent,'
      'property:properties!units_property_fkey(name))';

  final String leaseId;
  final String tenantName;
  final String unitLabel;
  final String propertyName;
  final Money monthlyRent;

  /// What the landlord asks for the unit today, when set.
  final Money? askingRent;

  Map<String, Object?> toRow() => {
    'id': leaseId,
    'monthly_rent': monthlyRent.toJson(),
    'tenant': {'full_name': tenantName},
    'unit': {
      'label': unitLabel,
      'asking_rent': askingRent?.toJson(),
      'property': {'name': propertyName},
    },
  };

  @override
  bool operator ==(Object other) =>
      other is RentRollEntry &&
      other.leaseId == leaseId &&
      other.tenantName == tenantName &&
      other.unitLabel == unitLabel &&
      other.propertyName == propertyName &&
      other.monthlyRent == monthlyRent &&
      other.askingRent == askingRent;

  @override
  int get hashCode => Object.hash(
    leaseId,
    tenantName,
    unitLabel,
    propertyName,
    monthlyRent,
    askingRent,
  );
}
