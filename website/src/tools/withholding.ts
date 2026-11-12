/**
 * The section 155 withholding calculator: the tax a tenant deducts from rent
 * over tax year 2027, from the FBR's rate card (src/lib/tax/s155.ts). It shows
 * withholding only, never final tax (decision D-10).
 */
import type { Locale } from "../i18n/locales.ts";
import { percentFromBasisPoints } from "../lib/money/basis-points.ts";
import { Money } from "../lib/money/money.ts";
import {
  PRESCRIBED_INDIVIDUAL_THRESHOLD,
  s155Withholding,
  tenantMustWithhold,
  type Payee,
  type S155Result,
  type Tenant,
} from "../lib/tax/s155.ts";
import { figure, isolateLtr, money, readRent, rentMessage } from "./input.ts";
import type { Calculator, FieldErrors, FormItem, ResultView, Segment } from "./types.ts";

export type RentPeriod = "month" | "year";

export interface WithholdingInput {
  readonly rent: Money;
  readonly period: RentPeriod;
  readonly payee: Payee;
  readonly onActiveTaxpayersList: boolean;
  readonly tenant: Tenant;
}

export const WITHHOLDING_DEFAULTS = {
  rent: "100,000",
  period: "month",
  payee: "individual",
  atl: "yes",
  tenant: "organisation",
} as const;

/** The year's gross rent: a monthly rent × 12, or the annual figure as typed. */
export function grossAnnualRent(input: Pick<WithholdingInput, "rent" | "period">): Money {
  return input.period === "month" ? input.rent.multiply(12) : input.rent;
}

export function withholdingFor(input: WithholdingInput): {
  gross: Money;
  result: S155Result;
  mustWithhold: boolean;
} {
  const gross = grossAnnualRent(input);
  return {
    gross,
    result: s155Withholding({
      grossAnnualRent: gross,
      payee: input.payee,
      onActiveTaxpayersList: input.onActiveTaxpayersList,
    }),
    mustWithhold: tenantMustWithhold(input.tenant, gross),
  };
}

const percent = (basisPoints: number) => `${percentFromBasisPoints(basisPoints)}%`;
/** An effective rate to two decimals: 625 → "6.25%", 0 → "0.00%". */
const rate = (basisPoints: number) =>
  `${Math.trunc(basisPoints / 100)}.${String(basisPoints % 100).padStart(2, "0")}%`;

interface Strings {
  readonly rent: { label: string; hint: string; prefix?: string; suffix?: string; error: string };
  readonly period: { legend: string; month: string; year: string };
  readonly payee: { legend: string; hint: string; individual: string; company: string };
  readonly atl: { legend: string; hint: string; yes: string; no: string };
  readonly tenant: { legend: string; hint: string; organisation: string; individual: string };
  summary(amount: string, effective: string): string;
  summaryNotRequired(threshold: string, amount: string): string;
  readonly figures: {
    annual: string;
    annualInfo: string;
    effective: string;
    monthly: string;
    gross: string;
  };
  stepGross(monthly: string, gross: string): Segment[];
  stepGrossAnnual(gross: string): Segment[];
  stepNil(gross: string, upTo: string): Segment[];
  stepBand(
    gross: string,
    over: string,
    upTo: string | null,
    fixed: string,
    bandRate: string,
  ): Segment[];
  stepBandWorking(
    gross: string,
    over: string,
    excess: string,
    bandRate: string,
    ofExcess: string,
    fixed: string,
    total: string,
  ): Segment[];
  stepCompany(onAtl: boolean, bandRate: string, gross: string, total: string): Segment[];
  stepEffective(total: string, gross: string, effective: string): Segment[];
  stepMonthly(total: string, monthly: string): Segment[];
  readonly notes: {
    adjustable: string;
    evenSpread: string;
    nonAtl: string;
    prescribedList: string;
  };
}

