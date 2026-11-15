import { describe, expect, test } from "vitest";
import origins from "../../../contracts/origins.json";
import {
  DEFAULT_APP_URL,
  DEFAULT_SITE_URL,
  resolveAppUrl,
  resolveSiteUrl,
} from "../../src/config/urls.ts";
import { readOrigins } from "../../scripts/lib/origins.ts";

/** Every address contracts/origins.json names, with the property it is under. */
const named: readonly (readonly [string, string])[] = [
  ["site.origin", origins.site.origin],
  ...origins.site.aliases.map((url) => ["site.aliases", url] as const),
  ...origins.site.legacy.map((url) => ["site.legacy", url] as const),
  ["app.origin", origins.app.origin],
  ...origins.app.legacy.map((url) => ["app.legacy", url] as const),
];

describe("contracts/origins.json, the one source of the production addresses (D-20)", () => {
  test("reads the same on Node (the deck, the e2e suite) as through the bundler", () => {
    expect(readOrigins()).toEqual(origins);
  });

  test.each(named)("%s %s is an https origin, written as browsers send it", (_, url) => {
    expect(resolveSiteUrl(url)).toBe(url);
    expect(new URL(url).protocol).toBe("https:");
    expect(new URL(url).origin).toBe(url);
  });

  test("names each address once, and the earlier ones only as redirects", () => {
    const urls = named.map(([, url]) => url);
    expect(new Set(urls).size).toBe(urls.length);
    const current = [origins.site.origin, origins.app.origin, ...origins.site.aliases];
    for (const legacy of [...origins.site.legacy, ...origins.app.legacy]) {
      expect(current).not.toContain(legacy);
    }
  });
});

describe("resolveSiteUrl (SITE_URL)", () => {
  test("defaults to the website's production origin in contracts/origins.json", () => {
    expect(DEFAULT_SITE_URL).toBe(origins.site.origin);
    expect(resolveSiteUrl(undefined)).toBe(DEFAULT_SITE_URL);
    expect(resolveSiteUrl("  ")).toBe(DEFAULT_SITE_URL);
  });

  test("accepts a custom domain and returns its origin without a trailing slash", () => {
    expect(resolveSiteUrl("https://example.pk")).toBe("https://example.pk");
    expect(resolveSiteUrl("https://example.pk/")).toBe("https://example.pk");
    expect(resolveSiteUrl("http://localhost:4321")).toBe("http://localhost:4321");
  });

  test.each([
    ["not a url", /absolute URL/],
    ["http://example.pk", /must use https/],
    ["ftp://example.pk", /must use https/],
    ["https://user:pass@example.pk", /credentials/],
    ["https://example.pk/?a=1", /query or fragment/],
    ["https://example.pk/#top", /query or fragment/],
    ["https://example.pk/site", /without a path/],
  ])("rejects %s", (raw, message) => {
    expect(() => resolveSiteUrl(raw)).toThrow(message);
  });
});

describe("resolveAppUrl (PUBLIC_APP_URL)", () => {
  test("defaults to the web app's production origin (its APP_URL) in contracts/origins.json", () => {
    expect(DEFAULT_APP_URL).toBe(origins.app.origin);
    expect(resolveAppUrl(undefined)).toBe(`${origins.app.origin}/`);
    expect(resolveAppUrl("")).toBe(`${origins.app.origin}/`);
  });

  test("normalises a custom address to end in a slash, keeping any path", () => {
    expect(resolveAppUrl("https://app.example.pk")).toBe("https://app.example.pk/");
    expect(resolveAppUrl("https://example.pk/app")).toBe("https://example.pk/app/");
  });

  test.each(["http://app.example.pk", "https://app.example.pk/?x=1", "app.example.pk"])(
    "rejects %s",
    (raw) => {
      expect(() => resolveAppUrl(raw)).toThrow();
    },
  );
});
