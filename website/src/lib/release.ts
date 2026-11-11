/**
 * What has been released, read when the site is built from the two files
 * release-please keeps: `.release-please-manifest.json` (the current version)
 * and `CHANGELOG.md` (every version, its date and its notes). The Release
 * workflow deploys the site at the tag it has just made, so these always
 * describe the release being deployed; nothing is fetched.
 *
 * The release's files are another matter: the tag exists minutes before the
 * Release workflow has built and attached them, and a build that fails
 * attaches nothing until it is re-run. So the Deploy workflow lists the files
 * attached when the site is built (src/data/release-assets.json), and the
 * download page links to those alone; a deploy is never held up by a missing
 * file, and never publishes a link to one.
 */
import { z } from "astro/zod";
import changelogText from "../../../CHANGELOG.md?raw";
import manifest from "../../../.release-please-manifest.json";
import { SITE } from "../config/site.ts";
import attachedAssets from "../data/release-assets.json";

export interface ReleaseNote {
  /** The Conventional Commits scope ("app", "db", "web"), if the entry has one. */
  readonly scope: string | undefined;
  /** The entry as written, without its scope or commit link. */
  readonly text: string;
}

export interface ReleaseSection {
  /** "Features", "Bug fixes", "⚠ BREAKING CHANGES" and so on, as release-please writes them. */
  readonly title: string;
  readonly notes: readonly ReleaseNote[];
}

export interface Release {
  readonly version: string;
  /** The git tag: "v1.0.1". */
  readonly tag: string;
  /** The release date, YYYY-MM-DD. */
  readonly date: string;
  /** The release's page on GitHub. */
  readonly url: string;
  readonly sections: readonly ReleaseSection[];
}

/** A file attached to a release by the Release workflow (.github/workflows/release.yml). */
export interface ReleaseAsset {
  readonly id: "android-arm64" | "android-arm32" | "android-x86" | "ios" | "web" | "checksums";
  readonly file: string;
  readonly url: string;
}

const VERSION = /\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?/.source;
const HEADING = new RegExp(
  `^## (?:\\[(${VERSION})\\]\\([^)]*\\)|(${VERSION})) \\((\\d{4}-\\d{2}-\\d{2})\\)\\s*$`,
);
const SECTION = /^### (.+?)\s*$/;
/** "* **app:** text ([abc1234](url))", the scope optional. */
const ENTRY = /^[*-] (?:\*\*([^*:]+):\*\* )?(.+?)\s*$/;

