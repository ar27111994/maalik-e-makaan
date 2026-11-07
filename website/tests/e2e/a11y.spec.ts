// WCAG 2.2 AA (and axe's best practices) on every page, in both languages,
// in light and dark mode, on a desktop and on a 360 px phone.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { sitePages } from "./site.ts";

const WCAG_22_AA = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

const conditions = [
  { name: "light, desktop", colorScheme: "light", viewport: { width: 1280, height: 800 } },
  { name: "dark, phone", colorScheme: "dark", viewport: { width: 360, height: 780 } },
] as const;

for (const site of sitePages()) {
  for (const condition of conditions) {
    test(`${site.path} has no WCAG 2.2 AA violations (${condition.name})`, async ({ page }) => {
      await page.setViewportSize(condition.viewport);
      await page.emulateMedia({ colorScheme: condition.colorScheme });
      await page.goto(site.path);
      await page.evaluate(async () => {
        await document.fonts.ready;
      });
      const results = await new AxeBuilder({ page }).withTags(WCAG_22_AA).analyze();
      const violations = results.violations.map((violation) => ({
        rule: violation.id,
        impact: violation.impact,
        help: violation.help,
        targets: violation.nodes.map((node) => node.target.join(" ")),
      }));
      expect(violations).toEqual([]);
      // axe must actually have checked colour contrast, not skipped it.
      expect(
        [...results.passes, ...results.incomplete].some((rule) => rule.id === "color-contrast"),
      ).toBe(true);
    });
  }
}
