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
      // "{font}" is a placeholder the page fills with a font's name, inside lang="en".
      expect(text.replaceAll("{font}", "")).not.toMatch(/[A-Za-z]/);
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

  test("until version 1.0 ships, the home page speaks of the app in the future tense", () => {
    const en = read("home/en.yaml") as { description: string; hero: { lede: string } };
    expect(en.description).toMatch(/^An app in development/);
    expect(en.hero.lede).toMatch(/will replace/);
    expect(en.hero.lede).not.toMatch(/\b(replaces|shows) /);
    const ur = read("home/ur.yaml") as { hero: { lede: string } };
    // The product's name is also the word for "landlord": as a subject it is "مالکِ مکان ایپ".
    expect(ur.hero.lede).toMatch(/^مالکِ مکان ایپ /);
    expect(ur.hero.lede).toMatch(/دے گی/);
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
