import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import {
  appBaselineOverrides,
  arabicScriptCharacters,
  charactersOf,
  codePointsOf,
  fontFaceCss,
  isArabicScript,
  LATIN_RANGES,
  servedFamily,
  typographyCss,
  unicodeRange,
  URDU_REPERTOIRE,
  urduLine,
  urduWeight,
  verticalMetrics,
} from "../../integrations/brand-assets.ts";

const tokens = JSON.parse(
  readFileSync(new URL("../../../design/tokens/maalik.tokens.json", import.meta.url), "utf8"),
) as unknown;
const font = (file: string) =>
  readFileSync(new URL(`../../../packages/mm_ui/assets/fonts/${file}`, import.meta.url));

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
  const css = typographyCss(tokens);

  test("writes every Latin and Urdu role of the design tokens, sizes in rem", () => {
    expect(css).toContain("--mm-type-body-size: 1rem;");
    expect(css).toContain("--mm-type-body-line: 1.5;");
    expect(css).toContain("--mm-type-title-small-size: 1rem;");
    expect(css).toContain("--mm-type-label-tracking: 0.0063rem;");
    expect(css).toContain("--mm-type-urdu-body-size: 1.0625rem;");
    expect(css).toContain("--mm-type-urdu-body-line: 1.6470588235294117;");
    expect(css).toContain("--mm-type-urdu-headline-size: 1.5625rem;");
    expect(css).toContain("--mm-type-urdu-wordmark-line: 2;");
    expect(css.match(/-size:/g)).toHaveLength(17);
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

describe("the faces the site serves", () => {
  test("follow the tokens: Noto Sans Arabic for Urdu text, Nastaliq only for the wordmark", () => {
    expect(servedFamily(tokens, "latin")).toEqual({
      family: "Atkinson Hyperlegible Next",
      source: "AtkinsonHyperlegibleNext-Variable.ttf",
    });
    expect(servedFamily(tokens, "urdu")).toEqual({
      family: "Noto Sans Arabic",
      source: "NotoSansArabic-Variable.ttf",
    });
    expect(servedFamily(tokens, "urduWordmark")).toEqual({
      family: "Noto Nastaliq Urdu",
      source: "NotoNastaliqUrdu-Variable.ttf",
    });
    expect(urduWeight(tokens, "label")).toBe(600);
    expect(urduWeight(tokens, "wordmark")).toBe(600);
    expect(urduLine(tokens, "wordmark")).toBe(2);
  });

  test("a token naming a font the site does not have fails the build", () => {
    const other = { font: { family: { urdu: { $value: ["Gulzar", "serif"] } } } };
    expect(() => servedFamily(other, "urdu")).toThrow(/"Gulzar", which the site does not serve/);
    expect(() => servedFamily({}, "urdu")).toThrow(/no font.family.urdu/);
    expect(() => urduWeight({}, "label")).toThrow(/no typography.urdu.label/);
  });
});

describe("the app's baseline", () => {
  test("reads the fonts' ascent and descent from their hhea tables", () => {
    expect(verticalMetrics(font("NotoSansArabic-Variable.ttf"))).toEqual({
      ascent: 1.374,
      descent: 0.738,
    });
    expect(verticalMetrics(font("NotoNastaliqUrdu-Variable.ttf"))).toEqual({
      ascent: 1.904,
      descent: 0.596,
    });
    expect(() => verticalMetrics(new Uint8Array(12))).toThrow(/no head or hhea/);
  });

  test("keeps the font's height and moves the baseline to where the app puts it", () => {
    // Flutter: a 28 px line for 17 px text puts the baseline 28 × 1.374 / 2.112 = 18.22 px down;
    // CSS with 130.4 % and 80.8 % puts it 14 + (1.304 - 0.808) / 2 × 17 = 18.22 px down too.
    const sans = appBaselineOverrides({ ascent: 1.374, descent: 0.738 }, 28 / 17);
    expect(sans).toEqual({ ascent: "130.4%", descent: "80.8%" });
    const nastaliq = appBaselineOverrides({ ascent: 1.904, descent: 0.596 }, 2);
    expect(nastaliq).toEqual({ ascent: "177.3%", descent: "72.7%" });
    // A font as tall above its baseline as below needs no move.
    expect(appBaselineOverrides({ ascent: 1, descent: 1 }, 1.5)).toEqual({
      ascent: "100%",
      descent: "100%",
    });
  });

  test("writes the overrides into the @font-face rule of a face that asks for them", () => {
    const job = {
      file: "noto-sans-arabic.woff2",
      family: "Noto Sans Arabic",
      role: "urdu" as const,
      source: "NotoSansArabic-Variable.ttf",
      text: "اردو",
      weight: { min: 400, max: 700 },
    };
    const sans = font("NotoSansArabic-Variable.ttf");
    const plain = fontFaceCss(job, sans);
    expect(plain).toContain("font-weight: 400 700;");
    expect(plain).toContain("unicode-range: U+627, U+62F, U+631, U+648;");
    expect(plain).not.toContain("override");
    const moved = fontFaceCss({ ...job, weight: 600, appLine: 28 / 17 }, sans);
    expect(moved).toContain("font-weight: 600;");
    expect(moved).toContain("ascent-override: 130.4%;");
    expect(moved).toContain("descent-override: 80.8%;");
  });
});
