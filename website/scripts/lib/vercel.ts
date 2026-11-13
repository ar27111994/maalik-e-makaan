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

/** With `trailingSlash: true`, a path without a file extension gains a slash (308). */
export function trailingSlashRedirect(config: VercelConfig, pathname: string): string | undefined {
  if (config.trailingSlash !== true || pathname.endsWith("/") || isWellKnown(pathname)) {
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
    let location = rule.destination;
    names.forEach((name, index) => {
      location = location.replace(new RegExp(`:${name}(?!\\w)`, "g"), match[index + 1] ?? "");
    });
    if (!location.includes("?")) location += search;
    return { status: rule.statusCode ?? (rule.permanent === true ? 308 : 307), location };
  }
  return undefined;
}
