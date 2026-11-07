import { describe, expect, test } from "vitest";
import {
  DEFAULT_APP_URL,
  DEFAULT_SITE_URL,
  resolveAppUrl,
  resolveSiteUrl,
} from "../../src/config/urls.ts";

describe("resolveSiteUrl (SITE_URL)", () => {
  test("defaults to the Vercel production address of maalik-e-makaan-site", () => {
    expect(DEFAULT_SITE_URL).toBe("https://maalik-e-makaan-site.vercel.app");
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
  test("defaults to the web app's production address (its APP_URL)", () => {
    expect(DEFAULT_APP_URL).toBe("https://maalik-e-makaan.vercel.app");
    expect(resolveAppUrl(undefined)).toBe("https://maalik-e-makaan.vercel.app/");
    expect(resolveAppUrl("")).toBe("https://maalik-e-makaan.vercel.app/");
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
