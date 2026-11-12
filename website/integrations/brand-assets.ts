/**
 * Builds the site's brand assets from the design system before Astro builds,
 * serves or type-checks the site:
 *
 * - WOFF2 subsets of the app's own fonts (packages/mm_ui/assets/fonts), with
 *   the @font-face rules that load them (src/generated/fonts.css): the Latin
 *   face, the Urdu face (Noto Sans Arabic, D-19) and its few letters for the
 *   language switch on English pages, and the Nastaliq wordmark, which holds
 *   only the letters of the brand name مالکِ مکان;
 * - the type scale from design/tokens/maalik.tokens.json as CSS custom
 *   properties (src/generated/typography.css). Colours, spacing, radii and
 *   motion come straight from design/tokens/maalik.tokens.css, which the global
 *   stylesheet imports as it is.
 *
 * Everything in src/generated/ is git-ignored and rebuilt only when an input
 * changes, so the design system stays the single source of truth.
 */
import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import type { AstroIntegration } from "astro";
import subsetFont from "subset-font";
import { LOCALE_INFO } from "../src/i18n/locales.ts";
import { SITE } from "../src/config/site.ts";

/** Bump when the generator's output format changes, to invalidate old outputs. */
const GENERATOR_VERSION = "4";

type Range = readonly [number, number];

/**
 * The Latin repertoire of the English pages: Google Fonts' "latin" subset plus
 * the rupee sign and "≈" (the calculators' working). Atkinson Hyperlegible Next covers all
 * of it that it can.
 */
export const LATIN_RANGES: readonly Range[] = [
  [0x20, 0x7e],
  [0xa0, 0xff],
  [0x131, 0x131],
  [0x152, 0x153],
  [0x2c6, 0x2c6],
  [0x2da, 0x2da],
  [0x2dc, 0x2dc],
  [0x2010, 0x2027],
  [0x2030, 0x203a],
  [0x20a8, 0x20a8],
  [0x20ac, 0x20ac],
  [0x2122, 0x2122],
  [0x2190, 0x2193],
  [0x2212, 0x2212],
  [0x2215, 0x2215],
  [0x2248, 0x2248],
];

/**
 * Every character an Urdu text on this site may need, whether or not today's
 * copy uses it: the Urdu alphabet (with the few Arabic letters that appear in
 * loanwords), the common diacritics and honorifics, Urdu punctuation, both
 * digit sets and the neutral punctuation and symbols Urdu borrows (the
 * footer's ©, the · and • between links). The build adds every Arabic-script
 * character it finds in src/, so new copy is never left without a glyph. The
 * Urdu font stack has no Latin face, so a character missing here would be
 * drawn in a system font; the e2e suite checks every character of Urdu text
 * against this subset.
 */
export const URDU_REPERTOIRE = [
  "ءآأؤإئابةتثجحخدذرزسشصضطظعغفقكلمنوهيٹپچڈڑژکگںھہۂۃیۓے",
  "ًٌٍَُِّْٰٕٖٔٗ٘",
  "ؐؑؒؓؔ",
  "،؛؟۔٪٫٬۝ﷲﷺ﷽",
  "۰۱۲۳۴۵۶۷۸۹0123456789",
  "  ‌‍‎‏.,:;!?()[]-–—/%+'\"‘’“”…©·•",
].join("");

/** Unicode blocks of the Arabic script, which Urdu is written in. */
const ARABIC_SCRIPT: readonly Range[] = [
  [0x0600, 0x06ff],
  [0x0750, 0x077f],
  [0x08a0, 0x08ff],
  [0xfb50, 0xfdff],
  [0xfe70, 0xfeff],
];

export function isArabicScript(codePoint: number): boolean {
  return ARABIC_SCRIPT.some(([from, to]) => codePoint >= from && codePoint <= to);
}

/** The distinct Arabic-script characters in `text`. */
export function arabicScriptCharacters(text: string): Set<string> {
  const found = new Set<string>();
  for (const char of text) {
    const codePoint = char.codePointAt(0);
    if (codePoint !== undefined && isArabicScript(codePoint)) found.add(char);
  }
  return found;
}

/** Expands ranges into the characters they cover. */
export function charactersOf(ranges: readonly Range[]): string {
  let text = "";
  for (const [from, to] of ranges) {
    for (let codePoint = from; codePoint <= to; codePoint += 1)
      text += String.fromCodePoint(codePoint);
  }
  return text;
}

