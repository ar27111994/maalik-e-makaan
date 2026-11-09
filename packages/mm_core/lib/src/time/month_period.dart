import 'package:meta/meta.dart';
import 'package:mm_core/src/time/calendar_date.dart';

/// A calendar month, e.g. the November 2026 rent period.
@immutable
final class MonthPeriod implements Comparable<MonthPeriod> {
  /// Creates a validated month period.
  new(this.year, this.month) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'must be within 1..9999');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be within 1..12');
    }
  }

  /// The month containing [date].
  factory of(CalendarDate date) => MonthPeriod(date.year, date.month);

  /// Parses `YYYY-MM` or a full `YYYY-MM-DD` date (the day is ignored).
  ///
  /// Throws a [FormatException] for malformed input.
  factory parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Expected YYYY-MM', value);
    }
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      throw FormatException('Month must be within 01..12', value);
    }
    return MonthPeriod(int.parse(match.group(1)!), month);
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})(?:-\d{2})?$');

  /// Four-digit year.
  final int year;

  /// Month, 1–12.
  final int month;

  /// The first day of the month.
  CalendarDate get first => CalendarDate(year, month, 1);

  /// The last day of the month.
  CalendarDate get last =>
      CalendarDate(year, month, CalendarDate.daysInMonth(year, month));

  /// Number of days in the month.
  int get lengthInDays => CalendarDate.daysInMonth(year, month);

  /// The following month.
  MonthPeriod get next => addMonths(1);

  /// The preceding month.
  MonthPeriod get previous => addMonths(-1);

  /// The month [months] months later (earlier when negative).
  MonthPeriod addMonths(int months) {
    final zeroBased = year * 12 + (month - 1) + months;
    return MonthPeriod(zeroBased ~/ 12, zeroBased % 12 + 1);
  }

  /// Whole months from [other] to this month (positive when this is later).
  int monthsSince(MonthPeriod other) =>
      (year * 12 + month) - (other.year * 12 + other.month);

  /// Whether [date] falls inside this month.
  bool contains(CalendarDate date) => date.year == year && date.month == month;

  /// The date in this month with day-of-month [day], clamped to the month's
  /// length (day 31 in February yields the 28th or 29th).
  CalendarDate dayClamped(int day) =>
      CalendarDate(year, month, day.clamp(1, lengthInDays));

  /// Every month from [from] to [to] inclusive, in order. Empty when [to] is
  /// before [from].
  static List<MonthPeriod> range(MonthPeriod from, MonthPeriod to) {
    final count = to.monthsSince(from);
    return [for (var i = 0; i <= count; i++) from.addMonths(i)];
  }

  /// `YYYY-MM`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(MonthPeriod other) => year != other.year
      ? year.compareTo(other.year)
      : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is MonthPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => toIso();
}
