/**
 * Serves the built site (dist/) the way Vercel does: the headers of
 * vercel.json, trailing-slash redirects, index.html for directories and
 * dist/404.html with status 404 for anything missing. The e2e suite and
 * Lighthouse run against it.
 *
 *   node scripts/serve.ts [--port 4321]
 */
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, normalize, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { headersFor, readVercelConfig, trailingSlashRedirect } from "./lib/vercel.ts";

const { values } = parseArgs({ options: { port: { type: "string", default: "4321" } } });
const port = Number(values.port);
const root = new URL("../", import.meta.url);
const dist = fileURLToPath(new URL("dist/", root));
const config = readVercelConfig(new URL("vercel.json", root));

const TYPES: Readonly<Record<string, string>> = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
};

async function isFile(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isFile();
  } catch {
    return false;
  }
}

/** The file in dist/ for a URL path, or undefined. Paths cannot escape dist/. */
async function resolveFile(pathname: string): Promise<string | undefined> {
  const relative = pathname.endsWith("/") ? `${pathname}index.html` : pathname;
  const path = normalize(`${dist}${decodeURIComponent(relative)}`);
  if (!path.startsWith(dist) || path.includes(`${sep}..${sep}`)) return undefined;
  return (await isFile(path)) ? path : undefined;
}

const server = createServer((request, response) => {
  void (async () => {
    const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
    const pathname = url.pathname;
    const headers = headersFor(config, pathname);
    const redirect = trailingSlashRedirect(config, pathname);
    if (redirect !== undefined && (await resolveFile(redirect)) !== undefined) {
      response.writeHead(308, { ...headers, location: `${redirect}${url.search}` }).end();
      return;
    }
    const file = await resolveFile(pathname);
    const served = file ?? `${dist}404.html`;
    response.writeHead(file === undefined ? 404 : 200, {
      "content-type": TYPES[extname(served)] ?? "application/octet-stream",
      ...headers,
    });
    if (request.method === "HEAD") {
      response.end();
      return;
    }
    createReadStream(served).pipe(response);
  })().catch((error: unknown) => {
    console.error(error);
    response.writeHead(500).end();
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Serving ${dist} at http://127.0.0.1:${port}/ (Ctrl+C to stop)`);
});
