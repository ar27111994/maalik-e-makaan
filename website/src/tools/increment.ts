/**
 * The rent increase calculator: the rent after an agreed yearly increase,
 * rounded once to the step the reader picks, and the years after it. The
 * arithmetic is `incrementedRent` from src/lib/money, the same rule as the
 * app's ledger (contracts/rent_math_vectors.json).
 */
import type { Locale } from "../i18n/locales.ts";
import { percentFromBasisPoints } from "../lib/money/basis-points.ts";
import { Money } from "../lib/money/money.ts";
import { RENT_ROUNDING, incrementedRent, type RentRounding } from "../lib/money/rent-math.ts";
import { figure, money, readInteger, readPercent, readRent, rentMessage } from "./input.ts";
import type { Calculator, FieldErrors, FormItem, ResultView, Segment } from "./types.ts";

export interface IncrementInput {
  readonly rent: Money;
  /** The yearly increase in basis points (10% = 1000). */
  readonly basisPoints: number;
  readonly rounding: RentRounding;
  /** How many years to show, 1 to 10. */
  readonly years: number;
}

export interface IncrementYear {
  readonly year: number;
  readonly rent: Money;
  readonly increase: Money;
}

export const INCREMENT_DEFAULTS = {
  rent: "45,000",
  percent: "10",
  rounding: "nearest100",
  years: "3",
} as const;

const ROUNDINGS = Object.keys(RENT_ROUNDING) as RentRounding[];

/** The rent for each of `years` years: each year's increase applies to the rounded rent before it. */
export function incrementSchedule(input: IncrementInput): IncrementYear[] {
  const schedule: IncrementYear[] = [];
  let rent = input.rent;
  for (let year = 1; year <= input.years; year += 1) {
    const next = incrementedRent(rent, {
      basisPoints: input.basisPoints,
      rounding: input.rounding,
    });
    schedule.push({ year, rent: next, increase: next.minus(rent) });
    rent = next;
  }
  return schedule;
}

interface Strings {
  readonly rent: { label: string; hint: string; prefix?: string; suffix?: string; error: string };
  readonly percent: { label: string; hint: string; error: string };
  readonly rounding: { label: string; options: Readonly<Record<RentRounding, string>> };
  readonly years: { label: string; hint: string; error: string };
  summary(newRent: string, increase: string): string;
  /** When rounding takes the new rent below the current one. */
  summaryFall(newRent: string, fall: string, rounding: string): string;
  readonly figures: { newRent: string; increase: string; decrease: string; rate: string };
  stepIncrease(rent: string, percent: string, increase: string, exact: boolean): Segment[];
  stepAdd(rent: string, increase: string, total: string, exact: boolean): Segment[];
  stepRound(rounding: string, rounded: string, unchanged: boolean): Segment[];
  stepLater(percent: string): Segment[];
  readonly table: {
    caption: string;
    head: readonly [string, string, string];
    /** The third column's heading when some year's rent falls. */
    changeHead: string;
    /** A fall in rent, in words: never a bare minus sign (DESIGN.md). */
    fall(amount: string): string;
    now: string;
    after(year: number): string;
  };
  readonly note: string;
  /** Added when rounding takes the rent below the current rent. */
  noteFall(rounding: string): string;
}

