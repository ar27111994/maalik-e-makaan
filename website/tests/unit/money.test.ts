// Ports of packages/mm_core/test/money/{money,divide_rounded,basis_points}_test.dart.
import { describe, expect, test } from "vitest";
import {
  Money,
  basisPointsFromPercent,
  divideRounded,
  percentFromBasisPoints,
} from "../../src/lib/money/index.ts";
import { mulberry32 } from "./random.ts";

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

  test("property: halfUp is always floor or floor + 1 of the exact quotient (seeded)", () => {
    const random = mulberry32(42);
    for (let i = 0; i < 2000; i++) {
      const paisa = BigInt(random.int(1 << 30) - (1 << 29));
      const numerator = BigInt(random.int(20000));
      const denominator = BigInt(1 + random.int(10000));
      const exact = paisa * numerator;
      const floor = (exact < 0n ? exact - (denominator - 1n) : exact) / denominator;
      const result = Money.fromPaisa(paisa).multiply(numerator, denominator).paisa;
      expect(result - floor >= 0n && result - floor <= 1n).toBe(true);
    }
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

  test("property: parts always sum to the whole (seeded)", () => {
    const random = mulberry32(20261103);
    for (let i = 0; i < 2000; i++) {
      const total = m(random.int(2 ** 31) - 2 ** 30);
      const ratios: number[] = Array.from({ length: 1 + random.int(8) }, () => random.int(50));
      if (!ratios.some((ratio) => ratio !== 0)) ratios[0] = 1;
      const parts = total.allocate(ratios);
      expect(Money.sum(parts).equals(total)).toBe(true);
      ratios.forEach((ratio, index) => {
        if (ratio === 0) expect(parts[index]?.isZero).toBe(true);
      });
    }
    expect(paisaOf(Money.fromRupees(1000).splitEvenly(3))).toEqual([33334n, 33333n, 33333n]);
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
});
