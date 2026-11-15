/**
 * The parts of Vercel's static hosting that this site relies on, read from
 * website/vercel.json, so the local server (scripts/serve.ts), the e2e suite
 * and Lighthouse see the same headers, redirects and not-found pages as
 * production. Only the vercel.json features the site uses are supported; an
 * unsupported one fails loudly instead of being ignored.
 */
import { readFileSync } from "node:fs";

interface HeaderRule {
  readonly source: string;
  readonly headers: readonly { readonly key: string; readonly value: string }[];
}

interface RedirectRule {
  readonly source: string;
  readonly destination: string;
  readonly has?: readonly { readonly type: string; readonly value?: string }[];
  readonly permanent?: boolean;
  readonly statusCode?: number;
  readonly [key: string]: unknown;
}

export interface VercelConfig {
  readonly trailingSlash?: boolean;
  readonly headers?: readonly HeaderRule[];
  readonly redirects?: readonly RedirectRule[];
  readonly [key: string]: unknown;
}

const SUPPORTED = new Set([
  "$schema",
  "framework",
  "installCommand",
  "buildCommand",
  "outputDirectory",
  "trailingSlash",
  "headers",
  "redirects",
]);

const REDIRECT_KEYS = new Set(["source", "destination", "has", "permanent", "statusCode"]);

export function readVercelConfig(path: URL): VercelConfig {
  const config = JSON.parse(readFileSync(path, "utf8")) as VercelConfig;
  const unsupported = Object.keys(config).filter((key) => !SUPPORTED.has(key));
  if (unsupported.length > 0) {
    throw new Error(
      `scripts/lib/vercel.ts does not emulate vercel.json "${unsupported.join('", "')}"`,
    );
  }
  for (const rule of config.redirects ?? []) checkRedirect(rule);
  return config;
}

/**
 * Vercel matches `source` with path-to-regexp. This site's sources use only
 * literal segments and unnamed regular-expression groups such as "/(.*)", which
 * mean the same as an anchored regular expression.
 */
export function sourceMatches(source: string, pathname: string): boolean {
  if (/:[a-z]/i.test(source)) throw new Error(`Named parameters are not emulated: ${source}`);
  return new RegExp(`^${source}$`).test(pathname);
}

// A Host header: a DNS name or an IPv4 address, or an IPv6 address in brackets, with a port or not.
const HOST_HEADER =
  /^(?:[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:.]+\])(?::\d{1,5})?$/;

/**
 * The URL of a request as Vercel reads it: the host of the Host header (or
 * localhost without one) and the request target, which is a path, as the path.
 * `new URL(target, base)` would instead read a target that starts with `//` as
 * another host (`//evil.example/` as evil.example's `/`), where Vercel keeps
 * `//evil.example/` as the path. Undefined for a target that is not a path
 * (absolute-form or `*`) or a Host header that is not a host: a 400.
 */
export function requestUrl(target: string, host: string | undefined): URL | undefined {
  if (!target.startsWith("/")) return undefined;
  const authority = host ?? "localhost";
  if (!HOST_HEADER.test(authority)) return undefined;
  try {
    return new URL(`http://${authority}${target}`);
  } catch {
    return undefined;
  }
}

/**
 * `pathname` with its percent-encoding decoded, or undefined when it is not valid percent-encoding
 * (`/%zz`, or bytes that are not UTF-8, such as `/%ff`): the server answers that with 400.
 */
export function decodedPath(pathname: string): string | undefined {
  try {
    return decodeURIComponent(pathname);
  } catch {
    return undefined;
  }
}

/** The response headers for `pathname`: later rules override earlier ones, as on Vercel. */
export function headersFor(config: VercelConfig, pathname: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const rule of config.headers ?? []) {
    if (!sourceMatches(rule.source, pathname)) continue;
    for (const { key, value } of rule.headers) result[key.toLowerCase()] = value;
  }
  return result;
}

/**
 * Vercel's compiled routes start with a pass-through for /.well-known/ (checked
 * with the pinned CLI's routing), so neither the trailing slash nor a redirect
 * applies there.
 */
function isWellKnown(pathname: string): boolean {
  return /^\/\.well-known(?:\/.*)?$/.test(pathname);
}

/**
 * The name of a search engine's ownership file: Google Search Console's HTML file method asks
 * for `google<16 hex digits>.html` at the site's root. Such a file lives in `public/` and is
 * served as it is. It is not a page of the site, and vercel.json's redirect from an earlier
 * address leaves it out, so that the earlier address can be verified too.
 */
export const VERIFICATION_FILE = /^google[0-9a-f]{16}\.html$/;

/**
 * With `trailingSlash: true`, a path without a file extension gains a slash (308). Not a path
 * that starts with `//`: its Location (`//ur/` for `//ur`) would start with `//` too, which a
 * browser reads as another host (`ur`). Such a path goes on to vercel.json's redirects and the
 * files instead.
 */
