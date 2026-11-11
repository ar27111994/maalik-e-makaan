// The release data the site reads from CHANGELOG.md and the release-please
// manifest, and the roadmap data from src/data/roadmap.json.
import { describe, expect, test } from "vitest";
import releasePleaseConfig from "../../../release-please-config.json";
import { charactersOf, isArabicScript, LATIN_RANGES } from "../../integrations/brand-assets.ts";
import { LOCALES } from "../../src/i18n/locales.ts";
import { ui } from "../../src/i18n/ui.ts";
import {
  APP_STATUS,
  CURRENT_VERSION,
  isReleased,
  LATEST_RELEASE,
  parseChangelog,
  RELEASES,
  releaseAssets,
} from "../../src/lib/release.ts";
import { localised, progress, ROADMAP, roadmapSchema } from "../../src/lib/roadmap.ts";

const repo = "https://github.com/owner/repo";

const SAMPLE = `# Changelog

## [1.1.0](https://github.com/owner/repo/compare/v1.0.0...v1.1.0) (2027-01-15)


### ⚠ BREAKING CHANGES

* **db:** rename a column ([abc1234](https://github.com/owner/repo/commit/abc1234))

### Features

* **app:** a new screen ([abc1234](https://github.com/owner/repo/commit/abc1234)), closes [#7](https://github.com/owner/repo/issues/7)
* plain entry without scope

## 1.0.0 (2026-11-09)


### Bug fixes

* **web:** fix a link ([def5678](https://github.com/owner/repo/commit/def5678))
`;

describe("parseChangelog", () => {
  const releases = parseChangelog(SAMPLE, repo);

  test("reads every version, newest first, with its date, tag and page", () => {
    expect(releases.map((release) => [release.version, release.date, release.tag])).toEqual([
      ["1.1.0", "2027-01-15", "v1.1.0"],
      ["1.0.0", "2026-11-09", "v1.0.0"],
    ]);
    expect(releases[0]?.url).toBe("https://github.com/owner/repo/releases/tag/v1.1.0");
  });

  test("keeps sections and entries, without scopes' markup or commit links", () => {
    expect(releases[0]?.sections.map((section) => section.title)).toEqual([
      "⚠ BREAKING CHANGES",
      "Features",
    ]);
    expect(releases[0]?.sections[1]?.notes).toEqual([
      { scope: "app", text: "a new screen" },
      { scope: undefined, text: "plain entry without scope" },
    ]);
    expect(releases[1]?.sections[0]?.notes).toEqual([{ scope: "web", text: "fix a link" }]);
  });

  test("a heading it cannot read, or an entry outside a section, fails loudly", () => {
    expect(() => parseChangelog("## Unreleased\n", repo)).toThrow(/cannot read the heading/);
    expect(() => parseChangelog("## 1.0.0 (2026-11-09)\n\n* stray\n", repo)).toThrow(
      /outside a section/,
    );
  });
});

/** The characters the self-hosted Latin font draws (integrations/brand-assets.ts). */
const LATIN = new Set(charactersOf(LATIN_RANGES));

/**
 * The characters of `text` that the page's fonts cannot draw: on an English
 * page, those outside the Latin subset; on an Urdu page, also Arabic-script
 * ones, since the build subsets the Urdu fonts to every such character in src/.
 */
function undrawable(text: string, urdu: boolean): string[] {
  // By code point, as the fonts' unicode-range is.
  return Array.from(text).filter((char) => {
    if (LATIN.has(char)) return false;
    return !(urdu && isArabicScript(char.codePointAt(0) ?? 0));
  });
}

/** The heading the release notes page shows for a section, as ReleasesPage.astro picks it. */
function sectionHeadings(title: string) {
  return LOCALES.map((locale) => ({ locale, heading: ui(locale).releases.sections[title] }));
}

describe("release notes section headings", () => {
  /**
   * Every section title release-please can write: the visible sections of its
   * config, and the one it adds for breaking changes, "⚠" and all (the
   * conventionalcommits preset that release-please uses).
   */
  const titles = [
    "⚠ BREAKING CHANGES",
    ...releasePleaseConfig["changelog-sections"]
      .filter((section) => !("hidden" in section && section.hidden))
      .map((section) => section.section),
  ];

  test("every section release-please can write has a heading in both languages", () => {
    expect(titles).toContain("Features");
    for (const title of titles) {
      for (const { locale, heading } of sectionHeadings(title))
        expect(heading, `${title} (${locale})`).toMatch(/\S/);
    }
  });

  test("a breaking-changes section is shown under a translated heading the fonts can draw", () => {
    const sample = parseChangelog(SAMPLE, repo);
    const breaking = sample[0]?.sections[0];
    expect(breaking?.title).toBe("⚠ BREAKING CHANGES");
    expect(breaking?.notes).toEqual([{ scope: "db", text: "rename a column" }]);
    for (const section of sample.flatMap((release) => release.sections)) {
      for (const { locale, heading } of sectionHeadings(section.title)) {
        if (heading === undefined) throw new Error(`no ${locale} heading for ${section.title}`);
        expect(heading).not.toContain("⚠");
        expect(undrawable(heading, locale === "ur"), `${section.title} (${locale})`).toEqual([]);
      }
    }
  });
});

