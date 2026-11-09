/**
 * Withholding tax on rent under section 155 of the Income Tax Ordinance 2001,
 * for tax year 2027 (1 July 2026 to 30 June 2027), exactly as the FBR's
 * Withholding Tax Rate Card for Tax Year 2027 states it (Division V of Part III
 * of the First Schedule, read with rule 1 of the Tenth Schedule).
 *
 * Source of every figure: .planning/research/website-facts.md §3.4 (TX-11 to
 * TX-15), whose worked examples (§3.6) are this module's unit-test vectors.
 *
 * This is withholding only. Tax withheld under s.155 is adjustable against the
 * landlord's final liability; it is not the final tax, and nothing here
 * estimates final tax (decision D-10 in .planning/PROJECT.md).
 *
 * Arithmetic is exact: amounts are integer paisa (`Money`), rates are basis
 * points, band edges are inclusive at the top ("does not exceed" means `<=`),
 * and the one rounding (half-up, to the paisa) happens once, at the end. For a
 * gross rent in whole rupees every band gives an exact number of paisa, so no
 * rounding happens at all.
 */
import { Money } from "../money/money.ts";
import { divideRounded } from "../money/rounding.ts";

/** The tax year these rates are for: TY2027 runs from 1 July 2026 to 30 June 2027. */
export const S155_TAX_YEAR = { label: "2027", start: "2026-07-01", end: "2027-06-30" } as const;

/** Who receives the rent: an individual or an association of persons (AOP), or a company. */
export type Payee = "individual" | "company";

/** One band of the individual and AOP table: on gross annual rent above `over`, up to `upTo`. */
export interface S155Band {
  /** The band's lower edge: the band applies to rent above this amount. */
  readonly over: Money;
  /** The band's upper edge, inclusive ("does not exceed"); `null` for the top band. */
  readonly upTo: Money | null;
  /** The fixed amount of tax for the rent up to `over`. */
  readonly fixed: Money;
  /** The rate on the amount above `over`, in basis points (5% = 500). */
  readonly rateBasisPoints: number;
}

const rupees = (value: number) => Money.fromRupees(value);

/**
 * Individuals and AOPs on the Active Taxpayers List (ATL): the FBR TY2027 card.
 *
 * - up to Rs 300,000: nil;
 * - Rs 300,001 to 600,000: 5% of the amount over Rs 300,000;
 * - Rs 600,001 to 2,000,000: Rs 15,000 plus 10% of the amount over Rs 600,000;
 * - over Rs 2,000,000: Rs 155,000 plus 25% of the amount over Rs 2,000,000.
 */
export const INDIVIDUAL_BANDS_ATL: readonly S155Band[] = [
  { over: rupees(0), upTo: rupees(300_000), fixed: rupees(0), rateBasisPoints: 0 },
  { over: rupees(300_000), upTo: rupees(600_000), fixed: rupees(0), rateBasisPoints: 500 },
  { over: rupees(600_000), upTo: rupees(2_000_000), fixed: rupees(15_000), rateBasisPoints: 1000 },
  { over: rupees(2_000_000), upTo: null, fixed: rupees(155_000), rateBasisPoints: 2500 },
];

/**
 * Individuals and AOPs not on the ATL: rule 1 of the Tenth Schedule increases
 * the rate by 100%, which the FBR card shows as these bands (every rate and
 * fixed amount doubled; the nil band stays nil). Whether the Tenth Schedule
 * applies to s.155 for individuals is less certain than the rest of the table:
 * the FBR's 2020 and 2021 cards excluded it, and the later cards cite rule 1
 * (website-facts.md TX-14, confidence Medium). The calculator says so.
 */
export const INDIVIDUAL_BANDS_NON_ATL: readonly S155Band[] = [
  { over: rupees(0), upTo: rupees(300_000), fixed: rupees(0), rateBasisPoints: 0 },
  { over: rupees(300_000), upTo: rupees(600_000), fixed: rupees(0), rateBasisPoints: 1000 },
  { over: rupees(600_000), upTo: rupees(2_000_000), fixed: rupees(30_000), rateBasisPoints: 2000 },
  { over: rupees(2_000_000), upTo: null, fixed: rupees(310_000), rateBasisPoints: 5000 },
];

/** Companies: 15% of the gross rent on the ATL, 30% off it (one band from zero). */
export const COMPANY_RATE_BASIS_POINTS = { onAtl: 1500, notOnAtl: 3000 } as const;

