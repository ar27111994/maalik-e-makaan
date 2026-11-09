/**
 * How to round a result that falls between two representable amounts.
 * Mirrors `RoundingMode` in packages/mm_core/lib/src/money/money.dart.
 */
export type RoundingMode =
  /** Nearest value; ties go away from zero (commercial rounding). */
  | "halfUp"
  /** Nearest value; ties go to the even neighbour (banker's rounding). */
  | "halfEven"
  /** Always toward zero (truncate). */
  | "down"
  /** Always away from zero. */
  | "up"
  /** Always toward negative infinity. */
  | "floor"
  /** Always toward positive infinity. */
  | "ceiling";

/**
 * Divides `numerator` by `denominator`, rounding the quotient with `mode`.
 * Exact integer arithmetic: no floating point is involved at any step.
 */
export function divideRounded(numerator: bigint, denominator: bigint, mode: RoundingMode): bigint {
  if (denominator === 0n) {
    throw new RangeError("denominator must not be 0");
  }
  let n = numerator;
  let d = denominator;
  if (d < 0n) {
    n = -n;
    d = -d;
  }
  const quotient = n / d; // BigInt division truncates toward zero.
  const remainder = n % d; // Carries the sign of n.
  if (remainder === 0n) return quotient;
  const negative = n < 0n;
  const awayFromZero = negative ? quotient - 1n : quotient + 1n;
  const twiceRemainder = (remainder < 0n ? -remainder : remainder) * 2n;
  switch (mode) {
    case "down":
      return quotient;
    case "up":
      return awayFromZero;
    case "floor":
      return negative ? quotient - 1n : quotient;
    case "ceiling":
      return negative ? quotient : quotient + 1n;
    case "halfUp":
      return twiceRemainder >= d ? awayFromZero : quotient;
    case "halfEven":
      if (twiceRemainder > d) return awayFromZero;
      if (twiceRemainder < d) return quotient;
      return quotient % 2n === 0n ? quotient : awayFromZero;
  }
}
