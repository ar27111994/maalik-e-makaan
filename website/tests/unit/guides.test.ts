import { describe, expect, test } from "vitest";
import { guidePath, parseGuideId, publishedGuides } from "../../src/lib/content/guides.ts";
import { guideSchema, isoDate } from "../../src/lib/content/schemas.ts";

const entry = (id: string, draft = false) => ({ id, data: { draft } });

describe("guide ids", () => {
  test("parse into locale and slug", () => {
    expect(parseGuideId("ur/police-registration")).toEqual({
      locale: "ur",
      slug: "police-registration",
    });
    expect(guidePath("police-registration")).toBe("/guides/police-registration/");
  });

  test.each(["fr/x", "en", "en/Has-Capitals", "en/a/b", "en/trailing-", "en/double--dash"])(
    "reject %s",
    (id) => {
      expect(() => parseGuideId(id)).toThrow();
    },
  );
});

describe("publishedGuides", () => {
  test("returns one language's guides, sorted, leaving out drafts", () => {
    const entries = [
      entry("en/b"),
      entry("ur/b"),
      entry("en/a"),
      entry("ur/a"),
      entry("en/c", true),
    ];
    expect(publishedGuides(entries, "en").map((guide) => guide.id)).toEqual(["en/a", "en/b"]);
    expect(publishedGuides(entries, "ur").map((guide) => guide.ref.slug)).toEqual(["a", "b"]);
  });

  test("fails when a published guide lacks its translation", () => {
    expect(() => publishedGuides([entry("en/a"), entry("ur/a"), entry("en/b")], "en")).toThrow(
      /Missing: ur\/b/,
    );
  });
});

describe("the guide schema", () => {
  const valid = {
    title: "Registering a tenant with the police",
    description:
      "Who must report a tenant to the police in each province, by when, and what the law says happens if nobody does.",
    lastReviewed: "2026-11-05",
    sources: [
      {
        title: "Punjab Information of Temporary Residents Act 2015",
        publisher: "Government of the Punjab",
        url: "http://punjablaws.gov.pk/laws/2591.html",
        accessed: "2026-11-05",
      },
    ],
  };

  test("accepts a dated guide with an official source; drafts default to false", () => {
    expect(guideSchema.parse(valid)).toMatchObject({ draft: false, lastReviewed: "2026-11-05" });
  });

  test("requires a review date and at least one source", () => {
    expect(guideSchema.safeParse({ ...valid, lastReviewed: undefined }).success).toBe(false);
    expect(guideSchema.safeParse({ ...valid, sources: [] }).success).toBe(false);
  });

  test("rejects unknown fields, impossible dates and non-web sources", () => {
    expect(guideSchema.safeParse({ ...valid, author: "x" }).success).toBe(false);
    expect(guideSchema.safeParse({ ...valid, lastReviewed: "2026-02-30" }).success).toBe(false);
    const ftp = { ...valid.sources[0], url: "ftp://example.pk/act.pdf" };
    expect(guideSchema.safeParse({ ...valid, sources: [ftp] }).success).toBe(false);
  });

  test("YAML dates (Date objects) become YYYY-MM-DD strings", () => {
    expect(isoDate.parse(new Date("2026-11-05T00:00:00Z"))).toBe("2026-11-05");
  });
});