/** Sorted, distinct code points of `text`. */
export function codePointsOf(text: string): number[] {
  return [...new Set(Array.from(text, (char) => char.codePointAt(0) ?? 0))].sort((a, b) => a - b);
}

/** A CSS `unicode-range` value covering exactly `codePoints`, e.g. "U+20-7E, U+A0". */
export function unicodeRange(codePoints: readonly number[]): string {
  const sorted = [...new Set(codePoints)].sort((a, b) => a - b);
  const parts: string[] = [];
  let index = 0;
  while (index < sorted.length) {
    const start = sorted[index] ?? 0;
    let end = start;
    while (sorted[index + 1] === end + 1) {
      end += 1;
      index += 1;
    }
    const hex = (value: number) => value.toString(16).toUpperCase();
    parts.push(start === end ? `U+${hex(start)}` : `U+${hex(start)}-${hex(end)}`);
    index += 1;
  }
  return parts.join(", ");
}

interface TypographyValue {
  readonly fontSize: { readonly value: number; readonly unit: string };
  readonly fontWeight: number;
  readonly letterSpacing: { readonly value: number; readonly unit: string };
  readonly lineHeight: number;
}

function kebab(name: string): string {
  return name.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}

function rem(dimension: { value: number; unit: string }, name: string): string {
  if (dimension.unit !== "px")
    throw new Error(`${name}: expected a px dimension, got ${dimension.unit}`);
  return `${Number((dimension.value / 16).toFixed(4))}rem`;
}

/**
 * The type scale of design/tokens/maalik.tokens.json as CSS custom properties:
 * `--mm-type-<role>-size|line|weight|tracking` for Latin roles and
 * `--mm-type-urdu-<role>-…` for Urdu roles, sizes in rem so text scales with
 * the reader's settings.
 */
export function typographyCss(tokens: unknown): string {
  const typography = (tokens as { typography?: Record<string, unknown> }).typography;
  if (typography === undefined) throw new Error("The tokens file has no typography group");
  const lines: string[] = [];
  for (const [script, prefix] of [
    ["latin", ""],
    ["urdu", "urdu-"],
  ] as const) {
    const roles = typography[script] as Record<string, { $value: TypographyValue }> | undefined;
    if (roles === undefined) throw new Error(`The tokens file has no typography.${script} group`);
    for (const [role, { $value: value }] of Object.entries(roles)) {
      const name = `--mm-type-${prefix}${kebab(role)}`;
      lines.push(
        `  ${name}-size: ${rem(value.fontSize, name)};`,
        `  ${name}-line: ${value.lineHeight};`,
        `  ${name}-weight: ${value.fontWeight};`,
        `  ${name}-tracking: ${rem(value.letterSpacing, name)};`,
      );
    }
  }
  return `${HEADER}:root {\n${lines.join("\n")}\n}\n`;
}

const HEADER =
  "/* GENERATED by integrations/brand-assets.ts from the design system. Do not edit. */\n\n";

/** What a font subset is for; the e2e suite checks each text against its role's subset. */
export type FontRole = "latin" | "urdu" | "urduLabel" | "urduWordmark";

export interface FontJob {
  /** Output file name in src/generated/fonts/. */
  readonly file: string;
  readonly family: string;
  readonly role: FontRole;
  readonly source: string;
  readonly text: string;
  /** The weight range kept from the variable font, or one weight to pin it to. */
  readonly weight: { readonly min: number; readonly max: number } | number;
  /**
   * A line height, as a multiple of the font size, on which the text's
   * baseline should sit where the app puts it (see appBaselineOverrides).
   */
  readonly appLine?: number;
}

/** Where each table of a TrueType font starts, by tag. */
function tableOffsets(font: Uint8Array): Map<string, number> {
  const view = new DataView(font.buffer, font.byteOffset, font.byteLength);
  const tables = new Map<string, number>();
  for (let index = 0; index < view.getUint16(4); index += 1) {
    const record = 12 + 16 * index;
    const tag = String.fromCharCode(...font.subarray(record, record + 4));
    tables.set(tag, view.getUint32(record + 8));
  }
  return tables;
}

/**
 * The code points a font has glyphs for, from the Unicode subtables of its cmap
 * (formats 4 and 12, the ones the app's fonts use).
 */
