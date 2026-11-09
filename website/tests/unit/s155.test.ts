// Section 155 withholding on rent, TY2027: the worked examples of
// .planning/research/website-facts.md §3.6 (computed independently by
// s155_vectors.py), every band edge from both sides, the prescribed-person
// threshold, and properties that hold for any rent.
import { describe, expect, test } from "vitest";
import { Money } from "../../src/lib/money/index.ts";
import {
  COMPANY_RATE_BASIS_POINTS,
  INDIVIDUAL_BANDS_ATL,
  INDIVIDUAL_BANDS_NON_ATL,
  PRESCRIBED_INDIVIDUAL_THRESHOLD,
  S155_TAX_YEAR,
  bandIndexFor,
  s155Withholding,
  tenantMustWithhold,
  type Payee,
} from "../../src/lib/tax/s155.ts";
import { mulberry32 } from "./random.ts";

const rs = (value: number) => Money.fromRupees(value);
const paisa = (value: bigint) => Money.fromPaisa(value);

function annual(gross: Money, payee: Payee, onActiveTaxpayersList: boolean): string {
  return s155Withholding({
    grossAnnualRent: gross,
    payee,
    onActiveTaxpayersList,
  }).annual.toDecimalString();
}

describe("the worked examples of website-facts.md §3.6", () => {
  // gross, individual ATL, individual non-ATL, company ATL, company non-ATL, effective % (ind. ATL)
  const vectors = [
    [240_000, 0, 0, 36_000, 72_000, "0.00"],
    [300_000, 0, 0, 45_000, 90_000, "0.00"],
    [360_000, 3_000, 6_000, 54_000, 108_000, "0.83"],
    [600_000, 15_000, 30_000, 90_000, 180_000, "2.50"],
    [1_200_000, 75_000, 150_000, 180_000, 360_000, "6.25"],
    [1_500_000, 105_000, 210_000, 225_000, 450_000, "7.00"],
    [2_000_000, 155_000, 310_000, 300_000, 600_000, "7.75"],
    [3_000_000, 405_000, 810_000, 450_000, 900_000, "13.50"],
    [6_000_000, 1_155_000, 2_310_000, 900_000, 1_800_000, "19.25"],
  ] as const;

  test.each(vectors)(
    "Rs %i a year: %i / %i / %i / %i, effective %s%%",
    (gross, indAtl, indNon, coAtl, coNon, effective) => {
      expect(annual(rs(gross), "individual", true)).toBe(rs(indAtl).toDecimalString());
      expect(annual(rs(gross), "individual", false)).toBe(rs(indNon).toDecimalString());
      expect(annual(rs(gross), "company", true)).toBe(rs(coAtl).toDecimalString());
      expect(annual(rs(gross), "company", false)).toBe(rs(coNon).toDecimalString());
      const result = s155Withholding({
        grossAnnualRent: rs(gross),
        payee: "individual",
        onActiveTaxpayersList: true,
      });
      expect((result.effectiveRateBasisPoints / 100).toFixed(2)).toBe(effective);
    },
  );
});

