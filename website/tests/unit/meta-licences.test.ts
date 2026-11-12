import { describe, expect, test } from "vitest";
import {
  copyrightLine,
  fontLicence,
  fontLicencePath,
  FONT_LICENCES,
} from "../../src/lib/licences.ts";
import { documentTitle, ogLocales, siteName } from "../../src/lib/seo/meta.ts";
import { licenceTexts } from "./fixtures.ts";

describe("document titles", () => {
  test("add the site's name in the page's language, unless the title starts with it", () => {
    expect(documentTitle("Licences", "en")).toBe("Licences | Maalik-e-Makaan");
    expect(documentTitle("لائسنس", "ur")).toBe("لائسنس | مالکِ مکان");
    expect(documentTitle("Maalik-e-Makaan: rent records", "en")).toBe(
      "Maalik-e-Makaan: rent records",
    );
    expect(siteName("ur")).toBe("مالکِ مکان");
  });

  test("Open Graph locales name the page's language and the other one", () => {
    expect(ogLocales("en")).toEqual({ locale: "en_GB", alternate: "ur_PK" });
    expect(ogLocales("ur")).toEqual({ locale: "ur_PK", alternate: "en_GB" });
  });
});

describe("font licences", () => {
  test("every font has an OFL 1.1 text with a copyright line", () => {
    for (const font of FONT_LICENCES) {
      const text = licenceTexts[font.slug] ?? "";
      expect(text).toContain("SIL OPEN FONT LICENSE Version 1.1");
      expect(copyrightLine(text)).toMatch(/^Copyright \d{4}/);
      // No Reserved Font Name: the subsets may keep the fonts' names.
      expect(text.split("\n")[0]).not.toMatch(/Reserved Font Name/i);
    }
    expect(copyrightLine(licenceTexts["ofl-noto-sans-arabic"] ?? "")).toBe(
      "Copyright 2022 The Noto Project Authors (https://github.com/notofonts/arabic)",
    );
    expect(copyrightLine(licenceTexts["ofl-noto-nastaliq-urdu"] ?? "")).toBe(
      "Copyright 2022 The Noto Project Authors (https://github.com/notofonts/nastaliq)",
    );
  });

  test("lists the three fonts the site serves: Latin, Urdu and the Urdu wordmark", () => {
    expect(FONT_LICENCES.map((font) => font.family)).toEqual([
      "Atkinson Hyperlegible Next",
      "Noto Sans Arabic",
      "Noto Nastaliq Urdu",
    ]);
  });

  test("paths and lookups", () => {
    expect(fontLicencePath("ofl-noto-sans-arabic")).toBe("/licences/ofl-noto-sans-arabic.txt");
    expect(fontLicence("ofl-atkinson-hyperlegible-next").family).toBe("Atkinson Hyperlegible Next");
    expect(() => fontLicence("ofl-unknown")).toThrow(/Unknown/);
    expect(() => copyrightLine("no notice here")).toThrow(/no copyright line/);
  });
});
