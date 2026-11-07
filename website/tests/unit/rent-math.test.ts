// Ports of packages/mm_core/test/rent/*, test/ledger/allocation_test.dart and test/time/*.
import { describe, expect, test } from "vitest";
import {
  CalendarDate,
  DateRange,
  MAX_LATE_FEE,
  Money,
  MonthPeriod,
  RENT_ROUNDING,
  TaxYear,
  billablePeriods,
  billedRent,
  billingDueDate,
  daysInMonth,
  dueDate,
  incrementedRent,
  isLeapYear,
  lateFeeFor,
  lateFeePolicyFromColumns,
  nextAnniversary,
  occupiedDays,
  planFifoAllocation,
  proratedRent,
  type LateFeePolicy,
} from "../../src/lib/money/index.ts";
import { mulberry32 } from "./random.ts";

const d = (iso: string) => CalendarDate.parse(iso);
const rent = Money.fromRupees(45000);
const nov = new MonthPeriod(2026, 11);

describe("CalendarDate", () => {
  test("rejects impossible dates and parses strict ISO dates only", () => {
    expect(() => new CalendarDate(2026, 2, 29)).toThrow(RangeError);
    expect(() => new CalendarDate(2026, 13, 1)).toThrow(RangeError);
    expect(() => new CalendarDate(0, 1, 1)).toThrow(RangeError);
    expect(new CalendarDate(2028, 2, 29).toIso()).toBe("2028-02-29");
    for (const bad of ["2026-2-1", "2026-02-30", "26-02-01", "2026-02-01T00:00", "x"]) {
      expect(CalendarDate.tryParse(bad), bad).toBeNull();
    }
    expect(() => CalendarDate.parse("x")).toThrow(SyntaxError);
  });

  test("leap years and month lengths", () => {
    expect([1900, 2000, 2024, 2026].map(isLeapYear)).toEqual([false, true, true, false]);
    expect(daysInMonth(2028, 2)).toBe(29);
    expect(daysInMonth(2026, 2)).toBe(28);
    expect(() => daysInMonth(2026, 0)).toThrow(RangeError);
  });

  test("day arithmetic is exact across years, including years before 100", () => {
    expect(d("2026-12-31").addDays(1).toIso()).toBe("2027-01-01");
    expect(d("2028-03-01").addDays(-1).toIso()).toBe("2028-02-29");
    expect(d("2027-01-01").differenceInDays(d("2026-01-01"))).toBe(365);
    expect(d("0050-03-01").addDays(-1).toIso()).toBe("0050-02-28");
    expect(d("0001-01-01").addDays(366).toIso()).toBe("0002-01-02");
  });

  test("weekdays (ISO: Monday is 1)", () => {
    expect(d("2026-11-05").weekday).toBe(4); // a Thursday
    expect(d("1970-01-01").weekday).toBe(4);
    expect(d("2026-11-08").weekday).toBe(7);
  });

  test("month arithmetic clamps the day", () => {
    expect(d("2026-01-31").addMonths(1).toIso()).toBe("2026-02-28");
    expect(d("2024-02-29").addYears(1).toIso()).toBe("2025-02-28");
    expect(d("2026-03-15").addMonths(-3).toIso()).toBe("2025-12-15");
  });

  test("property: addDays and differenceInDays agree (seeded)", () => {
    const random = mulberry32(7);
    for (let i = 0; i < 2000; i++) {
      // Years 30–9929 keep start ± 10,000 days inside the supported 1–9999.
      const start = new CalendarDate(30 + random.int(9900), 1 + random.int(12), 1 + random.int(28));
      const days = random.int(20000) - 10000;
      const end = start.addDays(days);
      expect(end.differenceInDays(start)).toBe(days);
      expect(end.addDays(-days).equals(start)).toBe(true);
    }
  });
});

