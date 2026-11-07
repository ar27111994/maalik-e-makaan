import { CalendarDate, DateRange, MonthPeriod } from "./calendar.ts";
import { Money } from "./money.ts";

/**
 * The granularity a rent is rounded to after an increment. Rents in Pakistan
 * are quoted in round figures: a 10% increment on Rs 47,300 is agreed as
 * Rs 52,000 rather than Rs 52,030. Mirrors `RentRounding` in rent_math.dart.
 */
export const RENT_ROUNDING = {
  none: 1,
  nearest10: 10,
  nearest50: 50,
  nearest100: 100,
  nearest500: 500,
  nearest1000: 1000,
} as const;

export type RentRounding = keyof typeof RENT_ROUNDING;

/**
 * The due date of `period` for rent due on day `dueDay` of each month,
 * clamped to the month's length.
 */
export function dueDate(period: MonthPeriod, dueDay: number): CalendarDate {
  if (!Number.isInteger(dueDay) || dueDay < 1 || dueDay > 31) {
    throw new RangeError(`dueDay must be within 1..31, got ${dueDay}`);
  }
  return period.dayClamped(dueDay);
}

/**
 * The due date of a billed month, never before billing starts: a tenant who
 * moves in on the 15th is not due on the 5th.
 */
export function billingDueDate(
  period: MonthPeriod,
  dueDay: number,
  billingStartsOn: CalendarDate,
): CalendarDate {
  return CalendarDate.max(dueDate(period, dueDay), billingStartsOn);
}

/** Number of days of `period` covered by `occupancy`. */
export function occupiedDays(period: MonthPeriod, occupancy: DateRange): number {
  return new DateRange(period.first, period.last).intersection(occupancy)?.lengthInDays ?? 0;
}

/**
 * Rent for `period` when `occupancy` covers only part of the month:
 * `monthlyRent × occupiedDays ÷ daysInMonth`, using the actual number of days
 * in that month, rounded once, half-up, to whole rupees, and never above
 * `monthlyRent`. A fully occupied month returns `monthlyRent`. Identical to the
 * database's `app.prorated_rent` (checked by the contract vectors).
 */
export function proratedRent({
  monthlyRent,
  period,
  occupancy,
}: {
  monthlyRent: Money;
  period: MonthPeriod;
  occupancy: DateRange;
}): Money {
  const days = occupiedDays(period, occupancy);
  if (days === period.lengthInDays) return monthlyRent;
  if (days === 0) return Money.ZERO;
  return Money.min(monthlyRent, monthlyRent.multiplyToStep(days, period.lengthInDays));
}

/**
 * The rent the ledger bills for `period`, exactly as the database's
 * `sync_lease_billing` generates it: nothing before the month billing starts;
 * in that month, a prorated amount when `prorateFirstMonth` is set and billing
 * starts after the 1st; every later month in full.
 */
export function billedRent({
  monthlyRent,
  period,
  billingStartsOn,
  prorateFirstMonth,
}: {
  monthlyRent: Money;
  period: MonthPeriod;
  billingStartsOn: CalendarDate;
  prorateFirstMonth: boolean;
}): Money {
  const firstMonth = MonthPeriod.of(billingStartsOn);
  if (period.compareTo(firstMonth) < 0) return Money.ZERO;
  if (!period.equals(firstMonth) || !prorateFirstMonth) return monthlyRent;
  return proratedRent({ monthlyRent, period, occupancy: new DateRange(billingStartsOn) });
}

/**
 * The rent after an increment of `basisPoints` (10% = 1000), rounded half-up
 * to `rounding` (nearest Rs 100 by default).
 */
export function incrementedRent(
  currentRent: Money,
  { basisPoints, rounding = "nearest100" }: { basisPoints: number; rounding?: RentRounding },
): Money {
  if (!Number.isSafeInteger(basisPoints) || basisPoints < 0) {
    throw new RangeError(`basisPoints must be a non-negative integer, got ${basisPoints}`);
  }
  return currentRent.multiplyToStep(10_000 + basisPoints, 10_000, {
    stepRupees: RENT_ROUNDING[rounding],
  });
}

/**
 * The first anniversary of `leaseStart` (every `intervalMonths`) on or after
 * `asOf`. Before the first anniversary this is `leaseStart + intervalMonths`.
 */
export function nextAnniversary(
  leaseStart: CalendarDate,
  asOf: CalendarDate,
  intervalMonths = 12,
): CalendarDate {
  if (!Number.isInteger(intervalMonths) || intervalMonths <= 0) {
    throw new RangeError(`intervalMonths must be > 0, got ${intervalMonths}`);
  }
  let cycles = 1;
  if (asOf.isAfter(leaseStart)) {
    const monthsElapsed = MonthPeriod.of(asOf).monthsSince(MonthPeriod.of(leaseStart));
    cycles = Math.max(1, Math.floor(monthsElapsed / intervalMonths));
  }
  let candidate = leaseStart.addMonths(cycles * intervalMonths);
  while (candidate.isBefore(asOf)) {
    cycles += 1;
    candidate = leaseStart.addMonths(cycles * intervalMonths);
  }
  return candidate;
}

/**
 * Every rent period from the month containing `start` through the month
 * containing `until`, clipped to the lease `end` if any.
 */
export function billablePeriods({
  start,
  until,
  end = null,
}: {
  start: CalendarDate;
  until: CalendarDate;
  end?: CalendarDate | null;
}): MonthPeriod[] {
  const last = end === null ? until : CalendarDate.min(until, end);
  if (last.isBefore(start)) return [];
  return MonthPeriod.range(MonthPeriod.of(start), MonthPeriod.of(last));
}
