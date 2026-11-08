import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

/// What a connection supplies (`public.utility_type`).
enum UtilityType with DbEnum {
  electricity('electricity'),
  gas('gas'),
  water('water'),
  internet('internet'),
  other('other');

  new(this.db);

  @override
  final String db;

  static UtilityType parse(String name) => parseDbEnum(values, name);

  /// The companies that supply it, `other` last.
  List<UtilityProvider> get providers => [
    for (final provider in UtilityProvider.values)
      if (provider.type == this || provider == UtilityProvider.other) provider,
  ];
}

/// Who supplies a connection (`public.utility_provider`): the 12
/// electricity distribution companies (K-Electric and HAZECO among them),
/// the two gas companies, the water authorities, PTCL, or another named in
/// `provider_other`.
enum UtilityProvider with DbEnum {
  lesco('lesco', UtilityType.electricity),
  iesco('iesco', UtilityType.electricity),
  gepco('gepco', UtilityType.electricity),
  fesco('fesco', UtilityType.electricity),
  mepco('mepco', UtilityType.electricity),
  pesco('pesco', UtilityType.electricity),
  hesco('hesco', UtilityType.electricity),
  sepco('sepco', UtilityType.electricity),
  qesco('qesco', UtilityType.electricity),
  tesco('tesco', UtilityType.electricity),
  hazeco('hazeco', UtilityType.electricity),
  kElectric('k_electric', UtilityType.electricity),
  sngpl('sngpl', UtilityType.gas),
  ssgc('ssgc', UtilityType.gas),
  wasa('wasa', UtilityType.water),
  kwsc('kwsc', UtilityType.water),
  cda('cda', UtilityType.water),
  ptcl('ptcl', UtilityType.internet),
  other('other', null);

  new(this.db, this.type);

  @override
  final String db;

  /// What it supplies; null for `other`, which may supply anything.
  final UtilityType? type;

  static UtilityProvider parse(String name) => parseDbEnum(values, name);

  /// How many digits its bills' reference (or account) number has, when
  /// that is known: 14 on the bills of the government distribution
  /// companies, 13 on K-Electric's (`.planning/research/legal-tax-formats.md`
  /// §6). A hint only: a number of another length is kept, with a warning.
  int? get referenceDigits => switch (this) {
    kElectric => 13,
    _ when type == UtilityType.electricity => 14,
    _ => null,
  };
}

/// Who pays a connection's bills (`public.bill_responsibility`).
enum BillResponsibility with DbEnum {
  tenant('tenant'),
  landlord('landlord'),
  shared('shared');

  new(this.db);

  @override
  final String db;

  static BillResponsibility parse(String name) => parseDbEnum(values, name);
}

/// The protected domestic electricity tariff: a consumer who uses 200
/// units or fewer a month keeps it; one month over 200 loses it for the
/// next six (NEPRA; `.planning/research/website-facts.md` UT-11). The
/// dashboard warns from 180 units (`get_dashboard`), as the app does.
abstract final class ProtectedTariff {
  /// The most units a month that keeps the tariff.
  static const limit = 200;

  /// From here a month is close to the limit.
  static const warnFrom = 180;

  /// Where [unitsInMonth] stands against the limit.
  static ProtectedUse useOf(Hundredths unitsInMonth) {
    if (unitsInMonth.value > limit * 100) return ProtectedUse.over;
    if (unitsInMonth.value >= warnFrom * 100) return ProtectedUse.near;
    return ProtectedUse.within;
  }
}

/// A month's units against the protected tariff's limit.
enum ProtectedUse {
  /// Comfortably within it.
  within,

  /// 180 to 200 units: one more push loses the tariff.
  near,

  /// Over 200 units: the tariff is lost for six months.
  over,
}

/// The largest reading or number of units `numeric(12,2)` holds.
const maxMeterUnits = Hundredths(999999999999);