describe("every band edge, from both sides", () => {
  // The research script's continuity check: at the edge, and one rupee above it.
  test.each([
    [300_000, "0.00", "0.05"],
    [600_000, "15000.00", "15000.10"],
    [2_000_000, "155000.00", "155000.25"],
  ] as const)("individual on the ATL at Rs %i: %s, and %s one rupee above", (edge, at, above) => {
    expect(annual(rs(edge), "individual", true)).toBe(at);
    expect(annual(rs(edge + 1), "individual", true)).toBe(above);
  });

  test.each([
    [300_000, "0.00", "0.10"],
    [600_000, "30000.00", "30000.20"],
    [2_000_000, "310000.00", "310000.50"],
  ] as const)(
    "individual not on the ATL at Rs %i: %s, and %s one rupee above",
    (edge, at, above) => {
      expect(annual(rs(edge), "individual", false)).toBe(at);
      expect(annual(rs(edge + 1), "individual", false)).toBe(above);
    },
  );

  test("one rupee below each edge stays in the lower band", () => {
    expect(annual(rs(299_999), "individual", true)).toBe("0.00");
    expect(annual(rs(599_999), "individual", true)).toBe("14999.95");
    expect(annual(rs(1_999_999), "individual", true)).toBe("154999.90");
    expect(annual(rs(599_999), "individual", false)).toBe("29999.90");
    expect(annual(rs(1_999_999), "individual", false)).toBe("309999.80");
  });

  test("band edges are inclusive at the top ('does not exceed'), by the paisa", () => {
    for (const bands of [INDIVIDUAL_BANDS_ATL, INDIVIDUAL_BANDS_NON_ATL]) {
      for (const [index, band] of bands.entries()) {
        if (band.upTo === null) continue;
        expect(bandIndexFor(bands, band.upTo)).toBe(index);
        expect(bandIndexFor(bands, band.upTo.plus(paisa(1n)))).toBe(index + 1);
      }
      expect(bandIndexFor(bands, Money.ZERO)).toBe(0);
      expect(bandIndexFor(bands, Money.MAX_VALUE)).toBe(bands.length - 1);
    }
  });

  test("the tax is continuous at every edge: the fixed amount is the band below's tax at its top", () => {
    for (const onAtl of [true, false]) {
      const bands = onAtl ? INDIVIDUAL_BANDS_ATL : INDIVIDUAL_BANDS_NON_ATL;
      for (const band of bands.slice(1)) {
        const justAbove = s155Withholding({
          grossAnnualRent: band.over.plus(paisa(1n)),
          payee: "individual",
          onActiveTaxpayersList: onAtl,
        });
        const at = s155Withholding({
          grossAnnualRent: band.over,
          payee: "individual",
          onActiveTaxpayersList: onAtl,
        });
        expect(at.annual.equals(band.fixed)).toBe(true);
        // One paisa more adds at most the band's rate of one paisa, rounded half up.
        expect(justAbove.annual.minus(at.annual).paisa).toBeLessThanOrEqual(1n);
      }
    }
  });

  test("companies pay a flat rate from the first rupee", () => {
    expect(annual(rs(1), "company", true)).toBe("0.15");
    expect(annual(rs(1), "company", false)).toBe("0.30");
    expect(annual(Money.ZERO, "company", true)).toBe("0.00");
    expect(COMPANY_RATE_BASIS_POINTS).toEqual({ onAtl: 1500, notOnAtl: 3000 });
  });
});

describe("the result explains itself", () => {
  test("band, excess, fixed amount and rate add up to the annual figure", () => {
    const result = s155Withholding({
      grossAnnualRent: rs(1_200_000),
      payee: "individual",
      onActiveTaxpayersList: true,
    });
    expect(result.bandIndex).toBe(2);
    expect(result.band.over.equals(rs(600_000))).toBe(true);
    expect(result.excess.equals(rs(600_000))).toBe(true);
    expect(result.band.fixed.equals(rs(15_000))).toBe(true);
    expect(result.band.rateBasisPoints).toBe(1000);
    expect(result.annual.equals(rs(75_000))).toBe(true);
    expect(result.monthlyEvenSpread.equals(rs(6_250))).toBe(true);
    expect(result.effectiveRateBasisPoints).toBe(625);
    expect(result.nonAtlIndividual).toBe(false);
  });

  test("the monthly figure is annual ÷ 12, rounded half up to the paisa", () => {
    const result = s155Withholding({
      grossAnnualRent: rs(360_000),
      payee: "individual",
      onActiveTaxpayersList: true,
    });
    expect(result.annual.equals(rs(3_000))).toBe(true);
    expect(result.monthlyEvenSpread.equals(rs(250))).toBe(true);
    const odd = s155Withholding({
      grossAnnualRent: rs(300_100),
      payee: "individual",
      onActiveTaxpayersList: true,
    });
    // 5% of Rs 100 = Rs 5.00; ÷ 12 = 0.41666… → 0.42.
    expect(odd.monthlyEvenSpread.toDecimalString()).toBe("0.42");
  });

  test("the non-ATL individual column is flagged as the uncertain one", () => {
    const flag = (payee: Payee, onAtl: boolean) =>
      s155Withholding({ grossAnnualRent: rs(1_000_000), payee, onActiveTaxpayersList: onAtl })
        .nonAtlIndividual;
    expect(flag("individual", false)).toBe(true);
    expect(flag("individual", true)).toBe(false);
    expect(flag("company", false)).toBe(false);
  });

  test("no rent, no tax, and no division by zero", () => {
    const result = s155Withholding({
      grossAnnualRent: Money.ZERO,
      payee: "individual",
      onActiveTaxpayersList: false,
    });
    expect(result.annual.isZero).toBe(true);
    expect(result.effectiveRateBasisPoints).toBe(0);
  });

  test("a negative rent is refused", () => {
    expect(() =>
      s155Withholding({ grossAnnualRent: rs(-1), payee: "company", onActiveTaxpayersList: true }),
    ).toThrow(RangeError);
  });

  test("the tax year is TY2027, 1 July 2026 to 30 June 2027", () => {
    expect(S155_TAX_YEAR).toEqual({ label: "2027", start: "2026-07-01", end: "2027-06-30" });
  });
});

