import 'package:meta/meta.dart';

/// A syntactically valid, normalised (trimmed, lower-cased) e-mail address.
///
/// The check is deliberately pragmatic rather than a full RFC 5322 parser:
/// it rejects the mistakes people actually make (missing `@`, spaces, missing
/// top-level domain, consecutive dots) while accepting every address that
/// real providers issue, including `+tags` and sub-domains.
@immutable
final class EmailAddress {
  const new _(this.value);

  /// Parses [input]; throws a [FormatException] when invalid.
  factory parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) throw FormatException('Invalid e-mail address', input);
    return parsed;
  }

  /// Maximum length permitted by RFC 5321.
  static const int maxLength = 254;

  static final RegExp _pattern = RegExp(
    r"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
    r'@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );

  /// Parses [input], returning `null` when it is not a valid address.
  static EmailAddress? tryParse(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty || normalized.length > maxLength) return null;
    final at = normalized.indexOf('@');
    if (at <= 0 || at > 64) return null; // local part is at most 64 chars
    if (!_pattern.hasMatch(normalized)) return null;
    return EmailAddress._(normalized);
  }

  /// The normalised address.
  final String value;

  /// The part after `@`.
  String get domain => value.substring(value.indexOf('@') + 1);

  @override
  bool operator ==(Object other) =>
      other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
