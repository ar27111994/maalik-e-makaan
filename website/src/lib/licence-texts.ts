/**
 * The licence texts of the self-hosted fonts, read from the app's copies in
 * packages/mm_ui/assets/fonts at build time (never copied by hand).
 */
import atkinson from "../../../packages/mm_ui/assets/fonts/OFL-AtkinsonHyperlegibleNext.txt?raw";
import nastaliq from "../../../packages/mm_ui/assets/fonts/OFL-NotoNastaliqUrdu.txt?raw";
import { FONT_LICENCES } from "./licences.ts";

const TEXTS: Readonly<Record<string, string>> = {
  "OFL-AtkinsonHyperlegibleNext.txt": atkinson,
  "OFL-NotoNastaliqUrdu.txt": nastaliq,
};

/** The full licence text for the font licence `slug`. */
export function licenceText(slug: string): string {
  const font = FONT_LICENCES.find((candidate) => candidate.slug === slug);
  const text = font === undefined ? undefined : TEXTS[font.sourceFile];
  if (text === undefined) throw new Error(`No licence text for ${slug}`);
  return text;
}