describe("MonthPeriod, DateRange and TaxYear", () => {
  test("months", () => {
    expect(MonthPeriod.parse("2026-11").last.toIso()).toBe("2026-11-30");
    expect(MonthPeriod.parse("2026-11-15").equals(nov)).toBe(true);
    expect(() => MonthPeriod.parse("2026-13")).toThrow(SyntaxError);
    expect(nov.addMonths(2).toIso()).toBe("2027-01");
    expect(nov.addMonths(-11).toIso()).toBe("2025-12");
    expect(MonthPeriod.range(nov, nov.addMonths(2)).map(String)).toEqual([
      "2026-11",
      "2026-12",
      "2027-01",
    ]);
    expect(MonthPeriod.range(nov, nov.addMonths(-1))).toEqual([]);
    expect(nov.dayClamped(31).toIso()).toBe("2026-11-30");
  });

  test("ranges", () => {
    const open = new DateRange(d("2026-11-15"));
    expect(open.lengthInDays).toBeNull();
    expect(open.contains(d("2099-01-01"))).toBe(true);
    expect(new DateRange(d("2026-11-01"), d("2026-11-30")).intersection(open)?.lengthInDays).toBe(
      16,
    );
    expect(new DateRange(d("2026-01-01"), d("2026-01-31")).intersection(open)).toBeNull();
    expect(() => new DateRange(d("2026-11-02"), d("2026-11-01"))).toThrow(RangeError);
  });

  test("tax years run from July to June and are named after the year they end", () => {
    const ty = TaxYear.containing(d("2026-11-05"));
    expect(ty.label).toBe("TY2027");
    expect(ty.spanLabel).toBe("2026-27");
    expect(ty.start.toIso()).toBe("2026-07-01");
    expect(ty.end.toIso()).toBe("2027-06-30");
    expect(TaxYear.containing(d("2026-06-30")).label).toBe("TY2026");
    expect(ty.contains(d("2027-06-30"))).toBe(true);
    expect(ty.contains(d("2027-07-01"))).toBe(false);
  });
});

describe("due dates", () => {
  test("clamp to the month and reject impossible due days", () => {
    expect(dueDate(nov, 5).toIso()).toBe("2026-11-05");
    expect(dueDate(new MonthPeriod(2026, 2), 31).toIso()).toBe("2026-02-28");
    expect(() => dueDate(nov, 0)).toThrow(RangeError);
    expect(() => dueDate(nov, 32)).toThrow(RangeError);
  });

  test("are never before billing starts", () => {
    expect(billingDueDate(nov, 5, d("2026-11-15")).toIso()).toBe("2026-11-15");
    expect(billingDueDate(nov.addMonths(1), 5, d("2026-11-15")).toIso()).toBe("2026-12-05");
  });
});

describe("proration (actual days in the month)", () => {
  test("a full month is the rent; a mid-month start is prorated and rounded half-up", () => {
    expect(
      proratedRent({ monthlyRent: rent, period: nov, occupancy: new DateRange(d("2026-10-01")) }),
    ).toBe(rent);
    // 16 of 30 days: 45,000 × 16 ÷ 30 = 24,000.
    expect(
      proratedRent({
        monthlyRent: rent,
        period: nov,
        occupancy: new DateRange(d("2026-11-15")),
      }).toDecimalString(),
    ).toBe("24000.00");
    // 1 of 31 days: 10,001 ÷ 31 = 322.61, rounded to 323.
    expect(
      proratedRent({
        monthlyRent: Money.fromRupees(10001),
        period: new MonthPeriod(2026, 12),
        occupancy: new DateRange(d("2026-12-31")),
      }).toDecimalString(),
    ).toBe("323.00");
  });

  test("rounding never lifts a prorated month above the rent", () => {
    const tiny = Money.parseDecimal("0.90");
    expect(
      proratedRent({
        monthlyRent: tiny,
        period: new MonthPeriod(2026, 1),
        occupancy: new DateRange(d("2026-01-02")),
      }),
    ).toBe(tiny);
  });

  test("move-out and no-overlap cases", () => {
    expect(
      proratedRent({
        monthlyRent: rent,
        period: nov,
        occupancy: new DateRange(d("2026-01-01"), d("2026-11-10")),
      }).toDecimalString(),
    ).toBe("15000.00");
    expect(
      proratedRent({ monthlyRent: rent, period: nov, occupancy: new DateRange(d("2027-01-01")) })
        .isZero,
    ).toBe(true);
    expect(occupiedDays(new MonthPeriod(2028, 2), new DateRange(d("2028-02-20")))).toBe(10);
  });

  test("billed rent: nothing before billing starts; only the first month is prorated, if chosen", () => {
    const billed = (period: MonthPeriod, prorate = true) =>
      billedRent({
        monthlyRent: rent,
        period,
        billingStartsOn: d("2026-11-15"),
        prorateFirstMonth: prorate,
      });
    expect(billed(new MonthPeriod(2026, 10)).isZero).toBe(true);
    expect(billed(nov).toDecimalString()).toBe("24000.00");
    expect(billed(nov, false)).toBe(rent);
    expect(billed(nov.addMonths(1))).toBe(rent);
  });
});