export function glyphCodePoints(font: Uint8Array): Set<number> {
  const view = new DataView(font.buffer, font.byteOffset, font.byteLength);
  const cmap = tableOffsets(font).get("cmap");
  if (cmap === undefined) throw new Error("The font has no cmap");
  const found = new Set<number>();
  for (let index = 0; index < view.getUint16(cmap + 2); index += 1) {
    const record = cmap + 4 + 8 * index;
    const platform = view.getUint16(record);
    const encoding = view.getUint16(record + 2);
    if (platform !== 0 && !(platform === 3 && (encoding === 1 || encoding === 10))) continue;
    const table = cmap + view.getUint32(record + 4);
    const format = view.getUint16(table);
    if (format === 4) {
      const segments = view.getUint16(table + 6) / 2;
      const ends = table + 14;
      const starts = ends + 2 * segments + 2;
      const deltas = starts + 2 * segments;
      const rangeOffsets = deltas + 2 * segments;
      for (let segment = 0; segment < segments; segment += 1) {
        const start = view.getUint16(starts + 2 * segment);
        const end = view.getUint16(ends + 2 * segment);
        const delta = view.getUint16(deltas + 2 * segment);
        const at = rangeOffsets + 2 * segment;
        const rangeOffset = view.getUint16(at);
        for (let code = start; code <= end && code !== 0xffff; code += 1) {
          let glyph = (code + delta) & 0xffff;
          if (rangeOffset !== 0) {
            const indexed = view.getUint16(at + rangeOffset + 2 * (code - start));
            glyph = indexed === 0 ? 0 : (indexed + delta) & 0xffff;
          }
          if (glyph !== 0) found.add(code);
        }
      }
    } else if (format === 12) {
      for (let group = 0; group < view.getUint32(table + 12); group += 1) {
        const at = table + 16 + 12 * group;
        const start = view.getUint32(at);
        const startGlyph = view.getUint32(at + 8);
        for (let code = start; code <= view.getUint32(at + 4); code += 1) {
          if (startGlyph + code - start !== 0) found.add(code);
        }
      }
    }
  }
  return found;
}

/** The characters of `text` that `font` has no glyph for, other than spaces and format controls. */
export function missingGlyphs(font: Uint8Array, text: string): string[] {
  const glyphs = glyphCodePoints(font);
  return [...new Set(Array.from(text))].filter(
    (char) => !/[\s\p{Cf}]/u.test(char) && !glyphs.has(char.codePointAt(0) ?? 0),
  );
}

/** A font's ascent and descent (both positive), in em, from its hhea table. */
export function verticalMetrics(font: Uint8Array): { ascent: number; descent: number } {
  const view = new DataView(font.buffer, font.byteOffset, font.byteLength);
  const tables = tableOffsets(font);
  const head = tables.get("head");
  const hhea = tables.get("hhea");
  if (head === undefined || hhea === undefined) throw new Error("The font has no head or hhea");
  const unitsPerEm = view.getUint16(head + 18);
  return {
    ascent: view.getInt16(hhea + 4) / unitsPerEm,
    descent: -view.getInt16(hhea + 6) / unitsPerEm,
  };
}

/**
 * @font-face ascent and descent overrides that put the baseline where the app
 * puts it on a line `line` times the font size. Flutter shares out a line's
 * extra or missing height in proportion to the font's ascent and descent; CSS
 * shares it out evenly, which sets the Urdu faces, whose ascent is far larger
 * than their descent, about 0.1 em lower than in the app: Urdu words sat up
 * to 2.25 px below the middle of a button or a link. The overrides keep the
 * font's total height, so a "normal" line is unchanged, and move only where
 * the baseline falls in a line box.
 */
export function appBaselineOverrides(
  metrics: { ascent: number; descent: number },
  line: number,
): { ascent: string; descent: string } {
  const height = metrics.ascent + metrics.descent;
  // The app's baseline lies this far below the middle of the line, in em.
  const below = line * (metrics.ascent / height - 0.5);
  const percent = (value: number) => `${Number((value * 100).toFixed(1))}%`;
  return { ascent: percent(height / 2 + below), descent: percent(height / 2 - below) };
}

export function fontFaceCss(job: FontJob, font: Uint8Array): string {
  const weight =
    typeof job.weight === "number" ? `${job.weight}` : `${job.weight.min} ${job.weight.max}`;
  const overrides =
    job.appLine === undefined
      ? undefined
      : appBaselineOverrides(verticalMetrics(font), job.appLine);
  return [
    "@font-face {",
    `  font-family: "${job.family}";`,
    `  src: url("./fonts/${job.file}") format("woff2");`,
    `  font-weight: ${weight};`,
    "  font-style: normal;",
    "  font-display: swap;",
    ...(overrides === undefined
      ? []
      : [`  ascent-override: ${overrides.ascent};`, `  descent-override: ${overrides.descent};`]),
    `  unicode-range: ${unicodeRange(codePointsOf(job.text))};`,
    "}",
  ].join("\n");
}

