// The committed icons and Open Graph images (written by `npm run og`).
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { markSvg, MARK_HOUSE_PATH } from "../../src/lib/brand.ts";
import { ogImage } from "../../src/lib/seo/meta.ts";

const file = (path: string) => readFileSync(new URL(`../../public/${path}`, import.meta.url));

/** Width and height from a PNG's IHDR chunk. */
function pngSize(png: Buffer): { width: number; height: number } {
  expect(png.subarray(0, 8).toString("hex")).toBe("89504e470d0a1a0a");
  expect(png.subarray(12, 16).toString("ascii")).toBe("IHDR");
  return { width: png.readUInt32BE(16), height: png.readUInt32BE(20) };
}

describe("Open Graph images", () => {
  test.each(["en", "ur"] as const)("the %s card is a 1200 × 630 PNG under 100 KiB", (locale) => {
    const image = ogImage(locale);
    const png = file(image.path.slice(1));
    expect(pngSize(png)).toEqual({ width: image.width, height: image.height });
    expect(png.length).toBeLessThan(100 * 1024);
  });
});

describe("icons", () => {
  test("favicon.ico holds one 32 × 32 PNG", () => {
    const ico = file("favicon.ico");
    expect(ico.readUInt16LE(2)).toBe(1); // icon
    expect(ico.readUInt16LE(4)).toBe(1); // one image
    expect(pngSize(ico.subarray(ico.readUInt32LE(18)))).toEqual({ width: 32, height: 32 });
  });

  test("the touch icon and the logo have the sizes the pages declare", () => {
    expect(pngSize(file("apple-touch-icon.png"))).toEqual({ width: 180, height: 180 });
    expect(pngSize(file("icon-512.png"))).toEqual({ width: 512, height: 512 });
  });

  test("favicon.svg is the mark, drawn from the shared definition", () => {
    const svg = file("favicon.svg").toString("utf8");
    expect(svg).toContain(MARK_HOUSE_PATH);
    expect(svg.trim()).toBe(markSvg({ tile: "#1D3F8F", glyph: "#FFFFFF" }));
  });
});
