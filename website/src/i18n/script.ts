import { LOCALE_INFO, type Locale } from "./locales.ts";

/**
 * The language a short text such as a source's title is written in, judged by
 * its script: Latin letters mean English, Arabic-script letters Urdu. Pages
 * mark text with this so screen readers pronounce it correctly and the right
 * font is used.
 */
export function languageOfText(text: string): Locale | undefined {
  const latin = /[A-Za-z]/.test(text);
  const arabic = /[؀-ۿ]/.test(text);
  if (latin === arabic) return undefined;
  return latin ? "en" : "ur";
}

/** The `lang` attribute for `text` on a page in `pageLocale`, when it differs from the page's. */
export function langAttribute(text: string, pageLocale: Locale): string | undefined {
  const language = languageOfText(text);
  return language === undefined || language === pageLocale
    ? undefined
    : LOCALE_INFO[language].htmlLang;
}

/**
 * `lang` and `dir` for a short text in the other language: the `dir` isolates
 * it, so an English title's punctuation and numbers stay in order inside an
 * Urdu sentence (and the other way round).
 */
export function scriptAttributes(
  text: string,
  pageLocale: Locale,
): { lang?: string; dir?: "ltr" | "rtl" } {
  const language = languageOfText(text);
  if (language === undefined || language === pageLocale) return {};
  return { lang: LOCALE_INFO[language].htmlLang, dir: LOCALE_INFO[language].dir };
}

/** A piece of a text: a number range such as "2026-27", or the text between. */
export interface TextPart {
  readonly text: string;
  readonly numberRange: boolean;
}

/**
 * `text` cut where a number range such as "2026-27" stands. On a right-to-left
 * page each range needs a left-to-right run of its own: after Urdu words the
 * bidi algorithm reads its digits as Arabic numbers, which a hyphen does not
 * join, and draws "2026-27" as "27-2026".
 */
export function numberRanges(text: string): TextPart[] {
  const parts: TextPart[] = [];
  let last = 0;
  for (const match of text.matchAll(/[0-9]+(?:[-–][0-9]+)+/gu)) {
    if (match.index > last) parts.push({ text: text.slice(last, match.index), numberRange: false });
    parts.push({ text: match[0], numberRange: true });
    last = match.index + match[0].length;
  }
  if (last < text.length) parts.push({ text: text.slice(last), numberRange: false });
  return parts;
}
