/**
 * The font licences this site must ship with its fonts (SIL Open Font
 * License 1.1). The texts are served from packages/mm_ui/assets/fonts, where
 * the app's copies of the fonts live, by src/pages/licences/[licence].txt.ts.
 */
export const FONT_LICENCES = [
  {
    slug: "ofl-atkinson-hyperlegible-next",
    family: "Atkinson Hyperlegible Next",
    sourceFile: "OFL-AtkinsonHyperlegibleNext.txt",
  },
  {
    slug: "ofl-noto-sans-arabic",
    family: "Noto Sans Arabic",
    sourceFile: "OFL-NotoSansArabic.txt",
  },
  {
    slug: "ofl-noto-nastaliq-urdu",
    family: "Noto Nastaliq Urdu",
    sourceFile: "OFL-NotoNastaliqUrdu.txt",
  },
] as const;

export type FontLicence = (typeof FONT_LICENCES)[number];

/** The URL path of a licence text, e.g. "/licences/ofl-noto-sans-arabic.txt". */
export function fontLicencePath(slug: string): string {
  return `/licences/${slug}.txt`;
}

export function fontLicence(slug: string): FontLicence {
  const found = FONT_LICENCES.find((font) => font.slug === slug);
  if (found === undefined) throw new Error(`Unknown font licence: ${slug}`);
  return found;
}

/** The copyright line at the top of a licence text, e.g. "Copyright 2022 The Noto Project Authors (…)". */
export function copyrightLine(licenceText: string): string {
  const line = licenceText.split("\n").find((candidate) => candidate.startsWith("Copyright "));
  if (line === undefined) throw new Error("The licence text has no copyright line");
  return line.trim();
}
