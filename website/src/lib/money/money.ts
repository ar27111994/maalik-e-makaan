import { divideRounded, type RoundingMode } from "./rounding.ts";

/** A whole number of paisa or rupees: a `bigint`, or a `number` that is a safe integer. */
export type WholeNumber = bigint | number;

function toBigInt(value: WholeNumber, name: string): bigint {
  if (typeof value === "bigint") return value;
  if (!Number.isSafeInteger(value)) {
    throw new RangeError(`${name} must be a safe integer, got ${String(value)}`);
  }
  return BigInt(value);
}

const DECIMAL_PATTERN = /^([+-])?(\d+)(?:\.(\d{1,2}))?$/;

/**
 * An exact amount of Pakistani Rupees, stored as an integer number of paisa
 * (1 rupee = 100 paisa).
 *
 * Mirrors `Money` in packages/mm_core/lib/src/money/money.dart. Floating-point
 * numbers are never used for arithmetic: every operation that can produce a
 * fraction of a paisa takes an explicit {@link RoundingMode} and is computed
 * with `bigint`, so the website's calculators agree with the app and the
 * database to the paisa.
 *
 * The supported storage range mirrors the database type `numeric(14,2)`:
 * ±999,999,999,999.99.
 */
export class Money {
  /** The number of paisa in one rupee. */
  static readonly PAISA_PER_RUPEE = 100n;
  /** Zero rupees. */
  static readonly ZERO = new Money(0n);
  /** Largest representable amount (matches `numeric(14,2)`). */
  static readonly MAX_VALUE = new Money(99_999_999_999_999n);
  /** Smallest representable amount (matches `numeric(14,2)`). */
  static readonly MIN_VALUE = new Money(-99_999_999_999_999n);

  /** The amount in paisa. Negative values represent credits or refunds. */
  readonly paisa: bigint;

  private constructor(paisa: bigint) {
    this.paisa = paisa;
  }

  /** An amount of `paisa` paisa. */
  static fromPaisa(paisa: WholeNumber): Money {
    return new Money(toBigInt(paisa, "paisa"));
  }

  /** An amount of `rupees` whole rupees. */
  static fromRupees(rupees: WholeNumber): Money {
    return new Money(toBigInt(rupees, "rupees") * Money.PAISA_PER_RUPEE);
  }

  /**
   * Parses an exact decimal string such as `1500`, `1500.5` or `-20.75`. At
   * most two fraction digits are accepted; grouping separators are not (use
   * `parseMoneyInput` for typed input). Throws a `SyntaxError` otherwise.
   */
  static parseDecimal(value: string): Money {
    const parsed = Money.tryParseDecimal(value);
    if (parsed === null) {
      throw new SyntaxError(`Not a valid decimal money amount: ${JSON.stringify(value)}`);
    }
    return parsed;
  }

  /**
   * Parses an exact decimal string, returning `null` when it is malformed, has
   * more than two fraction digits, or is outside the storage range.
   */
  static tryParseDecimal(value: string): Money | null {
    const match = DECIMAL_PATTERN.exec(value);
    if (match === null) return null;
    const [, sign, whole = "", fraction = ""] = match;
    const paisa = BigInt(whole) * Money.PAISA_PER_RUPEE + BigInt(fraction.padEnd(2, "0"));
    const signed = sign === "-" ? -paisa : paisa;
    if (signed > Money.MAX_VALUE.paisa || signed < Money.MIN_VALUE.paisa) return null;
    return new Money(signed);
  }

  /**
   * Decodes an amount as the database API serialises `numeric` columns: a JSON
   * number or a decimal string. Throws a `SyntaxError` for anything else.
   */
  static fromJson(json: unknown): Money {
    if (typeof json === "number") {
      if (!Number.isFinite(json)) throw new SyntaxError("Money must be finite");
      if (Number.isInteger(json)) return Money.fromRupees(json);
      // toFixed(2) rounds through the shortest round-trip decimal, which is
      // exact for every value numeric(14,2) can hold.
      return Money.parseDecimal(json.toFixed(2));
    }
    if (typeof json === "string") return Money.parseDecimal(json.trim());
    throw new SyntaxError(`Unsupported money JSON value: ${String(json)}`);
  }

