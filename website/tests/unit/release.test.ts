// The release data the site reads from CHANGELOG.md and the release-please
// manifest, and the roadmap data from src/data/roadmap.json.
import { describe, expect, test } from "vitest";
import {
  APP_STATUS,
  CURRENT_VERSION,
  isReleased,
  LATEST_RELEASE,
  parseChangelog,
  RELEASES,
  releaseAssets,
} from "../../src/lib/release.ts";
import { progress, ROADMAP, roadmapSchema } from "../../src/lib/roadmap.ts";

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

describe("the repository's releases", () => {
  test("the manifest's version is the newest entry in CHANGELOG.md", () => {
    expect(RELEASES[0]?.version).toBe(CURRENT_VERSION);
    expect(LATEST_RELEASE?.version).toBe(CURRENT_VERSION);
    expect(LATEST_RELEASE?.sections.length).toBeGreaterThan(0);
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
  });
});
