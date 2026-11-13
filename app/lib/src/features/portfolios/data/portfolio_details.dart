import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// A portfolio's caretaker: always a member with the manager role, who
/// looks after the properties for an owner (often one who lives abroad).
/// The database clears it when that membership ends or stops being manager.
@immutable
final class Caretaker {
  const new({required this.userId, required this.since});

  /// The caretaker's user id (`portfolios.caretaker_user_id`).
  final String userId;

  /// When they were named.
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is Caretaker && other.userId == userId && other.since == since;

  @override
  int get hashCode => Object.hash(userId, since);
}

/// A portfolio's own settings (owners change them): its name, the defaults
/// a new tenancy starts from, and the payment details printed on receipts
/// and reminders; and, read-only here, the answer to "Does the owner of
/// these properties live abroad?" and the caretaker, which change only
/// through their own functions (`set_owner_abroad`, `set_caretaker`).
@immutable
final class PortfolioDetails {
  const new({
    required this.id,
    required this.name,
    required this.defaultDueDay,
    required this.defaultGraceDays,
    required this.defaultIncrementBasisPoints,
    this.landlordName,
    this.landlordPhone,
    this.raastId,
    this.bankAccountTitle,
    this.bankIban,
    this.ownerAbroad = OwnerAbroad.notAnswered,
    this.caretaker,
  });

  /// Reads a `portfolios` row selected with [PortfolioDetails.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'portfolio');
    final phone = row.optionalString('landlord_phone');
    final raast = row.optionalString('raast_id');
    final iban = row.optionalString('bank_iban');
    final caretaker = row.optionalString('caretaker_user_id');
    final since = row.optionalTimestamp('caretaker_since');
    if ((caretaker == null) != (since == null)) {
      throw FormatException('caretaker without its date', json);
    }
    return PortfolioDetails(
      id: row.string('id'),
      name: row.string('name'),
      defaultDueDay: row.integer('default_due_day'),
      defaultGraceDays: row.integer('default_grace_days'),
      defaultIncrementBasisPoints: row.percent('default_increment_percent'),
      landlordName: row.optionalString('landlord_name'),
      landlordPhone: phone == null ? null : PhoneNumber.fromE164(phone),
      raastId: raast == null ? null : PhoneNumber.fromE164(raast),
      bankAccountTitle: row.optionalString('bank_account_title'),
      bankIban: iban == null ? null : Iban.parse(iban),
      ownerAbroad: OwnerAbroad.fromJson(row.optionalBoolean('owner_abroad')),
      caretaker: caretaker == null
          ? null
          : Caretaker(userId: caretaker, since: since!),
    );
  }

  /// The columns [PortfolioDetails.fromRow] reads.
  static const columns =
      'id,name,default_due_day,default_grace_days,default_increment_percent,'
      'landlord_name,landlord_phone,raast_id,bank_account_title,bank_iban,'
      'owner_abroad,caretaker_user_id,caretaker_since';

  /// The longest landlord name and account title the database accepts.
  static const maxNameLength = 120;

  /// The due days the database accepts (every month has them).
  static const firstDueDay = 1;
  static const lastDueDay = 28;

  /// The longest grace period the database accepts, in days.
  static const maxGraceDays = 60;

  final String id;
  final String name;

  /// The day of the month rent falls due, 1 to 28.
  final int defaultDueDay;

  /// Days after the due day before rent counts as late, 0 to 60.
  final int defaultGraceDays;

  /// The yearly increment, in basis points (10 % = 1000).
  final int defaultIncrementBasisPoints;

  /// The name printed on receipts; the owner's own when null.
  final String? landlordName;
  final PhoneNumber? landlordPhone;

  /// The Raast ID (a Pakistani mobile number) tenants can pay to.
  final PhoneNumber? raastId;
  final String? bankAccountTitle;
  final Iban? bankIban;

  /// The answer to "Does the owner of these properties live abroad?".
  final OwnerAbroad ownerAbroad;

  /// The caretaker, or null.
  final Caretaker? caretaker;

  /// The columns a client may update, with these values, as the database
  /// stores them. Never [ownerAbroad] or [caretaker]: no client may write
  /// those columns, and PostgREST would refuse the whole save (42501).
  Map<String, Object?> toUpdate() => {
    'name': singleLineWithin(name, 80),
    'default_due_day': defaultDueDay,
    'default_grace_days': defaultGraceDays,
    'default_increment_percent': percentFromBasisPoints(
      defaultIncrementBasisPoints,
    ),
    'landlord_name': optionalText(landlordName, maxNameLength),
    'landlord_phone': landlordPhone?.e164,
    'raast_id': raastId?.e164,
    'bank_account_title': optionalText(bankAccountTitle, maxNameLength),
    'bank_iban': bankIban?.value,
  };

  /// The row [PortfolioDetails.fromRow] reads back (for the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    ...toUpdate(),
    'name': name,
    'landlord_name': landlordName,
    'bank_account_title': bankAccountTitle,
    'owner_abroad': ownerAbroad.toJson(),
    'caretaker_user_id': caretaker?.userId,
    'caretaker_since': caretaker?.since.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is PortfolioDetails &&
      other.id == id &&
      other.name == name &&
      other.defaultDueDay == defaultDueDay &&
      other.defaultGraceDays == defaultGraceDays &&
      other.defaultIncrementBasisPoints == defaultIncrementBasisPoints &&
      other.landlordName == landlordName &&
      other.landlordPhone == landlordPhone &&
      other.raastId == raastId &&
      other.bankAccountTitle == bankAccountTitle &&
      other.bankIban == bankIban &&
      other.ownerAbroad == ownerAbroad &&
      other.caretaker == caretaker;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    defaultDueDay,
    defaultGraceDays,
    defaultIncrementBasisPoints,
    landlordName,
    landlordPhone,
    raastId,
    bankAccountTitle,
    bankIban,
    ownerAbroad,
    caretaker,
  );
}
