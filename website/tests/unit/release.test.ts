// The release data the site reads from CHANGELOG.md and the release-please
// manifest, the release's attached files from src/data/release-assets.json,
// and the roadmap data from src/data/roadmap.json.
import { describe, expect, test } from "vitest";
import releasePleaseConfig from "../../../release-please-config.json";
import { charactersOf, isArabicScript, LATIN_RANGES } from "../../integrations/brand-assets.ts";
import { LOCALES } from "../../src/i18n/locales.ts";
import { ui } from "../../src/i18n/ui.ts";
import {
  APP_STATUS,
  ATTACHED_ASSETS,
  attachedAssetsSchema,
  CURRENT_VERSION,
  isReleased,
  LATEST_RELEASE,
  parseChangelog,
  RELEASES,
  releaseAssets,
} from "../../src/lib/release.ts";
import { localised, progress, ROADMAP, roadmapSchema } from "../../src/lib/roadmap.ts";

const repo = "https://github.com/owner/repo";
/** src/data/release-assets.json as committed: the attached files were not looked up. */
const NOT_LOOKED_UP = { tag: null, files: null } as const;

const SAMPLE = `# Changelog

## [1.1.0](https://github.com/owner/repo/compare/v1.0.0...v1.1.0) (2027-01-15)


### ⚠ BREAKING CHANGES

* **db:** rename a column

### Features

* **app:** a new screen ([abc1234](https://github.com/owner/repo/commit/abc1234)), closes [#7](https://github.com/owner/repo/issues/7)
* plain entry without scope


### Refactoring

* **db:** rename a column ([fed4321](https://github.com/owner/repo/commit/fed4321))

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
      "Refactoring",
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
   * Every section title release-please can write: each section of its config,
   * hidden ones included, and the one it adds for breaking changes, "⚠" and
   * all. The conventionalcommits preset that release-please uses keeps a commit
   * of a hidden type when it is breaking or has a `Release-As:` footer, and
   * lists it under its type's section.
   */
  const titles = [
    "⚠ BREAKING CHANGES",
    ...releasePleaseConfig["changelog-sections"].map((section) => section.section),
  ];

  test("every section release-please can write has a heading in both languages", () => {
    expect(titles).toEqual(expect.arrayContaining(["Features", "Refactoring", "Tests"]));
    for (const title of titles) {
      for (const { locale, heading } of sectionHeadings(title))
        expect(heading ?? "", `${title} (${locale})`).toMatch(/\S/);
    }
  });

  test("each language gives each section its own heading", () => {
    for (const locale of LOCALES) {
      const headings = titles.map((title) => ui(locale).releases.sections[title]);
      expect(new Set(headings).size, locale).toBe(titles.length);
    }
  });

  test("a breaking change of a hidden type is shown under translated headings the fonts can draw", () => {
    // What release-please writes for `refactor(db)!: rename a column`.
    const sample = parseChangelog(SAMPLE, repo);
    const sections = sample[0]?.sections ?? [];
    expect(sections[0]?.title).toBe("⚠ BREAKING CHANGES");
    expect(sections[0]?.notes).toEqual([{ scope: "db", text: "rename a column" }]);
    expect(sections[2]?.title).toBe("Refactoring");
    expect(sections[2]?.notes).toEqual([{ scope: "db", text: "rename a column" }]);
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
    const files = releaseAssets({ tag: "v1.0.1" }, repo, NOT_LOOKED_UP);
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

describe("the release's files on the download page", () => {
  test("the committed list is not looked up, so a local build links every file", () => {
    expect(ATTACHED_ASSETS).toEqual(NOT_LOOKED_UP);
  });

  test("once looked up, only the attached files are linked, in the page's order", () => {
    // The iOS job failed and the Android one has attached its files: no link to the IPA.
    const attached = {
      tag: "v1.0.1",
      files: [
        "SHA256SUMS",
        "maalik-e-makaan-v1.0.1-web.zip",
        "maalik-e-makaan-v1.0.1-x86_64.apk",
        "maalik-e-makaan-v1.0.1-armeabi-v7a.apk",
        "maalik-e-makaan-v1.0.1-arm64-v8a.apk",
        "maalik-e-makaan-v1.0.1.aab",
        "maalik-e-makaan-v1.0.1-debug-symbols.zip",
      ],
    };
    expect(releaseAssets({ tag: "v1.0.1" }, repo, attached).map((file) => file.id)).toEqual([
      "android-arm64",
      "android-arm32",
      "android-x86",
      "web",
      "checksums",
    ]);
  });

  test("a release whose builds have attached nothing yet gets no links", () => {
    expect(releaseAssets({ tag: "v1.0.1" }, repo, { tag: "v1.0.1", files: [] })).toEqual([]);
  });

  test("a list made for another release fails the build", () => {
    expect(() =>
      releaseAssets({ tag: "v1.0.1" }, repo, { tag: "v1.0.0", files: ["SHA256SUMS"] }),
    ).toThrow(/lists the files of v1.0.0, not of v1.0.1/);
  });

  test("the list deploy.yml writes is accepted; a malformed one is refused", () => {
    const written = { tag: "v1.2.3", files: ["SHA256SUMS", "SHA256SUMS-ios"] };
    expect(attachedAssetsSchema.parse(written)).toEqual(written);
    expect(attachedAssetsSchema.safeParse({ tag: "v1.2.3", files: null }).success).toBe(false);
    expect(attachedAssetsSchema.safeParse({ tag: null, files: [] }).success).toBe(false);
    expect(attachedAssetsSchema.safeParse({ tag: "1.2.3", files: [] }).success).toBe(false);
    expect(attachedAssetsSchema.safeParse({ tag: "v1.2.3", files: [""] }).success).toBe(false);
    expect(attachedAssetsSchema.safeParse({ ...written, extra: true }).success).toBe(false);
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