const STRINGS: Readonly<Record<Locale, Strings>> = {
  en: {
    rent: {
      label: "Current monthly rent",
      hint: "In rupees, in English or Urdu digits, for example 45,000.",
      prefix: "Rs",
      error: "Enter the monthly rent in rupees, for example 45,000.",
    },
    percent: {
      label: "Yearly increase (%)",
      hint: "The percentage in your agreement, for example 10.",
      error: "Enter the yearly increase as a percentage from 0 to 100, for example 10.",
    },
    rounding: {
      label: "Round the new rent to",
      options: {
        none: "the nearest rupee",
        nearest10: "the nearest Rs\u00A010",
        nearest50: "the nearest Rs\u00A050",
        nearest100: "the nearest Rs\u00A0100",
        nearest500: "the nearest Rs\u00A0500",
        nearest1000: "the nearest Rs\u00A01,000",
      },
    },
    years: {
      label: "Years to show",
      hint: "From 1 to 10.",
      error: "Enter a number of years from 1 to 10.",
    },
    summary: (newRent, increase) =>
      `After one year the rent becomes ${newRent} a month, an increase of ${increase}.`,
    summaryFall: (newRent, fall, rounding) =>
      `Rounded to ${rounding}, the rent would become ${newRent} a month, a decrease of ${fall}. The rounding step is larger than the increase: choose a smaller one.`,
    figures: {
      newRent: "New monthly rent",
      increase: "Increase",
      decrease: "Decrease",
      rate: "Yearly increase",
    },
    stepIncrease: (rent, percent, increase, exact) => [
      "The increase is ",
      { math: `${rent} × ${percent}% ${exact ? "=" : "≈"} ${increase}` },
      ".",
    ],
    stepAdd: (rent, increase, total, exact) => [
      "Before rounding, the new rent is ",
      { math: `${rent} + ${increase} ${exact ? "=" : "≈"} ${total}` },
      ".",
    ],
    stepRound: (rounding, rounded, unchanged) =>
      unchanged
        ? [`Rounded to ${rounding}, it stays `, { math: rounded }, "."]
        : [`Rounded to ${rounding} (a half rounds up), it becomes `, { math: rounded }, "."],
    stepLater: (percent) => [
      "Each later year adds ",
      { math: `${percent}%` },
      " to the rounded rent of the year before, then rounds again.",
    ],
    table: {
      caption: "Monthly rent, year by year",
      head: ["Year", "Monthly rent", "Increase"],
      changeHead: "Change",
      fall: (amount) => `${amount} less`,
      now: "Now",
      after: (year) => (year === 1 ? "After 1 year" : `After ${year} years`),
    },
    note: "Rounding is a convention, not a rule of law. The increase that counts is the one in your agreement (and, in Islamabad, the law's 10% if the agreement says nothing).",
    noteFall: (rounding) =>
      `Rounding to ${rounding} takes this rent below what it is now, because the step is larger than the increase. An agreed increase never lowers the rent, so round to a smaller step or to the nearest rupee.`,
  },
  ur: {
    rent: {
      label: "موجودہ ماہانہ کرایہ",
      hint: "روپوں میں، اردو یا انگریزی ہندسوں میں، جیسے ۴۵۰۰۰ یا 45,000۔",
      suffix: "روپے",
      error: "ماہانہ کرایہ روپوں میں لکھیں، جیسے 45,000۔",
    },
    percent: {
      label: "سالانہ اضافہ (فیصد)",
      hint: "آپ کے کرایہ نامے میں لکھا فیصد، جیسے 10۔",
      error: "سالانہ اضافہ صفر سے سو کے درمیان فیصد میں لکھیں، جیسے 10۔",
    },
    rounding: {
      label: "نئے کرائے کو گول کریں",
      options: {
        none: "قریب ترین روپے تک",
        nearest10: "قریب ترین 10\u00A0روپے تک",
        nearest50: "قریب ترین 50\u00A0روپے تک",
        nearest100: "قریب ترین 100\u00A0روپے تک",
        nearest500: "قریب ترین 500\u00A0روپے تک",
        nearest1000: "قریب ترین 1,000\u00A0روپے تک",
      },
    },
    years: {
      label: "کتنے سال دکھائیں",
      hint: "1 سے 10 تک۔",
      error: "سالوں کی تعداد 1 سے 10 کے درمیان لکھیں۔",
    },
    summary: (newRent, increase) =>
      `ایک سال بعد کرایہ ${newRent} ماہانہ ہو جائے گا، یعنی ${increase} کا اضافہ۔`,
    summaryFall: (newRent, fall, rounding) =>
      `${rounding} گول کرنے پر کرایہ ${newRent} ماہانہ رہ جائے گا، یعنی ${fall} کی کمی۔ گول کرنے کا درجہ اضافے سے بڑا ہے: اس سے چھوٹا درجہ چنیں۔`,
    figures: {
      newRent: "نیا ماہانہ کرایہ",
      increase: "اضافہ",
      decrease: "کمی",
      rate: "سالانہ اضافہ",
    },
    stepIncrease: (rent, percent, increase, exact) => [
      "اضافہ: ",
      { math: `${rent} × ${percent}% ${exact ? "=" : "≈"} ${increase}` },
      "۔",
    ],
    stepAdd: (rent, increase, total, exact) => [
      "گول کرنے سے پہلے نیا کرایہ: ",
      { math: `${rent} + ${increase} ${exact ? "=" : "≈"} ${total}` },
      "۔",
    ],
    stepRound: (rounding, rounded, unchanged) =>
      unchanged
        ? [`${rounding} گول کرنے پر بھی یہ `, { math: rounded }, " ہی رہتا ہے۔"]
        : [`${rounding} گول کرنے پر (آدھا اوپر کی طرف) یہ `, { math: rounded }, " ہو جاتا ہے۔"],
    stepLater: (percent) => [
      "اس کے بعد ہر سال پچھلے سال کے گول کیے گئے کرائے پر ",
      { math: `${percent}%` },
      " اضافہ کر کے دوبارہ گول کیا جاتا ہے۔",
    ],
    table: {
      caption: "ہر سال کا ماہانہ کرایہ",
      head: ["سال", "ماہانہ کرایہ", "اضافہ"],
      changeHead: "فرق",
      fall: (amount) => `${amount} کم`,
      now: "ابھی",
      after: (year) => (year === 1 ? "ایک سال بعد" : `${year} سال بعد`),
    },
    note: "کرایہ گول کرنا ایک رواج ہے، قانون نہیں۔ اصل اضافہ وہی ہے جو آپ کے کرایہ نامے میں لکھا ہے (اور اسلام آباد میں، اگر کرایہ نامے میں کچھ نہ لکھا ہو تو قانون کے مطابق 10 فیصد)۔",
    noteFall: (rounding) =>
      `${rounding} گول کرنے سے یہ کرایہ موجودہ کرائے سے کم ہو جاتا ہے، کیونکہ گول کرنے کا درجہ اضافے سے بڑا ہے۔ طے شدہ اضافہ کرایہ کبھی کم نہیں کرتا، اس لیے چھوٹا درجہ چنیں یا قریب ترین روپے تک گول کریں۔`,
  },
};

