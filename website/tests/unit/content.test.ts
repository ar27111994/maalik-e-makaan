// The content files themselves: valid against their schemas, the two languages
// in step, Urdu in Urdu script, English in British spelling.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { parse } from "yaml";
import {
  downloadSchema,
  faqSchema,
  featuresSchema,
  homeSchema,
  howItWorksSchema,
  licencesSchema,
  pricingSchema,
  companySchema,
} from "../../src/lib/content/schemas.ts";

const read = (path: string): unknown =>
  parse(readFileSync(new URL(`../../src/content/${path}`, import.meta.url), "utf8"));

const collections = [
  { name: "home", schema: homeSchema },
  { name: "licences", schema: licencesSchema },
  { name: "faq", schema: faqSchema },
  { name: "features", schema: featuresSchema },
  { name: "how-it-works", schema: howItWorksSchema },
  { name: "download", schema: downloadSchema },
  { name: "pricing", schema: pricingSchema },
  { name: "company", schema: companySchema },
] as const;

/** The shape of a value: its keys and array lengths, without the text. */
function shape(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(shape);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, shape(child)]));
  }
  return typeof value;
}

/** Keys whose values are identifiers, not copy: a section's anchor and status. */
const IDENTIFIER_KEYS = new Set(["id", "status"]);

function texts(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.flatMap(texts);
  if (value !== null && typeof value === "object") {
    return Object.entries(value).flatMap(([key, child]) =>
      IDENTIFIER_KEYS.has(key) && typeof child === "string" && /^[a-z][a-z0-9-]*$/.test(child)
        ? []
        : texts(child),
    );
  }
  return [];
}