  /** The smaller of `a` and `b`. */
  static min(a: Money, b: Money): Money {
    return a.lte(b) ? a : b;
  }

  /** The larger of `a` and `b`. */
  static max(a: Money, b: Money): Money {
    return a.gte(b) ? a : b;
  }

  /** Sums `amounts`; an empty list sums to zero. */
  static sum(amounts: Iterable<Money>): Money {
    let total = 0n;
    for (const amount of amounts) total += amount.paisa;
    return new Money(total);
  }

  /** Whole rupees, truncated toward zero. */
  get wholeRupees(): bigint {
    return this.paisa / Money.PAISA_PER_RUPEE;
  }

  /** The paisa component (0–99) of the absolute amount. */
  get paisaComponent(): bigint {
    const magnitude = this.paisa < 0n ? -this.paisa : this.paisa;
    return magnitude % Money.PAISA_PER_RUPEE;
  }

  get isZero(): boolean {
    return this.paisa === 0n;
  }

  get isPositive(): boolean {
    return this.paisa > 0n;
  }

  get isNegative(): boolean {
    return this.paisa < 0n;
  }

  /** Whether the amount has a non-zero paisa component. */
  get hasPaisa(): boolean {
    return this.paisaComponent !== 0n;
  }

  /** Whether the amount lies within `MIN_VALUE`..`MAX_VALUE`. */
  get isWithinStorageRange(): boolean {
    return this.paisa <= Money.MAX_VALUE.paisa && this.paisa >= Money.MIN_VALUE.paisa;
  }

  plus(other: Money): Money {
    return new Money(this.paisa + other.paisa);
  }

  minus(other: Money): Money {
    return new Money(this.paisa - other.paisa);
  }

  negate(): Money {
    return new Money(-this.paisa);
  }

  abs(): Money {
    return this.paisa < 0n ? this.negate() : this;
  }

  compareTo(other: Money): number {
    return this.paisa < other.paisa ? -1 : this.paisa > other.paisa ? 1 : 0;
  }

  equals(other: unknown): boolean {
    return other instanceof Money && other.paisa === this.paisa;
  }

  lt(other: Money): boolean {
    return this.paisa < other.paisa;
  }

  lte(other: Money): boolean {
    return this.paisa <= other.paisa;
  }

  gt(other: Money): boolean {
    return this.paisa > other.paisa;
  }

  gte(other: Money): boolean {
    return this.paisa >= other.paisa;
  }

  /** Restricts the amount to the inclusive range `lower`..`upper`. */
  clamp(lower: Money, upper: Money): Money {
    if (lower.gt(upper)) {
      throw new RangeError(
        `lower (${lower.toString()}) must not exceed upper (${upper.toString()})`,
      );
    }
    if (this.lt(lower)) return lower;
    if (this.gt(upper)) return upper;
    return this;
  }

  /**
   * Multiplies by the exact ratio `numerator`/`denominator`, rounding the
   * result to whole paisa with `mode`.
   */
  multiply(
    numerator: WholeNumber,
    denominator: WholeNumber = 1n,
    mode: RoundingMode = "halfUp",
  ): Money {
    const d = toBigInt(denominator, "denominator");
    if (d === 0n) throw new RangeError("denominator must not be 0");
    return new Money(divideRounded(this.paisa * toBigInt(numerator, "numerator"), d, mode));
  }

