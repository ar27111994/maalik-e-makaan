// What the server sends: the security headers of vercel.json on every
// response, long-lived caching for hashed assets, redirects and 404s.
import { readdirSync, readFileSync } from "node:fs";
import { request as httpRequest } from "node:http";
import { createRequire } from "node:module";
import { expect, test } from "@playwright/test";
import { readOrigins } from "../../scripts/lib/origins.ts";
import { headersFor, readVercelConfig, VERIFICATION_FILE } from "../../scripts/lib/vercel.ts";
import { sitePages, verificationFiles } from "./site.ts";

const config = readVercelConfig(new URL("../../vercel.json", import.meta.url));
const origins = readOrigins();

test("every page is served with the security headers of vercel.json", async ({ request }) => {
  for (const site of sitePages()) {
    const response = await request.get(site.path);
    expect(response.status()).toBe(200);
    const headers = response.headers();
    for (const [name, value] of Object.entries(headersFor(config, site.path))) {
      expect(headers[name], `${name} on ${site.path}`).toBe(value);
    }
    expect(headers["content-type"]).toBe("text/html; charset=utf-8");
  }
});

test("hashed assets are cached for a year; pages are not cached that way", async ({
  page,
  request,
}) => {
  const assets: string[] = [];
  page.on("response", (response) => {
    if (new URL(response.url()).pathname.startsWith("/_astro/")) assets.push(response.url());
  });
  await page.goto("/ur/", { waitUntil: "networkidle" });
  expect(assets.some((url) => url.endsWith(".css"))).toBe(true);
  expect(assets.some((url) => url.endsWith(".woff2"))).toBe(true);
  for (const url of assets) {
    const response = await request.get(url);
    expect(response.headers()["cache-control"]).toBe("public, max-age=31536000, immutable");
  }
  expect((await request.get("/ur/")).headers()["cache-control"]).toBeUndefined();
});

test("paths without a trailing slash redirect permanently to the slashed page", async ({
  request,
}) => {
  for (const [from, to] of [
    ["/ur", "/ur/"],
    ["/licences", "/licences/"],
    ["/ur/licences", "/ur/licences/"],
  ] as const) {
    const response = await request.get(from, { maxRedirects: 0 });
    expect(response.status()).toBe(308);
    expect(response.headers().location).toBe(to);
  }
});

/** GET `path` from the local server as if it were `host` (the Host header picks the redirect). */
function getAs(
  baseURL: string,
  host: string,
  path: string,
): Promise<{ status: number; location: string | undefined }> {
  const { hostname, port } = new URL(baseURL);
  return new Promise((resolve, reject) => {
    httpRequest({ hostname, port, path, headers: { host } }, (response) => {
      response.resume();
      resolve({ status: response.statusCode ?? 0, location: response.headers.location });
    })
      .on("error", reject)
      .end();
  });
}

/** GET `path` as `host`, as getAs does, and read the whole answer. */
function readAs(
  baseURL: string,
  host: string,
  path: string,
): Promise<{ status: number; type: string | undefined; body: string }> {
  const { hostname, port } = new URL(baseURL);
  return new Promise((resolve, reject) => {
    httpRequest({ hostname, port, path, headers: { host } }, (response) => {
      const chunks: Buffer[] = [];
      response.on("data", (chunk: Buffer) => chunks.push(chunk));
      response.on("end", () => {
        resolve({
          status: response.statusCode ?? 0,
          type: response.headers["content-type"],
          body: Buffer.concat(chunks).toString("utf8"),
        });
      });
    })
      .on("error", reject)
      .end();
  });
}

test("a search engine's ownership file is served as it is, on the origin and each earlier address", async ({
  baseURL,
}) => {
  const publicDirectory = new URL("../../public/", import.meta.url);
  const names = readdirSync(publicDirectory).filter((name) => VERIFICATION_FILE.test(name));
  // The build copies public/ as it is, so dist/ holds the same files, and at least the one
  // the owner's Search Console property asks for.
  expect(names).toContain("google17fd3f30f3354533.html");
  expect(verificationFiles()).toEqual(names.toSorted());
  const hosts = [origins.site.origin, ...origins.site.legacy].map((url) => new URL(url).host);
  for (const name of names) {
    const body = readFileSync(new URL(name, publicDirectory), "utf8");
    for (const host of hosts) {
      expect(await readAs(baseURL ?? "", host, `/${name}`), `${host}/${name}`).toEqual({
        status: 200,
        type: "text/html; charset=utf-8",
        body,
      });
    }
  }
});

