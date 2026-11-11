/**
 * The roadmap, as GitHub has it: the milestones and the issues labelled
 * "roadmap", with their state. tool/github/fetch_roadmap.py writes
 * src/data/roadmap.json (live from GitHub when the site is deployed; a
 * copy made from .github/roadmap.toml is kept in the repository for offline
 * builds). It is checked here, so a malformed file fails the build.
 */
import { z } from "astro/zod";
import data from "../data/roadmap.json";
import type { Locale } from "../i18n/locales.ts";

/** "closed" is done: an issue closed as not planned or as a duplicate is left out of the data. */
const state = z.enum(["open", "closed"]);
/** A day that exists, as YYYY-MM-DD: "2027-02-29" is refused, not read as 1 March. */
const date = z.iso.date();

const roadmapIssue = z.strictObject({
  /** The id from the roadmap file, or null for an issue added on GitHub. */
  id: z.string().nullable(),
  number: z.int().positive().nullable(),
  title: z.string().trim().min(1),
  /** The Urdu title, while the English one is still the roadmap file's. */
  titleUr: z.string().trim().min(1).nullable(),
  state,
  url: z.url().nullable(),
});

const roadmapMilestone = z.strictObject({
  id: z.string().nullable(),
  number: z.int().positive().nullable(),
  title: z.string().trim().min(1),
  titleUr: z.string().trim().min(1).nullable(),
  description: z.string(),
  descriptionUr: z.string().nullable(),
  due: date.nullable(),
  state,
  url: z.url().nullable(),
  issues: z.array(roadmapIssue),
});

export const roadmapSchema = z.strictObject({
  /** "github" when the data is live; "file" for the plan in the repository. */
  source: z.enum(["github", "file"]),
  repository: z.url(),
  /** The day the live data was read, or null for the repository's copy. */
  updated: date.nullable(),
  milestones: z.array(roadmapMilestone).min(1),
  /** Issues labelled "roadmap" that are in no milestone yet (always empty in the file's copy). */
  unscheduled: z.array(roadmapIssue),
});

export type Roadmap = z.infer<typeof roadmapSchema>;
export type RoadmapMilestone = z.infer<typeof roadmapMilestone>;
export type RoadmapIssue = z.infer<typeof roadmapIssue>;

export const ROADMAP: Roadmap = roadmapSchema.parse(data);

/**
 * A title or description in the page's language: on the Urdu page, the Urdu
 * when there is one. English there is marked as English and set left to
 * right, as the site does with every block of Latin text on an Urdu page;
 * otherwise the page's right-to-left direction would draw its closing full
 * stop or question mark at the start.
 */
export function localised(
  english: string,
  urdu: string | null,
  locale: Locale,
): { text: string; lang?: "en"; dir?: "ltr" } {
  if (locale === "en") return { text: english };
  return urdu === null ? { text: english, lang: "en", dir: "ltr" } : { text: urdu };
}

/** How many of a milestone's issues are done, of how many. */
export function progress(milestone: RoadmapMilestone): { done: number; total: number } {
  return {
    done: milestone.issues.filter((issue) => issue.state === "closed").length,
    total: milestone.issues.length,
  };
}
