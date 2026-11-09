/**
 * llms.txt and llms-full.txt (https://llmstxt.org): plain Markdown summaries of
 * the site for language models. Both are built from the same content
 * collections as the HTML pages, so they never drift from what the pages say.
 */
import { SITE } from "../config/site.ts";
import { absoluteUrl, localisePath, LOCALES, type Locale } from "../i18n/locales.ts";
import { ui } from "../i18n/ui.ts";
import type {
  DownloadContent,
  FaqContent,
  FeaturesContent,
  HomeContent,
  HowItWorksContent,
  LicencesContent,
  Source,
} from "./content/schemas.ts";
import { guidePath } from "./content/guides.ts";
import { copyrightLine, fontLicence, fontLicencePath } from "./licences.ts";

export interface LlmsGuide {
  readonly locale: Locale;
  readonly slug: string;
  readonly title: string;
  readonly description: string;
  readonly lastReviewed: string;
  readonly sources: readonly Source[];
  /** The guide's Markdown body. */
  readonly body: string;
}

/** A calculator page: its introduction, notices and Markdown body (the method and the law). */
export interface LlmsTool {
  readonly locale: Locale;
  readonly slug: string;
  readonly order: number;
  readonly title: string;
  readonly description: string;
  readonly intro: string;
  readonly disclaimer?: string | undefined;
  readonly lastReviewed: string;
  readonly sources: readonly Source[];
  readonly body: string;
}

/** A page of running text (privacy, terms). */
export interface LlmsTextPage {
  readonly locale: Locale;
  readonly slug: string;
  readonly title: string;
  readonly description: string;
  readonly lastUpdated: string;
  readonly body: string;
}

export interface LlmsInput {
  readonly site: string | URL;
  readonly appUrl: string;
  readonly home: Readonly<Record<Locale, HomeContent>>;
  readonly licences: Readonly<Record<Locale, LicencesContent>>;
  readonly features: Readonly<Record<Locale, FeaturesContent>>;
  readonly howItWorks: Readonly<Record<Locale, HowItWorksContent>>;
  readonly faq: Readonly<Record<Locale, FaqContent>>;
  readonly download: Readonly<Record<Locale, DownloadContent>>;
  readonly guides: readonly LlmsGuide[];
  readonly tools: readonly LlmsTool[];
  readonly textPages: readonly LlmsTextPage[];
  /** Licence texts by font licence slug, for the copyright lines. */
  readonly licenceTexts: Readonly<Record<string, string>>;
}

const LANGUAGE_NAME: Readonly<Record<Locale, string>> = { en: "English", ur: "Urdu" };

/** Collapses whitespace so a value fits on one Markdown line. */
function line(text: string): string {
  // Runs of whitespace become one space; a no-break space (between a figure and "Rs") is kept.
  return text.replace(/[^\S\u00A0]+/gu, " ").trim();
}

function pageUrl(site: string | URL, path: string, locale: Locale): string {
  return absoluteUrl(site, localisePath(path, locale));
}

/**
 * A Markdown body as plain Markdown: the language spans an Urdu body puts
 * around Latin words are dropped, and links to the site's own pages become
 * absolute.
 */
function markdownBody(site: string | URL, body: string): string {
  return body
    .replace(/<\/?(span|kbd)\b[^>]*>/g, "")
    .replace(/\]\((\/[^)\s]*)\)/g, (_match, path: string) => `](${absoluteUrl(site, path)})`)
    .trim();
}

const toolPath = (slug: string) => `/tools/${slug}/`;
const textPagePath = (slug: string) => `/${slug}/`;

/** "- [Title (Urdu)](url): description" for a page in `locale`. */
function pageLink(
  site: string | URL,
  path: string,
  locale: Locale,
  title: string,
  description: string,
): string {
  const suffix = locale === "en" ? "" : ` (${LANGUAGE_NAME[locale]})`;
  return `- [${line(title)}${suffix}](${pageUrl(site, path, locale)}): ${line(description)}`;
}

function statusLine(locale: Locale): string | undefined {
  return SITE.appStatus === "in-development" ? ui(locale).appStatus.inDevelopment : undefined;
}

