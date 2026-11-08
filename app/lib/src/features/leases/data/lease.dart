import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

/// Whether a tenancy runs (`public.lease_status`).
enum LeaseStatus with DbEnum {
  active('active'),
  ended('ended');

  new(this.db);

  @override
  final String db;

  static LeaseStatus parse(String name) => parseDbEnum(values, name);
}

/// Where police registration of a tenancy stands
/// (`public.police_registration_status`).
enum PoliceStatus with DbEnum {
  notRequired('not_required'),
  pending('pending'),
  submitted('submitted'),
  registered('registered');

  new(this.db);

  @override
  final String db;

  static PoliceStatus parse(String name) => parseDbEnum(values, name);
}

/// How a tenancy was registered with the police
/// (`public.police_registration_channel`).
enum PoliceChannel with DbEnum {
  onlinePortal('online_portal'),
  khidmatMarkaz('khidmat_markaz'),
  policeStation('police_station'),
  other('other');

  new(this.db);

  @override
  final String db;

  static PoliceChannel parse(String name) => parseDbEnum(values, name);
}

/// Where the agreement stands with the Punjab Rent Registrar
/// (`public.rent_registrar_status`).
enum RegistrarStatus with DbEnum {
  notApplicable('not_applicable'),
  notPresented('not_presented'),
  presented('presented'),
  registered('registered');

  new(this.db);

  @override
  final String db;

  static RegistrarStatus parse(String name) => parseDbEnum(values, name);
}

/// Why a tenancy ended (`public.lease_end_reason`).
enum EndReason with DbEnum {
  termCompleted('term_completed'),
  tenantMovedOut('tenant_moved_out'),
  eviction('eviction'),
  mutualAgreement('mutual_agreement'),
  other('other');

  new(this.db);

  @override
  final String db;

  static EndReason parse(String name) => parseDbEnum(values, name);
}

/// Why the rent changed (`rent_changes.reason`).
enum RentChangeReason with DbEnum {
  initial('initial'),
  annualIncrement('annual_increment'),
  renegotiation('renegotiation'),
  correction('correction');

  new(this.db);

  @override
  final String db;

  static RentChangeReason parse(String name) => parseDbEnum(values, name);
}

/// The terms of a tenancy a client may set when it starts and edit later
/// (`leases` column grants), apart from the rent, which only `change_rent`
/// changes once the tenancy has started.
@immutable
final class LeaseTerms {
  const new({
    required this.startDate,
    required this.monthlyRent,
    required this.billingStartsOn,
    this.endDate,
    this.rentDueDay = 5,
    this.graceDays = 5,
    this.securityDeposit = Money.zero,
    this.incrementBasisPoints = 1000,
    this.incrementIntervalMonths = 12,
    this.lateFee = const NoLateFee(),
    this.prorateFirstMonth = true,
    this.noticePeriodDays = 30,
    this.permittedUse,
    this.sublettingAllowed = false,
    this.agreementSignedOn,
    this.eStampNumber,
    this.eStampAmount,
    this.registrarStatus = RegistrarStatus.notPresented,
    this.registrarOffice,
    this.registrationNumber,
    this.registeredOn,
    this.policeStatus = PoliceStatus.pending,
    this.policeChannel,
    this.policeStation,
    this.policeReference,
    this.policeRegisteredOn,
    this.policeFee,
    this.utilitiesNote,
    this.notes,
  });

  static const maxNoticeDays = 365;
  static const maxIncrementMonths = 60;
  static const maxUseLength = 120;
  static const maxStampLength = 40;
  static const maxOfficeLength = 120;
  static const maxRegistrationLength = 60;
  static const maxUtilitiesLength = 500;
  static const maxNotesLength = 2000;

  final CalendarDate startDate;

  /// The agreed end; null for a periodic tenancy.
  final CalendarDate? endDate;
  final Money monthlyRent;
  final int rentDueDay;
  final int graceDays;
  final Money securityDeposit;
  final int incrementBasisPoints;
  final int incrementIntervalMonths;
  final LateFeePolicy lateFee;
  final bool prorateFirstMonth;

  /// The first day billed: later than the start when an existing tenancy
  /// is brought into the app.
  final CalendarDate billingStartsOn;
  final int noticePeriodDays;
  final String? permittedUse;
  final bool sublettingAllowed;
  final CalendarDate? agreementSignedOn;
  final String? eStampNumber;
  final Money? eStampAmount;
  final RegistrarStatus registrarStatus;
  final String? registrarOffice;
  final String? registrationNumber;
  final CalendarDate? registeredOn;
  final PoliceStatus policeStatus;
  final PoliceChannel? policeChannel;
  final String? policeStation;
  final String? policeReference;
  final CalendarDate? policeRegisteredOn;
  final Money? policeFee;
  final String? utilitiesNote;
  final String? notes;

