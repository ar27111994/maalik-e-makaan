import type { SitemapItem } from "@astrojs/sitemap";

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
