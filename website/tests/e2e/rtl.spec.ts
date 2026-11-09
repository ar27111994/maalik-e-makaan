// Right-to-left details the bidi algorithm gets wrong unless the page helps it:
// numbers after Urdu words, the calculators' step numbers, and negative amounts.
import { expect, test, type Page } from "@playwright/test";
import { sitePages } from "./site.ts";

/**
 * Text in right-to-left context that the Unicode bidi algorithm draws in the
 * wrong order. After an Arabic-script letter, Western digits are Arabic
 * numbers (rule W2), so a hyphen, dash or plus between two of them, or a
 * percent sign beside one, no longer joins them: "2026-27" is drawn "27-2026"
 * and "6.25%" is drawn "%6.25". A minus sign before a figure is drawn after it
 * in any right-to-left run. Text inside a left-to-right element (dir="ltr",
 * such as the calculators' <bdi class="math">) or between the isolates
 * U+2066 and U+2069 is safe.
 */
async function bidiProblems(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const digit = "[0-9۰-۹]";
    const afterArabic = [
      new RegExp(`${digit}\\s*[-–−+]\\s*${digit}`, "gu"),
      new RegExp(`${digit}\\s*[%٪]`, "gu"),
      new RegExp(`[%٪]\\s*${digit}`, "gu"),
    ];
    const minus = new RegExp(`(?:^|[\\s‎(])[-−]${digit}`, "u");
    const letter = /\p{L}/gu;
    const arabic = /\p{Script=Arabic}/u;
    const blocks =
      "p, li, td, th, dd, dt, h1, h2, h3, h4, h5, h6, caption, figcaption, label, legend";
    const problems: string[] = [];
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
      const parent = node.parentElement;
      if (parent?.closest("script, style, template, [hidden]") !== null) continue;
      if (parent.closest("[dir]")?.getAttribute("dir") !== "rtl") continue;
      const text = (node.textContent ?? "").replace(/\u2066[^\u2069]*\u2069/gu, (run) =>
        "\u2066".padEnd(run.length, "\u2069"),
      );
      if (minus.test(text)) problems.push(`minus sign: ${text.trim()}`);
      // The strong letter that decides how a number is read: the last one before it in its block.
      const block = parent.closest(blocks) ?? parent;
      const range = document.createRange();
      range.setStart(block, 0);
      range.setEnd(node, 0);
      const before = range.toString();
      for (const pattern of afterArabic) {
        for (const match of text.matchAll(pattern)) {
          const letters = `${before}${text.slice(0, match.index)}`.match(letter) ?? [];
          const last = letters.at(-1);
          if (last !== undefined && arabic.test(last)) {
            problems.push(`"${match[0]}" after Urdu text: ${text.trim().slice(0, 120)}`);
          }
        }
      }
    }
    return problems;
  });
}

for (const site of sitePages().filter((page) => page.locale === "ur")) {
  test(`${site.path} has no number drawn in the wrong order`, async ({ page }) => {
    await page.goto(site.path);
    expect(await bidiProblems(page)).toEqual([]);
  });
}

const calculators = [
  { path: "/ur/tools/rent-increase-calculator/", id: "increment" },
  { path: "/ur/tools/first-month-rent-calculator/", id: "proration" },
  { path: "/ur/tools/s155-withholding-calculator/", id: "withholding" },
];

test("the Urdu calculators' results, recalculated, have no number in the wrong order", async ({
  page,
}) => {
  const [increment, proration, withholding] = calculators;
  if (increment === undefined || proration === undefined || withholding === undefined) {
    throw new Error("three calculators expected");
  }
  const runs: { path: string; id: string; set: (page: Page) => Promise<void> }[] = [
    // A rounding step larger than the increase: the rent falls, and the fall is said in words.
    {
      ...increment,
      set: async (p) => {
        await p.locator("#increment-rent").fill("499");
        await p.locator("#increment-percent").fill("0");
        await p.locator("#increment-rounding").selectOption("nearest1000");
      },
    },
    // A company landlord: the band rate sits in the sentence, not only in the working.
    {
      ...withholding,
      set: async (p) => {
        await p.locator('input[name="payee"][value="company"]').check();
      },
    },
    // A decimal comma: the message suggests the amount, isolated from the Urdu around it.
    {
      ...proration,
      set: async (p) => {
        await p.locator("#proration-rent").fill("45,5");
      },
    },
  ];
  for (const run of runs) {
    await page.goto(run.path);
    await expect(page.locator(`#${run.id}-form`)).toHaveAttribute("data-ready", "true");
    await run.set(page);
    await page.locator(`#${run.id}-form button[type="submit"]`).click();
    await page.waitForTimeout(50);
    expect(await bidiProblems(page), run.path).toEqual([]);
  }
});

test("in Urdu, a step's number stands apart from a formula that starts the step", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  for (const { path } of calculators) {
    await page.goto(path);
    const steps = await page.locator(".result__steps > li").evaluateAll((items) =>
      items.map((item) => {
        const style = getComputedStyle(item);
        const marker = getComputedStyle(item, "::before");
        return {
          listStyle: style.listStyleType,
          // Positioned out of the line, the number is a bidi paragraph of its own.
          position: marker.position,
          marker: marker.content,
        };
      }),
    );
    expect(steps.length).toBeGreaterThan(1);
    for (const step of steps) {
      expect(step.listStyle).toBe("none");
      expect(step.position).toBe("absolute");
      expect(step.marker).toMatch(/^counter\(step\)/);
    }
  }
});
