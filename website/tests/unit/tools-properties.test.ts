// Properties of the three calculators over any input their forms accept: the
// results are whole paisa and never negative, they move the way the rules say
// (more days of tenancy, a higher increase or a higher rent never give less),
// what a calculator writes it reads back, and every result renders in both
// languages without a negative amount.
import fc from "fast-check";
import { describe, expect, test } from "vitest";
import type { Locale } from "../../src/i18n/locales.ts";
import {
  CalendarDate,
  DateRange,
  Money,
  MonthPeriod,
  RENT_ROUNDING,
  billedRent,
  daysInMonth,
  incrementedRent,
  percentFromBasisPoints,
  proratedRent,
  toUrduDigits,
  type RentRounding,
} from "../../src/lib/money/index.ts";
import { LEFT_TO_RIGHT_MARK } from "../../src/lib/money/format.ts";
import {
  PRESCRIBED_INDIVIDUAL_THRESHOLD,
  type Payee,
  type Tenant,
} from "../../src/lib/tax/s155.ts";
import { incrementCalculator, incrementSchedule } from "../../src/tools/increment.ts";
import { MAX_RENT, money } from "../../src/tools/input.ts";
import { prorate, prorationCalculator } from "../../src/tools/proration.ts";
import type { ResultView, Segment } from "../../src/tools/types.ts";
import {
  grossAnnualRent,
  withholdingCalculator,
  withholdingFor,
  type RentPeriod,
} from "../../src/tools/withholding.ts";
import { RUNS, calculatorRent, calendarDate } from "./arbitraries.ts";

const locale = fc.constantFrom<Locale>("en", "ur");
const roundings = Object.keys(RENT_ROUNDING) as RentRounding[];

/** Every string a result shows. */
function strings(view: ResultView): string[] {
  const text = (parts: readonly Segment[]) =>
    parts.map((part) => (typeof part === "string" ? part : part.math)).join("");
  return [
    view.summary,
    ...view.figures.flatMap((figure) => [figure.label, figure.value]),
    ...view.steps.map(text),
    ...(view.table === undefined
      ? []
      : [view.table.caption, ...view.table.head, ...view.table.rows.flat()]),
    ...view.notes,
  ];
}

/**
 * A negative amount as formatMoney writes it: a left-to-right mark, then the minus sign. A
 * result says a fall in words instead (DESIGN.md); the "−" of the working is subtraction.
 */
const NEGATIVE_AMOUNT = new RegExp(`${LEFT_TO_RIGHT_MARK}-`, "u");

/** The day, month and year fields as a reader types them, in Western or Urdu digits. */
function dateFields(date: CalendarDate, urduDigits: boolean) {
  const write = (value: number) => (urduDigits ? toUrduDigits(String(value)) : String(value));
  return { day: write(date.day), month: write(date.month), year: write(date.year) };
}