describe("increments", () => {
  const base = Money.fromRupees(47300);
  const after = (rounding?: keyof typeof RENT_ROUNDING) =>
    incrementedRent(
      base,
      rounding === undefined ? { basisPoints: 1000 } : { basisPoints: 1000, rounding },
    ).toDecimalString();

  test("10% rounded to the nearest Rs 100 by default", () => {
    expect(incrementedRent(rent, { basisPoints: 1000 }).toDecimalString()).toBe("49500.00");
    expect(after()).toBe("52000.00");
  });

  test("other rounding steps, zero and negative increments", () => {
    expect(after("none")).toBe("52030.00");
    expect(after("nearest10")).toBe("52030.00");
    expect(after("nearest50")).toBe("52050.00");
    expect(after("nearest500")).toBe("52000.00");
    expect(after("nearest1000")).toBe("52000.00");
    expect(incrementedRent(base, { basisPoints: 0 }).equals(base)).toBe(true);
    expect(() => incrementedRent(base, { basisPoints: -1 })).toThrow(RangeError);
    expect(Object.values(RENT_ROUNDING)).toEqual([1, 10, 50, 100, 500, 1000]);
  });
});

describe("anniversaries and billable periods", () => {
  const start = d("2025-03-15");

  test("before, on and after anniversaries", () => {
    expect(nextAnniversary(start, d("2025-01-01")).toIso()).toBe("2026-03-15");
    expect(nextAnniversary(start, start).toIso()).toBe("2026-03-15");
    expect(nextAnniversary(start, d("2025-12-01")).toIso()).toBe("2026-03-15");
    expect(nextAnniversary(start, d("2026-03-15")).toIso()).toBe("2026-03-15");
    expect(nextAnniversary(start, d("2026-03-16")).toIso()).toBe("2027-03-15");
    expect(nextAnniversary(start, d("2030-01-01")).toIso()).toBe("2030-03-15");
  });

  test("11-month cycles, leap-day starts and invalid intervals", () => {
    expect(nextAnniversary(start, d("2026-03-01"), 11).toIso()).toBe("2027-01-15");
    expect(nextAnniversary(d("2024-02-29"), d("2025-01-01")).toIso()).toBe("2025-02-28");
    expect(() => nextAnniversary(start, start, 0)).toThrow(RangeError);
  });

  test("periods from the start month through until, clipped to the end", () => {
    expect(billablePeriods({ start: d("2026-09-15"), until: d("2026-11-03") }).map(String)).toEqual(
      ["2026-09", "2026-10", "2026-11"],
    );
    expect(
      billablePeriods({ start: d("2026-09-15"), until: d("2027-03-01"), end: d("2026-10-10") }).map(
        String,
      ),
    ).toEqual(["2026-09", "2026-10"]);
    expect(billablePeriods({ start: d("2027-01-01"), until: d("2026-11-03") })).toEqual([]);
  });
});

describe("late fees", () => {
  const owed = Money.fromRupees(40000);
  const fee = (policy: LateFeePolicy, daysLate: number, graceDays = 5, overdueAmount = owed) =>
    lateFeeFor(policy, { overdueAmount, daysLate, graceDays }).toDecimalString();

  test("decode every type from the database columns", () => {
    expect(lateFeePolicyFromColumns({ type: "none" })).toEqual({ type: "none" });
    expect(lateFeePolicyFromColumns({ type: "flat", value: "1000.00" })).toEqual({
      type: "flat",
      amount: Money.fromRupees(1000),
    });
    expect(lateFeePolicyFromColumns({ type: "percent", value: "2.50" })).toEqual({
      type: "percent",
      basisPoints: 250,
    });
    expect(lateFeePolicyFromColumns({ type: "daily", value: 100, cap: "2500" })).toEqual({
      type: "daily",
      perDay: Money.fromRupees(100),
      cap: Money.fromRupees(2500),
    });
  });

  test("reject unknown types and missing or negative values", () => {
    expect(() => lateFeePolicyFromColumns({ type: "weekly" })).toThrow(RangeError);
    expect(() => lateFeePolicyFromColumns({ type: "flat" })).toThrow(RangeError);
    expect(() => lateFeePolicyFromColumns({ type: "flat", value: "-1" })).toThrow(RangeError);
    expect(() => lateFeePolicyFromColumns({ type: "percent" })).toThrow(RangeError);
    expect(() => lateFeePolicyFromColumns({ type: "daily", value: null })).toThrow(RangeError);
  });

  test("no fee within the grace period or when nothing is owed", () => {
    const flat: LateFeePolicy = { type: "flat", amount: Money.fromRupees(1000) };
    expect(fee(flat, 5)).toBe("0.00");
    expect(fee(flat, 30, 5, Money.ZERO)).toBe("0.00");
    expect(fee({ type: "none" }, 60)).toBe("0.00");
    expect(() => fee(flat, 6, -1)).toThrow(RangeError);
  });

  test("policy amounts, rounded to rupees and capped after rounding", () => {
    expect(fee({ type: "flat", amount: Money.parseDecimal("499.50") }, 9, 0)).toBe("500.00");
    expect(fee({ type: "percent", basisPoints: 250 }, 6)).toBe("1000.00");
    expect(fee({ type: "daily", perDay: Money.fromRupees(100), cap: null }, 6)).toBe("600.00");
    expect(
      fee({ type: "daily", perDay: Money.fromRupees(100), cap: Money.fromRupees(2500) }, 56),
    ).toBe("2500.00");
    expect(
      fee(
        { type: "daily", perDay: Money.parseDecimal("33.35"), cap: Money.parseDecimal("99.50") },
        3,
        0,
      ),
    ).toBe("99.50");
  });

  test("fees never exceed what a charge can hold", () => {
    expect(fee({ type: "daily", perDay: Money.fromRupees(10_000_000), cap: null }, 200_000)).toBe(
      "999999999999.00",
    );
    expect(MAX_LATE_FEE.isWithinStorageRange).toBe(true);
  });
});

