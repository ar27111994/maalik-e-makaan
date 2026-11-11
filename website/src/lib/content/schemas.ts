import { z } from "astro/zod";
import { FONT_LICENCES } from "../licences.ts";

/**
 * Schemas for the site's content collections (see src/content.config.ts).
 * They live here, outside the collection definitions, so unit tests can
 * exercise them directly.
 */

const text = (min: number, max: number) => z.string().trim().min(min).max(max);

/** A date written as YYYY-MM-DD in front matter (YAML reads it as a Date), kept as that string. */
export const isoDate = z
  .union([z.date(), z.string().regex(/^\d{4}-\d{2}-\d{2}$/)])
  .transform((value, context) => {
    const date = value instanceof Date ? value : new Date(`${value}T00:00:00Z`);
    if (Number.isNaN(date.getTime())) {
      context.addIssue({ code: "custom", message: "not a real date" });
      return z.NEVER;
    }
    const iso = date.toISOString().slice(0, 10);
    if (typeof value === "string" && iso !== value) {
      context.addIssue({ code: "custom", message: `${value} is not a real date` });
      return z.NEVER;
    }
    return iso;
  });

/** A web address for a source. Some official Pakistani sites still serve only http. */
export const sourceUrl = z.url({ protocol: /^https?$/ });

export const sourceSchema = z.strictObject({
  /** The document's own title, e.g. "Punjab Information of Temporary Residents Act 2015". */
  title: text(3, 200),
  /** Who publishes it, e.g. "Government of the Punjab". */
  publisher: text(2, 120),
  url: sourceUrl,
  /** When the source was last opened or checked. */
  accessed: isoDate,
});

/**
 * A guide: informational legal or tax content. Every guide carries the date it
 * was last reviewed and at least one official source; the guide layout prints
 * both, with a notice that it is not legal or tax advice.
 */
export const guideSchema = z.strictObject({
  /** The page title and h1 (the layout adds the site name to <title>). */
  title: text(10, 70),
  /** The meta description and the summary in llms.txt. */
  description: text(50, 165),
  /** The first publication date, if it differs from lastReviewed. */
  published: isoDate.optional(),
  lastReviewed: isoDate,
  sources: z.array(sourceSchema).min(1),
  /** Drafts are validated but not published. */
  draft: z.boolean().default(false),
});

const item = z.strictObject({ title: text(3, 80), body: text(10, 420) });
const question = z.strictObject({ question: text(10, 140), answer: text(20, 700) });
/**
 * A call to action: an in-page anchor such as "#features", "app" for the web
 * app, or a page of this site by its locale-neutral path such as "/features/"
 * (the page links to the same page in its own language).
 */
