// The calculators: reading what people type (Western and Urdu digits), the
// increment and first-month rules against the research's worked examples,
// the s.155 result's wording, and both languages' results.
import { describe, expect, test } from "vitest";
import { contentHref } from "../../src/lib/content/links.ts";
import { wrapTables } from "../../src/lib/markdown/tables.ts";
import { CalendarDate, Money } from "../../src/lib/money/index.ts";
import { CHROME } from "../../src/tools/chrome.ts";
import {
  INCREMENT_EXAMPLES,
  incrementCalculator,
  incrementExampleTable,
  incrementSchedule,
} from "../../src/tools/increment.ts";
import {
  readInteger,
  readPercent,
  readRent,
  readRupees,
  rentMessage,
} from "../../src/tools/input.ts";
import {
  PRORATION_EXAMPLES,
  prorate,
  prorationCalculator,
  prorationExampleTable,
} from "../../src/tools/proration.ts";
import {
  calculatorExamples,
  renderCalculator,
  type CalculatorName,
} from "../../src/tools/registry.ts";
import type { ResultView, Segment } from "../../src/tools/types.ts";
import {
  grossAnnualRent,
  withholdingCalculator,
  withholdingExampleTable,
  withholdingFor,
} from "../../src/tools/withholding.ts";

const rs = (value: number) => Money.fromRupees(value);
const text = (parts: readonly Segment[]) =>
  parts.map((part) => (typeof part === "string" ? part : part.math)).join("");