  /**
   * Multiplies by the exact ratio `numerator`/`denominator` and rounds the
   * result once to a multiple of `stepRupees` whole rupees. Rounding twice
   * (to paisa, then to the step) can differ from the database's single
   * rounding: an exact Rs 12.495 would become 12.50 and then 13, not 12.
   */
  multiplyToStep(
    numerator: WholeNumber,
    denominator: WholeNumber,
    { stepRupees = 1n, mode = "halfUp" }: { stepRupees?: WholeNumber; mode?: RoundingMode } = {},
  ): Money {
    const d = toBigInt(denominator, "denominator");
    if (d === 0n) throw new RangeError("denominator must not be 0");
    const step = toBigInt(stepRupees, "stepRupees");
    if (step <= 0n) throw new RangeError("stepRupees must be > 0");
    const stepPaisa = step * Money.PAISA_PER_RUPEE;
    const steps = divideRounded(this.paisa * toBigInt(numerator, "numerator"), d * stepPaisa, mode);
    return new Money(steps * stepPaisa);
  }

  /** `basisPoints` hundredths of a percent of this amount (10% = 1000). */
  percentage(basisPoints: WholeNumber, mode: RoundingMode = "halfUp"): Money {
    return this.multiply(basisPoints, 10_000n, mode);
  }

  /** Rounds to a multiple of `stepRupees` whole rupees (100 rounds 52,030 to 52,000). */
  roundToStep(stepRupees: WholeNumber, mode: RoundingMode = "halfUp"): Money {
    const step = toBigInt(stepRupees, "stepRupees");
    if (step <= 0n) throw new RangeError("stepRupees must be > 0");
    const stepPaisa = step * Money.PAISA_PER_RUPEE;
    return new Money(divideRounded(this.paisa, stepPaisa, mode) * stepPaisa);
  }

  /** Rounds to whole rupees. */
  roundToRupee(mode: RoundingMode = "halfUp"): Money {
    return this.roundToStep(1n, mode);
  }

  /**
   * Splits this amount in proportion to `ratios` without losing a paisa, using
   * the largest-remainder method; ties go to the earliest index. The parts
   * always sum to this amount.
   */
  allocate(ratios: readonly WholeNumber[]): Money[] {
    if (ratios.length === 0) throw new RangeError("ratios must not be empty");
    const weights = ratios.map((ratio) => toBigInt(ratio, "ratio"));
    if (weights.some((ratio) => ratio < 0n)) throw new RangeError("ratios must be non-negative");
    const total = weights.reduce((sum, ratio) => sum + ratio, 0n);
    if (total === 0n) throw new RangeError("ratios must not all be zero");
    const magnitude = this.paisa < 0n ? -this.paisa : this.paisa;
    const parts = weights.map((ratio) => (magnitude * ratio) / total);
    const remainders = weights.map((ratio, index) => ({
      index,
      remainder: (magnitude * ratio) % total,
    }));
    let leftover = magnitude - parts.reduce((sum, part) => sum + part, 0n);
    remainders.sort((a, b) =>
      a.remainder === b.remainder ? a.index - b.index : a.remainder > b.remainder ? -1 : 1,
    );
    for (const { index } of remainders) {
      if (leftover === 0n) break;
      parts[index] = (parts[index] ?? 0n) + 1n;
      leftover -= 1n;
    }
    const sign = this.paisa < 0n ? -1n : 1n;
    return parts.map((part) => new Money(part * sign));
  }

  /** Splits into `count` near-equal parts that sum exactly to this amount. */
  splitEvenly(count: number): Money[] {
    if (!Number.isSafeInteger(count) || count <= 0) throw new RangeError("count must be > 0");
    return this.allocate(Array.from({ length: count }, () => 1n));
  }

  /** Exact decimal representation with two fraction digits, e.g. `1500.05`. */
  toDecimalString(): string {
    const sign = this.paisa < 0n ? "-" : "";
    const whole = this.wholeRupees < 0n ? -this.wholeRupees : this.wholeRupees;
    return `${sign}${whole.toString()}.${this.paisaComponent.toString().padStart(2, "0")}`;
  }

  /** JSON representation: the exact decimal string accepted by `numeric`. */
  toJSON(): string {
    return this.toDecimalString();
  }

  toString(): string {
    return `Money(${this.toDecimalString()} PKR)`;
  }
}
