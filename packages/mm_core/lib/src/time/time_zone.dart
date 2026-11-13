import 'package:meta/meta.dart';
import 'package:mm_core/src/residence/country_code.dart';
import 'package:mm_core/src/time/clock_time.dart';
import 'package:mm_core/src/time/local_date_time.dart';
import 'package:mm_core/src/time/time_zone_data.g.dart';

const int _microsPerSecond = 1000000;
const int _secondsPerDay = 86400;

/// An IANA time zone a person may store as the zone of their own alerts
/// (`profile_residences.time_zone`): a `zone.tab` name of the bundled tz
/// database, such as `Europe/London`.
///
/// Only a person's alerts, digests, quiet hours and the second time of a
/// `DualTime` use it. Rent, ledger and due dates, police deadlines, the tax
/// year and every message to tenants stay on Pakistan time
/// (`CalendarDate.todayInPakistan`), whatever zone a person states.
///
/// Offsets come from the bundled data (`time_zone_data.g.dart`, generated
/// from the pinned tzdata by `make contracts`), which covers 2020 to 2100:
/// before 2020 a zone keeps its 2020 offset, from 2100 its last one. Every
/// rule is checked against `contracts/time_zone_vectors.json`, as
/// PostgreSQL's conversions are in suite 23.
@immutable
final class TimeZoneId implements Comparable<TimeZoneId> {
  const new _(this.name);

  /// A zone to store: exactly one of [all]. Throws a [FormatException]
  /// otherwise (`Asia/Calcutta`, `UTC`, `europe/london`).
  factory parse(String stored) {
    final zone = tryParse(stored);
    if (zone == null) {
      throw FormatException('Not a supported time zone', stored);
    }
    return zone;
  }

  /// Decodes a stored zone. A well-formed name this build does not know (a
  /// newer build may store one) is kept, with [isKnown] false, so an older
  /// app can still read the row; anything else throws a [FormatException].
  factory fromJson(Object? json) {
    if (json is String && json.length <= 64 && _shape.hasMatch(json)) {
      return TimeZoneId._(json);
    }
    throw FormatException('Expected a time zone name', '$json');
  }

  /// Pakistan: UTC+05:00 all year. Not stated means this.
  static const pakistan = TimeZoneId._('Asia/Karachi');

  /// Every zone a person may store, sorted by name.
  static final List<TimeZoneId> all = List.unmodifiable(
    tzZones.keys.map(TimeZoneId._),
  );

  /// The stored zone named exactly [name], or `null`.
  static TimeZoneId? tryParse(String name) =>
      tzZones.containsKey(name) ? TimeZoneId._(name) : null;

  /// The zone to suggest for a device's zone name, or `null`. A stored name
  /// is itself (`Asia/Kuwait`); an old or linked name is the zone it links
  /// to (`Asia/Calcutta` is `Asia/Kolkata`). Only a suggestion: a person
  /// confirms the zone, and the device's zone is never their residence.
  static TimeZoneId? fromDevice(String deviceName) {
    if (tzZones.containsKey(deviceName)) return TimeZoneId._(deviceName);
    final target = tzDeviceLinks[deviceName];
    return target == null ? null : TimeZoneId._(target);
  }

  static final RegExp _shape = RegExp(
    r'^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+){1,2}$',
  );

  /// The IANA name, such as `Europe/London`.
  final String name;

  /// Whether this build has the zone's offsets.
  bool get isKnown => tzZones.containsKey(name);

  /// Whether this is Pakistan's zone. Another zone that is also UTC+05:00
  /// (`Asia/Tashkent`) is not Pakistan.
  bool get isPakistan => name == pakistan.name;

  /// The zone's country in `zone.tab`, or `null` when the zone is unknown.
  CountryCode? get country {
    final entry = tzZones[name];
    return entry == null ? null : CountryCode.parse(entry.$2);
  }

  /// The place in the zone's name, in English (`London`, `Buenos Aires`).
  /// A fallback: screens show the localised name.
  String get exemplarCity =>
      name.substring(name.lastIndexOf('/') + 1).replaceAll('_', ' ');

  List<int> get _schedule {
    final entry = tzZones[name];
    if (entry == null) {
      throw StateError('This build has no offsets for the time zone $name');
    }
    return tzSchedules[entry.$1];
  }

