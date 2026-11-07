/**
 * Builds the site's brand assets from the design system before Astro builds,
 * serves or type-checks the site:
 *
 * - WOFF2 subsets of the app's own fonts (packages/mm_ui/assets/fonts), with
 *   the @font-face rules that load them (src/generated/fonts.css);
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
const GENERATOR_VERSION = "3";

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
 * digit sets and the neutral punctuation Urdu borrows. The build adds every
 * Arabic-script character it finds in src/, so new copy is never left without
 * a glyph.
 */
export const URDU_REPERTOIRE = [
  "ءآأؤإئابةتثجحخدذرزسشصضطظعغفقكلمنوهيٹپچڈڑژکگںھہۂۃیۓے",
  "ًٌٍَُِّْٰٕٖٔٗ٘",
  "ؐؑؒؓؔ",
  "،؛؟۔٪٫٬۝ﷲﷺ﷽",
  "۰۱۲۳۴۵۶۷۸۹0123456789",
  "  ‌‍‎‏.,:;!?()[]-–—/%+'\"‘’“”…",
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

interface FontJob {
  /** Output file name in src/generated/fonts/. */
  readonly file: string;
  readonly family: string;
  readonly source: string;
  readonly text: string;
  /** The weight range kept from the variable font, or one weight to pin it to. */
  readonly weight: { readonly min: number; readonly max: number } | number;
}

function fontFaceCss(job: FontJob): string {
  const weight =
    typeof job.weight === "number" ? `${job.weight}` : `${job.weight.min} ${job.weight.max}`;
  return [
    "@font-face {",
    `  font-family: "${job.family}";`,
    `  src: url("./fonts/${job.file}") format("woff2");`,
    `  font-weight: ${weight};`,
    "  font-style: normal;",
    "  font-display: swap;",
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

/** The family used for the few Urdu words on English pages (see src/styles/global.css). */
export const LABEL_FAMILY = "MM Nastaliq Label";

export async function generateBrandAssets(
  root: URL,
  log: (message: string) => void,
): Promise<void> {
  const repo = new URL("../", root);
  const fontsDir = fileURLToPath(new URL("packages/mm_ui/assets/fonts/", repo));
  const tokensPath = fileURLToPath(new URL("design/tokens/maalik.tokens.json", repo));
  const srcDir = fileURLToPath(new URL("src/", root));
  const outDir = fileURLToPath(new URL("src/generated/", root));

  const sourceText = await scanSourceText(srcDir, outDir.replace(/\/$/, ""));
  const urduText = [
    ...new Set([...Array.from(URDU_REPERTOIRE), ...arabicScriptCharacters(sourceText)]),
  ].join("");
  const labelText = [...new Set(Array.from(`${LOCALE_INFO.ur.endonym} ${SITE.nameUrdu}`))].join("");

  const jobs: FontJob[] = [
    {
      file: "atkinson-hyperlegible-next-latin.woff2",
      family: "Atkinson Hyperlegible Next",
      source: "AtkinsonHyperlegibleNext-Variable.ttf",
      text: charactersOf(LATIN_RANGES),
      weight: { min: 400, max: 700 },
    },
    {
      file: "noto-nastaliq-urdu.woff2",
      family: "Noto Nastaliq Urdu",
      source: "NotoNastaliqUrdu-Variable.ttf",
      text: urduText,
      weight: { min: 400, max: 700 },
    },
    {
      file: "noto-nastaliq-urdu-label.woff2",
      family: LABEL_FAMILY,
      source: "NotoNastaliqUrdu-Variable.ttf",
      text: labelText,
      weight: 400,
    },
  ];

  const tokens = await readFile(tokensPath);
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
  const manifest: Record<string, { family: string; unicodeRange: string }> = {};
  for (const job of jobs) {
    const font = await readFile(join(fontsDir, job.source));
    const subset = await subsetFont(font, job.text, {
      targetFormat: "woff2",
      variationAxes: { wght: job.weight },
      // Keep the copyright, licence description and licence URL records (OFL 1.1).
      preserveNameIds: [0, 1, 2, 3, 4, 5, 6, 13, 14],
    });
    await writeFile(join(outDir, "fonts", job.file), subset);
    faces.push(fontFaceCss(job));
    manifest[job.file] = { family: job.family, unicodeRange: unicodeRange(codePointsOf(job.text)) };
  }
  await writeFile(join(outDir, "fonts.css"), `${HEADER}${faces.join("\n\n")}\n`);
  await writeFile(join(outDir, "fonts.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  await writeFile(
    join(outDir, "typography.css"),
    typographyCss(JSON.parse(tokens.toString("utf8"))),
  );
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
