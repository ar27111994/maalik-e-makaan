// The release facts the pitch deck names (scripts/lib/deck-release.ts), and the rule that a
// slide or its notes name the current release, or count the releases, only through the
// renderer's placeholders: a number written out goes stale at the next release.
import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { deckRelease } from "../../scripts/lib/deck-release.ts";
import { CURRENT_VERSION, LATEST_RELEASE, RELEASES } from "../../src/lib/release.ts";

const CHANGELOG = `# Changelog

## [1.2.0](https://github.com/owner/repo/compare/v1.1.0...v1.2.0) (2026-03-09)


### Features

* **app:** a feature ([#3](https://github.com/owner/repo/issues/3))

## [1.1.0](https://github.com/owner/repo/compare/v1.0.0...v1.1.0) (2026-02-01)


### Bug Fixes

* **web:** a fix

## 1.0.0 (2026-01-31)


### Features

* the first release
`;

const manifest = (version: string): string => JSON.stringify({ ".": version });

describe("deckRelease", () => {
  test("reads the current version, its date as a slide writes it, and the releases after the first", () => {
    expect(deckRelease(manifest("1.2.0"), CHANGELOG)).toEqual({
      version: "1.2.0",
      date: "9 March 2026",
      later: 2,
    });
  });

  test("the date is the current version's own, in either form of heading", () => {
    expect(deckRelease(manifest("1.1.0"), CHANGELOG).date).toBe("1 February 2026");
    expect(deckRelease(manifest("1.0.0"), CHANGELOG).date).toBe("31 January 2026");
  });

  test("the count does not depend on which release is current", () => {
    expect(deckRelease(manifest("1.0.0"), CHANGELOG).later).toBe(2);
  });

  test("a first release has none after it", () => {
    const first = "# Changelog\n\n## 1.0.0 (2026-01-31)\n";
    expect(deckRelease(manifest("1.0.0"), first)).toEqual({
      version: "1.0.0",
      date: "31 January 2026",
      later: 0,
    });
  });

  test("only a release's heading counts", () => {
    const more =
      CHANGELOG +
      "\n### 9.9.9 (2026-01-01)\n\n* as in ## 8.8.8 (2026-01-01)\n\n## Unreleased\n\n## 7.7 (2026-01-01)\n";
    expect(deckRelease(manifest("1.2.0"), more).later).toBe(2);
  });

  test("a version is matched whole, and its dots are dots", () => {
    for (const version of ["1.1", "1.1.00", "11.1.0", "1x1x0", "1.2.0-rc.1"]) {
      expect(() => deckRelease(manifest(version), CHANGELOG), version).toThrow(
        `CHANGELOG.md has no entry for ${version}`,
      );
    }
  });

  test("a pre-release is a release of its own", () => {
    const text = CHANGELOG.replace("## [1.2.0]", "## [1.2.0-rc.1]");
    expect(deckRelease(manifest("1.2.0-rc.1"), text)).toEqual({
      version: "1.2.0-rc.1",
      date: "9 March 2026",
      later: 2,
    });
  });

  test("refuses a manifest that names no version", () => {
    expect(() => deckRelease("{}", CHANGELOG)).toThrow(
      "The release-please manifest has no version",
    );
  });

  test("agrees with the site's reading of the repository's own manifest and changelog", () => {
    const read = (file: string): string =>
      readFileSync(new URL(`../../../${file}`, import.meta.url), "utf8");
    const real = deckRelease(read(".release-please-manifest.json"), read("CHANGELOG.md"));
    expect(real.version).toBe(CURRENT_VERSION);
    expect(real.later).toBe(RELEASES.length - 1);
    // The same day the site gives the latest release, written out as on the cover.
    expect(LATEST_RELEASE).toBeDefined();
    const written = new Intl.DateTimeFormat("en-GB", {
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(new Date(`${LATEST_RELEASE?.date ?? ""}T00:00:00Z`));
    expect(real.date).toBe(written);
    // The status slide's notes say "Since 1.0.0": the first release the changelog lists.
    expect(RELEASES.at(-1)?.version).toBe("1.0.0");
  });
});

describe("the deck's slides and their notes", () => {
  const folder = new URL("../../deck/slides/", import.meta.url);
  const slides = readdirSync(folder)
    .filter((file) => file.endsWith(".html"))
    .sort();
  const slide = (file: string): string => readFileSync(new URL(file, folder), "utf8");

  test("name the current release only through {{version}}", () => {
    const current = new RegExp(`(?<![\\d.])${CURRENT_VERSION.replaceAll(".", "\\.")}(?![\\d.])`);
    expect(slides.filter((file) => current.test(slide(file)))).toEqual([]);
    expect(slide("product.html")).toContain("the released app ({{version}})");
  });

  /** A number before "releases", in digits or words. */
  const NUMBER =
    "\\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\\w+teen|twenty|thirty|forty|fifty|a dozen";
  /** "four releases (1.1.0 to 1.3.0)": a count that names the releases it counts. */
  const RANGE = "\\s*\\((\\d+\\.\\d+\\.\\d+) to (\\d+\\.\\d+\\.\\d+)\\)";

  test("count the releases to date only through {{laterReleases}}", () => {
    const counted = new RegExp(
      `\\b(?:${NUMBER})\\s+(?:more\\s+|later\\s+|new\\s+)?releases\\b(?!${RANGE})`,
      "i",
    );
    expect(slides.filter((file) => counted.test(slide(file)))).toEqual([]);
    expect(slide("status.html")).toContain("there have been {{laterReleases}} more releases");
  });

  test("a count of the releases between two versions it names is the changelog's", () => {
    const words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
    const ranged = new RegExp(`\\b(${NUMBER})\\s+releases${RANGE}`, "gi");
    const oldestFirst = RELEASES.map((release) => release.version).reverse();
    const found = slides.flatMap((file) =>
      [...slide(file).matchAll(ranged)].map((match) => ({
        file,
        count: (match[1] ?? "").toLowerCase(),
        from: oldestFirst.indexOf(match[2] ?? ""),
        to: oldestFirst.indexOf(match[3] ?? ""),
      })),
    );
    expect(found.map((range) => range.file)).toEqual(["roadmap.html"]);
    for (const { file, count, from, to } of found) {
      expect(from, file).toBeGreaterThanOrEqual(0);
      expect(to, file).toBeGreaterThanOrEqual(from);
      const said = /^\d+$/.test(count) ? Number(count) : words.indexOf(count);
      expect(said, file).toBe(to - from + 1);
    }
  });
});
