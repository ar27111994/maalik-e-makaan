import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final date = CalendarDate(2026, 11, 12);

  test('validates the time of day', () {
    expect(LocalDateTime(date, 23, 59, 59).secondOfDay, 86399);
    expect(LocalDateTime(date, 0, 0).second, 0);
    expect(() => LocalDateTime(date, 24, 0), throwsArgumentError);
    expect(() => LocalDateTime(date, -1, 0), throwsArgumentError);
    expect(() => LocalDateTime(date, 0, 60), throwsArgumentError);
    expect(() => LocalDateTime(date, 0, -1), throwsArgumentError);
    expect(() => LocalDateTime(date, 0, 0, 60), throwsArgumentError);
    expect(() => LocalDateTime(date, 0, 0, -1), throwsArgumentError);
  });

  test('parses exactly YYYY-MM-DDTHH:MM:SS', () {
    expect(
      LocalDateTime.parse('2026-11-12T15:15:07'),
      LocalDateTime(date, 15, 15, 7),
    );
    for (final bad in [
      '2026-11-12T24:00:00',
      '2026-11-12T23:60:00',
      '2026-11-12T23:59:60',
      '2026-02-30T00:00:00',
      '0000-01-01T00:00:00',
      '2026-11-12 15:15:00',
      '2026-11-12T15:15',
      '2026-11-12T15:15:00Z',
      ' 2026-11-12T15:15:00',
      '',
    ]) {
      expect(
        () => LocalDateTime.parse(bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  test('converts to and from seconds on the same clock', () {
    final local = LocalDateTime(date, 15, 15, 7);
    expect(local.secondsSinceEpoch, 1794496507);
    expect(LocalDateTime.fromSecondsSinceEpoch(1794496507), local);
    expect(
      LocalDateTime.fromSecondsSinceEpoch(-1),
      LocalDateTime(CalendarDate(1969, 12, 31), 23, 59, 59),
    );
  });

  test('orders, compares and prints', () {
    final morning = LocalDateTime(date, 8, 0);
    final evening = LocalDateTime(date, 20, 0);
    final tomorrow = LocalDateTime(date.addDays(1), 7, 0);
    expect(morning.compareTo(evening), lessThan(0));
    expect(evening.compareTo(tomorrow), lessThan(0));
    expect(tomorrow.compareTo(morning), greaterThan(0));
    expect(morning, LocalDateTime.parse('2026-11-12T08:00:00'));
    expect(morning, isNot(evening));
    expect(morning.hashCode, LocalDateTime(date, 8, 0).hashCode);
    expect(morning.clockTime, ClockTime(8, 0));
    expect('$morning', '2026-11-12T08:00:00');
    expect(LocalDateTime(date, 8, 5, 9).toIso(), '2026-11-12T08:05:09');
  });
}