/** The short index: what the product is, the key facts, and every page. */
export function llmsTxt(input: LlmsInput): string {
  const en = input.home.en;
  const out: string[] = [
    `# ${SITE.name} (${SITE.nameUrdu})`,
    "",
    `> ${line(en.description)}`,
    "",
    line(en.hero.lede),
    "",
  ];
  const status = statusLine("en");
  if (status !== undefined) out.push(status, "");
  out.push(
    `Key facts, from the site's questions and answers:`,
    "",
    ...en.faq.items.map((item) => `- ${line(item.question)} ${line(item.answer)}`),
    `- ${ui("en").footer.disclaimer}`,
    "",
    "## Pages",
    "",
  );
  for (const locale of LOCALES) {
    const strings = ui(locale);
    out.push(
      pageLink(input.site, "/", locale, input.home[locale].title, input.home[locale].description),
      pageLink(
        input.site,
        "/features/",
        locale,
        input.features[locale].title,
        input.features[locale].description,
      ),
      pageLink(
        input.site,
        "/how-it-works/",
        locale,
        input.howItWorks[locale].title,
        input.howItWorks[locale].description,
      ),
      pageLink(input.site, "/faq/", locale, input.faq[locale].title, input.faq[locale].description),
      pageLink(
        input.site,
        "/download/",
        locale,
        input.download[locale].title,
        input.download[locale].description,
      ),
      pageLink(input.site, "/guides/", locale, strings.guides.title, strings.guides.description),
      pageLink(input.site, "/tools/", locale, strings.tools.title, strings.tools.description),
      ...input.textPages
        .filter((page) => page.locale === locale)
        .map((page) =>
          pageLink(input.site, textPagePath(page.slug), locale, page.title, page.description),
        ),
      pageLink(
        input.site,
        "/licences/",
        locale,
        input.licences[locale].title,
        input.licences[locale].description,
      ),
    );
  }
  if (input.guides.length > 0) {
    out.push("", "## Guides", "");
    for (const guide of input.guides) {
      out.push(
        `${pageLink(input.site, guidePath(guide.slug), guide.locale, guide.title, guide.description)} Last reviewed ${guide.lastReviewed}.`,
      );
    }
  }
  if (input.tools.length > 0) {
    out.push("", "## Calculators", "");
    for (const tool of input.tools) {
      out.push(
        `${pageLink(input.site, toolPath(tool.slug), tool.locale, tool.title, tool.description)} Last reviewed ${tool.lastReviewed}.`,
      );
    }
  }
  out.push(
    "",
    "## Optional",
    "",
    `- [Full text](${absoluteUrl(input.site, "/llms-full.txt")}): every page of this site, in English and Urdu, in one Markdown file.`,
    SITE.appStatus === "available"
      ? `- [Web app](${input.appUrl}): ${SITE.name} itself.`
      : `- [Web app](${input.appUrl}): the address reserved for ${SITE.name}; it shows a holding page until version 1.0 is released.`,
    `- [Source code](${SITE.repositoryUrl}): the app, its database and this website, under the MIT licence.`,
    "",
  );
  return out.join("\n");
}

function homeSection(input: LlmsInput, locale: Locale): string[] {
  const home = input.home[locale];
  const out = [
    `## ${line(home.title)}`,
    "",
    `URL: ${pageUrl(input.site, "/", locale)}`,
    "",
    `### ${line(home.hero.heading)}`,
    "",
    line(home.hero.lede),
    "",
  ];
  const status = statusLine(locale);
  if (status !== undefined) out.push(status, "");
  out.push(`### ${line(home.features.heading)}`, "");
  for (const item of home.features.items) out.push(`- **${line(item.title)}.** ${line(item.body)}`);
  out.push("", `### ${line(home.steps.heading)}`, "");
  home.steps.items.forEach((item, index) => {
    out.push(`${index + 1}. **${line(item.title)}.** ${line(item.body)}`);
  });
  out.push("", `### ${line(home.trust.heading)}`, "");
  for (const item of home.trust.items) out.push(`- **${line(item.title)}.** ${line(item.body)}`);
  out.push("", `### ${line(home.faq.heading)}`, "");
  for (const item of home.faq.items)
    out.push(`#### ${line(item.question)}`, "", line(item.answer), "");
  const closing =
    SITE.appStatus === "available"
      ? `${line(home.closing.appBody)} ${input.appUrl}`
      : `${line(home.closing.body)} ${pageUrl(input.site, home.closing.cta.href, locale)}`;
  out.push(`### ${line(home.closing.heading)}`, "", closing, "");
  return out;
}

