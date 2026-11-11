// Renders the pitch deck in deck/ to public/pitch/maalik-e-makaan-pitch-deck.pdf.
//
//   npm run deck        (PW_CHROMIUM_PATH picks a Chromium other than Playwright's)
//
// The slides are kept in the format of the deck artifact they were written in:
// one <section> of inline-styled HTML per slide, with <x-icon> and
// <x-connector> elements and data-crop on images. This script turns those into
// plain HTML: the icons from deck/icons (Lucide), the screens cropped from the
// app's golden test images (sample data, so they always show the current app),
// the fonts from packages/mm_ui, and {{version}} and {{releaseDate}} from the
// release-please manifest and CHANGELOG.md. CI and the Deploy workflow run it
// before the site is built, so the deck on the site matches each release.
import { readFileSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import sharp from "sharp";

const website = new URL("../", import.meta.url);
const repository = new URL("../../", import.meta.url);
const deckDir = new URL("deck/", website);
const output = new URL("public/pitch/maalik-e-makaan-pitch-deck.pdf", website);

const text = (url: URL) => readFileSync(url, "utf8");
const base64 = (url: URL) => readFileSync(url).toString("base64");

/** The screens the slides show: the golden image and the part of it to keep (left, top, width, height). */
const SCREENS: Readonly<Record<string, readonly [number, number, number, number]>> = {
  dashboard_light: [0, 0, 360, 780],
  dashboard_urdu: [0, 0, 360, 780],
  reminder_composer_light: [0, 575, 360, 925],
  receipt_light: [0, 0, 360, 900],
};

/** The deck format's icon names, as Lucide's file names. */
const ICONS: Readonly<Record<string, string>> = {
  CheckCircle: "circle-check",
  Clock: "clock",
  Globe: "globe",
  Users: "users",
  Chat: "message-circle",
};

function release(): { version: string; date: string } {
  const manifest = JSON.parse(text(new URL(".release-please-manifest.json", repository))) as Record<
    string,
    string
  >;
  const version = manifest["."];
  if (version === undefined) throw new Error("The release-please manifest has no version");
  const escaped = version.replaceAll(".", "\\.");
  const heading = new RegExp(
    `^## \\[?${escaped}\\]?(?:\\([^)]*\\))? \\((\\d{4}-\\d{2}-\\d{2})\\)`,
    "m",
  );
  const iso = heading.exec(text(new URL("CHANGELOG.md", repository)))?.[1];
  if (iso === undefined) throw new Error(`CHANGELOG.md has no entry for ${version}`);
  const date = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${iso}T00:00:00Z`));
  return { version, date };
}

async function screen(name: string): Promise<string> {
  const box = SCREENS[name];
  if (box === undefined) throw new Error(`deck: no crop for the screen ${name}`);
  const [left, top, width, height] = box;
  const golden = new URL(`app/test/src/goldens/goldens/${name}.png`, repository);
  const png = await sharp(readFileSync(golden))
    .extract({ left, top, width, height })
    .resize(width * 2, height * 2, { kernel: "lanczos3" })
    .png()
    .toBuffer();
  return `data:image/png;base64,${png.toString("base64")}`;
}

function icon(name: string, style: string): string {
  const file = ICONS[name];
  if (file === undefined) throw new Error(`deck: no icon called ${name}`);
  // Lucide's files are a licence comment followed by one <svg> element: keep the
  // element and drop everything before it, rather than editing comments out.
  const source = text(new URL(`icons/${file}.svg`, deckDir));
  const start = source.indexOf("<svg");
  const end = source.lastIndexOf("</svg>");
  if (start === -1 || end < start) throw new Error(`deck: icons/${file}.svg has no <svg> element`);
  const svg = source
    .slice(start, end + "</svg>".length)
    .replace(/\sclass="[^"]*"/, "")
    .replace(/\swidth="24"\s+height="24"/, "");
  return svg.replace("<svg", `<svg aria-hidden="true" style="flex:none;${style}"`);
}

function connector(style: string): string {
  const width = Number(/width:\s*(\d+)px/.exec(style)?.[1] ?? "48");
  const color = /color:\s*(#[0-9A-Fa-f]{3,8})/.exec(style)?.[1] ?? "currentColor";
  const y = 12;
  return (
    `<svg aria-hidden="true" viewBox="0 0 ${width} 24" style="flex:none;align-self:center;width:${width}px;height:24px">` +
    `<path d="M2 ${y}H${width - 6}" stroke="${color}" stroke-width="4"/>` +
    `<path d="M${width - 14} ${y - 7}l9 7-9 7" fill="none" stroke="${color}" stroke-width="4"/></svg>`
  );
}

async function slideHtml(file: string, values: Record<string, string>): Promise<string> {
  let html = text(new URL(`slides/${file}.html`, deckDir));
  for (const [key, value] of Object.entries(values)) html = html.replaceAll(`{{${key}}}`, value);
  if (/\{\{\w+\}\}/.test(html)) throw new Error(`deck: ${file} has a placeholder with no value`);
  html = html.replace(
    /<x-icon name="(\w+)" style="([^"]*)"><\/x-icon>/g,
    (_, name: string, style: string) => icon(name, style),
  );
  html = html.replace(
    /<x-connector[^>]*style="([^"]*)"[^>]*><\/x-connector>/g,
    (_, style: string) => connector(style),
  );
  if (/<x-[a-z]+/.test(html))
    throw new Error(`deck: ${file} uses an element the renderer cannot draw`);
  // data-crop="ZOOM X% Y%": the image's focal point, as object-position.
  html = html.replace(
    /data-crop="[\d.]+ ([\d.]+%) ([\d.]+%)" style="/g,
    'style="object-position:$1 $2;',
  );
  for (const match of html.matchAll(/src="screens\/(\w+)\.png"/g)) {
    const name = match[1] ?? "";
    html = html.replace(match[0], `src="${await screen(name)}"`);
  }
  return html;
}

const deck = JSON.parse(text(new URL("deck.json", deckDir))) as { title: string; order: string[] };
const { version, date } = release();
const slides = await Promise.all(
  deck.order.map((file) => slideHtml(file, { version, releaseDate: date })),
);
const fonts = [
  ["Atkinson Hyperlegible Next", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"],
  ["Noto Nastaliq Urdu", "NotoNastaliqUrdu-Variable.ttf", "400 700"],
]
  .map(
    ([family, file, weight]) =>
      `@font-face{font-family:"${family}";font-weight:${weight};src:url(data:font/ttf;base64,${base64(
        new URL(`packages/mm_ui/assets/fonts/${file}`, repository),
      )})}`,
  )
  .join("\n");
const page = `<!doctype html><html lang="en-GB"><head><meta charset="utf-8">
<title>${deck.title} (version ${version})</title>
<style>
${fonts}
@page{size:1920px 1080px;margin:0}
*{box-sizing:border-box;margin:0}
html,body{padding:0}
section{width:1920px;height:1080px;position:relative;overflow:hidden;break-after:page}
section:last-of-type{break-after:auto}
aside{display:none}
ul,ol{padding-inline-start:1.2em}
table{border-collapse:separate;border-spacing:0;overflow:hidden}
th,td{padding:.35em .6em;text-align:left;vertical-align:top;border-bottom:1px solid #D5DAE0}
tr:last-child td{border-bottom:none}
</style></head><body>
${slides.join("\n")}
</body></html>`;

const executablePath = process.env.PW_CHROMIUM_PATH;
const browser = await chromium.launch(executablePath === undefined ? {} : { executablePath });
try {
  const tab = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await tab.setContent(page, { waitUntil: "load" });
  await tab.evaluate(async () => {
    await document.fonts.ready;
  });
  await mkdir(new URL("./", output), { recursive: true });
  // A file path, not the URL's percent-encoded pathname: a checkout under
  // "My Projects" would otherwise get its PDF in a new "My%20Projects" folder.
  await tab.pdf({
    path: fileURLToPath(output),
    width: "1920px",
    height: "1080px",
    printBackground: true,
    preferCSSPageSize: true,
  });
  console.log(
    `Pitch deck: ${deck.order.length} slides, version ${version} (${date}) -> public/pitch/`,
  );
} finally {
  await browser.close();
}
