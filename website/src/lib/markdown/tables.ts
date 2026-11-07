/**
 * Wraps every table in rendered Markdown in a box that scrolls sideways on
 * its own (`.table-scroll`), so a wide table never makes the page scroll at
 * 320 px. The box is focusable and is a named region (labelled by the heading
 * above the table), so keyboard users can scroll it too (WCAG 2.1.1, axe's
 * scrollable-region-focusable).
 *
 * The input is the HTML Astro rendered from our own Markdown at build time;
 * this never runs on anything a visitor typed.
 */
const TOKENS = /<h[2-6]\b[^>]*\sid="([^"]+)"[^>]*>|<table\b[^>]*>|<\/table>/g;

export function wrapTables(html: string): string {
  let headingId: string | undefined;
  return html.replace(TOKENS, (match: string, id: string | undefined) => {
    if (id !== undefined) {
      headingId = id;
      return match;
    }
    if (match.startsWith("</")) return `${match}</div>`;
    const label = headingId === undefined ? "" : ` aria-labelledby="${headingId}"`;
    return `<div class="table-scroll" role="region" tabindex="0"${label}>${match}`;
  });
}
