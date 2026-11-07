// Contract tests: the website's calculators must agree with the app (mm_core)
// and the database for every vector in contracts/rent_math_vectors.json. The
// Dart side is asserted by packages/mm_core/test/contract/rent_math_contract_test.dart
// and the SQL side by supabase/tests/database/10_contract_vectors.test.sql.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import {
  CalendarDate,
  DateRange,
  Money,
  MonthPeriod,
  billedRent,
  billingDueDate,
  dueDate,
  lateFeeFor,
  lateFeePolicyFromColumns,
  nextAnniversary,
  planFifoAllocation,
  proratedRent,
} from "../../src/lib/money/index.ts";

const VECTORS_URL = new URL("../../../contracts/rent_math_vectors.json", import.meta.url);
const vectors = JSON.parse(readFileSync(VECTORS_URL, "utf8")) as Record<string, unknown>;

type Vector = Record<string, unknown>;
const TESTED_GROUPS = [
  "due_date",
  "billing_due_date",
  "prorated_rent",
  "next_anniversary",
  "late_fee",
  "allocation",
  "billed_rent",
] as const;

function cases(group: (typeof TESTED_GROUPS)[number]): Vector[] {
  const list = vectors[group];
  if (!Array.isArray(list) || list.length === 0) throw new Error(`no vectors for ${group}`);
  return list as Vector[];
}

const str = (value: unknown): string => {
  if (typeof value !== "string")
    throw new TypeError(`expected a string, got ${JSON.stringify(value)}`);
  return value;
};
const int = (value: unknown): number => {
  if (typeof value !== "number" || !Number.isInteger(value))
    throw new TypeError(`expected an integer, got ${JSON.stringify(value)}`);
  return value;
};
const date = (value: unknown) => CalendarDate.parse(str(value));
const month = (value: unknown) => MonthPeriod.parse(str(value));
const money = (value: unknown) => Money.parseDecimal(str(value));

describe("the contract file", () => {
  test("every vector group is exercised here, so a new group cannot be skipped silently", () => {
    const groups = Object.keys(vectors).filter((key) => !key.startsWith("$"));
    expect(groups.toSorted()).toEqual([...TESTED_GROUPS].toSorted());
  });
});

describe("due_date", () => {
  test.each(cases("due_date"))("$month day $due_day", (v) => {
    expect(dueDate(month(v.month), int(v.due_day)).toIso()).toBe(str(v.expected));
  });
});

describe("billing_due_date", () => {
  test.each(cases("billing_due_date"))("$month from $billing_starts_on", (v) => {
    expect(billingDueDate(month(v.month), int(v.due_day), date(v.billing_starts_on)).toIso()).toBe(
      str(v.expected),
    );
  });
});

describe("prorated_rent", () => {
  test.each(cases("prorated_rent"))("$monthly_rent from $billing_starts_on", (v) => {
    const result = proratedRent({
      monthlyRent: money(v.monthly_rent),
      period: month(v.month),
      occupancy: new DateRange(date(v.billing_starts_on)),
    });
    expect(result.toDecimalString()).toBe(str(v.expected));
  });
});

describe("next_anniversary", () => {
  test.each(cases("next_anniversary"))("$start as of $as_of every $interval_months months", (v) => {
    expect(nextAnniversary(date(v.start), date(v.as_of), int(v.interval_months)).toIso()).toBe(
      str(v.expected),
    );
  });
});

describe("allocation", () => {
  test.each(cases("allocation"))("$name", (v) => {
    const charges = (v.charges as Vector[]).map((c) => ({
      id: str(c.id),
      dueDate: date(c.due_date),
      outstanding: money(c.outstanding),
    }));
    const plan = planFifoAllocation(money(v.payment), charges, {
      chosenChargeIds: (v.chosen_charge_ids as unknown[]).map(str),
    });
    expect(
      plan.allocations.map((a) => ({ charge_id: a.chargeId, amount: a.amount.toDecimalString() })),
    ).toEqual(v.expected_allocations);
    expect(plan.unallocated.toDecimalString()).toBe(str(v.expected_unallocated));
  });
});

describe("billed_rent", () => {
  test.each(cases("billed_rent"))(
    "$monthly_rent for $month from $billing_starts_on (prorate $prorate_first_month)",
    (v) => {
      const result = billedRent({
        monthlyRent: money(v.monthly_rent),
        period: month(v.month),
        billingStartsOn: date(v.billing_starts_on),
        prorateFirstMonth: v.prorate_first_month === true,
      });
      expect(result.toDecimalString()).toBe(str(v.expected));
    },
  );
});

describe("late_fee", () => {
  test.each(cases("late_fee"))(
    "$type $value (cap $cap) on $outstanding after $days_late days",
    (v) => {
      const policy = lateFeePolicyFromColumns({ type: str(v.type), value: v.value, cap: v.cap });
      const fee = lateFeeFor(policy, {
        overdueAmount: money(v.outstanding),
        daysLate: int(v.days_late),
        graceDays: int(v.grace_days),
      });
      expect(fee.toDecimalString()).toBe(str(v.expected));
    },
  );
});