const STRINGS: Readonly<Record<Locale, Strings>> = {
  en: {
    rent: {
      label: "Gross rent",
      hint: "In rupees, in English or Urdu digits. Include any charge for furniture, fixtures or services.",
      prefix: "Rs",
      error: "Enter the gross rent in rupees, for example 100,000.",
    },
    period: { legend: "The rent is", month: "per month", year: "per year" },
    payee: {
      legend: "Who receives the rent?",
      hint: "The landlord: the person the tax is deducted from.",
      individual: "An individual, or an association of persons (AOP)",
      company: "A company",
    },
    atl: {
      legend: "Is the landlord on the FBR's Active Taxpayers List (ATL)?",
      hint: "To check, send ATL, a space and the 13-digit CNIC to 9966 (see “Check the ATL” below).",
      yes: "Yes, on the ATL",
      no: "No, not on the ATL",
    },
    tenant: {
      legend: "Who pays the rent?",
      hint: "The tenant: the one who deducts the tax, if the law requires it.",
      organisation:
        "A company, a government or local body, an NGO or charity, a foreign diplomatic mission, or a private school, hospital, clinic, maternity home, boutique or beauty parlour",
      individual: "An individual, or an association of persons (AOP)",
    },
    summary: (amount, effective) =>
      `The tenant deducts ${amount} over the year: ${effective} of the gross rent. It counts towards your final tax; it is not your final tax.`,
    summaryNotRequired: (threshold, amount) =>
      `This tenant does not have to deduct tax under section 155: an individual or AOP tenant deducts only when the rent is ${threshold} a year or more. For information, the rate card gives ${amount} a year.`,
    figures: {
      annual: "Tax deducted over the year",
      annualInfo: "Rate-card figure for the year (for information)",
      effective: "As a share of the gross rent",
      monthly: "Even spread per month (an assumption)",
      gross: "Gross rent for the year",
    },
    stepGross: (monthly, gross) => [
      "The gross rent for the year is ",
      { math: `${monthly} × 12 = ${gross}` },
      ".",
    ],
    stepGrossAnnual: (gross) => ["The gross rent for the year is ", { math: gross }, "."],
    stepNil: (gross, upTo) => [
      "Rs\u00A0",
      { math: gross },
      " does not exceed Rs\u00A0",
      { math: upTo },
      ", so nothing is deducted.",
    ],
    stepBand: (gross, over, upTo, fixed, bandRate) => [
      "Rs\u00A0",
      { math: gross },
      " is over Rs\u00A0",
      { math: over },
      ...(upTo === null ? [] : [" and does not exceed Rs\u00A0", { math: upTo }]),
      ", so the band is ",
      ...(fixed === "0" ? [] : ["Rs\u00A0", { math: fixed }, " plus "]),
      { math: bandRate },
      " of the amount over Rs\u00A0",
      { math: over },
      ".",
    ],
    stepBandWorking: (gross, over, excess, bandRate, ofExcess, fixed, total) => [
      { math: `${gross} − ${over} = ${excess}` },
      "; ",
      { math: `${bandRate} × ${excess} = ${ofExcess}` },
      ...(fixed === "0" ? [] : ["; ", { math: `${fixed} + ${ofExcess} = ${total}` }]),
      ".",
    ],
    stepCompany: (onAtl, bandRate, gross, total) => [
      `A company ${onAtl ? "on" : "not on"} the ATL has ${bandRate} of the gross rent deducted: `,
      { math: `${bandRate} × ${gross} = ${total}` },
      ".",
    ],
    stepEffective: (total, gross, effective) => [
      "As a share of the gross rent: ",
      { math: `${total} ÷ ${gross} = ${effective}` },
      ".",
    ],
    stepMonthly: (total, monthly) => [
      "Spread evenly over twelve months: ",
      { math: `${total} ÷ 12 ≈ ${monthly}` },
      " a month.",
    ],
    notes: {
      adjustable:
        "Tax deducted under section 155 is adjustable: it counts towards your final income tax for the year. It is not your final tax, and this calculator does not estimate your final tax. Not tax advice.",
      evenSpread:
        "The law states the bands on a year's gross rent. We found no official rule on spreading them over monthly payments, a part year or a mid-year change of rent, so the monthly figure is only the year's figure divided by 12.",
      nonAtl:
        "For an individual or AOP not on the ATL, the FBR's current rate card doubles the rates. The FBR's 2020 and 2021 cards said this doubling did not apply to section 155, and we have not found the law that changed it, so check this figure with a tax adviser.",
      prescribedList:
        "Who must deduct comes from the FBR's published guidance (2013 and 2018); we have not seen the 2026 text of the law itself.",
    },
  },
  ur: {
    rent: {
      label: "پورا کرایہ (ٹیکس کٹنے سے پہلے)",
      hint: "روپوں میں، اردو یا انگریزی ہندسوں میں۔ فرنیچر، فکسچر یا سروسز کی کوئی رقم ہو تو وہ بھی شامل کریں۔",
      suffix: "روپے",
      error: "پورا کرایہ روپوں میں لکھیں، جیسے 100,000۔",
    },
    period: { legend: "یہ کرایہ ہے", month: "ماہانہ", year: "سالانہ" },
    payee: {
      legend: "کرایہ کس کو ملتا ہے؟",
      hint: "مالکِ مکان: جس کے کرائے میں سے ٹیکس کٹتا ہے۔",
      individual: "کوئی فرد، یا افراد کی انجمن (اے او پی)",
      company: "کوئی کمپنی",
    },
    atl: {
      legend: "کیا مالکِ مکان کا نام ایف بی آر کی فعال ٹیکس دہندگان کی فہرست (اے ٹی ایل) میں ہے؟",
      hint: "یہ جاننے کا طریقہ اسی صفحے پر نیچے “اپنا اے ٹی ایل دیکھیں” میں دیا گیا ہے۔",
      yes: "جی ہاں، فہرست میں ہے",
      no: "نہیں، فہرست میں نہیں",
    },
    tenant: {
      legend: "کرایہ کون دیتا ہے؟",
      hint: "کرایہ دار: اگر قانون کے مطابق لازم ہو تو ٹیکس یہی کاٹتا ہے۔",
      organisation:
        "کوئی کمپنی، سرکاری یا بلدیاتی ادارہ، این جی او یا خیراتی ادارہ، غیر ملکی سفارت خانہ یا ہائی کمیشن، یا کوئی نجی تعلیمی ادارہ، ہسپتال، کلینک، میٹرنٹی ہوم، بوتیک یا بیوٹی پارلر",
      individual: "کوئی فرد، یا افراد کی انجمن (اے او پی)",
    },
    summary: (amount, effective) =>
      `کرایہ دار سال بھر میں ${amount} کاٹے گا، جو پورے کرائے کا ${isolateLtr(effective)} ہے۔ یہ رقم آپ کے سال کے اصل ٹیکس میں ادا شدہ مانی جاتی ہے۔ یہ آپ کا سال کا اصل ٹیکس نہیں۔`,
    summaryNotRequired: (threshold, amount) =>
      `اس کرایہ دار پر دفعہ 155 کے تحت ٹیکس کاٹنا لازم نہیں۔ کوئی فرد یا اے او پی کرایہ دار ٹیکس تب کاٹتا ہے جب کرایہ سال میں ${threshold} یا اس سے زیادہ ہو۔ صرف معلومات کے لیے: ریٹ کارڈ کے مطابق یہ رقم سال میں ${amount} بنتی ہے۔`,
    figures: {
      annual: "سال بھر میں کٹنے والا ٹیکس",
      annualInfo: "ریٹ کارڈ کے مطابق سالانہ رقم (صرف معلومات کے لیے)",
      effective: "پورے کرائے کا کتنا فیصد",
      monthly: "ہر مہینے برابر حصہ (فرض کر کے)",
      gross: "سال کا پورا کرایہ",
    },
    stepGross: (monthly, gross) => [
      "سال کا پورا کرایہ: ",
      { math: `${monthly} × 12 = ${gross}` },
      "۔",
    ],
    stepGrossAnnual: (gross) => ["سال کا پورا کرایہ: ", { math: gross }, "۔"],
    stepNil: (gross, upTo) => [
      { math: gross },
      "\u00A0روپے، ",
      { math: upTo },
      "\u00A0روپے سے زیادہ نہیں، اس لیے کوئی ٹیکس نہیں کٹتا۔",
    ],
    stepBand: (gross, over, upTo, fixed, bandRate) => [
      { math: gross },
      "\u00A0روپے، ",
      { math: over },
      "\u00A0روپے سے زیادہ ہے",
      ...(upTo === null ? [] : [" اور ", { math: upTo }, "\u00A0روپے سے زیادہ نہیں"]),
      "، اس لیے ریٹ یہ ہے: ",
      ...(fixed === "0" ? [] : [{ math: fixed }, "\u00A0روپے جمع "]),
      { math: over },
      "\u00A0روپے سے اوپر کی رقم کا ",
      { math: bandRate },
      "۔",
    ],
    stepBandWorking: (gross, over, excess, bandRate, ofExcess, fixed, total) => [
      { math: `${gross} − ${over} = ${excess}` },
      "؛ ",
      { math: `${bandRate} × ${excess} = ${ofExcess}` },
      ...(fixed === "0" ? [] : ["؛ ", { math: `${fixed} + ${ofExcess} = ${total}` }]),
      "۔",
    ],
    stepCompany: (onAtl, bandRate, gross, total) => [
      `اے ٹی ایل ${onAtl ? "میں شامل" : "سے باہر"} کمپنی کے پورے کرائے کا `,
      { math: bandRate },
      " کٹتا ہے: ",
      { math: `${bandRate} × ${gross} = ${total}` },
      "۔",
    ],
    stepEffective: (total, gross, effective) => [
      "پورے کرائے کا کتنا فیصد: ",
      { math: `${total} ÷ ${gross} = ${effective}` },
      "۔",
    ],
    stepMonthly: (total, monthly) => [
      "بارہ مہینوں پر برابر تقسیم: ",
      { math: `${total} ÷ 12 ≈ ${monthly}` },
      " ماہانہ۔",
    ],
    notes: {
      adjustable:
        "دفعہ 155 کے تحت کٹا ہوا ٹیکس ایڈجسٹ ہوتا ہے: یہ آپ کے سال کے اصل انکم ٹیکس میں ادا شدہ مانا جاتا ہے۔ یہ آپ کا سال کا اصل ٹیکس نہیں، اور یہ کیلکولیٹر اس کا اندازہ نہیں لگاتا۔ یہ ٹیکس مشورہ نہیں۔",
      evenSpread:
        "قانون میں ریٹ سال کے پورے کرائے پر دیے گئے ہیں۔ ہمیں کوئی سرکاری طریقہ نہیں ملا کہ انہیں ماہانہ ادائیگیوں پر کیسے بانٹا جائے، یا سال کے کچھ حصے پر، یا جب سال کے بیچ کرایہ بدل جائے۔ اس لیے ماہانہ رقم صرف سال کی رقم کو 12 سے تقسیم کر کے نکالی گئی ہے۔",
      nonAtl:
        "اے ٹی ایل سے باہر کسی فرد یا اے او پی کے لیے ایف بی آر کا موجودہ ریٹ کارڈ ریٹ دگنے کر دیتا ہے۔ ایف بی آر کے 2020 اور 2021 کے کارڈز کے مطابق یہ دگنا ریٹ دفعہ 155 پر لاگو نہیں تھا، اور ہمیں وہ قانون نہیں ملا جس نے اسے بدلا۔ اس لیے یہ رقم کسی ٹیکس مشیر سے ضرور چیک کروائیں۔",
      prescribedList:
        "ٹیکس کاٹنا کس پر لازم ہے، یہ ہم نے ایف بی آر کی جاری کی ہوئی رہنمائی (2013 اور 2018) سے لیا ہے۔ ہم نے 2026 کے قانون کے اپنے الفاظ نہیں دیکھے۔",
    },
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
      size: 14,
      defaultValue: WITHHOLDING_DEFAULTS.rent,
    },
    {
      kind: "radio",
      name: "period",
      legend: s.period.legend,
      options: [
        { value: "month", label: s.period.month },
        { value: "year", label: s.period.year },
      ],
      defaultValue: WITHHOLDING_DEFAULTS.period,
    },
    {
      kind: "radio",
      name: "payee",
      legend: s.payee.legend,
      hint: s.payee.hint,
      options: [
        { value: "individual", label: s.payee.individual },
        { value: "company", label: s.payee.company },
      ],
      defaultValue: WITHHOLDING_DEFAULTS.payee,
    },
    {
      kind: "radio",
      name: "atl",
      legend: s.atl.legend,
      hint: s.atl.hint,
      options: [
        { value: "yes", label: s.atl.yes },
        { value: "no", label: s.atl.no },
      ],
      defaultValue: WITHHOLDING_DEFAULTS.atl,
    },
    {
      kind: "radio",
      name: "tenant",
      legend: s.tenant.legend,
      hint: s.tenant.hint,
      options: [
        { value: "organisation", label: s.tenant.organisation },
        { value: "individual", label: s.tenant.individual },
      ],
      defaultValue: WITHHOLDING_DEFAULTS.tenant,
    },
  ];
}

