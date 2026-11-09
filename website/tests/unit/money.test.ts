// Ports of packages/mm_core/test/money/{money,divide_rounded,basis_points}_test.dart.
import fc from "fast-check";
import { describe, expect, test } from "vitest";
import {
  Money,
  RENT_ROUNDING,
  basisPointsFromPercent,
  divideRounded,
  percentFromBasisPoints,
  type RoundingMode,
} from "../../src/lib/money/index.ts";
import { RUNS, nonNegativeAmount, paisaIn, storedAmount } from "./arbitraries.ts";

const m = (paisa: number) => Money.fromPaisa(paisa);

describe("Money construction", () => {
  test("fromRupees and fromPaisa agree", () => {
    expect(Money.fromRupees(1500).equals(Money.fromPaisa(150000))).toBe(true);
    expect(Money.ZERO.isZero).toBe(true);
  });

  test("exposes whole rupees and the paisa component for negatives", () => {
    const amount = m(-150025);
    expect(amount.wholeRupees).toBe(-1500n);
    expect(amount.paisaComponent).toBe(25n);
    expect(amount.isNegative).toBe(true);
    expect(amount.hasPaisa).toBe(true);
  });

  test("the storage range mirrors numeric(14,2)", () => {
    expect(Money.MAX_VALUE.toDecimalString()).toBe("999999999999.99");
    expect(Money.MIN_VALUE.toDecimalString()).toBe("-999999999999.99");
    expect(Money.MAX_VALUE.isWithinStorageRange).toBe(true);
    expect(Money.fromPaisa(99_999_999_999_999n + 1n).isWithinStorageRange).toBe(false);
    expect(Money.fromPaisa(-99_999_999_999_999n - 1n).isWithinStorageRange).toBe(false);
  });

  test("numbers must be safe integers: money never passes through floating point", () => {
    expect(() => Money.fromPaisa(1.5)).toThrow(RangeError);
    expect(() => Money.fromRupees(Number.MAX_SAFE_INTEGER + 1)).toThrow(RangeError);
    expect(() => Money.fromPaisa(Number.NaN)).toThrow(RangeError);
  });
});

describe("parseDecimal and tryParseDecimal", () => {
  test("parse whole, one- and two-decimal values", () => {
    expect(Money.parseDecimal("1500").paisa).toBe(150000n);
    expect(Money.parseDecimal("1500.5").paisa).toBe(150050n);
    expect(Money.parseDecimal("1500.05").paisa).toBe(150005n);
    expect(Money.parseDecimal("-20.75").paisa).toBe(-2075n);
    expect(Money.parseDecimal("+3").paisa).toBe(300n);
    expect(Money.parseDecimal("0").isZero).toBe(true);
  });

  test.each(["", " ", "1,500", "1.234", ".5", "5.", "abc", "1e3", "--1", "١٢", "1000000000000"])(
    "reject %j",
    (bad) => {
      expect(Money.tryParseDecimal(bad)).toBeNull();
    },
  );

  test("parseDecimal throws for malformed input", () => {
    expect(() => Money.parseDecimal("x")).toThrow(SyntaxError);
  });
});

describe("fromJson and toJSON", () => {
  test("accept integers, fractional numbers and numeric strings", () => {
    expect(Money.fromJson(1500).equals(Money.fromRupees(1500))).toBe(true);
    expect(Money.fromJson(0.29).paisa).toBe(29n);
    expect(Money.fromJson(1234.56).paisa).toBe(123456n);
    expect(Money.fromJson(-12.5).paisa).toBe(-1250n);
    expect(Money.fromJson(" 99.99 ").paisa).toBe(9999n);
  });

  test("reject null, non-finite numbers and other types", () => {
    for (const bad of [null, Number.NaN, Number.POSITIVE_INFINITY, true, "12.345"]) {
      expect(() => Money.fromJson(bad), String(bad)).toThrow(SyntaxError);
    }
  });

  test("round-trip through the exact decimal string", () => {
    const amount = m(-505);
    expect(JSON.stringify({ amount })).toBe('{"amount":"-5.05"}');
    expect(Money.fromJson(amount.toJSON()).equals(amount)).toBe(true);
  });
});

