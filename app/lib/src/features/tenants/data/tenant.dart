import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// Who a tenant is (`public.tenant_kind`).
enum TenantKind with DbEnum {
  individual('individual'),
  company('company'),
  government('government'),
  other('other');

  new(this.db);

  @override
  final String db;

  static TenantKind parse(String name) => parseDbEnum(values, name);
}

/// How a tenant's guardian is related to them (S/O, D/O, W/O).
enum GuardianRelation with DbEnum {
  sonOf('son_of'),
  daughterOf('daughter_of'),
  wifeOf('wife_of'),
  other('other');

  new(this.db);

  @override
  final String db;

  static GuardianRelation parse(String name) => parseDbEnum(values, name);
}

/// Someone to call: a name and a phone number.
typedef Contact = ({String? name, PhoneNumber? phone});

/// A tenant profile (TEN-01): a person or an organisation, their identity
/// (the CNIC is shown masked), how to reach them and who vouches for them.
@immutable
final class Tenant {
  const new({
    required this.id,
    required this.fullName,
    this.kind = TenantKind.individual,
    this.guardianName,
    this.guardianRelation,
    this.cnic,
    this.cnicExpiry,
    this.ntn,
    this.phone,
    this.altPhone,
    this.email,
    this.occupation,
    this.employer,
    this.permanentAddress,
    this.previousAddress,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.reference1 = (name: null, phone: null),
    this.reference2 = (name: null, phone: null),
    this.householdSize,
    this.deductsWithholdingTax = false,
    this.consentRecordedAt,
    this.consentNote,
    this.notes,
    this.archivedAt,
    this.createdAt = '',
  });

  /// Reads a `tenants` row selected with [Tenant.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'tenant');
    PhoneNumber? phone(String field) {
      final value = row.optionalString(field);
      return value == null ? null : PhoneNumber.fromE164(value);
    }

