import 'package:meta/meta.dart';

/// A time of day to the minute, with no date and no time zone: when quiet
/// hours start or end, or when a digest goes out. Shown and stored as
/// `HH:MM`, from 00:00 to 23:59.
@immutable
final class ClockTime implements Comparable<ClockTime> {
  /// Creates a validated time. Throws [ArgumentError] when [hour] is outside
  /// 0–23 or [minute] outside 0–59.
  new(this.hour, this.minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be within 0..23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be within 0..59');
    }
  }

  /// Parses exactly `HH:MM` (two ASCII digits each). Throws a
  /// [FormatException] for anything else, including 24:00.
  factory parse(String text) {
    final match = _pattern.firstMatch(text);
    final hour = match == null ? 24 : int.parse(match.group(1)!);
    final minute = match == null ? 60 : int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw FormatException('Expected a time of day as HH:MM', text);
    }
    return ClockTime(hour, minute);
  }

  /// Decodes `HH:MM`, or PostgreSQL's `time` as `HH:MM:00`.
  factory fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('Expected a time of day', '$json');
    }
    final whole = json.length == 8 && json.endsWith(':00');
    return ClockTime.parse(whole ? json.substring(0, 5) : json);
  }

  static final RegExp _pattern = RegExp(r'^(\d{2}):(\d{2})$');

  /// Hour of the day, 0–23.
  final int hour;

  /// Minute of the hour, 0–59.
  final int minute;

  /// Minutes since midnight, 0–1439.
  int get minuteOfDay => hour * 60 + minute;

  /// `HH:MM`.
  String toJson() => toString();

  @override
  int compareTo(ClockTime other) => minuteOfDay.compareTo(other.minuteOfDay);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
