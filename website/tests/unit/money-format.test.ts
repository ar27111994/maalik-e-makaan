// Ports of packages/mm_core/test/money/money_format_test.dart, money_parse_test.dart and digits_test.dart.
import fc from "fast-check";
import { describe, expect, test } from "vitest";
import {
  Money,
  formatMoney,
  groupDigits,
  normalizeDigits,
  parseMoneyInput,
  toUrduDigits,
  type DigitGrouping,
  type MoneyFormatOptions,
} from "../../src/lib/money/index.ts";
import { RUNS, storedAmount } from "./arbitraries.ts";

const rs = (rupees: number) => Money.fromRupees(rupees);

describe("groupDigits", () => {
  test("western grouping", () => {
    expect(groupDigits("0", "western")).toBe("0");
    expect(groupDigits("999", "western")).toBe("999");
    expect(groupDigits("1000", "western")).toBe("1,000");
    expect(groupDigits("1234567", "western")).toBe("1,234,567");
  });

  test("South Asian lakh and crore grouping", () => {
    expect(groupDigits("1000", "southAsian")).toBe("1,000");
    expect(groupDigits("100000", "southAsian")).toBe("1,00,000");
    expect(groupDigits("1234567", "southAsian")).toBe("12,34,567");
    expect(groupDigits("123456789", "southAsian")).toBe("12,34,56,789");
  });
});

describe("formatMoney, standard notation", () => {
  test("defaults: Rs, western grouping, no paisa for whole amounts", () => {
    expect(formatMoney(rs(150000))).toBe("Rs\u00A0150,000");
    expect(formatMoney(Money.ZERO)).toBe("Rs\u00A00");
    expect(formatMoney(Money.fromPaisa(150050))).toBe("Rs\u00A01,500.50");
  });

  test("negative amounts carry a leading sign", () => {
    expect(formatMoney(rs(-5000))).toBe("\u200E-Rs\u00A05,000");
    expect(formatMoney(rs(-5000), { language: "urdu" })).toBe("\u200E-5,000\u00A0روپے");
  });

  test("paisa display policies", () => {
    expect(formatMoney(rs(5), { paisa: "always" })).toBe("Rs\u00A05.00");
    expect(formatMoney(Money.fromPaisa(123456), { paisa: "never" })).toBe("Rs\u00A01,235");
    expect(formatMoney(Money.fromPaisa(123449), { paisa: "never" })).toBe("Rs\u00A01,234");
  });

  test("currency display and grouping options", () => {
    expect(formatMoney(rs(2000), { currency: "code" })).toBe("PKR\u00A02,000");
    expect(formatMoney(rs(2000), { currency: "none" })).toBe("2,000");
    expect(formatMoney(rs(150000), { grouping: "southAsian" })).toBe("Rs\u00A01,50,000");
  });

  test("Urdu puts the unit after the amount, optionally with Urdu numerals", () => {
    expect(formatMoney(rs(5000), { language: "urdu" })).toBe("5,000\u00A0روپے");
    expect(formatMoney(rs(5000), { language: "urdu", nativeDigits: true })).toBe("۵,۰۰۰\u00A0روپے");
    expect(formatMoney(rs(5), { nativeDigits: true })).toBe("Rs\u00A05");
  });
});

describe("formatMoney, compact notation (lakh and crore)", () => {
  const compact: MoneyFormatOptions = { notation: "compact" };

  test("below one lakh is written in full", () => {
    expect(formatMoney(rs(99999), compact)).toBe("Rs\u00A099,999");
  });

  test("lakh with up to two trimmed decimals", () => {
    expect(formatMoney(rs(100000), compact)).toBe("Rs\u00A01\u00A0lakh");
    expect(formatMoney(rs(150000), compact)).toBe("Rs\u00A01.5\u00A0lakh");
    expect(formatMoney(rs(1234567), compact)).toBe("Rs\u00A012.35\u00A0lakh");
    expect(formatMoney(rs(2350000), compact)).toBe("Rs\u00A023.5\u00A0lakh");
    expect(formatMoney(rs(105000), compact)).toBe("Rs\u00A01.05\u00A0lakh");
  });

  test("crore, including promotion when lakh rounds to 100", () => {
    expect(formatMoney(rs(10000000), compact)).toBe("Rs\u00A01\u00A0crore");
    expect(formatMoney(rs(12500000), compact)).toBe("Rs\u00A01.25\u00A0crore");
    expect(formatMoney(rs(9999999), compact)).toBe("Rs\u00A01\u00A0crore");
    expect(formatMoney(rs(1500000000), compact)).toBe("Rs\u00A0150\u00A0crore");
    expect(formatMoney(rs(-250000), compact)).toBe("\u200E-Rs\u00A02.5\u00A0lakh");
    expect(formatMoney(rs(123456000000), compact)).toBe("Rs\u00A012,345.6\u00A0crore");
  });

  test("Urdu units", () => {
    expect(formatMoney(rs(150000), { ...compact, language: "urdu" })).toBe(
      "1.5\u00A0لاکھ\u00A0روپے",
    );
    expect(formatMoney(rs(12500000), { ...compact, language: "urdu" })).toBe(
      "1.25\u00A0کروڑ\u00A0روپے",
    );
  });
});