describe("the first-month rent calculator", () => {
  /** The calculator's own range of years: 2000 to 2100. */
  const start = calendarDate(2000, 2100);

  test("property: counts the days from the first day to the month's end, both included", () => {
    fc.assert(
      fc.property(calculatorRent, start, (rent, first) => {
        const result = prorate({ rent, start: first });
        expect(result.period.contains(first)).toBe(true);
        expect(result.daysInMonth).toBe(daysInMonth(first.year, first.month));
        expect(result.days).toBe(result.daysInMonth - first.day + 1);
        expect(result.days).toBeGreaterThanOrEqual(1);
        expect(result.nextMonth.equals(result.period.last.addDays(1))).toBe(true);
        expect(result.nextMonth.day).toBe(1);
      }),
      RUNS,
    );
  });

  test("property: between nothing and the rent; whole rupees for a part month", () => {
    fc.assert(
      fc.property(calculatorRent, start, (rent, first) => {
        const { amount, days, daysInMonth: length } = prorate({ rent, start: first });
        expect(amount.isNegative).toBe(false);
        expect(amount.lte(rent)).toBe(true);
        if (first.day === 1) {
          expect(amount.equals(rent)).toBe(true);
          return;
        }
        // Whole rupees, unless rounding up would pass a rent with paisa (then the rent).
        expect(amount.paisa % 100n === 0n || amount.equals(rent)).toBe(true);
        // Within half a rupee of rent × days ÷ days in the month.
        const error = amount.paisa * BigInt(length) - rent.paisa * BigInt(days);
        expect((error < 0n ? -error : error) <= 50n * BigInt(length)).toBe(true);
      }),
      RUNS,
    );
  });

  test("property: more days of tenancy, or a higher rent, never lower the first month's rent", () => {
    fc.assert(
      fc.property(
        calculatorRent,
        calculatorRent,
        start,
        fc.integer({ min: 1, max: 31 }),
        (a, b, first, otherDay) => {
          const other = MonthPeriod.of(first).dayClamped(otherDay);
          const [sooner, later] = first.isOnOrBefore(other) ? [first, other] : [other, first];
          const amount = (rent: Money, from: CalendarDate) => prorate({ rent, start: from }).amount;
          expect(amount(a, sooner).gte(amount(a, later))).toBe(true);
          const [low, high] = a.lte(b) ? [a, b] : [b, a];
          expect(amount(low, first).lte(amount(high, first))).toBe(true);
        },
      ),
      RUNS,
    );
  });

  test("property: the same figure as the ledger's first billed month", () => {
    fc.assert(
      fc.property(calculatorRent, start, (rent, first) => {
        const { amount, period } = prorate({ rent, start: first });
        const billed = billedRent({
          monthlyRent: rent,
          period,
          billingStartsOn: first,
          prorateFirstMonth: true,
        });
        expect(amount.equals(billed)).toBe(true);
        expect(
          amount.equals(
            proratedRent({ monthlyRent: rent, period, occupancy: new DateRange(first) }),
          ),
        ).toBe(true);
      }),
      RUNS,
    );
  });

  test("property: what the calculator writes, it reads back, and the result renders", () => {
    fc.assert(
      fc.property(calculatorRent, start, locale, fc.boolean(), (rent, first, lang, urdu) => {
        const parsed = prorationCalculator.parse(
          { rent: money(rent, lang), ...dateFields(first, urdu) },
          lang,
        );
        expect(parsed.ok).toBe(true);
        if (!parsed.ok) return;
        expect(parsed.value.rent.equals(rent)).toBe(true);
        expect(parsed.value.start.equals(first)).toBe(true);
        for (const shown of strings(prorationCalculator.view(parsed.value, lang))) {
          expect(shown, shown).not.toMatch(NEGATIVE_AMOUNT);
        }
      }),
      RUNS,
    );
  });
});

describe("the rent increase calculator", () => {
  const increase = fc.integer({ min: 0, max: 10_000 });
  const rounding = fc.constantFrom(...roundings);
  const years = fc.integer({ min: 1, max: 10 });

  test("property: one row a year, each a whole step, each change from the year before", () => {
    fc.assert(
      fc.property(calculatorRent, increase, rounding, years, (rent, basisPoints, step, count) => {
        const schedule = incrementSchedule({ rent, basisPoints, rounding: step, years: count });
        expect(schedule.map((row) => row.year)).toEqual(
          Array.from({ length: count }, (_, index) => index + 1),
        );
        const stepPaisa = BigInt(RENT_ROUNDING[step]) * 100n;
        let previous = rent;
        for (const row of schedule) {
          expect(row.rent.paisa % stepPaisa).toBe(0n);
          expect(row.rent.isNegative).toBe(false);
          expect(row.increase.equals(row.rent.minus(previous))).toBe(true);
          expect(row.rent.equals(incrementedRent(previous, { basisPoints, rounding: step }))).toBe(
            true,
          );
          previous = row.rent;
        }
      }),
      RUNS,
    );
  });

  test("property: a higher percentage or a higher rent never lowers any year's rent", () => {
    fc.assert(
      fc.property(
        calculatorRent,
        calculatorRent,
        increase,
        increase,
        rounding,
        years,
        (a, b, p, q, step, count) => {
          const schedule = (rent: Money, basisPoints: number) =>
            incrementSchedule({ rent, basisPoints, rounding: step, years: count });
          const [low, high] = a.lte(b) ? [a, b] : [b, a];
          const [less, more] = p <= q ? [p, q] : [q, p];
          const base = schedule(low, less);
          const higherRate = schedule(low, more);
          const higherRent = schedule(high, less);
          base.forEach((row, index) => {
            expect(row.rent.lte(higherRate[index]?.rent ?? Money.ZERO)).toBe(true);
            expect(row.rent.lte(higherRent[index]?.rent ?? Money.ZERO)).toBe(true);
          });
        },
      ),
      RUNS,
    );
  });

  test("property: when the increase is at least half the step, no year's rent falls", () => {
    fc.assert(
      fc.property(calculatorRent, increase, rounding, years, (rent, basisPoints, step, count) => {
        const stepPaisa = BigInt(RENT_ROUNDING[step]) * 100n;
        // rent × bp ÷ 10,000 ≥ step ÷ 2, in whole numbers; later years only start higher.
        fc.pre(rent.paisa * BigInt(basisPoints) * 2n >= stepPaisa * 10_000n);
        const schedule = incrementSchedule({ rent, basisPoints, rounding: step, years: count });
        expect(schedule.every((row) => !row.increase.isNegative)).toBe(true);
      }),
      RUNS,
    );
  });

  test("property: what the calculator writes, it reads back, and a fall is said in words", () => {
    fc.assert(
      fc.property(
        calculatorRent,
        increase,
        rounding,
        years,
        locale,
        (rent, basisPoints, step, count, lang) => {
          const parsed = incrementCalculator.parse(
            {
              rent: money(rent, lang),
              percent: `${percentFromBasisPoints(basisPoints)}%`,
              rounding: step,
              years: String(count),
            },
            lang,
          );
          expect(parsed).toEqual({
            ok: true,
            value: { rent, basisPoints, rounding: step, years: count },
          });
          if (!parsed.ok) return;
          for (const shown of strings(incrementCalculator.view(parsed.value, lang))) {
            expect(shown, shown).not.toMatch(NEGATIVE_AMOUNT);
          }
        },
      ),
      RUNS,
    );
  });
});

