// What the server sends: the security headers of vercel.json on every
// response, long-lived caching for hashed assets, redirects and 404s.
import { expect, test } from "@playwright/test";
import { headersFor, readVercelConfig } from "../../scripts/lib/vercel.ts";
import { sitePages } from "./site.ts";

const config = readVercelConfig(new URL("../../vercel.json", import.meta.url));

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
