/**
 * The release facts the pitch deck names, for scripts/render-deck.ts: the
 * current version (the release-please manifest), its date, and how many
 * releases followed the first (CHANGELOG.md). Node without a bundler cannot
 * import src/lib/release.ts, which reads the two files through Vite, so this
 * takes their text; tests/unit/deck-release.test.ts holds the two readings
 * together.
 */

/**
 * A release's heading as release-please writes it, `## [1.4.0](…) (2026-11-15)` or
 * `## 1.0.0 (2026-11-09)`: the same two forms src/lib/release.ts reads.
 */
const HEADING =
  /^## (?:\[(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\]\([^)]*\)|(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)) \((\d{4}-\d{2}-\d{2})\)\s*$/gm;

export interface DeckRelease {
  /** The current version, as the manifest has it. */
  readonly version: string;
  /** Its date as a slide writes it: 15 November 2026. */
  readonly date: string;
  /** How many releases CHANGELOG.md lists after its first. */
  readonly later: number;
}

export function deckRelease(manifestJson: string, changelog: string): DeckRelease {
  const version = (JSON.parse(manifestJson) as Record<string, string>)["."];
  if (version === undefined) throw new Error("The release-please manifest has no version");
  const releases = [...changelog.matchAll(HEADING)];
  const iso = releases.find((heading) => (heading[1] ?? heading[2]) === version)?.[3];
  if (iso === undefined) throw new Error(`CHANGELOG.md has no entry for ${version}`);
  const date = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${iso}T00:00:00Z`));
  return { version, date, later: releases.length - 1 };
}
