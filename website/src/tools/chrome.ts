/**
 * The words every calculator shares, in both languages. Kept apart from
 * src/i18n/ui.ts so the calculators' browser scripts bundle only these.
 */
import type { Locale } from "../i18n/locales.ts";
import type { CalculatorChrome } from "./types.ts";

export const CHROME: Readonly<Record<Locale, CalculatorChrome>> = {
  en: {
    submit: "Calculate",
    resultHeading: "Result",
    stepsHeading: "How this was worked out",
    errorSummary: "Check the highlighted answers: the result has not changed.",
  },
  ur: {
    submit: "حساب لگائیں",
    resultHeading: "نتیجہ",
    stepsHeading: "یہ حساب کیسے لگا",
    errorSummary: "نشان زدہ جوابات دیکھ لیں: نتیجہ نہیں بدلا۔",
  },
};

/** The ids of a calculator's elements, shared by the page and its script. */
export const calculatorIds = (id: string) =>
  ({
    form: `${id}-form`,
    status: `${id}-status`,
    body: `${id}-result-body`,
    resultHeading: `${id}-result-heading`,
    field: (name: string) => `${id}-${name}`,
    hint: (name: string) => `${id}-${name}-hint`,
    error: (name: string) => `${id}-${name}-error`,
    tableCaption: `${id}-result-table-caption`,
  }) as const;
