import { describe, expect, test } from "vitest";
import { inlineCodeProblems, missingTwins, pagePath } from "../../integrations/site-checks.ts";

describe("missingTwins", () => {
  test("normalises Astro's page names", () => {
    expect(pagePath("")).toBe("/");
    expect(pagePath("ur/")).toBe("/ur/");
    expect(pagePath("404")).toBe("/404/");
    expect(pagePath("/licences/")).toBe("/licences/");
  });

  test("passes when every page has its twin and both not-found pages exist", () => {
    expect(missingTwins(["", "ur/", "licences/", "ur/licences/", "404", "ur/404/"])).toEqual([]);
  });

  test("names each page whose translation is missing", () => {
    expect(missingTwins(["", "ur/", "licences/", "404", "ur/404/"])).toEqual([
      "/licences/ → /ur/licences/",
    ]);
    expect(missingTwins(["", "ur/", "ur/guides/x/", "404", "ur/404/"])).toEqual([
      "/ur/guides/x/ → /guides/x/",
    ]);
    expect(missingTwins(["", "ur/", "404"])).toEqual([
      "/ur/404/ (the not-found page in each language)",
    ]);
  });
});

describe("inlineCodeProblems", () => {
  test("allows external scripts, external styles and JSON-LD data blocks", () => {
    const html =
      '<link rel="stylesheet" href="/_astro/a.css"><script type="module" src="/_astro/a.js"></script>' +
      '<script type="application/ld+json">{"@context":"https://schema.org"}</script>';
    expect(inlineCodeProblems(html)).toEqual([]);
  });

  test("reports what the Content-Security-Policy would block", () => {
    expect(inlineCodeProblems("<script>alert(1)</script>")).toEqual(["an inline <script>"]);
    expect(inlineCodeProblems('<script type="module">x()</script>')).toEqual([
      "an inline <script>",
    ]);
    expect(inlineCodeProblems("<style>p{}</style>")).toEqual(["an inline <style>"]);
    expect(inlineCodeProblems('<p style="color: red">x</p>')).toEqual(["a style attribute"]);
    expect(inlineCodeProblems('<button onclick="go()">x</button>')).toEqual([
      "an inline event handler",
    ]);
  });

  test("does not mistake data attributes or text for inline code", () => {
    expect(inlineCodeProblems('<p data-style="x" data-onclick="y">style= onclick=</p>')).toEqual(
      [],
    );
  });
});
