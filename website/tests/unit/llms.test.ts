import { describe, expect, test } from "vitest";
import {
  llmsFullTxt,
  llmsTxt,
  type LlmsGuide,
  type LlmsInput,
  type LlmsTextPage,
  type LlmsTool,
} from "../../src/lib/llms.ts";
import {
  download,
  faq,
  features,
  home,
  howItWorks,
  licences,
  licenceTexts,
  pricing,
  company,
} from "./fixtures.ts";

const guide = (locale: "en" | "ur"): LlmsGuide => ({
  locale,
  slug: "police-registration",
  title: locale === "en" ? "Registering a tenant with the police" : "کرایہ دار کی پولیس رجسٹریشن",
  description: "Who must report a tenant, and by when, in each province.",
  lastReviewed: "2026-11-05",
  sources: [
    {
      title:
        locale === "en"
          ? "Sindh Information of Temporary Residents Act 2015"
          : "سندھ انفارمیشن آف ٹیمپریری ریذیڈنٹس ایکٹ 2015",
      publisher: locale === "en" ? "Provincial Assembly of Sindh" : "صوبائی اسمبلی سندھ",
      url: "https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf",
      accessed: "2026-11-05",
    },
  ],
  body: "## In Sindh\n\nWithin 48 hours of handing over possession.",
});

const tool = (locale: "en" | "ur"): LlmsTool => ({
  locale,
  slug: "s155-withholding-calculator",
  order: 3,
  title: locale === "en" ? "Section 155 withholding tax calculator" : "دفعہ 155 کا کیلکولیٹر",
  description: "The tax a tenant deducts from rent under section 155 for tax year 2027.",
  intro: "Some tenants must deduct income tax from the rent they pay.",
  disclaimer: "Withholding only. It is not your final tax.",
  lastReviewed: "2026-11-05",
  sources: [
    {
      title:
        locale === "en"
          ? "Withholding Tax Rate Card, Tax Year 2027"
          : "ودہولڈنگ ٹیکس ریٹ کارڈ، ٹیکس سال 2027",
      publisher: locale === "en" ? "Federal Board of Revenue" : "فیڈرل بورڈ آف ریونیو",
      url: "https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf",
      accessed: "2026-11-05",
    },
  ],
  body: '## Check the ATL\n\nSend <kbd lang="en" dir="ltr">ATL</kbd> to 9966. See the [guide](/guides/rental-income-tax/).',
});

const textPage = (locale: "en" | "ur"): LlmsTextPage => ({
  locale,
  slug: "privacy",
  title: locale === "en" ? "Privacy" : "رازداری",
  description: "How this website and the app treat your data.",
  lastUpdated: "2026-11-07",
  body: "## In short\n\nThis website sets no cookies.",
});

const input = (
  guides: LlmsGuide[] = [],
  tools: LlmsTool[] = [],
  textPages: LlmsTextPage[] = [],
): LlmsInput => ({
  site: new URL("https://example.pk"),
  appUrl: "https://app.example.pk/",
  home,
  licences,
  features,
  howItWorks,
  faq,
  download,
  pricing,
  company,
  guides,
  tools,
  textPages,
  licenceTexts,
});

/**
 * The lines of `text` with a Latin "," or "." beside an Urdu word, where Urdu
 * writes "،" and "۔". A Markdown list or heading number such as "1. " is not
 * punctuation and is set aside.
 */
