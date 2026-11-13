import 'package:meta/meta.dart';
import 'package:mm_core/src/time/clock_time.dart';
import 'package:mm_core/src/time/local_date_time.dart';
import 'package:mm_core/src/time/time_zone.dart';

const int _microsPerDay = 86400 * 1000000;

/// The hours a person does not want alerts, by the clock of their own zone:
/// from [start] up to, but not including, [end], across midnight when
/// [start] is later than [end] (22:00 to 07:00).
///
/// A person without quiet hours has no [QuietHours] at all; there is no
/// default window here.
@immutable
final class QuietHours {
  /// Creates quiet hours. Throws [ArgumentError] when [start] equals [end],
  /// which could mean either all day or never.
  new(this.start, this.end) {
    if (start == end) {
      throw ArgumentError.value(end, 'end', 'must differ from start');
    }
  }

  /// When they begin.
  final ClockTime start;

  /// When they end: the first minute that is not quiet.
  final ClockTime end;

  /// Whether a wall-clock time is within the quiet hours.
  bool includes(LocalDateTime local) {
    final second = local.secondOfDay;
    final from = start.minuteOfDay * 60;
    final until = end.minuteOfDay * 60;
    return from < until
        ? second >= from && second < until
        : second >= from || second < until;
  }

  /// Whether [instant] falls within the quiet hours of [zone]'s clocks.
  bool isQuietAt(DateTime instant, TimeZoneId zone) =>
      includes(zone.at(instant).local);

  /// When an alert due at [instant] may go out: [instant] itself when it is
  /// not quiet, otherwise the first later instant at which [zone]'s clocks
  /// are outside the quiet hours.
  ///
  /// That is usually [end] on the zone's clock, but a clock change can end
  /// them sooner (London's clocks jump from 01:00 to 02:00 past an end of
  /// 01:30) or start them again (on the night the clocks go back, the
  /// repeated hour is quiet again).
  DateTime releaseAt(DateTime instant, TimeZoneId zone) {
    if (!isQuietAt(instant, zone)) return instant;
    var moment = instant.toUtc();
    while (true) {
      // Within one offset the clock leaves the window when it reaches [end].
      final micros = moment.microsecondsSinceEpoch;
      final wall = micros + zone.offsetAt(moment).inMicroseconds;
      final untilEnd = (end.minuteOfDay * 60 * 1000000 - wall) % _microsPerDay;
      final leaves = DateTime.fromMicrosecondsSinceEpoch(
        micros + untilEnd,
        isUtc: true,
      );
      final change = zone.nextChangeAfter(moment);
      if (change == null || leaves.isBefore(change)) return leaves;
      // The clock changes first; at the change it may already be outside.
      if (!isQuietAt(change, zone)) return change;
      moment = change;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start–$end';
}
