/**
 * The site's mark: a house drawn on a 32 × 32 tile. One definition feeds the
 * header (src/components/BrandMark.astro) and the icon files that
 * scripts/generate-og.ts writes to public/.
 */
export const MARK_VIEWBOX = "0 0 32 32";
export const MARK_TILE_RADIUS = 8;
export const MARK_HOUSE_PATH = "M8 15.5 16 8.5l8 7M10.5 13.5V24h11V13.5M14 24v-5h4v5";

/** A standalone SVG of the mark, for favicons and app icons. */
export function markSvg({
  tile,
  glyph,
  size = 32,
}: {
  tile: string;
  glyph: string;
  size?: number;
}): string {
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${MARK_VIEWBOX}" width="${size}" height="${size}">`,
    `<rect width="32" height="32" rx="${MARK_TILE_RADIUS}" fill="${tile}"/>`,
    `<path d="${MARK_HOUSE_PATH}" fill="none" stroke="${glyph}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`,
    "</svg>",
  ].join("");
}