describe("the section 155 calculator", () => {
  const period = fc.constantFrom<RentPeriod>("month", "year");
  const payee = fc.constantFrom<Payee>("individual", "company");
  const tenant = fc.constantFrom<Tenant>("individual", "organisation");
  const input = fc.record({
    rent: calculatorRent,
    period,
    payee,
    onActiveTaxpayersList: fc.boolean(),
    tenant,
  });

  test("property: a monthly rent is the same as twelve times it a year", () => {
    fc.assert(
      fc.property(input, (monthly) => {
        const yearly = { ...monthly, rent: monthly.rent.multiply(12), period: "year" as const };
        const a = withholdingFor({ ...monthly, period: "month" });
        const b = withholdingFor(yearly);
        expect(a.gross.equals(monthly.rent.multiply(12))).toBe(true);
        expect(a.gross.equals(b.gross)).toBe(true);
        expect(a.result.annual.equals(b.result.annual)).toBe(true);
        expect(a.mustWithhold).toBe(b.mustWithhold);
        expect(grossAnnualRent({ rent: monthly.rent, period: "year" })).toBe(monthly.rent);
      }),
      RUNS,
    );
  });

  test("property: never negative, never less for more rent, and who withholds is the rule's", () => {
    fc.assert(
      fc.property(input, calculatorRent, (first, otherRent) => {
        const [low, high] = first.rent.lte(otherRent)
          ? [first.rent, otherRent]
          : [otherRent, first.rent];
        const lower = withholdingFor({ ...first, rent: low });
        const higher = withholdingFor({ ...first, rent: high });
        expect(lower.result.annual.isNegative).toBe(false);
        expect(lower.result.monthlyEvenSpread.isNegative).toBe(false);
        expect(lower.result.annual.lte(higher.result.annual)).toBe(true);
        expect(lower.mustWithhold).toBe(
          first.tenant === "organisation" || lower.gross.gte(PRESCRIBED_INDIVIDUAL_THRESHOLD),
        );
        // A tenant who must withhold at some rent must withhold at any higher rent.
        if (lower.mustWithhold) expect(higher.mustWithhold).toBe(true);
      }),
      RUNS,
    );
  });

  test("property: what the calculator writes, it reads back, and the result renders", () => {
    fc.assert(
      fc.property(input, locale, (value, lang) => {
        const parsed = withholdingCalculator.parse(
          {
            rent: money(value.rent, lang),
            period: value.period,
            payee: value.payee,
            atl: value.onActiveTaxpayersList ? "yes" : "no",
            tenant: value.tenant,
          },
          lang,
        );
        expect(parsed).toEqual({ ok: true, value });
        if (!parsed.ok) return;
        for (const shown of strings(withholdingCalculator.view(parsed.value, lang))) {
          expect(shown, shown).not.toMatch(NEGATIVE_AMOUNT);
        }
      }),
      RUNS,
    );
  });

  test("every rent the form accepts is at most Rs 10 crore, and a negative amount is caught", () => {
    expect(MAX_RENT.equals(Money.fromRupees(100_000_000))).toBe(true);
    expect(money(Money.fromRupees(-499), "en")).toMatch(NEGATIVE_AMOUNT);
    expect(money(Money.fromRupees(-499), "ur")).toMatch(NEGATIVE_AMOUNT);
  });
});
