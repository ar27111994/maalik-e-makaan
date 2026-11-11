// Every built page, in both languages: language and direction, one h1,
// canonical and reciprocal hreflang links, Open Graph tags, structured data,
// the language switch, a clean console, script hygiene and font coverage.
import { readFileSync } from "node:fs";
import { expect, test, type Page } from "@playwright/test";
import { LOCALE_INFO } from "../../src/i18n/locales.ts";
import {
  escapeRegExp,
  fontManifest,
  localPath,
  siteOrigin,
  sitePages,
  type SitePage,
} from "./site.ts";

const pages = sitePages();
// From version 1.0.0 the app is released (src/lib/release.ts reads the same manifest).
const released =
  Number(
    (
      JSON.parse(
        readFileSync(new URL("../../../.release-please-manifest.json", import.meta.url), "utf8"),
      ) as Record<string, string>
    )["."]?.split(".")[0] ?? 0,
  ) >= 1;
const origin = siteOrigin();

test("the site has every page WEB-01 requires, in both languages", () => {
  const neutral = [
    "/",
    "/features/",
    "/pricing/",
    "/roadmap/",
    "/releases/",
    "/company/",
    "/how-it-works/",
    "/faq/",
    "/download/",
    "/privacy/",
    "/terms/",
    "/guides/",
    "/guides/police-registration/",
    "/guides/tenancy-agreement-checklist/",
    "/guides/rental-income-tax/",
    "/guides/utilities-in-your-name/",
    "/tools/",
    "/tools/rent-increase-calculator/",
    "/tools/first-month-rent-calculator/",
    "/tools/s155-withholding-calculator/",
    "/licences/",
  ];
  expect(pages.map((page) => page.path)).toEqual(
    expect.arrayContaining([
      ...neutral,
      ...neutral.map((path) => (path === "/" ? "/ur/" : `/ur${path}`)),
      "/404.html",
      "/ur/404/",
    ]),
  );
});

test("every page has its own title and description", async ({ page }) => {
  const titles = new Map<string, string>();
  const descriptions = new Map<string, string>();
  for (const site of pages.filter((candidate) => !candidate.notFound)) {
    await page.goto(site.path);
    const title = await page.title();
    const description = (await meta(page, 'meta[name="description"]')) ?? "";
    expect(
      titles.get(title),
      `${site.path} repeats the title of ${titles.get(title) ?? ""}`,
    ).toBeUndefined();
    expect(
      descriptions.get(description),
      `${site.path} repeats the description of ${descriptions.get(description) ?? ""}`,
    ).toBeUndefined();
    titles.set(title, site.path);
    descriptions.set(description, site.path);
  }
});

async function alternates(page: Page): Promise<Record<string, string>> {
  const links = await page.locator('head link[rel="alternate"][hreflang]').all();
  const result: Record<string, string> = {};
  for (const link of links) {
    result[(await link.getAttribute("hreflang")) ?? ""] = (await link.getAttribute("href")) ?? "";
  }
  return result;
}

async function meta(page: Page, selector: string): Promise<string | null> {
  const element = page.locator(`head ${selector}`);
  return (await element.count()) === 0 ? null : element.first().getAttribute("content");
}

