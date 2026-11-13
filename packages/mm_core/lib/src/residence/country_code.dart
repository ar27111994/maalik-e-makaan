import 'package:meta/meta.dart';
import 'package:mm_core/src/time/time_zone.dart';
import 'package:mm_core/src/time/time_zone_data.g.dart';

/// A country a person says they live in: an ISO 3166-1 alpha-2 code of the
/// bundled tz database's `iso3166.tab` (`PK`, `GB`), as
/// `profile_residences.residence_country` stores it.
///
/// Declared by the person, never inferred: not from a +92 number, the store
/// country, an IP address, the app's language or a payment currency.
@immutable
final class CountryCode implements Comparable<CountryCode> {
  const new _(this.code);

  /// A code to store: exactly one of [all]. Throws a [FormatException]
  /// otherwise.
  factory parse(String stored) {
    if (!tzCountries.containsKey(stored)) {
      throw FormatException('Not a supported country code', stored);
    }
    return CountryCode._(stored);
  }

  /// Decodes a stored code. Two upper-case letters this build does not know
  /// (a newer build may store one) are kept, with [isKnown] false; anything
  /// else throws a [FormatException].
  factory fromJson(Object? json) {
    if (json is String && _shape.hasMatch(json)) return CountryCode._(json);
    throw FormatException('Expected an ISO 3166-1 alpha-2 code', '$json');
  }

  /// Pakistan.
  static const pakistan = CountryCode._('PK');

  /// Every country a person may store, sorted by code.
  static final List<CountryCode> all = List.unmodifiable(
    tzCountries.keys.map(CountryCode._),
  );

  /// Reads typed or picked input: spaces around it are dropped and letters
  /// upper-cased. Returns `null` unless the result is a supported code (so
  /// `UK`, `XK` and `PAK` are refused; the United Kingdom is `GB`).
  static CountryCode? tryParse(String input) {
    final code = input.trim().toUpperCase();
    return tzCountries.containsKey(code) ? CountryCode._(code) : null;
  }

  static final RegExp _shape = RegExp(r'^[A-Z]{2}$');

  /// The two upper-case letters.
  final String code;

  /// Whether this build supports the code.
  bool get isKnown => tzCountries.containsKey(code);

  /// Whether this is Pakistan.
  bool get isPakistan => code == pakistan.code;

  /// The country's time zones, in `zone.tab`'s order (the first is the most
  /// populous); empty for an unknown code or a country without people.
  List<TimeZoneId> get timeZones => [
    for (final name in tzCountries[code] ?? const <String>[])
      TimeZoneId.parse(name),
  ];

  /// The code.
  String toJson() => code;

  @override
  int compareTo(CountryCode other) => code.compareTo(other.code);

  @override
  bool operator ==(Object other) => other is CountryCode && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