function licencesSection(input: LlmsInput, locale: Locale): string[] {
  const page = input.licences[locale];
  const out = [
    `## ${line(page.title)}`,
    "",
    `URL: ${pageUrl(input.site, "/licences/", locale)}`,
    "",
    line(page.intro),
    "",
    `### ${line(page.code.heading)}`,
    "",
    line(page.code.body),
    "",
    `### ${line(page.fonts.heading)}`,
    "",
    line(page.fonts.body),
    "",
  ];
  for (const item of page.fonts.items) {
    const font = fontLicence(item.licence);
    const text = input.licenceTexts[font.slug];
    const copyright = text === undefined ? "" : ` ${copyrightLine(text)}.`;
    out.push(
      `- **${font.family}**: ${line(item.role)}${copyright} ${absoluteUrl(input.site, fontLicencePath(font.slug))}`,
    );
  }
  out.push("", line(page.fonts.note), "");
  return out;
}

function guideSection(input: LlmsInput, guide: LlmsGuide): string[] {
  const strings = ui(guide.locale).guide;
  return [
    `## ${line(guide.title)}`,
    "",
    `URL: ${pageUrl(input.site, guidePath(guide.slug), guide.locale)}`,
    "",
    `${strings.lastReviewed}: ${guide.lastReviewed}. ${strings.notAdvice}`,
    "",
    markdownBody(input.site, guide.body),
    "",
    `### ${strings.sources}`,
    "",
    ...guide.sources.map(
      (source) =>
        `- [${line(source.title)}](${source.url}), ${line(source.publisher)} (${strings.accessed} ${source.accessed})`,
    ),
    "",
  ];
}

function sourcesList(locale: Locale, sources: readonly Source[]): string[] {
  const strings = ui(locale).guide;
  return [
    `### ${strings.sources}`,
    "",
    ...sources.map(
      (source) =>
        `- [${line(source.title)}](${source.url}), ${line(source.publisher)} (${strings.accessed} ${source.accessed})`,
    ),
    "",
  ];
}

function featuresSection(input: LlmsInput, locale: Locale): string[] {
  const page = input.features[locale];
  const out = [
    `## ${line(page.title)}`,
    "",
    `URL: ${pageUrl(input.site, "/features/", locale)}`,
    "",
  ];
  out.push(line(page.intro), "", line(page.status.note), "");
  for (const section of page.sections) {
    out.push(
      `### ${line(section.heading)} (${page.status[section.status]})`,
      "",
      line(section.body),
      "",
    );
    for (const point of section.points) out.push(`- ${line(point)}`);
    out.push("");
  }
  return out;
}

function howItWorksSection(input: LlmsInput, locale: Locale): string[] {
  const page = input.howItWorks[locale];
  const out = [
    `## ${line(page.title)}`,
    "",
    `URL: ${pageUrl(input.site, "/how-it-works/", locale)}`,
    "",
  ];
  out.push(line(page.intro), "");
  page.steps.forEach((step, index) => {
    out.push(`### ${index + 1}. ${line(step.heading)}`, "", line(step.body), "");
    for (const point of step.points) out.push(`- ${line(point)}`);
    if (step.points.length > 0) out.push("");
  });
  return out;
}

function faqSection(input: LlmsInput, locale: Locale): string[] {
  const page = input.faq[locale];
  const out = [`## ${line(page.title)}`, "", `URL: ${pageUrl(input.site, "/faq/", locale)}`, ""];
  out.push(line(page.intro), "");
  for (const group of page.groups) {
    out.push(`### ${line(group.heading)}`, "");
    for (const item of group.items)
      out.push(`#### ${line(item.question)}`, "", line(item.answer), "");
  }
  return out;
}