function items(locale: Locale): FormItem[] {
  const s = STRINGS[locale];
  return [
    {
      kind: "text",
      name: "rent",
      label: s.rent.label,
      hint: s.rent.hint,
      ...(s.rent.prefix === undefined ? {} : { prefix: s.rent.prefix }),
      ...(s.rent.suffix === undefined ? {} : { suffix: s.rent.suffix }),
      inputMode: "decimal",
      size: 12,
      defaultValue: INCREMENT_DEFAULTS.rent,
    },
    {
      kind: "text",
      name: "percent",
      label: s.percent.label,
      hint: s.percent.hint,
      inputMode: "decimal",
      size: 6,
      defaultValue: INCREMENT_DEFAULTS.percent,
    },
    {
      kind: "select",
      name: "rounding",
      label: s.rounding.label,
      options: ROUNDINGS.map((value) => ({ value, label: s.rounding.options[value] })),
      defaultValue: INCREMENT_DEFAULTS.rounding,
    },
    {
      kind: "text",
      name: "years",
      label: s.years.label,
      hint: s.years.hint,
      inputMode: "numeric",
      size: 3,
      defaultValue: INCREMENT_DEFAULTS.years,
    },
  ];
}

function parse(values: Readonly<Record<string, string>>, locale: Locale) {
  const s = STRINGS[locale];
  const errors: Record<string, string> = {};
  const read = readRent(values.rent ?? "");
  const rent = read.ok ? read.value : null;
  if (!read.ok) errors.rent = rentMessage(read.problem, locale, s.rent.error);
  const basisPoints = readPercent(values.percent ?? "");
  if (basisPoints === null) errors.percent = s.percent.error;
  const rounding = ROUNDINGS.find((value) => value === values.rounding) ?? "nearest100";
  const years = readInteger(values.years ?? "", 1, 10);
  if (years === null) errors.years = s.years.error;
  if (rent === null || basisPoints === null || years === null) {
    return { ok: false, errors: errors as FieldErrors } as const;
  }
  return { ok: true, value: { rent, basisPoints, rounding, years } } as const;
}

