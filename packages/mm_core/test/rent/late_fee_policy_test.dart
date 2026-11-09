import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  const overdue = Money.fromRupees(40000);

  group('fromColumns decodes database values', () {
    test('every type', () {
      expect(LateFeePolicy.fromColumns(type: 'none'), const NoLateFee());
      expect(
        LateFeePolicy.fromColumns(type: 'flat', value: 500),
        const FlatLateFee(Money.fromRupees(500)),
      );
      expect(
        LateFeePolicy.fromColumns(type: 'percent', value: '2.5'),
        const PercentLateFee(250),
      );
      expect(
        LateFeePolicy.fromColumns(type: 'daily', value: 100, cap: '1500.00'),
        const DailyLateFee(Money.fromRupees(100), cap: Money.fromRupees(1500)),
      );
      expect(
        LateFeePolicy.fromColumns(type: 'daily', value: 100),
        const DailyLateFee(Money.fromRupees(100)),
      );
    });

    test('rejects unknown types and missing or negative values', () {
      expect(
        () => LateFeePolicy.fromColumns(type: 'weekly'),
        throwsArgumentError,
      );
      expect(
        () => LateFeePolicy.fromColumns(type: 'flat'),
        throwsArgumentError,
      );
      expect(
        () => LateFeePolicy.fromColumns(type: 'flat', value: -5),
        throwsArgumentError,
      );
      expect(
        () => LateFeePolicy.fromColumns(type: 'percent'),
        throwsArgumentError,
      );
      expect(
        () => LateFeePolicy.fromColumns(type: 'daily'),
        throwsArgumentError,
      );
    });
  });

  group('feeFor', () {
    test('no fee within grace or when nothing is owed', () {
      const flat = FlatLateFee(Money.fromRupees(500));
      expect(
        flat.feeFor(overdueAmount: overdue, daysLate: 5, graceDays: 5),
        Money.zero,
      );
      expect(
        flat.feeFor(overdueAmount: Money.zero, daysLate: 30, graceDays: 0),
        Money.zero,
      );
      expect(
        () => flat.feeFor(overdueAmount: overdue, daysLate: 1, graceDays: -1),
        throwsArgumentError,
      );
    });

    test('policy-specific amounts, rounded to rupees', () {
      expect(
        const NoLateFee().feeFor(
          overdueAmount: overdue,
          daysLate: 99,
          graceDays: 0,
        ),
        Money.zero,
      );
      expect(
        const FlatLateFee(Money.fromRupees(500))
            .feeFor(overdueAmount: overdue, daysLate: 6, graceDays: 5),
        const Money.fromRupees(500),
      );
      expect(
        const PercentLateFee(250)
            .feeFor(overdueAmount: overdue, daysLate: 6, graceDays: 5),
        const Money.fromRupees(1000),
      );
      expect(
        const PercentLateFee(333).feeFor(
          overdueAmount: const Money.fromRupees(1001),
          daysLate: 6,
          graceDays: 5,
        ),
        const Money.fromRupees(33),
      );
      expect(
        const DailyLateFee(Money.fromRupees(100))
            .feeFor(overdueAmount: overdue, daysLate: 12, graceDays: 5),
        const Money.fromRupees(1200),
      );
      expect(
        const DailyLateFee(
          Money.fromRupees(100),
          cap: Money.fromRupees(1000),
        ).feeFor(overdueAmount: overdue, daysLate: 12, graceDays: 5),
        const Money.fromRupees(1000),
      );
    });

    test('a capped fee is rounded first, so it never exceeds its cap', () {
      // 33.35 × 3 = 100.05 rounds to 100, above the 99.50 cap: 99.50.
      expect(
        DailyLateFee(
          Money.parseDecimal('33.35'),
          cap: Money.parseDecimal('99.50'),
        ).feeFor(overdueAmount: overdue, daysLate: 3, graceDays: 0),
        Money.parseDecimal('99.50'),
      );
    });

    test('fees never exceed what a charge can hold', () {
      const crore = Money.fromRupees(10000000);
      expect(
        const DailyLateFee(crore)
            .feeFor(overdueAmount: overdue, daysLate: 200000, graceDays: 5),
        LateFeePolicy.maxFee,
      );
      expect(
        const DailyLateFee(
          crore,
          cap: Money.fromRupees(5000),
        ).feeFor(overdueAmount: overdue, daysLate: 200000, graceDays: 5),
        const Money.fromRupees(5000),
      );
      expect(LateFeePolicy.maxFee.isWithinStorageRange, isTrue);
    });

    test('type names and value semantics', () {
      expect(const NoLateFee().type, 'none');
      expect(const FlatLateFee(Money.zero).type, 'flat');
      expect(const PercentLateFee(0).type, 'percent');
      expect(const DailyLateFee(Money.zero).type, 'daily');
      expect(const NoLateFee().hashCode, const NoLateFee().hashCode);
      expect(
        const FlatLateFee(Money.zero).hashCode,
        const FlatLateFee(Money.zero).hashCode,
      );
      expect(
        const PercentLateFee(5).hashCode,
        const PercentLateFee(5).hashCode,
      );
      expect(
        const DailyLateFee(Money.zero).hashCode,
        const DailyLateFee(Money.zero).hashCode,
      );
      expect(const PercentLateFee(5) == const PercentLateFee(6), isFalse);
    });
  });
}
