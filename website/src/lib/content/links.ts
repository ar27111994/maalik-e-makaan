import { localisePath, type Locale } from "../../i18n/locales.ts";

/**
 * Where a call to action in the content goes: "app" opens the web app, "#…"
 * is a section of the same page, and "/…/" is a page of this site, in the
 * reader's language.
 */
export function contentHref(href: string, locale: Locale, appUrl: string): string {
  if (href === "app") return appUrl;
  if (href.startsWith("#")) return href;
  return localisePath(href, locale);
}