  /// The columns of a lease these terms set, as the database stores them:
  /// [editable] leaves out what only starting a tenancy sets (its start,
  /// rent, billing start and proration).
  Map<String, Object?> toWrite({bool editable = false}) {
    String? line(String? value, int max) =>
        sanitizeOptional(value, maxLength: max);
    String? text(String? value, int max) {
      if (value == null) return null;
      final clean = sanitizeMultiline(value, maxLength: max);
      return clean.isEmpty ? null : clean;
    }

    final fee = lateFee;
    return {
      if (!editable) ...{
        'start_date': startDate.toJson(),
        'monthly_rent': monthlyRent.toJson(),
        'billing_starts_on': billingStartsOn.toJson(),
        'prorate_first_month': prorateFirstMonth,
      },
      'end_date': endDate?.toJson(),
      'rent_due_day': rentDueDay,
      'grace_days': graceDays,
      'security_deposit': securityDeposit.toJson(),
      'increment_percent': percentFromBasisPoints(incrementBasisPoints),
      'increment_interval_months': incrementIntervalMonths,
      'late_fee_type': fee.type,
      'late_fee_value': switch (fee) {
        NoLateFee() => null,
        FlatLateFee(:final amount) => amount.toJson(),
        PercentLateFee(:final basisPoints) => percentFromBasisPoints(
          basisPoints,
        ),
        DailyLateFee(:final perDay) => perDay.toJson(),
      },
      'late_fee_cap': fee is DailyLateFee ? fee.cap?.toJson() : null,
      'notice_period_days': noticePeriodDays,
      'permitted_use': line(permittedUse, maxUseLength),
      'subletting_allowed': sublettingAllowed,
      'agreement_signed_on': agreementSignedOn?.toJson(),
      'e_stamp_number': line(eStampNumber, maxStampLength),
      'e_stamp_amount': eStampAmount?.toJson(),
      'rent_registrar_status': registrarStatus.db,
      'rent_registrar_office': line(registrarOffice, maxOfficeLength),
      'rent_registration_number': line(
        registrationNumber,
        maxRegistrationLength,
      ),
      'rent_registered_on': registeredOn?.toJson(),
      'police_status': policeStatus.db,
      'police_channel': policeChannel?.db,
      'police_station': line(policeStation, maxOfficeLength),
      'police_reference': line(policeReference, maxRegistrationLength),
      'police_registered_on': policeRegisteredOn?.toJson(),
      'police_fee': policeFee?.toJson(),
      'utilities_note': text(utilitiesNote, maxUtilitiesLength),
      'notes': text(notes, maxNotesLength),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is LeaseTerms && mapEquals(other.toWrite(), toWrite());

  @override
  int get hashCode => Object.hashAll(toWrite().values);
}

/// A tenancy (LEASE-01, LEASE-03, LEASE-04, LEASE-07) with the names a
/// screen shows: the tenant's, the unit's and its property's, and the
/// province whose police rule applies.
@immutable
final class Lease {
  const new({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.status,
    required this.terms,
    required this.tenantName,
    required this.unitLabel,
    required this.propertyId,
    required this.propertyName,
    required this.province,
    this.movedOutOn,
    this.endReason,
    this.createdAt = '',
  });

  /// Reads a `leases` row selected with [Lease.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'lease');
    final unit = row.object('unit');
    final property = unit.object('property');
    final lateFee = _lateFee(row);
    return Lease(
      id: row.string('id'),
      unitId: row.string('unit_id'),
      tenantId: row.string('tenant_id'),
      status: row.choice('status', LeaseStatus.parse),
      tenantName: row.object('tenant').string('full_name'),
      unitLabel: unit.string('label'),
      propertyId: unit.string('property_id'),
      propertyName: property.string('name'),
      province: property.choice('province', Province.parse),
      movedOutOn: row.optionalDate('moved_out_on'),
      endReason: row.optionalChoice('end_reason', EndReason.parse),
      createdAt: row.string('created_at'),
      terms: LeaseTerms(
        startDate: row.date('start_date'),
        endDate: row.optionalDate('end_date'),
        monthlyRent: row.money('monthly_rent'),
        rentDueDay: row.integer('rent_due_day'),
        graceDays: row.integer('grace_days'),
        securityDeposit: row.money('security_deposit'),
        incrementBasisPoints: row.percent('increment_percent'),
        incrementIntervalMonths: row.integer('increment_interval_months'),
        lateFee: lateFee,
        prorateFirstMonth: row.boolean('prorate_first_month'),
        billingStartsOn: row.date('billing_starts_on'),
        noticePeriodDays: row.integer('notice_period_days'),
        permittedUse: row.optionalString('permitted_use'),
        sublettingAllowed: row.boolean('subletting_allowed'),
        agreementSignedOn: row.optionalDate('agreement_signed_on'),
        eStampNumber: row.optionalString('e_stamp_number'),
        eStampAmount: row.optionalMoney('e_stamp_amount'),
        registrarStatus: row.choice(
          'rent_registrar_status',
          RegistrarStatus.parse,
        ),
        registrarOffice: row.optionalString('rent_registrar_office'),
        registrationNumber: row.optionalString('rent_registration_number'),
        registeredOn: row.optionalDate('rent_registered_on'),
        policeStatus: row.choice('police_status', PoliceStatus.parse),
        policeChannel: row.optionalChoice(
          'police_channel',
          PoliceChannel.parse,
        ),
        policeStation: row.optionalString('police_station'),
        policeReference: row.optionalString('police_reference'),
        policeRegisteredOn: row.optionalDate('police_registered_on'),
        policeFee: row.optionalMoney('police_fee'),
        utilitiesNote: row.optionalString('utilities_note'),
        notes: row.optionalString('notes'),
      ),
    );
  }

  /// The late-fee policy of a row (`late_fee_type`, `_value`, `_cap`).
  static LateFeePolicy _lateFee(JsonRow row) {
    final value = row.optionalMoney('late_fee_value');
    final cap = row.optionalMoney('late_fee_cap');
    return switch (row.string('late_fee_type')) {
      'none' => const NoLateFee(),
      'flat' when value != null => FlatLateFee(value),
      'percent' when value != null => PercentLateFee(
        basisPointsFromPercent(value.toJson()),
      ),
      'daily' when value != null => DailyLateFee(value, cap: cap),
      final type => throw FormatException('late fee is not valid', type),
    };
  }

  /// The columns [Lease.fromRow] reads, with the tenant, unit and property
  /// embedded through their composite foreign keys.
  static const columns =
      'id,unit_id,tenant_id,status,start_date,end_date,monthly_rent,'
      'rent_due_day,grace_days,security_deposit,increment_percent,'
      'increment_interval_months,late_fee_type,late_fee_value,late_fee_cap,'
      'prorate_first_month,billing_starts_on,notice_period_days,'
      'permitted_use,subletting_allowed,agreement_signed_on,e_stamp_number,'
      'e_stamp_amount,rent_registrar_status,rent_registrar_office,'
      'rent_registration_number,rent_registered_on,police_status,'
      'police_channel,police_station,police_reference,police_registered_on,'
      'police_fee,utilities_note,notes,moved_out_on,end_reason,created_at,'
      'tenant:tenants!leases_tenant_fkey(full_name),'
      'unit:units!leases_unit_fkey(label,property_id,'
      'property:properties!units_property_fkey(name,province))';

  final String id;
  final String unitId;
  final String tenantId;
  final LeaseStatus status;
  final LeaseTerms terms;
  final String tenantName;
  final String unitLabel;
  final String propertyId;
  final String propertyName;
  final Province province;
  final CalendarDate? movedOutOn;
  final EndReason? endReason;
  final String createdAt;

  bool get active => status == LeaseStatus.active;

  /// When police registration is due, by the province's rule (or the app's
  /// reminder where no law fixes it).
  CalendarDate get policeDeadline =>
      province.policeRule.deadline(terms.startDate, terms.agreementSignedOn);

  /// The row [Lease.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() {
    final fee = terms.lateFee;
    return {
      'id': id,
      'unit_id': unitId,
      'tenant_id': tenantId,
      'status': status.db,
      ...terms.toWrite(),
      'late_fee_value': switch (fee) {
        NoLateFee() => null,
        FlatLateFee(:final amount) => amount.toJson(),
        PercentLateFee(:final basisPoints) => percentFromBasisPoints(
          basisPoints,
        ),
        DailyLateFee(:final perDay) => perDay.toJson(),
      },
      'permitted_use': terms.permittedUse,
      'e_stamp_number': terms.eStampNumber,
      'rent_registrar_office': terms.registrarOffice,
      'rent_registration_number': terms.registrationNumber,
      'police_station': terms.policeStation,
      'police_reference': terms.policeReference,
      'utilities_note': terms.utilitiesNote,
      'notes': terms.notes,
      'moved_out_on': movedOutOn?.toJson(),
      'end_reason': endReason?.db,
      'created_at': createdAt,
      'tenant': {'full_name': tenantName},
      'unit': {
        'label': unitLabel,
        'property_id': propertyId,
        'property': {'name': propertyName, 'province': province.db},
      },
    };
  }

