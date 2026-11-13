import 'package:meta/meta.dart';
import 'package:mm_core/src/residence/country_code.dart';
import 'package:mm_core/src/time/time_zone.dart';

/// Whether a person has said where they live, and whether it is Pakistan.
enum ResidenceStatus {
  /// The person has not said.
  notStated,

  /// The person lives in Pakistan.
  pakistan,

  /// The person lives in another country.
  abroad,
}

/// Where a person says they live, and the zone of their own alerts.
///
/// Declared only: there is no way to make one from a phone number, a
/// language, the store country or a currency. It is the person's own (not
/// shown to teammates or tenants), and it never answers a portfolio's
/// question "Does the owner of these properties live abroad?"
/// (`OwnerAbroad`), because whoever creates a portfolio is often a caretaker
/// or a relative. Nationality and immigration status are never recorded.
@immutable
final class Residence {
  /// Creates a residence; either part may be left unstated.
  const new({this.country, this.timeZone});

  /// Nothing stated.
  static const notStated = Residence();

  /// The country the person says they live in, or `null`.
  final CountryCode? country;

  /// The zone the person chose for their own alerts, or `null` (Pakistan
  /// time).
  final TimeZoneId? timeZone;

  /// Whether the person lives in Pakistan, abroad, or has not said.
  ResidenceStatus get status => switch (country) {
    null => ResidenceStatus.notStated,
    final country when country.isPakistan => ResidenceStatus.pakistan,
    _ => ResidenceStatus.abroad,
  };

  /// Whether the person lives abroad but has not chosen a time zone (the
  /// app asks for one).
  bool get needsTimeZone =>
      status == ResidenceStatus.abroad && timeZone == null;

  /// The zone of the person's alerts, digests, quiet hours and the second
  /// time of a `DualTime`: their stated zone when this build knows it,
  /// otherwise Pakistan's. Never for business dates, which stay on Pakistan
  /// time.
  TimeZoneId get alertZone => switch (timeZone) {
    final zone? when zone.isKnown => zone,
    _ => TimeZoneId.pakistan,
  };

  @override
  bool operator ==(Object other) =>
      other is Residence &&
      other.country == country &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(country, timeZone);

  @override
  String toString() => 'Residence(${country ?? '-'}, ${timeZone ?? '-'})';
}
