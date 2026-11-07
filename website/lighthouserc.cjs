// Lighthouse CI: every built page, on Lighthouse's default mobile profile
// (a mid-range phone on a slow 4G connection), against the local server that
// sends vercel.json's headers. Each category must score 95 or more. The
// not-found pages are kept out of search on purpose (noindex), so their SEO
// category is not scored; everything else is.
//
//   npm run build && npm run lighthouse
//
// Chromium is the browser Playwright 1.63.0 pins and the environment
// preinstalls (no download); set LIGHTHOUSE_CHROME_PATH to use another.
const { readdirSync, statSync } = require("node:fs");
const { join, relative } = require("node:path");
const { chromium } = require("@playwright/test");

const port = 4323;
const dist = join(__dirname, "dist");
const NOT_FOUND = ["/404.html", "/ur/404/"];

/** @param {string} directory @returns {string[]} */
function walk(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

const pages = walk(dist)
  .filter((file) => file.endsWith(".html"))
  .map((file) => `/${relative(dist, file).replace(/index\.html$/, "")}`)
  .sort();

/**
 * The 95 budget, judged on the median of the runs (Lighthouse CI's default
 * would take the best run).
 * @param {boolean} seo
 */
const scores = (seo) => {
  const budget = ["error", { minScore: 0.95, aggregationMethod: "median" }];
  return {
    "categories:performance": budget,
    "categories:accessibility": budget,
    "categories:best-practices": budget,
    "categories:seo": seo ? budget : "off",
  };
};

module.exports = {
  ci: {
    collect: {
      startServerCommand: `node scripts/serve.ts --port ${port}`,
      startServerReadyPattern: "Serving",
      url: pages.map((path) => `http://127.0.0.1:${port}${path}`),
      numberOfRuns: 3,
      chromePath: process.env.LIGHTHOUSE_CHROME_PATH ?? chromium.executablePath(),
      settings: {
        onlyCategories: ["performance", "accessibility", "best-practices", "seo"],
        // --no-sandbox: Chromium will not start as root (CI containers) without it.
        chromeFlags: "--headless=new --no-sandbox",
      },
    },
    assert: {
      assertMatrix: [
        {
          matchingUrlPattern: `^http://127\\.0\\.0\\.1:${port}/(?!404\\.html$|ur/404/$)`,
          assertions: scores(true),
        },
        {
          matchingUrlPattern: `^http://127\\.0\\.0\\.1:${port}/(404\\.html|ur/404/)$`,
          assertions: scores(false),
        },
      ],
    },
    upload: { target: "filesystem", outputDir: "./.lighthouseci/reports" },
  },
};

if (!NOT_FOUND.every((path) => pages.includes(path))) {
  throw new Error("Run `npm run build` first: dist/ has no not-found pages.");
}