/// [text] as a reference, customer or meter number is stored: Urdu digits
/// read as digits, upper case, without spaces.
String normalizeIdentifier(String text) =>
    normalizeDigits(text).toUpperCase().replaceAll(RegExp(r'\s+'), '');

/// A utility connection of a property or one of its units (UTIL-01): who
/// supplies it, its numbers, whose name is on the bill and who pays.
/// Arrears follow the premises (NEPRA), so a connection in the landlord's
/// name is a risk to watch.
@immutable
final class UtilityAccount {
  const new({
    required this.id,
    required this.propertyId,
    required this.type,
    this.provider = UtilityProvider.other,
    this.propertyName = '',
    this.unitId,
    this.unitLabel,
    this.providerOther,
    this.referenceNumber,
    this.customerId,
    this.meterNumber,
    this.accountTitle,
    this.inLandlordName = true,
    this.isSubMeter = false,
    this.isProtectedConsumer = false,
    this.responsibility = BillResponsibility.tenant,
    this.notes,
    this.archivedAt,
    this.createdAt = '',
  });

  /// Reads a `utility_accounts` row selected with [UtilityAccount.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'utility account');
    return UtilityAccount(
      id: row.string('id'),
      propertyId: row.string('property_id'),
      propertyName: row.object('property').string('name'),
      unitId: row.optionalString('unit_id'),
      unitLabel: row.optionalObject('unit')?.string('label'),
      type: row.choice('type', UtilityType.parse),
      provider: row.choice('provider', UtilityProvider.parse),
      providerOther: row.optionalString('provider_other'),
      referenceNumber: row.optionalString('reference_number'),
      customerId: row.optionalString('customer_id'),
      meterNumber: row.optionalString('meter_number'),
      accountTitle: row.optionalString('account_title'),
      inLandlordName: row.boolean('in_landlord_name'),
      isSubMeter: row.boolean('is_sub_meter'),
      isProtectedConsumer: row.boolean('is_protected_consumer'),
      responsibility: row.choice('responsibility', BillResponsibility.parse),
      notes: row.optionalString('notes'),
      archivedAt: row.optionalTimestamp('archived_at'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [UtilityAccount.fromRow] reads, with the property and
  /// unit embedded through their composite foreign keys.
  static const columns =
      'id,property_id,unit_id,type,provider,provider_other,reference_number,'
      'customer_id,meter_number,account_title,in_landlord_name,is_sub_meter,'
      'is_protected_consumer,responsibility,notes,archived_at,created_at,'
      'property:properties!utility_accounts_property_fkey(name),'
      'unit:units!utility_accounts_unit_fkey(label)';

  static const maxProviderOtherLength = 60;
  static const maxReferenceLength = 24;
  static const maxCustomerIdLength = 30;
  static const maxMeterLength = 30;
  static const maxTitleLength = 120;
  static const maxNotesLength = 500;

  /// `utility_accounts_reference_number_check`.
  static final referencePattern = RegExp(r'^[0-9A-Z-]{4,24}$');

  /// `utility_accounts_customer_id_check`.
  static final customerIdPattern = RegExp(r'^[0-9A-Z-]{1,30}$');

  /// `utility_accounts_meter_number_check`.
  static final meterPattern = RegExp(r'^[0-9A-Z/-]{1,30}$');

  final String id;
  final String propertyId;
  final String propertyName;

  /// The unit it serves; null for the whole property.
  final String? unitId;
  final String? unitLabel;
  final UtilityType type;
  final UtilityProvider provider;

  /// The supplier's name when [provider] is `other`.
  final String? providerOther;

  /// The bill's reference or account number.
  final String? referenceNumber;
  final String? customerId;
  final String? meterNumber;

  /// The name printed on the bill.
  final String? accountTitle;

  /// Whether the connection is in the landlord's name.
  final bool inLandlordName;
  final bool isSubMeter;

  /// On the protected domestic tariff (electricity): see [ProtectedTariff].
  final bool isProtectedConsumer;
  final BillResponsibility responsibility;
  final String? notes;
  final DateTime? archivedAt;
  final String createdAt;

  bool get archived => archivedAt != null;

  /// Whether its months are measured against the protected tariff.
  bool get watchesProtectedTariff =>
      isProtectedConsumer && type == UtilityType.electricity;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// What the connection's bills and readings carry of it.
  UtilityConnection get connection => UtilityConnection(
    id: id,
    type: type,
    provider: provider,
    providerOther: providerOther,
    propertyId: propertyId,
    propertyName: propertyName,
    unitId: unitId,
    unitLabel: unitLabel,
    inLandlordName: inLandlordName,
    isProtectedConsumer: isProtectedConsumer,
  );

  /// What [UtilityAccount.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    'property_id': propertyId,
    'property': {'name': propertyName},
    'unit_id': unitId,
    'unit': unitLabel == null ? null : {'label': unitLabel},
    'type': type.db,
    'provider': provider.db,
    'provider_other': providerOther,
    'reference_number': referenceNumber,
    'customer_id': customerId,
    'meter_number': meterNumber,
    'account_title': accountTitle,
    'in_landlord_name': inLandlordName,
    'is_sub_meter': isSubMeter,
    'is_protected_consumer': isProtectedConsumer,
    'responsibility': responsibility.db,
    'notes': notes,
    'archived_at': archivedAt?.toIso8601String(),
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    propertyId,
    propertyName,
    unitId,
    unitLabel,
    type,
    provider,
    providerOther,
    referenceNumber,
    customerId,
    meterNumber,
    accountTitle,
    inLandlordName,
    isSubMeter,
    isProtectedConsumer,
    responsibility,
    notes,
    archivedAt,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is UtilityAccount && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// A connection to add or save (`utility_accounts` grants: its property is
/// fixed once added).
@immutable
final class UtilityAccountDraft {
  const new({
    required this.propertyId,
    required this.type,
    this.provider = UtilityProvider.other,
    this.unitId,
    this.providerOther,
    this.referenceNumber,
    this.customerId,
    this.meterNumber,
    this.accountTitle,
    this.inLandlordName = true,
    this.isSubMeter = false,
    this.isProtectedConsumer = false,
    this.responsibility = BillResponsibility.tenant,
    this.notes,
  });

  /// [account]'s fields, as a draft that would store it again.
  factory of(UtilityAccount account) => UtilityAccountDraft(
    propertyId: account.propertyId,
    unitId: account.unitId,
    type: account.type,
    provider: account.provider,
    providerOther: account.providerOther,
    referenceNumber: account.referenceNumber,
    customerId: account.customerId,
    meterNumber: account.meterNumber,
    accountTitle: account.accountTitle,
    inLandlordName: account.inLandlordName,
    isSubMeter: account.isSubMeter,
    isProtectedConsumer: account.isProtectedConsumer,
    responsibility: account.responsibility,
    notes: account.notes,
  );

  final String propertyId;
  final String? unitId;
  final UtilityType type;
  final UtilityProvider provider;
  final String? providerOther;
  final String? referenceNumber;
  final String? customerId;
  final String? meterNumber;
  final String? accountTitle;
  final bool inLandlordName;
  final bool isSubMeter;
  final bool isProtectedConsumer;
  final BillResponsibility responsibility;
  final String? notes;

  static String? _identifier(String? value) {
    if (value == null) return null;
    final normal = normalizeIdentifier(value);
    return normal.isEmpty ? null : normal;
  }

  /// The columns a client may update.
  Map<String, Object?> toWrite() => {
    'unit_id': unitId,
    'type': type.db,
    'provider': provider.db,
    'provider_other': provider == UtilityProvider.other
        ? optionalText(providerOther, UtilityAccount.maxProviderOtherLength)
        : null,
    'reference_number': _identifier(referenceNumber),
    'customer_id': _identifier(customerId),
    'meter_number': _identifier(meterNumber),
    'account_title': optionalText(accountTitle, UtilityAccount.maxTitleLength),
    'in_landlord_name': inLandlordName,
    'is_sub_meter': isSubMeter,
    // The protected tariff is an electricity tariff.
    'is_protected_consumer':
        isProtectedConsumer && type == UtilityType.electricity,
    'responsibility': responsibility.db,
    'notes': optionalLines(notes, UtilityAccount.maxNotesLength),
  };

  /// The columns of a new connection.
  Map<String, Object?> toInsert() => {'property_id': propertyId, ...toWrite()};

  @override
  bool operator ==(Object other) =>
      other is UtilityAccountDraft && mapEquals(other.toInsert(), toInsert());

  @override
  int get hashCode => Object.hashAll(toInsert().values);
}

/// What a bill or a reading carries of its connection: enough to name it
/// and to measure it against the protected tariff.
@immutable
final class UtilityConnection {
  const new({
    required this.id,
    required this.type,
    required this.provider,
    required this.propertyId,
    required this.propertyName,
    this.providerOther,
    this.unitId,
    this.unitLabel,
    this.inLandlordName = false,
    this.isProtectedConsumer = false,
  });

  /// Reads the connection embedded with [UtilityConnection.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'connection');
    return UtilityConnection(
      id: row.string('id'),
      type: row.choice('type', UtilityType.parse),
      provider: row.choice('provider', UtilityProvider.parse),
      providerOther: row.optionalString('provider_other'),
      propertyId: row.string('property_id'),
      propertyName: row.object('property').string('name'),
      unitId: row.optionalString('unit_id'),
      unitLabel: row.optionalObject('unit')?.string('label'),
      inLandlordName: row.boolean('in_landlord_name'),
      isProtectedConsumer: row.boolean('is_protected_consumer'),
    );
  }

  /// The connection's columns, embedded in a bill or a reading.
  static const columns =
      'id,type,provider,provider_other,property_id,unit_id,in_landlord_name,'
      'is_protected_consumer,'
      'property:properties!utility_accounts_property_fkey(name),'
      'unit:units!utility_accounts_unit_fkey(label)';

  final String id;
  final UtilityType type;
  final UtilityProvider provider;
  final String? providerOther;
  final String propertyId;
  final String propertyName;
  final String? unitId;
  final String? unitLabel;
  final bool inLandlordName;
  final bool isProtectedConsumer;

  bool get watchesProtectedTariff =>
      isProtectedConsumer && type == UtilityType.electricity;

  Map<String, Object?> toRow() => {
    'id': id,
    'type': type.db,
    'provider': provider.db,
    'provider_other': providerOther,
    'property_id': propertyId,
    'property': {'name': propertyName},
    'unit_id': unitId,
    'unit': unitLabel == null ? null : {'label': unitLabel},
    'in_landlord_name': inLandlordName,
    'is_protected_consumer': isProtectedConsumer,
  };

  List<Object?> get _fields => [
    id,
    type,
    provider,
    providerOther,
    propertyId,
    propertyName,
    unitId,
    unitLabel,
    inLandlordName,
    isProtectedConsumer,
  ];

  @override
  bool operator ==(Object other) =>
      other is UtilityConnection && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// Whether a bill is paid (`public.utility_bill_status`).
enum BillStatus with DbEnum {
  unpaid('unpaid'),
  paid('paid');

  new(this.db);

  @override
  final String db;

  static BillStatus parse(String name) => parseDbEnum(values, name);
}

/// Who paid a bill (`utility_bills_paid_by_check`).
enum BillPayer with DbEnum {
  tenant('tenant'),
  landlord('landlord');

  new(this.db);

  @override
  final String db;

  static BillPayer parse(String name) => parseDbEnum(values, name);
}

/// The charge a bill was put on a tenant's ledger as
/// (`bill_utility_to_tenant`).
@immutable
final class BilledCharge {
  const new({required this.id, required this.leaseId, this.voided = false});

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'charge');
    return BilledCharge(
      id: row.string('id'),
      leaseId: row.string('lease_id'),
      voided: row.optionalTimestamp('voided_at') != null,
    );
  }

  static const columns = 'id,lease_id,voided_at';

  final String id;
  final String leaseId;

  /// A voided charge no longer bills the tenant: the bill can be charged
  /// again.
  final bool voided;

  Map<String, Object?> toRow() => {
    'id': id,
    'lease_id': leaseId,
    // The time is not kept, only that it was voided.
    'voided_at': voided ? '1970-01-01T00:00:00Z' : null,
  };

  @override
  bool operator ==(Object other) =>
      other is BilledCharge &&
      other.id == id &&
      other.leaseId == leaseId &&
      other.voided == voided;

  @override
  int get hashCode => Object.hash(id, leaseId, voided);
}

/// A month's bill of a connection (UTIL-02): what it is for, its amount,
/// due date and units, whether it is paid and by whom, and the charge on
/// the tenant's ledger when it was billed to them.
@immutable
final class UtilityBill {
  const new({
    required this.id,
    required this.connection,
    required this.billingMonth,
    required this.amount,
    this.status = BillStatus.unpaid,
    this.dueDate,
    this.unitsConsumed,
    this.paidOn,
    this.paidBy,
    this.charge,
    this.notes,
    this.createdAt = '',
  });

