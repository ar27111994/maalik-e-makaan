/**
 * The first-month rent calculator: the rent for a tenancy that starts part of
 * the way through a month, by the actual number of days in that month,
 * rounded once, half up, to whole rupees. The arithmetic is `proratedRent`
 * from src/lib/money, the same rule as the database's `app.prorated_rent`
 * (contracts/rent_math_vectors.json).
 */
import { formatDate, formatDayMonth, formatMonth } from "../i18n/dates.ts";
import type { Locale } from "../i18n/locales.ts";
import { CalendarDate, DateRange, MonthPeriod, daysInMonth } from "../lib/money/calendar.ts";
import { Money } from "../lib/money/money.ts";
import { proratedRent } from "../lib/money/rent-math.ts";
import { count, figure, money, readInteger, readRent, rentMessage } from "./input.ts";
import type { Calculator, FieldErrors, FormItem, ResultView, Segment } from "./types.ts";

export interface ProrationInput {
  readonly rent: Money;
  /** The first day the tenant's rent covers. */
  readonly start: CalendarDate;
}

export interface Proration {
  readonly period: MonthPeriod;
  readonly daysInMonth: number;
  /** Days from `start` to the month's last day, counting both. */
  readonly days: number;
  readonly amount: Money;
  /** The first day of the next month, when the full rent starts. */
  readonly nextMonth: CalendarDate;
}

export const PRORATION_DEFAULTS = { rent: "45,000", day: "15", month: "11", year: "2026" } as const;

export function prorate({ rent, start }: ProrationInput): Proration {
  const period = MonthPeriod.of(start);
  return {
    period,
    daysInMonth: period.lengthInDays,
    days: period.last.differenceInDays(start) + 1,
    amount: proratedRent({ monthlyRent: rent, period, occupancy: new DateRange(start) }),
    nextMonth: period.addMonths(1).first,
  };
}

interface Strings {
  readonly rent: { label: string; hint: string; prefix?: string; suffix?: string; error: string };
  readonly date: {
    legend: string;
    hint: string;
    day: string;
    month: string;
    year: string;
    error: string;
  };
  summary(from: string, to: string, amount: string, days: string, of: string): string;
  summaryFull(amount: string): string;
  readonly figures: { amount: string; days: string; daysValue(days: string, of: string): string };
  fullFrom(date: string): string;
  stepMonth(month: string, days: string): Segment[];
  stepDays(from: string, to: string, last: string, day: string, days: string): Segment[];
  stepMultiply(rent: string, days: string, of: string, result: string, exact: boolean): Segment[];
  stepRound(rounded: string): Segment[];
  stepFull(): Segment[];
  readonly note: string;
}