describe("who must withhold (prescribed persons)", () => {
  test("an individual or AOP tenant withholds from Rs 1.5 million a year, not one rupee below", () => {
    expect(PRESCRIBED_INDIVIDUAL_THRESHOLD.equals(rs(1_500_000))).toBe(true);
    expect(tenantMustWithhold("individual", rs(1_500_000))).toBe(true);
    expect(tenantMustWithhold("individual", rs(1_499_999))).toBe(false);
    expect(tenantMustWithhold("individual", rs(1_499_999).plus(paisa(99n)))).toBe(false);
    expect(tenantMustWithhold("individual", rs(1_500_001))).toBe(true);
  });

  test("an organisation on the FBR's list withholds whatever the rent", () => {
    expect(tenantMustWithhold("organisation", Money.ZERO)).toBe(true);
    expect(tenantMustWithhold("organisation", rs(240_000))).toBe(true);
  });
});

describe("properties over random rents", () => {
  const random = mulberry32(155);
  // Every band edge, plus 500 random whole-rupee rents up to Rs 1 crore.
  const rents = [
    ...[0, 1, 299_999, 300_000, 300_001, 599_999, 600_000, 600_001].map(rs),
    ...[1_999_999, 2_000_000, 2_000_001].map(rs),
    ...Array.from({ length: 500 }, () => rs(random.int(10_000_000))),
  ];

  test("not on the ATL is exactly double on the ATL, for individuals and companies", () => {
    for (const gross of rents) {
      for (const payee of ["individual", "company"] as const) {
        const on = s155Withholding({ grossAnnualRent: gross, payee, onActiveTaxpayersList: true });
        const off = s155Withholding({
          grossAnnualRent: gross,
          payee,
          onActiveTaxpayersList: false,
        });
        expect(off.annual.paisa).toBe(on.annual.paisa * 2n);
      }
    }
  });

  test("withholding never falls as rent rises, and never exceeds the top marginal rate", () => {
    const sorted = [...rents].sort((a, b) => a.compareTo(b));
    let previous = Money.ZERO;
    for (const gross of sorted) {
      const result = s155Withholding({
        grossAnnualRent: gross,
        payee: "individual",
        onActiveTaxpayersList: true,
      });
      expect(result.annual.gte(previous)).toBe(true);
      expect(result.annual.lte(gross.percentage(2500))).toBe(true);
      previous = result.annual;
    }
  });

  test("whole-rupee rents give an exact number of paisa: no rounding is needed", () => {
    for (const gross of rents) {
      for (const [payee, onAtl] of [
        ["individual", true],
        ["individual", false],
        ["company", true],
        ["company", false],
      ] as const) {
        const result = s155Withholding({
          grossAnnualRent: gross,
          payee,
          onActiveTaxpayersList: onAtl,
        });
        const exact =
          result.band.fixed.paisa * 10_000n +
          result.excess.paisa * BigInt(result.band.rateBasisPoints);
        expect(exact % 10_000n).toBe(0n);
        expect(result.annual.paisa).toBe(exact / 10_000n);
      }
    }
  });
});