const SCANNED_EXTENSIONS = new Set([".astro", ".ts", ".yaml", ".yml", ".md", ".mdx", ".json"]);

async function scanSourceText(directory: string, skip: string): Promise<string> {
  let text = "";
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (path === skip) continue;
    if (entry.isDirectory()) text += await scanSourceText(path, skip);
    else if (SCANNED_EXTENSIONS.has(entry.name.slice(entry.name.lastIndexOf(".")))) {
      text += await readFile(path, "utf8");
    }
  }
  return text;
}

/**
 * The family of the few Urdu words on English pages, the language switch's
 * "اردو" (see .ur-label in src/styles/global.css): a few letters of the Urdu
 * face, so an English page need not load the whole of it.
 */
export const LABEL_FAMILY = "MM Urdu Label";

/** The app's font files in packages/mm_ui/assets/fonts, by family. */
export const FONT_FILES: Readonly<Record<string, string>> = {
  "Atkinson Hyperlegible Next": "AtkinsonHyperlegibleNext-Variable.ttf",
  "Noto Sans Arabic": "NotoSansArabic-Variable.ttf",
  "Noto Nastaliq Urdu": "NotoNastaliqUrdu-Wordmark.ttf",
};

interface FontTokens {
  readonly font?: { readonly family?: Record<string, { readonly $value?: readonly string[] }> };
  readonly typography?: {
    readonly urdu?: Record<
      string,
      { readonly $value?: { readonly fontWeight?: number; readonly lineHeight?: number } }
    >;
  };
}

/**
 * The face the site serves for a font.family token: the token's first family,
 * which must be one of the app's fonts. A token naming a font the site does
 * not have fails the build, rather than leaving text in a fallback face.
 */
export function servedFamily(
  tokens: unknown,
  name: "latin" | "urdu" | "urduWordmark",
): { readonly family: string; readonly source: string } {
  const family = (tokens as FontTokens).font?.family?.[name]?.$value?.[0];
  if (family === undefined) throw new Error(`The tokens file has no font.family.${name}`);
  const source = FONT_FILES[family];
  if (source === undefined) {
    throw new Error(`font.family.${name} names "${family}", which the site does not serve`);
  }
  return { family, source };
}

function urduRole(tokens: unknown, role: string): { fontWeight: number; lineHeight: number } {
  const value = (tokens as FontTokens).typography?.urdu?.[role]?.$value;
  if (value?.fontWeight === undefined || value.lineHeight === undefined) {
    throw new Error(`The tokens file has no typography.urdu.${role}`);
  }
  return { fontWeight: value.fontWeight, lineHeight: value.lineHeight };
}

/** The weight of an Urdu type role, e.g. the wordmark's. */
export function urduWeight(tokens: unknown, role: string): number {
  return urduRole(tokens, role).fontWeight;
}

/** The line height of an Urdu type role, as a multiple of its size. */
export function urduLine(tokens: unknown, role: string): number {
  return urduRole(tokens, role).lineHeight;
}

