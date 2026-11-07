import { describe, expect, test } from "vitest";
import { formatDate, UI } from "../../src/i18n/ui.ts";

/** Every string in a nested object, with its dotted key. */
function strings(value: unknown, prefix = ""): [string, string][] {
  if (typeof value === "string") return [[prefix, value]];
  if (value !== null && typeof value === "object") {
    return Object.entries(value).flatMap(([key, child]) =>
      strings(child, prefix === "" ? key : `${prefix}.${key}`),
    );
  }
  return [];
}

describe("UI strings", () => {
  test("both languages define the same keys", () => {
    expect(strings(UI.ur).map(([key]) => key)).toEqual(strings(UI.en).map(([key]) => key));
  });

  test("Urdu strings are in Urdu script: no Latin letters (so no Roman Urdu)", () => {
    // The not-found page's note for readers of the other language is English on purpose
    // and is rendered inside lang="en".
    const urdu = strings(UI.ur).filter(([key]) => !key.startsWith("notFound.otherLanguage"));
    for (const [key, value] of urdu) expect(value, key).not.toMatch(/[A-Za-z]/);
  });

  test("English strings are in Latin script, except the note for Urdu readers", () => {
    const english = strings(UI.en).filter(([key]) => !key.startsWith("notFound.otherLanguage"));
    for (const [key, value] of english) expect(value, key).not.toMatch(/[؀-ۿ]/);
  });

  test("the guide notice says plainly that it is not legal or tax advice", () => {
    expect(UI.en.guide.notAdvice).toContain("not legal or tax advice");
    expect(UI.ur.guide.notAdvice).toContain("قانونی یا ٹیکس مشورہ نہیں");
  });
});

describe("formatDate", () => {
  test("writes dates out in each language, in UTC", () => {
    expect(formatDate("2026-11-05", "en")).toBe("5 November 2026");
    expect(formatDate("2026-11-05", "ur")).toBe("5 نومبر، 2026");
    expect(formatDate("2027-06-30", "en")).toBe("30 June 2027");
  });

  test("rejects a value that is not a date", () => {
    expect(() => formatDate("not-a-date", "en")).toThrow(RangeError);
  });
});