/** Values that are identifiers, not copy: hrefs and licence slugs. */
const IDENTIFIER = /^(#[a-z-]+|app|\/([a-z0-9-]+\/)*|ofl-[a-z-]+|\d{4}-\d{4})$/;

describe.each(collections)("the $name collection", ({ name, schema }) => {
  const en = read(`${name}/en.yaml`);
  const ur = read(`${name}/ur.yaml`);

  test("both files are valid", () => {
    expect(schema.safeParse(en).error).toBeUndefined();
    expect(schema.safeParse(ur).error).toBeUndefined();
  });

  test("English and Urdu are in step: same keys, same number of items", () => {
    expect(shape(ur)).toEqual(shape(en));
  });

  test("Urdu copy is in Urdu script, with no Latin letters (no Roman Urdu)", () => {
    for (const text of texts(ur).filter((value) => !IDENTIFIER.test(value))) {
      // "{font}", "{version}" and "{date}" are placeholders the page fills in.
      expect(text.replaceAll(/\{(font|version|date)\}/g, "")).not.toMatch(/[A-Za-z]/);
    }
  });

  test("English copy uses British spelling", () => {
    const american =
      /\b(color\w*|center\w*|favorite\w*|behavior\w*|licenses?|(organ|author|recogn|categor|priorit|custom|summar|normal|optim|minim|maxim|real|util|apolog|special)iz(e|es|ed|ing|ation|ations)|analyz\w*)\b/i;
    for (const text of texts(en)) {
      // "SIL Open Font License" is the licence's proper name.
      expect(text.replaceAll("Open Font License", "")).not.toMatch(american);
    }
  });
});

describe("content facts", () => {
  test("the home page never claims to estimate final tax (D-10)", () => {
    const en = JSON.stringify(read("home/en.yaml"));
    expect(en).toContain("It will not estimate your final tax");
    expect(en).toMatch(/not tax advice/);
    expect(en).not.toMatch(/\b(calculates|estimates|works out) your (income )?tax\b/i);
  });

  test("now that version 1.0 is out, the pages speak of the app in the present tense", () => {
    const en = read("home/en.yaml") as { description: string; hero: { lede: string } };
    expect(en.description).not.toMatch(/in development/i);
    expect(en.hero.lede).not.toMatch(/\bwill (replace|show)\b/);
    const ur = read("home/ur.yaml") as { hero: { lede: string } };
    // The product's name is also the word for "landlord": as a subject it is "مالکِ مکان ایپ".
    expect(ur.hero.lede).toMatch(/^مالکِ مکان ایپ /);
    for (const name of ["home", "features", "how-it-works", "faq", "download"]) {
      const text = JSON.stringify(read(`${name}/en.yaml`));
      expect(text, name).not.toMatch(
        /in development|has not been released|not out yet|being built now/i,
      );
    }
  });

  test("the home page says a receipt is made in English or Urdu, not in both", () => {
    // The app makes each receipt PDF in the one language the landlord picks (DocumentLanguage).
    const en = JSON.stringify(read("home/en.yaml"));
    expect(en).toMatch(/receipts? in English or Urdu/);
    expect(en).not.toMatch(
      /receipts? (is |are )?in (both|two) languages|receipts? in English and Urdu/i,
    );
    const ur = JSON.stringify(read("home/ur.yaml"));
    expect(ur).toMatch(/اردو یا انگریزی میں/);
    expect(ur).not.toMatch(
      /رسید[یں]* دونوں زبانوں|دو زبانوں میں نمبر والی|اردو اور انگریزی میں (پی ڈی ایف )?رسید/,
    );
  });

  test("no guides are published in one language only", async () => {
    const { readdirSync } = await import("node:fs");
    const list = (locale: string) =>
      readdirSync(new URL(`../../src/content/guides/${locale}/`, import.meta.url)).filter((file) =>
        /\.mdx?$/.test(file),
      );
    expect(list("ur").map((file) => file.replace(/\.mdx?$/, ""))).toEqual(
      list("en").map((file) => file.replace(/\.mdx?$/, "")),
    );
  });
});

describe("pricing facts", () => {
  interface Plan {
    id: string;
    price: string;
    annual: string;
  }
  type Locale = "en" | "ur";

  function plan(locale: Locale, id: string): Plan {
    const { plans } = read(`pricing/${locale}.yaml`) as { plans: Plan[] };
    const found = plans.find((candidate) => candidate.id === id);
    if (found === undefined) throw new Error(`pricing/${locale}.yaml has no plan ${id}`);
    return found;
  }

  /** The groups [pattern] captures in [text], as numbers. */
  function figures(text: string, pattern: RegExp): number[] {
    const match = pattern.exec(text);
    if (match === null) throw new Error(`${String(pattern)} does not match "${text}"`);
    return match.slice(1).map((figure) => Number(figure.replaceAll(",", "")));
  }

  /** US$1 for each Rs 200 (half a cent a rupee), at the nearest price ending in 49 or 99 cents. */
  const overseasCents = (rupees: number): number => 49 + 50 * Math.round((rupees / 2 - 49) / 50);

  const [pro = 0] = figures(plan("en", "pro").price, /^Rs\u00A0([\d,]+)$/);
  const [proStep = 0] = figures(
    plan("en", "pro").annual,
    /^Then Rs\u00A0([\d,]+) more a month for each 5 more let units\./,
  );
  const [business = 0] = figures(plan("en", "business").price, /^Rs\u00A0([\d,]+)$/);
  const [businessStep = 0] = figures(
    plan("en", "business").annual,
    /^Then Rs\u00A0([\d,]+) more a month for each 10 more let units\./,
  );

  /** The rupee price of [units] let units, in Pro's blocks of 5 up to 25 or Business's of 10. */
  const rupees = (units: number): number =>
    units <= 25 ? pro + proStep * (units / 5 - 1) : business + businessStep * ((units - 30) / 10);

  test("a year of a rupee plan costs exactly 10 months", () => {
    for (const id of ["pro", "business"]) {
      const en = plan("en", id);
      const [monthly = 0] = figures(en.price, /^Rs\u00A0([\d,]+)$/);
      expect(figures(en.annual, /A year costs 10 months: Rs\u00A0([\d,]+) for/)).toEqual([
        10 * monthly,
      ]);
      const ur = plan("ur", id);
      expect(figures(ur.price, /^([\d,]+)\u00A0روپے$/)).toEqual([monthly]);
      expect(figures(ur.annual, /سال بھر کی قیمت دس ماہ کے برابر: .*?([\d,]+)\u00A0روپے/)).toEqual([
        10 * monthly,
      ]);
    }
  });

  test("the Overseas plan is US$1 for each Rs 200 of the rupee price, at every size", () => {
    const overseas = plan("en", "overseas");
    const cents = (text: string, pattern: RegExp): number[] =>
      figures(text, pattern).map((dollars) => Math.round(dollars * 100));
    const [first = 0] = cents(overseas.price, /^US\$(\d+\.\d\d)$/);
    const [step5 = 0, from30 = 0, step10 = 0, year = 0] = cents(
      overseas.annual,
      /^Then US\$(\d+\.\d\d) more a month for each 5 more let units up to 25\. From 30 let units, US\$(\d+\.\d\d) a month, then US\$(\d+\.\d\d) more for each 10 more\. A year costs about 10 months: US\$(\d+\.\d\d) for 5 units\.$/,
    );
    const stated = (units: number): number =>
      units <= 25 ? first + step5 * (units / 5 - 1) : from30 + step10 * ((units - 30) / 10);
    for (const units of [5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100]) {
      expect(stated(units), `${String(units)} let units`).toBe(overseasCents(rupees(units)));
    }
    // A year is the rule applied to 10 months of rupees; 10 × US$2.49 would be US$24.90,
    // so the page says "about 10 months" here and nowhere else.
    expect(year).toBe(overseasCents(10 * pro));
    expect(year).not.toBe(10 * first);

    // The Urdu states the same dollar figures, in the same order, and also says "about".
    const dollars = (text: string): string[] => text.match(/\d+\.\d\d/g) ?? [];
    const ur = plan("ur", "overseas");
    expect(dollars(ur.price)).toEqual(dollars(overseas.price));
    expect(dollars(ur.annual)).toEqual(dollars(overseas.annual));
    expect(ur.annual).toContain("تقریباً دس ماہ کے برابر");
  });

  test("only rupee prices are said to include tax; the stores add their own", () => {
    // In some stores, such as the US ones, sales tax is added at checkout.
    const en = JSON.stringify(read("pricing/en.yaml"));
    expect(en).toContain("Rupee prices include Pakistani tax.");
    expect(en).not.toMatch(/\bprices? includes? (tax|VAT|your)|with its VAT/i);
    const ur = JSON.stringify(read("pricing/ur.yaml"));
    expect(ur).toContain("روپوں والی قیمتوں میں پاکستانی ٹیکس شامل ہے۔");
    expect(ur).not.toMatch(/"قیمتوں میں ٹیکس شامل|قیمت میں آپ کے ملک کا ٹیکس شامل/);
  });

  test("a figure and its currency are never split across lines", () => {
    expect(JSON.stringify(read("pricing/en.yaml"))).not.toMatch(/\bRs \d/);
    expect(JSON.stringify(read("pricing/ur.yaml"))).not.toMatch(/\d (روپے|امریکی|ڈالر|سینٹ)/);
  });

  test("the deck's pricing slide shows the pricing page's prices", () => {
    const slide = readFileSync(new URL("../../deck/slides/pricing.html", import.meta.url), "utf8");
    const { plans } = read("pricing/en.yaml") as { plans: Plan[] };
    for (const { price } of plans) expect(slide).toContain(`>${price}</p>`);
    expect(slide).toContain("Rupee prices include Pakistani tax");
    expect(slide).not.toMatch(/(?<!Rupee )Prices include tax/);
  });
});

describe("pitch deck facts", () => {
  const slide = (id: string): string =>
    readFileSync(new URL(`../../deck/slides/${id}.html`, import.meta.url), "utf8");
  /** The speaker notes, which the PDF leaves out but a presenter reads aloud. */
  const notes = (html: string): string => html.split("<aside>")[1] ?? "";

  test("the status slide does not call the published pricing unfinished", () => {
    const status = slide("status");
    const next = status.split(">Next</h3>")[1]?.split("<aside>")[0] ?? "";
    expect(next).not.toBe("");
    expect(next).not.toMatch(/pricing/i);
    expect(notes(status)).not.toMatch(/no pricing/i);
  });

  test("reminders are not said to be held back: the app only suggests waiting", () => {
    // Etiquette.concerns (app reminders.dart) returns notes; the sheet still offers "Send anyway".
    const product = slide("product");
    expect(product).not.toMatch(/never[^.<]*(night|prayers)/i);
    expect(product).toContain("a gentle suggestion to wait");
  });

  test("no slide says receipts or reminders carry a link", () => {
    // Reminders are the template, payment details and sign-off; the PDFs' footers have no URL.
    const { order } = JSON.parse(
      readFileSync(new URL("../../deck/deck.json", import.meta.url), "utf8"),
    ) as { order: string[] };
    for (const id of order) {
      expect(slide(id), id).not.toMatch(/carr(y|ies) a (small )?link|link back/i);
    }
  });
});