describe("parseMoneyInput accepts how Pakistanis type amounts", () => {
  const accepted: [string, bigint][] = [
    ["150000", 15000000n],
    ["150,000", 15000000n],
    ["1,50,000", 15000000n],
    ["1 50 000", 15000000n],
    ["Rs 25,000", 2500000n],
    ["Rs.25000", 2500000n],
    ["rs. 25,000/-", 2500000n],
    ["PKR 1,000", 100000n],
    ["₨ 500", 50000n],
    ["500 rupees", 50000n],
    ["1500.5", 150050n],
    ["1500.50", 150050n],
    ["50k", 5000000n],
    ["50 K", 5000000n],
    ["5 thousand", 500000n],
    ["5 hazar", 500000n],
    ["1.5 lakh", 15000000n],
    ["1.5 lac", 15000000n],
    ["2 lakhs", 20000000n],
    ["1.2 crore", 1200000000n],
    ["1.25cr", 1250000000n],
    ["3 million", 300000000n],
    ["2.5m", 250000000n],
    ["1 arab", 100000000000n],
    ["۱۵۰۰۰۰", 15000000n],
    ["٢٥٠٠٠", 2500000n],
    ["1.5 لاکھ", 15000000n],
    ["2 کروڑ", 2000000000n],
    ["5 ہزار", 500000n],
    ["25,000 روپے", 2500000n],
    ["1٫5", 150n],
    ["1٬500", 150000n],
    ["+500", 50000n],
    ["0", 0n],
  ];
  test.each(accepted)("%j", (input, expected) => {
    expect(parseMoneyInput(input)?.paisa).toBe(expected);
  });

  test("unit words round half-up to the nearest paisa", () => {
    expect(parseMoneyInput("1.234567 lakh")?.paisa).toBe(12345670n);
    expect(parseMoneyInput("0.0000001 crore")?.paisa).toBe(100n);
    expect(parseMoneyInput("0.00000001 crore")?.paisa).toBe(10n);
  });
});

describe("parseMoneyInput rejects invalid input", () => {
  test.each([
    "",
    "   ",
    "abc",
    "12abc",
    "1.234",
    "1..5",
    ".",
    "lakh",
    "rs",
    "1,5,0.0.0",
    "1e5",
    "0x10",
    "9999999999999",
  ])("%j", (bad) => {
    expect(parseMoneyInput(bad)).toBeNull();
  });

  test("negatives are rejected unless allowed", () => {
    expect(parseMoneyInput("-500")).toBeNull();
    expect(parseMoneyInput("Rs -500")).toBeNull();
    expect(parseMoneyInput("-500", { allowNegative: true })?.paisa).toBe(-50000n);
    expect(parseMoneyInput("−500", { allowNegative: true })?.paisa).toBe(-50000n);
    expect(parseMoneyInput("Rs -500", { allowNegative: true })?.paisa).toBe(-50000n);
  });
});

test("parse and format round-trip for a spread of amounts", () => {
  const formats: MoneyFormatOptions[] = [
    {},
    { grouping: "southAsian" },
    { language: "urdu" },
    { language: "urdu", nativeDigits: true },
    { currency: "code" },
  ];
  for (let paisa = 0n; paisa < 5_000_000_000n; paisa += 7_777_777n) {
    const amount = Money.fromPaisa(paisa);
    for (const options of formats) {
      const text = formatMoney(amount, options);
      expect(parseMoneyInput(text)?.equals(amount), text).toBe(true);
    }
  }
});

