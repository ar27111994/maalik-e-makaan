/**
 * Digit normalisation for input typed on Urdu, Arabic or Persian keyboards.
 * Mirrors packages/mm_core/lib/src/text/digits.dart: Extended Arabic-Indic
 * (Urdu, U+06F0–U+06F9), Arabic-Indic (U+0660–U+0669) and full-width
 * (U+FF10–U+FF19) digits become ASCII; everything else is kept.
 */

const ASCII_ZERO = 0x30;
const ZEROS = [0x0660, 0x06f0, 0xff10] as const;

export function normalizeDigits(input: string): string {
  let output = "";
  for (const char of input) {
    const code = char.codePointAt(0) ?? 0;
    const zero = ZEROS.find((candidate) => code >= candidate && code <= candidate + 9);
    output += zero === undefined ? char : String.fromCharCode(ASCII_ZERO + (code - zero));
  }
  return output;
}

/** Writes ASCII digits with Urdu (Extended Arabic-Indic) numerals `۰۱۲۳۴۵۶۷۸۹`. */
export function toUrduDigits(input: string): string {
  return input.replace(/[0-9]/g, (digit) => String.fromCharCode(0x06f0 + Number(digit)));
}
