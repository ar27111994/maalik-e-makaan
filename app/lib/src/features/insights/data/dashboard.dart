import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

/// A share (`numeric` from 0 to 1, rounded to 4 places by the server) in
/// basis points: 0.8235 is 8235. Null stays null (nothing to divide by).
int? ratioBasisPoints(Object? value, String field) {
  if (value == null) return null;
  if (value is num && value.isFinite) return (value * 10000).round();
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null && parsed.isFinite) return (parsed * 10000).round();
  }
  throw FormatException('$field is not a number', value);
}

/// [basisPoints] as the server writes the share: 8235 is 0.8235.
String? ratioToJson(int? basisPoints) =>
    basisPoints == null ? null : (basisPoints / 10000).toStringAsFixed(4);

/// Equality and hashing for the flat rows of the dashboard, through what
/// each row writes.
mixin _RowValue {
  Map<String, Object?> toRow();

  @override
  bool operator ==(Object other) =>
      other is _RowValue &&
      other.runtimeType == runtimeType &&
      mapEquals(other.toRow(), toRow());

  @override
  int get hashCode => Object.hashAll(toRow().values);
}

/// This month's dues and collections (INS-01): what fell due (rent, late
/// fees and other charges, not deposits), what of it is paid, the cash
/// received in the month by method and the tax withheld from it.
@immutable
final class MonthCollection with _RowValue {
  const new({
    required this.period,
    required this.expected,
    required this.paid,
    required this.cashReceived,
    required this.taxWithheld,
    this.collectionRate,
    this.byMethod = const {},
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'month');
    final map = json! as Map;
    final methods = row.object('by_method');
    return MonthCollection(
      period: MonthPeriod.of(row.date('period')),
      expected: row.money('expected'),
      paid: row.money('paid'),
      collectionRate: ratioBasisPoints(
        map['collection_rate'],
        'collection_rate',
      ),
      cashReceived: row.money('cash_received'),
      taxWithheld: row.money('tax_withheld'),
      byMethod: {
        for (final key in (map['by_method']! as Map).keys.cast<String>())
          PaymentMethod.parse(key): methods.money(key),
      },
    );
  }

  final MonthPeriod period;

  /// What fell due in the month, less what was waived.
  final Money expected;

  /// What of it is paid.
  final Money paid;

  /// [paid] over [expected] in basis points; null when nothing fell due.
  final int? collectionRate;

  /// Money received in the month, whatever it paid.
  final Money cashReceived;
  final Money taxWithheld;

  /// [cashReceived] by how it was paid.
  final Map<PaymentMethod, Money> byMethod;

  /// What fell due and is not paid.
  Money get unpaid => Money.max(expected - paid, Money.zero);

