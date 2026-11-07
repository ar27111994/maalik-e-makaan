import { toUrduDigits } from "./digits.ts";
import { Money } from "./money.ts";
import { divideRounded } from "./rounding.ts";

/** `western` groups in threes (1,234,567); `southAsian` uses lakh/crore grouping (12,34,567). */
export type DigitGrouping = "western" | "southAsian";
/** `compact` abbreviates with lakh (10⁵) and crore (10⁷); amounts below a lakh stay in full. */
export type MoneyNotation = "standard" | "compact";
/** `symbol` is "Rs" in English and "روپے" in Urdu; `code` is "PKR". */
export type CurrencyDisplay = "symbol" | "code" | "none";
/** `auto` shows paisa only when the amount is not a whole number of rupees. */
export type PaisaDisplay = "auto" | "always" | "never";
export type MoneyLanguage = "english" | "urdu";

export interface MoneyFormatOptions {
  grouping?: DigitGrouping;
  notation?: MoneyNotation;
  currency?: CurrencyDisplay;
  paisa?: PaisaDisplay;
  language?: MoneyLanguage;
  /** Urdu numerals `۰۱۲۳۴۵۶۷۸۹`; applies only when `language` is Urdu. */
  nativeDigits?: boolean;
}

/**
 * U+00A0 NO-BREAK SPACE between the figures and the currency or unit words
 * beside them (`Rs`, `PKR`, `روپے`, `lakh`, `کروڑ`), so an amount that wraps
 * never leaves its currency or unit on one line and its figures on the next.
 */
export const NO_BREAK_SPACE = "\u00A0";

/**
 * U+200E LEFT-TO-RIGHT MARK before the minus sign of a negative amount, so the
 * sign stays on the left of the figures in right-to-left text too.
 */
export const LEFT_TO_RIGHT_MARK = "\u200E";

const LAKH_PAISA = 100_000n * Money.PAISA_PER_RUPEE;
const CRORE_PAISA = 10_000_000n * Money.PAISA_PER_RUPEE;

/** Inserts thousands separators into a string of ASCII digits. */
export function groupDigits(digits: string, grouping: DigitGrouping): string {
  if (digits.length <= 3) return digits;
  const head = digits.slice(0, -3);
  const tail = digits.slice(-3);
  const size = grouping === "western" ? 3 : 2;
  const groups: string[] = [];
  for (let end = head.length; end > 0; end -= size) {
    groups.unshift(head.slice(Math.max(0, end - size), end));
  }
  return `${groups.join(",")},${tail}`;
}

/**
 * Formats {@link Money} the way Pakistani landlords and tenants read amounts.
 * Mirrors `MoneyFormat` in packages/mm_core/lib/src/money/money_format.dart:
 * `formatMoney(Money.fromRupees(150000))` is "Rs 150,000"; with
 * `{ language: "urdu" }` it is "150,000 روپے". The space between the figures
 * and "Rs", "روپے", "lakh" or "کروڑ" is a no-break space, and a negative
 * amount starts with a left-to-right mark before its minus sign.
 */
export function formatMoney(amount: Money, options: MoneyFormatOptions = {}): string {
  const {
    grouping = "western",
    notation = "standard",
    currency = "symbol",
    paisa = "auto",
    language = "english",
    nativeDigits = false,
  } = options;
  const magnitude = amount.abs();
  const number =
    notation === "compact" && magnitude.paisa >= LAKH_PAISA
      ? compactNumber(magnitude, grouping, language)
      : standardNumber(magnitude, grouping, paisa);
  const localised = nativeDigits && language === "urdu" ? toUrduDigits(number) : number;
  const sign = amount.isNegative ? `${LEFT_TO_RIGHT_MARK}-` : "";
  if (currency === "none") return `${sign}${localised}`;
  if (currency === "code") return `${sign}PKR${NO_BREAK_SPACE}${localised}`;
  // Urdu places the unit after the amount ("پانچ ہزار روپے").
  return language === "english"
    ? `${sign}Rs${NO_BREAK_SPACE}${localised}`
    : `${sign}${localised}${NO_BREAK_SPACE}روپے`;
}

function standardNumber(magnitude: Money, grouping: DigitGrouping, paisa: PaisaDisplay): string {
  const showPaisa = paisa === "always" || (paisa === "auto" && magnitude.hasPaisa);
  if (!showPaisa) return groupDigits(magnitude.roundToRupee().wholeRupees.toString(), grouping);
  const whole = groupDigits(magnitude.wholeRupees.toString(), grouping);
  return `${whole}.${magnitude.paisaComponent.toString().padStart(2, "0")}`;
}

function compactNumber(magnitude: Money, grouping: DigitGrouping, language: MoneyLanguage): string {
  const hundredthsOf = (unitPaisa: bigint) =>
    divideRounded(magnitude.paisa * 100n, unitPaisa, "halfUp");
  // Two decimals, half-up, trailing zeros trimmed. A value that rounds up to
  // 100 lakh is promoted to crore ("1 crore", never "100 lakh").
  let useCrore = magnitude.paisa >= CRORE_PAISA;
  let hundredths = hundredthsOf(useCrore ? CRORE_PAISA : LAKH_PAISA);
  if (!useCrore && hundredths >= 100n * 100n) {
    useCrore = true;
    hundredths = hundredthsOf(CRORE_PAISA);
  }
  let digits = groupDigits((hundredths / 100n).toString(), grouping);
  const fraction = hundredths % 100n;
  if (fraction !== 0n) digits += `.${fraction.toString().padStart(2, "0").replace(/0$/, "")}`;
  const unit = language === "english" ? (useCrore ? "crore" : "lakh") : useCrore ? "کروڑ" : "لاکھ";
  return `${digits}${NO_BREAK_SPACE}${unit}`;
}
