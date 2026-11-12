// The Markdown collections (guides, calculator pages, text pages): valid front
// matter, both languages, Urdu in Urdu script, British spelling, and the facts
// the research says must never be published as settled.
import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { parse } from "yaml";
import { URDU_UNIT_SPLIT } from "../../src/i18n/units.ts";
import { guideSchema, textPageSchema, toolSchema } from "../../src/lib/content/schemas.ts";

const collections = [
  { name: "guides", schema: guideSchema },
  { name: "tools", schema: toolSchema },
  { name: "pages", schema: textPageSchema },
] as const;

function files(collection: string, locale: string): string[] {
  return readdirSync(new URL(`../../src/content/${collection}/${locale}/`, import.meta.url))
    .filter((file) => file.endsWith(".md"))
    .sort();
}

function read(collection: string, locale: string, file: string) {
  const text = readFileSync(
    new URL(`../../src/content/${collection}/${locale}/${file}`, import.meta.url),
    "utf8",
  );
  const match = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/.exec(text);
  if (match === null) throw new Error(`${collection}/${locale}/${file} has no front matter`);
  return { data: parse(match[1] ?? "") as unknown, body: match[2] ?? "" };
}

/** Words of copy: front-matter strings that are not URLs, and the body without link targets or markup. */
function copyOf(data: unknown, body: string): string[] {
  const strings: string[] = [];
  const walk = (value: unknown, key = ""): void => {
    if (typeof value === "string") {
      if (key !== "url" && key !== "calculator") strings.push(value);
    } else if (Array.isArray(value)) {
      for (const item of value) walk(item, key);
    } else if (value !== null && typeof value === "object") {
      for (const [childKey, child] of Object.entries(value)) walk(child, childKey);
    }
  };
  walk(data);
  let text = body
    .replace(/<kbd lang="en" dir="ltr">[^<]*<\/kbd>/g, "")
    .replace(/\]\([^)]*\)/g, "]");
  // Strip tags until none is left, so a tag split by another cannot survive.
  let previous;
  do {
    previous = text;
    text = text.replace(/<[^>]+>/g, "");
  } while (text !== previous);
  strings.push(text);
  return strings;
}

describe.each(collections)("the $name collection", ({ name, schema }) => {
  test("has the same files in English and Urdu", () => {
    expect(files(name, "en").length).toBeGreaterThan(0);
    expect(files(name, "ur")).toEqual(files(name, "en"));
  });

  for (const locale of ["en", "ur"] as const) {
    for (const file of files(name, locale)) {
      test(`${locale}/${file} has valid front matter`, () => {
        expect(schema.safeParse(read(name, locale, file).data).error).toBeUndefined();
      });
    }
  }

  for (const file of files(name, "ur")) {
    test(`ur/${file} is in Urdu script: no Latin letters outside a lang="en" kbd or a link target`, () => {
      const { data, body } = read(name, "ur", file);
      for (const text of copyOf(data, body)) expect(text).not.toMatch(/[A-Za-z]/);
    });

    test(`ur/${file} links to the Urdu pages of this site`, () => {
      const { body } = read(name, "ur", file);
      for (const [, target] of body.matchAll(/\]\((\/[^)]*)\)/g)) expect(target).toMatch(/^\/ur\//);
    });
  }

  for (const file of files(name, "en")) {
    test(`en/${file} uses British spelling`, () => {
      const { data, body } = read(name, "en", file);
      const american =
        /\b(color\w*|center\w*|favorite\w*|behavior\w*|licenses?|(organ|author|recogn|categor|priorit|custom|summar|normal|optim|minim|maxim|real|util|apolog|special)iz(e|es|ed|ing|ation|ations)|analyz\w*)\b/i;
      for (const text of copyOf(data, body)) {
        expect(text.replaceAll("Open Font License", "")).not.toMatch(american);
      }
    });
  }
});