const STRINGS: Readonly<Record<Locale, Strings>> = {
  en: {
    rent: {
      label: "Monthly rent",
      hint: "In rupees, in English or Urdu digits, for example 45,000.",
      prefix: "Rs",
      error: "Enter the monthly rent in rupees, for example 45,000.",
    },
    date: {
      legend: "First day of the tenancy",
      hint: "The day the rent starts. For example, 15 11 2026.",
      day: "Day",
      month: "Month",
      year: "Year",
      error:
        "Enter a real date between the years 2000 and 2100, for example day 15, month 11, year 2026.",
    },
    summary: (from, to, amount, days, of) =>
      `Rent from ${from} to ${to}: ${amount}, for ${days} of ${of} days.`,
    summaryFull: (amount) => `A tenancy that starts on the 1st pays the full month: ${amount}.`,
    figures: {
      amount: "First-month rent",
      days: "Days charged",
      daysValue: (days, of) => `${days} of ${of}`,
    },
    fullFrom: (date) => `Full rent from ${date}`,
    stepMonth: (month, days) => [`${month} has `, { math: days }, " days."],
    stepDays: (from, to, last, day, days) => [
      `From ${from} to ${to}, counting both days, is `,
      { math: `${last} − ${day} + 1 = ${days}` },
      " days.",
    ],
    stepMultiply: (rent, days, of, result, exact) => [
      "The rent for those days is ",
      { math: `${rent} × ${days} ÷ ${of} ${exact ? "=" : "≈"} ${result}` },
      ".",
    ],
    stepRound: (rounded) => [
      "Rounded to the nearest rupee (a half rounds up): ",
      { math: rounded },
      ".",
    ],
    stepFull: () => [
      "The tenancy starts on the first day of the month, so the month is not split.",
    ],
    note: "No law that we found says how to charge for part of a month. This calculator counts the actual days in the month, as the Maalik-e-Makaan app does; some agreements count every month as 30 days instead, which gives a different figure.",
  },
  ur: {
    rent: {
      label: "ماہانہ کرایہ",
      hint: "روپوں میں، اردو یا انگریزی ہندسوں میں، جیسے ۴۵۰۰۰ یا 45,000۔",
      suffix: "روپے",
      error: "ماہانہ کرایہ روپوں میں لکھیں، جیسے 45,000۔",
    },
    date: {
      legend: "کرایہ داری کا پہلا دن",
      hint: "جس دن سے کرایہ شروع ہو۔ جیسے 15 11 2026۔",
      day: "دن",
      month: "مہینہ",
      year: "سال",
      error: "سن 2000 اور 2100 کے درمیان کوئی درست تاریخ لکھیں، جیسے دن 15، مہینہ 11، سال 2026۔",
    },
    summary: (from, to, amount, days, of) =>
      `${from} سے ${to} تک کا کرایہ: ${amount}، ${of} میں سے ${days}\u00A0دنوں کا۔`,
    summaryFull: (amount) =>
      `مہینے کی پہلی تاریخ سے شروع ہونے والی کرایہ داری پر پورے مہینے کا کرایہ لگتا ہے: ${amount}۔`,
    figures: {
      amount: "پہلے مہینے کا کرایہ",
      days: "جن دنوں کا کرایہ لیا گیا",
      daysValue: (days, of) => `${of} میں سے ${days}`,
    },
    fullFrom: (date) => `${date} سے پورا کرایہ`,
    stepMonth: (month, days) => [`${month} میں `, { math: days }, " دن ہیں۔"],
    stepDays: (from, to, last, day, days) => [
      `${from} سے ${to} تک، دونوں دن شامل کر کے، `,
      { math: `${last} − ${day} + 1 = ${days}` },
      " دن بنتے ہیں۔",
    ],
    stepMultiply: (rent, days, of, result, exact) => [
      "ان دنوں کا کرایہ: ",
      { math: `${rent} × ${days} ÷ ${of} ${exact ? "=" : "≈"} ${result}` },
      "۔",
    ],
    stepRound: (rounded) => [
      "قریب ترین روپے تک گول کرنے پر (آدھا اوپر کی طرف): ",
      { math: rounded },
      "۔",
    ],
    stepFull: () => [
      "کرایہ داری مہینے کے پہلے دن سے شروع ہو رہی ہے، اس لیے مہینہ تقسیم نہیں ہوتا۔",
    ],
    note: "ہمیں کوئی ایسا قانون نہیں ملا جو بتائے کہ مہینے کے کچھ حصے کا کرایہ کیسے لیا جائے۔ یہ کیلکولیٹر مہینے کے اصل دن گنتا ہے، جیسے مالکِ مکان ایپ گنتی ہے۔ کچھ کرایہ نامے ہر مہینے کو 30\u00A0دن کا مانتے ہیں، جس سے رقم مختلف آتی ہے۔",
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
      defaultValue: PRORATION_DEFAULTS.rent,
    },
    {
      kind: "group",
      name: "date",
      legend: s.date.legend,
      hint: s.date.hint,
      fields: [
        {
          kind: "text",
          name: "day",
          label: s.date.day,
          inputMode: "numeric",
          size: 2,
          defaultValue: PRORATION_DEFAULTS.day,
        },
        {
          kind: "text",
          name: "month",
          label: s.date.month,
          inputMode: "numeric",
          size: 2,
          defaultValue: PRORATION_DEFAULTS.month,
        },
        {
          kind: "text",
          name: "year",
          label: s.date.year,
          inputMode: "numeric",
          size: 4,
          defaultValue: PRORATION_DEFAULTS.year,
        },
      ],
    },
  ];
}

