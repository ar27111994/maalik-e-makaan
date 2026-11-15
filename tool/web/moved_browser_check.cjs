#!/usr/bin/env node
// Loads the page an earlier address of the web app answers with (package_vercel.py:
// moved.html and moved.js) in Chromium, served with the package's own routes and headers
// (serve_output.py), and checks what a person's browser does there:
//
// 1. With the response's Clear-Site-Data: "storage", everything the earlier address kept is
//    gone (localStorage, another site's keys too, and IndexedDB) and the browser is at the
//    same path, query and #fragment on the app's origin.
// 2. Without the header, as in a browser that does not know it: the script alone removes the
//    app's own keys, leaves any other, and goes to the same address.
// 3. Without scripts: the browser goes to the origin's first page.
// 4. The App Links file and the app's files clear nothing.
// 5. Nothing breaks the app's Content-Security-Policy.
// 6. A late e-mail link (docs/operations.md, Domains, step 12): /auth/callback?code=... is
//    cleared like any other path, so the sign-in verifier goes with the header (as part of
//    everything the earlier address kept) and with the script alone (as one of the app's own
//    keys), and the browser arrives at the same path and query on the origin.
//
//   node tool/web/moved_browser_check.cjs OUTPUT_DIR
//
// The addresses are those of contracts/origins.json. The earlier address is resolved to this
// machine and treated as a secure origin, since a browser ignores Clear-Site-Data from plain
// http anywhere but localhost; the origin's pages are answered here, not fetched. Needs the
// `playwright` package and a Chromium (PW_CHROMIUM_PATH names one other than Playwright's).
"use strict";

const { spawn } = require("node:child_process");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");

const origins = JSON.parse(
  readFileSync(path.join(__dirname, "../../contracts/origins.json"), "utf8"),
).app;

// What the app keeps in a browser (docs/architecture/app.md), by example, and a key of no app.
const APP_KEYS = [
  "mm.swr.v1.tenants",
  "mm.settings.locale",
  "mm.portfolio.current",
  "mm.invitation.pending",
  "sb-abcdefghijklmnop-auth-token",
  "flutter.supabase.auth.token-code-verifier",
];
const OTHER_KEY = "another-site";
// A file of the earlier address that never clears and runs nothing: where storage is written
// and read back.
const NEUTRAL = "/.well-known/assetlinks.json";

function startServer(output) {
  const script = path.join(__dirname, "serve_output.py");
  const child = spawn("python3", [script, output, "--port", "0"], {
    stdio: ["ignore", "pipe", "inherit"],
  });
  return new Promise((resolve, reject) => {
    let buffer = "";
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      const match = buffer.match(/on http:\/\/[^:]+:(\d+)\//);
      if (match) resolve({ child, port: match[1] });
    });
    child.on("exit", (code) => reject(new Error(`server exited with ${code}`)));
  });
}

/** Writes the app's keys, another one and an IndexedDB database on the page's origin. */
async function seed(page, old) {
  await page.goto(old + NEUTRAL);
  await page.evaluate(
    async ([keys, other]) => {
      for (const key of [...keys, other]) localStorage.setItem(key, "kept");
      await new Promise((resolve, reject) => {
        const request = indexedDB.open("kept", 1);
        request.onsuccess = () => {
          request.result.close();
          resolve();
        };
        request.onerror = () => reject(request.error);
      });
    },
    [APP_KEYS, OTHER_KEY],
  );
}

/** What the page's origin still keeps: its localStorage keys and IndexedDB databases. */
async function kept(page, old) {
  await page.goto(old + NEUTRAL);
  return page.evaluate(async () => ({
    keys: Object.keys(localStorage).sort(),
    databases: (await indexedDB.databases()).map((database) => database.name),
  }));
}

/** Opens `from` and waits until the browser is at `to` (the page replaces itself on the way). */
async function arrive(page, from, to) {
  await page.goto(from).catch(() => {});
  await page.waitForURL((url) => url.href === to, { timeout: 15000 }).catch(() => {});
}

