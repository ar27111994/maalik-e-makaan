/**
 * robots.txt (RFC 9309). The site is public information meant to be found and
 * cited, so every crawler may read all of it. The search and AI crawlers are
 * also named one by one, so the welcome is explicit for each of them.
 */
export const NAMED_CRAWLERS = [
  // Search engines.
  "Googlebot",
  "Bingbot",
  "Applebot",
  "DuckDuckBot",
  // AI assistants, AI search and model training.
  "GPTBot",
  "OAI-SearchBot",
  "ChatGPT-User",
  "ClaudeBot",
  "Claude-SearchBot",
  "Claude-User",
  "Google-Extended",
  "Applebot-Extended",
  "PerplexityBot",
  "Perplexity-User",
  "CCBot",
  "Amazonbot",
  "meta-externalagent",
  "DuckAssistBot",
  "MistralAI-User",
  "cohere-ai",
] as const;

export function robotsTxt(site: string | URL): string {
  const sitemap = new URL("/sitemap-index.xml", site).href;
  return [
    "# Maalik-e-Makaan: everything on this site is public. Search engines and AI",
    "# crawlers are welcome to read, index and cite all of it.",
    "",
    "User-agent: *",
    "Allow: /",
    "",
    ...NAMED_CRAWLERS.map((agent) => `User-agent: ${agent}`),
    "Allow: /",
    "",
    `Sitemap: ${sitemap}`,
    "",
  ].join("\n");
}