    final cnic = row.optionalString('cnic');
    return Tenant(
      id: row.string('id'),
      kind: row.choice('kind', TenantKind.parse),
      fullName: row.string('full_name'),
      guardianName: row.optionalString('guardian_name'),
      guardianRelation: row.optionalChoice(
        'guardian_relation',
        GuardianRelation.parse,
      ),
      cnic: cnic == null ? null : Cnic.parse(cnic),
      cnicExpiry: row.optionalDate('cnic_expiry'),
      ntn: row.optionalString('ntn'),
      phone: phone('phone'),
      altPhone: phone('alt_phone'),
      email: row.optionalString('email'),
      occupation: row.optionalString('occupation'),
      employer: row.optionalString('employer'),
      permanentAddress: row.optionalString('permanent_address'),
      previousAddress: row.optionalString('previous_address'),
      emergencyName: row.optionalString('emergency_contact_name'),
      emergencyPhone: phone('emergency_contact_phone'),
      emergencyRelation: row.optionalString('emergency_contact_relation'),
      reference1: (
        name: row.optionalString('reference1_name'),
        phone: phone('reference1_phone'),
      ),
      reference2: (
        name: row.optionalString('reference2_name'),
        phone: phone('reference2_phone'),
      ),
      householdSize: row.optionalInteger('household_size'),
      deductsWithholdingTax: row.boolean('deducts_withholding_tax'),
      consentRecordedAt: row.optionalTimestamp('consent_recorded_at'),
      consentNote: row.optionalString('consent_note'),
      notes: row.optionalString('notes'),
      archivedAt: row.optionalTimestamp('archived_at'),
      createdAt: row.string('created_at'),
    );
  }

  /// The columns [Tenant.fromRow] reads.
  static const columns =
      'id,kind,full_name,guardian_name,guardian_relation,cnic,cnic_expiry,'
      'ntn,phone,alt_phone,email,occupation,employer,permanent_address,'
      'previous_address,emergency_contact_name,emergency_contact_phone,'
      'emergency_contact_relation,reference1_name,reference1_phone,'
      'reference2_name,reference2_phone,household_size,'
      'deducts_withholding_tax,consent_recorded_at,consent_note,notes,'
      'archived_at,created_at';

  static const maxNameLength = 120;
  static const maxOccupationLength = 80;
  static const maxAddressLength = 300;
  static const maxRelationLength = 40;
  static const maxConsentLength = 300;
  static const maxNotesLength = 2000;
  static const maxHousehold = 50;

  /// What the database accepts as an NTN.
  static final ntnPattern = RegExp(r'^[0-9A-Z][0-9A-Z-]{5,14}$');

  final String id;
  final TenantKind kind;
  final String fullName;

  /// The father's, husband's or guardian's name (S/O, D/O, W/O).
  final String? guardianName;
  final GuardianRelation? guardianRelation;
  final Cnic? cnic;
  final CalendarDate? cnicExpiry;

  /// The tax number of a company or a filer.
  final String? ntn;
  final PhoneNumber? phone;
  final PhoneNumber? altPhone;
  final String? email;
  final String? occupation;
  final String? employer;
  final String? permanentAddress;
  final String? previousAddress;
  final String? emergencyName;
  final PhoneNumber? emergencyPhone;
  final String? emergencyRelation;
  final Contact reference1;
  final Contact reference2;
  final int? householdSize;

  /// Withholds s.155 tax from the rent (companies, government).
  final bool deductsWithholdingTax;

  /// When the landlord recorded telling the tenant what data is kept and
  /// why (TEN-03); null until then.
  final DateTime? consentRecordedAt;
  final String? consentNote;
  final String? notes;
  final DateTime? archivedAt;
  final String createdAt;

  bool get archived => archivedAt != null;

  PageCursor get cursor => PageCursor(createdAt: createdAt, id: id);

  /// The editable columns, as the database stores them.
  Map<String, Object?> toWrite() {
    String? line(String? value, int max) =>
        sanitizeOptional(value, maxLength: max);
    final note = notes == null
        ? ''
        : sanitizeMultiline(notes!, maxLength: maxNotesLength);
    return {
      'kind': kind.db,
      'full_name': sanitizeSingleLine(fullName, maxLength: maxNameLength),
      'guardian_name': line(guardianName, maxNameLength),
      'guardian_relation': guardianRelation?.db,
      'cnic': cnic?.digits,
      'cnic_expiry': cnicExpiry?.toJson(),
      'ntn': line(ntn, 15)?.toUpperCase(),
      'phone': phone?.e164,
      'alt_phone': altPhone?.e164,
      'email': line(email, 254)?.toLowerCase(),
      'occupation': line(occupation, maxOccupationLength),
      'employer': line(employer, maxNameLength),
      'permanent_address': line(permanentAddress, maxAddressLength),
      'previous_address': line(previousAddress, maxAddressLength),
      'emergency_contact_name': line(emergencyName, maxNameLength),
      'emergency_contact_phone': emergencyPhone?.e164,
      'emergency_contact_relation': line(emergencyRelation, maxRelationLength),
      'reference1_name': line(reference1.name, maxNameLength),
      'reference1_phone': reference1.phone?.e164,
      'reference2_name': line(reference2.name, maxNameLength),
      'reference2_phone': reference2.phone?.e164,
      'household_size': householdSize,
      'deducts_withholding_tax': deductsWithholdingTax,
      'consent_recorded_at': consentRecordedAt?.toUtc().toIso8601String(),
      'consent_note': line(consentNote, maxConsentLength),
      'notes': note.isEmpty ? null : note,
    };
  }

  /// The row [Tenant.fromRow] reads back (the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    ...toWrite(),
    'full_name': fullName,
    'archived_at': archivedAt?.toIso8601String(),
    'created_at': createdAt,
  };

  List<Object?> get _fields => [
    id,
    kind,
    fullName,
    guardianName,
    guardianRelation,
    cnic,
    cnicExpiry,
    ntn,
    phone,
    altPhone,
    email,
    occupation,
    employer,
    permanentAddress,
    previousAddress,
    emergencyName,
    emergencyPhone,
    emergencyRelation,
    reference1,
    reference2,
    householdSize,
    deductsWithholdingTax,
    consentRecordedAt,
    consentNote,
    notes,
    archivedAt,
    createdAt,
  ];

  @override
  bool operator ==(Object other) =>
      other is Tenant && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// Another tenant with the same CNIC or phone number (TEN-02).
typedef TenantMatch = ({String id, String fullName});
