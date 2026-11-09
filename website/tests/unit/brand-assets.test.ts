import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import {
  arabicScriptCharacters,
  charactersOf,
  codePointsOf,
  isArabicScript,
  LATIN_RANGES,
  typographyCss,
  unicodeRange,
  URDU_REPERTOIRE,
} from "../../integrations/brand-assets.ts";

describe("character sets", () => {
  test("the Urdu repertoire covers the whole Urdu alphabet and Urdu punctuation", () => {
    const alphabet =
      "ا آ ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن ں و ہ ھ ء ی ے ۂ ۓ ئ ؤ";
    for (const letter of alphabet.split(" ")) expect(URDU_REPERTOIRE).toContain(letter);
    for (const mark of "،؛؟۔") expect(URDU_REPERTOIRE).toContain(mark);
    for (const digit of "۰۱۲۳۴۵۶۷۸۹0123456789") expect(URDU_REPERTOIRE).toContain(digit);
    // Zero-width non-joiner: Urdu spelling needs it.
    expect(URDU_REPERTOIRE).toContain("‌");
  });

  test("the Latin repertoire covers ASCII, Latin-1 and the rupee sign", () => {
    const latin = charactersOf(LATIN_RANGES);
    for (const char of "AZaz09 ,.;:'\"()-–—‘’“”…éü£€₨") expect(latin).toContain(char);
    expect(latin).not.toContain("ا");
  });

  test("arabicScriptCharacters finds Urdu letters and ignores everything else", () => {
    expect([...arabicScriptCharacters("Rent کرایہ 45,000 روپے")].sort()).toEqual(
      [...new Set(Array.from("کرایہوپے"))].sort(),
    );
    expect(isArabicScript(0x0627)).toBe(true);
    expect(isArabicScript(0x0041)).toBe(false);
    expect(isArabicScript(0xfdf2)).toBe(true);
  });
});

describe("unicodeRange", () => {
  test("compresses runs and writes single code points alone", () => {
    expect(unicodeRange([0x41, 0x42, 0x43, 0x45, 0x20a8])).toBe("U+41-43, U+45, U+20A8");
    expect(unicodeRange(codePointsOf("cab"))).toBe("U+61-63");
    expect(unicodeRange([])).toBe("");
  });
});

describe("typographyCss", () => {
  const tokens = JSON.parse(
    readFileSync(new URL("../../../design/tokens/maalik.tokens.json", import.meta.url), "utf8"),
  ) as unknown;
  const css = typographyCss(tokens);

  test("writes every Latin and Urdu role of the design tokens, sizes in rem", () => {
    expect(css).toContain("--mm-type-body-size: 1rem;");
    expect(css).toContain("--mm-type-body-line: 1.5;");
    expect(css).toContain("--mm-type-title-small-size: 1rem;");
    expect(css).toContain("--mm-type-label-tracking: 0.0063rem;");
    expect(css).toContain("--mm-type-urdu-body-size: 1.125rem;");
    expect(css).toContain("--mm-type-urdu-body-line: 2;");
    expect(css).toContain("--mm-type-urdu-headline-size: 1.625rem;");
    expect(css.match(/-size:/g)).toHaveLength(16);
  });

  test("rejects tokens without a typography group or with non-px sizes", () => {
    expect(() => typographyCss({})).toThrow(/no typography/);
    expect(() =>
      typographyCss({
        typography: {
          latin: {
            body: {
              $value: {
                fontSize: { value: 1, unit: "rem" },
                fontWeight: 400,
                letterSpacing: { value: 0, unit: "px" },
                lineHeight: 1.5,
              },
            },
          },
          urdu: {},
        },
      }),
    ).toThrow(/px dimension/);
  });
});
