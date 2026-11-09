import { defineConfig, devices } from "@playwright/test";

const port = 4322;

/**
 * End-to-end tests against the built site (run `npm run build` first), served
 * by scripts/serve.ts with the headers and not-found handling of vercel.json.
 *
 * The browser is Playwright's own Chromium, the build 1.64.1 pins, installed by
 * `npx playwright install --with-deps chromium` in CI. Set PW_CHROMIUM_PATH to
 * run another Chromium binary instead.
 */
const chromiumPath = process.env.PW_CHROMIUM_PATH;
const ci = process.env.CI !== undefined;

export default defineConfig({
  testDir: "tests/e2e",
  globalSetup: "./tests/e2e/global-setup.ts",
  fullyParallel: true,
  forbidOnly: ci,
  retries: 0,
  // In CI, also an HTML report (playwright-report/), uploaded when the job fails.
  reporter: ci ? [["list"], ["github"], ["html", { open: "never" }]] : [["list"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: `http://127.0.0.1:${port}`,
    trace: "retain-on-failure",
    launchOptions: chromiumPath === undefined ? {} : { executablePath: chromiumPath },
  },
  projects: [{ name: "chromium" }],
  webServer: {
    command: `node scripts/serve.ts --port ${port}`,
    url: `http://127.0.0.1:${port}/`,
    reuseExistingServer: !ci,
    stdout: "ignore",
    stderr: "pipe",
  },
});
