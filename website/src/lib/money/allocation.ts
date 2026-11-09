import type { CalendarDate } from "./calendar.ts";
import { Money } from "./money.ts";

/** A charge that still has an outstanding balance. */
export interface OpenCharge {
  /** The charge's identifier (a UUIDv7, so it also sorts by creation time). */
  readonly id: string;
  readonly dueDate: CalendarDate;
  /** Amount still owed; must be positive. */
  readonly outstanding: Money;
  /** The lease's security-deposit due, which a deposit adjustment never pays. */
  readonly isSecurityDeposit?: boolean;
}

export interface ChargeAllocation {
  readonly chargeId: string;
  readonly amount: Money;
}

export interface AllocationPlan {
  /** Slices of the payment applied to charges, in the order applied. */
  readonly allocations: readonly ChargeAllocation[];
  /** The part of the payment left over as tenant credit (advance). */
  readonly unallocated: Money;
}

/** Code-unit order, the same as Dart's `String.compareTo` (and uuid byte order for lower-case hex). */
function compareIds(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/**
 * Applies `payment` to `charges`: the `chosenChargeIds` first, in the order
 * given (a charge chosen twice keeps its first position), then the rest
 * oldest first, by due date and then id. Mirrors `planFifoAllocation` in
 * packages/mm_core/lib/src/ledger/allocation.dart and the database's
 * `private.allocate_payment`.
 */
export function planFifoAllocation(
  payment: Money,
  charges: readonly OpenCharge[],
  {
    chosenChargeIds = [],
    depositAdjustment = false,
  }: { chosenChargeIds?: readonly string[]; depositAdjustment?: boolean } = {},
): AllocationPlan {
  if (payment.isNegative) throw new RangeError("payment must be >= 0");
  const known = new Set<string>();
  for (const charge of charges) {
    if (!charge.outstanding.isPositive) {
      throw new RangeError(`charge ${charge.id} must have a positive outstanding amount`);
    }
    known.add(charge.id);
  }
  for (const id of chosenChargeIds) {
    if (!known.has(id)) throw new RangeError(`chosen charge ${id} is not an open charge`);
  }
  const rank = (charge: OpenCharge) => {
    const index = chosenChargeIds.indexOf(charge.id);
    return index < 0 ? chosenChargeIds.length : index;
  };
  const ordered = charges
    .filter((charge) => !(depositAdjustment && charge.isSecurityDeposit === true))
    .sort((a, b) => rank(a) - rank(b) || a.dueDate.compareTo(b.dueDate) || compareIds(a.id, b.id));

  let remaining = payment;
  const allocations: ChargeAllocation[] = [];
  for (const charge of ordered) {
    if (remaining.isZero) break;
    const applied = Money.min(remaining, charge.outstanding);
    allocations.push({ chargeId: charge.id, amount: applied });
    remaining = remaining.minus(applied);
  }
  return { allocations, unallocated: remaining };
}
