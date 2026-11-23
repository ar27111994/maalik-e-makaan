/**
 * The site's mark, "twin gables", chosen by the owner on 23 November 2026: a
 * filled white house on a 32 × 32 cobalt tile. Two steep gables make the
 * roofline a capital M, the eaves reach 2 units past the walls, and two arched
 * doorways cut the walls into a small m: Maalik-e-Makaan's two Ms.
 *
 * One definition feeds the header (src/components/BrandMark.astro), the icon
 * files that scripts/generate-og.ts writes to public/, and the app's launcher
 * icons, which tool/design/build_app_icons.py (`make app-icons`) reads from
 * this file and checks against every platform's safe zone. Keep these
 * constants plain literals, and the glyph one filled outline: straight lines
 * and circular arcs (M, L, H, V, A and Z commands) that never cross, drawn
 * with a fill and no stroke. Every level and upright edge sits on an even
 * unit, so it lands on whole pixels at 16, 32, 48 and 64 px.
 */
export const MARK_VIEWBOX = "0 0 32 32";
export const MARK_TILE_RADIUS = 8;
export const MARK_GLYPH_PATH =
  "M6 24V18H4L12 6L16 12L20 6L28 18H26V24H22V16.5A2 2 0 0 0 18 16.5V24H14V16.5A2 2 0 0 0 10 16.5V24Z";

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
    `<path d="${MARK_GLYPH_PATH}" fill="${glyph}"/>`,
    "</svg>",
  ].join("");
}