describe("arithmetic and comparison", () => {
  const a = Money.fromRupees(100);
  const b = m(2550);

  test("operations", () => {
    expect(a.plus(b).paisa).toBe(12550n);
    expect(a.minus(b).paisa).toBe(7450n);
    expect(a.negate().paisa).toBe(-10000n);
    expect(a.negate().abs().equals(a)).toBe(true);
    expect(a.gt(b) && b.lt(a) && a.gte(a) && a.lte(a)).toBe(true);
    expect(a.compareTo(b)).toBe(1);
    expect(Money.min(a, b)).toBe(b);
    expect(Money.max(a, b)).toBe(a);
    expect(Money.sum([a, b, b]).paisa).toBe(15100n);
    expect(Money.sum([]).equals(Money.ZERO)).toBe(true);
  });

  test("clamp", () => {
    expect(Money.fromRupees(5).clamp(Money.ZERO, a).equals(Money.fromRupees(5))).toBe(true);
    expect(Money.fromRupees(500).clamp(Money.ZERO, a)).toBe(a);
    expect(Money.fromRupees(-5).clamp(Money.ZERO, a)).toBe(Money.ZERO);
    expect(() => a.clamp(a, Money.ZERO)).toThrow(RangeError);
  });

  test("equality and toString", () => {
    expect(m(10).equals(m(10))).toBe(true);
    expect(m(10).equals({ paisa: 10n })).toBe(false);
    expect(m(150005).toString()).toBe("Money(1500.05 PKR)");
  });
});

describe("rounding modes", () => {
  test("halfUp rounds ties away from zero", () => {
    expect(m(5).multiply(1, 2).paisa).toBe(3n);
    expect(m(-5).multiply(1, 2).paisa).toBe(-3n);
    expect(m(4).multiply(1, 3).paisa).toBe(1n);
  });

  test("halfEven rounds ties to the even neighbour", () => {
    expect(m(5).multiply(1, 2, "halfEven").paisa).toBe(2n);
    expect(m(7).multiply(1, 2, "halfEven").paisa).toBe(4n);
    expect(m(-5).multiply(1, 2, "halfEven").paisa).toBe(-2n);
    expect(m(11).multiply(1, 4, "halfEven").paisa).toBe(3n);
    expect(m(9).multiply(1, 4, "halfEven").paisa).toBe(2n);
  });

  test("directional modes", () => {
    expect(m(7).multiply(1, 2, "down").paisa).toBe(3n);
    expect(m(-7).multiply(1, 2, "down").paisa).toBe(-3n);
    expect(m(7).multiply(1, 2, "up").paisa).toBe(4n);
    expect(m(-7).multiply(1, 2, "up").paisa).toBe(-4n);
    expect(m(7).multiply(1, 2, "floor").paisa).toBe(3n);
    expect(m(-7).multiply(1, 2, "floor").paisa).toBe(-4n);
    expect(m(7).multiply(1, 2, "ceiling").paisa).toBe(4n);
    expect(m(-7).multiply(1, 2, "ceiling").paisa).toBe(-3n);
  });

  test("negative denominators, exact results and zero denominators", () => {
    expect(m(10).multiply(1, -2).paisa).toBe(-5n);
    expect(m(10).multiply(3).paisa).toBe(30n);
    expect(() => m(10).multiply(1, 0)).toThrow(RangeError);
    expect(() => divideRounded(1n, 0n, "halfUp")).toThrow(RangeError);
  });

  test("percentage uses basis points", () => {
    expect(Money.fromRupees(45000).percentage(1000).equals(Money.fromRupees(4500))).toBe(true);
    expect(Money.fromRupees(333).percentage(250).paisa).toBe(833n);
  });

  test("roundToStep and roundToRupee", () => {
    expect(Money.fromRupees(52030).roundToStep(100).equals(Money.fromRupees(52000))).toBe(true);
    expect(Money.fromRupees(52050).roundToStep(100).equals(Money.fromRupees(52100))).toBe(true);
    expect(
      Money.fromRupees(52050).roundToStep(100, "halfEven").equals(Money.fromRupees(52000)),
    ).toBe(true);
    expect(m(150050).roundToRupee().equals(Money.fromRupees(1501))).toBe(true);
    expect(m(-150050).roundToRupee().equals(Money.fromRupees(-1501))).toBe(true);
    expect(() => Money.ZERO.roundToStep(0)).toThrow(RangeError);
  });

  test("multiplyToStep rounds once, straight to the step", () => {
    // Exact value Rs 12.495: rounding twice would give 12.50 and then 13.
    expect(m(1249500).multiplyToStep(1, 1000).equals(Money.fromRupees(12))).toBe(true);
    expect(m(1249500).multiply(1, 1000).roundToRupee().equals(Money.fromRupees(13))).toBe(true);
    expect(
      Money.fromRupees(47300)
        .multiplyToStep(11000, 10000, { stepRupees: 100 })
        .equals(Money.fromRupees(52000)),
    ).toBe(true);
    expect(
      Money.fromRupees(-15).multiplyToStep(1, 2, { mode: "halfEven" }).equals(Money.fromRupees(-8)),
    ).toBe(true);
    expect(() => Money.ZERO.multiplyToStep(1, 0)).toThrow(RangeError);
    expect(() => Money.ZERO.multiplyToStep(1, 1, { stepRupees: 0 })).toThrow(RangeError);
  });

  test("large values stay exact", () => {
    // 999,999,999,999.99 × 9999 ÷ 10000 is beyond 2^53 paisa before the division.
    expect(Money.MAX_VALUE.multiply(9999, 10000).paisa).toBe(99_989_999_999_999n);
  });

  test("property: halfUp is the floor or floor + 1 of the exact quotient, and the nearest", () => {
    fc.assert(
      fc.property(
        storedAmount,
        fc.bigInt({ min: 0n, max: 20_000n }),
        fc.bigInt({ min: 1n, max: 10_000n }),
        (amount, numerator, denominator) => {
          const exact = amount.paisa * numerator;
          const floor = (exact < 0n ? exact - (denominator - 1n) : exact) / denominator;
          const result = amount.multiply(numerator, denominator).paisa;
          expect(result - floor >= 0n && result - floor <= 1n).toBe(true);
          const error = exact - result * denominator;
          expect((error < 0n ? -error : error) * 2n <= denominator).toBe(true);
        },
      ),
      RUNS,
    );
  });
});

