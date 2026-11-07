import { describe, expect, test } from "vitest";
import { NAMED_CRAWLERS, robotsTxt } from "../../src/lib/robots.ts";
import { sitemapItemWithDefault } from "../../src/lib/seo/sitemap.ts";

describe("robots.txt", () => {
  const text = robotsTxt("https://example.pk");

  test("allows every crawler and names the search and AI crawlers explicitly", () => {
    expect(text).toContain("User-agent: *\nAllow: /");
    for (const agent of [
      "GPTBot",
      "OAI-SearchBot",
      "ChatGPT-User",
      "ClaudeBot",
      "Claude-SearchBot",
      "Claude-User",
      "Google-Extended",
      "PerplexityBot",
      "CCBot",
      "Applebot-Extended",
      "Googlebot",
      "Bingbot",
    ]) {
      expect(NAMED_CRAWLERS).toContain(agent);
      expect(text).toContain(`User-agent: ${agent}\n`);
    }
    expect(text).not.toMatch(/^Disallow:/m);
  });

  test("points at the sitemap index with an absolute URL", () => {
    expect(text).toContain("Sitemap: https://example.pk/sitemap-index.xml\n");
  });

  test("uses only directives that RFC 9309 and the major crawlers understand", () => {
    for (const line of text.split("\n")) {
      if (line === "" || line.startsWith("#")) continue;
      expect(line).toMatch(/^(User-agent|Allow|Sitemap): \S/);
    }
  });
});

describe("sitemap entries", () => {
  test("gain an x-default alternate pointing at the English page", () => {
    const item = {
      url: "https://example.pk/ur/",
      links: [
        { lang: "en", url: "https://example.pk/" },
        { lang: "ur", url: "https://example.pk/ur/" },
      ],
    };
    expect(sitemapItemWithDefault(item).links).toEqual([
      ...item.links,
      { lang: "x-default", url: "https://example.pk/" },
    ]);
  });

  test("are left alone without alternates or when x-default is already there", () => {
    const bare = { url: "https://example.pk/" };
    expect(sitemapItemWithDefault(bare)).toBe(bare);
    const done = {
      url: "https://example.pk/",
      links: [
        { lang: "en", url: "a" },
        { lang: "x-default", url: "a" },
      ],
    };
    expect(sitemapItemWithDefault(done)).toBe(done);
  });
});
