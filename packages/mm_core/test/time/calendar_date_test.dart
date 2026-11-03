import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarDate construction & parsing', () {
    test('validates components', () {
      expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
      expect(() => CalendarDate(2026, 13, 1), throwsArgumentError);
      expect(() => CalendarDate(2026, 0, 1), throwsArgumentError);
      expect(() => CalendarDate(0, 1, 1), throwsArgumentError);
      expect(() => CalendarDate(10000, 1, 1), throwsArgumentError);
      expect(() => CalendarDate(2026, 4, 31), throwsArgumentError);
      expect(CalendarDate(2024, 2, 29).day, 29);
    });

    test('parses strict ISO dates only', () {
      expect(CalendarDate.parse('2026-11-03'), CalendarDate(2026, 11, 3));
      expect(CalendarDate.tryParse(' 2026-01-31 '), CalendarDate(2026, 1, 31));
      for (final bad in [
        '2026-02-30',
        '2026-13-01',
        '2026-00-10',
        '26-11-03',
        '2026/11/03',
        '2026-11-3',
        '2026-11-03T00:00:00',
        '',
        '0000-01-01',
      ]) {
        expect(CalendarDate.tryParse(bad), isNull, reason: bad);
      }
      expect(() => CalendarDate.parse('nope'), throwsFormatException);
    });

    test('JSON round-trip', () {
      final date = CalendarDate(2026, 7, 1);
      expect(date.toJson(), '2026-07-01');
      expect(CalendarDate.fromJson('2026-07-01'), date);
      expect(() => CalendarDate.fromJson(20260701), throwsFormatException);
      expect(CalendarDate(987, 3, 4).toIso(), '0987-03-04');
    });

    test('fromDateTime uses the given fields', () {
      expect(
        CalendarDate.fromDateTime(DateTime(2026, 11, 3, 23, 59)),
        CalendarDate(2026, 11, 3),
      );
    });
  });

  group('todayInPakistan', () {
    test('uses PKT (UTC+5) regardless of device zone', () {
      // 19:30 UTC on 3 Nov is 00:30 on 4 Nov in Pakistan.
      expect(
        CalendarDate.todayInPakistan(now: DateTime.utc(2026, 11, 3, 19, 30)),
        CalendarDate(2026, 11, 4),
      );
      expect(
        CalendarDate.todayInPakistan(now: DateTime.utc(2026, 11, 3, 18, 59)),
        CalendarDate(2026, 11, 3),
      );
      expect(CalendarDate.todayInPakistan(), isA<CalendarDate>());
    });
  });

  group('calendar maths', () {
    test('leap years and month lengths', () {
      expect(CalendarDate.isLeapYear(2024), isTrue);
      expect(CalendarDate.isLeapYear(2100), isFalse);
      expect(CalendarDate.isLeapYear(2000), isTrue);
      expect(CalendarDate.daysInMonth(2026, 2), 28);
      expect(CalendarDate.daysInMonth(2028, 2), 29);
      expect(CalendarDate.daysInMonth(2026, 4), 30);
      expect(CalendarDate(2026, 4, 30).isLastDayOfMonth, isTrue);
      expect(CalendarDate(2026, 4, 30).lengthOfMonth, 30);
    });

    test('addDays crosses months and years', () {
      expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
      expect(CalendarDate(2026, 3, 1).addDays(-1), CalendarDate(2026, 2, 28));
      expect(CalendarDate(2026, 1, 1).addDays(365), CalendarDate(2027, 1, 1));
    });

    test('addMonths clamps to month length', () {
      expect(CalendarDate(2026, 1, 31).addMonths(1), CalendarDate(2026, 2, 28));
      expect(CalendarDate(2028, 1, 31).addMonths(1), CalendarDate(2028, 2, 29));
      expect(
        CalendarDate(2026, 3, 31).addMonths(-1),
        CalendarDate(2026, 2, 28),
      );
      expect(
        CalendarDate(2026, 11, 15).addMonths(14),
        CalendarDate(2028, 1, 15),
      );
      expect(
        CalendarDate(2026, 1, 15).addMonths(-13),
        CalendarDate(2024, 12, 15),
      );
      expect(CalendarDate(2024, 2, 29).addYears(1), CalendarDate(2025, 2, 28));
    });

    test('differences, ordering and helpers', () {
      final a = CalendarDate(2026, 11, 3);
      final b = CalendarDate(2026, 12, 3);
      expect(b.differenceInDays(a), 30);
      expect(a.differenceInDays(b), -30);
      expect(a.isBefore(b) && b.isAfter(a), isTrue);
      expect(a.isOnOrBefore(a) && a.isOnOrAfter(a), isTrue);
      expect(CalendarDate.min(a, b), a);
      expect(CalendarDate.max(a, b), b);
      expect(a.weekday, DateTime.tuesday);
      expect(CalendarDate(2026, 1, 1).dayOfYear, 1);
      expect(CalendarDate(2024, 12, 31).dayOfYear, 366);
      expect(a.toDateTimeUtc(), DateTime.utc(2026, 11, 3));
      expect(a.compareTo(CalendarDate(2026, 11, 4)), lessThan(0));
      expect(a.compareTo(CalendarDate(2027, 1, 1)), lessThan(0));
      expect(a.compareTo(CalendarDate(2026, 10, 30)), greaterThan(0));
      expect(a.hashCode, CalendarDate(2026, 11, 3).hashCode);
      expect(a == Object(), isFalse);
      expect('$a', '2026-11-03');
    });
  });
}