/** Every string a result shows. */
function strings(view: ResultView): string[] {
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

describe("reading typed amounts", () => {
  test("rupees in Western or Urdu digits, with commas, Rs, lakh or ہزار", () => {
    for (const [input, rupees] of [
      ["45000", 45_000],
      ["45,000", 45_000],
      ["۴۵۰۰۰", 45_000],
      ["۴۵,۰۰۰", 45_000],
      ["Rs 45,000", 45_000],
      ["45,000 روپے", 45_000],
      ["1.5 lakh", 150_000],
      ["۴۵ ہزار", 45_000],
    ] as const) {
      expect(readRupees(input)?.equals(rs(rupees)), input).toBe(true);
    }
  });

  test("nothing, zero, negative, words and amounts over Rs\u00A010 crore are refused", () => {
    for (const input of ["", "  ", "0", "-500", "abc", "45,000.123", "100000001"]) {
      expect(readRupees(input), input).toBeNull();
    }
    expect(readRupees("100000000")?.equals(rs(100_000_000))).toBe(true);
  });

  test("a decimal comma is questioned, not read as a thousands separator", () => {
    // "45,5" would otherwise become Rs 455: parseMoneyInput drops every comma.
    for (const [input, suggestion] of [
      ["45,5", "45.5"],
      ["45,50", "45.50"],
      ["Rs 45,5", "45.5"],
      ["۴۵,۵", "45.5"],
      ["45,5 روپے", "45.5"],
    ] as const) {
      expect(readRent(input), input).toEqual({
        ok: false,
        problem: { kind: "decimalComma", suggestion },
      });
      expect(readRupees(input), input).toBeNull();
    }
    // Thousands and lakh grouping are still read.
    expect(readRupees("1,50,000")?.equals(rs(150_000))).toBe(true);
    expect(readRupees("45,000")?.equals(rs(45_000))).toBe(true);
  });

  test("each problem has its own message in each language", () => {
    expect(rentMessage({ kind: "decimalComma", suggestion: "45.5" }, "en", "x")).toContain(
      "did you mean 45.5?",
    );
    expect(rentMessage({ kind: "decimalComma", suggestion: "45.5" }, "ur", "x")).toContain(
      "\u206645.5\u2069",
    );
    expect(readRent("100000001")).toEqual({ ok: false, problem: { kind: "tooLarge" } });
    expect(rentMessage({ kind: "tooLarge" }, "en", "x")).toBe(
      "This calculator takes a rent of up to Rs\u00A0100,000,000 (Rs 10 crore). Check the number of zeros.",
    );
    expect(rentMessage({ kind: "format" }, "en", "the example")).toBe("the example");
    const parsed = incrementCalculator.parse(
      { rent: "100000001", percent: "10", rounding: "nearest100", years: "1" },
      "en",
    );
    expect(parsed.ok ? "" : parsed.errors.rent).toContain("up to");
  });

  test("percentages in either digits, with % or ٪, to two decimals", () => {
    expect(readPercent("10")).toBe(1000);
    expect(readPercent("۱۰")).toBe(1000);
    expect(readPercent("10%")).toBe(1000);
    expect(readPercent("۱۰٪")).toBe(1000);
    expect(readPercent("12.5")).toBe(1250);
    expect(readPercent("۱۲٫۵")).toBe(1250);
    expect(readPercent("0")).toBe(0);
    for (const input of ["", "101", "-1", "1.234", "ten"])
      expect(readPercent(input), input).toBeNull();
  });

  test("whole numbers within a range, in either digits", () => {
    expect(readInteger("15", 1, 31)).toBe(15);
    expect(readInteger("۱۵", 1, 31)).toBe(15);
    expect(readInteger("0", 1, 31)).toBeNull();
    expect(readInteger("32", 1, 31)).toBeNull();
    expect(readInteger("1.5", 1, 31)).toBeNull();
  });
});

describe("the rent increase calculator", () => {
  test("the research's examples: 45,000 → 49,500 and 37,350 → 41,100 at 10%, to Rs\u00A0100", () => {
    expect(incrementSchedule(INCREMENT_EXAMPLES[0] ?? never())[0]?.rent.equals(rs(49_500))).toBe(
      true,
    );
    expect(incrementSchedule(INCREMENT_EXAMPLES[1] ?? never())[0]?.rent.equals(rs(41_100))).toBe(
      true,
    );
    // 47,300 + 10% = 52,030, quoted as 52,000 (rent-math.ts).
    expect(incrementSchedule(INCREMENT_EXAMPLES[2] ?? never())[0]?.rent.equals(rs(52_000))).toBe(
      true,
    );
  });

  test("each later year applies the increase to the rounded rent before it", () => {
    const years = incrementSchedule({
      rent: rs(45_000),
      basisPoints: 1000,
      rounding: "nearest100",
      years: 3,
    });
    expect(years.map((year) => year.rent.wholeRupees)).toEqual([49_500n, 54_500n, 60_000n]);
    // 49,500 × 1.1 = 54,450 → 54,500; 54,500 × 1.1 = 59,950 → 60,000.
    expect(years.map((year) => year.increase.wholeRupees)).toEqual([4_500n, 5_000n, 5_500n]);
  });

  test("the result shows its working, exactly or approximately", () => {
    const view = incrementCalculator.view(
      { rent: rs(45_000), basisPoints: 1000, rounding: "nearest100", years: 2 },
      "en",
    );
    expect(view.summary).toBe(
      "After one year the rent becomes Rs\u00A049,500 a month, an increase of Rs\u00A04,500.",
    );
    expect(view.steps.map(text)).toEqual([
      "The increase is 45,000 × 10% = 4,500.00.",
      "Before rounding, the new rent is 45,000 + 4,500.00 = 49,500.00.",
      "Rounded to the nearest Rs\u00A0100, it stays 49,500.",
      "Each later year adds 10% to the rounded rent of the year before, then rounds again.",
    ]);
    expect(view.table?.rows).toEqual([
      ["Now", "Rs\u00A045,000", "–"],
      ["After 1 year", "Rs\u00A049,500", "Rs\u00A04,500"],
      ["After 2 years", "Rs\u00A054,500", "Rs\u00A05,000"],
    ]);
    const odd = incrementCalculator.view(
      { rent: Money.parseDecimal("33333.33"), basisPoints: 1050, rounding: "nearest100", years: 1 },
      "en",
    );
    expect(text(odd.steps[0] ?? [])).toContain("≈");
  });

  test("a rounding step larger than the increase: the fall is said in words, never as a bare minus", () => {
    for (const input of [
      { rent: rs(499), basisPoints: 0, rounding: "nearest1000", years: 1 },
      { rent: rs(1), basisPoints: 1, rounding: "nearest1000", years: 2 },
      { rent: rs(45_049), basisPoints: 0, rounding: "nearest100", years: 1 },
    ] as const) {
      for (const locale of ["en", "ur"] as const) {
        const view = incrementCalculator.view(input, locale);
        for (const shown of strings(view)) {
          expect(shown, shown).not.toMatch(/[-\u2212]\s*(?:Rs)?\s*\d|\d\s*[-\u2212]\s*روپے/u);
        }
      }
    }
    const en = incrementCalculator.view(
      { rent: rs(499), basisPoints: 0, rounding: "nearest1000", years: 1 },
      "en",
    );
    expect(en.summary).toBe(
      "Rounded to the nearest Rs\u00A01,000, the rent would become Rs\u00A00 a month, a decrease of Rs\u00A0499. The rounding step is larger than the increase: choose a smaller one.",
    );
    expect(en.figures[1]).toEqual({ label: "Decrease", value: "Rs\u00A0499" });
    expect(en.table?.head).toEqual(["Year", "Monthly rent", "Change"]);
    expect(en.table?.rows[1]).toEqual(["After 1 year", "Rs\u00A00", "Rs\u00A0499 less"]);
    expect(en.notes[0]).toContain("takes this rent below what it is now");
    const ur = incrementCalculator.view(
      { rent: rs(499), basisPoints: 0, rounding: "nearest1000", years: 1 },
      "ur",
    );
    expect(ur.table?.rows[1]?.[2]).toBe("499\u00A0روپے کم");
    expect(ur.figures[1]?.label).toBe("کمی");
    // A rise keeps the usual wording and column.
    const rise = incrementCalculator.view(
      { rent: rs(45_000), basisPoints: 1000, rounding: "nearest100", years: 1 },
      "en",
    );
    expect(rise.table?.head[2]).toBe("Increase");
    expect(rise.notes).toHaveLength(1);
  });

  test("the form's answers are read, or each wrong one gets its own message", () => {
    const ok = incrementCalculator.parse(
      { rent: "۴۵,۰۰۰", percent: "۱۰", rounding: "nearest500", years: "۵" },
      "ur",
    );
    expect(ok).toEqual({
      ok: true,
      value: { rent: rs(45_000), basisPoints: 1000, rounding: "nearest500", years: 5 },
    });
    const bad = incrementCalculator.parse(
      { rent: "x", percent: "200", rounding: "?", years: "11" },
      "en",
    );
    expect(bad.ok).toBe(false);
    if (!bad.ok) expect(Object.keys(bad.errors).sort()).toEqual(["percent", "rent", "years"]);
  });
});

describe("the first-month rent calculator", () => {
  test.each([
    ["2026-11-15", 45_000, 16, 30, 24_000],
    ["2027-02-15", 45_000, 14, 28, 22_500],
    ["2026-12-20", 50_000, 12, 31, 19_355],
    ["2028-02-15", 30_000, 15, 29, 15_517],
  ] as const)(
    "from %s at Rs %i: %i of %i days → Rs %i (website-facts.md §5.3)",
    (start, rent, days, of, amount) => {
      const result = prorate({ rent: rs(rent), start: CalendarDate.parse(start) });
      expect(result.days).toBe(days);
      expect(result.daysInMonth).toBe(of);
      expect(result.amount.equals(rs(amount))).toBe(true);
    },
  );

  test("a tenancy from the 1st pays the full month, and says so", () => {
    const view = prorationCalculator.view(
      { rent: rs(45_000), start: CalendarDate.parse("2026-11-01") },
      "en",
    );
    expect(view.summary).toBe(
      "A tenancy that starts on the 1st pays the full month: Rs\u00A045,000.",
    );
  });

  test("the working counts both days and rounds half up", () => {
    const view = prorationCalculator.view(
      { rent: rs(50_000), start: CalendarDate.parse("2026-12-20") },
      "en",
    );
    expect(view.summary).toBe(
      "Rent from 20\u00A0December to 31\u00A0December 2026: Rs\u00A019,355, for 12 of 31 days.",
    );
    expect(view.steps.map(text)).toEqual([
      "December 2026 has 31 days.",
      "From 20\u00A0December to 31\u00A0December 2026, counting both days, is 31 − 20 + 1 = 12 days.",
      "The rent for those days is 50,000 × 12 ÷ 31 ≈ 19,354.84.",
      "Rounded to the nearest rupee (a half rounds up): 19,355.",
    ]);
  });

  test("impossible dates are refused with one message on the date", () => {
    for (const [day, month, year] of [
      ["29", "2", "2027"],
      ["31", "4", "2026"],
      ["15", "13", "2026"],
      ["15", "11", "1999"],
      ["", "11", "2026"],
    ] as const) {
      const parsed = prorationCalculator.parse({ rent: "45000", day, month, year }, "en");
      expect(parsed.ok, `${day}/${month}/${year}`).toBe(false);
      if (!parsed.ok) expect(Object.keys(parsed.errors)).toEqual(["date"]);
    }
    expect(
      prorationCalculator.parse({ rent: "45000", day: "۲۹", month: "۲", year: "۲۰۲۸" }, "ur").ok,
    ).toBe(true);
  });
});

describe("the section 155 calculator", () => {
  test("a monthly rent is multiplied by 12; an annual one is taken as it is", () => {
    expect(grossAnnualRent({ rent: rs(100_000), period: "month" }).equals(rs(1_200_000))).toBe(
      true,
    );
    expect(grossAnnualRent({ rent: rs(1_200_000), period: "year" }).equals(rs(1_200_000))).toBe(
      true,
    );
  });

  test("the default: a company tenant, an individual landlord on the ATL, Rs\u00A0100,000 a month", () => {
    const view = withholdingCalculator.view(
      {
        rent: rs(100_000),
        period: "month",
        payee: "individual",
        onActiveTaxpayersList: true,
        tenant: "organisation",
      },
      "en",
    );
    expect(view.summary).toBe(
      "The tenant deducts Rs\u00A075,000 over the year: 6.25% of the gross rent. It counts towards your final tax; it is not your final tax.",
    );
    expect(view.steps.map(text)).toEqual([
      "The gross rent for the year is 100,000 × 12 = 1,200,000.",
      "Rs\u00A01,200,000 is over Rs\u00A0600,000 and does not exceed Rs\u00A02,000,000, so the band is Rs\u00A015,000 plus 10% of the amount over Rs\u00A0600,000.",
      "1,200,000 − 600,000 = 600,000; 10% × 600,000 = 60,000; 15,000 + 60,000 = 75,000.",
      "As a share of the gross rent: 75,000 ÷ 1,200,000 = 6.25%.",
      "Spread evenly over twelve months: 75,000 ÷ 12 ≈ 6,250 a month.",
    ]);
    expect(view.figures.map((figure) => figure.value)).toEqual([
      "Rs\u00A075,000",
      "6.25%",
      "Rs\u00A06,250",
      "Rs\u00A01,200,000",
    ]);
    expect(view.notes[0]).toMatch(/not your final tax/);
    expect(view.notes.join(" ")).not.toMatch(/doubles the rates/);
  });

  test("an individual tenant below Rs\u00A01.5 million a year is told it need not deduct", () => {
    const result = withholdingFor({
      rent: rs(100_000),
      period: "month",
      payee: "individual",
      onActiveTaxpayersList: true,
      tenant: "individual",
    });
    expect(result.mustWithhold).toBe(false);
    const view = withholdingCalculator.view(
      {
        rent: rs(100_000),
        period: "month",
        payee: "individual",
        onActiveTaxpayersList: true,
        tenant: "individual",
      },
      "en",
    );
    expect(view.summary).toMatch(/^This tenant does not have to deduct tax under section 155/);
    expect(view.figures[0]?.label).toBe("Rate-card figure for the year (for information)");
    // Rs\u00A0125,000 a month is Rs\u00A01.5 million a year: now the tenant must deduct.
    expect(
      withholdingFor({
        rent: rs(125_000),
        period: "month",
        payee: "individual",
        onActiveTaxpayersList: true,
        tenant: "individual",
      }).mustWithhold,
    ).toBe(true);
  });

  test("a landlord not on the ATL gets the doubled rate, flagged as uncertain", () => {
    const view = withholdingCalculator.view(
      {
        rent: rs(1_200_000),
        period: "year",
        payee: "individual",
        onActiveTaxpayersList: false,
        tenant: "organisation",
      },
      "en",
    );
    expect(view.figures[0]?.value).toBe("Rs\u00A0150,000");
    expect(view.notes.join(" ")).toMatch(/check this figure with a tax adviser/);
  });

  test("a company landlord: a flat rate, explained", () => {
    const view = withholdingCalculator.view(
      {
        rent: rs(100_000),
        period: "month",
        payee: "company",
        onActiveTaxpayersList: false,
        tenant: "organisation",
      },
      "en",
    );
    expect(view.figures[0]?.value).toBe("Rs\u00A0360,000");
    expect(view.steps.map(text)[1]).toBe(
      "A company not on the ATL has 30% of the gross rent deducted: 30% × 1,200,000 = 360,000.",
    );
  });

  test("a rent in the nil band says nothing is deducted, without a monthly figure to explain", () => {
    const view = withholdingCalculator.view(
      {
        rent: rs(20_000),
        period: "month",
        payee: "individual",
        onActiveTaxpayersList: true,
        tenant: "organisation",
      },
      "en",
    );
    expect(view.steps.map(text)).toEqual([
      "The gross rent for the year is 20,000 × 12 = 240,000.",
      "Rs\u00A0240,000 does not exceed Rs\u00A0300,000, so nothing is deducted.",
    ]);
  });

  test("the rate table under the calculator is the research's table", () => {
    const table = withholdingExampleTable("en");
    expect(table.rows[4]).toEqual([
      "Rs\u00A01,200,000",
      "Rs\u00A075,000",
      "Rs\u00A0150,000",
      "Rs\u00A0180,000",
      "Rs\u00A0360,000",
    ]);
    expect(table.rows[8]).toEqual([
      "Rs\u00A06,000,000",
      "Rs\u00A01,155,000",
      "Rs\u00A02,310,000",
      "Rs\u00A0900,000",
      "Rs\u00A01,800,000",
    ]);
  });
});

describe("both languages", () => {
  const names: CalculatorName[] = ["increment", "proration", "withholding"];

  test.each(names)("the %s calculator renders its default result in both languages", (name) => {
    for (const locale of ["en", "ur"] as const) {
      const { view, items } = renderCalculator(name, locale);
      expect(view.summary.length).toBeGreaterThan(20);
      expect(items.length).toBeGreaterThan(1);
    }
  });

  test.each(names)(
    "the %s calculator's Urdu has no Latin letters (no Roman Urdu, no Rs)",
    (name) => {
      const { view, items } = renderCalculator(name, "ur");
      const labels = items.flatMap((item) =>
        item.kind === "group"
          ? [item.legend, item.hint ?? "", ...item.fields.map((field) => field.label)]
          : item.kind === "radio"
            ? [item.legend, item.hint ?? "", ...item.options.map((option) => option.label)]
            : item.kind === "select"
              ? [item.label, item.hint ?? "", ...item.options.map((option) => option.label)]
              : [item.label, item.hint ?? "", item.prefix ?? "", item.suffix ?? ""],
      );
      for (const value of [
        ...strings(view),
        ...labels,
        ...calculatorExamples(name, "ur").head,
        ...calculatorExamples(name, "ur").rows.flat(),
      ]) {
        expect(value).not.toMatch(/[A-Za-z]/);
      }
      for (const value of Object.values(CHROME.ur)) expect(value).not.toMatch(/[A-Za-z]/);
    },
  );

  test("the Urdu tables show the same figures as the English ones", () => {
    // The numbers in each cell, in order of size: "16 of 30" reads "30 میں سے 16" in Urdu.
    const digits = (value: string) =>
      (value.match(/[\d,]+/g) ?? []).map((number) => number.replaceAll(",", "")).sort();
    for (const table of [incrementExampleTable, prorationExampleTable, withholdingExampleTable]) {
      const en = table("en").rows.map((row) => row.map(digits));
      const ur = table("ur").rows.map((row) => row.map(digits));
      expect(ur).toEqual(en);
    }
    expect(PRORATION_EXAMPLES.length).toBe(4);
  });
});

describe("wrapTables", () => {
  test("puts each table in a focusable region named by the heading above it", () => {
    const html =
      '<h2 id="at-a-glance">At a glance</h2><table><tr><td>1</td></tr></table><p>x</p><h3 id="more">More</h3><table class="t"><tr><td>2</td></tr></table>';
    expect(wrapTables(html)).toBe(
      '<h2 id="at-a-glance">At a glance</h2><div class="table-scroll" role="region" tabindex="0" aria-labelledby="at-a-glance"><table><tr><td>1</td></tr></table></div><p>x</p><h3 id="more">More</h3><div class="table-scroll" role="region" tabindex="0" aria-labelledby="more"><table class="t"><tr><td>2</td></tr></table></div>',
    );
  });

  test("leaves HTML without tables alone", () => {
    expect(wrapTables("<p>No tables</p>")).toBe("<p>No tables</p>");
  });
});

describe("contentHref", () => {
  test("app, anchors and site paths in each language", () => {
    expect(contentHref("app", "ur", "https://app.example/")).toBe("https://app.example/");
    expect(contentHref("#faq", "ur", "https://app.example/")).toBe("#faq");
    expect(contentHref("/faq/", "en", "https://app.example/")).toBe("/faq/");
    expect(contentHref("/faq/", "ur", "https://app.example/")).toBe("/ur/faq/");
  });
});

function never(): never {
  throw new Error("missing example");
}
