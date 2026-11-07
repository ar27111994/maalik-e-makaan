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

/** A rent in rupees: more than zero, at most `MAX_RENT`, to the paisa. */
export function readRupees(text: string): Money | null {
  const amount = parseMoneyInput(text);
  if (amount === null || !amount.isPositive || amount.gt(MAX_RENT)) return null;
  return amount;
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
