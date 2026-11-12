import { describe, expect, test } from "vitest";
import {
  langAttribute,
  languageOfText,
  numberRanges,
  scriptAttributes,
} from "../../src/i18n/script.ts";

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

describe("numberRanges", () => {
  test("cuts out each number range, so a right-to-left page can keep it in order", () => {
    expect(numberRanges("مالی سال 2026-27 کا سرکلر نمبر 2 (فنانس ایکٹ 2026)")).toEqual([
      { text: "مالی سال ", numberRange: false },
      { text: "2026-27", numberRange: true },
      { text: " کا سرکلر نمبر 2 (فنانس ایکٹ 2026)", numberRange: false },
    ]);
    expect(numberRanges("2026-11-05")).toEqual([{ text: "2026-11-05", numberRange: true }]);
    expect(numberRanges("ص 10–12")).toEqual([
      { text: "ص ", numberRange: false },
      { text: "10–12", numberRange: true },
    ]);
  });

  test("leaves a text without a range whole", () => {
    expect(numberRanges("فنانس ایکٹ 2026")).toEqual([
      { text: "فنانس ایکٹ 2026", numberRange: false },
    ]);
    expect(numberRanges("")).toEqual([]);
  });
});