  /// How many of [schedule]'s clock changes happen at or before [micros].
  static int _changesUntil(List<int> schedule, int micros) {
    var low = 0;
    var high = (schedule.length - 1) ~/ 2;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (schedule[1 + 2 * middle] * _microsPerSecond <= micros) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int _offsetSeconds(int micros) {
    final schedule = _schedule;
    final changes = _changesUntil(schedule, micros);
    return changes == 0 ? schedule[0] : schedule[2 * changes];
  }

  /// The zone's offset from UTC at [instant]. Throws a [StateError] when the
  /// zone is not [isKnown].
  Duration offsetAt(DateTime instant) =>
      Duration(seconds: _offsetSeconds(instant.microsecondsSinceEpoch));

  /// The first instant after [instant] at which the zone's offset changes,
  /// or `null` when it does not change again before 2100.
  DateTime? nextChangeAfter(DateTime instant) {
    final schedule = _schedule;
    final next = _changesUntil(schedule, instant.microsecondsSinceEpoch);
    if (2 * next + 1 >= schedule.length) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      schedule[2 * next + 1] * 1000,
      isUtc: true,
    );
  }

  /// [instant] as seen in this zone.
  ZonedDateTime at(DateTime instant) =>
      ZonedDateTime._(instant.toUtc(), this, offsetAt(instant));

  /// The instant (UTC) at which this zone's clocks read [local].
  ///
  /// A local time a clock change skips (spring forward) or repeats (fall
  /// back) is read as the later of its two instants, as PostgreSQL's
  /// `timestamp at time zone` reads it: 01:30 on the day London's clocks go
  /// forward is 01:30 UTC, and on the day they go back, the second 01:30.
  DateTime instantAt(LocalDateTime local) {
    // The offsets a day either side; the generator asserts that a zone's
    // clock changes are at least two days apart, so at most one lies between.
    final wall = local.secondsSinceEpoch;
    final before = _offsetSeconds((wall - _secondsPerDay) * _microsPerSecond);
    final after = _offsetSeconds((wall + _secondsPerDay) * _microsPerSecond);
    final first = wall - before;
    final second = wall - after;
    final firstReads = _offsetSeconds(first * _microsPerSecond) == before;
    final secondReads = _offsetSeconds(second * _microsPerSecond) == after;
    // Both read back: a repeated time, take the later. Neither: a skipped
    // time, and wall - before (the offset before the change) is the later.
    final instant = secondReads && (!firstReads || second > first)
        ? second
        : first;
    return DateTime.fromMillisecondsSinceEpoch(instant * 1000, isUtc: true);
  }

  /// The first instant strictly after [after] at which this zone's clocks
  /// read [time], on the ISO [isoWeekday] (Monday 1 to Sunday 7) when one is
  /// given. A skipped or repeated time follows [instantAt].
  DateTime nextAt(ClockTime time, {required DateTime after, int? isoWeekday}) {
    if (isoWeekday != null && (isoWeekday < 1 || isoWeekday > 7)) {
      throw ArgumentError.value(isoWeekday, 'isoWeekday', 'must be 1..7');
    }
    var date = at(after).local.date.addDays(-1);
    while (true) {
      if (isoWeekday == null || date.weekday == isoWeekday) {
        final instant = instantAt(LocalDateTime(date, time.hour, time.minute));
        if (instant.isAfter(after)) return instant;
      }
      date = date.addDays(1);
    }
  }

  /// The IANA name.
  String toJson() => name;

  @override
  int compareTo(TimeZoneId other) => name.compareTo(other.name);

  @override
  bool operator ==(Object other) => other is TimeZoneId && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// An instant as seen in a time zone: what its clocks read, and its offset.
@immutable
final class ZonedDateTime {
  const new _(this.instant, this.zone, this.offset);

  /// The instant, in UTC.
  final DateTime instant;

  /// The zone it is seen in.
  final TimeZoneId zone;

  /// The zone's offset from UTC at [instant].
  final Duration offset;

  /// What the zone's clocks read at [instant], to the second.
  LocalDateTime get local {
    final micros = instant.microsecondsSinceEpoch + offset.inMicroseconds;
    final seconds = (micros - micros % _microsPerSecond) ~/ _microsPerSecond;
    return LocalDateTime.fromSecondsSinceEpoch(seconds);
  }

  @override
  bool operator ==(Object other) =>
      other is ZonedDateTime &&
      other.instant == instant &&
      other.zone == zone &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(instant, zone, offset);

  @override
  String toString() {
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final rest = (minutes % 60).toString().padLeft(2, '0');
    return '${local.toIso()}$sign$hours:$rest ($zone)';
  }
}