describe("facts the research says must not be published as settled", () => {
  const all = collections.flatMap(({ name }) =>
    (["en", "ur"] as const).flatMap((locale) =>
      files(name, locale).map((file) => {
        const { data, body } = read(name, locale, file);
        return { id: `${name}/${locale}/${file}`, text: `${JSON.stringify(data)}\n${body}` };
      }),
    ),
  );
  const english = all.filter((page) => page.id.includes("/en/"));

  test("no page estimates final tax (D-10)", () => {
    for (const page of english) {
      expect(page.text, page.id).not.toMatch(/\byour (final|income) tax (is|will be|comes to)\b/i);
      expect(page.text, page.id).not.toMatch(
        /\b(we|the calculator|it) (estimates?|works? out) your (final|income) tax\b/i,
      );
    }
  });

  test("no 4% deemed rent, no Punjab default increase, no lease stamp-duty amount, no ICT fee (all graded Low)", () => {
    for (const page of english) {
      expect(page.text, page.id).not.toMatch(/deemed (commercial )?(rent|income)[^.]{0,40}4%/i);
      expect(page.text, page.id).not.toMatch(/Punjab[^.]{0,60}10% a year/i);
      expect(page.text, page.id).not.toMatch(/stamp duty[^.]{0,40}(Rs|\d+%)/i);
      expect(page.text, page.id).not.toMatch(/Rs 500\b/);
    }
  });

  test("the uncertain points are worded as uncertain", () => {
    const police =
      english.find((page) => page.id === "guides/en/police-registration.md")?.text ?? "";
    // KP's seven days were read in an unofficial copy; Balochistan's three days conflict with fifteen.
    expect(police).toMatch(/unofficial copy/);
    expect(police).toMatch(/fifteen days, so the deadline is not settled/);
    // Islamabad has no statute; the s.144 orders come and go.
    expect(police).toMatch(/no statute/i);
    const tax = english.find((page) => page.id === "guides/en/rental-income-tax.md")?.text ?? "";
    expect(tax).toMatch(/did not find the law that changed that/);
    expect(tax).toMatch(/no official rule on how a tenant spreads/);
  });

  test("every guide and calculator page was reviewed on the research date", () => {
    for (const { name } of collections.filter((collection) => collection.name !== "pages")) {
      for (const locale of ["en", "ur"] as const) {
        for (const file of files(name, locale)) {
          const data = read(name, locale, file).data as { lastReviewed: Date | string };
          expect(new Date(data.lastReviewed).toISOString().slice(0, 10)).toBe("2026-11-05");
        }
      }
    }
  });
});

describe("amounts never break from their currency or unit", () => {
  // As the app's MoneyFormat does: "Rs", "روپے", "lakh", "crore", "لاکھ" and "کروڑ" are
  // joined to the figures by a no-break space (U+00A0), never an ordinary space.
  const SPLIT = /\b(Rs|PKR) \d|\d (روپے|lakh|crore|million|لاکھ|کروڑ)|(لاکھ|کروڑ) روپے/u;
  const sources = [
    ...["guides", "tools", "pages"].flatMap((name) =>
      (["en", "ur"] as const).flatMap((locale) =>
        files(name, locale).map((file) => `${name}/${locale}/${file}`),
      ),
    ),
    ...[
      "home",
      "faq",
      "features",
      "pricing",
      "company",
      "how-it-works",
      "download",
      "licences",
    ].flatMap((name) => [`${name}/en.yaml`, `${name}/ur.yaml`]),
  ];

  test.each(sources)("src/content/%s", (path) => {
    const text = readFileSync(new URL(`../../src/content/${path}`, import.meta.url), "utf8");
    const line = text.split("\n").find((candidate) => SPLIT.test(candidate));
    expect(line).toBeUndefined();
    // In Urdu, a figure and the unit or month after it too ("30 یونٹس", "10 فیصد", "5 نومبر").
    if (path.includes("/ur/") || path.endsWith("/ur.yaml")) {
      expect(text.split("\n").find((candidate) => URDU_UNIT_SPLIT.test(candidate))).toBeUndefined();
    }
  });
});
