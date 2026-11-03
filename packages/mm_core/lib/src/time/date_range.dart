import 'package:meta/meta.dart';
import 'package:mm_core/src/time/calendar_date.dart';

/// An inclusive range of calendar dates. An open-ended range (no [end])
/// represents a periodic tenancy that continues until terminated.
@immutable
final class DateRange {
  /// Creates a range from [start] to [end] inclusive. Throws [ArgumentError]
  /// when [end] precedes [start].
  new(this.start, [this.end]) {
    final last = end;
    if (last != null && last.isBefore(start)) {
      throw ArgumentError('end ($last) must not precede start ($start)');
    }
  }

  /// First day of the range.
  final CalendarDate start;

  /// Last day of the range, or `null` when open-ended.
  final CalendarDate? end;

  /// Whether the range has no end date.
  bool get isOpenEnded => end == null;

  /// Whether [date] lies within the range.
  bool contains(CalendarDate date) {
    final last = end;
    return date.isOnOrAfter(start) && (last == null || date.isOnOrBefore(last));
  }

  /// Whether this range shares at least one day with [other].
  bool overlaps(DateRange other) {
    final thisEnd = end;
    final otherEnd = other.end;
    final startsBeforeOtherEnds =
        otherEnd == null || start.isOnOrBefore(otherEnd);
    final otherStartsBeforeThisEnds =
        thisEnd == null || other.start.isOnOrBefore(thisEnd);
    return startsBeforeOtherEnds && otherStartsBeforeThisEnds;
  }

  /// The overlapping part of two ranges, or `null` when they do not overlap.
  DateRange? intersection(DateRange other) {
    if (!overlaps(other)) return null;
    final first = CalendarDate.max(start, other.start);
    final thisEnd = end;
    final otherEnd = other.end;
    final CalendarDate? last;
    if (thisEnd == null) {
      last = otherEnd;
    } else if (otherEnd == null) {
      last = thisEnd;
    } else {
      last = CalendarDate.min(thisEnd, otherEnd);
    }
    return DateRange(first, last);
  }

  /// Number of days in the range, or `null` when open-ended.
  int? get lengthInDays {
    final last = end;
    return last == null ? null : last.differenceInDays(start) + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start .. ${end ?? '∞'}]';
}
