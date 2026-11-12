import { describe, expect, test } from "vitest";
import {
  articleNode,
  breadcrumbListNode,
  faqEntities,
  ids,
  jsonLdGraph,
  organizationNode,
  serializeJsonLd,
  softwareApplicationNode,
  webApplicationNode,
  webPageNode,
  websiteNode,
} from "../../src/lib/seo/json-ld.ts";

const site = "https://example.pk";

describe("shared nodes", () => {
  test("Organization and WebSite point at each other by @id", () => {
    const organization = organizationNode(site);
    const website = websiteNode(new URL(site));
    expect(organization).toMatchObject({
      "@type": "Organization",
      "@id": "https://example.pk/#organization",
      name: "AR Labs",
      legalName: "AR LABS (SMC-PRIVATE) LIMITED",
      url: "https://ar27111994.dev/",
      logo: { url: "https://example.pk/icon-512.png", width: 512, height: 512 },
      brand: { name: "Maalik-e-Makaan", alternateName: "مالکِ مکان", url: "https://example.pk/" },
      identifier: { propertyID: "SECP CUIN", value: "0361950" },
      founder: { "@type": "Person", name: "Ahmed Rehan" },
      sameAs: [
        "https://www.linkedin.com/company/ar27111994",
        "https://github.com/ar27111994/maalik-e-makaan",
      ],
    });
    expect(website).toMatchObject({
      "@type": "WebSite",
      inLanguage: ["en-GB", "ur"],
      publisher: { "@id": organization["@id"] },
    });
  });

  test("SoftwareApplication claims no price, rating or version", () => {
    const app = softwareApplicationNode({
      site,
      appUrl: "https://app.example.pk/",
      description: "Rent records.",
    });
    expect(app).toMatchObject({
      "@type": "SoftwareApplication",
      "@id": ids.app(site),
      url: "https://app.example.pk/",
      applicationCategory: "BusinessApplication",
      operatingSystem: "Android, iOS, Web",
    });
    for (const claim of ["offers", "aggregateRating", "review", "softwareVersion"]) {
      expect(app).not.toHaveProperty(claim);
    }
  });
});

describe("page nodes", () => {
  const url = "https://example.pk/ur/licences/";

  test("WebPage links to the site, the publisher and, when present, the breadcrumb", () => {
    const page = webPageNode({
      site,
      url,
      name: "لائسنس",
      description: "…",
      locale: "ur",
      hasBreadcrumb: true,
    });
    expect(page).toMatchObject({
      "@type": "WebPage",
      "@id": `${url}#webpage`,
      inLanguage: "ur",
      isPartOf: { "@id": ids.website(site) },
      breadcrumb: { "@id": `${url}#breadcrumb` },
    });
    expect(
      webPageNode({ site, url, name: "x", description: "y", locale: "en" }),
    ).not.toHaveProperty("breadcrumb");
  });

  test("an FAQPage carries its questions as Question/Answer pairs", () => {
    const page = webPageNode({
      site,
      url: "https://example.pk/",
      name: "Home",
      description: "…",
      locale: "en",
      type: "FAQPage",
      extra: { mainEntity: faqEntities([{ question: "Is it free?", answer: "Not decided." }]) },
    });
    expect(page["@type"]).toBe("FAQPage");
    expect(page.mainEntity).toEqual([
      {
        "@type": "Question",
        name: "Is it free?",
        acceptedAnswer: { "@type": "Answer", text: "Not decided." },
      },
    ]);
  });

  test("BreadcrumbList numbers its items from 1 and ends at the page", () => {
    const list = breadcrumbListNode(url, [
      { name: "ہوم", url: "https://example.pk/ur/" },
      { name: "لائسنس", url },
    ]);
    expect(list.itemListElement).toEqual([
      { "@type": "ListItem", position: 1, name: "ہوم", item: "https://example.pk/ur/" },
      { "@type": "ListItem", position: 2, name: "لائسنس", item: url },
    ]);
    expect(() => breadcrumbListNode(url, [{ name: "Home", url: "https://example.pk/" }])).toThrow(
      /at least two/,
    );
    expect(() =>
      breadcrumbListNode(url, [
        { name: "Home", url: "https://example.pk/" },
        { name: "Other", url: "https://example.pk/other/" },
      ]),
    ).toThrow(/page itself/);
  });

  test("Article: review date as dateModified, sources as citations", () => {
    const article = articleNode({
      site,
      url: "https://example.pk/guides/x/",
      headline: "Police registration",
      description: "…",
      locale: "en",
      dateModified: "2026-11-05",
      datePublished: undefined,
      citations: [{ title: "An Act", publisher: "Government", url: "https://gov.example/act.pdf" }],
    });
    expect(article).toMatchObject({
      "@type": "Article",
      datePublished: "2026-11-05",
      dateModified: "2026-11-05",
      inLanguage: "en-GB",
      mainEntityOfPage: { "@id": "https://example.pk/guides/x/#webpage" },
      image: {
        "@type": "ImageObject",
        url: "https://example.pk/og/en.png",
        width: 1200,
        height: 630,
      },
      citation: [
        {
          "@type": "CreativeWork",
          name: "An Act",
          url: "https://gov.example/act.pdf",
          publisher: { "@type": "Organization", name: "Government" },
        },
      ],
    });
  });
});

describe("the graph and its serialisation", () => {
  test("a graph refuses two nodes with the same @id", () => {
    expect(() => jsonLdGraph([organizationNode(site), organizationNode(site)])).toThrow(
      /Duplicate/,
    );
    expect(jsonLdGraph([organizationNode(site)])["@context"]).toBe("https://schema.org");
  });

  test("serialisation cannot close the <script> element early and round-trips", () => {
    const value = { name: "</script><script>alert(1)</script>", other: "a\u2028b\u2029c" };
    const json = serializeJsonLd(value);
    expect(json).not.toContain("<");
    expect(json).not.toMatch(/[\u2028\u2029]/);
    expect(JSON.parse(json)).toEqual(value);
  });
});

describe("calculators", () => {
  test("WebApplication: free (an offer at 0 PKR), with no rating or review", () => {
    const tool = webApplicationNode({
      site,
      url: "https://example.pk/tools/x/",
      name: "A calculator",
      description: "…",
      locale: "ur",
    });
    expect(tool).toMatchObject({
      "@type": "WebApplication",
      isAccessibleForFree: true,
      offers: { "@type": "Offer", price: "0", priceCurrency: "PKR" },
    });
    expect(tool).not.toHaveProperty("aggregateRating");
    expect(tool).not.toHaveProperty("review");
  });
});