  /// Reads a `utility_bills` row selected with [UtilityBill.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'bill');
    final units = row.optionalMoney('units_consumed');
    final charge = row.optionalObject('charge');
    return UtilityBill(
      id: row.string('id'),
      connection: UtilityConnection.fromRow(row.object('account')),
      billingMonth: MonthPeriod.of(row.date('billing_month')),
      amount: row.money('amount'),
      dueDate: row.optionalDate('due_date'),
      unitsConsumed: units == null ? null : Hundredths(units.paisa),
      status: row.choice('status', BillStatus.parse),
      paidOn: row.optionalDate('paid_on'),
      paidBy: row.optionalChoice('paid_by', BillPayer.parse),
      charge: charge == null ? null : BilledCharge.fromRow(charge),
      notes: row.optionalString('notes'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [UtilityBill.fromRow] reads, with the connection and the
  /// tenant's charge embedded.
  static const columns =
      'id,billing_month,amount,due_date,units_consumed,status,paid_on,'
      'paid_by,notes,created_at,'
      'account:utility_accounts!utility_bills_account_fkey'
      '(${UtilityConnection.columns}),'
      'charge:charges!utility_bills_charge_id_fkey(${BilledCharge.columns})';

  static const maxNotesLength = 500;

  final String id;
  final UtilityConnection connection;
  final MonthPeriod billingMonth;
  final Money amount;
  final CalendarDate? dueDate;
  final Hundredths? unitsConsumed;
  final BillStatus status;
  final CalendarDate? paidOn;
  final BillPayer? paidBy;

  /// The live or voided charge it was billed to a tenant as.
  final BilledCharge? charge;
  final String? notes;
  final String createdAt;

  bool get paid => status == BillStatus.paid;

  /// The live charge billing it to a tenant, if any.
  BilledCharge? get liveCharge =>
      charge != null && !charge!.voided ? charge : null;

  /// Where its units stand against the protected tariff; null when its
  /// connection is not on it or the units are not known.
  ProtectedUse? get protectedUse {
    final units = unitsConsumed;
    if (units == null || !connection.watchesProtectedTariff) return null;
    return ProtectedTariff.useOf(units);
  }

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  Map<String, Object?> toRow() => {
    'id': id,
    'account': connection.toRow(),
    'billing_month': billingMonth.first.toJson(),
    'amount': amount.toJson(),
    'due_date': dueDate?.toJson(),
    'units_consumed': unitsConsumed?.toString(),
    'status': status.db,
    'paid_on': paidOn?.toJson(),
    'paid_by': paidBy?.db,
    'charge': charge?.toRow(),
    'notes': notes,
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    connection,
    billingMonth,
    amount,
    dueDate,
    unitsConsumed,
    status,
    paidOn,
    paidBy,
    charge,
    notes,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is UtilityBill && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// Whether a bill is paid, when and by whom: all that marking it paid or
/// unpaid writes, so the other columns keep what is stored, whatever copy
/// of the bill the screen showed. A bill with a paid date is paid
/// (`utility_bills_paid_consistency_check`).
@immutable
final class BillPayment {
  /// Paid on [paidOn] by [paidBy].
  const new({required CalendarDate this.paidOn, this.paidBy});

  /// Not paid: the paid date and payer are cleared.
  const new unpaid() : paidOn = null, paidBy = null;

  final CalendarDate? paidOn;
  final BillPayer? paidBy;

  Map<String, Object?> toWrite() => {
    'status': paidOn == null ? BillStatus.unpaid.db : BillStatus.paid.db,
    'paid_on': paidOn?.toJson(),
    'paid_by': paidOn == null ? null : paidBy?.db,
  };

  @override
  bool operator ==(Object other) =>
      other is BillPayment && other.paidOn == paidOn && other.paidBy == paidBy;

  @override
  int get hashCode => Object.hash(paidOn, paidBy);
}

/// A bill to add or save (`utility_bills` grants: its connection and month
/// are fixed once added). Saving it leaves whether it is paid alone: that
/// is [BillPayment]'s.
@immutable
final class BillDraft {
  const new({
    required this.billingMonth,
    required this.amount,
    this.dueDate,
    this.unitsConsumed,
    this.paidOn,
    this.paidBy,
    this.notes,
  });

  /// [bill]'s fields, as a draft that would store it again.
  factory of(UtilityBill bill) => BillDraft(
    billingMonth: bill.billingMonth,
    amount: bill.amount,
    dueDate: bill.dueDate,
    unitsConsumed: bill.unitsConsumed,
    paidOn: bill.paidOn,
    paidBy: bill.paidBy,
    notes: bill.notes,
  );

  final MonthPeriod billingMonth;
  final Money amount;
  final CalendarDate? dueDate;
  final Hundredths? unitsConsumed;

  /// When a new bill was paid; null while unpaid.
  final CalendarDate? paidOn;
  final BillPayer? paidBy;
  final String? notes;

  /// The bill's details a client may update.
  Map<String, Object?> toWrite() => {
    'amount': amount.toJson(),
    'due_date': dueDate?.toJson(),
    'units_consumed': unitsConsumed?.toString(),
    'notes': optionalLines(notes, UtilityBill.maxNotesLength),
  };

  /// The columns of a new bill of [accountId], paid or not.
  Map<String, Object?> toInsert(String accountId) {
    final paidOn = this.paidOn;
    return {
      'utility_account_id': accountId,
      'billing_month': billingMonth.first.toJson(),
      ...toWrite(),
      ...(paidOn == null
              ? const BillPayment.unpaid()
              : BillPayment(paidOn: paidOn, paidBy: paidBy))
          .toWrite(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BillDraft && mapEquals(other.toInsert(''), toInsert(''));

  @override
  int get hashCode => Object.hashAll(toInsert('').values);
}

/// Why a meter was read (`public.meter_reading_context`).
enum ReadingContext with DbEnum {
  moveIn('move_in'),
  moveOut('move_out'),
  monthly('monthly'),
  other('other');

  new(this.db);

  @override
  final String db;

  static ReadingContext parse(String name) => parseDbEnum(values, name);
}

/// A meter reading (UTIL-03), above all at move-in and move-out, perhaps
/// of a tenancy.
@immutable
final class MeterReading {
  const new({
    required this.id,
    required this.accountId,
    required this.reading,
    required this.readOn,
    this.context = ReadingContext.other,
    this.leaseId,
    this.tenantName,
    this.notes,
    this.createdAt = '',
  });

  /// Reads a `meter_readings` row selected with [MeterReading.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'reading');
    final lease = row.optionalObject('lease');
    return MeterReading(
      id: row.string('id'),
      accountId: row.string('utility_account_id'),
      leaseId: row.optionalString('lease_id'),
      tenantName: lease?.object('tenant').string('full_name'),
      reading: Hundredths(row.money('reading').paisa),
      readOn: row.date('read_on'),
      context: row.choice('context', ReadingContext.parse),
      notes: row.optionalString('notes'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [MeterReading.fromRow] reads, with the tenant of its
  /// tenancy embedded.
  static const columns =
      'id,utility_account_id,lease_id,reading,read_on,context,notes,'
      'created_at,lease:leases!meter_readings_lease_fkey'
      '(tenant:tenants!leases_tenant_fkey(full_name))';

  static const maxNotesLength = 500;

  final String id;
  final String accountId;
  final Hundredths reading;
  final CalendarDate readOn;
  final ReadingContext context;

  /// The tenancy it was read for, and its tenant.
  final String? leaseId;
  final String? tenantName;
  final String? notes;
  final String createdAt;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  Map<String, Object?> toRow() => {
    'id': id,
    'utility_account_id': accountId,
    'lease_id': leaseId,
    'lease': tenantName == null
        ? null
        : {
            'tenant': {'full_name': tenantName},
          },
    'reading': reading.toString(),
    'read_on': readOn.toJson(),
    'context': context.db,
    'notes': notes,
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    accountId,
    leaseId,
    tenantName,
    reading,
    readOn,
    context,
    notes,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is MeterReading && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// A reading to add or save (`meter_readings` grants: its connection and
/// tenancy are fixed once added).
@immutable
final class ReadingDraft {
  const new({
    required this.reading,
    required this.readOn,
    this.context = ReadingContext.other,
    this.leaseId,
    this.notes,
  });

  /// [reading]'s fields, as a draft that would store it again.
  factory of(MeterReading reading) => ReadingDraft(
    reading: reading.reading,
    readOn: reading.readOn,
    context: reading.context,
    leaseId: reading.leaseId,
    notes: reading.notes,
  );

  final Hundredths reading;
  final CalendarDate readOn;
  final ReadingContext context;
  final String? leaseId;
  final String? notes;

  Map<String, Object?> toWrite() => {
    'reading': reading.toString(),
    'read_on': readOn.toJson(),
    'context': context.db,
    'notes': optionalLines(notes, MeterReading.maxNotesLength),
  };

  Map<String, Object?> toInsert(String accountId) => {
    'utility_account_id': accountId,
    'lease_id': leaseId,
    ...toWrite(),
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingDraft && mapEquals(other.toInsert(''), toInsert(''));

  @override
  int get hashCode => Object.hashAll(toInsert('').values);
}

/// The units a meter turned between two readings, and the pace of a month
/// they make.
@immutable
final class Consumption {
  const new({required this.units, required this.days});

  /// Between [earlier] and [later], or null when they cannot be compared:
  /// the same day, or a later reading below the earlier one (the meter was
  /// replaced or reset).
  static Consumption? between(MeterReading earlier, MeterReading later) {
    final days = later.readOn.differenceInDays(earlier.readOn);
    final units = later.reading.value - earlier.reading.value;
    if (days <= 0 || units < 0) return null;
    return Consumption(units: Hundredths(units), days: days);
  }

  /// The units used.
  final Hundredths units;

  /// Over how many days.
  final int days;

  /// The whole units a month of 30 days at this pace uses.
  Hundredths get perMonth =>
      Hundredths((units.value * 30 / days / 100).round() * 100);

  @override
  bool operator ==(Object other) =>
      other is Consumption && other.units == units && other.days == days;

  @override
  int get hashCode => Object.hash(units, days);
}

/// Each of [readings]' consumption since the reading before it in time
/// (by date, then by when it was recorded), keyed by its id. Readings
/// without one before them, or after a meter reset, have none.
Map<String, Consumption> consumptionOf(Iterable<MeterReading> readings) {
  final ordered = [...readings]
    ..sort((a, b) {
      final day = a.readOn.compareTo(b.readOn);
      if (day != 0) return day;
      final made = a.createdAt.compareTo(b.createdAt);
      return made != 0 ? made : a.id.compareTo(b.id);
    });
  return {
    for (var i = 1; i < ordered.length; i++)
      ordered[i].id: ?Consumption.between(ordered[i - 1], ordered[i]),
  };
}

/// A connection with its bills and readings, newest first.
@immutable
final class UtilityAccountDetail {
  const new({
    required this.account,
    required this.bills,
    required this.readings,
  });

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'connection');
    return UtilityAccountDetail(
      account: UtilityAccount.fromRow(row.object('account')),
      bills: Paged.fromJson(row.object('bills'), UtilityBill.fromRow),
      readings: Paged.fromJson(row.object('readings'), MeterReading.fromRow),
    );
  }

  final UtilityAccount account;
  final Paged<UtilityBill> bills;
  final Paged<MeterReading> readings;

  UtilityAccountDetail copyWith({
    UtilityAccount? account,
    Paged<UtilityBill>? bills,
    Paged<MeterReading>? readings,
  }) => UtilityAccountDetail(
    account: account ?? this.account,
    bills: bills ?? this.bills,
    readings: readings ?? this.readings,
  );

  Map<String, Object?> toJson() => {
    'account': account.toRow(),
    'bills': bills.toJson((b) => b.toRow()),
    'readings': readings.toJson((r) => r.toRow()),
  };

  @override
  bool operator ==(Object other) =>
      other is UtilityAccountDetail &&
      other.account == account &&
      other.bills == bills &&
      other.readings == readings;

  @override
  int get hashCode => Object.hash(account, bills, readings);
}

/// A reading with its connection and the reading before it, to measure
/// what was used.
@immutable
final class ReadingDetail {
  const new({required this.reading, required this.connection, this.previous});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'reading');
    final previous = row.optionalObject('previous');
    return ReadingDetail(
      reading: MeterReading.fromRow(row.object('reading')),
      connection: UtilityConnection.fromRow(row.object('connection')),
      previous: previous == null ? null : MeterReading.fromRow(previous),
    );
  }

  final MeterReading reading;
  final UtilityConnection connection;
  final MeterReading? previous;

  /// What the meter turned since [previous].
  Consumption? get consumption {
    final before = previous;
    return before == null ? null : Consumption.between(before, reading);
  }

  Map<String, Object?> toJson() => {
    'reading': reading.toRow(),
    'connection': connection.toRow(),
    'previous': previous?.toRow(),
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingDetail &&
      other.reading == reading &&
      other.connection == connection &&
      other.previous == previous;

  @override
  int get hashCode => Object.hash(reading, connection, previous);
}

/// The latest of [readings] in time (by date, then by when it was
/// recorded), or null when there are none.
MeterReading? latestReading(Iterable<MeterReading> readings) {
  MeterReading? latest;
  for (final reading in readings) {
    final current = latest;
    if (current == null ||
        reading.readOn.isAfter(current.readOn) ||
        (reading.readOn == current.readOn &&
            reading.createdAt.compareTo(current.createdAt) > 0)) {
      latest = reading;
    }
  }
  return latest;
}

/// Of [readings], the latest on or before [day] and the earliest after it
/// (in time: by date, then by when it was recorded), to measure a reading
/// of [day] against; either is null when there is none.
(MeterReading?, MeterReading?) readingsAround(
  Iterable<MeterReading> readings,
  CalendarDate day,
) {
  final before = latestReading([
    for (final reading in readings)
      if (!reading.readOn.isAfter(day)) reading,
  ]);
  MeterReading? after;
  for (final reading in readings) {
    if (!reading.readOn.isAfter(day)) continue;
    final current = after;
    if (current == null ||
        reading.readOn.isBefore(current.readOn) ||
        (reading.readOn == current.readOn &&
            reading.createdAt.compareTo(current.createdAt) < 0)) {
      after = reading;
    }
  }
  return (before, after);
}
