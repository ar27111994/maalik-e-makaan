// Mobile-first layout and the user's display preferences: no sideways
// scrolling from 320 px up (WCAG 1.4.10), room for adjusted text spacing
// (1.4.12), right-to-left mirroring, dark mode, reduced motion and forced colours.
import { expect, test, type Page } from "@playwright/test";
import { sitePages } from "./site.ts";

const pages = sitePages();

async function overflow(page: Page): Promise<number> {
  return page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
}

for (const site of pages) {
  test(`${site.path} reflows at 320 px without sideways scrolling`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 640 });
    await page.goto(site.path);
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    expect(await overflow(page)).toBe(0);
  });

  test.describe(`${site.path} with the reader's own text settings`, () => {
    // The test styles go in as an inline <style>, which the site's CSP rightly blocks.
    test.use({ bypassCSP: true });

    test(`${site.path} survives WCAG 1.4.12 text spacing at 320 px`, async ({ page }) => {
      await page.setViewportSize({ width: 320, height: 640 });
      await page.goto(site.path);
      await page.addStyleTag({
        content:
          "* { line-height: 1.5 !important; letter-spacing: 0.12em !important; word-spacing: 0.16em !important; } p { margin-block-end: 2em !important; }",
      });
      await page.evaluate(async () => {
        await document.fonts.ready;
      });
      expect(await overflow(page)).toBe(0);
    });

    test(`${site.path} at 200% text size on a 1280 px screen`, async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(site.path);
      await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
      expect(await overflow(page)).toBe(0);
    });
  });
}

test("the Urdu pages mirror: the brand sits at the right edge, the switch at the left", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  for (const path of ["/", "/ur/"]) {
    await page.goto(path);
    const brand = await page.locator(".brand").boundingBox();
    const switchLink = await page.locator("header [data-language-switch]").boundingBox();
    if (brand === null || switchLink === null) throw new Error("header not rendered");
    if (path === "/") expect(brand.x).toBeLessThan(switchLink.x);
    else expect(brand.x).toBeGreaterThan(switchLink.x);
  }
});

test("Urdu text is set in Nastaliq with twice the line height; amounts use Latin figures", async ({
  page,
}) => {
  await page.goto("/ur/");
  const body = await page.evaluate(() => {
    const style = getComputedStyle(document.body);
    return { family: style.fontFamily, fontSize: style.fontSize, lineHeight: style.lineHeight };
  });
  expect(body.family).toMatch(/^"?Noto Nastaliq Urdu"?/);
  expect(Number.parseFloat(body.lineHeight) / Number.parseFloat(body.fontSize)).toBeCloseTo(2, 5);
  const amount = await page
    .locator(".receipt .amount")
    .first()
    .evaluate((element) => ({
      family: getComputedStyle(element).fontFamily,
      numeric: getComputedStyle(element).fontVariantNumeric,
      text: element.textContent,
    }));
  expect(amount.family).toMatch(/^"?Atkinson Hyperlegible Next"?/);
  expect(amount.numeric).toBe("tabular-nums");
  expect(amount.text).toBe("45,000\u00A0روپے");
});

test("dark mode uses the design tokens' dark colours", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto("/");
  const colours = await page.evaluate(() => ({
    background: getComputedStyle(document.body).backgroundColor,
    text: getComputedStyle(document.body).color,
  }));
  // design/tokens/maalik.tokens.json: color.dark.bg #0F1419 and color.dark.ink #E6EAF0.
  expect(colours).toEqual({ background: "rgb(15, 20, 25)", text: "rgb(230, 234, 240)" });
  await page.emulateMedia({ colorScheme: "light" });
  expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe(
    "rgb(244, 245, 247)",
  );
});

test("reduced motion turns off smooth scrolling and transitions", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  const motion = await page.evaluate(() => {
    const button = document.querySelector(".button");
    if (button === null) throw new Error("no .button on the page");
    return {
      scroll: getComputedStyle(document.documentElement).scrollBehavior,
      transition: getComputedStyle(button).transitionDuration,
      duration: Number.parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue("--mm-duration-quick"),
      ),
    };
  });
  expect(motion).toEqual({ scroll: "auto", transition: "0s", duration: 0 });
  await page.emulateMedia({ reducedMotion: "no-preference" });
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior)).toBe(
    "smooth",
  );
});

test("forced colours keep controls and cards outlined, and focus visible", async ({ page }) => {
  await page.emulateMedia({ forcedColors: "active" });
  await page.goto("/");
  const borders = await page.evaluate(() =>
    [...document.querySelectorAll(".button, .card, .language-switch")].map((element) => {
      const style = getComputedStyle(element);
      return {
        style: style.borderBlockStartStyle,
        width: Number.parseFloat(style.borderBlockStartWidth),
        forced: style.forcedColorAdjust,
      };
    }),
  );
  expect(borders.length).toBeGreaterThan(5);
  for (const border of borders) {
    expect(border.style).toBe("solid");
    expect(border.width).toBeGreaterThan(0);
  }
  await page.keyboard.press("Tab");
  const outline = await page.evaluate(() =>
    document.activeElement === null
      ? "none"
      : getComputedStyle(document.activeElement).outlineStyle,
  );
  expect(outline).toBe("solid");
});
