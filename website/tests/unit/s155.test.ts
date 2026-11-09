// Section 155 withholding on rent, TY2027: the worked examples of
// .planning/research/website-facts.md §3.6 (computed independently by
// s155_vectors.py), every band edge from both sides, the prescribed-person
// threshold, and properties that hold for any rent.
import fc from "fast-check";
import { describe, expect, test } from "vitest";
import { Money } from "../../src/lib/money/index.ts";
import {
  COMPANY_RATE_BASIS_POINTS,
  INDIVIDUAL_BANDS_ATL,
  INDIVIDUAL_BANDS_NON_ATL,
  PRESCRIBED_INDIVIDUAL_THRESHOLD,
  S155_TAX_YEAR,
  bandIndexFor,
  individualBands,
  s155Withholding,
  tenantMustWithhold,
  type Payee,
} from "../../src/lib/tax/s155.ts";
import { RUNS, paisaIn, rupeesIn } from "./arbitraries.ts";

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

describe("properties over any rent", () => {
  const EDGES = [0, 1, 299_999, 300_000, 300_001, 599_999, 600_000, 600_001];
  const TOP_EDGES = [1_999_999, 2_000_000, 2_000_001, 1_499_999, 1_500_000, 1_500_001];
  /** Whole-rupee rents up to Rs 1 crore a year, with every band edge and its neighbours. */
  const wholeRupeeRent = fc.oneof(
    fc.constantFrom(...EDGES, ...TOP_EDGES).map(rs),
    rupeesIn(0, 10_000_000),
  );
  /** Any rent to the paisa, up to Rs 120 crore: Rs 10 crore a month, the calculator's maximum. */
  const anyRent = fc.oneof(wholeRupeeRent, paisaIn(0n, 120_000_000_000n));
  const columns = fc.constantFrom<readonly [Payee, boolean]>(
    ["individual", true],
    ["individual", false],
    ["company", true],
    ["company", false],
  );
  const withholding = (gross: Money, payee: Payee, onActiveTaxpayersList: boolean) =>
    s155Withholding({ grossAnnualRent: gross, payee, onActiveTaxpayersList });

  test("not on the ATL is exactly double on the ATL, for individuals and companies", () => {
    fc.assert(
      fc.property(
        wholeRupeeRent,
        fc.constantFrom<Payee>("individual", "company"),
        (gross, payee) => {
          const on = withholding(gross, payee, true);
          const off = withholding(gross, payee, false);
          expect(off.annual.paisa).toBe(on.annual.paisa * 2n);
        },
      ),
      RUNS,
    );
  });

  test("withholding never falls as rent rises, and never exceeds the top marginal rate", () => {
    fc.assert(
      fc.property(anyRent, anyRent, columns, (a, b, [payee, onAtl]) => {
        const [low, high] = a.lte(b) ? [a, b] : [b, a];
        const lower = withholding(low, payee, onAtl);
        const higher = withholding(high, payee, onAtl);
        expect(lower.annual.gte(Money.ZERO)).toBe(true);
        expect(lower.annual.lte(higher.annual)).toBe(true);
        // The top marginal rate: 25% (individual, ATL), 50% (not), 15% or 30% (company).
        const top =
          payee === "company"
            ? onAtl
              ? COMPANY_RATE_BASIS_POINTS.onAtl
              : COMPANY_RATE_BASIS_POINTS.notOnAtl
            : (individualBands(onAtl).at(-1)?.rateBasisPoints ?? 0);
        expect(higher.annual.lte(high.percentage(top))).toBe(true);
        // The effective rate is the rounded annual figure over the rent, rounded half up
        // to the basis point. Below Rs 100 a year the half paisa of the annual figure's own
        // rounding is a basis point or more (Rs 0.02 at 30% is 0.6 paisa, withheld as 1
        // paisa: 50%), so the cap on the rate holds from Rs 100.
        const effective = BigInt(higher.effectiveRateBasisPoints);
        const error = effective * high.paisa - higher.annual.paisa * 10_000n;
        expect((error < 0n ? -error : error) * 2n <= high.paisa).toBe(true);
        if (high.gte(rs(100))) expect(higher.effectiveRateBasisPoints).toBeLessThanOrEqual(top);
      }),
      RUNS,
    );
  });

  test("whole-rupee rents give an exact number of paisa: no rounding is needed", () => {
    fc.assert(
      fc.property(wholeRupeeRent, columns, (gross, [payee, onAtl]) => {
        const result = withholding(gross, payee, onAtl);
        const exact =
          result.band.fixed.paisa * 10_000n +
          result.excess.paisa * BigInt(result.band.rateBasisPoints);
        expect(exact % 10_000n).toBe(0n);
        expect(result.annual.paisa).toBe(exact / 10_000n);
      }),
      RUNS,
    );
  });

  test("the rent falls in its band: above the lower edge, not above the upper", () => {
    fc.assert(
      fc.property(anyRent, fc.boolean(), (gross, onAtl) => {
        const result = withholding(gross, "individual", onAtl);
        const { band } = result;
        expect(band).toBe(individualBands(onAtl)[result.bandIndex]);
        expect(gross.gt(band.over) || result.bandIndex === 0).toBe(true);
        expect(band.upTo === null || gross.lte(band.upTo)).toBe(true);
        expect(result.excess.equals(gross.minus(band.over))).toBe(true);
        expect(result.nonAtlIndividual).toBe(!onAtl);
      }),
      RUNS,
    );
  });

  test("the monthly figure times 12 is within 6 paisa of the year's", () => {
    fc.assert(
      fc.property(anyRent, columns, (gross, [payee, onAtl]) => {
        const result = withholding(gross, payee, onAtl);
        const difference = result.monthlyEvenSpread.paisa * 12n - result.annual.paisa;
        expect(difference >= -6n && difference <= 6n).toBe(true);
      }),
      RUNS,
    );
  });

  test("an individual tenant withholds exactly from Rs 1.5 million, an organisation always", () => {
    fc.assert(
      fc.property(anyRent, (gross) => {
        expect(tenantMustWithhold("organisation", gross)).toBe(true);
        expect(tenantMustWithhold("individual", gross)).toBe(
          gross.gte(PRESCRIBED_INDIVIDUAL_THRESHOLD),
        );
      }),
      RUNS,
    );
  });
});
