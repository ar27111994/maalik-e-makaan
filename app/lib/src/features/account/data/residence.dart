import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:mm_core/mm_core.dart';

/// Where the signed-in user says they live, and the zone of their own
/// alerts (`public.profile_residences`): theirs alone, never shown to
/// teammates or tenants, never inferred, and never the answer to a
/// portfolio's "Does the owner of these properties live abroad?".
@immutable
final class AccountResidence {
  const new({required this.residence, this.statedAt});

  /// Reads a `profile_residences` row selected with
  /// [AccountResidence.columns]. A well-formed country or zone this app
  /// version does not know (a newer one stored it) is kept, not refused,
  /// so the rest of the app keeps working; alerts then use Pakistan time.
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'residence');
    final country = row.optionalString('residence_country');
    final zone = row.optionalString('time_zone');
    return AccountResidence(
      residence: Residence(
        country: country == null ? null : CountryCode.fromJson(country),
        timeZone: zone == null ? null : TimeZoneId.fromJson(zone),
      ),
      statedAt: row.optionalTimestamp('stated_at'),
    );
  }

  /// The columns [AccountResidence.fromRow] reads.
  static const columns = 'residence_country,time_zone,stated_at';

  /// Nothing stated yet.
  static const notStated = AccountResidence(residence: Residence.notStated);

  final Residence residence;

  /// When the user last answered; null when they never have (the app may
  /// ask once).
  final DateTime? statedAt;

  /// Whether the user has ever answered (perhaps choosing not to say).
  bool get stated => statedAt != null;

  /// The zone of the user's alerts, digests, quiet hours and the second
  /// time of a dual time; Pakistan's unless they chose one this app knows.
  /// Never for business dates.
  TimeZoneId get alertZone => residence.alertZone;

  /// The row [AccountResidence.fromRow] reads back (for the offline cache).
  Map<String, Object?> toRow() => {
    'residence_country': residence.country?.code,
    'time_zone': residence.timeZone?.name,
    'stated_at': statedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AccountResidence &&
      other.residence == residence &&
      other.statedAt == statedAt;

  @override
  int get hashCode => Object.hash(residence, statedAt);
}
