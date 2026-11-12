// Mobile-first layout and the user's display preferences: no sideways
// scrolling from 320 px up (WCAG 1.4.10), room for adjusted text spacing
// (1.4.12), right-to-left mirroring, dark mode, reduced motion and forced colours.
import { readFileSync } from "node:fs";
import { expect, test, type Locator, type Page } from "@playwright/test";
import sharp from "sharp";
import { sitePages } from "./site.ts";

const pages = sitePages();
const urduTypography = (
  JSON.parse(
    readFileSync(new URL("../../../design/tokens/maalik.tokens.json", import.meta.url), "utf8"),
  ) as {
    typography: { urdu: Record<string, { $value: { lineHeight: number; fontWeight: number } }> };
  }
).typography.urdu;

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

test("Urdu text is set in Noto Sans Arabic on the Urdu body line, the brand name in the Nastaliq wordmark; amounts use Latin figures", async ({
  page,
}) => {
  await page.goto("/ur/");
  const body = await page.evaluate(() => {
    const style = getComputedStyle(document.body);
    return { family: style.fontFamily, fontSize: style.fontSize, lineHeight: style.lineHeight };
  });
  expect(body.family).toMatch(/^"?Noto Sans Arabic"?/);
  expect(Number.parseFloat(body.lineHeight) / Number.parseFloat(body.fontSize)).toBeCloseTo(
    urduTypography.body?.$value.lineHeight ?? 0,
    2,
  );
  const brand = await page.locator(".brand__name").evaluate((element) => ({
    family: getComputedStyle(element).fontFamily,
    weight: getComputedStyle(element).fontWeight,
    text: element.textContent,
  }));
  expect(brand.family).toMatch(/^"?Noto Nastaliq Urdu"?/);
  expect(brand.weight).toBe(String(urduTypography.wordmark?.$value.fontWeight));
  expect(brand.text).toBe("مالکِ مکان");
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

/**
 * How far the middle of the ink of a control's text lies below the middle of the control, in
 * CSS pixels (negative: above), from a screenshot: the rows holding pixels unlike the
 * control's background. `inset` skips the border and rounded corners.
 */
async function inkOffset(page: Page, control: Locator, inset: { x: number; y: number }) {
  const box = await control.boundingBox();
  if (box === null) throw new Error("control not rendered");
  const clip = {
    x: box.x + inset.x,
    y: box.y + inset.y,
    width: box.width - 2 * inset.x,
    height: box.height - 2 * inset.y,
  };
  const { data, info } = await sharp(await page.screenshot({ clip }))
    .raw()
    .toBuffer({ resolveWithObject: true });
  const scale = info.height / clip.height;
  const pixel = (offset: number) => [
    data[offset] ?? 0,
    data[offset + 1] ?? 0,
    data[offset + 2] ?? 0,
  ];
  const counts = new Map<string, number>();
  for (let offset = 0; offset < data.length; offset += info.channels) {
    const key = pixel(offset).join();
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const background = ([...counts].sort((a, b) => b[1] - a[1])[0]?.[0] ?? "").split(",").map(Number);
  const rows: number[] = [];
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      const colour = pixel((y * info.width + x) * info.channels);
      const distance = colour.reduce(
        (sum, value, index) => sum + Math.abs(value - (background[index] ?? 0)),
        0,
      );
      if (distance > 60) {
        rows.push(y);
        break;
      }
    }
  }
  const top = (rows[0] ?? 0) / scale;
  const bottom = ((rows.at(-1) ?? 0) + 1) / scale;
  return (top + bottom) / 2 - clip.height / 2;
}

test.describe("Urdu words sit in the middle of their controls", () => {
  test.use({ deviceScaleFactor: 2 });

  // Measured for Noto Sans Arabic with the app's baseline (integrations/brand-assets.ts):
  // within 1.25 px, against 2.25 px below the middle without it and 3.75 px in Nastaliq.
  const tolerance = 1.5;

  test("the language switch's اردو on an English page", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto("/");
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    const offset = await inkOffset(page, page.locator("header [data-language-switch]"), {
      x: 12,
      y: 3,
    });
    expect(Math.abs(offset)).toBeLessThanOrEqual(tolerance);
  });

  test("buttons, the section links and the receipt's chip on the Urdu home page", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto("/ur/");
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    const controls: [Locator, { x: number; y: number }][] = [
      ...(await page.locator(".hero .button").all()).map(
        (button) => [button, { x: 10, y: 3 }] as [Locator, { x: number; y: number }],
      ),
      ...(await page.locator(".site-nav__link").all()).map(
        (link) => [link, { x: 0, y: 0 }] as [Locator, { x: number; y: number }],
      ),
      [page.locator(".receipt .chip").first(), { x: 8, y: 1 }],
    ];
    expect(controls.length).toBeGreaterThan(5);
    for (const [control, inset] of controls) {
      const offset = await inkOffset(page, control, inset);
      expect(Math.abs(offset), (await control.textContent()) ?? "").toBeLessThanOrEqual(tolerance);
    }
  });
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

test("the header's Tab order follows the order on screen, on phones and on wide screens", async ({
  page,
}) => {
  for (const width of [390, 1280]) {
    await page.setViewportSize({ width, height: 800 });
    for (const path of ["/", "/ur/"]) {
      await page.goto(path);
      // The DOM order of the header's three parts, and of the links in the nav. On a phone
      // the nav scrolls sideways, so its links are compared with each other and the nav's
      // own box with the brand and the switch.
      const parts = await page
        .locator(".site-header :is(.brand, .site-nav, [data-language-switch])")
        .evaluateAll((elements) =>
          elements.map((element) => {
            const box = element.getBoundingClientRect();
            return {
              x: box.x,
              right: box.right,
              y: Math.round(box.y),
              name: element.getAttribute("class") ?? "",
            };
          }),
        );
      const links = await page.locator(".site-nav__link").evaluateAll((elements) =>
        elements.map((element) => {
          const box = element.getBoundingClientRect();
          return { x: box.x, right: box.right, y: Math.round(box.y), name: element.textContent };
        }),
      );
      expect(parts).toHaveLength(3);
      const rtl = path === "/ur/";
      for (const stops of [parts, links]) {
        for (let index = 1; index < stops.length; index += 1) {
          const before = stops[index - 1];
          const after = stops[index];
          if (before === undefined || after === undefined) continue;
          // In the reading direction: on a later row, or further along the same one.
          const laterRow = after.y > before.y + 8;
          const furtherAlong = rtl ? after.right <= before.x + 1 : after.x >= before.right - 1;
          expect(
            laterRow || furtherAlong,
            `${path} at ${width} px: ${before.name} → ${after.name}`,
          ).toBe(true);
        }
      }
    }
  }
});

test("on a phone the header is at most two rows, and its links scroll sideways in one", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  for (const path of ["/", "/ur/"]) {
    await page.goto(path);
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    const header = await page.locator(".site-header").boundingBox();
    expect(header?.height ?? 999, path).toBeLessThanOrEqual(130);
    const rows = await page
      .locator(".site-nav__link")
      .evaluateAll(
        (links) => new Set(links.map((link) => Math.round(link.getBoundingClientRect().y))).size,
      );
    expect(rows, path).toBe(1);
    // A link off screen scrolls into view when it takes focus.
    const last = page.locator(".site-nav__link").last();
    await last.focus();
    const box = await last.boundingBox();
    expect(box?.x ?? -1).toBeGreaterThanOrEqual(0);
    expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(390);
  }
});

test("a long breadcrumb wraps with its separator at the end of the line, not the start of the next", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  for (const path of [
    "/tools/s155-withholding-calculator/",
    "/ur/tools/s155-withholding-calculator/",
  ]) {
    await page.goto(path);
    const items = await page.locator(".breadcrumbs__item").evaluateAll((elements) =>
      elements.map((element) => ({
        after: getComputedStyle(element, "::after").content,
        before: getComputedStyle(element, "::before").content,
      })),
    );
    expect(items.length).toBe(3);
    for (const [index, item] of items.entries()) {
      expect(item.before).toBe("none");
      expect(item.after, `${path} crumb ${index}`).toBe(
        index === items.length - 1 ? "none" : '"/" / ""',
      );
    }
  }
});

test("the worked examples on a calculator page use the full width on a wide screen", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  for (const path of [
    "/ur/tools/s155-withholding-calculator/",
    "/tools/s155-withholding-calculator/",
  ]) {
    await page.goto(path);
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    const clipped = await page
      .locator(".tool__examples .table-scroll")
      .evaluate((box) => box.scrollWidth - box.clientWidth);
    expect(clipped, path).toBeLessThanOrEqual(1);
  }
});