  List<Object?> get _fields => [
    id,
    unitId,
    tenantId,
    status,
    terms,
    tenantName,
    unitLabel,
    propertyId,
    propertyName,
    province,
    movedOutOn,
    endReason,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is Lease && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// An adult living with the tenant (LEASE-05).
@immutable
final class Occupant {
  const new({
    required this.id,
    required this.fullName,
    this.relation,
    this.cnic,
    this.phone,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'occupant');
    final cnic = row.optionalString('cnic');
    final phone = row.optionalString('phone');
    return Occupant(
      id: row.string('id'),
      fullName: row.string('full_name'),
      relation: row.optionalString('relation'),
      cnic: cnic == null ? null : Cnic.parse(cnic),
      phone: phone == null ? null : PhoneNumber.fromE164(phone),
    );
  }

  static const columns = 'id,full_name,relation,cnic,phone';
  static const maxNameLength = 120;
  static const maxRelationLength = 40;

  final String id;
  final String fullName;
  final String? relation;
  final Cnic? cnic;
  final PhoneNumber? phone;

  Map<String, Object?> toWrite() => {
    'full_name': sanitizeSingleLine(fullName, maxLength: maxNameLength),
    'relation': sanitizeOptional(relation, maxLength: maxRelationLength),
    'cnic': cnic?.digits,
    'phone': phone?.e164,
  };

  Map<String, Object?> toRow() => {
    'id': id,
    ...toWrite(),
    'full_name': fullName,
    'relation': relation,
  };

  @override
  bool operator ==(Object other) =>
      other is Occupant &&
      other.id == id &&
      other.fullName == fullName &&
      other.relation == relation &&
      other.cnic == cnic &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, fullName, relation, cnic, phone);
}

/// The rent in force from a month (LEASE-06).
@immutable
final class RentChange {
  const new({
    required this.id,
    required this.effectiveFrom,
    required this.monthlyRent,
    required this.reason,
    this.note,
  });

  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'rent change');
    return RentChange(
      id: row.string('id'),
      effectiveFrom: MonthPeriod.of(row.date('effective_from')),
      monthlyRent: row.money('monthly_rent'),
      reason: row.choice('reason', RentChangeReason.parse),
      note: row.optionalString('note'),
    );
  }

  static const columns = 'id,effective_from,monthly_rent,reason,note';
  static const maxNoteLength = 300;

  final String id;
  final MonthPeriod effectiveFrom;
  final Money monthlyRent;
  final RentChangeReason reason;
  final String? note;

  Map<String, Object?> toRow() => {
    'id': id,
    'effective_from': effectiveFrom.first.toJson(),
    'monthly_rent': monthlyRent.toJson(),
    'reason': reason.db,
    'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is RentChange &&
      other.id == id &&
      other.effectiveFrom == effectiveFrom &&
      other.monthlyRent == monthlyRent &&
      other.reason == reason &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, effectiveFrom, monthlyRent, reason, note);
}

/// A tenancy with its occupants and rent history: what the tenancy screen
/// shows.
@immutable
final class LeaseDetail {
  const new({
    required this.lease,
    required this.occupants,
    required this.rentChanges,
  });

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'lease detail');
    return LeaseDetail(
      lease: Lease.fromRow(row.object('lease')),
      occupants: [for (final o in row.list('occupants')) Occupant.fromRow(o)],
      rentChanges: [
        for (final c in row.list('rent_changes')) RentChange.fromRow(c),
      ],
    );
  }

  final Lease lease;
  final List<Occupant> occupants;

  /// Newest first.
  final List<RentChange> rentChanges;

  Map<String, Object?> toJson() => {
    'lease': lease.toRow(),
    'occupants': [for (final o in occupants) o.toRow()],
    'rent_changes': [for (final c in rentChanges) c.toRow()],
  };

  @override
  bool operator ==(Object other) =>
      other is LeaseDetail &&
      other.lease == lease &&
      listEquals(other.occupants, occupants) &&
      listEquals(other.rentChanges, rentChanges);

  @override
  int get hashCode => Object.hash(
    lease,
    Object.hashAll(occupants),
    Object.hashAll(rentChanges),
  );
}