function parse(values: Readonly<Record<string, string>>, locale: Locale) {
  const s = STRINGS[locale];
  const read = readRent(values.rent ?? "");
  if (!read.ok) {
    const message = rentMessage(read.problem, locale, s.rent.error);
    return { ok: false, errors: { rent: message } as FieldErrors } as const;
  }
  const rent = read.value;
  return {
    ok: true,
    value: {
      rent,
      period: values.period === "year" ? "year" : "month",
      payee: values.payee === "company" ? "company" : "individual",
      onActiveTaxpayersList: values.atl !== "no",
      tenant: values.tenant === "individual" ? "individual" : "organisation",
    },
  } as const;
}

function view(input: WithholdingInput, locale: Locale): ResultView {
  const s = STRINGS[locale];
  const { gross, result, mustWithhold } = withholdingFor(input);
  const annual = money(result.annual, locale);
  const effective = rate(result.effectiveRateBasisPoints);
  const bandRate = percent(result.band.rateBasisPoints);
  const steps: Segment[][] = [
    input.period === "month"
      ? s.stepGross(figure(input.rent), figure(gross))
      : s.stepGrossAnnual(figure(gross)),
  ];
  const paisa = { currency: "none", paisa: "auto" } as const;
  if (input.payee === "company") {
    steps.push(
      s.stepCompany(
        input.onActiveTaxpayersList,
        bandRate,
        figure(gross),
        money(result.annual, locale, paisa),
      ),
    );
  } else if (result.band.rateBasisPoints === 0) {
    steps.push(s.stepNil(figure(gross), figure(result.band.upTo ?? Money.ZERO)));
  } else {
    const ofExcess = result.excess.multiply(result.band.rateBasisPoints, 10_000);
    steps.push(
      s.stepBand(
        figure(gross),
        figure(result.band.over),
        result.band.upTo === null ? null : figure(result.band.upTo),
        figure(result.band.fixed),
        bandRate,
      ),
      s.stepBandWorking(
        figure(gross),
        figure(result.band.over),
        figure(result.excess),
        bandRate,
        money(ofExcess, locale, paisa),
        figure(result.band.fixed),
        money(result.annual, locale, paisa),
      ),
    );
  }
  if (!result.annual.isZero) {
    steps.push(
      s.stepEffective(money(result.annual, locale, paisa), figure(gross), effective),
      s.stepMonthly(money(result.annual, locale, paisa), figure(result.monthlyEvenSpread)),
    );
  }
  const notes = [s.notes.adjustable];
  if (!result.annual.isZero) notes.push(s.notes.evenSpread);
  if (result.nonAtlIndividual && !result.annual.isZero) notes.push(s.notes.nonAtl);
  notes.push(s.notes.prescribedList);
  return {
    summary: mustWithhold
      ? s.summary(annual, effective)
      : s.summaryNotRequired(money(PRESCRIBED_INDIVIDUAL_THRESHOLD, locale), annual),
    figures: [
      {
        label: mustWithhold ? s.figures.annual : s.figures.annualInfo,
        value: annual,
        primary: true,
      },
      { label: s.figures.effective, value: effective },
      { label: s.figures.monthly, value: money(result.monthlyEvenSpread, locale) },
      { label: s.figures.gross, value: money(gross, locale) },
    ],
    steps,
    notes,
  };
}

