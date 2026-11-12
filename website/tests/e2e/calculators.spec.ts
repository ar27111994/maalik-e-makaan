// The calculators in a real browser: they recalculate from Western or Urdu
// digits, announce the result in the live region, show their working, report
// errors beside the field in words, rebuild exactly the markup the page was
// built with, and still read sensibly with JavaScript off.
import { expect, test, type Page } from "@playwright/test";

/** Console errors and page errors, including a Trusted Types violation. */
function watch(page: Page): string[] {
  const problems: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") {
      problems.push(`console ${message.type()}: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  return problems;
}

/** The result body as tags, classes and text, to compare the build's markup with the script's. */
async function resultShape(page: Page, id: string): Promise<string> {
  return page.locator(`#${id}-result-body`).evaluate((root) => {
    const describe = (node: Node): string => {
      if (node.nodeType === Node.TEXT_NODE) return (node.textContent ?? "").replace(/\s+/g, " ");
      if (!(node instanceof Element)) return "";
      const attributes = ["class", "role", "tabindex", "aria-labelledby", "id", "scope", "dir"]
        .map((name) =>
          node.hasAttribute(name) ? ` ${name}="${node.getAttribute(name) ?? ""}"` : "",
        )
        .join("");
      return `<${node.tagName.toLowerCase()}${attributes}>${[...node.childNodes].map(describe).join("")}</${node.tagName.toLowerCase()}>`;
    };
    return [...root.childNodes].map(describe).join("").replace(/>\s+</g, "><").trim();
  });
}

/** Opens a calculator page and waits until its script has wired up the form. */
async function open(page: Page, path: string, id: string): Promise<void> {
  await page.goto(path);
  await expect(page.locator(`#${id}-form`)).toHaveAttribute("data-ready", "true");
}

async function statusAfter(page: Page, id: string, previous: string): Promise<string> {
  const status = page.locator(`#${id}-status`);
  await expect(status).not.toHaveText(previous);
  await expect(status).not.toHaveText("");
  return (await status.textContent())?.trim() ?? "";
}

const calculators = [
  { path: "/tools/rent-increase-calculator/", id: "increment" },
  { path: "/tools/first-month-rent-calculator/", id: "proration" },
  { path: "/tools/s155-withholding-calculator/", id: "withholding" },
  { path: "/ur/tools/rent-increase-calculator/", id: "increment" },
  { path: "/ur/tools/first-month-rent-calculator/", id: "proration" },
  { path: "/ur/tools/s155-withholding-calculator/", id: "withholding" },
];

for (const { path, id } of calculators) {
  test.describe(path, () => {
    test("the script rebuilds exactly the result the page was built with", async ({ page }) => {
      const problems = watch(page);
      await open(page, path, id);
      const built = await resultShape(page, id);
      const summary = (await page.locator(`#${id}-status`).textContent())?.trim() ?? "";
      expect(built.length).toBeGreaterThan(100);
      await page.locator(`#${id}-form button[type="submit"]`).click();
      // The live region clears and is refilled with the same sentence, so it is announced again.
      await expect(page.locator(`#${id}-status`)).toHaveText(summary);
      expect(await resultShape(page, id)).toBe(built);
      expect(problems).toEqual([]);
    });

    test("a wrong answer is named beside its field, in words, and focus goes to it", async ({
      page,
    }) => {
      const problems = watch(page);
      await open(page, path, id);
      const before = await resultShape(page, id);
      const rent = page.locator(`#${id}-rent`);
      await rent.fill("abc");
      await page.locator(`#${id}-form button[type="submit"]`).click();
      await expect(rent).toHaveAttribute("aria-invalid", "true");
      await expect(rent).toBeFocused();
      const error = page.locator(`#${id}-rent-error`);
      await expect(error).toBeVisible();
      expect((await error.textContent())?.length).toBeGreaterThan(10);
      expect(await rent.getAttribute("aria-describedby")).toContain(`${id}-rent-error`);
      await expect(page.locator(`#${id}-status`)).not.toHaveText("");
      expect(await resultShape(page, id)).toBe(before);
      // Fixing it clears the error.
      await rent.fill("60000");
      await page.locator(`#${id}-form button[type="submit"]`).click();
      await expect(error).toBeHidden();
      await expect(rent).not.toHaveAttribute("aria-invalid", "true");
      expect(problems).toEqual([]);
    });

    test("with JavaScript off, the page says so and still shows a worked result", async ({
      browser,
    }) => {
      const context = await browser.newContext({ javaScriptEnabled: false });
      const page = await context.newPage();
      await page.goto(path);
      await expect(page.locator(".calculator__noscript")).toBeVisible();
      await expect(page.locator(`#${id}-result-body .result__steps li`).first()).toBeVisible();
      await context.close();
    });

    test("with JavaScript off, submitting sends nothing anywhere", async ({ browser }) => {
      // The privacy page promises the figures never leave the device. A form
      // without method="dialog" would send them, in the URL (GET) or in the
      // body (POST), so once the page has settled no request may start at all.
      const context = await browser.newContext({ javaScriptEnabled: false });
      const page = await context.newPage();
      await page.goto(path);
      await page.waitForLoadState("networkidle");
      const start = page.url();
      const marker = "987654";
      for (const input of await page.locator(`#${id}-form input[type=text]`).all()) {
        await input.fill(marker);
      }
      const sent: string[] = [];
      page.on("request", (request) =>
        sent.push(`${request.method()} ${request.url()} ${request.postData() ?? ""}`),
      );
      await page.locator(`#${id}-form button[type='submit']`).click();
      await page.waitForLoadState("networkidle");
      expect(sent).toEqual([]);
      expect(page.url()).toBe(start);
      await context.close();
    });
  });
}

