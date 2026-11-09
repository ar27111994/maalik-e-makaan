// The UAT suite: the release web build in Chromium against a local Supabase
// stack. tool/uat/run.sh starts everything and runs it; docs/uat.md has the
// journeys and the latest report.
import { defineConfig } from "@playwright/test";

const chrome = process.env.UAT_CHROME;

export default defineConfig({
  testDir: "./tests",
  // The journeys share users and data, in order: one worker, no retries
  // (a retry would replay a half-finished journey against changed data).
  workers: 1,
  fullyParallel: false,
  retries: 0,
  timeout: 10 * 60 * 1000,
  expect: { timeout: 20_000 },
  outputDir: "build/test-results",
  reporter: [["list"], ["html", { outputFolder: "build/report", open: "never" }]],
  use: {
    baseURL: process.env.UAT_APP_URL ?? "http://127.0.0.1:8080",
    // A phone-sized window: the app's primary target.
    viewport: { width: 412, height: 915 },
    locale: "en-GB",
    timezoneId: "Asia/Karachi",
    reducedMotion: "reduce",
    actionTimeout: 20_000,
    navigationTimeout: 60_000,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
    launchOptions: chrome ? { executablePath: chrome } : {},
  },
});
