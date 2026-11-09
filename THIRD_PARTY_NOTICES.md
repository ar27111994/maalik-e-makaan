# Third-party notices

Maalik-e-Makaan is MIT-licensed ([LICENSE](LICENSE)). This page lists the
third-party software and fonts it uses directly, with the version this
repository pins and its licence, and what each licence asks of us when we
ship. It was compiled on 2026-11-08 from the lockfiles and from each package's
own licence file:

- Dart and Flutter: `pubspec.lock` (one pub workspace), licence files read
  from `~/.pub-cache/hosted/pub.dev/<package>-<version>/LICENSE`;
- Edge Functions: `supabase/functions/deno.lock`, licences from the npm
  packages' `package.json` in Deno's cache and the `@std` sources' headers;
- website and repository tooling: `website/package-lock.json` and
  `package-lock.json`, licences from `node_modules/<package>/package.json`;
- Python tooling: the hashed `tool/*requirements*.txt`, licences from the
  installed packages' metadata.

Transitive dependencies are not listed one by one, but every one was scanned
for copyleft licences; the results are under [Copyleft](#copyleft).

Update this page when a direct dependency is added, removed or changes
licence.

## What ships to users

| Surface                        | Third-party code that reaches users                                                                                        |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| App (Android, iOS, web, Linux) | Flutter and the pub packages of `app/`, `packages/mm_ui` and `packages/mm_core`, with their transitive packages; the fonts |
| Edge Functions                 | Run on Supabase; nothing is distributed to users                                                                           |
| Website                        | Static HTML, CSS and the subset fonts; the npm packages run only at build time                                             |
| Tooling (`tool/`, root `npm`)  | Development only; never distributed                                                                                        |

## The app

### Flutter SDK

| Component                                                                               | Version         | Licence      |
| --------------------------------------------------------------------------------------- | --------------- | ------------ |
| Flutter SDK (`flutter`, `flutter_localizations`, `flutter_web_plugins`, `flutter_test`) | 3.47.9 (stable) | BSD-3-Clause |

The Flutter engine bundles further third-party code (Skia, ICU, HarfBuzz and
others); Flutter writes their notices into every build's `NOTICES` asset.

### `app/` dependencies

| Package            | Version | Licence                                                                            |
| ------------------ | ------- | ---------------------------------------------------------------------------------- |
| clock              | 1.1.3   | Apache-2.0                                                                         |
| file_picker        | 13.3.2  | MIT                                                                                |
| flutter_riverpod   | 3.4.3   | MIT                                                                                |
| go_router          | 18.1.3  | BSD-3-Clause                                                                       |
| http               | 1.6.0   | BSD-3-Clause                                                                       |
| image              | 4.12.0  | MIT                                                                                |
| image_picker       | 1.2.4   | BSD-3-Clause (its licence file also carries an Apache-2.0 notice for aFileChooser) |
| intl               | 0.20.3  | BSD-3-Clause                                                                       |
| pdf                | 3.13.1  | Apache-2.0                                                                         |
| share_plus         | 13.3.1  | BSD-3-Clause                                                                       |
| shared_preferences | 2.5.6   | BSD-3-Clause                                                                       |
| supabase_flutter   | 2.18.3  | MIT                                                                                |
| url_launcher       | 6.3.3   | BSD-3-Clause                                                                       |
| web                | 1.1.2   | BSD-3-Clause                                                                       |

Development only (tests and analysis; not shipped):

| Package                               | Version | Licence      |
| ------------------------------------- | ------- | ------------ |
| mocktail                              | 1.0.5   | MIT          |
| shared_preferences_platform_interface | 2.4.2   | BSD-3-Clause |
| very_good_analysis                    | 11.0.0  | MIT          |

### `packages/mm_core` dependencies

| Package    | Version | Licence      |
| ---------- | ------- | ------------ |
| characters | 1.4.1   | BSD-3-Clause |
| collection | 1.19.1  | BSD-3-Clause |
| meta       | 1.19.0  | BSD-3-Clause |

Development only: test 1.31.1 (BSD-3-Clause), very_good_analysis 11.0.0
(MIT).

### `packages/mm_ui` dependencies

Only the Flutter SDK and `mm_core`. Development only:
`flutter_localizations` and `flutter_test` (Flutter SDK, BSD-3-Clause),
very_good_analysis 11.0.0 (MIT).

### Every pub package, by licence

`pubspec.lock` resolves 159 packages. Their licence files read as follows:
108 BSD-3-Clause, 33 MIT (one also BSD-3-Clause), 12 Apache-2.0 (three of
them the image_picker family, which also carries BSD-3-Clause), 1 MPL-2.0
(`dbus`, see below) and 5 parts of the Flutter SDK. None is GPL, LGPL or
AGPL.

### Bundled fonts

| Font                       | Version              | Licence                                     | Copyright                                                |
| -------------------------- | -------------------- | ------------------------------------------- | -------------------------------------------------------- |
| Atkinson Hyperlegible Next | 2.001                | SIL Open Font License 1.1                   | 2020-2024 The Atkinson Hyperlegible Next Project Authors |
| Noto Nastaliq Urdu         | 3.009                | SIL Open Font License 1.1                   | 2022 The Noto Project Authors                            |
| MmIcons (subset of Lucide) | lucide-static 1.66.0 | ISC; the icons derived from Feather are MIT | Lucide Icons and Contributors; Cole Bemis (Feather)      |

The font files and their licence texts are in `packages/mm_ui/assets/fonts/`
(`OFL-AtkinsonHyperlegibleNext.txt`, `OFL-NotoNastaliqUrdu.txt`,
`LICENSE-lucide.txt`). Versions come from each font's name table. The website
serves subsets of the two text fonts (one renamed "MM Nastaliq Label") and
publishes both OFL texts at `/licences/`.

What the licences ask:

- **OFL 1.1**: the fonts may be used, embedded (including in the PDFs the app
  makes), subset and redistributed with the app, as long as every copy carries
  the copyright notice and the licence, and the fonts are not sold on their
  own. Neither licence names a Reserved Font Name, so a renamed subset is
  allowed. The two font files carry their copyright and a pointer to the OFL
  in their name tables; the full texts ship with the app and appear on its
  licence page (see [Gaps](#gaps)).
- **ISC and MIT** (icons): keep the copyright and permission notice with every
  copy. The generated `MmIcons.ttf` has an empty copyright field, so the
  notice ships as text on the app's licence page (see [Gaps](#gaps)).

## Edge Functions (`supabase/functions`)

Direct imports from `deno.json`, versions from `deno.lock`:

| Package               | Version | Licence |
| --------------------- | ------- | ------- |
| @supabase/server      | 1.9.2   | MIT     |
| @supabase/supabase-js | 2.118.0 | MIT     |
| @std/assert (tests)   | 1.0.19  | MIT     |
| @std/testing (tests)  | 1.0.21  | MIT     |

Their locked transitive packages are MIT (`@supabase/auth-js`,
`functions-js`, `postgrest-js`, `realtime-js`, `storage-js` 2.118.0,
`@supabase/middleware` 1.0.0, `@supabase/phoenix` 0.4.5, `iceberg-js` 0.8.1,
`jose` 6.2.15, `std-env` 4.3.0, `@std/fs`, `@std/internal`, `@std/path`) and
0BSD (`tslib` 2.8.1). The functions run on Supabase and are not distributed.

## Website (`website/`)

| Package          | Version | Licence      |
| ---------------- | ------- | ------------ |
| astro            | 7.4.5   | MIT          |
| @astrojs/mdx     | 8.1.2   | MIT          |
| @astrojs/sitemap | 3.7.4   | MIT          |
| subset-font      | 2.9.0   | BSD-3-Clause |

Development only:

| Package                   | Version | Licence    |
| ------------------------- | ------- | ---------- |
| @astrojs/check            | 0.9.12  | MIT        |
| @axe-core/playwright      | 4.14.0  | MPL-2.0    |
| @eslint/js                | 10.0.1  | MIT        |
| @lhci/cli                 | 0.15.1  | Apache-2.0 |
| @playwright/test          | 1.64.1  | Apache-2.0 |
| @types/node               | 22.20.5 | MIT        |
| eslint                    | 10.14.0 | MIT        |
| eslint-plugin-astro       | 3.2.1   | MIT        |
| eslint-plugin-jsx-a11y    | 6.10.2  | MIT        |
| fast-check                | 4.10.2  | MIT        |
| globals                   | 17.14.0 | MIT        |
| parse5                    | 8.1.0   | MIT        |
| postcss-html              | 2.0.0   | MIT        |
| prettier                  | 3.9.10  | MIT        |
| prettier-plugin-astro     | 1.1.2   | MIT        |
| sharp                     | 0.35.5  | Apache-2.0 |
| stylelint                 | 17.16.0 | MIT        |
| stylelint-config-standard | 40.0.0  | MIT        |
| stylelint-use-logical     | 2.1.3   | CC0-1.0    |
| typescript                | 6.0.3   | Apache-2.0 |
| typescript-eslint         | 8.72.1  | MIT        |
| vitest                    | 5.1.0   | MIT        |
| yaml                      | 2.9.1   | ISC        |

## Repository tooling

Root `package.json` (development only):

| Package                         | Version | Licence |
| ------------------------------- | ------- | ------- |
| @commitlint/cli                 | 21.2.4  | MIT     |
| @commitlint/config-conventional | 21.2.4  | MIT     |
| lefthook                        | 2.2.2   | MIT     |
| lucide-static                   | 1.66.0  | ISC     |
| markdownlint-cli2               | 0.24.0  | MIT     |
| prettier                        | 3.9.10  | MIT     |

Browser UAT (`app/uat/package.json`, development only; `docs/uat.md`):

| Package          | Version | Licence    |
| ---------------- | ------- | ---------- |
| @playwright/test | 1.64.1  | Apache-2.0 |

It installs `playwright` and `playwright-core` 1.64.1 (Apache-2.0) and, at run time, a Chromium
build for testing; none of it is distributed.

Python (`tool/requirements.txt`, `tool/requirements-lint.txt`,
`tool/formal/requirements.txt`; development only):

| Package              | Version   | Licence                                                          |
| -------------------- | --------- | ---------------------------------------------------------------- |
| fonttools            | 4.68.0    | MIT                                                              |
| black                | 26.10.1   | MIT                                                              |
| ruff                 | 0.17.3    | MIT                                                              |
| shellcheck-py        | 0.11.0.1  | MIT wrapper; the ShellCheck 0.11.0 binary it installs is GPL-3.0 |
| shfmt-py             | 4.2.0     | MIT AND BSD-3-Clause (shfmt 3.14.1)                              |
| squawk-cli           | 2.71.0    | Apache-2.0 OR MIT                                                |
| editorconfig-checker | 3.11.1    | MIT                                                              |
| actionlint-py        | 1.7.12.25 | MIT                                                              |
| z3-solver            | 5.3.3.0   | MIT                                                              |

Locked transitive Python packages: click 8.5.0 (BSD-3-Clause), mypy-extensions
1.2.0 (MIT), packaging 26.3 (Apache-2.0 OR BSD-2-Clause), pathspec 1.1.1
(MPL-2.0), platformdirs 4.14.5 (MIT), pytokens 0.4.1 (MIT).

## Copyleft

| Package                                     | Licence           | Where                                        | What it asks of us                      |
| ------------------------------------------- | ----------------- | -------------------------------------------- | --------------------------------------- |
| dbus 0.8.0                                  | MPL-2.0           | App, Linux desktop only                      | See below                               |
| lightningcss 1.33.0 (and platform binaries) | MPL-2.0           | Website build (through Astro and Vite)       | Nothing: not distributed                |
| axe-core 4.14.0, @axe-core/playwright       | MPL-2.0           | Website tests                                | Nothing: not distributed                |
| @img/sharp-libvips-\* 1.3.4                 | LGPL-3.0-or-later | Website build (optional binaries of `sharp`) | Nothing: not distributed                |
| pathspec 1.1.1                              | MPL-2.0           | Python formatter (through black)             | Nothing: not distributed                |
| ShellCheck 0.11.0                           | GPL-3.0           | Shell lint (through shellcheck-py)           | Nothing: run as a tool, not distributed |

The copyleft only applies when the code is distributed. Everything in the
table except dbus runs on developer machines and in CI, and none of it ends up
in the app, the website's output or the functions.

### dbus 0.8.0 (MPL-2.0)

`file_picker` 13.3.2 uses `file_picker_linux` 2.0.2 (MIT) on Linux, which
talks to the desktop's file chooser portal through `dbus` 0.8.0
(<https://github.com/canonical/dbus.dart>). Only a Linux desktop build runs
it; Android, iOS and web builds never call it. The package is used unmodified.

The MPL-2.0 is a file-level copyleft. For a build that includes `dbus`, it
asks:

1. Tell recipients that the build contains MPL-2.0 code and where its source
   is: here, and in the build's `NOTICES` asset, which Flutter fills from every
   package's licence file (the web build's `assets/NOTICES` includes the MPL-2.0
   text under `dbus`).
2. Make the source of the MPL-covered files available. As `dbus` is
   unmodified, pointing to version 0.8.0 on pub.dev and its repository is
   enough.
3. If its files are ever modified, publish the modified files under the
   MPL-2.0.

The rest of the app stays under its own licence: the MPL-2.0 does not reach
files that only use `dbus`. If a Linux build is never distributed, nothing
applies.

## Gaps

Found while compiling this page. Closed since (checked on 2026-11-08):

- `packages/mm_ui/LICENSE` and `packages/mm_core/LICENSE` hold the project's MIT
  licence.
- `MmLicenses.register()` (`packages/mm_ui/lib/src/foundation/mm_licenses.dart`,
  called from `app/lib/src/bootstrap.dart`) adds `OFL-AtkinsonHyperlegibleNext.txt`,
  `OFL-NotoNastaliqUrdu.txt` and `LICENSE-lucide.txt` to `LicenseRegistry`, and
  Settings, About opens `showLicensePage`.

Still open:

- `MmIcons.ttf` has no copyright, licence or licence-URL entries in its name
  table; the icon build (`tool/design/build_icons.py`) could write the Lucide
  copyright there. The notice ships as text through the licence page meanwhile.
