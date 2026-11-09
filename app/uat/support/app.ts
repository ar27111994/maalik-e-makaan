// Driving the Flutter web app through its semantics tree. The app paints to
// a canvas; with semantics on, Flutter mirrors every control into the DOM
// with an ARIA role and label, which is what a screen reader reads and what
// these helpers click and type into. A control a test cannot find by its
// role and label is one a blind landlord cannot find either.
import { expect, type Locator, type Page } from "@playwright/test";

/** Opens [path] and turns on the semantics tree. */
export async function open(page: Page, path = "/"): Promise<void> {
  await page.goto(path);
  await page.locator("flutter-view").waitFor({ state: "attached", timeout: 60_000 });
  await enableSemantics(page);
}

/** Clicks Flutter's hidden "enable accessibility" placeholder, once per page load. */
export async function enableSemantics(page: Page): Promise<void> {
  const placeholder = page.locator("flt-semantics-placeholder");
  await placeholder.waitFor({ state: "attached", timeout: 60_000 });
  await placeholder.evaluate((element: HTMLElement) => element.click());
  await expect(page.locator("flt-semantics").first()).toBeAttached();
}

/** The button labelled [name] (exact, unless a RegExp). */
export function button(page: Page | Locator, name: string | RegExp): Locator {
  return page.getByRole("button", { name, exact: typeof name === "string" }).first();
}

/**
 * Activates [target] the way a screen reader does: a click event on its
 * semantics node, which Flutter turns into a tap on the widget. No pointer
 * geometry is involved, so it works wherever the node is scrolled to.
 * (Scrolling the semantics DOM with the mouse or scrollIntoView moves the
 * DOM without moving Flutter's view, and a real pointer click then lands on
 * whatever is painted there.)
 */
export async function activate(target: Locator): Promise<void> {
  await expect(target).toBeAttached();
  await target.evaluate((element: HTMLElement) => element.click());
}

/** Taps the button labelled [name]. */
export async function tap(page: Page | Locator, name: string | RegExp): Promise<void> {
  await activate(button(page, name));
}

/** Types [value] into the text field labelled [label], replacing its text. */
export async function fill(
  page: Page | Locator,
  label: string | RegExp,
  value: string,
): Promise<void> {
  const field = page
    .getByRole("textbox", { name: label, exact: typeof label === "string" })
    .first();
  await typeInto(field, value);
}

/** What [value] keeps when a field formats it: its digits, or itself. */
function essence(value: string): string {
  const digits = value.replace(/[^0-9]/g, "");
  return digits.length > 0 && /^[0-9 +\-,.]*$/.test(value) ? digits : value;
}

/**
 * Focuses [field] and types [value]. Flutter starts its editing session on
 * focus and may swap the input element as it does, so the text is checked
 * after and typed again if it did not arrive (formatting such as a CNIC's
 * dashes or a rupee amount's commas is allowed).
 */
export async function typeInto(field: Locator, value: string): Promise<void> {
  for (let attempt = 0; attempt < 4; attempt++) {
    await expect(field).toBeAttached();
    await field.evaluate((element: HTMLElement) => element.focus({ preventScroll: true }));
    await field.page().waitForTimeout(250);
    await field.fill(value);
    await field.page().waitForTimeout(250);
    const now = await field.inputValue().catch(() => "");
    if (essence(now) === essence(value)) return;
  }
  throw new Error(`Could not type ${JSON.stringify(value)} into ${field}`);
}

/**
 * [text] as a pattern found anywhere in a label. Any run of spaces matches
 * any whitespace (amounts and dates are kept on one line with no-break
 * spaces: "Rs\u00a0250,000"), and the invisible marks the app adds for
 * line breaking and bidi isolation (a zero-width space after an e-mail's
 * "@", isolates around names and numbers) may appear around spaces, after
 * "@" and before punctuation.
 */
export function loose(text: string): RegExp {
  const invisible = "[\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069]*";
  const escaped = text.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
  return new RegExp(
    escaped
      .replace(/ +/g, `${invisible}\\s+${invisible}`)
      .replace(/@/g, `@${invisible}`)
      .replace(/(\\[.,:)]|[,:·])/g, `${invisible}$1`),
  );
}

/** Waits until [text] is on screen: as text, or as the label of a control. */
export async function see(page: Page, text: string | RegExp, timeout = 20_000): Promise<void> {
  const pattern = typeof text === "string" ? new RegExp(`^\\s*${loose(text).source}\\s*$`) : text;
  const shown = page
    .getByText(pattern)
    .or(page.getByLabel(pattern))
    .or(page.getByRole("button", { name: pattern }));
  await expect(shown.first()).toBeAttached({ timeout });
}

/** The page's accessibility tree, for failure messages and the report. */
export async function tree(page: Page): Promise<string> {
  return page.locator("body").ariaSnapshot();
}

/** Saves a screenshot under docs/uat/ when UAT_SCREENSHOTS is set. */
export async function shot(page: Page, name: string): Promise<void> {
  const directory = process.env.UAT_SCREENSHOTS;
  if (!directory) return;
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${directory}/${name}.png` });
}

/** d/m/yyyy, as the date picker's text field takes it in English. */
export function pickerDate(date: Date): string {
  return `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
}

/** Opens the date picker with [trigger] and types [date] into its text mode. */
export async function chooseDate(page: Page, trigger: Locator, date: string): Promise<void> {
  await activate(trigger);
  const picker = page.getByRole("dialog");
  await activate(button(picker, /^(Switch to input|ان پٹ پر سوئچ کریں)$/));
  await typeInto(picker.getByRole("textbox").first(), date);
  await activate(picker.getByRole("button").last());
  await expect(picker).toBeHidden();
}

/** Reloads the page (the app starts again from the server's data). */
export async function reload(page: Page): Promise<void> {
  await page.reload();
  await page.locator("flutter-view").waitFor({ state: "attached", timeout: 60_000 });
  await enableSemantics(page);
}