describe("the repository's releases", () => {
  test("the manifest's version is the newest entry in CHANGELOG.md", () => {
    expect(RELEASES[0]?.version).toBe(CURRENT_VERSION);
    expect(LATEST_RELEASE?.version).toBe(CURRENT_VERSION);
    expect(LATEST_RELEASE?.sections.length).toBeGreaterThan(0);
  });

  test("every section has a heading in both languages, and every note a glyph", () => {
    for (const release of RELEASES) {
      for (const section of release.sections) {
        for (const { locale, heading } of sectionHeadings(section.title))
          expect(heading, `${release.version}: ${section.title} (${locale})`).toBeDefined();
        // The notes are shown as written, in English, on both pages.
        for (const note of section.notes)
          expect(undrawable(note.text, false), `${release.version}: ${note.text}`).toEqual([]);
      }
    }
  });

  test("from 1.0.0 the app is available", () => {
    expect(isReleased("0.9.3")).toBe(false);
    expect(isReleased("1.0.0")).toBe(true);
    expect(isReleased("2.3.4-beta.1")).toBe(true);
    expect(APP_STATUS).toBe(isReleased(CURRENT_VERSION) ? "available" : "in-development");
  });

  test("names the files the Release workflow attaches", () => {
    const files = releaseAssets({ tag: "v1.0.1" }, repo);
    expect(files.map((file) => file.file)).toEqual([
      "maalik-e-makaan-v1.0.1-arm64-v8a.apk",
      "maalik-e-makaan-v1.0.1-armeabi-v7a.apk",
      "maalik-e-makaan-v1.0.1-x86_64.apk",
      "maalik-e-makaan-v1.0.1-ios-unsigned.ipa",
      "maalik-e-makaan-v1.0.1-web.zip",
      "SHA256SUMS",
    ]);
    expect(files[0]?.url).toBe(
      "https://github.com/owner/repo/releases/download/v1.0.1/maalik-e-makaan-v1.0.1-arm64-v8a.apk",
    );
  });
});

describe("the roadmap", () => {
  test("the committed copy is valid, with Urdu for every item it plans", () => {
    expect(ROADMAP.milestones.length).toBeGreaterThanOrEqual(3);
    for (const milestone of ROADMAP.milestones) {
      expect(milestone.titleUr).not.toBeNull();
      for (const issue of milestone.issues) expect(issue.titleUr, issue.title).not.toBeNull();
    }
  });

  test("progress counts closed issues", () => {
    const [first] = ROADMAP.milestones;
    if (first === undefined) throw new Error("the roadmap has no milestones");
    const milestone = {
      ...first,
      issues: [
        { id: null, number: 1, title: "A", titleUr: null, state: "closed" as const, url: null },
        { id: null, number: 2, title: "B", titleUr: null, state: "open" as const, url: null },
      ],
    };
    expect(progress(milestone)).toEqual({ done: 1, total: 2 });
  });

  test("a malformed file is refused", () => {
    expect(roadmapSchema.safeParse({ ...ROADMAP, milestones: [] }).success).toBe(false);
    expect(roadmapSchema.safeParse({ ...ROADMAP, source: "somewhere" }).success).toBe(false);
    expect(roadmapSchema.safeParse({ ...ROADMAP, unscheduled: undefined }).success).toBe(false);
  });

  test("a date is a day that exists, not one the calendar rolls over", () => {
    const [first, ...rest] = ROADMAP.milestones;
    if (first === undefined) throw new Error("the roadmap has no milestones");
    const due = (value: string) =>
      roadmapSchema.safeParse({ ...ROADMAP, milestones: [{ ...first, due: value }, ...rest] })
        .success;
    expect(due("2027-02-28")).toBe(true);
    expect(due("2028-02-29")).toBe(true);
    // new Date() would read these as 1 March and 1 July, and the page would show the wrong month.
    expect(due("2027-02-29")).toBe(false);
    expect(due("2027-06-31")).toBe(false);
    expect(due("2027-13-01")).toBe(false);
    expect(roadmapSchema.safeParse({ ...ROADMAP, updated: "2026-11-31" }).success).toBe(false);
  });

  test("English-only text on the Urdu page is marked as English, left to right", () => {
    expect(localised("Launch.", "اجرا۔", "en")).toEqual({ text: "Launch." });
    expect(localised("Launch.", "اجرا۔", "ur")).toEqual({ text: "اجرا۔" });
    expect(localised("Launch.", null, "ur")).toEqual({ text: "Launch.", lang: "en", dir: "ltr" });
  });

  test("the file's copy has nothing unscheduled; live data may", () => {
    expect(ROADMAP.unscheduled).toEqual([]);
    const live = {
      ...ROADMAP,
      source: "github",
      updated: "2026-11-11",
      unscheduled: [{ id: null, number: 40, title: "A", titleUr: null, state: "open", url: null }],
    };
    expect(roadmapSchema.parse(live).unscheduled).toHaveLength(1);
  });
});
