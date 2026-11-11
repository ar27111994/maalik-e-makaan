import { describe, expect, test } from "vitest";
import {
  absoluteUrl,
  alternateLinks,
  delocalisePath,
  isLocale,
  LOCALE_INFO,
  localisePath,
  otherLocale,
} from "../../src/i18n/locales.ts";

describe("locales", () => {
  test("English is left to right and British; Urdu is right to left", () => {
    expect(LOCALE_INFO.en).toMatchObject({ htmlLang: "en-GB", dir: "ltr", hreflang: "en" });
    expect(LOCALE_INFO.ur).toMatchObject({ htmlLang: "ur", dir: "rtl", hreflang: "ur" });
    expect(LOCALE_INFO.ur.endonym).toBe("اردو");
  });

  test("each language joins parts of a sentence with its own comma", () => {
    expect(LOCALE_INFO.en.comma).toBe(", ");
    // The Arabic comma U+060C, which Urdu uses; never the Latin "," between Urdu words.
    expect(LOCALE_INFO.ur.comma).toBe("، ");
  });

  test("isLocale and otherLocale", () => {
    expect(isLocale("ur")).toBe(true);
    expect(isLocale("fr")).toBe(false);
    expect(isLocale(undefined)).toBe(false);
    expect(otherLocale("en")).toBe("ur");
    expect(otherLocale("ur")).toBe("en");
  });

  test("localisePath puts Urdu under /ur and keeps English at the root", () => {
    expect(localisePath("/", "en")).toBe("/");
    expect(localisePath("/", "ur")).toBe("/ur/");
    expect(localisePath("/licences/", "ur")).toBe("/ur/licences/");
    expect(localisePath("/licences/", "en")).toBe("/licences/");
  });

  test("localisePath rejects paths that are not locale-neutral", () => {
    expect(() => localisePath("licences/", "en")).toThrow(/single "\/"/);
    expect(() => localisePath("//evil.example/", "en")).toThrow(/single "\/"/);
    expect(() => localisePath("/ur/licences/", "en")).toThrow(/locale-neutral/);
    expect(() => localisePath("/ur", "ur")).toThrow(/locale-neutral/);
  });

  test("delocalisePath inverts localisePath", () => {
    for (const path of ["/", "/licences/", "/guides/police-registration/"]) {
      for (const locale of ["en", "ur"] as const) {
        expect(delocalisePath(localisePath(path, locale))).toEqual({ locale, path });
      }
    }
    expect(delocalisePath("/ur")).toEqual({ locale: "ur", path: "/" });
    // "/urdu-guide/" is an English page whose slug happens to start with "ur".
    expect(delocalisePath("/urdu-guide/")).toEqual({ locale: "en", path: "/urdu-guide/" });
  });

  test("alternateLinks lists both languages and x-default (English), as absolute URLs", () => {
    expect(alternateLinks("https://example.pk", "/licences/")).toEqual([
      { hreflang: "en", href: "https://example.pk/licences/" },
      { hreflang: "ur", href: "https://example.pk/ur/licences/" },
      { hreflang: "x-default", href: "https://example.pk/licences/" },
    ]);
    expect(absoluteUrl(new URL("https://example.pk"), "/ur/")).toBe("https://example.pk/ur/");
  });
});