export const withholdingCalculator: Calculator<WithholdingInput> = {
  id: "withholding",
  items,
  parse,
  view,
};

/** The worked examples of website-facts.md §3.6, printed under the calculator. */
export const WITHHOLDING_EXAMPLE_RENTS = [
  240_000, 300_000, 360_000, 600_000, 1_200_000, 1_500_000, 2_000_000, 3_000_000, 6_000_000,
] as const;

export function withholdingExampleTable(locale: Locale) {
  const head =
    locale === "en"
      ? [
          "Gross rent a year",
          "Individual or AOP, on the ATL",
          "Individual or AOP, not on the ATL",
          "Company, on the ATL",
          "Company, not on the ATL",
        ]
      : [
          "سال کا پورا کرایہ (ٹیکس کٹنے سے پہلے)",
          "فرد یا اے او پی، اے ٹی ایل میں",
          "فرد یا اے او پی، اے ٹی ایل سے باہر",
          "کمپنی، اے ٹی ایل میں",
          "کمپنی، اے ٹی ایل سے باہر",
        ];
  const cell = (gross: Money, payee: Payee, onActiveTaxpayersList: boolean) =>
    money(s155Withholding({ grossAnnualRent: gross, payee, onActiveTaxpayersList }).annual, locale);
  return {
    head,
    rows: WITHHOLDING_EXAMPLE_RENTS.map((value) => {
      const gross = Money.fromRupees(value);
      return [
        money(gross, locale),
        cell(gross, "individual", true),
        cell(gross, "individual", false),
        cell(gross, "company", true),
        cell(gross, "company", false),
      ];
    }),
  };
}
