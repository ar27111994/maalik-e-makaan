/**
 * Structured data (schema.org JSON-LD) for every page. Each page carries one
 * `@graph`: the Organization and WebSite that every page shares, the page
 * itself, and whatever the page adds (the SoftwareApplication on the home
 * page, a BreadcrumbList, an Article for a guide). Nodes refer to each other by
 * `@id`, so search engines and AI tools can tell they describe one product.
 */
import { SITE } from "../../config/site.ts";
import { LOCALE_INFO, type Locale } from "../../i18n/locales.ts";
import { ogImage } from "./meta.ts";

export type JsonLdNode = {
  readonly "@type": string | readonly string[];
  readonly "@id"?: string;
} & Readonly<Record<string, unknown>>;

export interface JsonLdGraph {
  readonly "@context": "https://schema.org";
  readonly "@graph": readonly JsonLdNode[];
}

/** The site's origin without a trailing slash, from `Astro.site` or SITE_URL. */
function origin(site: string | URL): string {
  return new URL(site).origin;
}

export const ids = {
  organization: (site: string | URL) => `${origin(site)}/#organization`,
  website: (site: string | URL) => `${origin(site)}/#website`,
  app: (site: string | URL) => `${origin(site)}/#app`,
  webPage: (pageUrl: string) => `${pageUrl}#webpage`,
  breadcrumb: (pageUrl: string) => `${pageUrl}#breadcrumb`,
  article: (pageUrl: string) => `${pageUrl}#article`,
  tool: (pageUrl: string) => `${pageUrl}#tool`,
} as const;

/** The language tags of the site's content, as `inLanguage` values. */
const inLanguage = (locale: Locale) => LOCALE_INFO[locale].htmlLang;

/** The project and publisher behind the site and the app. */
export function organizationNode(site: string | URL): JsonLdNode {
  return {
    "@type": "Organization",
    "@id": ids.organization(site),
    name: SITE.name,
    alternateName: SITE.nameUrdu,
    url: `${origin(site)}/`,
    logo: {
      "@type": "ImageObject",
      url: `${origin(site)}/icon-512.png`,
      width: 512,
      height: 512,
    },
    founder: { "@type": "Person", name: SITE.copyrightHolder },
    sameAs: [SITE.repositoryUrl],
  };
}

/** The website, in both its languages. */
export function websiteNode(site: string | URL): JsonLdNode {
  return {
    "@type": "WebSite",
    "@id": ids.website(site),
    name: SITE.name,
    alternateName: SITE.nameUrdu,
    url: `${origin(site)}/`,
    inLanguage: [inLanguage("en"), inLanguage("ur")],
    publisher: { "@id": ids.organization(site) },
  };
}

/**
 * The app the site describes. No price, rating or release version is given:
 * none exists yet, and structured data must not claim what the page does not.
 */
export function softwareApplicationNode({
  site,
  appUrl,
  description,
}: {
  site: string | URL;
  appUrl: string;
  description: string;
}): JsonLdNode {
  return {
    "@type": "SoftwareApplication",
    "@id": ids.app(site),
    name: SITE.name,
    alternateName: SITE.nameUrdu,
    description,
    url: appUrl,
    applicationCategory: "BusinessApplication",
    applicationSubCategory: "Property management",
    operatingSystem: "Android, iOS, Web",
    inLanguage: [inLanguage("en"), inLanguage("ur")],
    publisher: { "@id": ids.organization(site) },
    license: SITE.licenceUrl,
  };
}

export interface PageFacts {
  readonly site: string | URL;
  /** The page's canonical URL. */
  readonly url: string;
  readonly name: string;
  readonly description: string;
  readonly locale: Locale;
  /** The page's own type: "WebPage" by default, "FAQPage" for a page of questions. */
  readonly type?: "WebPage" | "FAQPage" | "AboutPage" | "CollectionPage";
  /** Whether a BreadcrumbList node for this page is in the same graph. */
  readonly hasBreadcrumb?: boolean;
  /** Extra properties, e.g. `mainEntity` or `about`. */
  readonly extra?: Readonly<Record<string, unknown>>;
}

export function webPageNode(page: PageFacts): JsonLdNode {
  return {
    "@type": page.type ?? "WebPage",
    "@id": ids.webPage(page.url),
    url: page.url,
    name: page.name,
    description: page.description,
    inLanguage: inLanguage(page.locale),
    isPartOf: { "@id": ids.website(page.site) },
    publisher: { "@id": ids.organization(page.site) },
    ...(page.hasBreadcrumb === true ? { breadcrumb: { "@id": ids.breadcrumb(page.url) } } : {}),
    ...page.extra,
  };
}

