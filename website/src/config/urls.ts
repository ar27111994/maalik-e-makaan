/**
 * The site's own address (SITE_URL) and the web app's address (PUBLIC_APP_URL).
 *
 * Both default to the Vercel production addresses. When the owner moves either
 * to a custom domain, set the variable in the Vercel project (and locally in
 * website/.env) and rebuild; see website/README.md. These helpers validate the
 * values when the site is built, so a typo fails the build instead of shipping
 * broken canonical URLs.
 */

/** The production address of the Vercel project maalik-e-makaan-site (root directory website/). */
export const DEFAULT_SITE_URL = "https://maalik-e-makaan-site.vercel.app";
/** The production address of the Flutter web app (its APP_URL). */
export const DEFAULT_APP_URL = "https://maalik-e-makaan.vercel.app";

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

function parseHttpUrl(raw: string, name: string): URL {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    throw new Error(`${name} must be an absolute URL, got ${JSON.stringify(raw)}`);
  }
  const local = LOCAL_HOSTS.has(url.hostname);
  if (url.protocol !== "https:" && !(local && url.protocol === "http:")) {
    throw new Error(
      `${name} must use https (http is allowed only for localhost), got ${JSON.stringify(raw)}`,
    );
  }
  if (url.username !== "" || url.password !== "") {
    throw new Error(`${name} must not contain credentials`);
  }
  if (url.search !== "" || url.hash !== "") {
    throw new Error(`${name} must not contain a query or fragment`);
  }
  return url;
}

/**
 * The public origin the site is served from, e.g. `https://example.com` (no
 * path, no trailing slash). Canonical URLs, hreflang links, the sitemap,
 * robots.txt and llms.txt are all built from it.
 */
export function resolveSiteUrl(raw: string | undefined): string {
  if (raw === undefined || raw.trim() === "") return DEFAULT_SITE_URL;
  const url = parseHttpUrl(raw, "SITE_URL");
  if (url.pathname !== "/") {
    throw new Error(`SITE_URL must be an origin without a path, got ${JSON.stringify(raw)}`);
  }
  return url.origin;
}

/** The web app's address. It may include a path; it is returned normalised, ending in "/". */
export function resolveAppUrl(raw: string | undefined): string {
  if (raw === undefined || raw.trim() === "") return `${DEFAULT_APP_URL}/`;
  const url = parseHttpUrl(raw, "PUBLIC_APP_URL");
  if (!url.pathname.endsWith("/")) url.pathname += "/";
  return url.href;
}
