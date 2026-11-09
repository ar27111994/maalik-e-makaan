import { describe, expect, test } from "vitest";
import { langAttribute, languageOfText, scriptAttributes } from "../../src/i18n/script.ts";

describe("languageOfText", () => {
  test("reads the language from the script", () => {
    expect(languageOfText("Sindh Information of Temporary Residents Act 2015")).toBe("en");
    expect(languageOfText("صوبائی اسمبلی سندھ")).toBe("ur");
    expect(languageOfText("2026-11-05")).toBeUndefined();
    expect(languageOfText("Act ایکٹ")).toBeUndefined();
  });

  test("langAttribute marks only text in the other language", () => {
    expect(langAttribute("Provincial Assembly of Sindh", "ur")).toBe("en-GB");
    expect(langAttribute("Provincial Assembly of Sindh", "en")).toBeUndefined();
    expect(langAttribute("صوبائی اسمبلی سندھ", "en")).toBe("ur");
    expect(langAttribute("48", "ur")).toBeUndefined();
  });

  test("scriptAttributes adds the direction that isolates the text", () => {
    expect(scriptAttributes("Provincial Assembly of Sindh", "ur")).toEqual({
      lang: "en-GB",
      dir: "ltr",
    });
    expect(scriptAttributes("صوبائی اسمبلی", "en")).toEqual({ lang: "ur", dir: "rtl" });
    expect(scriptAttributes("Provincial Assembly of Sindh", "en")).toEqual({});
  });
});
