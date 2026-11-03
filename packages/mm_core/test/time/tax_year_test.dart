import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  test('tax year N runs 1 July (N-1) to 30 June N', () {
    final ty = TaxYear(2026);
    expect(ty.start, CalendarDate(2025, 7, 1));
    expect(ty.end, CalendarDate(2026, 6, 30));
    expect(ty.label, 'TY2026');
    expect(ty.spanLabel, '2025-26');
    expect(TaxYear(2101).spanLabel, '2100-01');
  });

  test('containing() assigns dates on both sides of the boundary', () {
    expect(TaxYear.containing(CalendarDate(2026, 6, 30)), TaxYear(2026));
    expect(TaxYear.containing(CalendarDate(2026, 7, 1)), TaxYear(2027));
    // Today (3 Nov 2026) falls in TY2027.
    expect(TaxYear.containing(CalendarDate(2026, 11, 3)), TaxYear(2027));
  });

  test('months, contains and navigation', () {
    final ty = TaxYear(2027);
    expect(ty.months.length, 12);
    expect(ty.months.first, MonthPeriod(2026, 7));
    expect(ty.months.last, MonthPeriod(2027, 6));
    expect(ty.contains(CalendarDate(2026, 7, 1)), isTrue);
    expect(ty.contains(CalendarDate(2027, 7, 1)), isFalse);
    expect(ty.contains(CalendarDate(2026, 6, 30)), isFalse);
    expect(ty.next, TaxYear(2028));
    expect(ty.previous, TaxYear(2026));
    expect(ty.compareTo(TaxYear(2028)), lessThan(0));
    expect(ty.hashCode, TaxYear(2027).hashCode);
    expect(ty == Object(), isFalse);
    expect('$ty', 'TY2027');
    expect(() => TaxYear(1), throwsArgumentError);
  });
}
