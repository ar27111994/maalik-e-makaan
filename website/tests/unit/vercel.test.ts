import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { describe, expect, test } from "vitest";
import origins from "../../../contracts/origins.json";
import {
  headersFor,
  readVercelConfig,
  redirectFor,
  sourceMatches,
  trailingSlashRedirect,
  type VercelConfig,
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
    expect(headersFor(config, "/licences/ofl-noto-sans-arabic.txt")["content-type"]).toBe(
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

describe("the earlier addresses redirect to the site's origin (contracts/origins.json, D-20)", () => {
  const legacyHosts = origins.site.legacy.map((url) => new URL(url).hostname);
  const siteHost = new URL(origins.site.origin).hostname;

  test("one permanent redirect per earlier address, matched on its exact host, to the origin", () => {
    expect(config.redirects).toEqual(
      legacyHosts.map((host) => ({
        source: "/:path((?!google[0-9a-f]{16}\\.html$).*)",
        has: [{ type: "host", value: host.replaceAll(".", "\\.") }],
        destination: `${origins.site.origin}/:path`,
        permanent: true,
      })),
    );
  });

  test.each(legacyHosts)(
    "%s: every path, with its query, goes to the same path on the origin",
    (host) => {
      for (const [path, search] of [
        ["/", ""],
        ["/pricing/", "?utm_source=x&a=%20b"],
        ["/ur/guides/rent-agreement/", ""],
        ["/sitemap-index.xml", ""],
        ["/missing/", "?q=1"],
      ] as const) {
        expect(redirectFor(config, host, path, search)).toEqual({
          status: 308,
          location: `${origins.site.origin}${path}${search}`,
        });
      }
    },
  );

  test.each(legacyHosts)(
    "%s keeps answering Google's verification file and /.well-known/ itself",
    (host) => {
      expect(redirectFor(config, host, "/google0123456789abcdef.html")).toBeUndefined();
      expect(redirectFor(config, host, "/.well-known/security.txt")).toBeUndefined();
      // Only a file at the root is Google's; the same name deeper down moves like any page.
      expect(redirectFor(config, host, "/x/google0123456789abcdef.html")?.status).toBe(308);
    },
  );

  test("the origin, its aliases, previews and local servers are never redirected", () => {
    for (const host of [
      siteHost,
      ...origins.site.aliases.map((url) => new URL(url).hostname),
      `x${legacyHosts[0] ?? ""}`,
      `${legacyHosts[0] ?? ""}.example`,
      // A preview's host: the project's name with the branch and team after it.
      (legacyHosts[0] ?? "").replace(/^([^.]+)/, "$1-git-main-team"),
      "127.0.0.1",
      "localhost",
    ]) {
      expect(redirectFor(config, host, "/pricing/"), host).toBeUndefined();
    }
  });
});

describe("the redirect emulation refuses what it cannot apply as Vercel does", () => {
  function configWith(redirects: unknown): URL {
    const dir = mkdtempSync(join(tmpdir(), "vercel-json-"));
    const file = join(dir, "vercel.json");
    writeFileSync(file, JSON.stringify({ redirects }));
    return pathToFileURL(file);
  }
  const rule = { source: "/:p(.*)", destination: "https://b.example/:p", permanent: true };

  test.each([
    [{ ...rule, source: "/:p*" }, /not emulated/],
    [{ ...rule, source: "/:p" }, /not emulated/],
    [{ ...rule, source: "/(.*)" }, /not emulated/],
    [{ ...rule, source: "/:p((.*))" }, /Capturing group/],
    [{ ...rule, source: "/:p(.*)?" }, /modifiers/],
    [{ ...rule, source: "/:p(.*" }, /Unbalanced/],
    [{ ...rule, has: [{ type: "header", key: "x", value: "y" }] }, /on the host/],
    [{ ...rule, missing: [] }, /nothing else/],
    [{ ...rule, statusCode: 301 }, /permanent or statusCode/],
    [{ source: rule.source, destination: rule.destination }, /permanent or statusCode/],
  ])("%j", (bad, message) => {
    expect(() => readVercelConfig(configWith([bad]))).toThrow(message);
  });

  test("statusCode, a temporary redirect, a destination with its own query and literal text", () => {
    const own: VercelConfig = {
      redirects: [
        { source: "/old.html", destination: "/new/?from=old", statusCode: 301 },
        { source: "/a/:rest(.*)", destination: "https://b.example/c/:rest", permanent: false },
      ],
    };
    expect(redirectFor(own, "any", "/old.html", "?x=1")).toEqual({
      status: 301,
      location: "/new/?from=old",
    });
    expect(redirectFor(own, "any", "/oldxhtml")).toBeUndefined();
    expect(redirectFor(own, "any", "/a/b/c", "?y")).toEqual({
      status: 307,
      location: "https://b.example/c/b/c?y",
    });
  });

  test("the trailing slash is not added under /.well-known/, as on Vercel", () => {
    expect(trailingSlashRedirect(config, "/.well-known/thing")).toBeUndefined();
  });
});