  @override
  Map<String, Object?> toRow() => {
    'period': period.first.toIso(),
    'expected': expected.toJson(),
    'paid': paid.toJson(),
    'collection_rate': ratioToJson(collectionRate),
    'cash_received': cashReceived.toJson(),
    'tax_withheld': taxWithheld.toJson(),
    'by_method': {
      for (final entry in byMethod.entries) entry.key.db: entry.value.toJson(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is MonthCollection &&
      other.period == period &&
      other.expected == expected &&
      other.paid == paid &&
      other.collectionRate == collectionRate &&
      other.cashReceived == cashReceived &&
      other.taxWithheld == taxWithheld &&
      mapEquals(other.byMethod, byMethod);

  @override
  int get hashCode => Object.hash(
    period,
    expected,
    paid,
    collectionRate,
    cashReceived,
    taxWithheld,
    Object.hashAllUnordered(byMethod.entries.map((e) => (e.key, e.value))),
  );
}

/// What is owed and how old it is: not yet due, then overdue by age.
@immutable
final class Ageing with _RowValue {
  const new({
    required this.total,
    required this.overdue,
    required this.notDue,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'outstanding');
    final aging = row.object('aging');
    return Ageing(
      total: row.money('total'),
      overdue: row.money('overdue'),
      notDue: aging.money('not_due'),
      days1to30: aging.money('d1_30'),
      days31to60: aging.money('d31_60'),
      days61to90: aging.money('d61_90'),
      over90: aging.money('d90_plus'),
    );
  }

  /// All that is owed, due or not.
  final Money total;

  /// What is past its due date.
  final Money overdue;
  final Money notDue;
  final Money days1to30;
  final Money days31to60;
  final Money days61to90;
  final Money over90;

  @override
  Map<String, Object?> toRow() => {
    'total': total.toJson(),
    'overdue': overdue.toJson(),
    'aging': {
      'not_due': notDue.toJson(),
      'd1_30': days1to30.toJson(),
      'd31_60': days31to60.toJson(),
      'd61_90': days61to90.toJson(),
      'd90_plus': over90.toJson(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is Ageing &&
      other.total == total &&
      other.overdue == overdue &&
      other.notDue == notDue &&
      other.days1to30 == days1to30 &&
      other.days31to60 == days31to60 &&
      other.days61to90 == days61to90 &&
      other.over90 == over90;

  @override
  int get hashCode => Object.hash(
    total,
    overdue,
    notDue,
    days1to30,
    days31to60,
    days61to90,
    over90,
  );
}

/// The portfolio's units in use: let, vacant (available to let) and not
/// available, with the occupancy rate of the units that can be let.
@immutable
final class Occupancy with _RowValue {
  const new({
    required this.units,
    required this.occupied,
    required this.vacant,
    required this.unavailable,
    required this.vacantAskingRent,
    this.rate,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'occupancy');
    return Occupancy(
      units: row.integer('units'),
      occupied: row.integer('occupied'),
      vacant: row.integer('vacant'),
      unavailable: row.integer('unavailable'),
      rate: ratioBasisPoints((json! as Map)['rate'], 'rate'),
      vacantAskingRent: row.money('vacant_asking_rent'),
    );
  }

  final int units;
  final int occupied;
  final int vacant;
  final int unavailable;

  /// Occupied over the units that can be let, in basis points; null when
  /// there are none.
  final int? rate;

  /// The asking rent of the vacant units: what they lose each month.
  final Money vacantAskingRent;

  @override
  Map<String, Object?> toRow() => {
    'units': units,
    'occupied': occupied,
    'vacant': vacant,
    'unavailable': unavailable,
    'rate': ratioToJson(rate),
    'vacant_asking_rent': vacantAskingRent.toJson(),
  };
}

/// A unit that can be let and has no tenant.
@immutable
final class VacantUnit with _RowValue {
  const new({
    required this.unitId,
    required this.unitLabel,
    required this.propertyId,
    required this.propertyName,
    required this.vacantSince,
    required this.vacantDays,
    this.askingRent,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'vacant unit');
    return VacantUnit(
      unitId: row.string('unit_id'),
      unitLabel: row.string('unit_label'),
      propertyId: row.string('property_id'),
      propertyName: row.string('property_name'),
      askingRent: row.optionalMoney('asking_rent'),
      vacantSince: row.date('vacant_since'),
      vacantDays: row.integer('vacant_days'),
    );
  }

  final String unitId;
  final String unitLabel;
  final String propertyId;
  final String propertyName;
  final Money? askingRent;
  final CalendarDate vacantSince;
  final int vacantDays;

  @override
  Map<String, Object?> toRow() => {
    'unit_id': unitId,
    'unit_label': unitLabel,
    'property_id': propertyId,
    'property_name': propertyName,
    'asking_rent': askingRent?.toJson(),
    'vacant_since': vacantSince.toIso(),
    'vacant_days': vacantDays,
  };
}

/// A tenancy with rent overdue, among the ten owing most (INS-02).
@immutable
final class Arrear with _RowValue {
  const new({
    required this.leaseId,
    required this.tenantId,
    required this.tenantName,
    required this.unitLabel,
    required this.propertyName,
    required this.monthlyRent,
    required this.outstanding,
    required this.overdue,
    required this.oldestOverdueDueDate,
    required this.daysOverdue,
    this.tenantPhone,
    this.lastPaidOn,
    this.lastRemindedAt,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'arrear');
    return Arrear(
      leaseId: row.string('lease_id'),
      tenantId: row.string('tenant_id'),
      tenantName: row.string('tenant_name'),
      tenantPhone: row.dialablePhone('tenant_phone'),
      unitLabel: row.string('unit_label'),
      propertyName: row.string('property_name'),
      monthlyRent: row.money('monthly_rent'),
      outstanding: row.money('outstanding'),
      overdue: row.money('overdue'),
      oldestOverdueDueDate: row.date('oldest_overdue_due_date'),
      daysOverdue: row.integer('days_overdue'),
      lastPaidOn: row.optionalDate('last_paid_on'),
      lastRemindedAt: row.optionalTimestamp('last_reminded_at'),
    );
  }

  final String leaseId;
  final String tenantId;
  final String tenantName;

  /// The tenant's phone, or null when they have none the app can dial.
  final PhoneNumber? tenantPhone;
  final String unitLabel;
  final String propertyName;
  final Money monthlyRent;
  final Money outstanding;
  final Money overdue;
  final CalendarDate oldestOverdueDueDate;
  final int daysOverdue;
  final CalendarDate? lastPaidOn;
  final DateTime? lastRemindedAt;

  @override
  Map<String, Object?> toRow() => {
    'lease_id': leaseId,
    'tenant_id': tenantId,
    'tenant_name': tenantName,
    'tenant_phone': tenantPhone?.e164,
    'unit_label': unitLabel,
    'property_name': propertyName,
    'monthly_rent': monthlyRent.toJson(),
    'outstanding': outstanding.toJson(),
    'overdue': overdue.toJson(),
    'oldest_overdue_due_date': oldestOverdueDueDate.toIso(),
    'days_overdue': daysOverdue,
    'last_paid_on': lastPaidOn?.toIso(),
    'last_reminded_at': lastRemindedAt?.toIso8601String(),
  };
}

/// An active tenancy ending within 90 days.
@immutable
final class ExpiringLease with _RowValue {
  const new({
    required this.leaseId,
    required this.tenantName,
    required this.unitLabel,
    required this.endDate,
    required this.daysLeft,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'expiring lease');
    return ExpiringLease(
      leaseId: row.string('lease_id'),
      tenantName: row.string('tenant_name'),
      unitLabel: row.string('unit_label'),
      endDate: row.date('end_date'),
      daysLeft: row.integer('days_left'),
    );
  }

  final String leaseId;
  final String tenantName;
  final String unitLabel;
  final CalendarDate endDate;
  final int daysLeft;

  @override
  Map<String, Object?> toRow() => {
    'lease_id': leaseId,
    'tenant_name': tenantName,
    'unit_label': unitLabel,
    'end_date': endDate.toIso(),
    'days_left': daysLeft,
  };
}

/// Whether a rent increase is coming or was not made when it fell due.
enum IncrementStatus with DbEnum {
  upcoming('upcoming'),
  missed('missed');

  new(this.db);

  @override
  final String db;

  static IncrementStatus parse(String name) => parseDbEnum(values, name);
}

/// A tenancy's agreed rent increase: due within 30 days, or missed (its
/// anniversary passed and the rent was not changed).
@immutable
final class IncrementDue with _RowValue {
  const new({
    required this.leaseId,
    required this.tenantName,
    required this.unitLabel,
    required this.currentRent,
    required this.incrementBasisPoints,
    required this.anniversary,
    required this.status,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'increment');
    return IncrementDue(
      leaseId: row.string('lease_id'),
      tenantName: row.string('tenant_name'),
      unitLabel: row.string('unit_label'),
      currentRent: row.money('current_rent'),
      incrementBasisPoints: row.percent('increment_percent'),
      anniversary: row.date('anniversary'),
      status: row.choice('status', IncrementStatus.parse),
    );
  }

  final String leaseId;
  final String tenantName;
  final String unitLabel;
  final Money currentRent;

  /// The agreed increase (10 % is 1000).
  final int incrementBasisPoints;
  final CalendarDate anniversary;
  final IncrementStatus status;

  /// The rent after the increase, to the rupee.
  Money get newRent =>
      currentRent + currentRent.percentage(incrementBasisPoints).roundToRupee();

  @override
  Map<String, Object?> toRow() => {
    'lease_id': leaseId,
    'tenant_name': tenantName,
    'unit_label': unitLabel,
    'current_rent': currentRent.toJson(),
    'increment_percent': percentFromBasisPoints(incrementBasisPoints),
    'anniversary': anniversary.toIso(),
    'status': status.db,
  };
}

/// A tenancy not yet registered with the police (or submitted and not
/// confirmed), with its deadline under its province's rule: a law's
/// deadline when [rule] is statutory, otherwise the app's reminder.
@immutable
final class PolicePending with _RowValue {
  const new({
    required this.leaseId,
    required this.tenantName,
    required this.unitLabel,
    required this.province,
    required this.startDate,
    required this.deadline,
    required this.overdue,
    required this.status,
    required this.rule,
    required this.clockStartsOn,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'police registration');
    return PolicePending(
      leaseId: row.string('lease_id'),
      tenantName: row.string('tenant_name'),
      unitLabel: row.string('unit_label'),
      province: row.choice('province', Province.parse),
      startDate: row.date('start_date'),
      deadline: row.date('deadline'),
      overdue: row.boolean('overdue'),
      status: row.choice('status', PoliceStatus.parse),
      rule: PoliceRule(
        days: row.integer('deadline_days'),
        clock: row.choice('clock', _clock),
        statutory: row.boolean('statutory'),
      ),
      clockStartsOn: row.date('clock_starts_on'),
    );
  }

  static PoliceClock _clock(String name) => switch (name) {
    'possession' => PoliceClock.possession,
    'agreement' => PoliceClock.agreement,
    _ => throw FormatException('unknown value', name),
  };

  final String leaseId;
  final String tenantName;
  final String unitLabel;
  final Province province;
  final CalendarDate startDate;
  final CalendarDate deadline;

  /// Whether [deadline] has passed.
  final bool overdue;
  final PoliceStatus status;
  final PoliceRule rule;
  final CalendarDate clockStartsOn;

  /// Whether the tenancy is still not registered after the deadline a law
  /// sets. One submitted to the police is never late, whatever its date
  /// ([overdue] only says the date has passed).
  bool get pastLegalDeadline =>
      status == PoliceStatus.pending && overdue && rule.statutory;

  @override
  Map<String, Object?> toRow() => {
    'lease_id': leaseId,
    'tenant_name': tenantName,
    'unit_label': unitLabel,
    'province': province.db,
    'start_date': startDate.toIso(),
    'deadline': deadline.toIso(),
    'overdue': overdue,
    'status': status.db,
    'deadline_days': rule.days,
    'statutory': rule.statutory,
    'clock': rule.clock.name,
    'clock_starts_on': clockStartsOn.toIso(),
  };
}

/// A tenant of an active tenancy whose CNIC expires within 30 days, or
/// has expired.
@immutable
final class CnicExpiring with _RowValue {
  const new({
    required this.tenantId,
    required this.tenantName,
    required this.expiry,
    required this.expired,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'cnic');
    return CnicExpiring(
      tenantId: row.string('tenant_id'),
      tenantName: row.string('tenant_name'),
      expiry: row.date('cnic_expiry'),
      expired: row.boolean('expired'),
    );
  }

  final String tenantId;
  final String tenantName;
  final CalendarDate expiry;
  final bool expired;

  @override
  Map<String, Object?> toRow() => {
    'tenant_id': tenantId,
    'tenant_name': tenantName,
    'cnic_expiry': expiry.toIso(),
    'expired': expired,
  };
}

/// An electricity connection on the protected tariff whose latest bill
/// came near (180 units) or over the 200-unit threshold.
@immutable
final class HighUsage with _RowValue {
  const new({
    required this.utilityAccountId,
    required this.propertyName,
    required this.billingMonth,
    required this.unitsConsumed,
    required this.crossed,
    this.unitLabel,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'high usage');
    return HighUsage(
      utilityAccountId: row.string('utility_account_id'),
      propertyName: row.string('property_name'),
      unitLabel: row.optionalString('unit_label'),
      billingMonth: MonthPeriod.of(row.date('billing_month')),
      unitsConsumed: Hundredths(row.money('units_consumed').paisa),
      crossed: row.boolean('crossed'),
    );
  }

  final String utilityAccountId;
  final String propertyName;
  final String? unitLabel;
  final MonthPeriod billingMonth;
  final Hundredths unitsConsumed;

  /// Whether it went over 200 units.
  final bool crossed;

  @override
  Map<String, Object?> toRow() => {
    'utility_account_id': utilityAccountId,
    'property_name': propertyName,
    'unit_label': unitLabel,
    'billing_month': billingMonth.first.toIso(),
    'units_consumed': '$unitsConsumed',
    'crossed': crossed,
  };
}

/// Unpaid utility bills: those on connections in the landlord's name
/// (the landlord is liable for them) and those past their due date.
@immutable
final class UtilityArrears with _RowValue {
  const new({
    required this.unpaidInLandlordName,
    required this.unpaidInLandlordNameCount,
    required this.overdueCount,
  });

  final Money unpaidInLandlordName;
  final int unpaidInLandlordNameCount;
  final int overdueCount;

  @override
  Map<String, Object?> toRow() => {
    'unpaid_landlord_name_total': unpaidInLandlordName.toJson(),
    'unpaid_landlord_name_count': unpaidInLandlordNameCount,
    'overdue_count': overdueCount,
  };
}

/// How many of each thing the portfolio has.
@immutable
final class PortfolioCounts with _RowValue {
  const new({
    required this.properties,
    required this.tenants,
    required this.activeLeases,
    required this.openMaintenance,
    required this.urgentMaintenance,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'counts');
    return PortfolioCounts(
      properties: row.integer('properties'),
      tenants: row.integer('tenants'),
      activeLeases: row.integer('active_leases'),
      openMaintenance: row.integer('open_maintenance'),
      urgentMaintenance: row.integer('urgent_maintenance'),
    );
  }

  final int properties;
  final int tenants;
  final int activeLeases;
  final int openMaintenance;
  final int urgentMaintenance;

  @override
  Map<String, Object?> toRow() => {
    'properties': properties,
    'tenants': tenants,
    'active_leases': activeLeases,
    'open_maintenance': openMaintenance,
    'urgent_maintenance': urgentMaintenance,
  };
}

/// A portfolio at a glance (`public.get_dashboard`, one round trip): the
/// month's collection, what is owed by age, occupancy and the vacant
/// units, the tenancies owing most, and what needs doing soon (tenancies
/// ending, rent increases, police registration, CNICs, utilities).
@immutable
final class Dashboard {
  const new({
    required this.asOf,
    required this.month,
    required this.outstanding,
    required this.occupancy,
    required this.deposits,
    required this.utilities,
    required this.expensesThisMonth,
    required this.expensesTrailingAverage,
    required this.counts,
    this.vacantUnits = const [],
    this.topArrears = const [],
    this.expiring = const [],
    this.incrementsUpcoming = const [],
    this.incrementsMissed = const [],
    this.police = const [],
    this.cnic = const [],
    this.highUsage = const [],
  });

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'dashboard');
    final deposits = row.object('deposits');
    final utilities = row.object('utilities');
    final expenses = row.object('expenses');
    List<T> list<T>(JsonRow from, String field, T Function(Object?) read) => [
      for (final item in from.list(field)) read(item),
    ];
    return Dashboard(
      asOf: row.date('as_of'),
      month: MonthCollection.fromRow(row.object('month')),
      outstanding: Ageing.fromRow(row.object('outstanding')),
      occupancy: Occupancy.fromRow(row.object('occupancy')),
      vacantUnits: list(row, 'vacant_units', VacantUnit.fromRow),
      topArrears: list(row, 'top_arrears', Arrear.fromRow),
      expiring: list(row, 'leases_expiring', ExpiringLease.fromRow),
      incrementsUpcoming: list(
        row,
        'increments_upcoming',
        IncrementDue.fromRow,
      ),
      incrementsMissed: list(row, 'increments_missed', IncrementDue.fromRow),
      police: list(row, 'police_pending', PolicePending.fromRow),
      cnic: list(row, 'cnic_expiring', CnicExpiring.fromRow),
      deposits: (
        agreed: deposits.money('agreed'),
        held: deposits.money('held'),
      ),
      utilities: UtilityArrears(
        unpaidInLandlordName: utilities.money('unpaid_landlord_name_total'),
        unpaidInLandlordNameCount: utilities.integer(
          'unpaid_landlord_name_count',
        ),
        overdueCount: utilities.integer('overdue_count'),
      ),
      highUsage: list(utilities, 'high_usage', HighUsage.fromRow),
      expensesThisMonth: expenses.money('this_month'),
      expensesTrailingAverage: expenses.money('trailing_3m_avg'),
      counts: PortfolioCounts.fromRow(row.object('counts')),
    );
  }

  /// The day the figures are for, in Pakistan.
  final CalendarDate asOf;
  final MonthCollection month;
  final Ageing outstanding;
  final Occupancy occupancy;

  /// Vacant units, the longest vacant first.
  final List<VacantUnit> vacantUnits;

  /// The ten tenancies with the most overdue, the most first.
  final List<Arrear> topArrears;

  /// Active tenancies ending within 90 days, the soonest first.
  final List<ExpiringLease> expiring;
  final List<IncrementDue> incrementsUpcoming;
  final List<IncrementDue> incrementsMissed;
  final List<PolicePending> police;
  final List<CnicExpiring> cnic;

  /// The deposits agreed in active tenancies, and what of them is held.
  final ({Money agreed, Money held}) deposits;
  final UtilityArrears utilities;
  final List<HighUsage> highUsage;
  final Money expensesThisMonth;

  /// The average of the three months before this one.
  final Money expensesTrailingAverage;
  final PortfolioCounts counts;

  /// The answer of `get_dashboard`, as [Dashboard.fromJson] reads it.
  Map<String, Object?> toJson() => {
    'as_of': asOf.toIso(),
    'month': month.toRow(),
    'outstanding': outstanding.toRow(),
    'occupancy': occupancy.toRow(),
    'vacant_units': [for (final u in vacantUnits) u.toRow()],
    'top_arrears': [for (final a in topArrears) a.toRow()],
    'leases_expiring': [for (final e in expiring) e.toRow()],
    'increments_upcoming': [for (final i in incrementsUpcoming) i.toRow()],
    'increments_missed': [for (final i in incrementsMissed) i.toRow()],
    'police_pending': [for (final p in police) p.toRow()],
    'cnic_expiring': [for (final c in cnic) c.toRow()],
    'deposits': {
      'agreed': deposits.agreed.toJson(),
      'held': deposits.held.toJson(),
    },
    'utilities': {
      ...utilities.toRow(),
      'high_usage': [for (final h in highUsage) h.toRow()],
    },
    'expenses': {
      'this_month': expensesThisMonth.toJson(),
      'trailing_3m_avg': expensesTrailingAverage.toJson(),
    },
    'counts': counts.toRow(),
  };

  @override
  bool operator ==(Object other) =>
      other is Dashboard &&
      other.asOf == asOf &&
      other.month == month &&
      other.outstanding == outstanding &&
      other.occupancy == occupancy &&
      listEquals(other.vacantUnits, vacantUnits) &&
      listEquals(other.topArrears, topArrears) &&
      listEquals(other.expiring, expiring) &&
      listEquals(other.incrementsUpcoming, incrementsUpcoming) &&
      listEquals(other.incrementsMissed, incrementsMissed) &&
      listEquals(other.police, police) &&
      listEquals(other.cnic, cnic) &&
      other.deposits == deposits &&
      other.utilities == utilities &&
      listEquals(other.highUsage, highUsage) &&
      other.expensesThisMonth == expensesThisMonth &&
      other.expensesTrailingAverage == expensesTrailingAverage &&
      other.counts == counts;

  @override
  int get hashCode => Object.hash(
    asOf,
    month,
    outstanding,
    occupancy,
    Object.hashAll(vacantUnits),
    Object.hashAll(topArrears),
    Object.hashAll(expiring),
    Object.hashAll(incrementsUpcoming),
    Object.hashAll(incrementsMissed),
    Object.hashAll(police),
    Object.hashAll(cnic),
    deposits,
    utilities,
    Object.hashAll(highUsage),
    expensesThisMonth,
    expensesTrailingAverage,
    counts,
  );
}