/** A page of a new context, in which the origin's pages are answered here. */
async function newPage(browser, problems, options = {}) {
  const context = await browser.newContext(options);
  await context.route(`${origins.origin}/**`, (route) =>
    route.fulfill({ contentType: "text/html", body: "<title>the app</title>" }),
  );
  const page = await context.newPage();
  page.on("console", (message) => {
    if (message.type() === "error" || /Content.Security.Policy/i.test(message.text())) {
      problems.push(`console ${message.type()}: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  return page;
}

async function main() {
  const output = process.argv[2];
  if (!output) throw new Error("usage: moved_browser_check.cjs OUTPUT_DIR");
  const [legacy] = origins.legacy;
  if (!legacy) throw new Error("contracts/origins.json names no earlier address of the web app");
  const host = new URL(legacy).hostname;
  const { child, port } = await startServer(output);
  const old = `http://${host}:${port}`;
  const browser = await chromium.launch({
    executablePath: process.env.PW_CHROMIUM_PATH || undefined,
    args: [
      `--host-resolver-rules=MAP ${host} 127.0.0.1`,
      `--unsafely-treat-insecure-origin-as-secure=${old}`,
    ],
  });
  const problems = [];
  const expect = (what, got, wanted) => {
    const same = JSON.stringify(got) === JSON.stringify(wanted);
    console.log(`${same ? "ok" : "FAILED"}: ${what}`);
    if (!same) problems.push(`${what}: got ${JSON.stringify(got)}, not ${JSON.stringify(wanted)}`);
  };
  const deep = "/invite?x=1&y=%20#token=abc";
  const callback = "/auth/callback?code=late-link";
  try {
    // 1. The header and the script, as in a browser that knows the header.
    let page = await newPage(browser, problems);
    await seed(page, old);
    await arrive(page, old + deep, origins.origin + deep);
    expect("with the header: the same page on the origin", page.url(), origins.origin + deep);
    expect("with the header: nothing is kept", await kept(page, old), { keys: [], databases: [] });

    // 6. A late e-mail link, with the header.
    await seed(page, old);
    await arrive(page, old + callback, origins.origin + callback);
    expect("a late link, with the header: on the origin", page.url(), origins.origin + callback);
    expect("a late link, with the header: nothing is kept", await kept(page, old), {
      keys: [],
      databases: [],
    });

    // 4. What the earlier address keeps answering clears nothing, however it is requested.
    await seed(page, old);
    const statuses = await page.evaluate(
      (paths) =>
        Promise.all(
          paths.map(async (item) => {
            const response = await fetch(item);
            await response.arrayBuffer();
            return response.status;
          }),
        ),
      [NEUTRAL, "/main.dart.js", "/moved.js"],
    );
    expect("the kept paths answer", statuses, [200, 200, 200]);
    expect("the kept paths clear nothing", await kept(page, old), {
      keys: [...APP_KEYS, OTHER_KEY].sort(),
      databases: ["kept"],
    });
    await page.context().close();

    // 2. The script alone: the header is taken off the page's response before the browser's
    // network code sees it, as for a browser that does not know it.
    page = await newPage(browser, problems);
    await page.context().route(`${old}/**`, async (route) => {
      // Fetched by Node, which does not know the browser's mapping of the host.
      const request = route.request();
      const response = await route.fetch({
        url: request.url().replace(old, `http://127.0.0.1:${port}`),
        headers: { ...request.headers(), host: `${host}:${port}` },
      });
      const headers = { ...response.headers() };
      delete headers["clear-site-data"];
      await route.fulfill({ response, headers });
    });
    await seed(page, old);
    await arrive(page, old + deep, origins.origin + deep);
    expect("without the header: the same page on the origin", page.url(), origins.origin + deep);
    expect("without the header: only the app's keys are gone", await kept(page, old), {
      keys: [OTHER_KEY],
      databases: ["kept"],
    });
    // 6. A late e-mail link, with the script alone: the verifier and the session go too.
    await seed(page, old);
    await arrive(page, old + callback, origins.origin + callback);
    expect("a late link, without the header: on the origin", page.url(), origins.origin + callback);
    expect("a late link, without the header: only the app's keys are gone", await kept(page, old), {
      keys: [OTHER_KEY],
      databases: ["kept"],
    });
    await arrive(page, `${old}/index.html?from=mail`, `${origins.origin}/?from=mail`);
    expect("the first page in another spelling", page.url(), `${origins.origin}/?from=mail`);
    await page.context().close();

    // 3. Without scripts.
    page = await newPage(browser, problems, { javaScriptEnabled: false });
    await arrive(page, old + deep, `${origins.origin}/`);
    expect("without scripts: the origin's first page", page.url(), `${origins.origin}/`);
    await page.context().close();
  } finally {
    await browser.close();
    child.kill();
  }
  for (const problem of problems) console.error(`error: ${problem}`);
  if (problems.length > 0) process.exit(1);
  console.log(`The page of ${host} clears its storage and goes to ${origins.origin}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