describe("properties of formatting and parsing", () => {
  const options: fc.Arbitrary<MoneyFormatOptions> = fc.record({
    grouping: fc.constantFrom("western", "southAsian"),
    notation: fc.constantFrom("standard", "compact"),
    currency: fc.constantFrom("symbol", "code", "none"),
    paisa: fc.constantFrom("auto", "always", "never"),
    language: fc.constantFrom("english", "urdu"),
    nativeDigits: fc.boolean(),
  });
  const CRORE = Money.fromRupees(10_000_000);

  const isCompact = (amount: Money, format: MoneyFormatOptions) =>
    format.notation === "compact" && amount.abs().gte(rs(100_000));
  // The rounded figures can pass the top of numeric(14,2), which parseMoneyInput refuses:
  // from Rs 99,999.995 crore a compact figure reads "100,000 crore" (Rs 10^12), and without
  // paisa Rs 999,999,999,999.50 reads "Rs 1,000,000,000,000".
  const passesTheTop = (amount: Money, format: MoneyFormatOptions) =>
    isCompact(amount, format)
      ? amount.abs().gte(rs(999_999_950_000))
      : format.paisa === "never" && !amount.roundToRupee().isWithinStorageRange;

  test("property: every stored amount reads back from every way it is written", () => {
    fc.assert(
      fc.property(storedAmount, options, (amount, format) => {
        const text = formatMoney(amount, format);
        const parsed = parseMoneyInput(text, { allowNegative: true });
        if (passesTheTop(amount, format)) {
          expect(parsed, text).toBeNull();
          return;
        }
        expect(parsed, text).not.toBeNull();
        if (parsed === null) return;
        expect(parsed.isNegative && !amount.isNegative, text).toBe(false);
        if (isCompact(amount, format)) {
          // Two decimals of a lakh (Rs 1,000) or of a crore (Rs 1,00,000), rounded half up.
          const hundredth = parsed.abs().gte(CRORE) ? rs(100_000) : rs(1_000);
          expect(parsed.minus(amount).abs().paisa * 2n <= hundredth.paisa, text).toBe(true);
        } else if (format.paisa === "never") {
          expect(parsed.equals(amount.roundToRupee()), text).toBe(true);
        } else {
          expect(parsed.equals(amount), text).toBe(true);
        }
      }),
      RUNS,
    );
  });

  test("property: a negative amount is refused unless negatives are allowed", () => {
    fc.assert(
      fc.property(storedAmount, options, (amount, format) => {
        fc.pre(!passesTheTop(amount, format));
        const text = formatMoney(amount, format);
        expect(parseMoneyInput(text) === null, text).toBe(amount.isNegative);
      }),
      RUNS,
    );
  });

  test("property: grouping only adds commas, and Urdu digits convert back", () => {
    fc.assert(
      fc.property(
        fc.stringMatching(/^[1-9]\d{0,17}$/),
        fc.constantFrom<DigitGrouping>("western", "southAsian"),
        (digits, grouping) => {
          const grouped = groupDigits(digits, grouping);
          expect(grouped.replaceAll(",", "")).toBe(digits);
          expect(grouped.split(",").at(-1)?.length).toBe(Math.min(3, digits.length));
          const groupSize = grouping === "western" ? 3 : 2;
          for (const group of grouped.split(",").slice(1, -1)) {
            expect(group).toHaveLength(groupSize);
          }
          expect(normalizeDigits(toUrduDigits(grouped))).toBe(grouped);
        },
      ),
      RUNS,
    );
  });
});

describe("digits", () => {
  test("Urdu, Arabic-Indic and full-width digits become ASCII; other text is kept", () => {
    expect(normalizeDigits("۰۳۰۰۱۲۳۴۵۶۷")).toBe("03001234567");
    expect(normalizeDigits("٠١٢٣٤٥٦٧٨٩")).toBe("0123456789");
    expect(normalizeDigits("０１２")).toBe("012");
    expect(normalizeDigits("Rs ۵۰۰ روپے")).toBe("Rs 500 روپے");
    expect(normalizeDigits("")).toBe("");
  });

  test("toUrduDigits writes Urdu numerals", () => {
    expect(toUrduDigits("2026-11-05")).toBe("۲۰۲۶-۱۱-۰۵");
  });
});