/** The floor-based reference for every rounding mode, independent of rounding.ts. */
function referenceRounding(numerator: bigint, denominator: bigint, mode: RoundingMode): bigint {
  const [n, d] = denominator < 0n ? [-numerator, -denominator] : [numerator, denominator];
  const floor = n >= 0n ? n / d : -((-n + d - 1n) / d);
  const remainder = n - floor * d; // 0 <= remainder < d
  if (remainder === 0n) return floor;
  const ceiling = floor + 1n;
  const towardZero = n >= 0n ? floor : ceiling;
  const awayFromZero = n >= 0n ? ceiling : floor;
  const nearer = remainder * 2n < d ? floor : remainder * 2n > d ? ceiling : null;
  switch (mode) {
    case "floor":
      return floor;
    case "ceiling":
      return ceiling;
    case "down":
      return towardZero;
    case "up":
      return awayFromZero;
    case "halfUp":
      return nearer ?? awayFromZero;
    case "halfEven":
      return nearer ?? (floor % 2n === 0n ? floor : ceiling);
  }
}

const ROUNDING_MODES: readonly RoundingMode[] = [
  "halfUp",
  "halfEven",
  "down",
  "up",
  "floor",
  "ceiling",
];

describe("properties of rounding and scaling", () => {
  test("property: divideRounded agrees with a floor-based reference in every mode", () => {
    fc.assert(
      fc.property(
        fc.bigInt({ min: -(10n ** 20n), max: 10n ** 20n }),
        fc.bigInt({ min: -1_000_000n, max: 1_000_000n }).filter((d) => d !== 0n),
        fc.constantFrom(...ROUNDING_MODES),
        (numerator, denominator, mode) => {
          expect(divideRounded(numerator, denominator, mode)).toBe(
            referenceRounding(numerator, denominator, mode),
          );
        },
      ),
      RUNS,
    );
  });

  test("property: ties are what tell halfUp and halfEven apart", () => {
    // Random pairs are seldom ties, so half the cases are built as q × d ± d ÷ 2 (d even).
    const tie = fc
      .tuple(
        fc.bigInt({ min: -(10n ** 9n), max: 10n ** 9n }),
        fc.bigInt({ min: 1n, max: 500_000n }),
        fc.boolean(),
      )
      .map(([quotient, half, below]): [bigint, bigint] => [
        quotient * 2n * half + (below ? -half : half),
        2n * half,
      ]);
    fc.assert(
      fc.property(
        fc.oneof(
          fc.tuple(
            fc.bigInt({ min: -(10n ** 15n), max: 10n ** 15n }),
            fc.bigInt({ min: 1n, max: 1_000_000n }),
          ),
          tie,
        ),
        ([numerator, denominator]) => {
          const halfUp = divideRounded(numerator, denominator, "halfUp");
          const halfEven = divideRounded(numerator, denominator, "halfEven");
          const isTie =
            (numerator % denominator) * 2n === denominator ||
            (numerator % denominator) * 2n === -denominator;
          if (!isTie) expect(halfEven).toBe(halfUp);
          else expect(halfEven % 2n).toBe(0n);
        },
      ),
      RUNS,
    );
  });

  test("property: multiplyToStep lands on a multiple of the step, within half a step", () => {
    fc.assert(
      fc.property(
        storedAmount,
        fc.bigInt({ min: 0n, max: 20_000n }),
        fc.bigInt({ min: 1n, max: 10_000n }),
        fc.constantFrom(...Object.values(RENT_ROUNDING)),
        (amount, numerator, denominator, stepRupees) => {
          const stepPaisa = BigInt(stepRupees) * 100n;
          const result = amount.multiplyToStep(numerator, denominator, { stepRupees });
          expect(result.paisa % stepPaisa).toBe(0n);
          const error = result.paisa * denominator - amount.paisa * numerator;
          expect((error < 0n ? -error : error) * 2n <= stepPaisa * denominator).toBe(true);
        },
      ),
      RUNS,
    );
  });

  test("property: on amounts of zero or more, a larger ratio never gives less", () => {
    fc.assert(
      fc.property(
        nonNegativeAmount,
        fc.integer({ min: 0, max: 20_000 }),
        fc.integer({ min: 0, max: 20_000 }),
        fc.constantFrom(...Object.values(RENT_ROUNDING)),
        (amount, a, b, stepRupees) => {
          const [low, high] = a <= b ? [a, b] : [b, a];
          expect(amount.percentage(low).lte(amount.percentage(high))).toBe(true);
          expect(
            amount
              .multiplyToStep(low, 10_000, { stepRupees })
              .lte(amount.multiplyToStep(high, 10_000, { stepRupees })),
          ).toBe(true);
        },
      ),
      RUNS,
    );
  });

  test("property: 0% is nothing, 100% is the whole amount, and rounding to a step is idempotent", () => {
    fc.assert(
      fc.property(
        storedAmount,
        fc.constantFrom(...Object.values(RENT_ROUNDING)),
        fc.constantFrom(...ROUNDING_MODES),
        (amount, step, mode) => {
          expect(amount.percentage(0).isZero).toBe(true);
          expect(amount.percentage(10_000).equals(amount)).toBe(true);
          const rounded = amount.roundToStep(step, mode);
          expect(rounded.roundToStep(step, mode).equals(rounded)).toBe(true);
        },
      ),
      RUNS,
    );
  });

  test("property: the exact decimal string and JSON round-trip every stored amount", () => {
    fc.assert(
      fc.property(storedAmount, (amount) => {
        const text = amount.toDecimalString();
        expect(text).toMatch(/^-?\d+\.\d{2}$/);
        expect(Money.parseDecimal(text).equals(amount)).toBe(true);
        const json = JSON.parse(JSON.stringify({ amount })) as { amount: unknown };
        expect(Money.fromJson(json.amount).equals(amount)).toBe(true);
      }),
      RUNS,
    );
  });

  test("property: an amount outside numeric(14,2) does not parse", () => {
    const beyond = Money.MAX_VALUE.paisa + 1n;
    fc.assert(
      fc.property(paisaIn(beyond, beyond * 1000n), fc.boolean(), (amount, negative) => {
        const text = (negative ? amount.negate() : amount).toDecimalString();
        expect(Money.tryParseDecimal(text)).toBeNull();
      }),
      RUNS,
    );
  });
});

