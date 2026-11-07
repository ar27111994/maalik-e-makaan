import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// The languages the app and the profile know (`profiles.locale`).
enum AppLanguage {
  english('en'),
  urdu('ur');

  new(this.code);

  /// The code stored in the profile and the settings.
  final String code;

  /// The language of [code]; throws [FormatException] for any other.
  static AppLanguage parse(String code) => switch (code) {
    'en' => english,
    'ur' => urdu,
    _ => throw FormatException('unknown language', code),
  };
}

/// The signed-in user's own profile (`public.profiles`): what teammates see
/// and what the user may edit (name, phone, language).
@immutable
final class Profile {
  const new({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.language,
  });

  /// Reads a `profiles` row selected with [Profile.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'profile');
    final phone = row.optionalString('phone');
    return Profile(
      id: row.string('id'),
      email: row.optionalString('email'),
      fullName: row.string('full_name'),
      phone: phone == null ? null : PhoneNumber.fromE164(phone),
      language: AppLanguage.parse(row.string('locale')),
    );
  }

  /// The columns [Profile.fromRow] reads.
  static const columns = 'id,email,full_name,phone,locale';

  /// The longest name the database accepts.
  static const maxNameLength = 120;

  final String id;

  /// The sign-in address, as Auth stores it (lower case).
  final String? email;

  /// Empty until the user gives a name.
  final String fullName;

  final PhoneNumber? phone;

  final AppLanguage language;

  /// The row [Profile.fromRow] reads back (for the offline cache).
  Map<String, Object?> toRow() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone?.e164,
    'locale': language.code,
  };

  Profile copyWith({AppLanguage? language}) => Profile(
    id: id,
    email: email,
    fullName: fullName,
    phone: phone,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.language == language;

  @override
  int get hashCode => Object.hash(id, email, fullName, phone, language);
}
