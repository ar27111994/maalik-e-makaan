import 'package:mm_core/mm_core.dart';

/// Strict readers for PostgREST rows and Edge Function answers: a missing or
/// mistyped field throws [FormatException] naming it, which the repository
/// turns into a `ServerFailure` (the server and the app disagree).
extension type const JsonRow(Map<String, Object?> _fields) {
  /// Reads [json] as an object, or throws.
  factory of(Object? json, [String what = 'row']) {
    if (json is Map<String, Object?>) return JsonRow(json);
    if (json is Map) return JsonRow(json.cast<String, Object?>());
    throw FormatException('$what is not an object', json);
  }

  /// The string [field].
  String string(String field) => _typed<String>(field);

  /// The string [field], which may be null.
  String? optionalString(String field) => _optional<String>(field);

  /// The phone number [field] when the app can dial it as stored, else
  /// null: for a contact shown beside a row in a summary (who owes what),
  /// where one number the app does not read (stored before the database
  /// checked numbers as the app does) must cost that row its number, not
  /// fail the whole list. Records read for editing keep strict readers.
  PhoneNumber? dialablePhone(String field) {
    final stored = optionalString(field);
    if (stored == null) return null;
    final phone = PhoneNumber.tryParse(stored);
    return phone?.e164 == stored ? phone : null;
  }

  /// The whole number [field].
  int integer(String field) => _typed<int>(field);

  /// The boolean [field].
  bool boolean(String field) => _typed<bool>(field);

  /// The boolean [field], which may be null (a question not yet answered).
  bool? optionalBoolean(String field) => _optional<bool>(field);

  /// The whole number [field], which may be null.
  int? optionalInteger(String field) => _optional<int>(field);

  /// The object [field].
  JsonRow object(String field) => JsonRow.of(_require(field), field);

  /// The object [field], which may be null.
  JsonRow? optionalObject(String field) {
    final value = _require(field);
    return value == null ? null : JsonRow.of(value, field);
  }

  /// The amount [field] (`numeric(14,2)`), exact (see `Money.fromJson`).
  Money money(String field) => Money.fromJson(_require(field));

  /// The amount [field], which may be null.
  Money? optionalMoney(String field) {
    final value = _require(field);
    return value == null ? null : Money.fromJson(value);
  }

  /// The date [field] (`YYYY-MM-DD`).
  CalendarDate date(String field) => CalendarDate.fromJson(_require(field));

  /// The date [field], which may be null.
  CalendarDate? optionalDate(String field) {
    final value = _require(field);
    return value == null ? null : CalendarDate.fromJson(value);
  }

  /// The timestamp [field], in UTC.
  DateTime timestamp(String field) => _parseTimestamp(string(field), field);

  /// The timestamp [field], in UTC, which may be null.
  DateTime? optionalTimestamp(String field) {
    final value = optionalString(field);
    return value == null ? null : _parseTimestamp(value, field);
  }

  /// The enumeration value [field], read with [parse] (which throws
  /// [FormatException] for a value it does not know).
  T choice<T>(String field, T Function(String name) parse) =>
      parse(string(field));

  /// The enumeration value [field], which may be null.
  T? optionalChoice<T>(String field, T Function(String name) parse) {
    final value = optionalString(field);
    return value == null ? null : parse(value);
  }

  /// The percentage [field] (`numeric(5,2)`) in basis points (10 % = 1000).
  int percent(String field) => basisPointsFromPercent(_require(field));

  /// The list [field].
  List<Object?> list(String field) {
    final value = _require(field);
    if (value is List) return value.cast<Object?>();
    throw FormatException('$field is not a list', value);
  }

  static DateTime _parseTimestamp(String value, String field) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field is not a timestamp', value);
    }
    return parsed.toUtc();
  }

  Object? _require(String field) {
    if (!_fields.containsKey(field)) {
      throw FormatException('$field is missing', _fields);
    }
    return _fields[field];
  }

  T _typed<T extends Object>(String field) {
    final value = _require(field);
    if (value is T) return value;
    throw FormatException('$field is not a $T', value);
  }

  T? _optional<T extends Object>(String field) {
    final value = _require(field);
    if (value == null || value is T) return value as T?;
    throw FormatException('$field is not a $T', value);
  }
}

/// An enumeration that mirrors a database enum one to one; [db] is the
/// value the database stores (`apartment_building`, `khyber_pakhtunkhwa`).
mixin DbEnum on Enum {
  String get db;
}

/// The value of [values] the database calls [name]; throws
/// [FormatException] for a value this app does not know.
T parseDbEnum<T extends DbEnum>(List<T> values, String name) {
  for (final value in values) {
    if (value.db == name) return value;
  }
  throw FormatException('unknown value', name);
}
