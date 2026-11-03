import 'package:meta/meta.dart';

/// Pakistan Standard Time is UTC+05:00 all year (no daylight saving since
/// 2009). Due dates, payment dates and "today" are all evaluated in PKT.
const Duration pakistanUtcOffset = Duration(hours: 5);

/// A calendar date without a time of day or time zone, e.g. a rent due date.
///
/// Using `DateTime` for dates invites off-by-one bugs around midnight and
/// time-zone conversion; a `CalendarDate` is just a year, month and day, and
/// all arithmetic is performed in UTC internally so it is DST-proof.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// Creates a validated date. Throws [ArgumentError] for impossible dates
  /// such as 2026-02-30.
  new(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'must be within 1..9999');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be within 1..12');
    }
    final maxDay = daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw ArgumentError.value(day, 'day', 'must be within 1..$maxDay');
    }
  }

  /// The calendar date of [dateTime] as seen in its own time zone fields.
  factory fromDateTime(DateTime dateTime) =>
      CalendarDate(dateTime.year, dateTime.month, dateTime.day);

  /// Today's date in Pakistan (PKT), regardless of the device time zone.
  ///
  /// Pass [now] in tests for determinism.
  factory todayInPakistan({DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    return CalendarDate.fromDateTime(utc.add(pakistanUtcOffset));
  }

  /// Parses a strict ISO-8601 calendar date (`YYYY-MM-DD`).
  ///
  /// Throws a [FormatException] for anything else.
  factory parse(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) {
      throw FormatException('Expected a YYYY-MM-DD date', iso);
    }
    return parsed;
  }

  /// Decodes a JSON date string (`YYYY-MM-DD`, as returned by PostgREST).
  factory fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('Expected a date string', '$json');
    }
    return CalendarDate.parse(json);
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses `YYYY-MM-DD`, returning `null` for malformed or impossible dates.
  static CalendarDate? tryParse(String iso) {
    final match = _isoPattern.firstMatch(iso.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year < 1 || month < 1 || month > 12) return null;
    if (day < 1 || day > daysInMonth(year, month)) return null;
    return CalendarDate(year, month, day);
  }

  /// Whether [year] is a Gregorian leap year.
  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Number of days in [month] of [year].
  static int daysInMonth(int year, int month) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) return 29;
    return days[month - 1];
  }

  /// The earlier of two dates.
  static CalendarDate min(CalendarDate a, CalendarDate b) =>
      a.isAfter(b) ? b : a;

  /// The later of two dates.
  static CalendarDate max(CalendarDate a, CalendarDate b) =>
      a.isBefore(b) ? b : a;

  /// Four-digit year.
  final int year;

  /// Month, 1–12.
  final int month;

  /// Day of month, 1–31.
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => _utc.weekday;

  /// Day of the year, 1–366.
  int get dayOfYear => differenceInDays(CalendarDate(year, 1, 1)) + 1;

  /// Number of days in this date's month.
  int get lengthOfMonth => daysInMonth(year, month);

  /// Whether this date is the last day of its month.
  bool get isLastDayOfMonth => day == lengthOfMonth;

  /// The date [days] days later (or earlier when negative).
  CalendarDate addDays(int days) =>
      CalendarDate.fromDateTime(_utc.add(Duration(days: days)));

  /// The date [months] months later (or earlier when negative). The day is
  /// clamped to the length of the target month: Jan 31 + 1 month = Feb 28/29.
  CalendarDate addMonths(int months) {
    final zeroBased = year * 12 + (month - 1) + months;
    final targetYear = zeroBased ~/ 12;
    final targetMonth = zeroBased % 12 + 1;
    final targetDay = day.clamp(1, daysInMonth(targetYear, targetMonth));
    return CalendarDate(targetYear, targetMonth, targetDay);
  }

  /// The date [years] years later; Feb 29 maps to Feb 28 in common years.
  CalendarDate addYears(int years) => addMonths(years * 12);

  /// Whole days from [other] to this date (positive when this is later).
  int differenceInDays(CalendarDate other) =>
      _utc.difference(other._utc).inDays;

  /// Whether this date is strictly before [other].
  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  /// Whether this date is strictly after [other].
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  /// Whether this date is on or before [other].
  bool isOnOrBefore(CalendarDate other) => compareTo(other) <= 0;

  /// Whether this date is on or after [other].
  bool isOnOrAfter(CalendarDate other) => compareTo(other) >= 0;

  /// Midnight UTC at the start of this date.
  DateTime toDateTimeUtc() => _utc;

  /// ISO-8601 representation, `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// JSON representation (ISO-8601 date string).
  String toJson() => toIso();

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
