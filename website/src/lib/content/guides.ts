import { LOCALES, isLocale, type Locale } from "../../i18n/locales.ts";

/**
 * Guides live at src/content/guides/<locale>/<slug>.md(x). The same slug in
 * both folders is the same guide in two languages, served at
 * /guides/<slug>/ and /ur/guides/<slug>/.
 */

const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export interface GuideRef {
  readonly locale: Locale;
  readonly slug: string;
}

/**
 * Reads the locale and slug from the id of an entry in a collection kept as
 * <locale>/<slug> files, such as "ur/police-registration".
 */
export function parseLocalisedId(id: string, collection: string): GuideRef {
  const [locale, slug, ...rest] = id.split("/");
  if (!isLocale(locale) || slug === undefined || rest.length > 0 || !SLUG.test(slug)) {
    throw new Error(
      `"${id}" must be at src/content/${collection}/<${LOCALES.join("|")}>/<slug>.md(x), with a lower-case, hyphenated slug`,
    );
  }
  return { locale, slug };
}

/** Reads the locale and slug from a guide's id such as "ur/police-registration". */
export function parseGuideId(id: string): GuideRef {
  return parseLocalisedId(id, "guides");
}

/** The locale-neutral page path of a guide. */
export function guidePath(slug: string): string {
  return `/guides/${slug}/`;
}

/**
 * Checks that every published guide exists in both languages, and returns
 * the published guides of `locale`. A guide in one language only fails the
 * build: the site promises every page in English and Urdu.
 */
export function publishedGuides<T extends { id: string; data: { draft: boolean } }>(
  entries: readonly T[],
  locale: Locale,
): (T & { ref: GuideRef })[] {
  return pairedEntries(
    entries.filter((entry) => !entry.data.draft),
    locale,
    "guides",
  );
}

/**
 * Checks that every entry of a <locale>/<slug> collection exists in both
 * languages, and returns the entries of `locale`, sorted by slug. An entry in
 * one language only fails the build: the site promises every page in English
 * and Urdu.
 */
export function pairedEntries<T extends { id: string }>(
  entries: readonly T[],
  locale: Locale,
  collection: string,
): (T & { ref: GuideRef })[] {
  const published = entries.map((entry) => ({
    ...entry,
    ref: parseLocalisedId(entry.id, collection),
  }));
  const slugsByLocale = new Map<Locale, Set<string>>(LOCALES.map((l) => [l, new Set<string>()]));
  for (const entry of published) slugsByLocale.get(entry.ref.locale)?.add(entry.ref.slug);
  const missing: string[] = [];
  for (const entry of published) {
    for (const other of LOCALES) {
      if (!slugsByLocale.get(other)?.has(entry.ref.slug))
        missing.push(`${other}/${entry.ref.slug}`);
    }
  }
  if (missing.length > 0) {
    throw new Error(
      `Every entry of ${collection} needs both languages. Missing: ${[...new Set(missing)].sort().join(", ")}`,
    );
  }
  return published
    .filter((entry) => entry.ref.locale === locale)
    .sort((a, b) => a.ref.slug.localeCompare(b.ref.slug, "en"));
}
