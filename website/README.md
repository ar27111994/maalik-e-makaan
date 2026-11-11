# Maalik-e-Makaan website

The public website of Maalik-e-Makaan (مالکِ مکان): a static [Astro](https://astro.build) site in
English (at `/`) and Urdu (at `/ur/`, right to left, in Nastaliq), hosted on Vercel. It exists for
people and for search and AI tools (decision D-01 in [`.planning/PROJECT.md`](../.planning/PROJECT.md)),
so every page is plain, fast, accessible HTML with no tracking.

## Run it

You need Node 22 (the version in the repository's `.nvmrc`) and npm.

```sh
cd website
npm ci                 # exact versions from package-lock.json
npm run dev            # http://localhost:4321/ with live reload
npm run build          # the static site in dist/
npm run preview        # serve dist/ the way Vercel does (headers, redirects, 404s)
```

| Script                  | What it does                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| `npm run check`         | `astro check`, `tsc --noEmit`, ESLint, Stylelint and `prettier --check`; all must be clean         |
| `npm run lint`          | ESLint and Stylelint only                                                                          |
| `npm run format`        | Prettier, writing changes                                                                          |
| `npm test`              | Vitest unit and property tests, including every vector in `contracts/rent_math_vectors.json`       |
| `npm run test:links`    | checks every link, image and `#fragment` in `dist/` (no network)                                   |
| `npm run test:e2e`      | the link check, then Playwright against `dist/` (build first)                                      |
| `npm run lighthouse`    | Lighthouse CI on every page of `dist/`, mobile profile; each category must score 95 or more        |
| `npm run lighthouse:ci` | the same on eight pages (home, a guide, a calculator and the FAQ, in both languages); CI runs this |
| `npm run og`            | redraws the Open Graph images and icons in `public/` (after `npm run build`)                       |

`make test-web` at the repository root runs `npm run check`, `npm test`, `npm run deck`,
`npm run build`, `npm run test:e2e` and `npm run lighthouse:ci`, the same sequence as CI's
`website` job. The deck comes before the build because the company page links to its PDF, which
is not kept in the repository, and the link check fails without it.

Playwright is pinned to 1.64.1 and uses its own Chromium build (156, build 1248), installed in CI
by `npx playwright install --with-deps chromium`. The development environment's
`PLAYWRIGHT_BROWSERS_PATH` holds an older build (1243, from Playwright 1.63.0) until it is
re-provisioned; run there with `PW_CHROMIUM_PATH=/opt/pw-browsers/chromium`. Set `PW_CHROMIUM_PATH` to run the e2e suite on
another Chromium binary. Lighthouse CI uses the same Chromium (`chromium.executablePath()` from
Playwright), or `LIGHTHOUSE_CHROME_PATH`, then `PW_CHROMIUM_PATH`, when set; it ignores the generic
`CHROME_PATH`, which may name a different system Chrome. Astro's anonymous build telemetry is
switched off in the scripts.

## Environment variables

Both are optional. Set them in the Vercel project for deploys, or in `website/.env` locally (copy
[`.env.example`](.env.example)). The build validates them and fails on a malformed value.

| Variable         | Default                                   | Used for                                                                       |
| ---------------- | ----------------------------------------- | ------------------------------------------------------------------------------ |
| `SITE_URL`       | `https://maalik-e-makaan-site.vercel.app` | canonical URLs, hreflang links, Open Graph URLs, sitemap, robots.txt, llms.txt |
| `PUBLIC_APP_URL` | `https://maalik-e-makaan.vercel.app`      | the "Open the web app" links and the SoftwareApplication structured data       |

The defaults are the production addresses of the two Vercel projects: this site
(`maalik-e-makaan-site`) and the Flutter web app (`maalik-e-makaan`, whose own `APP_URL` is the same
address). When either moves to a custom domain, set the variable to the new origin (https only, no
path for `SITE_URL`) and redeploy; nothing else changes.

## Deploying on Vercel

The Deploy workflow's `site` job builds and deploys the site (`vercel build --prod`, then
`vercel deploy --prebuilt --prod`) and smoke-tests it; see
[`docs/operations.md`](../docs/operations.md). The Vercel project `maalik-e-makaan-site` uses the
root directory `website/` and the Astro framework preset. [`vercel.json`](vercel.json) fixes the rest: `npm ci`, `npm run build`, the `dist/` output,
trailing slashes and the response headers.

- The build reads files outside `website/`: the design tokens (`../design/tokens/`), the fonts and
  their licences (`../packages/mm_ui/assets/fonts/`). Keep the project setting "Include files
  outside the root directory in the Build Step" switched on (Vercel's default).
- Vercel serves `dist/404.html` for every missing address, in either language, with status 404.
  That page is English and carries a short Urdu note with a link to the Urdu home page; the Urdu
  not-found page (`/ur/404/`) is the same the other way round.

### Security headers

Every response carries (see `vercel.json`, checked by `tests/unit/vercel.test.ts` and
`tests/e2e/http.spec.ts`):

- a strict `Content-Security-Policy`: `default-src 'none'`, scripts, styles, fonts and images from
  the site itself only, no inline script or style, `frame-ancestors 'none'`, `base-uri 'none'`,
  `upgrade-insecure-requests` and Trusted Types (`require-trusted-types-for 'script'`);
- `Strict-Transport-Security` (two years, sub-domains), `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, a
  `Permissions-Policy` that turns off camera, microphone, location, payment and similar features,
  and `Cross-Origin-Opener-Policy: same-origin`.

Hashed files in `/_astro/` are cached for a year (`immutable`). To keep within the policy:

- Astro is set to write every stylesheet as a file (`build.inlineStylesheets: "never"`) and never
  to inline assets (`vite.build.assetsInlineLimit: 0`).
- The build fails if a page has an inline `<script>`, `<style>`, `style=""` or `on…=` handler
  (`integrations/site-checks.ts`). JSON-LD blocks are data, not scripts, and are allowed.
- Scripts added later (the calculators) must be modules in `src/`, which Astro bundles as files.
  Because of Trusted Types they must build DOM with `textContent` and `createElement`, never
  `innerHTML`; the e2e suite fails on any console error, including a blocked sink.

### Privacy

No cookies, analytics, trackers, third-party scripts or third-party requests. Fonts and images are
served from the site. The e2e suite fails if a page makes a request that fails or logs an error.

## How the code is organised

```text
website/
  astro.config.ts          site URL, i18n routing, integrations
  integrations/
    brand-assets.ts        font subsets and the type scale, generated from the design system
    site-checks.ts         build guards: every page in both languages, no inline code
  src/
    pages/                 routes: one thin file per language (index.astro, ur/index.astro, …)
    page-components/       the pages themselves, each taking a `locale`
    layouts/BaseLayout.astro   <head>, skip link, header, breadcrumbs, main, footer
    components/            Seo, JsonLd, SiteHeader, LanguageSwitch, Breadcrumbs, Receipt, …
    components/tools/      the calculator form, its result and each calculator's script tag
    content/               the copy, in en and ur: home/, features/, how-it-works/, faq/,
                           download/, licences/ (YAML); guides/, tools/, pages/ (Markdown)
    i18n/                  locales and URL mapping, the interface strings, script detection
    lib/money/             exact money and rent arithmetic for the calculators (integer paisa)
    lib/tax/s155.ts        section 155 withholding on rent, TY2027 (the FBR rate card)
    lib/markdown/          build-time touches to rendered Markdown (scrollable tables)
    tools/                 the calculators: inputs, parsing, results and their wording
    scripts/calculator.ts  the one browser script: recalculates and announces results
    lib/seo/               JSON-LD builders, titles, Open Graph, sitemap entries
    lib/llms.ts, robots.ts llms.txt, llms-full.txt and robots.txt, built from the content
    styles/global.css      base styles on the design tokens
    generated/             (git-ignored) font subsets, @font-face rules, type scale
  scripts/                 serve.ts (local Vercel), check-links.ts, generate-og.ts
  tests/unit/              Vitest
  tests/e2e/               Playwright
```

### Design system

- Colours, spacing, radii, sizes and motion come from
  [`design/tokens/maalik.tokens.css`](../design/tokens/maalik.tokens.css), imported as it is by
  `src/styles/global.css`. It is generated from `maalik.tokens.json` by `make tokens`; never copy
  or edit it here. Light and dark follow `prefers-color-scheme`, high contrast follows
  `prefers-contrast`, and `forced-colors` keeps every control outlined.
- The type scale (`--mm-type-*`) and the `@font-face` rules are generated at build time from the
  same tokens file and from the app's fonts in `packages/mm_ui/assets/fonts/`: Atkinson Hyperlegible
  Next for English and figures, Noto Nastaliq Urdu for Urdu, both under the SIL Open Font License
  1.1. The build subsets them to the characters the site needs (the whole Urdu alphabet, plus
  every Arabic-script character found in `src/`) and converts them to WOFF2; the licence texts are
  served at `/licences/*.txt` and listed on the licences page.
- Stylelint allows logical properties only (so every margin, padding, inset, border and alignment
  mirrors in Urdu) and colours only from `--mm-color-*` custom properties: no hex, named or
  functional colour literals.

### Calculators

The three calculators (`/tools/…`) are pure modules in `src/tools/`: each lists its inputs, reads
what the reader typed (Western or Urdu digits, commas, `Rs`, `lakh`) and returns a result with a
one-sentence summary, the figures, the working step by step and its caveats. The page is built with
the result for the default inputs, so it reads fully without JavaScript (a `<noscript>` note says
so); the bundled script `src/scripts/calculator.ts` recalculates on submit, builds the same markup
with `createElement` (Trusted Types forbid `innerHTML`) and announces the summary in the
`role="status"` live region. The e2e suite checks that the two renderings match.

The s.155 calculator uses only the rates and thresholds in
[`website-facts.md`](../.planning/research/website-facts.md) §3.4, tested at every band edge, shows
withholding only (never final tax, D-10) and flags the uncertain non-ATL individual column.

### Money and rent maths

`src/lib/money/` mirrors `packages/mm_core` (`money.dart`, `rent_math.dart`,
`late_fee_policy.dart` and the calendar types). Money is an integer number of paisa held in a
`bigint`; every rounding is explicit and happens once. `tests/unit/rent-math-contract.test.ts`
checks every vector in `contracts/rent_math_vectors.json`, the same file the Dart and SQL suites
check, so a calculator on this site always agrees with the app and the database.

Property tests written with [fast-check](https://fast-check.dev/) check the rules for any input
in range, not only the examples: amounts stay whole paisa, rounding lands within half a step,
allocations keep every paisa, withholding never falls as rent rises, a longer tenancy or a higher
increase never gives less, and what a calculator writes it reads back. They live in
`tests/unit/money.test.ts`, `money-format.test.ts`, `rent-math.test.ts`, `s155.test.ts` and
`tools-properties.test.ts`, with the shared arbitraries in `tests/unit/arbitraries.ts`. Each run
uses a new seed and 500 cases a property; a failure prints the seed and the shrunk counterexample,
and `FC_NUM_RUNS=100000 npm test` searches longer.

As in the app's `MoneyFormat`, "Rs", "روپے", "lakh" and "کروڑ" are joined to the figures by a
no-break space (U+00A0), so an amount never breaks across lines. The copy in `src/content/` does the
same, and `tests/unit/content-markdown.test.ts` fails on an ordinary space there.

## Content and translations

Every page exists in English and Urdu. The URL is the same apart from the `/ur` prefix, and slugs
stay in English, so the language switch always leads to the same page. Each page lists its twin
in `hreflang` links (`en`, `ur` and `x-default`, which is the English page), and the build fails if
a page lacks its twin.

- Page copy lives in `src/content/` as YAML (or Markdown for guides), one file per language, with
  a schema in `src/lib/content/schemas.ts`. Unit tests check that both files of a pair have the
  same shape.
- The words around the pages (navigation, footer, notices) are in `src/i18n/ui.ts`; TypeScript
  requires every key in both languages.
- English is British English. Urdu is natural, respectful Urdu in Urdu script, never Roman Urdu.
  A Latin-script word on an Urdu page goes inside an element with `lang="en"` (and an Urdu word on
  an English page inside `lang="ur"`); the e2e suite fails otherwise.
- Legal and tax content is informational: dated, citing official sources inline, and saying
  plainly that it is not legal or tax advice. The facts come from
  [`.planning/research/website-facts.md`](../.planning/research/website-facts.md).

### Add a page

1. Write the copy for both languages (a YAML pair in `src/content/<page>/` with a schema, or
   strings in `src/i18n/ui.ts`).
2. Make a page component in `src/page-components/` that takes `locale` and renders inside
   `BaseLayout` with the page's locale-neutral `path`, its `title`, `description` and
   `breadcrumbs`.
3. Add the two thin routes, for example `src/pages/<page>/index.astro` and
   `src/pages/ur/<page>/index.astro`.
4. Run `npm run build` and `npm run test:e2e`: the page is found in `dist/` and gets every check
   (accessibility in light and dark, keyboard, hreflang, structured data, links, scripts, fonts).

### Add a guide

Add `src/content/guides/en/<slug>.md` and `src/content/guides/ur/<slug>.md`; see
[`src/content/guides/README.md`](src/content/guides/README.md) for the front matter and the
writing rules. The guide appears at `/guides/<slug>/` and `/ur/guides/<slug>/`, in the sitemap,
in `llms.txt` and `llms-full.txt`, with Article and BreadcrumbList structured data, its review
date, the not-advice notice and its sources. Until the first guide exists the build logs that
the `guides` collection is empty; that warning is expected.

### Pages that update themselves

- **Release:** `src/lib/release.ts` reads `CHANGELOG.md` and `.release-please-manifest.json` at
  build time for the download page's release block, the release notes page (`/releases/`), the
  footer and `llms.txt`; from 1.0.0 it switches the site from "in development" to "available".
  The download page links to the files attached to that release on GitHub; the Deploy workflow
  checks that each one is there before it publishes the site.
- **Roadmap:** `/roadmap/` renders `src/data/roadmap.json`, which `tool/github/fetch_roadmap.py`
  writes from GitHub's roadmap milestones and issues before a deploy (`make roadmap` rewrites the
  committed copy from `.github/roadmap.toml`). It leaves out issues opened outside the project,
  whose authors could retitle them, and issues closed as not planned or as duplicates. On the Urdu
  page, a title or description GitHub has only in English is set `lang="en" dir="ltr"`.
- **Pitch deck:** `npm run deck` renders `deck/` to `public/pitch/` (not committed); the company
  page (`/company/`) links to it. See [`deck/README.md`](deck/README.md).
- **Pricing:** `/pricing/` is copy in `src/content/pricing/`; billing is not switched on in the app.

## Search and AI tools

- Each page has a title, description, canonical URL, `hreflang` alternates, Open Graph and Twitter
  tags (with 1200 × 630 images in `public/og/`) and one JSON-LD graph: Organization and WebSite on
  every page, the page itself, SoftwareApplication and the FAQPage questions on the home page,
  BreadcrumbList on inner pages, Article on guides.
- `sitemap-index.xml` lists every indexable page with its `en`, `ur` and `x-default` alternates.
- `robots.txt` allows every crawler and names the search and AI crawlers (GPTBot, ClaudeBot,
  Google-Extended, PerplexityBot, CCBot and others) explicitly.
- `llms.txt` and `llms-full.txt` follow [llmstxt.org](https://llmstxt.org) and are generated from
  the same content as the pages.

## Dependencies

Every version in `package.json` is exact, and every package in `package-lock.json` was published
at least seven days before it was locked; install new versions with
`npm install --before=<a date a week ago>`. `overrides` in `package.json`:

| Override                                                                                       | Why                                                                                       |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `eslint-plugin-jsx-a11y` → `eslint: $eslint`                                                   | its 6.10.2 peer range stops at ESLint 9; it runs on ESLint 10 (checked by the lint suite) |
| `minimatch@>=10.0.0 <11.0.1` → 11.0.3, `@eslint/config-array` → `minimatch` 11.0.3             | GHSA-g3hv-75wg-m249 in ESLint's minimatch                                                 |
| `lighthouse` → 13.6.0                                                                          | Lighthouse CI 0.15.1 pins 12.6.1, whose puppeteer chain carries advisories                |
| `tmp` → 0.2.7, `uuid` → 11.1.1, `basic-ftp` → 6.2.3, `@sentry/bundler-plugins` → `glob` 14.0.3 | advisories in Lighthouse CI's dependencies                                                |
| `playwright-core` → 1.64.1                                                                     | keeps `@axe-core/playwright` on the same Playwright as the tests and their browser        |

`npm audit` reports no vulnerabilities with these overrides.
