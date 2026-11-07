#!/usr/bin/env node
// Loads the packaged web app (package_vercel.py output) in Chromium, served
// with the same headers, CSP and fallback as production (serve_output.py),
// and fails on CSP violations, console errors or a Flutter app that does not
// start. Network failures are allowed only for the hosts given with
// --offline-host (the placeholder Supabase project of a test build).
//
//   node tool/web/browser_check.cjs OUTPUT_DIR [--offline-host HOST]...
//       [--screenshot FILE] [--click BUTTON_LABEL | --type TEXT]...
//
// On "/", the --click and --type actions run in order: --click presses a
// button by its accessible name, each --type fills the next text field. Text
// outside the bundled fonts makes Flutter fetch fallback fonts, and a sign-in
// reaches Supabase; the CSP must allow both.
//
// Needs the `playwright` package and its Chromium (npx playwright install chromium).
"use strict";

const { spawn } = require("node:child_process");
const path = require("node:path");
const { chromium } = require("playwright");

function parseArgs(argv) {
  const args = { offlineHosts: [], actions: [], screenshot: null, output: null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--offline-host") args.offlineHosts.push(argv[++i]);
    else if (arg === "--screenshot") args.screenshot = argv[++i];
    else if (arg === "--click") args.actions.push({ click: argv[++i] });
    else if (arg === "--type") args.actions.push({ type: argv[++i] });
    else if (!args.output) args.output = arg;
    else throw new Error(`unexpected argument ${arg}`);
  }
  if (!args.output) throw new Error("usage: browser_check.cjs OUTPUT_DIR [options]");
  return args;
}

function startServer(output) {
  const script = path.join(__dirname, "serve_output.py");
  const child = spawn("python3", [script, output, "--port", "0"], {
    stdio: ["ignore", "pipe", "inherit"],
  });
  return new Promise((resolve, reject) => {
    let buffer = "";
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      const match = buffer.match(/on (http:\/\/\S+)\//);
      if (match) resolve({ child, base: match[1] });
    });
    child.on("exit", (code) => reject(new Error(`server exited with ${code}`)));
  });
}

// Records CSP violations from inside the page, before any script runs.
const RECORD_VIOLATIONS = () => {
  window.__cspViolations = [];
  document.addEventListener("securitypolicyviolation", (event) => {
    window.__cspViolations.push(
      `${event.effectiveDirective} blocked ${event.blockedURI || "inline"} (${event.sourceFile}:${event.lineNumber})`,
    );
  });
};

async function checkPage(browser, base, route, args) {
  const page = await browser.newPage();
  const problems = [];
  const requests = new Set();
  const offline = [];
  page.on("console", (message) => {
    if (message.type() === "error" || /Content.Security.Policy/i.test(message.text())) {
      // A failed request also logs "Failed to load resource"; it is judged by requestfailed.
      if (!/^Failed to load resource/.test(message.text())) {
        problems.push(`console ${message.type()}: ${message.text()}`);
      }
    }
  });
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  const crossOrigin = [];
  page.on("request", (request) => {
    const url = new URL(request.url());
    requests.add(url.origin);
    if (!request.url().startsWith(base)) crossOrigin.push(`${url.origin}${url.pathname}`);
  });
  page.on("requestfailed", (request) => {
    const url = new URL(request.url());
    const failure = `${request.failure()?.errorText} ${url.origin}${url.pathname}`;
    if (args.offlineHosts.includes(url.hostname)) offline.push(failure);
    else problems.push(`request failed: ${failure}`);
  });
  page.on("response", (response) => {
    if (response.status() >= 400) problems.push(`HTTP ${response.status()} ${response.url()}`);
  });
  await page.addInitScript(RECORD_VIOLATIONS);

  const response = await page.goto(base + route, { waitUntil: "load" });
  const html = await response.text();
  if (response.status() !== 200 || !html.includes("flutter_bootstrap.js")) {
    problems.push(`${route} did not answer 200 with index.html`);
  }
  let text = "";
  try {
    // Flutter mounts its view, then (once asked) the semantics tree.
    await page.waitForSelector("flutter-view", { timeout: 30000 });
    await page.waitForSelector("flt-semantics-placeholder", { state: "attached", timeout: 30000 });
    await page.evaluate(() => document.querySelector("flt-semantics-placeholder").click());
    await page.waitForSelector("flt-semantics-host", { state: "attached", timeout: 15000 });
    await page.waitForFunction(
      () => document.querySelector("flt-semantics-host")?.innerText.trim().length > 0,
      null,
      { timeout: 15000 },
    );
    text = await page.evaluate(() =>
      document.querySelector("flt-semantics-host").innerText.replace(/\s+/g, " ").trim(),
    );
    let field = 0;
    for (const action of args.actions) {
      if (action.click) {
        await page.getByRole("button", { name: action.click }).first().click({ timeout: 15000 });
      } else {
        const input = page.locator("flt-semantics-host input, flt-semantics-host textarea");
        await input.nth(field).waitFor({ state: "attached", timeout: 15000 });
        await input.nth(field++).click({ force: true });
        await page.keyboard.type(action.type);
      }
      await page.waitForTimeout(2000);
    }
  } catch (error) {
    problems.push(`app did not start or respond: ${error.message.split("\n")[0]}`);
  }
  await page.waitForTimeout(1500);
  const violations = await page.evaluate(() => window.__cspViolations);
  problems.push(...violations.map((v) => `CSP violation: ${v}`));
  if (args.screenshot && route === "/") await page.screenshot({ path: args.screenshot });
  const result = {
    route,
    finalUrl: page.url(),
    text,
    origins: [...requests].sort(),
    crossOrigin,
    offline,
    problems,
  };
  await page.close();
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const { child, base } = await startServer(path.resolve(args.output));
  const browser = await chromium.launch();
  let failed = false;
  try {
    const deep = `/no/such/${Math.random().toString(36).slice(2)}/path`;
    for (const route of ["/", "/auth/callback?code=x", deep]) {
      const result = await checkPage(browser, base, route, route === "/" ? args : { ...args, actions: [] });
      console.log(JSON.stringify(result, null, 2));
      if (result.problems.length > 0) failed = true;
    }
  } finally {
    await browser.close();
    child.kill();
  }
  console.log(failed ? "FAILED" : "OK: the app starts under the production headers on every route");
  process.exit(failed ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
