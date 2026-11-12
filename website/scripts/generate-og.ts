/**
 * Writes the site's Open Graph images and icons to public/, from the design
 * tokens, the self-hosted fonts and the home page copy:
 *
 *   public/og/en.png, public/og/ur.png   1200 × 630 social cards
 *   public/favicon.svg, public/favicon.ico (32 × 32), public/apple-touch-icon.png (180 × 180),
 *   public/icon-512.png (the Organization logo in the structured data)
 *
 * The cards are drawn by Chromium (Playwright), with the site's own font
 * subsets and @font-face rules (src/generated/fonts.css): Urdu text in Noto
 * Sans Arabic and the brand name مالکِ مکان in the Nastaliq wordmark (D-19).
 * They are then compressed with sharp. The outputs are committed, so the build
 * needs neither; run this again after changing the copy, the tokens, the fonts
 * or the mark:
 *
 *   npm run build   # generates the font subsets in src/generated/
 *   npm run og
 */
import { readFileSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { chromium } from "@playwright/test";
import sharp from "sharp";
import { parse } from "yaml";
import { SITE } from "../src/config/site.ts";
import { LOCALE_INFO, LOCALES, type Locale } from "../src/i18n/locales.ts";
import { markSvg } from "../src/lib/brand.ts";
import { formatMoney, Money } from "../src/lib/money/index.ts";

const root = new URL("../", import.meta.url);
const repo = new URL("../", root);
const publicDir = new URL("public/", root);

interface Tokens {
  color: Record<string, Record<string, { $value: { hex: string } }>>;
}
const tokens = JSON.parse(
  readFileSync(new URL("design/tokens/maalik.tokens.json", repo), "utf8"),
) as Tokens;
const light = (role: string): string => {
  const value = tokens.color.light?.[role]?.$value.hex;
  if (value === undefined) throw new Error(`No light colour token "${role}"`);
  return value;
};

interface HomeCopy {
  hero: { heading: string };
  receipt: {
    title: string;
    numberLabel: string;
    number: string;
    payerLabel: string;
    payer: string;
    lineLabel: string;
    amountRupees: number;
    status: string;
  };
}

/** The site's @font-face rules, with each font file inlined as a data URL. */
function fontFacesCss(): string {
  const css = readFileSync(new URL("src/generated/fonts.css", root), "utf8");
  return css.replace(/url\("\.\/fonts\/([\w.-]+)"\)/g, (_, file: string) => {
    const data = readFileSync(new URL(`src/generated/fonts/${file}`, root));
    return `url(data:font/woff2;base64,${data.toString("base64")})`;
  });
}

interface UrduRole {
  $value: { fontWeight: number; lineHeight: number };
}
const urdu = (
  JSON.parse(readFileSync(new URL("design/tokens/maalik.tokens.json", repo), "utf8")) as {
    typography: { urdu: Record<string, UrduRole> };
  }
).typography.urdu;
const urduType = (role: string): UrduRole["$value"] => {
  const value = urdu[role]?.$value;
  if (value === undefined) throw new Error(`No Urdu type role "${role}"`);
  return value;
};
const urduLine = (role: string): number => urduType(role).lineHeight;

function escapeHtml(text: string): string {
  return text.replace(/[&<>"]/g, (char) => `&#${char.charCodeAt(0)};`);
}

function cardHtml(locale: Locale): string {
  const home = parse(
    readFileSync(new URL(`src/content/home/${locale}.yaml`, root), "utf8"),
  ) as HomeCopy;
  const info = LOCALE_INFO[locale];
  const tokensCss = readFileSync(new URL("design/tokens/maalik.tokens.css", repo), "utf8");
  const amount = formatMoney(Money.fromRupees(home.receipt.amountRupees), {
    language: locale === "en" ? "english" : "urdu",
  });
  const primaryName = locale === "en" ? SITE.name : SITE.nameUrdu;
  const secondaryName = locale === "en" ? SITE.nameUrdu : SITE.name;
  const secondaryLang = locale === "en" ? "ur" : "en";
  // The Urdu name is the wordmark, in Nastaliq, wherever it stands as the brand.
  const primaryClass = locale === "ur" ? "brand-name wordmark" : "brand-name";
  const secondaryClass = locale === "en" ? "brand-secondary wordmark" : "brand-secondary";
  const mark = markSvg({ tile: light("primary"), glyph: light("onPrimary"), size: 72 });
  const r = home.receipt;
  return `<!doctype html>
<html lang="${info.htmlLang}" dir="${info.dir}" data-theme="light">
<head><meta charset="utf-8"><style>
${tokensCss}
${fontFacesCss()}
* { box-sizing: border-box; margin: 0; }
html, body { width: 1200px; height: 630px; }
body { background: var(--mm-color-bg); color: var(--mm-color-ink); font-family: var(--mm-font-latin);
  display: grid; grid-template-columns: 1fr 400px; gap: 56px; padding: 72px 80px; align-items: center;
  border-block-end: 12px solid var(--mm-color-primary); }
/* Each language keeps its own script's face; the page's own language sets the body's. */
html[lang="ur"] body, [lang="ur"] { font-family: var(--mm-font-urdu); }
[lang|="en"] { font-family: var(--mm-font-latin); }
.brand { display: flex; align-items: center; gap: 20px; margin-block-end: 40px; }
.brand-name { font-size: 40px; font-weight: 700; }
.brand-secondary { font-size: 30px; color: var(--mm-color-ink-muted); }
html[lang="ur"] .brand-name { font-size: 44px; }
/* After the brand's own rules: the wordmark's weight is the one weight its subset holds. */
.wordmark { font-family: var(--mm-font-urdu-wordmark); font-weight: ${urduType("wordmark").fontWeight}; line-height: ${urduLine("wordmark")}; }
h1 { font-size: 60px; line-height: 1.12; font-weight: 700; }
html[lang="ur"] h1 { font-size: 56px; line-height: ${urduLine("headline")}; font-weight: 700; }
.receipt { background: var(--mm-color-surface); border: 2px solid var(--mm-color-rule);
  border-block-start: 4px dashed var(--mm-color-outline); padding: 28px; display: grid; gap: 18px; }
.head { display: flex; justify-content: space-between; align-items: center; }
.title { font-size: 28px; font-weight: 600; }
.seal { border: 3px solid var(--mm-color-brass); background: var(--mm-color-brass-container);
  color: var(--mm-color-on-brass-container); border-radius: 999px; padding: 4px 16px; font-size: 22px; font-weight: 600;
  display: inline-flex; align-items: center; gap: 8px; }
.seal .n { font-family: var(--mm-font-latin); }
.label { color: var(--mm-color-ink-muted); font-size: 22px; }
.value { font-size: 26px; font-weight: 600; }
.amount { font-family: var(--mm-font-latin), var(--mm-font-urdu); font-size: 46px; font-weight: 700; white-space: nowrap; }
.chip { justify-self: start; background: var(--mm-color-paid-container); color: var(--mm-color-on-paid-container);
  border-radius: 6px; padding: 4px 14px; font-size: 22px; font-weight: 600; display: flex; gap: 8px; align-items: center; }
html[lang="ur"] .label, html[lang="ur"] .value, html[lang="ur"] .title { line-height: ${urduLine("body")}; }
html[lang="ur"] .chip, html[lang="ur"] .seal { line-height: ${urduLine("label")}; }
</style></head>
<body>
  <div>
    <div class="brand">${mark}<span class="${primaryClass}">${escapeHtml(primaryName)}</span>
      <span class="${secondaryClass}" lang="${secondaryLang}">${escapeHtml(secondaryName)}</span></div>
    <h1>${escapeHtml(home.hero.heading)}</h1>
  </div>
  <div class="receipt">
    <div class="head"><span class="title">${escapeHtml(r.title)}</span>
      <span class="seal"><span>${escapeHtml(r.numberLabel)}</span><span class="n" dir="ltr">${escapeHtml(r.number)}</span></span></div>
    <div><div class="label">${escapeHtml(r.payerLabel)}</div><div class="value">${escapeHtml(r.payer)}</div></div>
    <div><div class="label">${escapeHtml(r.lineLabel)}</div><div class="amount">${escapeHtml(amount)}</div></div>
    <span class="chip"><svg width="22" height="22" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="6.25" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="m5.25 8.25 1.9 1.9 3.6-3.9" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>${escapeHtml(r.status)}</span>
  </div>
</body></html>`;
}

/** An .ico file holding one PNG image, which every current browser reads. */
function icoFromPng(png: Buffer, size: number): Buffer {
  const header = Buffer.alloc(22);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type: icon
  header.writeUInt16LE(1, 4); // one image
  header.writeUInt8(size, 6);
  header.writeUInt8(size, 7);
  header.writeUInt8(0, 8); // no palette
  header.writeUInt8(0, 9);
  header.writeUInt16LE(1, 10); // colour planes
  header.writeUInt16LE(32, 12); // bits per pixel
  header.writeUInt32LE(png.length, 14);
  header.writeUInt32LE(22, 18); // image data offset
  return Buffer.concat([header, png]);
}

async function writeIcons(): Promise<void> {
  const svg = markSvg({ tile: light("primary"), glyph: light("onPrimary") });
  await writeFile(new URL("favicon.svg", publicDir), `${svg}\n`);
  const raster = (size: number) =>
    sharp(Buffer.from(markSvg({ tile: light("primary"), glyph: light("onPrimary"), size })))
      .png({ compressionLevel: 9, palette: true })
      .toBuffer();
  await writeFile(new URL("favicon.ico", publicDir), icoFromPng(await raster(32), 32));
  await writeFile(new URL("icon-512.png", publicDir), await raster(512));
  // Apple's touch icon is square and opaque; the system rounds the corners itself.
  const touch = await sharp(
    Buffer.from(
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="180" height="180"><rect width="32" height="32" fill="${light("primary")}"/>${markSvg(
        { tile: light("primary"), glyph: light("onPrimary"), size: 32 },
      )
        .replace(/^<svg[^>]*>/, "")
        .replace(/<\/svg>$/, "")}</svg>`,
    ),
  )
    .flatten({ background: light("primary") })
    .png({ compressionLevel: 9, palette: true })
    .toBuffer();
  await writeFile(new URL("apple-touch-icon.png", publicDir), touch);
}

async function writeCards(): Promise<void> {
  await mkdir(new URL("og/", publicDir), { recursive: true });
  // PW_CHROMIUM_PATH picks a Chromium other than Playwright's, as for the deck and the e2e suite.
  const executablePath = process.env.PW_CHROMIUM_PATH;
  const browser = await chromium.launch(executablePath === undefined ? {} : { executablePath });
  try {
    const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
    for (const locale of LOCALES) {
      await page.setContent(cardHtml(locale), { waitUntil: "load" });
      await page.evaluate(async () => {
        await document.fonts.ready;
      });
      const png = await page.screenshot({ type: "png" });
      const optimised = await sharp(png)
        .png({ compressionLevel: 9, palette: true, quality: 90, effort: 10 })
        .toBuffer();
      await writeFile(new URL(`og/${locale}.png`, publicDir), optimised);
      console.log(`public/og/${locale}.png: ${(optimised.length / 1024).toFixed(1)} KiB`);
    }
  } finally {
    await browser.close();
  }
}

await mkdir(publicDir, { recursive: true });
await writeIcons();
await writeCards();
console.log("Wrote public/favicon.svg, favicon.ico, apple-touch-icon.png and icon-512.png");
