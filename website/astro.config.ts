import { fileURLToPath } from "node:url";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";
import { loadEnv } from "vite";
import { brandAssets } from "./integrations/brand-assets.ts";
import { siteChecks } from "./integrations/site-checks.ts";
import { resolveSiteUrl } from "./src/config/urls.ts";
import { LOCALE_INFO } from "./src/i18n/locales.ts";
import { sitemapItemWithDefault } from "./src/lib/seo/sitemap.ts";

// SITE_URL comes from the environment (the Vercel project, or website/.env
// locally); see README.md. It defaults to the Vercel production address.
const env = loadEnv(process.env.NODE_ENV ?? "production", process.cwd(), "");
const site = resolveSiteUrl(env.SITE_URL);
const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));

export default defineConfig({
  site,
  trailingSlash: "always",
  build: {
    format: "directory",
    // Every stylesheet is a file, so the Content-Security-Policy in vercel.json
    // needs no 'unsafe-inline' for styles.
    inlineStylesheets: "never",
  },
  i18n: {
    locales: ["en", "ur"],
    defaultLocale: "en",
    routing: { prefixDefaultLocale: false },
  },
  integrations: [
    brandAssets(),
    mdx(),
    sitemap({
      i18n: {
        defaultLocale: "en",
        locales: { en: LOCALE_INFO.en.hreflang, ur: LOCALE_INFO.ur.hreflang },
      },
      filter: (page) => !/\/404\/?$/.test(new URL(page).pathname),
      serialize: sitemapItemWithDefault,
    }),
    siteChecks(),
  ],
  vite: {
    build: {
      // Never inline scripts, styles or fonts as data: URIs; the CSP allows
      // only same-origin files.
      assetsInlineLimit: 0,
    },
    server: {
      // The dev server reads the design tokens and fonts from the repository.
      fs: { allow: [repositoryRoot] },
    },
  },
});
