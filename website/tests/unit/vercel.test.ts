import { describe, expect, test } from "vitest";
import {
  headersFor,
  readVercelConfig,
  sourceMatches,
  trailingSlashRedirect,
} from "../../scripts/lib/vercel.ts";

const config = readVercelConfig(new URL("../../vercel.json", import.meta.url));
const page = headersFor(config, "/ur/licences/");

/** The directives of a Content-Security-Policy, by name. */
function directives(policy: string): Map<string, string[]> {
  return new Map(
    policy
      .split(";")
      .map((part) => part.trim().split(/\s+/))
      .filter((tokens) => tokens[0] !== "")
      .map(([name = "", ...values]) => [name, values]),
  );
}

describe("vercel.json", () => {
  test("builds the Astro project from website/ with the lockfile", () => {
    expect(config).toMatchObject({
      framework: "astro",
      installCommand: "npm ci",
      buildCommand: "npm run build",
      outputDirectory: "dist",
      trailingSlash: true,
    });
  });

  test("the Content-Security-Policy allows no inline script, no eval and no other origin", () => {
    const csp = directives(page["content-security-policy"] ?? "");
    expect(csp.get("default-src")).toEqual(["'none'"]);
    expect(csp.get("script-src")).toEqual(["'self'"]);
    expect(csp.get("style-src")).toEqual(["'self'"]);
    expect(csp.get("font-src")).toEqual(["'self'"]);
    expect(csp.get("img-src")).toEqual(["'self'"]);
    expect(csp.get("frame-ancestors")).toEqual(["'none'"]);
    expect(csp.get("base-uri")).toEqual(["'none'"]);
    expect(csp.get("object-src")).toEqual(["'none'"]);
    expect(csp.has("upgrade-insecure-requests")).toBe(true);
    expect(csp.get("require-trusted-types-for")).toEqual(["'script'"]);
    const all = [...csp.values()].flat().join(" ");
    expect(all).not.toMatch(/unsafe-inline|unsafe-eval|unsafe-hashes|data:|https?:|\*/);
  });

  test("sends HSTS for at least a year, and the other security headers", () => {
    const maxAge = Number(/max-age=(\d+)/.exec(page["strict-transport-security"] ?? "")?.[1]);
    expect(maxAge).toBeGreaterThanOrEqual(31_536_000);
    expect(page["strict-transport-security"]).toContain("includeSubDomains");
    expect(page["x-content-type-options"]).toBe("nosniff");
    expect(page["x-frame-options"]).toBe("DENY");
    expect(page["referrer-policy"]).toBe("strict-origin-when-cross-origin");
    expect(page["cross-origin-opener-policy"]).toBe("same-origin");
    for (const feature of ["camera", "microphone", "geolocation", "payment"]) {
      expect(page["permissions-policy"]).toContain(`${feature}=()`);
    }
  });

  test("hashed assets are cached for a year, immutably; pages are not", () => {
    expect(headersFor(config, "/_astro/BaseLayout.Cpm7xzbF.css")["cache-control"]).toBe(
      "public, max-age=31536000, immutable",
    );
    expect(page["cache-control"]).toBeUndefined();
  });

  test("resources stay same-origin, except the link-preview images; images and icons are cached for a week", () => {
    expect(page["cross-origin-resource-policy"]).toBe("same-origin");
    const og = headersFor(config, "/og/en.png");
    expect(og["cross-origin-resource-policy"]).toBe("cross-origin");
    expect(og["cache-control"]).toBe("public, max-age=604800");
    for (const icon of ["/favicon.ico", "/favicon.svg", "/apple-touch-icon.png", "/icon-512.png"]) {
      expect(headersFor(config, icon)["cache-control"], icon).toBe("public, max-age=604800");
    }
  });

  test("text files are served as UTF-8 (llms.txt and the licences hold Urdu)", () => {
    expect(headersFor(config, "/llms.txt")["content-type"]).toBe("text/plain; charset=utf-8");
    expect(headersFor(config, "/licences/ofl-noto-nastaliq-urdu.txt")["content-type"]).toBe(
      "text/plain; charset=utf-8",
    );
    expect(page["content-type"]).toBeUndefined();
  });
});

describe("the Vercel emulation used by the local server", () => {
  test("matches sources as anchored patterns", () => {
    expect(sourceMatches("/(.*)", "/anything/at/all")).toBe(true);
    expect(sourceMatches("/_astro/(.*)", "/_astro/x.css")).toBe(true);
    expect(sourceMatches("/_astro/(.*)", "/ur/_astro/x.css")).toBe(false);
    expect(() => sourceMatches("/:path*", "/x")).toThrow(/Named parameters/);
  });

  test("adds the trailing slash to page paths only", () => {
    expect(trailingSlashRedirect(config, "/ur")).toBe("/ur/");
    expect(trailingSlashRedirect(config, "/ur/licences")).toBe("/ur/licences/");
    expect(trailingSlashRedirect(config, "/ur/")).toBeUndefined();
    expect(trailingSlashRedirect(config, "/robots.txt")).toBeUndefined();
  });
});
