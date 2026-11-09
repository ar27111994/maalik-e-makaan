/**
 * Shared fast-check arbitraries for the property tests: amounts in paisa within
 * the ranges the code allows, and valid calendar dates. fast-check picks a new
 * seed each run and prints it with the shrunk counterexample when a property
 * fails; `fc.assert(…, { seed, path })` replays that exact case.
 */
import fc from "fast-check";
import { CalendarDate, Money, daysInMonth } from "../../src/lib/money/index.ts";
import { MAX_RENT } from "../../src/tools/input.ts";

function runsFromEnvironment(value: string | undefined): number | null {
  if (value === undefined || !/^[1-9]\d{0,7}$/.test(value)) return null;
  return Number(value);
}

/**
 * Runs per property: 500 reach the edges and keep `npm test` fast. `FC_NUM_RUNS=100000 npm
 * test` searches longer.
 */
export const RUNS = { numRuns: runsFromEnvironment(process.env.FC_NUM_RUNS) ?? 500 } as const;

/** A whole number of paisa from `min` to `max`, inclusive. */
export function paisaIn(min: bigint, max: bigint): fc.Arbitrary<Money> {
  return fc.bigInt({ min, max }).map((paisa) => Money.fromPaisa(paisa));
}

/** Any amount `numeric(14,2)` can store: ±999,999,999,999.99. */
export const storedAmount = paisaIn(Money.MIN_VALUE.paisa, Money.MAX_VALUE.paisa);

/** Any amount from zero to the storage maximum. */
export const nonNegativeAmount = paisaIn(0n, Money.MAX_VALUE.paisa);

/** A rent the calculators accept: one paisa to Rs 10 crore (`MAX_RENT`). */
export const calculatorRent = paisaIn(1n, MAX_RENT.paisa);

/** A whole-rupee amount from `min` to `max` rupees. */
export function rupeesIn(min: number, max: number): fc.Arbitrary<Money> {
  return fc.integer({ min, max }).map((rupees) => Money.fromRupees(rupees));
}

/** A valid date with a year from `minYear` to `maxYear`; every day of the month is possible. */
export function calendarDate(minYear = 1, maxYear = 9999): fc.Arbitrary<CalendarDate> {
  return fc
    .tuple(fc.integer({ min: minYear, max: maxYear }), fc.integer({ min: 1, max: 12 }))
    .chain(([year, month]) =>
      fc
        .integer({ min: 1, max: daysInMonth(year, month) })
        .map((day) => new CalendarDate(year, month, day)),
    );
}
