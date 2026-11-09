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