function parse(values: Readonly<Record<string, string>>, locale: Locale) {
  const s = STRINGS[locale];
  const errors: Record<string, string> = {};
  const read = readRent(values.rent ?? "");
  const rent = read.ok ? read.value : null;
  if (!read.ok) errors.rent = rentMessage(read.problem, locale, s.rent.error);
  const year = readInteger(values.year ?? "", 2000, 2100);
  const month = readInteger(values.month ?? "", 1, 12);
  const day = readInteger(values.day ?? "", 1, 31);
  const start =
    year !== null && month !== null && day !== null && day <= daysInMonth(year, month)
      ? new CalendarDate(year, month, day)
      : null;
  if (start === null) errors.date = s.date.error;
  if (rent === null || start === null) return { ok: false, errors: errors as FieldErrors } as const;
  return { ok: true, value: { rent, start } } as const;
}

function view(input: ProrationInput, locale: Locale): ResultView {
  const s = STRINGS[locale];
  const result = prorate(input);
  const nextMonth = formatDate(result.nextMonth.toIso(), locale);
  const amount = money(result.amount, locale);
  if (result.days === result.daysInMonth) {
    return {
      summary: s.summaryFull(amount),
      figures: [
        { label: s.figures.amount, value: amount, primary: true },
        {
          label: s.figures.days,
          value: s.figures.daysValue(count(result.days), count(result.daysInMonth)),
        },
      ],
      steps: [s.stepFull()],
      notes: [s.note],
    };
  }
  const from = formatDayMonth(input.start.toIso(), locale);
  const to = formatDate(result.period.last.toIso(), locale);
  // The exact share before rounding, to the paisa; "≈" when it is not exact.
  const numerator = input.rent.paisa * BigInt(result.days);
  const exact = numerator % BigInt(result.daysInMonth) === 0n;
  const unrounded = input.rent.multiply(result.days, result.daysInMonth);
  return {
    summary: s.summary(from, to, amount, count(result.days), count(result.daysInMonth)),
    figures: [
      { label: s.figures.amount, value: amount, primary: true },
      {
        label: s.figures.days,
        value: s.figures.daysValue(count(result.days), count(result.daysInMonth)),
      },
      { label: s.fullFrom(nextMonth), value: money(input.rent, locale) },
    ],
    steps: [
      s.stepMonth(formatMonth(input.start.toIso(), locale), count(result.daysInMonth)),
      s.stepDays(from, to, count(result.daysInMonth), count(input.start.day), count(result.days)),
      s.stepMultiply(
        figure(input.rent),
        count(result.days),
        count(result.daysInMonth),
        money(unrounded, locale, { currency: "none", paisa: "always" }),
        exact,
      ),
      s.stepRound(figure(result.amount)),
    ],
    notes: [s.note],
  };
}

export const prorationCalculator: Calculator<ProrationInput> = {
  id: "proration",
  items,
  parse,
  view,
};

/** The worked examples printed under the calculator (website-facts.md §5.3). */
export const PRORATION_EXAMPLES: readonly ProrationInput[] = [
  { rent: Money.fromRupees(45_000), start: CalendarDate.parse("2026-11-15") },
  { rent: Money.fromRupees(45_000), start: CalendarDate.parse("2027-02-15") },
  { rent: Money.fromRupees(50_000), start: CalendarDate.parse("2026-12-20") },
  { rent: Money.fromRupees(30_000), start: CalendarDate.parse("2028-02-15") },
];

export function prorationExampleTable(locale: Locale) {
  const s = STRINGS[locale];
  const head =
    locale === "en"
      ? ["Monthly rent", "First day", "Days charged", "First-month rent"]
      : ["ماہانہ کرایہ", "پہلا دن", "جن دنوں کا کرایہ", "پہلے مہینے کا کرایہ"];
  return {
    head,
    rows: PRORATION_EXAMPLES.map((example) => {
      const result = prorate(example);
      return [
        money(example.rent, locale),
        formatDate(example.start.toIso(), locale),
        s.figures.daysValue(count(result.days), count(result.daysInMonth)),
        money(result.amount, locale),
      ];
    }),
  };
}
