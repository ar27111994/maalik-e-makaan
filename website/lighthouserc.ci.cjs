// Lighthouse CI for the CI job: the same settings and budgets as
// lighthouserc.cjs, on a representative subset of pages in both languages
// (the home page, a guide, a calculator and the FAQ), so the job stays short.
// The full run over every page is `npm run lighthouse`.
//
//   npm run build && npm run lighthouse:ci
const base = require("./lighthouserc.cjs");

const SUBSET = [
  "/",
  "/guides/rental-income-tax/",
  "/tools/s155-withholding-calculator/",
  "/faq/",
].flatMap((path) => [path, `/ur${path}`]);

/** @type {string[]} */
const all = base.ci.collect.url;
const url = SUBSET.map((path) => {
  const match = all.find((candidate) => new URL(candidate).pathname === path);
  if (match === undefined) {
    throw new Error(`lighthouserc.ci.cjs: ${path} is not a page of dist/.`);
  }
  return match;
});

module.exports = {
  ci: { ...base.ci, collect: { ...base.ci.collect, url } },
};