const link = z.strictObject({
  label: text(2, 60),
  href: z.string().regex(/^(#[a-z][a-z0-9-]*|app|\/([a-z0-9-]+\/)*)$/),
});

/**
 * The home page's copy, one file per language (src/content/home/en.yaml and
 * ur.yaml). The same data renders the HTML page, its FAQPage JSON-LD and its
 * section of llms-full.txt.
 */
export const homeSchema = z.strictObject({
  title: text(20, 75),
  description: text(70, 165),
  hero: z.strictObject({
    heading: text(10, 90),
    lede: text(40, 320),
    /** The main button until version 1.0 ships: something the reader can do today. */
    primaryCta: link,
    /** The main button once SITE.appStatus is "available": the web app itself. */
    appCta: link,
    secondaryCta: link,
  }),
  receipt: z.strictObject({
    caption: text(10, 120),
    title: text(3, 40),
    numberLabel: text(2, 30),
    number: z.string().regex(/^\d{4}-\d{4}$/),
    payerLabel: text(2, 30),
    payer: text(2, 40),
    lineLabel: text(2, 60),
    amountRupees: z.int().positive(),
    methodLabel: text(2, 40),
    method: text(2, 40),
    status: text(2, 20),
    balanceLabel: text(2, 30),
  }),
  features: z.strictObject({ heading: text(3, 60), items: z.array(item).min(3).max(9) }),
  steps: z.strictObject({ heading: text(3, 60), items: z.array(item).min(2).max(6) }),
  trust: z.strictObject({ heading: text(3, 60), items: z.array(item).min(2).max(6) }),
  faq: z.strictObject({
    heading: text(3, 60),
    items: z.array(question).min(2).max(4),
    more: link,
  }),
  /** `body` and `cta` until version 1.0 ships; `appBody` and `appCta` once it is available. */
  closing: z.strictObject({
    heading: text(5, 80),
    body: text(10, 200),
    cta: link,
    appBody: text(10, 200),
    appCta: link,
  }),
});

const fontLicenceSlugs = FONT_LICENCES.map((font) => font.slug) as [string, ...string[]];

/** The licences page's copy, one file per language (src/content/licences/). */
export const licencesSchema = z.strictObject({
  title: text(3, 60),
  description: text(70, 165),
  heading: text(3, 60),
  intro: text(20, 400),
  code: z.strictObject({ heading: text(3, 60), body: text(20, 400), linkLabel: text(5, 80) }),
  fonts: z.strictObject({
    heading: text(3, 60),
    body: text(20, 400),
    items: z
      .array(
        z.strictObject({
          licence: z.enum(fontLicenceSlugs),
          /** What the font is used for on this site. */
          role: text(5, 120),
        }),
      )
      .length(FONT_LICENCES.length),
    /** The link to each licence text; "{font}" is replaced by the font's name. */
    linkLabel: text(5, 80).regex(/\{font\}/),
    note: text(20, 400),
  }),
});

/** The heading, description and introduction every page of copy starts with. */
const pageHead = {
  /** The <title> (the layout adds the site's name) and the page's name in structured data. */
  title: text(3, 70),
  description: text(70, 165),
  heading: text(3, 90),
  intro: text(20, 600),
};

/** The questions page (/faq/): the site's one FAQPage. */
export const faqSchema = z.strictObject({
  ...pageHead,
  groups: z.array(z.strictObject({ heading: text(3, 60), items: z.array(question).min(1) })).min(2),
  /** A closing line; the page links `linkLabel` to the project's GitHub issues. */
  closing: z.strictObject({ body: text(10, 300), linkLabel: text(3, 60) }),
});

/**
 * Where a feature stands: "v1" is in the released app (version 1.0 and later);
 * "later" is planned for a later version (the Should-Have list in
 * .planning/REQUIREMENTS.md, and the roadmap page).
 */
export const featureStatus = z.enum(["v1", "later"]);

/** The features page (/features/). */
export const featuresSchema = z.strictObject({
  ...pageHead,
  status: z.strictObject({ v1: text(5, 60), later: text(5, 60), note: text(20, 400) }),
  sections: z
    .array(
      z.strictObject({
        id: z.string().regex(/^[a-z][a-z0-9-]*$/),
        heading: text(3, 70),
        status: featureStatus,
        body: text(20, 600),
        points: z.array(text(10, 300)).min(1).max(8),
      }),
    )
    .min(5),
  closing: z.strictObject({ heading: text(5, 80), body: text(10, 300), cta: link }),
});

/** The how-it-works page (/how-it-works/). */
export const howItWorksSchema = z.strictObject({
  ...pageHead,
  steps: z
    .array(
      z.strictObject({
        heading: text(3, 70),
        body: text(20, 600),
        points: z.array(text(10, 300)).max(6),
      }),
    )
    .min(3)
    .max(8),
  closing: z.strictObject({ heading: text(5, 80), body: text(10, 300), cta: link }),
});

/**
 * A plan on the pricing page. Prices are written as they are read ("Rs 999",
 * with a no-break space), not computed, because each language words them
 * differently and the stores localise the overseas plan's price.
 */
const pricingPlan = z.strictObject({
  id: z.string().regex(/^[a-z][a-z0-9-]*$/),
  name: text(2, 40),
  /** Who the plan is for, in one line. */
  audience: text(10, 160),
  price: text(1, 30),
  /** What the price is per: "a month", "for good". */
  period: text(2, 40),
  /**
   * The price of more units and of a year, or what replaces it on a free plan.
   * Overseas states two steps (Pro's up to 25 units, Business's from 30), so it runs longer.
   */
  annual: text(5, 220),
  /** How many units (and people) the plan covers. */
  allowance: text(5, 140),
  /** The plan the page recommends to most landlords. */
  featured: z.boolean(),
  features: z
    .array(
      z.strictObject({
        text: text(5, 160),
        /** Planned rather than in the app today; the page labels it. */
        soon: z.boolean(),
      }),
    )
    .min(3)
    .max(10),
});

/**
 * The pricing page (/pricing/). Billing is not switched on in the app yet, so
 * the page states the prices and when and how they will apply.
 */
export const pricingSchema = z.strictObject({
  ...pageHead,
  earlyAccess: z.strictObject({ heading: text(5, 80), body: text(20, 600) }),
  labels: z.strictObject({
    featured: text(2, 40),
    soon: text(2, 30),
    includes: text(2, 40),
  }),
  plans: z.array(pricingPlan).min(3).max(5),
  /** The rules every plan shares: what a unit is, currencies, tax. */
  notes: z.strictObject({ heading: text(3, 60), items: z.array(text(10, 400)).min(2).max(8) }),
  faq: z.strictObject({ heading: text(3, 60), items: z.array(question).min(4).max(10) }),
  closing: z.strictObject({ heading: text(5, 80), body: text(10, 300), cta: link }),
});

/**
 * The company page (/company/): who publishes the app, the founder, the pitch
 * deck and how to get in touch. The registration details themselves come from
 * src/config/site.ts, so they are written once.
 */
export const companySchema = z.strictObject({
  ...pageHead,
  facts: z.strictObject({
    heading: text(3, 60),
    legalName: text(3, 60),
    cuin: text(3, 60),
    incorporated: text(3, 60),
    /** The label and the value, which is words, so it is translated here. */
    registry: z.strictObject({ label: text(3, 60), value: text(5, 160) }),
    product: z.strictObject({ label: text(3, 60), value: text(5, 160) }),
  }),
  founder: z.strictObject({
    heading: text(3, 60),
    name: text(3, 60),
    role: text(3, 60),
    bio: z.array(text(20, 400)).min(1).max(4),
    links: text(3, 60),
  }),
  deck: z.strictObject({
    heading: text(3, 60),
    body: text(20, 400),
    link: text(3, 80),
    /** Shown on the Urdu page: the deck is in English. */
    language: text(10, 200),
  }),
  contact: z.strictObject({
    heading: text(3, 60),
    body: text(20, 400),
    email: text(3, 60),
    website: text(3, 60),
    linkedIn: text(3, 60),
  }),
});

/** A file attached to each release, as the download page describes it. */
const releaseFile = z.strictObject({ label: text(3, 60), note: text(10, 240) });

/** The app page (/download/): the web app now, the store apps when they exist. */
export const downloadSchema = z.strictObject({
  ...pageHead,
  platforms: z
    .array(
      z.strictObject({
        name: text(2, 60),
        status: text(3, 40),
        available: z.boolean(),
        body: text(20, 500),
      }),
    )
    .min(2),
  webApp: z.strictObject({ heading: text(3, 70), body: text(20, 500), cta: link }),
  /**
   * The latest release, filled in when the site is built from CHANGELOG.md and
   * the release-please manifest: "{version}" and "{date}" are replaced.
   */
  release: z.strictObject({
    heading: text(5, 70).regex(/\{version\}/),
    date: text(5, 100).regex(/\{date\}/),
    notesHeading: text(3, 60),
    /** Shown on the Urdu page, whose release notes are in English. */
    notesLanguage: text(10, 200),
    filesHeading: text(3, 60),
    files: z.strictObject({
      "android-arm64": releaseFile,
      "android-arm32": releaseFile,
      "android-x86": releaseFile,
      ios: releaseFile,
      web: releaseFile,
      checksums: releaseFile,
    }),
    allReleases: link,
    github: text(5, 80),
  }),
  requirements: z.strictObject({ heading: text(3, 70), items: z.array(text(10, 300)).min(1) }),
});

/**
 * A page of running text in Markdown (src/content/pages/<locale>/<slug>.md),
 * served at /<slug>/: the privacy notice and the terms.
 */
export const textPageSchema = z.strictObject({
  title: text(3, 70),
  description: text(70, 165),
  /** The date the page last changed in substance, shown under the heading. */
  lastUpdated: isoDate,
});

/**
 * A calculator page (src/content/tools/<locale>/<slug>.md, served at
 * /tools/<slug>/). The front matter introduces the calculator; the Markdown
 * body explains the method and the law, citing sources inline.
 */
export const toolSchema = z.strictObject({
  title: text(10, 70),
  description: text(70, 165),
  calculator: z.enum(["increment", "proration", "withholding"]),
  /** The tools index lists calculators in this order. */
  order: z.int().min(1),
  intro: text(40, 500),
  /** A prominent notice above the calculator (the tax calculator's "withholding only"). */
  disclaimer: text(40, 700).optional(),
  /** Shown when JavaScript is off. */
  noscript: text(40, 300),
  examples: z.strictObject({ heading: text(3, 80), intro: text(10, 300) }),
  lastReviewed: isoDate,
  sources: z.array(sourceSchema).min(1),
});

export type FaqContent = z.infer<typeof faqSchema>;
export type FeaturesContent = z.infer<typeof featuresSchema>;
export type HowItWorksContent = z.infer<typeof howItWorksSchema>;
export type DownloadContent = z.infer<typeof downloadSchema>;
export type PricingContent = z.infer<typeof pricingSchema>;
export type CompanyContent = z.infer<typeof companySchema>;
export type TextPageData = z.infer<typeof textPageSchema>;
export type ToolData = z.infer<typeof toolSchema>;
export type HomeContent = z.infer<typeof homeSchema>;
export type LicencesContent = z.infer<typeof licencesSchema>;
export type GuideData = z.infer<typeof guideSchema>;
export type Source = z.infer<typeof sourceSchema>;
