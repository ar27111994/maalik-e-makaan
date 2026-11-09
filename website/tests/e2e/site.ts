/**
 * What the e2e suite knows about the built site: every HTML page in dist/,
 * its language and twin, the site's origin and the font subsets.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { delocalisePath, localisePath, otherLocale, type Locale } from "../../src/i18n/locales.ts";

export const dist = fileURLToPath(new URL("../../dist/", import.meta.url));

export interface SitePage {
  /** The URL path the page is served at. */
  readonly path: string;
  readonly locale: Locale;
  /** The not-found pages: no canonical URL, kept out of search results. */
  readonly notFound: boolean;
  /** The same page in the other language. */
  readonly twin: string;
}

function walk(directory: string): string[] {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

const NOT_FOUND: Readonly<Record<string, { locale: Locale; twin: string }>> = {
  "/404.html": { locale: "en", twin: "/ur/404/" },
  "/ur/404/": { locale: "ur", twin: "/404.html" },
};

/** Every HTML page in dist/, sorted by path. */
export function sitePages(): SitePage[] {
  return walk(dist)
    .filter((file) => file.endsWith(".html"))
    .map((file) => `/${relative(dist, file).replace(/index\.html$/, "")}`)
    .sort()
    .map((path) => {
      const notFound = NOT_FOUND[path];
      if (notFound !== undefined) return { path, ...notFound, notFound: true };
      const { locale, path: neutral } = delocalisePath(path);
      return { path, locale, notFound: false, twin: localisePath(neutral, otherLocale(locale)) };
    });
}

/** The origin the build used for canonical URLs (SITE_URL), read from the sitemap. */
export function siteOrigin(): string {
  const index = readFileSync(join(dist, "sitemap-index.xml"), "utf8");
  const loc = /<loc>([^<]+)<\/loc>/.exec(index)?.[1];
  if (loc === undefined) throw new Error("dist/sitemap-index.xml lists no sitemap");
  return new URL(loc).origin;
}

/** The local path of one of the site's absolute URLs. */
export function localPath(absolute: string): string {
  const url = new URL(absolute);
  if (url.origin !== siteOrigin()) throw new Error(`${absolute} is not on ${siteOrigin()}`);
  return url.pathname;
}

/** The code points of a CSS unicode-range such as "U+20-7E, U+A0". */
export function codePointsOfRange(range: string): number[] {
  return range.split(",").flatMap((part) => {
    const [from = "", to = from] = part.trim().replace(/^U\+/i, "").split("-");
    const start = Number.parseInt(from, 16);
    const end = Number.parseInt(to, 16);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  });
}

/** Each font subset's family and the code points it covers (src/generated/fonts.json). */
export function fontManifest(): { family: string; codePoints: Set<number> }[] {
  const manifest = JSON.parse(
    readFileSync(new URL("../../src/generated/fonts.json", import.meta.url), "utf8"),
  ) as Record<string, { family: string; unicodeRange: string }>;
  return Object.values(manifest).map((font) => ({
    family: font.family,
    codePoints: new Set(codePointsOfRange(font.unicodeRange)),
  }));
}

/** [text] as a regular expression that matches it literally. */
export function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
