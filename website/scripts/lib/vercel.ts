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

export interface VercelConfig {
  readonly trailingSlash?: boolean;
  readonly headers?: readonly HeaderRule[];
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
]);

export function readVercelConfig(path: URL): VercelConfig {
  const config = JSON.parse(readFileSync(path, "utf8")) as VercelConfig;
  const unsupported = Object.keys(config).filter((key) => !SUPPORTED.has(key));
  if (unsupported.length > 0) {
    throw new Error(
      `scripts/lib/vercel.ts does not emulate vercel.json "${unsupported.join('", "')}"`,
    );
  }
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

/** With `trailingSlash: true`, a path without a file extension gains a slash (308). */
export function trailingSlashRedirect(config: VercelConfig, pathname: string): string | undefined {
  if (config.trailingSlash !== true || pathname.endsWith("/")) return undefined;
  const last = pathname.slice(pathname.lastIndexOf("/") + 1);
  return last.includes(".") ? undefined : `${pathname}/`;
}
