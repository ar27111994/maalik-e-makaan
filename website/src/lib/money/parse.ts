import { normalizeDigits } from "./digits.ts";
import { Money } from "./money.ts";
import { divideRounded } from "./rounding.ts";

const NUMBER_PATTERN = /^(\d+)(?:\.(\d+))?$/;

const CURRENCY_MARKERS = [
  /^(?:rs\.?|pkr|₨|rupees?|روپے|روپیہ|روپیے)\s*/u,
  /\s*(?:rs\.?|pkr|₨|rupees?|روپے|روپیہ|روپیے|\/-)$/u,
];

const UNITS: readonly { pattern: RegExp; multiplier: bigint }[] = [
  { pattern: /\s*(?:arab|ارب)$/u, multiplier: 1_000_000_000n },
  { pattern: /\s*(?:crores?|cr|karor|کروڑ)$/u, multiplier: 10_000_000n },
  { pattern: /\s*(?:millions?|mn|m)$/u, multiplier: 1_000_000n },
  { pattern: /\s*(?:lakhs?|lacs?|لاکھ)$/u, multiplier: 100_000n },
  { pattern: /\s*(?:thousand|hazar|hazaar|ہزار|k)$/u, multiplier: 1_000n },
];

function stripCurrencyMarkers(input: string): string {
  let text = input;
  let changed = true;
  while (changed) {
    changed = false;
    for (const marker of CURRENCY_MARKERS) {
      const stripped = text.replace(marker, "").trim();
      if (stripped !== text) {
        text = stripped;
        changed = true;
      }
    }
  }
  return text;
}

/**
 * Parses an amount the way a Pakistani user types it. Mirrors
 * `parseMoneyInput` in packages/mm_core/lib/src/money/money_parse.dart.
 *
 * Accepts currency markers (`Rs`, `Rs.`, `PKR`, `₨`, `rupees`, `روپے`), grouping
 * separators in any position (`1,50,000`), Urdu and Arabic-Indic digits, the
 * Arabic decimal and thousands separators, and unit words (`k`, `hazar`,
 * `ہزار`, `lakh`, `لاکھ`, `million`, `crore`, `کروڑ`, `arab`, `ارب`). Plain
 * numbers may have at most two decimals; amounts with a unit word are rounded
 * half-up to the paisa. Returns `null` for empty, malformed, negative (unless
 * `allowNegative`) or out-of-range input.
 */
export function parseMoneyInput(input: string, { allowNegative = false } = {}): Money | null {
  // Direction marks (U+200E, U+200F, U+061C), such as the one formatMoney puts
  // before a minus sign, are not part of the amount (as in money_parse.dart).
  let text = normalizeDigits(input)
    .replace(/[\u200E\u200F\u061C]/gu, "")
    .toLowerCase()
    .trim();
  if (text === "") return null;

  let negative = false;
  if (text.startsWith("-") || text.startsWith("−")) {
    negative = true;
    text = text.slice(1).trim();
  } else if (text.startsWith("+")) {
    text = text.slice(1).trim();
  }

  text = stripCurrencyMarkers(text);
  // A leading sign may follow the currency marker: "Rs -500".
  if (!negative && text.startsWith("-")) {
    negative = true;
    text = text.slice(1).trim();
  }
  if (negative && !allowNegative) return null;

  text = text
    .replaceAll("٫", ".")
    .replaceAll("٬", "")
    .replaceAll(",", "")
    .replaceAll("_", "")
    .replaceAll("'", "");

  let multiplier = 1n;
  for (const unit of UNITS) {
    const match = unit.pattern.exec(text);
    if (match !== null) {
      multiplier = unit.multiplier;
      text = text.slice(0, match.index);
      break;
    }
  }
  text = text.replace(/\s+/gu, "");

  const match = NUMBER_PATTERN.exec(text);
  if (match === null) return null;
  const [, wholeDigits = "", fractionDigits = ""] = match;
  if (multiplier === 1n && fractionDigits.length > 2) return null;

  const scale = 10n ** BigInt(fractionDigits.length);
  const numerator = BigInt(`${wholeDigits}${fractionDigits}`) * multiplier * Money.PAISA_PER_RUPEE;
  const paisa = divideRounded(numerator, scale, "halfUp");
  const signed = negative ? -paisa : paisa;
  if (signed > Money.MAX_VALUE.paisa || signed < Money.MIN_VALUE.paisa) return null;
  return Money.fromPaisa(signed);
}