export interface Question {
  readonly question: string;
  readonly answer: string;
}

/** `mainEntity` for an FAQPage: the questions exactly as the page shows them. */
export function faqEntities(questions: readonly Question[]): JsonLdNode[] {
  return questions.map(({ question, answer }) => ({
    "@type": "Question",
    name: question,
    acceptedAnswer: { "@type": "Answer", text: answer },
  }));
}

export interface Crumb {
  readonly name: string;
  /** Absolute URL. */
  readonly url: string;
}

/** The trail from the home page to `pageUrl`; the last crumb is the page itself. */
export function breadcrumbListNode(pageUrl: string, crumbs: readonly Crumb[]): JsonLdNode {
  if (crumbs.length < 2) throw new RangeError("A breadcrumb trail needs at least two items");
  const last = crumbs.at(-1);
  if (last?.url !== pageUrl) throw new RangeError("The last breadcrumb must be the page itself");
  return {
    "@type": "BreadcrumbList",
    "@id": ids.breadcrumb(pageUrl),
    itemListElement: crumbs.map((crumb, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  };
}

export interface Citation {
  readonly title: string;
  readonly publisher: string;
  readonly url: string;
}

/** A guide: an informational article with its review date and the sources it cites. */
export function articleNode({
  site,
  url,
  headline,
  description,
  locale,
  dateModified,
  datePublished,
  citations,
}: {
  site: string | URL;
  url: string;
  headline: string;
  description: string;
  locale: Locale;
  /** The last-reviewed date, YYYY-MM-DD. */
  dateModified: string;
  datePublished?: string | undefined;
  citations: readonly Citation[];
}): JsonLdNode {
  const image = ogImage(locale);
  return {
    "@type": "Article",
    "@id": ids.article(url),
    headline,
    description,
    // The page's Open Graph card: the same image a link preview shows.
    image: {
      "@type": "ImageObject",
      url: new URL(image.path, site).href,
      width: image.width,
      height: image.height,
    },
    inLanguage: inLanguage(locale),
    datePublished: datePublished ?? dateModified,
    dateModified,
    author: { "@id": ids.organization(site) },
    publisher: { "@id": ids.organization(site) },
    mainEntityOfPage: { "@id": ids.webPage(url) },
    isAccessibleForFree: true,
    citation: citations.map((citation) => ({
      "@type": "CreativeWork",
      name: citation.title,
      url: citation.url,
      publisher: { "@type": "Organization", name: citation.publisher },
    })),
  };
}

/**
 * A calculator that runs in the browser. It is free to use (an offer at a
 * price of 0) and needs nothing but a browser with JavaScript. No rating or
 * review is claimed: there are none.
 */
export function webApplicationNode({
  site,
  url,
  name,
  description,
  locale,
}: {
  site: string | URL;
  url: string;
  name: string;
  description: string;
  locale: Locale;
}): JsonLdNode {
  return {
    "@type": "WebApplication",
    "@id": ids.tool(url),
    name,
    description,
    url,
    applicationCategory: "FinanceApplication",
    operatingSystem: "Any",
    browserRequirements: "Requires JavaScript",
    inLanguage: inLanguage(locale),
    isAccessibleForFree: true,
    offers: { "@type": "Offer", price: "0", priceCurrency: "PKR" },
    publisher: { "@id": ids.organization(site) },
    mainEntityOfPage: { "@id": ids.webPage(url) },
  };
}

/** One graph per page. Properties whose value is `undefined` are dropped when serialised. */
export function jsonLdGraph(nodes: readonly JsonLdNode[]): JsonLdGraph {
  const seen = new Set<string>();
  for (const node of nodes) {
    const id = node["@id"];
    if (id === undefined) continue;
    if (seen.has(id)) throw new Error(`Duplicate JSON-LD @id: ${id}`);
    seen.add(id);
  }
  return { "@context": "https://schema.org", "@graph": nodes };
}

/**
 * JSON for a `<script type="application/ld+json">` element. `<` is escaped so
 * no string in the data can close the element early, and the line and
 * paragraph separators are escaped for older parsers.
 */
export function serializeJsonLd(value: unknown): string {
  return JSON.stringify(value)
    .replaceAll("<", "\\u003c")
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
}
