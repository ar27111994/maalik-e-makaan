/**
 * Loads the site's content collections for pages and generated files. Only
 * modules that run inside Astro (pages and endpoints) may import this file,
 * because it reads "astro:content".
 */
import { getCollection, getEntry } from "astro:content";
import { LOCALES } from "../../i18n/locales.ts";
import { licenceText } from "../licence-texts.ts";
import { FONT_LICENCES } from "../licences.ts";
import type { LlmsGuide, LlmsInput, LlmsTextPage, LlmsTool } from "../llms.ts";
import { pairedEntries, publishedGuides } from "./guides.ts";

function required<T>(entry: T | undefined, file: string): T {
  if (entry === undefined) throw new Error(`${file} is missing`);
  return entry;
}

/** Every published guide, in both languages, sorted by language and slug. */
export async function loadGuides(): Promise<LlmsGuide[]> {
  const entries = await getCollection("guides");
  return LOCALES.flatMap((locale) =>
    publishedGuides(entries, locale).map((entry) => ({
      locale,
      slug: entry.ref.slug,
      title: entry.data.title,
      description: entry.data.description,
      lastReviewed: entry.data.lastReviewed,
      sources: entry.data.sources,
      body: entry.body ?? "",
    })),
  );
}

/** Every calculator page, in both languages, in the order of the tools index. */
export async function loadTools(): Promise<LlmsTool[]> {
  const entries = await getCollection("tools");
  return LOCALES.flatMap((locale) =>
    pairedEntries(entries, locale, "tools")
      .sort((a, b) => a.data.order - b.data.order)
      .map((entry) => ({
        locale,
        slug: entry.ref.slug,
        order: entry.data.order,
        title: entry.data.title,
        description: entry.data.description,
        intro: entry.data.intro,
        disclaimer: entry.data.disclaimer,
        lastReviewed: entry.data.lastReviewed,
        sources: entry.data.sources,
        body: entry.body ?? "",
      })),
  );
}

/** Every page of running text (privacy, terms), in both languages. */
export async function loadTextPages(): Promise<LlmsTextPage[]> {
  const entries = await getCollection("pages");
  return LOCALES.flatMap((locale) =>
    pairedEntries(entries, locale, "pages").map((entry) => ({
      locale,
      slug: entry.ref.slug,
      title: entry.data.title,
      description: entry.data.description,
      lastUpdated: entry.data.lastUpdated,
      body: entry.body ?? "",
    })),
  );
}

/** Everything llms.txt and llms-full.txt are built from. */
export async function loadLlmsInput(site: URL, appUrl: string): Promise<LlmsInput> {
  const [homeEn, homeUr, licencesEn, licencesUr, guides, tools, textPages] = await Promise.all([
    getEntry("home", "en"),
    getEntry("home", "ur"),
    getEntry("licences", "en"),
    getEntry("licences", "ur"),
    loadGuides(),
    loadTools(),
    loadTextPages(),
  ]);
  const [
    featuresEn,
    featuresUr,
    howEn,
    howUr,
    faqEn,
    faqUr,
    downloadEn,
    downloadUr,
    priceEn,
    priceUr,
  ] = await Promise.all([
    getEntry("features", "en"),
    getEntry("features", "ur"),
    getEntry("howItWorks", "en"),
    getEntry("howItWorks", "ur"),
    getEntry("faq", "en"),
    getEntry("faq", "ur"),
    getEntry("download", "en"),
    getEntry("download", "ur"),
    getEntry("pricing", "en"),
    getEntry("pricing", "ur"),
  ]);
  return {
    site,
    appUrl,
    home: {
      en: required(homeEn, "src/content/home/en.yaml").data,
      ur: required(homeUr, "src/content/home/ur.yaml").data,
    },
    licences: {
      en: required(licencesEn, "src/content/licences/en.yaml").data,
      ur: required(licencesUr, "src/content/licences/ur.yaml").data,
    },
    features: {
      en: required(featuresEn, "src/content/features/en.yaml").data,
      ur: required(featuresUr, "src/content/features/ur.yaml").data,
    },
    howItWorks: {
      en: required(howEn, "src/content/how-it-works/en.yaml").data,
      ur: required(howUr, "src/content/how-it-works/ur.yaml").data,
    },
    faq: {
      en: required(faqEn, "src/content/faq/en.yaml").data,
      ur: required(faqUr, "src/content/faq/ur.yaml").data,
    },
    download: {
      en: required(downloadEn, "src/content/download/en.yaml").data,
      ur: required(downloadUr, "src/content/download/ur.yaml").data,
    },
    pricing: {
      en: required(priceEn, "src/content/pricing/en.yaml").data,
      ur: required(priceUr, "src/content/pricing/ur.yaml").data,
    },
    guides,
    tools,
    textPages,
    licenceTexts: Object.fromEntries(
      FONT_LICENCES.map((font) => [font.slug, licenceText(font.slug)]),
    ),
  };
}