/** Records console messages, page errors, failed requests and error responses. */
function watch(page: Page): string[] {
  const problems: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") {
      problems.push(`console ${message.type()}: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  page.on("requestfailed", (request) =>
    problems.push(`request failed: ${request.url()} (${request.failure()?.errorText ?? "?"})`),
  );
  page.on("response", (response) => {
    if (response.status() >= 400 && response.request().resourceType() !== "document") {
      problems.push(`HTTP ${response.status()}: ${response.url()}`);
    }
  });
  return problems;
}

for (const site of pages) {
  const info = LOCALE_INFO[site.locale];

  test.describe(site.path, () => {
    test("language, direction, title and a single h1", async ({ page }) => {
      const response = await page.goto(site.path);
      expect(response?.status()).toBe(200);
      await expect(page.locator("html")).toHaveAttribute("lang", info.htmlLang);
      await expect(page.locator("html")).toHaveAttribute("dir", info.dir);
      await expect(page.locator("h1")).toHaveCount(1);
      expect((await page.title()).length).toBeGreaterThan(5);
      const description = (await meta(page, 'meta[name="description"]')) ?? "";
      expect(description.length).toBeGreaterThanOrEqual(50);
      expect(description.length).toBeLessThanOrEqual(165);
      // One of each landmark (an article's own <header> is not a banner).
      await expect(page.getByRole("main")).toHaveCount(1);
      await expect(page.locator("main#main")).toHaveCount(1);
      await expect(page.getByRole("banner")).toHaveCount(1);
      await expect(page.getByRole("contentinfo")).toHaveCount(1);
    });

    test("canonical URL and reciprocal hreflang links", async ({ page }) => {
      await page.goto(site.path);
      const canonical = page.locator('head link[rel="canonical"]');
      if (site.notFound) {
        await expect(canonical).toHaveCount(0);
        expect(await alternates(page)).toEqual({});
        expect(await meta(page, 'meta[name="robots"]')).toBe("noindex");
        return;
      }
      await expect(canonical).toHaveCount(1);
      expect(await canonical.getAttribute("href")).toBe(`${origin}${site.path}`);
      expect(await meta(page, 'meta[name="robots"]')).toContain("index, follow");
      const own = await alternates(page);
      const english = site.locale === "en" ? site.path : site.twin;
      expect(own).toEqual({
        en: `${origin}${english}`,
        ur: `${origin}${site.locale === "ur" ? site.path : site.twin}`,
        "x-default": `${origin}${english}`,
      });
      // Every alternate lists exactly the same set back.
      for (const href of Object.values(own)) {
        await page.goto(localPath(href));
        expect(await alternates(page)).toEqual(own);
      }
    });

    test("Open Graph and Twitter tags", async ({ page, request }) => {
      await page.goto(site.path);
      expect(await meta(page, 'meta[property="og:title"]')).toBe(await page.title());
      expect(await meta(page, 'meta[property="og:locale"]')).toBe(info.ogLocale);
      expect(await meta(page, 'meta[name="twitter:card"]')).toBe("summary_large_image");
      const image = (await meta(page, 'meta[property="og:image"]')) ?? "";
      expect(image).toBe(`${origin}/og/${site.locale}.png`);
      expect(await meta(page, 'meta[property="og:image:width"]')).toBe("1200");
      expect(await meta(page, 'meta[property="og:image:height"]')).toBe("630");
      expect((await meta(page, 'meta[property="og:image:alt"]'))?.length).toBeGreaterThan(10);
      const png = await request.get(localPath(image));
      expect(png.status()).toBe(200);
      expect(png.headers()["content-type"]).toBe("image/png");
      if (!site.notFound) {
        expect(await meta(page, 'meta[property="og:url"]')).toBe(`${origin}${site.path}`);
      }
    });

    test("structured data describes the page as it is shown", async ({ page }) => {
      await page.goto(site.path);
      const blocks = page.locator('script[type="application/ld+json"]');
      if (site.notFound) {
        await expect(blocks).toHaveCount(0);
        return;
      }
      await expect(blocks).toHaveCount(1);
      const data = JSON.parse((await blocks.textContent()) ?? "") as {
        "@context": string;
        "@graph": Record<string, unknown>[];
      };
      expect(data["@context"]).toBe("https://schema.org");
      const graph = data["@graph"];
      const byType = (type: string) => graph.filter((node) => node["@type"] === type);
      expect(byType("Organization")).toHaveLength(1);
      expect(byType("WebSite")).toHaveLength(1);
      const url = `${origin}${site.path}`;
      const webPage = graph.find((node) => node["@id"] === `${url}#webpage`);
      expect(webPage).toMatchObject({ url, inLanguage: info.htmlLang });

      const crumbs = page.locator("nav.breadcrumbs a");
      const breadcrumbList = byType("BreadcrumbList")[0];
      if ((await crumbs.count()) === 0) {
        expect(breadcrumbList).toBeUndefined();
      } else {
        const visible = await crumbs.evaluateAll((links) =>
          links.map((link) => ({
            name: link.textContent.trim(),
            item: (link as HTMLAnchorElement).href,
          })),
        );
        const items = (breadcrumbList?.itemListElement ?? []) as Record<string, unknown>[];
        expect(
          items.map((item) => ({ name: item.name, item: localPath(String(item.item)) })),
        ).toEqual(
          visible.map((crumb) => ({ name: crumb.name, item: new URL(crumb.item).pathname })),
        );
        expect(webPage?.breadcrumb).toEqual({ "@id": `${url}#breadcrumb` });
      }

      if (site.path === "/" || site.path === "/ur/") {
        // Before version 1.0 the app's address showed a holding page, so no main button
        // led there: the hero offered the calculators, the closing band the download
        // page. From 1.0 both lead to the web app (src/lib/release.ts: APP_STATUS).
        const app = byType("SoftwareApplication")[0];
        const appUrl = String(app?.url);
        const buttons = await page
          .locator(".button--primary")
          .evaluateAll((links) => links.map((link) => link.getAttribute("href") ?? ""));
        if (released) {
          // Once version 1.0 is out, both main buttons open the web app itself.
          expect(buttons).toEqual([appUrl, appUrl]);
        } else {
          expect(buttons).toEqual([
            site.path === "/" ? "/tools/" : "/ur/tools/",
            site.path === "/" ? "/download/" : "/ur/download/",
          ]);
          expect(buttons).not.toContain(appUrl);
        }
      }

      // The questions page is the site's one FAQPage, and states exactly the questions shown.
      if (site.path === "/faq/" || site.path === "/ur/faq/") {
        expect(webPage?.["@type"]).toBe("FAQPage");
        const shown = await page.locator("#faq h3").allTextContents();
        const answers = await page.locator("#faq h3 + p").allTextContents();
        const entities = webPage?.mainEntity as {
          name: string;
          acceptedAnswer: { text: string };
        }[];
        expect(entities.map((entity) => entity.name)).toEqual(shown.map((q) => q.trim()));
        expect(entities.map((entity) => entity.acceptedAnswer.text)).toEqual(
          answers.map((a) => a.trim()),
        );
      } else {
        expect(graph.filter((node) => node["@type"] === "FAQPage")).toEqual([]);
      }

      // A calculator is a free web application.
      if (/^(\/ur)?\/tools\/[a-z0-9-]+\/$/.test(site.path)) {
        expect(byType("WebApplication")[0]).toMatchObject({
          url,
          isAccessibleForFree: true,
          inLanguage: info.htmlLang,
        });
      }
    });

    // Guides only: /guides/<slug>/ and /ur/guides/<slug>/.
    if (/^(\/ur)?\/guides\/[a-z0-9-]+\/$/.test(site.path)) {
      test("a guide shows its review date, the not-advice notice and its sources", async ({
        page,
      }) => {
        await page.goto(site.path);
        const time = page.locator(".guide__reviewed time");
        const reviewed = await time.getAttribute("datetime");
        expect(reviewed).toMatch(/^\d{4}-\d{2}-\d{2}$/);
        // "Last reviewed: 5 November 2026": the label, a colon, one space, the date.
        expect((await page.locator(".guide__reviewed").textContent())?.trim()).toMatch(/\S: \S/);
        await expect(page.locator(".guide__notice")).toBeVisible();
        expect(await page.locator(".sources li a").count()).toBeGreaterThan(0);
        // Every claim cites a source inline: the body links to official texts.
        expect(await page.locator(".prose a[href^='http']").count()).toBeGreaterThan(2);
        const data = JSON.parse(
          (await page.locator('script[type="application/ld+json"]').textContent()) ?? "",
        ) as { "@graph": Record<string, unknown>[] };
        const article = data["@graph"].find((node) => node["@type"] === "Article");
        expect(article).toMatchObject({ dateModified: reviewed, inLanguage: info.htmlLang });
        expect(article?.citation).toHaveLength(await page.locator(".sources li").count());
        // Guides sit under the guides index in the breadcrumb trail.
        await expect(page.locator("nav.breadcrumbs a")).toHaveCount(3);
      });
    }

    test("the language switch leads to the same page in the other language", async ({ page }) => {
      await page.goto(site.path);
      const other = site.locale === "en" ? "ur" : "en";
      const switchLink = page.locator("header [data-language-switch]");
      await expect(switchLink).toHaveCount(1);
      await expect(switchLink).toBeVisible();
      await expect(switchLink).toHaveAttribute("href", site.twin);
      await expect(switchLink).toHaveAttribute("hreflang", other);
      await expect(switchLink).toHaveAttribute("lang", LOCALE_INFO[other].htmlLang);
      await switchLink.click();
      await expect(page).toHaveURL(new RegExp(`${escapeRegExp(site.twin)}$`));
      await expect(page.locator("html")).toHaveAttribute("lang", LOCALE_INFO[other].htmlLang);
      await expect(page.locator("header [data-language-switch]")).toHaveAttribute(
        "href",
        site.path,
      );
    });

    test("loads with no console errors or warnings and no failed requests", async ({ page }) => {
      const problems = watch(page);
      await page.goto(site.path, { waitUntil: "networkidle" });
      await page.evaluate(async () => {
        await document.fonts.ready;
      });
      expect(problems).toEqual([]);
    });

    test("each language keeps to its script", async ({ page }) => {
      await page.goto(site.path);
      // Text outside an element of the other language, by script.
      const stray = await page.evaluate((pageLocale) => {
        const otherLang = pageLocale === "en" ? "ur" : "en";
        const pattern = pageLocale === "en" ? /[؀-ۿ]/ : /[A-Za-z]/;
        const found: string[] = [];
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
          // With scripting on, <noscript> holds its markup as raw text, never shown.
          if (node.parentElement?.closest("noscript") !== null) continue;
          const text = node.textContent ?? "";
          if (!pattern.test(text)) continue;
          const lang = node.parentElement.closest("[lang]")?.getAttribute("lang") ?? "";
          if (!lang.startsWith(otherLang)) found.push(text.trim());
        }
        return found;
      }, site.locale);
      expect(stray).toEqual([]);
    });

    test("every character has a glyph in the self-hosted fonts", async ({ page }) => {
      await page.goto(site.path);
      const manifest = fontManifest();
      const covered = (family: string) =>
        new Set(
          manifest.filter((font) => font.family === family).flatMap((font) => [...font.codePoints]),
        );
      const urdu = covered("Noto Nastaliq Urdu");
      const label = covered("MM Nastaliq Label");
      const latin = covered("Atkinson Hyperlegible Next");
      const text = await page.evaluate(() => {
        const runs: { text: string; family: string }[] = [];
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
          const parent = node.parentElement;
          if (parent === null || (node.textContent ?? "").trim() === "") continue;
          if (parent.closest("noscript") !== null) continue;
          runs.push({ text: node.textContent ?? "", family: getComputedStyle(parent).fontFamily });
        }
        return runs;
      });
      const missing = new Set<string>();
      for (const run of text) {
        const primary = run.family.split(",")[0]?.replace(/"/g, "").trim() ?? "";
        for (const char of run.text) {
          const code = char.codePointAt(0) ?? 0;
          // Spaces, and invisible format controls such as the bidi isolates U+2066 and
          // U+2069 around a figure in Urdu text, are never drawn, so need no glyph.
          if (/[\s\p{Cf}]/u.test(char)) continue;
          const arabic = code >= 0x0600 && code <= 0x06ff;
          const set = arabic ? (primary === "MM Nastaliq Label" ? label : urdu) : latin;
          if (!set.has(code))
            missing.add(`${char} (U+${code.toString(16).toUpperCase()}) in ${primary}`);
        }
      }
      expect([...missing]).toEqual([]);
      const families = await page.evaluate(async () => {
        await document.fonts.ready;
        return [...document.fonts]
          .filter((face) => face.status === "loaded")
          .map((face) => face.family.replace(/"/g, ""));
      });
      expect(families).toContain("Atkinson Hyperlegible Next");
      if (site.locale === "ur") expect(families).toContain("Noto Nastaliq Urdu");
    });
  });
}

test("a missing page answers 404 with the not-found page, in either language", async ({ page }) => {
  for (const path of ["/no-such-page/", "/ur/no-such-page/"]) {
    const response = await page.goto(path);
    expect(response?.status()).toBe(404);
    await expect(page.locator("h1")).toHaveText("Page not found");
    await expect(page.locator('section[lang="ur"] h2')).toHaveText("صفحہ نہیں ملا");
    await expect(page.locator('head meta[name="robots"]')).toHaveAttribute("content", "noindex");
  }
});

test("language twins are mutual: each page's twin points back at it", () => {
  const twins = new Map(pages.map((page: SitePage) => [page.path, page.twin]));
  for (const [path, twin] of twins) expect(twins.get(twin)).toBe(path);
});