/**
 * An individual or AOP tenant becomes a "prescribed person", and so must
 * withhold under s.155, when the gross rent it pays in a year is Rs 1.5 million
 * or more (website-facts.md TX-11; the 2026 consolidated text was not seen).
 */
export const PRESCRIBED_INDIVIDUAL_THRESHOLD = rupees(1_500_000);

export interface S155Input {
  /** The gross rent for the year, including furniture, fixtures and services (TX-10). */
  readonly grossAnnualRent: Money;
  readonly payee: Payee;
  /** Whether the payee (the landlord) is on the FBR's Active Taxpayers List. */
  readonly onActiveTaxpayersList: boolean;
}

export interface S155Result {
  /** The band the rent falls in. For a company, one band from zero with no fixed amount. */
  readonly band: S155Band;
  /** The position of `band` in its table (0 = the nil band); always 0 for a company. */
  readonly bandIndex: number;
  /** The rent above the band's lower edge, which the rate applies to. */
  readonly excess: Money;
  /** The tax to withhold over the year: `band.fixed + excess × rate`. */
  readonly annual: Money;
  /** `annual ÷ 12` to the paisa, half-up: an even-spread assumption, not a rule of law. */
  readonly monthlyEvenSpread: Money;
  /** `annual ÷ gross` in basis points (hundredths of a percent), half-up; 0 for no rent. */
  readonly effectiveRateBasisPoints: number;
  /** The individual or AOP non-ATL column, whose legal basis is less certain (TX-14). */
  readonly nonAtlIndividual: boolean;
}

/** The individual or AOP band table for the payee's ATL status. */
export function individualBands(onActiveTaxpayersList: boolean): readonly S155Band[] {
  return onActiveTaxpayersList ? INDIVIDUAL_BANDS_ATL : INDIVIDUAL_BANDS_NON_ATL;
}

/** The band of `bands` that `gross` falls in: the first whose upper edge it does not exceed. */
export function bandIndexFor(bands: readonly S155Band[], gross: Money): number {
  const index = bands.findIndex((band) => band.upTo === null || gross.lte(band.upTo));
  if (index < 0) throw new Error("The band table has no open top band");
  return index;
}

/** The withholding under s.155 for a year's gross rent. */
export function s155Withholding({
  grossAnnualRent,
  payee,
  onActiveTaxpayersList,
}: S155Input): S155Result {
  if (grossAnnualRent.isNegative) throw new RangeError("Gross rent must not be negative");
  let band: S155Band;
  let bandIndex: number;
  if (payee === "company") {
    band = {
      over: Money.ZERO,
      upTo: null,
      fixed: Money.ZERO,
      rateBasisPoints: onActiveTaxpayersList
        ? COMPANY_RATE_BASIS_POINTS.onAtl
        : COMPANY_RATE_BASIS_POINTS.notOnAtl,
    };
    bandIndex = 0;
  } else {
    const bands = individualBands(onActiveTaxpayersList);
    bandIndex = bandIndexFor(bands, grossAnnualRent);
    const found = bands[bandIndex];
    if (found === undefined) throw new Error("unreachable: band index out of range");
    band = found;
  }
  const excess = Money.max(Money.ZERO, grossAnnualRent.minus(band.over));
  const annual = band.fixed.plus(excess.multiply(band.rateBasisPoints, 10_000));
  return {
    band,
    bandIndex,
    excess,
    annual,
    monthlyEvenSpread: annual.multiply(1, 12),
    effectiveRateBasisPoints: grossAnnualRent.isZero
      ? 0
      : Number(divideRounded(annual.paisa * 10_000n, grossAnnualRent.paisa, "halfUp")),
    nonAtlIndividual: payee === "individual" && !onActiveTaxpayersList,
  };
}

/** What kind of tenant pays the rent, for deciding whether it must withhold (TX-11). */
export type Tenant =
  /** A government, a company, an NPO or charity, a diplomatic mission, or a listed business. */
  | "organisation"
  /** An individual or AOP: a prescribed person only at Rs 1.5 million a year or more. */
  | "individual";

/** Whether a tenant must deduct tax under s.155 from rent of `grossAnnualRent` a year. */
export function tenantMustWithhold(tenant: Tenant, grossAnnualRent: Money): boolean {
  return tenant === "organisation" || grossAnnualRent.gte(PRESCRIBED_INDIVIDUAL_THRESHOLD);
}
