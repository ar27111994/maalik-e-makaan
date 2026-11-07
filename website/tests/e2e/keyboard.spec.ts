// Keyboard use: the skip link comes first and works, every control can be
// reached in order without a trap, and focus is always visible.
import { expect, test, type Page } from "@playwright/test";
import { sitePages } from "./site.ts";

/** A description of the focused element, and whether its focus indicator is visible. */
async function focused(page: Page) {
  return page.evaluate(() => {
    const element = document.activeElement;
    if (element === null || element === document.body) return null;
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return {
      tag: element.tagName.toLowerCase(),
      text: element.textContent.trim().slice(0, 40),
      href: element.getAttribute("href"),
      outline: style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) >= 2,
      onScreen: rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.right > 0,
    };
  });
}

for (const site of sitePages()) {
  test.describe(`${site.path} by keyboard`, () => {
    test("the first Tab reaches a visible skip link that moves focus into main", async ({
      page,
    }) => {
      await page.goto(site.path);
      await page.keyboard.press("Tab");
      const first = await focused(page);
      expect(first).toMatchObject({ tag: "a", href: "#main", outline: true });
      const box = await page.locator(".skip-link").boundingBox();
      expect(box).not.toBeNull();
      expect(box?.y ?? -1).toBeGreaterThanOrEqual(0);
      await page.keyboard.press("Enter");
      await expect(page).toHaveURL(/#main$/);
      await page.keyboard.press("Tab");
      const inMain = await page.evaluate(() => document.activeElement?.closest("main") !== null);
      expect(inMain).toBe(true);
    });

    test("Tab visits every control once, in document order, with a visible focus ring", async ({
      page,
    }) => {
      await page.goto(site.path);
      const expected = await page.evaluate(() =>
        [
          ...document.querySelectorAll<HTMLElement>(
            "a[href], button, input, select, textarea, [tabindex]",
          ),
        ]
          .filter((element) => element.tabIndex >= 0 && element.getClientRects().length > 0)
          // Tab stops once in a group of radio buttons: on the checked one.
          .filter(
            (element) =>
              !(element instanceof HTMLInputElement) || element.type !== "radio" || element.checked,
          )
          .map((element) => element.getAttribute("href") ?? element.tagName.toLowerCase()),
      );
      expect(expected.length).toBeGreaterThan(5);
      const visited: (string | null)[] = [];
      for (let index = 0; index < expected.length; index += 1) {
        await page.keyboard.press("Tab");
        const current = await focused(page);
        expect(current, `focus ${index + 1}`).not.toBeNull();
        expect(current?.outline, `visible focus on ${current?.text ?? ""}`).toBe(true);
        expect(current?.onScreen, `${current?.text ?? ""} is on screen when focused`).toBe(true);
        visited.push(current?.href ?? current?.tag ?? null);
      }
      expect(visited).toEqual(expected);
      // One more Tab leaves the page's controls: no keyboard trap.
      await page.keyboard.press("Tab");
      expect(await focused(page)).toBeNull();
    });

    test("Shift+Tab walks back through the same controls", async ({ page }) => {
      await page.goto(site.path);
      await page.keyboard.press("Tab");
      await page.keyboard.press("Tab");
      const second = await focused(page);
      await page.keyboard.press("Tab");
      await page.keyboard.press("Shift+Tab");
      expect(await focused(page)).toEqual(second);
    });

    test("Enter on the language switch opens the same page in the other language", async ({
      page,
    }) => {
      await page.goto(site.path);
      await page.locator("header [data-language-switch]").focus();
      await page.keyboard.press("Enter");
      await expect(page).toHaveURL(new RegExp(`${site.twin.replace(/[.]/g, "\\.")}$`));
    });
  });
}
