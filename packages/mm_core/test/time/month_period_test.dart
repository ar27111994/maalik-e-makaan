import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  test('construction, parsing and validation', () {
    expect(MonthPeriod.parse('2026-11'), MonthPeriod(2026, 11));
    expect(MonthPeriod.parse('2026-11-15'), MonthPeriod(2026, 11));
    expect(() => MonthPeriod.parse('2026-13'), throwsFormatException);
    expect(() => MonthPeriod.parse('2026/11'), throwsFormatException);
    expect(() => MonthPeriod(2026, 0), throwsArgumentError);
    expect(() => MonthPeriod(0, 5), throwsArgumentError);
    expect(MonthPeriod.of(CalendarDate(2026, 2, 14)), MonthPeriod(2026, 2));
  });

  test('bounds and length', () {
    final feb = MonthPeriod(2028, 2);
    expect(feb.first, CalendarDate(2028, 2, 1));
    expect(feb.last, CalendarDate(2028, 2, 29));
    expect(feb.lengthInDays, 29);
    expect(feb.contains(CalendarDate(2028, 2, 29)), isTrue);
    expect(feb.contains(CalendarDate(2028, 3, 1)), isFalse);
    expect(feb.dayClamped(31), CalendarDate(2028, 2, 29));
    expect(feb.dayClamped(0), CalendarDate(2028, 2, 1));
  });

  test('navigation and distance', () {
    expect(MonthPeriod(2026, 12).next, MonthPeriod(2027, 1));
    expect(MonthPeriod(2026, 1).previous, MonthPeriod(2025, 12));
    expect(MonthPeriod(2026, 11).addMonths(-23), MonthPeriod(2024, 12));
    expect(MonthPeriod(2027, 2).monthsSince(MonthPeriod(2026, 11)), 3);
    expect(MonthPeriod(2026, 11).monthsSince(MonthPeriod(2027, 2)), -3);
  });

  test('range', () {
    expect(MonthPeriod.range(MonthPeriod(2026, 11), MonthPeriod(2027, 2)), [
      MonthPeriod(2026, 11),
      MonthPeriod(2026, 12),
      MonthPeriod(2027, 1),
      MonthPeriod(2027, 2),
    ]);
    expect(
      MonthPeriod.range(MonthPeriod(2027, 2), MonthPeriod(2026, 11)),
      isEmpty,
    );
  });

  test('ordering, equality and text', () {
    expect(MonthPeriod(2026, 11).compareTo(MonthPeriod(2027, 1)), lessThan(0));
    expect(
      MonthPeriod(2026, 11).compareTo(MonthPeriod(2026, 2)),
      greaterThan(0),
    );
    expect(MonthPeriod(2026, 11).hashCode, MonthPeriod(2026, 11).hashCode);
    expect(MonthPeriod(2026, 11) == Object(), isFalse);
    expect(MonthPeriod(2026, 3).toIso(), '2026-03');
    expect('${MonthPeriod(2026, 3)}', '2026-03');
  });
}
