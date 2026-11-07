import { defineConfig, devices } from "@playwright/test";

const port = 4322;

/**
 * End-to-end tests against the built site (run `npm run build` first), served
 * by scripts/serve.ts with the headers and not-found handling of vercel.json.
 * Chromium is the version Playwright 1.63.0 pins; it is preinstalled, so this
 * suite never downloads a browser.
 */
export default defineConfig({
  testDir: "tests/e2e",
  globalSetup: "./tests/e2e/global-setup.ts",
  fullyParallel: true,
  forbidOnly: process.env.CI !== undefined,
  retries: 0,
  reporter: process.env.CI === undefined ? [["list"]] : [["list"], ["github"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: `http://127.0.0.1:${port}`,
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium" }],
  webServer: {
    command: `node scripts/serve.ts --port ${port}`,
    url: `http://127.0.0.1:${port}/`,
    reuseExistingServer: process.env.CI === undefined,
    stdout: "ignore",
    stderr: "pipe",
  },
});
