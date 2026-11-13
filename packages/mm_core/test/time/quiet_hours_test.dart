import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final london = TimeZoneId.parse('Europe/London');
  final night = QuietHours(ClockTime(22, 0), ClockTime(7, 0));
  final lunch = QuietHours(ClockTime(13, 0), ClockTime(14, 0));
  final date = CalendarDate(2026, 11, 12);

  test('start and end must differ', () {
    expect(
      () => QuietHours(ClockTime(22, 0), ClockTime(22, 0)),
      throwsArgumentError,
    );
  });

  test('include [start, end), across midnight when start is later', () {
    expect(night.includes(LocalDateTime(date, 22, 0)), isTrue);
    expect(night.includes(LocalDateTime(date, 3, 0)), isTrue);
    expect(night.includes(LocalDateTime(date, 6, 59, 59)), isTrue);
    expect(night.includes(LocalDateTime(date, 7, 0)), isFalse);
    expect(night.includes(LocalDateTime(date, 21, 59, 59)), isFalse);
    expect(lunch.includes(LocalDateTime(date, 13, 30)), isTrue);
    expect(lunch.includes(LocalDateTime(date, 14, 0)), isFalse);
    expect(lunch.includes(LocalDateTime(date, 12, 59)), isFalse);
  });

  test('are read on the zone of the person', () {
    final instant = DateTime.utc(2026, 11, 12, 18);
    expect(night.isQuietAt(instant, london), isFalse);
    expect(night.isQuietAt(instant, TimeZoneId.pakistan), isTrue);
  });

  test('release an alert at the end, or when a clock change ends them', () {
    final instant = DateTime.utc(2026, 11, 12, 23, 0, 30, 250);
    expect(night.releaseAt(instant, london), DateTime.utc(2026, 11, 13, 7));
    final noon = DateTime.utc(2026, 11, 12, 12);
    expect(night.releaseAt(noon, london), same(noon));
    // The end (01:30) is skipped when the clocks go forward at 01:00.
    final early = QuietHours(ClockTime(22, 0), ClockTime(1, 30));
    expect(
      early.releaseAt(DateTime.utc(2027, 3, 28, 0, 50), london),
      DateTime.utc(2027, 3, 28, 1),
    );
    // When the clocks go back, the repeated hour is quiet again.
    expect(
      early.releaseAt(DateTime.utc(2027, 10, 31, 0, 20), london),
      DateTime.utc(2027, 10, 31, 0, 30),
    );
    expect(
      early.releaseAt(DateTime.utc(2027, 10, 31, 1, 5), london),
      DateTime.utc(2027, 10, 31, 1, 30),
    );
    // Quiet hours the clocks jump into continue past the change.
    final dawn = QuietHours(ClockTime(1, 15), ClockTime(3, 0));
    expect(
      dawn.releaseAt(DateTime.utc(2027, 3, 28, 1), london),
      DateTime.utc(2027, 3, 28, 2),
    );
  });

  test('compare and print', () {
    expect(night, QuietHours(ClockTime(22, 0), ClockTime(7, 0)));
    expect(night, isNot(lunch));
    expect(night.hashCode, QuietHours(night.start, night.end).hashCode);
    expect('$night', '22:00–07:00');
  });
}
