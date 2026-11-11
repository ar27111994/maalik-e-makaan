// robots.txt, the sitemap with its hreflang alternates, and llms.txt.
import { expect, test } from "@playwright/test";
import { localPath, siteOrigin, sitePages } from "./site.ts";

const origin = siteOrigin();
const indexable = sitePages().filter((page) => !page.notFound);

test("robots.txt welcomes every crawler, names the AI crawlers and links the sitemap", async ({
  request,
}) => {
  const text = await (await request.get("/robots.txt")).text();
  expect(text).toContain("User-agent: *\nAllow: /");
  for (const agent of [
    "GPTBot",
    "ClaudeBot",
    "Google-Extended",
    "PerplexityBot",
    "CCBot",
    "OAI-SearchBot",
  ]) {
    expect(text).toContain(`User-agent: ${agent}`);
  }
  expect(text).not.toContain("Disallow");
  expect(text).toContain(`Sitemap: ${origin}/sitemap-index.xml`);
});

test("the sitemap lists every indexable page, with en, ur and x-default alternates", async ({
  request,
}) => {
  const index = await (await request.get("/sitemap-index.xml")).text();
  const sitemaps = [...index.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1] ?? "");
  expect(sitemaps).toEqual([`${origin}/sitemap-0.xml`]);
  const xml = await (await request.get(localPath(sitemaps[0] ?? ""))).text();
  const entries = [...xml.matchAll(/<url>([\s\S]*?)<\/url>/g)].map((match) => match[1] ?? "");
  const locs = entries.map((entry) => /<loc>([^<]+)<\/loc>/.exec(entry)?.[1]);
  expect(locs.sort()).toEqual(indexable.map((page) => `${origin}${page.path}`).sort());
  for (const entry of entries) {
    const links: Record<string, string> = {};
    for (const match of entry.matchAll(
      /<xhtml:link rel="alternate" hreflang="([^"]+)" href="([^"]+)"\/>/g,
    )) {
      links[match[1] ?? ""] = match[2] ?? "";
    }
    expect(Object.keys(links).sort()).toEqual(["en", "ur", "x-default"]);
    expect(links["x-default"]).toBe(links.en);
  }
  expect(xml).not.toContain("/404");
});

test("llms.txt follows llmstxt.org and every link in it resolves", async ({ request }) => {
  const text = await (await request.get("/llms.txt")).text();
  const lines = text.split("\n");
  expect(lines[0]).toMatch(/^# Maalik-e-Makaan/);
  expect(lines[2]).toMatch(/^> \S/);
  const links = [...text.matchAll(/\]\((https?:\/\/[^)]+)\)/g)].map((match) => match[1] ?? "");
  const own = links.filter((link) => link.startsWith(origin));
  expect(own.length).toBeGreaterThanOrEqual(5);
  for (const link of own) expect((await request.get(localPath(link))).status(), link).toBe(200);
});

test("llms-full.txt joins Urdu text with the Urdu comma and full stop", async ({ request }) => {
  const full = await (await request.get("/llms-full.txt")).text();
  const start = full.indexOf(`URL: ${origin}/ur/`);
  expect(start).toBeGreaterThan(0);
  // A Latin "," or "." beside an Urdu word, where Urdu writes "،" and "۔". A
  // Markdown list or heading number such as "1. " is not punctuation.
  const pattern = /[؀-ۿ][^\S\n]*[,.]|[,.][^\S\n]*[؀-ۿ]/u;
  const stray = full
    .slice(start)
    .split("\n")
    .filter((line) => pattern.test(line.replace(/^(#+ )?\d+\. /u, "")));
  expect(stray).toEqual([]);
});

test("llms-full.txt holds the text of every indexable page", async ({ page, request }) => {
  const full = await (await request.get("/llms-full.txt")).text();
  for (const site of indexable) {
    await page.goto(site.path);
    const heading = (await page.locator("h1").textContent())?.trim() ?? "";
    expect(full, site.path).toContain(heading);
    expect(full).toContain(`URL: ${origin}${site.path}`);
  }
});
