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

  /// The whole number [field].
  int integer(String field) => _typed<int>(field);

  /// The boolean [field].
  bool boolean(String field) => _typed<bool>(field);

  /// The object [field].
  JsonRow object(String field) => JsonRow.of(_require(field), field);

  /// The list [field].
  List<Object?> list(String field) {
    final value = _require(field);
    if (value is List) return value.cast<Object?>();
    throw FormatException('$field is not a list', value);
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
