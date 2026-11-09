import { basisPointsFromPercent } from "./basis-points.ts";
import { Money } from "./money.ts";

/**
 * How a lease charges for late rent. Mirrors `LateFeePolicy` in
 * packages/mm_core/lib/src/rent/late_fee_policy.dart and the `late_fee_type`,
 * `late_fee_value` and `late_fee_cap` columns of the `leases` table.
 */
export type LateFeePolicy =
  | { readonly type: "none" }
  /** A fixed fee once the grace period has passed. */
  | { readonly type: "flat"; readonly amount: Money }
  /** A percentage of the overdue amount, in basis points (250 = 2.5%). */
  | { readonly type: "percent"; readonly basisPoints: number }
  /** A fee per day late (counted from the due date), optionally capped. */
  | { readonly type: "daily"; readonly perDay: Money; readonly cap: Money | null };

/**
 * The largest fee ever charged: whole rupees below the 10^12 limit of a
 * `numeric(14,2)` charge. Mirrors `app.late_fee_amount`.
 */
export const MAX_LATE_FEE = Money.fromRupees(999_999_999_999n);

function requireMoney(value: unknown, type: string): Money {
  const money = value === null || value === undefined ? null : Money.fromJson(value);
  if (money === null || money.isNegative) {
    throw new RangeError(`late fee type "${type}" requires a non-negative value`);
  }
  return money;
}

/**
 * Decodes the database representation, where `value` and `cap` are the raw
 * JSON column values: `none`; `flat` (rupees); `percent` (a `numeric(5,2)`
 * percentage); `daily` (rupees per day, optionally capped at `cap`).
 */
export function lateFeePolicyFromColumns({
  type,
  value = null,
  cap = null,
}: {
  type: string;
  value?: unknown;
  cap?: unknown;
}): LateFeePolicy {
  switch (type) {
    case "none":
      return { type: "none" };
    case "flat":
      return { type: "flat", amount: requireMoney(value, type) };
    case "percent":
      if (value === null || value === undefined) {
        throw new RangeError('late fee type "percent" requires a value');
      }
      return { type: "percent", basisPoints: basisPointsFromPercent(value) };
    case "daily":
      return {
        type: "daily",
        perDay: requireMoney(value, type),
        cap: cap === null || cap === undefined ? null : Money.fromJson(cap),
      };
    default:
      throw new RangeError(`unknown late fee type: ${type}`);
  }
}

/**
 * The fee owed on `overdueAmount` that is `daysLate` days past its due date,
 * with a grace period of `graceDays` days.
 *
 * No fee while `daysLate <= graceDays` or when nothing is owed. The fee is
 * rounded half-up to whole rupees first and capped afterwards, so it never
 * exceeds the policy's cap nor {@link MAX_LATE_FEE}: the same order as the
 * database.
 */
export function lateFeeFor(
  policy: LateFeePolicy,
  {
    overdueAmount,
    daysLate,
    graceDays,
  }: { overdueAmount: Money; daysLate: number; graceDays: number },
): Money {
  if (!Number.isSafeInteger(graceDays) || graceDays < 0) {
    throw new RangeError(`graceDays must be >= 0, got ${graceDays}`);
  }
  if (!Number.isSafeInteger(daysLate))
    throw new RangeError(`daysLate must be an integer, got ${daysLate}`);
  if (!overdueAmount.isPositive || daysLate <= graceDays) return Money.ZERO;
  let fee: Money;
  switch (policy.type) {
    case "none":
      return Money.ZERO;
    case "flat":
      fee = policy.amount.roundToRupee();
      break;
    case "percent":
      // Round once, straight to rupees, exactly like the database.
      fee = overdueAmount.multiplyToStep(policy.basisPoints, 10_000);
      break;
    case "daily": {
      // Exact product, held below the maximum so years of daily fees cannot
      // overflow (anything above it is clamped after rounding anyway).
      const raw = policy.perDay.paisa * BigInt(daysLate);
      const limited = raw > MAX_LATE_FEE.paisa ? MAX_LATE_FEE : Money.fromPaisa(raw);
      fee = limited.roundToRupee();
      if (policy.cap !== null) fee = Money.min(fee, policy.cap);
      break;
    }
  }
  return Money.min(fee, MAX_LATE_FEE);
}