describe("payment allocation", () => {
  const charge = (id: string, due: string, rupees: number, isSecurityDeposit = false) => ({
    id,
    dueDate: d(due),
    outstanding: Money.fromRupees(rupees),
    isSecurityDeposit,
  });
  const summary = (plan: ReturnType<typeof planFifoAllocation>) => ({
    allocations: plan.allocations.map((a) => `${a.chargeId}:${a.amount.toDecimalString()}`),
    unallocated: plan.unallocated.toDecimalString(),
  });

  test("oldest first, ties broken by id; overpayment becomes credit", () => {
    const charges = [
      charge("c2", "2026-10-05", 40000),
      charge("c1", "2026-09-05", 40000),
      charge("c0", "2026-09-05", 20000),
    ];
    expect(summary(planFifoAllocation(Money.fromRupees(105000), charges))).toEqual({
      allocations: ["c0:20000.00", "c1:40000.00", "c2:40000.00"],
      unallocated: "5000.00",
    });
    expect(summary(planFifoAllocation(Money.ZERO, charges))).toEqual({
      allocations: [],
      unallocated: "0.00",
    });
  });

  test("a deposit adjustment never pays the security deposit", () => {
    const charges = [
      charge("deposit", "2026-01-01", 90000, true),
      charge("c-1", "2026-10-05", 40000),
    ];
    expect(
      summary(planFifoAllocation(Money.fromRupees(45000), charges, { depositAdjustment: true })),
    ).toEqual({
      allocations: ["c-1:40000.00"],
      unallocated: "5000.00",
    });
    expect(summary(planFifoAllocation(Money.fromRupees(45000), charges)).allocations).toEqual([
      "deposit:45000.00",
    ]);
  });

  test("rejects negative payments, empty charges and unknown chosen ids", () => {
    expect(() => planFifoAllocation(Money.fromRupees(-1), [])).toThrow(RangeError);
    expect(() => planFifoAllocation(Money.ZERO, [charge("x", "2026-01-01", 0)])).toThrow(
      RangeError,
    );
    expect(() => planFifoAllocation(Money.ZERO, [], { chosenChargeIds: ["nope"] })).toThrow(
      RangeError,
    );
  });

  test("property: conservation and order hold for random ledgers (seeded)", () => {
    const random = mulberry32(99);
    for (let i = 0; i < 500; i++) {
      const charges = Array.from({ length: 1 + random.int(6) }, (_, n) => ({
        id: `c${n}`,
        dueDate: new CalendarDate(2026, 1 + random.int(12), 1 + random.int(28)),
        outstanding: Money.fromPaisa(1 + random.int(10_000_000)),
      }));
      const payment = Money.fromPaisa(random.int(40_000_000));
      const plan = planFifoAllocation(payment, charges);
      expect(
        Money.sum(plan.allocations.map((a) => a.amount))
          .plus(plan.unallocated)
          .equals(payment),
      ).toBe(true);
      const dues = plan.allocations.map(
        (a) => charges.find((c) => c.id === a.chargeId)?.dueDate.toIso() ?? "",
      );
      expect(dues).toEqual(dues.toSorted());
      expect(plan.allocations.every((a) => a.amount.isPositive)).toBe(true);
    }
  });
});
