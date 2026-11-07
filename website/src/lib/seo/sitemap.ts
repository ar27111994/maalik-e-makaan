import type { SitemapItem } from "@astrojs/sitemap";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parse } from "yaml";

/**
 * Adds an `x-default` alternate (the English page) to a sitemap entry that
 * @astrojs/sitemap has already given its `en` and `ur` alternates, so the
 * sitemap states the same hreflang set as each page's <head>.
 */
export function sitemapItemWithDefault(item: SitemapItem): SitemapItem {
  const links = item.links ?? [];
  const english = links.find((link) => link.lang === "en");
  if (english === undefined || links.some((link) => link.lang === "x-default")) return item;
  return { ...item, links: [...links, { lang: "x-default", url: english.url }] };
}

/** Where each dated collection's pages are served: guides, calculators and text pages. */
const DATED_COLLECTIONS = [
  { folder: "guides", prefix: "/guides/", field: "lastReviewed" },
  { folder: "tools", prefix: "/tools/", field: "lastReviewed" },
  { folder: "pages", prefix: "/", field: "lastUpdated" },
] as const;

/** A Markdown file's front matter, or an empty object. */
function frontMatter(text: string): Record<string, unknown> {
  const match = /^---\n([\s\S]*?)\n---/.exec(text);
  const data: unknown = match === null ? {} : parse(match[1] ?? "");
  return typeof data === "object" && data !== null ? (data as Record<string, unknown>) : {};
}

/**
 * The date each dated page was last reviewed or updated, by URL path
 * ("/ur/guides/rental-income-tax/" → "2026-11-05"), read from the content's
 * front matter so the sitemap's <lastmod> always matches the date on the page.
 */
export function contentDates(contentRoot: string): Map<string, string> {
  const dates = new Map<string, string>();
  for (const { folder, prefix, field } of DATED_COLLECTIONS) {
    for (const locale of ["en", "ur"] as const) {
      const directory = join(contentRoot, folder, locale);
      for (const file of readdirSync(directory).filter((name) => name.endsWith(".md"))) {
        const value = frontMatter(readFileSync(join(directory, file), "utf8"))[field];
        const date =
          value instanceof Date
            ? value.toISOString().slice(0, 10)
            : typeof value === "string"
              ? value
              : undefined;
        if (date === undefined || !/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
        const slug = file.replace(/\.md$/, "");
        dates.set(`${locale === "en" ? "" : "/ur"}${prefix}${slug}/`, date);
      }
    }
  }
  return dates;
}

/** A sitemap entry with its x-default alternate and, for a dated page, its <lastmod>. */
export function sitemapItem(item: SitemapItem, dates: ReadonlyMap<string, string>): SitemapItem {
  const withDefault = sitemapItemWithDefault(item);
  const date = dates.get(new URL(item.url).pathname);
  return date === undefined ? withDefault : { ...withDefault, lastmod: date };
}
