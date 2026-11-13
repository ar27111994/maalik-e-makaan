import 'package:meta/meta.dart';
import 'package:mm_core/src/time/calendar_date.dart';
import 'package:mm_core/src/time/clock_time.dart';

/// A wall-clock date and time to the second, with no time zone: what a clock
/// in some place reads. `TimeZoneId.at` gives one for an instant, and
/// `TimeZoneId.instantAt` turns one back into an instant.
@immutable
final class LocalDateTime implements Comparable<LocalDateTime> {
  /// Creates a validated local time. Throws [ArgumentError] when [hour],
  /// [minute] or [second] is out of range.
  new(this.date, this.hour, this.minute, [this.second = 0]) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be within 0..23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be within 0..59');
    }
    if (second < 0 || second > 59) {
      throw ArgumentError.value(second, 'second', 'must be within 0..59');
    }
  }

  /// The local time [seconds] after 1970-01-01T00:00:00 on the same clock
  /// (the wall time read as if it were UTC).
  factory fromSecondsSinceEpoch(int seconds) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );
    return LocalDateTime(
      CalendarDate(utc.year, utc.month, utc.day),
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  /// Parses exactly `YYYY-MM-DDTHH:MM:SS`. Throws a [FormatException] for
  /// anything else.
  factory parse(String iso) {
    final match = _pattern.firstMatch(iso);
    final date = match == null ? null : CalendarDate.tryParse(match.group(1)!);
    if (match == null || date == null) {
      throw FormatException('Expected YYYY-MM-DDTHH:MM:SS', iso);
    }
    final hour = int.parse(match.group(2)!);
    final minute = int.parse(match.group(3)!);
    final second = int.parse(match.group(4)!);
    if (hour > 23 || minute > 59 || second > 59) {
      throw FormatException('Expected YYYY-MM-DDTHH:MM:SS', iso);
    }
    return LocalDateTime(date, hour, minute, second);
  }

  static final RegExp _pattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})$',
  );

  /// The calendar date.
  final CalendarDate date;

  /// Hour of the day, 0–23.
  final int hour;

  /// Minute of the hour, 0–59.
  final int minute;

  /// Second of the minute, 0–59.
  final int second;

  /// The time of day to the minute.
  ClockTime get clockTime => ClockTime(hour, minute);

  /// Seconds since midnight, 0–86399.
  int get secondOfDay => hour * 3600 + minute * 60 + second;

  /// Seconds from 1970-01-01T00:00:00 on the same clock (the inverse of
  /// [LocalDateTime.fromSecondsSinceEpoch]).
  int get secondsSinceEpoch =>
      date.toDateTimeUtc().millisecondsSinceEpoch ~/ 1000 + secondOfDay;

  /// `YYYY-MM-DDTHH:MM:SS`.
  String toIso() =>
      '${date.toIso()}T${_two(hour)}:${_two(minute)}:${_two(second)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  int compareTo(LocalDateTime other) {
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : secondOfDay.compareTo(other.secondOfDay);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDateTime &&
      other.date == date &&
      other.secondOfDay == secondOfDay;

  @override
  int get hashCode => Object.hash(date, secondOfDay);

  @override
  String toString() => toIso();
}