function downloadSection(input: LlmsInput, locale: Locale): string[] {
  const page = input.download[locale];
  const out = [
    `## ${line(page.title)}`,
    "",
    `URL: ${pageUrl(input.site, "/download/", locale)}`,
    "",
  ];
  out.push(line(page.intro), "");
  for (const platform of page.platforms) {
    out.push(`- **${line(platform.name)}** (${line(platform.status)}): ${line(platform.body)}`);
  }
  out.push(
    "",
    `### ${line(page.webApp.heading)}`,
    "",
    `${line(page.webApp.body)} ${input.appUrl}`,
    "",
  );
  out.push(`### ${line(page.requirements.heading)}`, "");
  for (const item of page.requirements.items) out.push(`- ${line(item)}`);
  out.push("");
  return out;
}

function toolSection(input: LlmsInput, tool: LlmsTool): string[] {
  const strings = ui(tool.locale);
  const out = [
    `## ${line(tool.title)}`,
    "",
    `URL: ${pageUrl(input.site, toolPath(tool.slug), tool.locale)}`,
    "",
    `${strings.guide.lastReviewed}: ${tool.lastReviewed}. ${strings.tools.notAdvice}`,
    "",
    line(tool.intro),
    "",
  ];
  if (tool.disclaimer !== undefined) out.push(line(tool.disclaimer), "");
  out.push(markdownBody(input.site, tool.body), "", ...sourcesList(tool.locale, tool.sources));
  return out;
}

function textPageSection(input: LlmsInput, page: LlmsTextPage): string[] {
  return [
    `## ${line(page.title)}`,
    "",
    `URL: ${pageUrl(input.site, textPagePath(page.slug), page.locale)}`,
    "",
    `${ui(page.locale).textPage.lastUpdated}: ${page.lastUpdated}.`,
    "",
    markdownBody(input.site, page.body),
    "",
  ];
}

/** An index page (/guides/ or /tools/): its introduction and the pages it lists. */
function indexSection(
  input: LlmsInput,
  locale: Locale,
  path: string,
  strings: { heading: string; intro: string },
  entries: readonly { title: string; description: string; path: string }[],
): string[] {
  return [
    `## ${line(strings.heading)}`,
    "",
    `URL: ${pageUrl(input.site, path, locale)}`,
    "",
    line(strings.intro),
    "",
    ...entries.map(
      (entry) =>
        `- [${line(entry.title)}](${pageUrl(input.site, entry.path, locale)}): ${line(entry.description)}`,
    ),
    "",
  ];
}

/** The whole site's text in one file: English pages first, then Urdu. */
export function llmsFullTxt(input: LlmsInput): string {
  const out: string[] = [
    `# ${SITE.name} (${SITE.nameUrdu}): the full text of the website`,
    "",
    `> ${line(input.home.en.description)}`,
    "",
    `This file holds the text of every page of ${absoluteUrl(input.site, "/")}, in English and then in Urdu. ${ui("en").footer.disclaimer}`,
    "",
  ];
  for (const locale of LOCALES) {
    out.push(
      ...homeSection(input, locale),
      ...featuresSection(input, locale),
      ...howItWorksSection(input, locale),
      ...faqSection(input, locale),
      ...downloadSection(input, locale),
    );
    const guides = input.guides.filter((candidate) => candidate.locale === locale);
    const tools = input.tools.filter((candidate) => candidate.locale === locale);
    out.push(
      ...indexSection(
        input,
        locale,
        "/guides/",
        ui(locale).guides,
        guides.map((guide) => ({ ...guide, path: guidePath(guide.slug) })),
      ),
    );
    for (const guide of guides) out.push(...guideSection(input, guide));
    out.push(
      ...indexSection(
        input,
        locale,
        "/tools/",
        ui(locale).tools,
        tools.map((tool) => ({ ...tool, path: toolPath(tool.slug) })),
      ),
    );
    for (const tool of tools) out.push(...toolSection(input, tool));
    for (const page of input.textPages.filter((candidate) => candidate.locale === locale)) {
      out.push(...textPageSection(input, page));
    }
    out.push(...licencesSection(input, locale));
  }
  return `${out.join("\n").trimEnd()}\n`;
}
