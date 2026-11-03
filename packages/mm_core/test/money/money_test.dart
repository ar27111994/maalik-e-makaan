import 'dart:math';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money construction', () {
    test('fromRupees and fromPaisa agree', () {
      expect(const Money.fromRupees(1500), const Money.fromPaisa(150000));
      expect(Money.zero.isZero, isTrue);
    });

    test('exposes whole rupees and paisa component for negatives', () {
      const amount = Money.fromPaisa(-150025);
      expect(amount.wholeRupees, -1500);
      expect(amount.paisaComponent, 25);
      expect(amount.isNegative, isTrue);
      expect(amount.hasPaisa, isTrue);
    });

    test('storage range mirrors numeric(14,2)', () {
      expect(Money.maxValue.toDecimalString(), '999999999999.99');
      expect(Money.minValue.toDecimalString(), '-999999999999.99');
      expect(Money.maxValue.isWithinStorageRange, isTrue);
      expect(
        const Money.fromPaisa(99999999999999 + 1).isWithinStorageRange,
        isFalse,
      );
      expect(
        const Money.fromPaisa(-99999999999999 - 1).isWithinStorageRange,
        isFalse,
      );
    });
  });

  group('Money.parseDecimal / tryParseDecimal', () {
    test('parses whole, one- and two-decimal values', () {
      expect(Money.parseDecimal('1500').paisa, 150000);
      expect(Money.parseDecimal('1500.5').paisa, 150050);
      expect(Money.parseDecimal('1500.05').paisa, 150005);
      expect(Money.parseDecimal('-20.75').paisa, -2075);
      expect(Money.parseDecimal('+3').paisa, 300);
      expect(Money.parseDecimal('0').isZero, isTrue);
    });

    test('rejects malformed input', () {
      for (final bad in [
        '',
        ' ',
        '1,500',
        '1.234',
        '.5',
        '5.',
        'abc',
        '1e3',
        '--1',
        '١٢',
        '1000000000000',
      ]) {
        expect(Money.tryParseDecimal(bad), isNull, reason: bad);
      }
      expect(() => Money.parseDecimal('x'), throwsFormatException);
    });
  });

  group('Money.fromJson / toJson', () {
    test('accepts ints, doubles and numeric strings', () {
      expect(Money.fromJson(1500), const Money.fromRupees(1500));
      expect(Money.fromJson(1500.0), const Money.fromRupees(1500));
      expect(Money.fromJson(0.29), const Money.fromPaisa(29));
      expect(Money.fromJson(1234.56), const Money.fromPaisa(123456));
      expect(Money.fromJson(-12.5), const Money.fromPaisa(-1250));
      expect(Money.fromJson(' 99.99 '), const Money.fromPaisa(9999));
    });

    test('rejects null, non-finite and other types', () {
      expect(() => Money.fromJson(null), throwsFormatException);
      expect(() => Money.fromJson(double.nan), throwsFormatException);
      expect(() => Money.fromJson(double.infinity), throwsFormatException);
      expect(() => Money.fromJson(true), throwsFormatException);
      expect(() => Money.fromJson('12.345'), throwsFormatException);
    });

    test('round-trips through the exact decimal string', () {
      const amount = Money.fromPaisa(-505);
      expect(amount.toJson(), '-5.05');
      expect(Money.fromJson(amount.toJson()), amount);
    });
  });

  group('arithmetic and comparison', () {
    const a = Money.fromRupees(100);
    const b = Money.fromPaisa(2550);

    test('operators', () {
      expect((a + b).paisa, 12550);
      expect((a - b).paisa, 7450);
      expect((-a).paisa, -10000);
      expect((-a).abs(), a);
      expect(a > b && b < a && a >= a && a <= a, isTrue);
      expect(a.compareTo(b), greaterThan(0));
      expect(Money.min(a, b), b);
      expect(Money.max(a, b), a);
      expect(Money.sum([a, b, b]).paisa, 15100);
      expect(Money.sum(const []), Money.zero);
    });

    test('clamp', () {
      expect(
        const Money.fromRupees(5).clamp(Money.zero, a),
        const Money.fromRupees(5),
      );
      expect(const Money.fromRupees(500).clamp(Money.zero, a), a);
      expect(const Money.fromRupees(-5).clamp(Money.zero, a), Money.zero);
      expect(() => a.clamp(a, Money.zero), throwsArgumentError);
    });

    test('equality, hashCode and toString', () {
      expect(const Money.fromPaisa(10), const Money.fromPaisa(10));
      expect(
        const Money.fromPaisa(10).hashCode,
        const Money.fromPaisa(10).hashCode,
      );
      expect(const Money.fromPaisa(10) == Object(), isFalse);
      expect(const Money.fromPaisa(150005).toString(), 'Money(1500.05 PKR)');
    });
  });

  group('rounding modes', () {
    // Each case: paisa, numerator, denominator, expected per mode.
    Money m(int paisa) => Money.fromPaisa(paisa);

    test('halfUp rounds ties away from zero', () {
      expect(m(5).multiply(1, 2).paisa, 3);
      expect(m(-5).multiply(1, 2).paisa, -3);
      expect(m(4).multiply(1, 3).paisa, 1);
    });

    test('halfEven rounds ties to the even neighbour', () {
      expect(m(5).multiply(1, 2, RoundingMode.halfEven).paisa, 2);
      expect(m(7).multiply(1, 2, RoundingMode.halfEven).paisa, 4);
      expect(m(-5).multiply(1, 2, RoundingMode.halfEven).paisa, -2);
      expect(m(11).multiply(1, 4, RoundingMode.halfEven).paisa, 3);
      expect(m(9).multiply(1, 4, RoundingMode.halfEven).paisa, 2);
    });

    test('directional modes', () {
      expect(m(7).multiply(1, 2, RoundingMode.down).paisa, 3);
      expect(m(-7).multiply(1, 2, RoundingMode.down).paisa, -3);
      expect(m(7).multiply(1, 2, RoundingMode.up).paisa, 4);
      expect(m(-7).multiply(1, 2, RoundingMode.up).paisa, -4);
      expect(m(7).multiply(1, 2, RoundingMode.floor).paisa, 3);
      expect(m(-7).multiply(1, 2, RoundingMode.floor).paisa, -4);
      expect(m(7).multiply(1, 2, RoundingMode.ceiling).paisa, 4);
      expect(m(-7).multiply(1, 2, RoundingMode.ceiling).paisa, -3);
    });

    test('negative denominators and exact results', () {
      expect(m(10).multiply(1, -2).paisa, -5);
      expect(m(10).multiply(3).paisa, 30);
      expect(() => m(10).multiply(1, 0), throwsArgumentError);
    });

    test('percentage uses basis points', () {
      expect(
        const Money.fromRupees(45000).percentage(1000),
        const Money.fromRupees(4500),
      );
      expect(const Money.fromRupees(333).percentage(250).paisa, 833);
    });

    test('roundToStep and roundToRupee', () {
      expect(
        const Money.fromRupees(52030).roundToStep(100),
        const Money.fromRupees(52000),
      );
      expect(
        const Money.fromRupees(52050).roundToStep(100),
        const Money.fromRupees(52100),
      );
      expect(
        const Money.fromRupees(52050)
            .roundToStep(100, mode: RoundingMode.halfEven),
        const Money.fromRupees(52000),
      );
      expect(
        const Money.fromPaisa(150050).roundToRupee(),
        const Money.fromRupees(1501),
      );
      expect(
        const Money.fromPaisa(-150050).roundToRupee(),
        const Money.fromRupees(-1501),
      );
      expect(() => Money.zero.roundToStep(0), throwsArgumentError);
    });

    test('large values stay exact (BigInt path)', () {
      // 999,999,999,999.99 * 9999 / 10000 would overflow 2^63 without BigInt.
      final result = Money.maxValue.multiply(9999, 10000);
      expect(result.paisa, 99989999999999); // 999,899,999,999.99 rounded
    });
  });

  group('allocate / splitEvenly', () {
    test('largest remainder keeps every paisa', () {
      final parts = const Money.fromPaisa(100).allocate([1, 1, 1]);
      expect(parts.map((p) => p.paisa), [34, 33, 33]);
      expect(Money.sum(parts), const Money.fromPaisa(100));
    });

    test('respects ratios and negative totals', () {
      final parts = const Money.fromPaisa(-1000).allocate([1, 3]);
      expect(parts.map((p) => p.paisa), [-250, -750]);
      expect(const Money.fromPaisa(10).allocate([0, 1]).map((p) => p.paisa), [
        0,
        10,
      ]);
    });

    test('ties go to the earliest index', () {
      expect(const Money.fromPaisa(1).allocate([1, 1]).map((p) => p.paisa), [
        1,
        0,
      ]);
    });

    test('rejects invalid ratios', () {
      expect(() => Money.zero.allocate(const []), throwsArgumentError);
      expect(() => Money.zero.allocate(const [-1, 2]), throwsArgumentError);
      expect(() => Money.zero.allocate(const [0, 0]), throwsArgumentError);
      expect(() => Money.zero.splitEvenly(0), throwsArgumentError);
    });

    test('property: parts always sum to the whole (seeded)', () {
      final random = Random(20261103);
      for (var i = 0; i < 2000; i++) {
        final total = Money.fromPaisa(random.nextInt(1 << 31) - (1 << 30));
        final ratios = List<int>.generate(
          1 + random.nextInt(8),
          (_) => random.nextInt(50),
        );
        if (ratios.every((r) => r == 0)) ratios[0] = 1;
        final parts = total.allocate(ratios);
        expect(Money.sum(parts), total);
        for (var p = 0; p < parts.length; p++) {
          if (ratios[p] == 0) expect(parts[p], Money.zero);
        }
      }
      final even = const Money.fromRupees(1000).splitEvenly(3);
      expect(even.map((p) => p.paisa), [33334, 33333, 33333]);
    });

    test('property: multiply matches exact rational rounding (seeded)', () {
      final random = Random(42);
      for (var i = 0; i < 2000; i++) {
        final paisa = random.nextInt(1 << 30) - (1 << 29);
        final numerator = random.nextInt(20000);
        final denominator = 1 + random.nextInt(10000);
        final exact = BigInt.from(paisa) * BigInt.from(numerator);
        final floor =
            (exact.isNegative
                ? (exact - BigInt.from(denominator - 1))
                : exact) ~/
            BigInt.from(denominator);
        final result = Money.fromPaisa(paisa)
            .multiply(numerator, denominator)
            .paisa;
        // halfUp result is always floor or floor + 1 of the exact quotient.
        expect(result - floor.toInt(), inInclusiveRange(0, 1));
      }
    });
  });
}