test("an ownership file is not a page: not in the suite's page list, nor in Lighthouse's", () => {
  const pages = sitePages().map((page) => page.path);
  expect(pages.filter((path) => VERIFICATION_FILE.test(path.slice(1)))).toEqual([]);
  // lighthouserc.cjs walks dist/ by itself; it must come to the same pages.
  const lighthouse = createRequire(import.meta.url)("../../lighthouserc.cjs") as {
    ci: { collect: { url: string[] } };
  };
  expect(lighthouse.ci.collect.url.map((url) => new URL(url).pathname)).toEqual(pages);
});

test("each earlier address redirects permanently to the same page on the origin", async ({
  baseURL,
}) => {
  for (const legacy of origins.site.legacy) {
    const host = new URL(legacy).host;
    // The replacement patterns of String.prototype.replace ($&, $1, $$, $`) stay as they are; a
    // backtick is percent-encoded in a path, as browsers send it.
    for (const path of [
      "/",
      "/ur/pricing/?utm_source=x&a=%20b",
      "/missing/",
      "/$&/",
      "/$1/",
      "/$$/",
      "/$%60/",
      "/$'/",
    ]) {
      expect(await getAs(baseURL ?? "", host, path), `${host}${path}`).toEqual({
        status: 308,
        location: `${origins.site.origin}${path}`,
      });
    }
    // A target that starts with // is a path on this host, as on Vercel, not another host.
    for (const path of ["//evil.example/", "//evil.example/x/"]) {
      expect(await getAs(baseURL ?? "", host, path), `${host}${path}`).toEqual({
        status: 308,
        location: `${origins.site.origin}${path}`,
      });
    }
    // Vercel adds the trailing slash on the same host first; the next request moves host.
    expect(await getAs(baseURL ?? "", host, "/ur")).toEqual({ status: 308, location: "/ur/" });
    // But not to a path that starts with //: a Location of //ur/ would name the host ur.
    for (const path of ["//ur", "//ur/licences"]) {
      expect(await getAs(baseURL ?? "", host, path), `${host}${path}`).toEqual({
        status: 308,
        location: `${origins.site.origin}${path}`,
      });
    }
    // A path that is not valid percent-encoding is refused.
    for (const path of ["/%zz", "/ur/%ff/"]) {
      expect(await getAs(baseURL ?? "", host, path), `${host}${path}`).toEqual({
        status: 400,
        location: undefined,
      });
    }
  }
  const site = new URL(origins.site.origin).host;
  expect((await getAs(baseURL ?? "", site, "/ur/")).status).toBe(200);
  // On the origin such a path is no page (it is not the home page of the host it names).
  for (const path of ["//evil.example/", "//evil.example/x/"]) {
    expect(await getAs(baseURL ?? "", site, path), `${site}${path}`).toEqual({
      status: 404,
      location: undefined,
    });
  }
  // Nor does a path that starts with // gain a slash there, though /ur/ is a page.
  for (const path of ["//ur", "//ur/licences"]) {
    expect(await getAs(baseURL ?? "", site, path), `${site}${path}`).toEqual({
      status: 404,
      location: undefined,
    });
  }
  // What is not a path, a path that is not valid percent-encoding, and a Host header that is
  // not a host, are refused.
  for (const path of ["/%zz", "/ur/%ff/"]) {
    expect((await getAs(baseURL ?? "", site, path)).status, path).toBe(400);
  }
  expect((await getAs(baseURL ?? "", site, "*")).status).toBe(400);
  expect((await getAs(baseURL ?? "", "evil.example/x", "/")).status).toBe(400);
});

test("missing addresses answer 404 with the not-found page and the same headers", async ({
  request,
}) => {
  for (const path of ["/missing/", "/ur/missing/", "/_astro/missing.css"]) {
    const response = await request.get(path);
    expect(response.status()).toBe(404);
    expect(response.headers()["content-security-policy"]).toContain("default-src 'none'");
    expect(await response.text()).toContain('<meta name="robots" content="noindex">');
  }
});

test("text files are UTF-8 and the licence texts are served beside the fonts", async ({
  request,
}) => {
  for (const path of [
    "/robots.txt",
    "/llms.txt",
    "/llms-full.txt",
    "/licences/ofl-atkinson-hyperlegible-next.txt",
    "/licences/ofl-noto-sans-arabic.txt",
    "/licences/ofl-noto-nastaliq-urdu.txt",
  ]) {
    const response = await request.get(path);
    expect(response.status(), path).toBe(200);
    expect(response.headers()["content-type"]).toBe("text/plain; charset=utf-8");
  }
  const ofl = await (await request.get("/licences/ofl-noto-sans-arabic.txt")).text();
  expect(ofl).toContain("SIL OPEN FONT LICENSE Version 1.1");
});