test("the increment calculator reads Urdu digits and announces the new rent", async ({ page }) => {
  await open(page, "/ur/tools/rent-increase-calculator/", "increment");
  const before = (await page.locator("#increment-status").textContent()) ?? "";
  await page.locator("#increment-rent").fill("۳۷,۳۵۰");
  await page.locator("#increment-percent").fill("۱۰");
  await page.locator("#increment-years").fill("۱");
  await page.locator("#increment-form button[type='submit']").click();
  const summary = await statusAfter(page, "increment", before);
  expect(summary).toContain("41,100\u00A0روپے");
  await expect(page.locator("#increment-result-body .result__figure--primary dd")).toHaveText(
    "41,100\u00A0روپے",
  );
  await expect(page.locator("#increment-result-body tbody tr")).toHaveCount(2);
});

test("the first-month calculator works out February in a leap year", async ({ page }) => {
  await open(page, "/tools/first-month-rent-calculator/", "proration");
  const before = (await page.locator("#proration-status").textContent()) ?? "";
  await page.locator("#proration-rent").fill("Rs 30,000");
  await page.locator("#proration-day").fill("15");
  await page.locator("#proration-month").fill("2");
  await page.locator("#proration-year").fill("2028");
  await page.locator("#proration-form button[type='submit']").click();
  const summary = await statusAfter(page, "proration", before);
  expect(summary).toBe(
    "Rent from 15\u00A0February to 29\u00A0February 2028: Rs\u00A015,517, for 15 of 29 days.",
  );
  await expect(page.locator("#proration-result-body .result__steps li").nth(2)).toHaveText(
    "The rent for those days is 30,000 × 15 ÷ 29 ≈ 15,517.24.",
  );
});

test("an impossible date is refused on the date's fieldset", async ({ page }) => {
  await open(page, "/tools/first-month-rent-calculator/", "proration");
  await page.locator("#proration-day").fill("31");
  await page.locator("#proration-month").fill("4");
  await page.locator("#proration-form button[type='submit']").click();
  await expect(page.locator("#proration-date-error")).toBeVisible();
  for (const field of ["day", "month", "year"]) {
    await expect(page.locator(`#proration-${field}`)).toHaveAttribute("aria-invalid", "true");
  }
  await expect(page.locator("#proration-day")).toBeFocused();
});

test("the s.155 calculator: a landlord not on the ATL, rent by the year, flagged as uncertain", async ({
  page,
}) => {
  await open(page, "/tools/s155-withholding-calculator/", "withholding");
  const before = (await page.locator("#withholding-status").textContent()) ?? "";
  await page.locator("#withholding-rent").fill("1,200,000");
  await page.getByLabel("per year").check();
  await page.getByLabel("No, not on the ATL").check();
  await page.locator("#withholding-form button[type='submit']").click();
  const summary = await statusAfter(page, "withholding", before);
  expect(summary).toContain("Rs\u00A0150,000");
  await expect(page.locator("#withholding-result-body .result__notes")).toContainText(
    "check this figure with a tax adviser",
  );
  // The disclaimer stays on the page, above the calculator.
  await expect(page.locator(".tool__disclaimer")).toContainText("not your final tax");
});

test("the s.155 calculator: an individual tenant below Rs 1.5 million need not deduct", async ({
  page,
}) => {
  await open(page, "/ur/tools/s155-withholding-calculator/", "withholding");
  const before = (await page.locator("#withholding-status").textContent()) ?? "";
  await page.locator("#withholding-rent").fill("۱۰۰۰۰۰");
  await page.locator("#withholding-form input[name='tenant'][value='individual']").check();
  await page.locator("#withholding-form button[type='submit']").click();
  const summary = await statusAfter(page, "withholding", before);
  expect(summary).toContain("لازم نہیں");
});
