/**
 * Reading what a reader types into a calculator: Western or Urdu digits,
 * commas anywhere, "Rs" or "روپے", "lakh" or "لاکھ", a "%" or "٪" sign. Each
 * reader returns a value or `null`; the calculators turn `null` into a message
 * that says what to type.
 */
import type { Locale } from "../i18n/locales.ts";
import { basisPointsFromPercent } from "../lib/money/basis-points.ts";
import { normalizeDigits } from "../lib/money/digits.ts";
import { formatMoney, type MoneyFormatOptions } from "../lib/money/format.ts";
import { Money } from "../lib/money/money.ts";
import { parseMoneyInput } from "../lib/money/parse.ts";

/** The largest rent the calculators accept: Rs 10 crore a month or a year. */
export const MAX_RENT = Money.fromRupees(100_000_000);

/**
 * Unicode isolates for a left-to-right run, such as a percentage, inside
 * right-to-left text set with textContent (where a <bdi> cannot be used):
 * without them the bidi algorithm draws "6.25%" as "%6.25" after Urdu words.
 */
export const LRI = "\u2066";
export const PDI = "\u2069";

/** `text` as an isolated left-to-right run. */
export function isolateLtr(text: string): string {
  return `${LRI}${text}${PDI}`;
}

/** A rent in rupees: more than zero, at most `MAX_RENT`, to the paisa. */
export function readRupees(text: string): Money | null {
  const read = readRent(text);
  return read.ok ? read.value : null;
}

/**
 * What is wrong with a typed rent: not an amount at all, a decimal comma
 * ("45,5", which `parseMoneyInput` would read as 455 because it drops every
 * comma), or more than `MAX_RENT`.
 */
export type RentProblem =
  | { readonly kind: "format" }
  | { readonly kind: "decimalComma"; readonly suggestion: string }
  | { readonly kind: "tooLarge" };

/**
 * A comma followed by only one or two final digits is never a thousands
 * separator (those groups have three digits, or two in lakh grouping before
 * three more), so it is a decimal comma: "45,5" or "45,50".
 */
const DECIMAL_COMMA = /^(.*\d)[,،](\d{1,2})$/u;

/**
 * A rent in rupees, or why the text is not one. The amount itself is read by
 * `parseMoneyInput`, which mirrors the app's money_parse.dart; the decimal-comma
 * check is the calculators' own, so that a mistyped "45,5" is questioned
 * instead of silently becoming Rs 455.
 */
export function readRent(
  text: string,
):
  | { readonly ok: true; readonly value: Money }
  | { readonly ok: false; readonly problem: RentProblem } {
  const plain = normalizeDigits(text)
    .replace(/[\u200E\u200F\u061C]/gu, "")
    .trim();
  const decimalComma = DECIMAL_COMMA.exec(plain.replace(/\s*(?:\/-|روپے)$/u, ""));
  if (decimalComma !== null) {
    const [, whole = "", fraction = ""] = decimalComma;
    const suggestion = `${whole.replace(/^(?:rs\.?|pkr|₨)\s*/iu, "")}.${fraction}`;
    return { ok: false, problem: { kind: "decimalComma", suggestion } };
  }
  const amount = parseMoneyInput(text);
  if (!amount?.isPositive) return { ok: false, problem: { kind: "format" } };
  if (amount.gt(MAX_RENT)) return { ok: false, problem: { kind: "tooLarge" } };
  return { ok: true, value: amount };
}

/** The message for a rent problem; `format` is the calculator's own example sentence. */
export function rentMessage(problem: RentProblem, locale: Locale, format: string): string {
  switch (problem.kind) {
    case "format":
      return format;
    case "decimalComma":
      return locale === "en"
        ? `Use a full stop, not a comma, before paisa: did you mean ${problem.suggestion}? A comma only separates thousands, as in 45,000.`
        : `پیسوں سے پہلے کوما نہیں، نقطہ لگائیں: کیا آپ کا مطلب ${LRI}${problem.suggestion}${PDI} ہے؟ کوما صرف ہزاروں کو الگ کرتا ہے، جیسے 45,000۔`;
    case "tooLarge":
      return locale === "en"
        ? `This calculator takes a rent of up to ${money(MAX_RENT, locale)} (Rs 10 crore). Check the number of zeros.`
        : `یہ کیلکولیٹر زیادہ سے زیادہ ${money(MAX_RENT, locale)} (دس کروڑ روپے) تک کا کرایہ لیتا ہے۔ صفر گن کر دیکھ لیں۔`;
  }
}

/** A percentage from 0 to `max`, with at most two decimals, as basis points (10% → 1000). */
export function readPercent(text: string, max = 100): number | null {
  const cleaned = normalizeDigits(text).replace(/[%٪]/gu, "").replaceAll("٫", ".").trim();
  if (cleaned === "") return null;
  try {
    const basisPoints = basisPointsFromPercent(cleaned);
    return basisPoints > max * 100 ? null : basisPoints;
  } catch {
    return null;
  }
}

/** A whole number from `min` to `max`, in Western or Urdu digits. */
export function readInteger(text: string, min: number, max: number): number | null {
  const cleaned = normalizeDigits(text).trim();
  if (!/^\d{1,9}$/.test(cleaned)) return null;
  const value = Number(cleaned);
  return value < min || value > max ? null : value;
}

/** How the calculators write amounts: "Rs 49,500" in English, "49,500 روپے" in Urdu. */
export function money(amount: Money, locale: Locale, options: MoneyFormatOptions = {}): string {
  return formatMoney(amount, { language: locale === "en" ? "english" : "urdu", ...options });
}

/** An amount without the currency, for working such as "45,000 × 16 ÷ 30". */
export function figure(amount: Money): string {
  return formatMoney(amount, { currency: "none" });
}

/** A whole number with thousands separators. */
export function count(value: number): string {
  return formatMoney(Money.fromRupees(value), { currency: "none" });
}