describe("allocate and splitEvenly", () => {
  const paisaOf = (parts: Money[]) => parts.map((part) => part.paisa);

  test("the largest remainder keeps every paisa", () => {
    const parts = m(100).allocate([1, 1, 1]);
    expect(paisaOf(parts)).toEqual([34n, 33n, 33n]);
    expect(Money.sum(parts).equals(m(100))).toBe(true);
  });

  test("ratios, negative totals and ties", () => {
    expect(paisaOf(m(-1000).allocate([1, 3]))).toEqual([-250n, -750n]);
    expect(paisaOf(m(10).allocate([0, 1]))).toEqual([0n, 10n]);
    expect(paisaOf(m(1).allocate([1, 1]))).toEqual([1n, 0n]);
  });

  test("invalid ratios are rejected", () => {
    expect(() => Money.ZERO.allocate([])).toThrow(RangeError);
    expect(() => Money.ZERO.allocate([-1, 2])).toThrow(RangeError);
    expect(() => Money.ZERO.allocate([0, 0])).toThrow(RangeError);
    expect(() => Money.ZERO.splitEvenly(0)).toThrow(RangeError);
  });

  test("property: parts sum to the whole, zero ratios get nothing, each part within a paisa", () => {
    fc.assert(
      fc.property(
        storedAmount,
        fc
          .array(fc.integer({ min: 0, max: 50 }), { minLength: 1, maxLength: 8 })
          .filter((ratios) => ratios.some((ratio) => ratio !== 0)),
        (total, ratios) => {
          const parts = total.allocate(ratios);
          expect(parts).toHaveLength(ratios.length);
          expect(Money.sum(parts).equals(total)).toBe(true);
          const weight = BigInt(ratios.reduce((sum, ratio) => sum + ratio, 0));
          ratios.forEach((ratio, index) => {
            const part = parts[index] ?? Money.ZERO;
            if (ratio === 0) expect(part.isZero).toBe(true);
            // |part − total × ratio ÷ weight| < 1 paisa, and the part has the total's sign.
            const error = part.paisa * weight - total.paisa * BigInt(ratio);
            expect((error < 0n ? -error : error) < weight).toBe(true);
            expect(part.isNegative && !total.isNegative).toBe(false);
          });
        },
      ),
      RUNS,
    );
    expect(paisaOf(Money.fromRupees(1000).splitEvenly(3))).toEqual([33334n, 33333n, 33333n]);
  });

  test("property: splitEvenly gives parts a paisa apart at most, the larger ones first", () => {
    fc.assert(
      fc.property(storedAmount, fc.integer({ min: 1, max: 60 }), (total, count) => {
        const parts = total.splitEvenly(count);
        expect(parts).toHaveLength(count);
        expect(Money.sum(parts).equals(total)).toBe(true);
        const magnitudes = parts.map((part) => part.abs().paisa);
        expect(magnitudes).toEqual(magnitudes.toSorted((a, b) => (a > b ? -1 : a < b ? 1 : 0)));
        const [largest = 0n] = magnitudes;
        const smallest = magnitudes.at(-1) ?? 0n;
        expect(largest - smallest <= 1n).toBe(true);
      }),
      RUNS,
    );
  });
});

