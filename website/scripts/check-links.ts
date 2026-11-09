/**
 * Checks every link in the built site (dist/) without a network: each
 * same-site href, src and srcset must resolve to a file the way Vercel serves
 * it, each #fragment must name an element on the target page, and every
 * absolute URL in the sitemap, llms.txt and llms-full.txt must be a page of
 * the site. Links to other sites must be well-formed https (or http for the
 * few official Pakistani sites that serve nothing else); they are listed, not
 * fetched, so the check is fast and repeatable.
 *
 *   node scripts/check-links.ts
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { parse, type DefaultTreeAdapterMap } from "parse5";

type Node = DefaultTreeAdapterMap["node"];
type Element = DefaultTreeAdapterMap["element"];

const dist = fileURLToPath(new URL("../dist/", import.meta.url));

function walk(directory: string): string[] {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

/** The site's own origin, as the build wrote it into the sitemap. */
function siteOrigin(): string {
  const index = readFileSync(join(dist, "sitemap-index.xml"), "utf8");
  const match = /<loc>(https?:\/\/[^<]+)<\/loc>/.exec(index);
  if (match?.[1] === undefined) throw new Error("dist/sitemap-index.xml lists no sitemap");
  return new URL(match[1]).origin;
}

function isFile(path: string): boolean {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

/** The dist/ file that serves a URL path, as Vercel resolves it (with trailingSlash: true). */
function fileFor(pathname: string): string | undefined {
  const decoded = decodeURIComponent(pathname);
  const candidates = decoded.endsWith("/")
    ? [`${decoded}index.html`]
    : [decoded, `${decoded}/index.html`]; // the second is reached through a 308 redirect
  for (const candidate of candidates) {
    const path = join(dist, candidate);
    if (path.startsWith(dist) && isFile(path)) return path;
  }
  return undefined;
}

function elements(node: Node, out: Element[] = []): Element[] {
  if ("tagName" in node) out.push(node);
  if ("childNodes" in node) for (const child of node.childNodes) elements(child, out);
  if ("content" in node) elements(node.content, out);
  return out;
}

const attribute = (element: Element, name: string): string | undefined =>
  element.attrs.find((attr) => attr.name === name)?.value;

const idsCache = new Map<string, Set<string>>();
function idsIn(file: string): Set<string> {
  let ids = idsCache.get(file);
  if (ids === undefined) {
    const document = parse(readFileSync(file, "utf8"));
    ids = new Set(
      elements(document)
        .map((element) => attribute(element, "id"))
        .filter((id): id is string => id !== undefined),
    );
    idsCache.set(file, ids);
  }
  return ids;
}

const origin = siteOrigin();
const problems: string[] = [];
const external = new Set<string>();
let checked = 0;

/** Checks one URL found in `source` (a dist/ file). */
function check(raw: string, source: string, base: string): void {
  checked += 1;
  const where = relative(dist, source);
  let url: URL;
  try {
    url = new URL(raw, base);
  } catch {
    problems.push(`${where}: malformed URL ${JSON.stringify(raw)}`);
    return;
  }
  if (url.origin !== origin) {
    if (url.protocol === "mailto:") return;
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      problems.push(`${where}: unsupported scheme in ${raw}`);
    } else if (url.username !== "" || url.password !== "") {
      problems.push(`${where}: credentials in ${raw}`);
    } else {
      external.add(url.href);
    }
    return;
  }
  const target = fileFor(url.pathname);
  if (target === undefined) {
    problems.push(`${where}: broken link to ${url.pathname}`);
    return;
  }
  if (url.hash.length > 1 && target.endsWith(".html")) {
    const id = decodeURIComponent(url.hash.slice(1));
    if (!idsIn(target).has(id)) problems.push(`${where}: no #${id} on ${url.pathname}`);
  }
}

const files = walk(dist);
for (const file of files.filter((path) => path.endsWith(".html"))) {
  const pagePath = `/${relative(dist, file).replace(/index\.html$/, "")}`;
  const base = new URL(pagePath, origin).href;
  for (const element of elements(parse(readFileSync(file, "utf8")))) {
    for (const name of ["href", "src"]) {
      const value = attribute(element, name);
      if (value !== undefined && value !== "") check(value, file, base);
    }
    const srcset = attribute(element, "srcset");
    if (srcset !== undefined) {
      for (const candidate of srcset.split(",")) {
        const value = candidate.trim().split(/\s+/)[0];
        if (value !== undefined && value !== "") check(value, file, base);
      }
    }
    // Open Graph and Twitter images and the page URL itself.
    const property = attribute(element, "property") ?? attribute(element, "name") ?? "";
    if (/^(og:image|og:url|twitter:image)$/.test(property)) {
      check(attribute(element, "content") ?? "", file, base);
    }
  }
}

/** The namespace URIs the sitemap declares, matched by host and path, not by substring. */
const XML_NAMESPACES: readonly (readonly [host: string, pathPrefix: string])[] = [
  ["www.sitemaps.org", "/schemas/"],
  ["www.w3.org", "/1999/xhtml"],
  ["www.google.com", "/schemas/"],
];

function isXmlNamespace(href: string): boolean {
  let url: URL;
  try {
    url = new URL(href);
  } catch {
    return false;
  }
  return XML_NAMESPACES.some(
    ([host, pathPrefix]) => url.hostname === host && url.pathname.startsWith(pathPrefix),
  );
}

// Absolute links in the generated text files.
for (const name of ["sitemap-0.xml", "llms.txt", "llms-full.txt", "robots.txt"]) {
  const file = join(dist, name);
  const text = readFileSync(file, "utf8");
  for (const match of text.matchAll(/https?:\/\/[^\s<>"')\]]+/g)) {
    // XML namespaces are identifiers, not links.
    if (isXmlNamespace(match[0])) continue;
    // Sentence punctuation after a bare URL is not part of it.
    check(match[0].replace(/[.,;:]+$/, "").replaceAll("&amp;", "&"), file, origin);
  }
}

console.log(`Checked ${checked} links in ${files.length} files of dist/ (site origin ${origin}).`);
console.log(`${external.size} links to other sites (well-formed, not fetched):`);
for (const href of [...external].sort()) console.log(`  ${href}`);
if (problems.length > 0) {
  console.error(`\n${problems.length} broken links:\n  ${problems.join("\n  ")}`);
  process.exit(1);
}
console.log("No broken links.");
