import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  const rent = Money.fromRupees(45000);
  final nov = MonthPeriod(2026, 11);

  group('dueDate', () {
    test('clamps to month length', () {
      expect(RentMath.dueDate(nov, 5), CalendarDate(2026, 11, 5));
      expect(
        RentMath.dueDate(MonthPeriod(2026, 2), 31),
        CalendarDate(2026, 2, 28),
      );
      expect(
        RentMath.dueDate(MonthPeriod(2028, 2), 30),
        CalendarDate(2028, 2, 29),
      );
      expect(() => RentMath.dueDate(nov, 0), throwsArgumentError);
      expect(() => RentMath.dueDate(nov, 32), throwsArgumentError);
    });
  });

  group('billingDueDate', () {
    test('never before the billing start', () {
      expect(
        RentMath.billingDueDate(
          MonthPeriod(2026, 9),
          5,
          CalendarDate(2026, 9, 15),
        ),
        CalendarDate(2026, 9, 15),
      );
      expect(
        RentMath.billingDueDate(
          MonthPeriod(2026, 10),
          5,
          CalendarDate(2026, 9, 15),
        ),
        CalendarDate(2026, 10, 5),
      );
    });
  });

  group('proratedRent', () {
    test('full month returns the rent unchanged', () {
      expect(
        RentMath.proratedRent(
          monthlyRent: rent,
          period: nov,
          occupancy: DateRange(CalendarDate(2026, 10, 1)),
        ),
        rent,
      );
    });

    test('mid-month move-in is prorated and rounded half-up to rupees', () {
      // 16 of 30 days: 45,000 × 16 / 30 = 24,000.
      expect(
        RentMath.proratedRent(
          monthlyRent: rent,
          period: nov,
          occupancy: DateRange(CalendarDate(2026, 11, 15)),
        ),
        const Money.fromRupees(24000),
      );
      // 1 day of 31: 10,001 / 31 = 322.61 → 323.
      expect(
        RentMath.proratedRent(
          monthlyRent: const Money.fromRupees(10001),
          period: MonthPeriod(2026, 12),
          occupancy: DateRange(CalendarDate(2026, 12, 31)),
        ),
        const Money.fromRupees(323),
      );
    });

    test('move-out and no-overlap cases', () {
      expect(
        RentMath.proratedRent(
          monthlyRent: rent,
          period: nov,
          occupancy: DateRange(
            CalendarDate(2026, 1, 1),
            CalendarDate(2026, 11, 10),
          ),
        ),
        const Money.fromRupees(15000),
      );
      expect(
        RentMath.proratedRent(
          monthlyRent: rent,
          period: nov,
          occupancy: DateRange(CalendarDate(2027, 1, 1)),
        ),
        Money.zero,
      );
      expect(
        RentMath.occupiedDays(
          MonthPeriod(2028, 2),
          DateRange(CalendarDate(2028, 2, 20)),
        ),
        10,
      );
    });
  });

  group('incrementedRent', () {
    test('10% default rounded to nearest Rs 100', () {
      expect(
        RentMath.incrementedRent(rent, basisPoints: 1000),
        const Money.fromRupees(49500),
      );
      expect(
        RentMath.incrementedRent(
          const Money.fromRupees(47300),
          basisPoints: 1000,
        ),
        const Money.fromRupees(52000),
      );
    });

    test('other rounding steps and zero increment', () {
      const base = Money.fromRupees(47300);
      expect(
        RentMath.incrementedRent(
          base,
          basisPoints: 1000,
          rounding: RentRounding.none,
        ),
        const Money.fromRupees(52030),
      );
      expect(
        RentMath.incrementedRent(
          base,
          basisPoints: 1000,
          rounding: RentRounding.nearest500,
        ),
        const Money.fromRupees(52000),
      );
      expect(
        RentMath.incrementedRent(
          base,
          basisPoints: 1000,
          rounding: RentRounding.nearest1000,
        ),
        const Money.fromRupees(52000),
      );
      expect(
        RentMath.incrementedRent(
          base,
          basisPoints: 1000,
          rounding: RentRounding.nearest10,
        ),
        const Money.fromRupees(52030),
      );
      expect(
        RentMath.incrementedRent(
          base,
          basisPoints: 1000,
          rounding: RentRounding.nearest50,
        ),
        const Money.fromRupees(52050),
      );
      expect(RentMath.incrementedRent(base, basisPoints: 0), base);
      expect(
        () => RentMath.incrementedRent(base, basisPoints: -1),
        throwsArgumentError,
      );
      expect(RentRounding.values.map((r) => r.stepRupees), [
        1,
        10,
        50,
        100,
        500,
        1000,
      ]);
    });
  });

  group('nextAnniversary', () {
    final start = CalendarDate(2025, 3, 15);

    test('before the first anniversary', () {
      expect(
        RentMath.nextAnniversary(start, CalendarDate(2025, 1, 1)),
        CalendarDate(2026, 3, 15),
      );
      expect(RentMath.nextAnniversary(start, start), CalendarDate(2026, 3, 15));
      expect(
        RentMath.nextAnniversary(start, CalendarDate(2025, 12, 1)),
        CalendarDate(2026, 3, 15),
      );
    });

    test('on and after anniversaries', () {
      expect(
        RentMath.nextAnniversary(start, CalendarDate(2026, 3, 15)),
        CalendarDate(2026, 3, 15),
      );
      expect(
        RentMath.nextAnniversary(start, CalendarDate(2026, 3, 16)),
        CalendarDate(2027, 3, 15),
      );
      expect(
        RentMath.nextAnniversary(start, CalendarDate(2030, 1, 1)),
        CalendarDate(2030, 3, 15),
      );
    });

    test('11-month cycles and leap-day starts', () {
      expect(
        RentMath.nextAnniversary(
          start,
          CalendarDate(2026, 3, 1),
          intervalMonths: 11,
        ),
        CalendarDate(2027, 1, 15),
      );
      expect(
        RentMath.nextAnniversary(
          CalendarDate(2024, 2, 29),
          CalendarDate(2025, 1, 1),
        ),
        CalendarDate(2025, 2, 28),
      );
      expect(
        () => RentMath.nextAnniversary(start, start, intervalMonths: 0),
        throwsArgumentError,
      );
    });
  });

  group('billablePeriods', () {
    test('from start month through until, clipped to end', () {
      expect(
        RentMath.billablePeriods(
          start: CalendarDate(2026, 9, 15),
          until: CalendarDate(2026, 11, 3),
        ),
        [MonthPeriod(2026, 9), MonthPeriod(2026, 10), MonthPeriod(2026, 11)],
      );
      expect(
        RentMath.billablePeriods(
          start: CalendarDate(2026, 9, 15),
          until: CalendarDate(2027, 3, 1),
          end: CalendarDate(2026, 10, 10),
        ),
        [MonthPeriod(2026, 9), MonthPeriod(2026, 10)],
      );
      expect(
        RentMath.billablePeriods(
          start: CalendarDate(2027, 1, 1),
          until: CalendarDate(2026, 11, 3),
        ),
        isEmpty,
      );
    });
  });
}