describe("basis points", () => {
  test("percentages become basis points", () => {
    expect(basisPointsFromPercent(10)).toBe(1000);
    expect(basisPointsFromPercent(2.5)).toBe(250);
    expect(basisPointsFromPercent("12.34")).toBe(1234);
    expect(basisPointsFromPercent(" 100 ")).toBe(10000);
  });

  test.each(["", "abc", "-1", "1.234", "100.01", "1000", null, Number.NaN])("reject %j", (bad) => {
    expect(() => basisPointsFromPercent(bad)).toThrow(SyntaxError);
  });

  test("basis points format as percentages", () => {
    expect(percentFromBasisPoints(1000)).toBe("10");
    expect(percentFromBasisPoints(250)).toBe("2.5");
    expect(percentFromBasisPoints(1234)).toBe("12.34");
    expect(percentFromBasisPoints(5)).toBe("0.05");
    expect(() => percentFromBasisPoints(-1)).toThrow(RangeError);
  });

  test("property: every percentage from 0 to 100 round-trips through basis points", () => {
    fc.assert(
      fc.property(fc.integer({ min: 0, max: 10_000 }), (basisPoints) => {
        const percent = percentFromBasisPoints(basisPoints);
        expect(basisPointsFromPercent(percent)).toBe(basisPoints);
        expect(basisPointsFromPercent(` ${percent} `)).toBe(basisPoints);
      }),
      RUNS,
    );
  });
});
