/**
 * Percentages stored as `numeric(5,2)` (e.g. `10.00` for 10%) are handled in
 * code as integer basis points (1% = 100 bp) so percentage arithmetic stays
 * exact. Mirrors packages/mm_core/lib/src/money/basis_points.dart.
 */

const PERCENT_PATTERN = /^(\d{1,3})(?:\.(\d{1,2}))?$/;

/**
 * Converts a percentage (a number or numeric string with at most two decimal
 * places, 0–100) into basis points: `10` → 1000, `2.5` → 250. Throws a
 * `SyntaxError` for malformed or out-of-range input.
 */
export function basisPointsFromPercent(value: unknown): number {
  let text: string;
  if (typeof value === "number" && Number.isFinite(value)) {
    text = Number.isInteger(value) ? String(value) : value.toFixed(2);
  } else if (typeof value === "string") {
    text = value.trim();
  } else {
    throw new SyntaxError(`Expected a percentage, got ${String(value)}`);
  }
  const match = PERCENT_PATTERN.exec(text);
  if (match === null) throw new SyntaxError(`Expected a percentage, got ${JSON.stringify(text)}`);
  const [, whole = "", fraction = ""] = match;
  const basisPoints = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  if (basisPoints > 10_000) throw new SyntaxError(`Percentage must not exceed 100: ${text}`);
  return basisPoints;
}

/** Formats basis points as a percentage: 1000 → `10`, 250 → `2.5`, 1234 → `12.34`. */
export function percentFromBasisPoints(basisPoints: number): string {
  if (!Number.isSafeInteger(basisPoints) || basisPoints < 0) {
    throw new RangeError(`basisPoints must be a non-negative integer, got ${basisPoints}`);
  }
  const whole = Math.trunc(basisPoints / 100);
  const fraction = basisPoints % 100;
  if (fraction === 0) return String(whole);
  return `${whole}.${String(fraction).padStart(2, "0").replace(/0$/, "")}`;
}
