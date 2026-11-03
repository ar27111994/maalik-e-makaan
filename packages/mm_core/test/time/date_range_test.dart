import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final nov1 = CalendarDate(2026, 11, 1);
  final nov15 = CalendarDate(2026, 11, 15);
  final nov30 = CalendarDate(2026, 11, 30);
  final dec10 = CalendarDate(2026, 12, 10);

  test('validation and basics', () {
    expect(() => DateRange(nov15, nov1), throwsArgumentError);
    final single = DateRange(nov1, nov1);
    expect(single.lengthInDays, 1);
    expect(DateRange(nov1).isOpenEnded, isTrue);
    expect(DateRange(nov1).lengthInDays, isNull);
    expect(DateRange(nov1, nov30).lengthInDays, 30);
  });

  test('contains', () {
    expect(DateRange(nov1, nov30).contains(nov15), isTrue);
    expect(DateRange(nov1, nov30).contains(dec10), isFalse);
    expect(DateRange(nov15).contains(dec10), isTrue);
    expect(DateRange(nov15).contains(nov1), isFalse);
  });

  test('overlaps is inclusive of shared boundary days', () {
    expect(DateRange(nov1, nov15).overlaps(DateRange(nov15, nov30)), isTrue);
    expect(DateRange(nov1, nov15).overlaps(DateRange(nov30, dec10)), isFalse);
    expect(DateRange(nov1).overlaps(DateRange(dec10, dec10)), isTrue);
    expect(DateRange(dec10, dec10).overlaps(DateRange(nov1)), isTrue);
    expect(DateRange(nov1, nov15).overlaps(DateRange(nov30)), isFalse);
  });

  test('intersection', () {
    expect(
      DateRange(nov1, nov30).intersection(DateRange(nov15, dec10)),
      DateRange(nov15, nov30),
    );
    expect(
      DateRange(nov1).intersection(DateRange(nov15, dec10)),
      DateRange(nov15, dec10),
    );
    expect(
      DateRange(nov15, dec10).intersection(DateRange(nov1)),
      DateRange(nov15, dec10),
    );
    expect(DateRange(nov1).intersection(DateRange(nov15)), DateRange(nov15));
    expect(DateRange(nov1, nov15).intersection(DateRange(nov30)), isNull);
  });

  test('equality and text', () {
    expect(DateRange(nov1, nov30), DateRange(nov1, nov30));
    expect(DateRange(nov1, nov30).hashCode, DateRange(nov1, nov30).hashCode);
    expect(DateRange(nov1) == Object(), isFalse);
    expect('${DateRange(nov1)}', '[2026-11-01 .. ∞]');
    expect('${DateRange(nov1, nov30)}', '[2026-11-01 .. 2026-11-30]');
  });
}
