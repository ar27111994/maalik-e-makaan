/**
 * The site's two languages and the rules that map a page between them.
 *
 * Every page has a locale-neutral path such as "/" or "/guides/police-registration/".
 * English is served at that path; Urdu at the same path under "/ur". The URL
 * slugs stay in English in both languages, so switching language keeps the
 * reader on the same page.
 */

export const LOCALES = ["en", "ur"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "en";

export interface LocaleInfo {
  /** The `lang` attribute of the page. English copy is written in British English. */
  readonly htmlLang: string;
  readonly dir: "ltr" | "rtl";
  /** The `hreflang` value for alternate links and the sitemap. */
  readonly hreflang: string;
  /** Open Graph locale. */
  readonly ogLocale: string;
  /** The language's own name, shown in the language switch. */
  readonly endonym: string;
  /**
   * The comma and the space after it, for text a page joins from parts (a
   * source and its publisher, a name and a role): Urdu writes "،", not ",".
   */
  readonly comma: string;
}

export const LOCALE_INFO: Readonly<Record<Locale, LocaleInfo>> = {
  en: {
    htmlLang: "en-GB",
    dir: "ltr",
    hreflang: "en",
    ogLocale: "en_GB",
    endonym: "English",
    comma: ", ",
  },
  ur: {
    htmlLang: "ur",
    dir: "rtl",
    hreflang: "ur",
    ogLocale: "ur_PK",
    endonym: "اردو",
    comma: "، ",
  },
};

const URDU_PREFIX = "/ur";

export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (LOCALES as readonly string[]).includes(value);
}

/** The other language. */
export function otherLocale(locale: Locale): Locale {
  return locale === "en" ? "ur" : "en";
}

function assertNeutralPath(path: string): void {
  if (!path.startsWith("/") || path.startsWith("//")) {
    throw new Error(`A page path must start with a single "/": ${JSON.stringify(path)}`);
  }
  if (path === URDU_PREFIX || path.startsWith(`${URDU_PREFIX}/`)) {
    throw new Error(
      `A page path must be locale-neutral (no "/ur" prefix): ${JSON.stringify(path)}`,
    );
  }
}

/** The URL path of a locale-neutral page path in `locale`: "/x/" → "/x/" or "/ur/x/". */
export function localisePath(path: string, locale: Locale): string {
  assertNeutralPath(path);
  if (locale === "en") return path;
  return path === "/" ? `${URDU_PREFIX}/` : `${URDU_PREFIX}${path}`;
}

/** Splits a URL path into its locale and locale-neutral page path. */
export function delocalisePath(pathname: string): { locale: Locale; path: string } {
  if (pathname === URDU_PREFIX || pathname === `${URDU_PREFIX}/`)
    return { locale: "ur", path: "/" };
  if (pathname.startsWith(`${URDU_PREFIX}/`))
    return { locale: "ur", path: pathname.slice(URDU_PREFIX.length) };
  return { locale: "en", path: pathname };
}

/** An absolute URL on the site. `site` is an origin such as "https://example.com". */
export function absoluteUrl(site: string | URL, path: string): string {
  return new URL(path, site).href;
}

export interface AlternateLink {
  readonly hreflang: string;
  readonly href: string;
}

/**
 * The reciprocal alternates every page lists: one per language, plus
 * `x-default`, which points at the English page.
 */
export function alternateLinks(site: string | URL, path: string): AlternateLink[] {
  const links = LOCALES.map((locale) => ({
    hreflang: LOCALE_INFO[locale].hreflang,
    href: absoluteUrl(site, localisePath(path, locale)),
  }));
  return [
    ...links,
    { hreflang: "x-default", href: absoluteUrl(site, localisePath(path, DEFAULT_LOCALE)) },
  ];
}