/** The entry as a reader sees it: no commit links, no "closes #7", links as their text. */
export function plainNote(markdown: string): string {
  return markdown
    .replace(/ \(\[[0-9a-f]{7,40}\]\([^)]*\)\)/g, "")
    .replace(/,? closes (?:\[#\d+\]\([^)]*\)(?:,? )?)+/g, "")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .trim();
}

/**
 * Every release in a release-please CHANGELOG.md, newest first. Lines that are
 * not a version heading, a section heading or an entry are ignored; an entry
 * outside a section, or a version without a date, is an error, so a changelog
 * the parser no longer understands fails the build instead of shipping a blank
 * page.
 */
export function parseChangelog(text: string, repositoryUrl: string): Release[] {
  const releases: {
    version: string;
    date: string;
    sections: { title: string; notes: ReleaseNote[] }[];
  }[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    if (line.startsWith("## ")) {
      const heading = HEADING.exec(line);
      if (heading === null)
        throw new Error(`CHANGELOG.md: cannot read the heading ${JSON.stringify(line)}`);
      const version = heading[1] ?? heading[2] ?? "";
      releases.push({ version, date: heading[3] ?? "", sections: [] });
      continue;
    }
    const current = releases.at(-1);
    const section = SECTION.exec(line);
    if (section !== null) {
      if (current === undefined)
        throw new Error(`CHANGELOG.md: section before any version: ${line}`);
      current.sections.push({ title: section[1] ?? "", notes: [] });
      continue;
    }
    const entry = ENTRY.exec(line);
    if (entry !== null) {
      const target = current?.sections.at(-1);
      if (target === undefined) throw new Error(`CHANGELOG.md: entry outside a section: ${line}`);
      target.notes.push({ scope: entry[1]?.trim(), text: plainNote(entry[2] ?? "") });
    }
  }
  return releases.map((release) => ({
    version: release.version,
    tag: `v${release.version}`,
    date: release.date,
    url: `${repositoryUrl}/releases/tag/v${release.version}`,
    sections: release.sections.filter((section) => section.notes.length > 0),
  }));
}

/**
 * The files attached to a release on GitHub, as deploy.yml's site job found
 * them just before the build: it writes src/data/release-assets.json. The
 * committed copy has both null, for "not looked up": a local or CI build
 * links every file the Release workflow attaches.
 */
export const attachedAssetsSchema = z.union([
  z.strictObject({ tag: z.null(), files: z.null() }),
  z.strictObject({
    tag: z.string().regex(new RegExp(`^v${VERSION}$`)),
    files: z.array(z.string().min(1)),
  }),
]);

export type AttachedAssets = z.infer<typeof attachedAssetsSchema>;

export const ATTACHED_ASSETS: AttachedAssets = attachedAssetsSchema.parse(attachedAssets);

/**
 * The files the Release workflow attaches to `release`, with their download
 * addresses, keeping those `attached` names when it has looked them up: the
 * site then links only to files that exist, whether or not the release's
 * builds have attached the rest yet. Keep it in step with release.yml's file
 * names; deploy.yml checks every link before it publishes the site.
 */
export function releaseAssets(
  release: Pick<Release, "tag">,
  repositoryUrl: string,
  attached: AttachedAssets,
): ReleaseAsset[] {
  if (attached.tag !== null && attached.tag !== release.tag) {
    throw new Error(
      `src/data/release-assets.json lists the files of ${attached.tag}, not of ${release.tag}`,
    );
  }
  const base = `${repositoryUrl}/releases/download/${release.tag}`;
  const file = (suffix: string) => `maalik-e-makaan-${release.tag}${suffix}`;
  const assets: Omit<ReleaseAsset, "url">[] = [
    { id: "android-arm64", file: file("-arm64-v8a.apk") },
    { id: "android-arm32", file: file("-armeabi-v7a.apk") },
    { id: "android-x86", file: file("-x86_64.apk") },
    { id: "ios", file: file("-ios-unsigned.ipa") },
    { id: "web", file: file("-web.zip") },
    { id: "checksums", file: "SHA256SUMS" },
  ];
  return assets
    .filter((asset) => attached.files === null || attached.files.includes(asset.file))
    .map((asset) => ({ ...asset, url: `${base}/${asset.file}` }));
}

/** Whether `version` is 1.0.0 or later: the app is released, not in development. */
export function isReleased(version: string): boolean {
  const major = Number.parseInt(version.split(".")[0] ?? "0", 10);
  return Number.isFinite(major) && major >= 1;
}

/**
 * Where the product stands, from the version: "in-development" before 1.0.0,
 * when every page says so plainly, and "available" from 1.0.0 on.
 */
export type AppStatus = "in-development" | "available";

/** The current version, from the manifest release-please updates with each release. */
export const CURRENT_VERSION: string = (manifest as Record<string, string>)["."] ?? "0.0.0";

/** Every release, newest first. */
export const RELEASES: readonly Release[] = parseChangelog(changelogText, SITE.repositoryUrl);

/**
 * The release the site describes: the one the manifest names. The build fails
 * if the changelog does not have it, so the two files can never disagree on a
 * live page.
 */
export const LATEST_RELEASE: Release | undefined = (() => {
  if (!isReleased(CURRENT_VERSION) && RELEASES.length === 0) return undefined;
  const release = RELEASES.find((candidate) => candidate.version === CURRENT_VERSION);
  if (release === undefined) {
    throw new Error(
      `CHANGELOG.md has no entry for ${CURRENT_VERSION}, the version in the manifest`,
    );
  }
  return release;
})();

export const APP_STATUS: AppStatus = isReleased(CURRENT_VERSION) ? "available" : "in-development";
