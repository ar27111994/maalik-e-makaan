/**
 * The calculators by the name a tool page's front matter uses. Imported at
 * build time by the pages; each page's browser script imports only its own
 * calculator.
 */
import type { Locale } from "../i18n/locales.ts";
import { incrementCalculator, incrementExampleTable } from "./increment.ts";
import { prorationCalculator, prorationExampleTable } from "./proration.ts";
import type { Calculator, FormItem, ResultView } from "./types.ts";
import { withholdingCalculator, withholdingExampleTable } from "./withholding.ts";

export type CalculatorName = "increment" | "proration" | "withholding";

interface Entry {
  readonly calculator: Calculator<never>;
  examples(locale: Locale): { head: string[]; rows: string[][] };
}

const CALCULATORS = {
  increment: { calculator: incrementCalculator, examples: incrementExampleTable },
  proration: { calculator: prorationCalculator, examples: prorationExampleTable },
  withholding: { calculator: withholdingCalculator, examples: withholdingExampleTable },
} as const satisfies Record<CalculatorName, unknown>;

/** The form's items, its default values and the result for them, for the page to render. */
export function renderCalculator(
  name: CalculatorName,
  locale: Locale,
): { id: string; items: readonly FormItem[]; view: ResultView } {
  const { calculator } = CALCULATORS[name] as { calculator: Calculator<unknown> };
  const items = calculator.items(locale);
  const defaults: Record<string, string> = {};
  for (const item of items) {
    if (item.kind === "group") {
      for (const field of item.fields) defaults[field.name] = field.defaultValue;
    } else {
      defaults[item.name] = item.defaultValue;
    }
  }
  const parsed = calculator.parse(defaults, locale);
  if (!parsed.ok) {
    throw new Error(
      `The ${name} calculator's defaults do not parse: ${JSON.stringify(parsed.errors)}`,
    );
  }
  return { id: calculator.id, items, view: calculator.view(parsed.value, locale) };
}

/** The worked examples table printed under a calculator. */
export function calculatorExamples(name: CalculatorName, locale: Locale) {
  return (CALCULATORS[name] as Entry).examples(locale);
}