export async function generateBrandAssets(
  root: URL,
  log: (message: string) => void,
): Promise<void> {
  const repo = new URL("../", root);
  const fontsDir = fileURLToPath(new URL("packages/mm_ui/assets/fonts/", repo));
  const tokensPath = fileURLToPath(new URL("design/tokens/maalik.tokens.json", repo));
  const srcDir = fileURLToPath(new URL("src/", root));
  const outDir = fileURLToPath(new URL("src/generated/", root));

  const tokens = await readFile(tokensPath);
  const tokenValues = JSON.parse(tokens.toString("utf8")) as unknown;
  const latin = servedFamily(tokenValues, "latin");
  const urdu = servedFamily(tokenValues, "urdu");
  const wordmark = servedFamily(tokenValues, "urduWordmark");

  const sourceText = await scanSourceText(srcDir, outDir.replace(/\/$/, ""));
  const urduText = [
    ...new Set([...Array.from(URDU_REPERTOIRE), ...arabicScriptCharacters(sourceText)]),
  ].join("");
  const distinct = (text: string) => [...new Set(Array.from(text))].join("");

  const jobs: FontJob[] = [
    {
      file: "atkinson-hyperlegible-next-latin.woff2",
      family: latin.family,
      role: "latin",
      source: latin.source,
      text: charactersOf(LATIN_RANGES),
      weight: { min: 400, max: 700 },
    },
    {
      // Urdu text: the weights the Urdu roles use. The app's copy of the face is at its normal
      // width already (tool/design/build_fonts.py).
      file: "noto-sans-arabic.woff2",
      family: urdu.family,
      role: "urdu",
      source: urdu.source,
      text: urduText,
      weight: { min: 400, max: 700 },
      appLine: urduLine(tokenValues, "body"),
    },
    {
      // The language switch's "اردو" on English pages, in the label role's weight. With the
      // space: a browser takes an element's line metrics from the first face whose range has
      // U+0020, and without it would fetch the whole Urdu face for them.
      file: "noto-sans-arabic-label.woff2",
      family: LABEL_FAMILY,
      role: "urduLabel",
      source: urdu.source,
      text: distinct(`${LOCALE_INFO.ur.endonym} `),
      weight: urduWeight(tokenValues, "label"),
      appLine: urduLine(tokenValues, "body"),
    },
    {
      // The brand name where it stands as the wordmark, and nothing else (D-19).
      file: "noto-nastaliq-urdu-wordmark.woff2",
      family: wordmark.family,
      role: "urduWordmark",
      source: wordmark.source,
      text: distinct(SITE.nameUrdu),
      weight: urduWeight(tokenValues, "wordmark"),
      appLine: urduLine(tokenValues, "wordmark"),
    },
  ];

  const hash = createHash("sha256").update(GENERATOR_VERSION).update(tokens);
  for (const job of jobs) {
    hash.update(JSON.stringify({ ...job, text: codePointsOf(job.text) }));
    hash.update(await readFile(join(fontsDir, job.source)));
  }
  const inputsHash = hash.digest("hex");
  const hashFile = join(outDir, ".inputs-hash");
  const previous = await readFile(hashFile, "utf8").catch(() => "");
  if (previous === inputsHash) return;

  const started = Date.now();
  await rm(outDir, { recursive: true, force: true });
  await mkdir(join(outDir, "fonts"), { recursive: true });
  const faces: string[] = [];
  const manifest: Record<string, { family: string; role: FontRole; unicodeRange: string }> = {};
  for (const job of jobs) {
    const font = await readFile(join(fontsDir, job.source));
    // An Urdu face must draw every character it is asked for: its unicode-range claims them
    // all, and the Urdu font stack has no other face, so a missing glyph would fall to a system
    // font. Atkinson lacks a few characters of the Latin ranges (the arrows, the rupee sign),
    // which no page uses; the Latin stack leaves those to the system's fonts.
    if (job.role !== "latin") {
      const missing = missingGlyphs(font, job.text);
      if (missing.length > 0) {
        throw new Error(`${job.source} has no glyph for ${missing.join(" ")} (${job.file})`);
      }
    }
    const subset = await subsetFont(font, job.text, {
      targetFormat: "woff2",
      variationAxes: { wght: job.weight },
      // Keep the copyright, licence description and licence URL records (OFL 1.1).
      preserveNameIds: [0, 1, 2, 3, 4, 5, 6, 13, 14],
    });
    await writeFile(join(outDir, "fonts", job.file), subset);
    faces.push(fontFaceCss(job, font));
    manifest[job.file] = {
      family: job.family,
      role: job.role,
      unicodeRange: unicodeRange(codePointsOf(job.text)),
    };
  }
  await writeFile(join(outDir, "fonts.css"), `${HEADER}${faces.join("\n\n")}\n`);
  await writeFile(join(outDir, "fonts.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  await writeFile(join(outDir, "typography.css"), typographyCss(tokenValues));
  await writeFile(hashFile, inputsHash);
  log(`generated ${relative(fileURLToPath(root), outDir)} in ${Date.now() - started} ms`);
}

export function brandAssets(): AstroIntegration {
  return {
    name: "maalik-brand-assets",
    hooks: {
      "astro:config:setup": async ({ config, addWatchFile, logger }) => {
        const repo = new URL("../", config.root);
        addWatchFile(new URL("design/tokens/maalik.tokens.json", repo));
        await generateBrandAssets(config.root, (message) => {
          logger.info(message);
        });
      },
    },
  };
}