function view(input: IncrementInput, locale: Locale): ResultView {
  const s = STRINGS[locale];
  const schedule = incrementSchedule(input);
  const first = schedule[0];
  if (first === undefined) throw new RangeError("years must be at least 1");
  const percent = percentFromBasisPoints(input.basisPoints);
  // The increase and the new rent before rounding, to the paisa; "≈" when not exact.
  const exact = (input.rent.paisa * BigInt(input.basisPoints)) % 10_000n === 0n;
  const rawIncrease = input.rent.percentage(input.basisPoints);
  const rawTotal = input.rent.plus(rawIncrease);
  const pad = { paisa: "always" } as const;
  const steps: Segment[][] = [
    s.stepIncrease(
      figure(input.rent),
      percent,
      money(rawIncrease, locale, { currency: "none", ...pad }),
      exact,
    ),
    s.stepAdd(
      figure(input.rent),
      money(rawIncrease, locale, { currency: "none", ...pad }),
      money(rawTotal, locale, { currency: "none", ...pad }),
      exact,
    ),
    s.stepRound(
      s.rounding.options[input.rounding],
      figure(first.rent),
      exact && rawTotal.equals(first.rent),
    ),
  ];
  if (input.years > 1) steps.push(s.stepLater(percent));
  const rounding = s.rounding.options[input.rounding];
  const firstFalls = first.increase.isNegative;
  const anyFalls = schedule.some((row) => row.increase.isNegative);
  // A fall is said in words with a positive amount, never with a bare minus sign.
  const change = (amount: Money) =>
    amount.isNegative ? s.table.fall(money(amount.negate(), locale)) : money(amount, locale);
  const [yearHead, rentHead, increaseHead] = s.table.head;
  return {
    summary: firstFalls
      ? s.summaryFall(money(first.rent, locale), money(first.increase.negate(), locale), rounding)
      : s.summary(money(first.rent, locale), money(first.increase, locale)),
    figures: [
      { label: s.figures.newRent, value: money(first.rent, locale), primary: true },
      firstFalls
        ? { label: s.figures.decrease, value: money(first.increase.negate(), locale) }
        : { label: s.figures.increase, value: money(first.increase, locale) },
      { label: s.figures.rate, value: `${percent}%` },
    ],
    steps,
    table: {
      caption: s.table.caption,
      head: [yearHead, rentHead, anyFalls ? s.table.changeHead : increaseHead],
      rows: [
        [s.table.now, money(input.rent, locale), "–"],
        ...schedule.map((row) => [
          s.table.after(row.year),
          money(row.rent, locale),
          change(row.increase),
        ]),
      ],
    },
    notes: anyFalls ? [s.noteFall(rounding), s.note] : [s.note],
  };
}

export const incrementCalculator: Calculator<IncrementInput> = {
  id: "increment",
  items,
  parse,
  view,
};

/** The worked examples printed under the calculator (website-facts.md §5.3 and LEASE-06). */
export const INCREMENT_EXAMPLES: readonly IncrementInput[] = [
  { rent: Money.fromRupees(45_000), basisPoints: 1000, rounding: "nearest100", years: 1 },
  { rent: Money.fromRupees(37_350), basisPoints: 1000, rounding: "nearest100", years: 1 },
  { rent: Money.fromRupees(47_300), basisPoints: 1000, rounding: "nearest1000", years: 1 },
  { rent: Money.fromRupees(25_000), basisPoints: 1500, rounding: "nearest500", years: 1 },
];

/** The column headings and row labels of the worked examples table. */
export function incrementExampleTable(locale: Locale) {
  const s = STRINGS[locale];
  const head =
    locale === "en"
      ? ["Current rent", "Increase", "Rounded to", "New rent"]
      : ["موجودہ کرایہ", "اضافہ", "گول کیا گیا", "نیا کرایہ"];
  return {
    head,
    rows: INCREMENT_EXAMPLES.map((example) => [
      money(example.rent, locale),
      `${percentFromBasisPoints(example.basisPoints)}%`,
      s.rounding.options[example.rounding],
      money(incrementSchedule(example)[0]?.rent ?? example.rent, locale),
    ]),
  };
}