export function trailingSlashRedirect(config: VercelConfig, pathname: string): string | undefined {
  if (
    config.trailingSlash !== true ||
    pathname.endsWith("/") ||
    pathname.startsWith("//") ||
    isWellKnown(pathname)
  ) {
    return undefined;
  }
  const last = pathname.slice(pathname.lastIndexOf("/") + 1);
  return last.includes(".") ? undefined : `${pathname}/`;
}

/**
 * A redirect's `source` as the anchored regular expression path-to-regexp
 * makes of it, and the names of its parameters. Only the shape this site uses
 * is read: literal text and parameters with a pattern, `:name(pattern)`.
 * Anything else (a bare `:name`, a modifier, an unnamed group) throws.
 */
function compileRedirectSource(source: string): { regex: RegExp; names: string[] } {
  const names: string[] = [];
  let pattern = "";
  let i = 0;
  while (i < source.length) {
    const param = /^:([A-Za-z_]\w*)\(/.exec(source.slice(i));
    if (param === null) {
      const char = source.charAt(i);
      if ("():*+?{}".includes(char)) {
        throw new Error(
          `Redirect sources other than literal text and :name(pattern) are not emulated: ${source}`,
        );
      }
      pattern += char.replace(/[.\\^$|[\]]/g, "\\$&");
      i += 1;
      continue;
    }
    names.push(param[1] ?? "");
    let depth = 1;
    let j = i + param[0].length;
    const start = j;
    while (j < source.length && depth > 0) {
      if (source[j] === "\\") j += 1;
      else if (source[j] === "(") {
        // path-to-regexp refuses a capturing group inside a parameter's pattern.
        if (source[j + 1] !== "?") throw new Error(`Capturing group in a parameter: ${source}`);
        depth += 1;
      } else if (source[j] === ")") depth -= 1;
      j += 1;
    }
    if (depth !== 0) throw new Error(`Unbalanced parameter pattern in ${source}`);
    if (j < source.length && "*+?".includes(source.charAt(j))) {
      throw new Error(`Parameter modifiers are not emulated: ${source}`);
    }
    pattern += `(${source.slice(start, j - 1)})`;
    i = j;
  }
  return { regex: new RegExp(`^(?:${pattern})$`), names };
}

/** A `has` condition: only `{"type": "host", "value": regex}`, matched against the whole host name. */
function hostMatches(rule: RedirectRule, hostname: string): boolean {
  return (rule.has ?? []).every((condition) =>
    new RegExp(`^(?:${condition.value ?? ""})$`).test(hostname),
  );
}

/** Throws on a redirect rule that redirectFor cannot apply exactly as Vercel does. */
function checkRedirect(rule: RedirectRule): void {
  const unknown = Object.keys(rule).filter((key) => !REDIRECT_KEYS.has(key));
  if (unknown.length > 0 || (rule.permanent === undefined) === (rule.statusCode === undefined)) {
    throw new Error(
      `Redirect rules need permanent or statusCode, and nothing else: ${JSON.stringify(rule)}`,
    );
  }
  compileRedirectSource(rule.source);
  for (const condition of rule.has ?? []) {
    if (condition.type !== "host" || typeof condition.value !== "string") {
      throw new Error(
        `Only "has" conditions on the host are emulated: ${JSON.stringify(condition)}`,
      );
    }
  }
}

/**
 * The redirect vercel.json's `redirects` give a request for `pathname` with
 * `search` on the host `hostname`: the status and the Location, with the query
 * passed through (Vercel keeps it unless the destination sets one), or
 * undefined. The first rule that matches wins, as on Vercel.
 */
export function redirectFor(
  config: VercelConfig,
  hostname: string,
  pathname: string,
  search = "",
): { status: number; location: string } | undefined {
  if (isWellKnown(pathname)) return undefined;
  for (const rule of config.redirects ?? []) {
    checkRedirect(rule);
    const { regex, names } = compileRedirectSource(rule.source);
    const match = regex.exec(pathname);
    if (match === null || !hostMatches(rule, hostname)) continue;
    // One pass, with a function: each :name takes its capture as it is, never read as a
    // replacement pattern ($&, $1, $$...) nor searched again for another parameter's name.
    const captures = new Map(names.map((name, index) => [name, match[index + 1] ?? ""]));
    let location = rule.destination;
    if (names.length > 0) {
      const parameter = new RegExp(`:(${names.join("|")})(?!\\w)`, "g");
      location = location.replace(parameter, (_, name: string) => captures.get(name) ?? "");
    }
    if (!location.includes("?")) location += search;
    return { status: rule.statusCode ?? (rule.permanent === true ? 308 : 307), location };
  }
  return undefined;
}
