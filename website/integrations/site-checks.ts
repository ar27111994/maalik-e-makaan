/**
 * Build-time guards that fail `astro build` instead of shipping a broken site:
 *
 * - every page exists in both languages (the language switch and the hreflang
 *   links of each page point at its twin);
 * - no page carries inline script or style, which the Content-Security-Policy
 *   in vercel.json would block (JSON-LD data blocks are not scripts and are
 *   allowed).
 */
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import type { AstroIntegration } from "astro";
import { delocalisePath, localisePath, LOCALES } from "../src/i18n/locales.ts";

/** Pages that exist in one language by design: none. Error pages are paired by their own rule. */
const NOT_FOUND_PAGES = new Set(["/404/", "/ur/404/"]);

/** Normalises the build's page names ("", "ur/", "404") to URL paths ("/", "/ur/", "/404/"). */
export function pagePath(pathname: string): string {
  const trimmed = pathname.replace(/^\/+|\/+$/g, "");
  return trimmed === "" ? "/" : `/${trimmed}/`;
}

/** The pages whose twin in the other language is missing, as "<path> → <missing twin>". */
export function missingTwins(pathnames: readonly string[]): string[] {
  const paths = new Set(pathnames.map(pagePath));
  const missing: string[] = [];
  for (const path of paths) {
    if (NOT_FOUND_PAGES.has(path)) continue;
    const { locale, path: neutral } = delocalisePath(path);
    for (const other of LOCALES) {
      if (other === locale) continue;
      const twin = localisePath(neutral, other);
      if (!paths.has(twin)) missing.push(`${path} → ${twin}`);
    }
  }
  for (const path of NOT_FOUND_PAGES) {
    if (!paths.has(path)) missing.push(`${path} (the not-found page in each language)`);
  }
  return missing.sort();
}

const SCRIPT_TAG = /<script\b([^>]*)>/gi;
const STYLE_TAG = /<style\b/i;
const STYLE_ATTRIBUTE = /<[a-z][^>]*\sstyle=/i;
const EVENT_HANDLER = /<[a-z][^>]*\son[a-z]+=/i;

/** What in `html` the CSP (script-src 'self'; style-src 'self') would block. */
export function inlineCodeProblems(html: string): string[] {
  const problems: string[] = [];
  for (const match of html.matchAll(SCRIPT_TAG)) {
    const attributes = match[1] ?? "";
    const external = /\ssrc=/i.test(attributes);
    const data = /\stype="?application\/ld\+json"?/i.test(attributes);
    if (!external && !data) problems.push("an inline <script>");
  }
  if (STYLE_TAG.test(html)) problems.push("an inline <style>");
  if (STYLE_ATTRIBUTE.test(html)) problems.push("a style attribute");
  if (EVENT_HANDLER.test(html)) problems.push("an inline event handler");
  return problems;
}

export function siteChecks(): AstroIntegration {
  return {
    name: "maalik-site-checks",
    hooks: {
      "astro:build:done": async ({ pages, dir, logger }) => {
        const failures: string[] = [];
        const missing = missingTwins(pages.map((page) => page.pathname));
        if (missing.length > 0) {
          failures.push(`Pages missing in the other language:\n  ${missing.join("\n  ")}`);
        }
        for (const page of pages) {
          const path = pagePath(page.pathname);
          const file = path === "/404/" ? "404.html" : `${path.slice(1)}index.html`;
          const html = await readFile(fileURLToPath(new URL(file, dir)), "utf8");
          const problems = inlineCodeProblems(html);
          if (problems.length > 0) failures.push(`${path} has ${problems.join(", ")}`);
        }
        if (failures.length > 0) throw new Error(failures.join("\n"));
        logger.info(`${pages.length} pages: every page has its twin, and none has inline code`);
      },
    },
  };
}