function latinPunctuationBesideUrdu(text: string): string[] {
  const pattern = /[؀-ۿ][^\S\n]*[,.]|[,.][^\S\n]*[؀-ۿ]/u;
  return text.split("\n").filter((line) => pattern.test(line.replace(/^(#+ )?\d+\. /u, "")));
}

describe("llms.txt", () => {
  const text = llmsTxt(input());
  const lines = text.split("\n");

  test("follows llmstxt.org: an H1, then a blockquote summary, then H2 link lists", () => {
    expect(lines[0]).toBe("# Maalik-e-Makaan (مالکِ مکان)");
    expect(lines[2]).toBe(`> ${home.en.description}`);
    const headings = lines.filter((line) => line.startsWith("#"));
    expect(headings).toEqual(["# Maalik-e-Makaan (مالکِ مکان)", "## Pages", "## Optional"]);
    // Every list item in a section is "- [name](url): notes".
    const items = lines.filter((line) => line.startsWith("- ["));
    expect(items.length).toBeGreaterThanOrEqual(7);
    for (const item of items) expect(item).toMatch(/^- \[[^\]]+\]\(https:\/\/[^)\s]+\): \S/);
  });

  test("states the key facts from the site's own answers, including the tax position", () => {
    for (const item of home.en.faq.items) expect(text).toContain(item.answer);
    expect(text).toContain("not legal or tax advice");
    // Version 1.0 is out: the summary gives the current version, not "in development".
    expect(text).not.toContain("In development");
    expect(text).toMatch(/Current version: \d+\.\d+\.\d+, released /);
  });

  test("lists every page in both languages, with absolute URLs", () => {
    for (const url of [
      "https://example.pk/",
      "https://example.pk/ur/",
      "https://example.pk/licences/",
      "https://example.pk/ur/licences/",
      "https://example.pk/features/",
      "https://example.pk/pricing/",
      "https://example.pk/ur/pricing/",
      "https://example.pk/roadmap/",
      "https://example.pk/ur/releases/",
      "https://example.pk/company/",
      "https://example.pk/ur/how-it-works/",
      "https://example.pk/faq/",
      "https://example.pk/ur/download/",
      "https://example.pk/guides/",
      "https://example.pk/ur/tools/",
      "https://example.pk/llms-full.txt",
    ]) {
      expect(text).toContain(`](${url})`);
    }
  });

  test("lists guides, with their review date, once there are any", () => {
    const withGuides = llmsTxt(input([guide("en"), guide("ur")]));
    expect(withGuides).toContain("## Guides");
    expect(withGuides).toContain(
      "- [Registering a tenant with the police](https://example.pk/guides/police-registration/)",
    );
    expect(withGuides).toContain("(https://example.pk/ur/guides/police-registration/)");
    expect(withGuides).toContain("Last reviewed 2026-11-05.");
  });

  test("lists the calculators and the text pages", () => {
    const text = llmsTxt(input([], [tool("en"), tool("ur")], [textPage("en"), textPage("ur")]));
    expect(text).toContain("## Calculators");
    expect(text).toContain(
      "- [Section 155 withholding tax calculator](https://example.pk/tools/s155-withholding-calculator/)",
    );
    expect(text).toContain("(https://example.pk/ur/tools/s155-withholding-calculator/)");
    expect(text).toContain("- [Privacy](https://example.pk/privacy/)");
    expect(text).toContain("(https://example.pk/ur/privacy/)");
  });
});

describe("llms-full.txt", () => {
  const text = llmsFullTxt(
    input([guide("en"), guide("ur")], [tool("en"), tool("ur")], [textPage("en"), textPage("ur")]),
  );

  test("holds the full copy of every page in both languages", () => {
    for (const locale of ["en", "ur"] as const) {
      expect(text).toContain(home[locale].hero.heading);
      for (const item of home[locale].features.items) expect(text).toContain(item.body);
      for (const item of home[locale].faq.items) expect(text).toContain(item.answer);
      expect(text).toContain(licences[locale].code.body);
      for (const section of features[locale].sections) expect(text).toContain(section.body);
      for (const step of howItWorks[locale].steps) expect(text).toContain(step.body);
      for (const plan of pricing[locale].plans) {
        expect(text).toContain(plan.price);
        for (const feature of plan.features) expect(text).toContain(feature.text);
      }
      for (const item of pricing[locale].faq.items) expect(text).toContain(item.answer);
      for (const group of faq[locale].groups) {
        for (const item of group.items) expect(text).toContain(item.answer);
      }
      for (const platform of download[locale].platforms) expect(text).toContain(platform.body);
    }
    expect(text).toContain("Copyright 2022 The Noto Project Authors");
  });

  test("dates each guide, says it is not advice, and lists its sources", () => {
    expect(text).toContain(
      "Last reviewed: 2026-11-05. This guide is general information, not legal or tax advice.",
    );
    expect(text).toContain("Within 48 hours of handing over possession.");
    expect(text).toContain(
      "- [Sindh Information of Temporary Residents Act 2015](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf), Provincial Assembly of Sindh (accessed 2026-11-05)",
    );
  });

  test("a calculator carries its disclaimer and sources; markup and site paths are resolved", () => {
    expect(text).toContain("Withholding only. It is not your final tax.");
    expect(text).toContain("Send ATL to 9966.");
    expect(text).not.toContain("<kbd");
    expect(text).toContain("[guide](https://example.pk/guides/rental-income-tax/)");
    expect(text).toContain(
      "- [Withholding Tax Rate Card, Tax Year 2027](https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf), Federal Board of Revenue (accessed 2026-11-05)",
    );
    expect(text).toContain("Last updated: 2026-11-07.");
  });

  test("the Urdu half joins its parts with the Urdu comma and full stop", () => {
    const urdu = text.slice(text.indexOf("URL: https://example.pk/ur/"));
    expect(latinPunctuationBesideUrdu(urdu)).toEqual([]);
    // The joins this file makes itself, which no content file supplies.
    expect(urdu).toContain(`${company.ur.founder.name}، ${company.ur.founder.role}۔`);
    expect(urdu).toContain(`**${home.ur.features.items[0]?.title}۔** `);
    expect(urdu).toContain("آخری نظرِ ثانی: 2026-11-05۔ ");
    expect(urdu).toContain("آخری تبدیلی: 2026-11-07۔");
    expect(urdu).toContain(")، صوبائی اسمبلی سندھ (رسائی کی تاریخ 2026-11-05)");
    expect(urdu).toContain(")، فیڈرل بورڈ آف ریونیو (رسائی کی تاریخ 2026-11-05)");
  });

  test("English comes before Urdu, and the file ends with one newline", () => {
    expect(text.indexOf(home.en.hero.heading)).toBeLessThan(text.indexOf(home.ur.hero.heading));
    expect(text.endsWith("\n")).toBe(true);
    expect(text.endsWith("\n\n")).toBe(false);
  });
});
