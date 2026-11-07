import type { APIRoute } from "astro";
import { APP_URL } from "../config/app-url.ts";
import { loadLlmsInput } from "../lib/content/load.ts";
import { llmsFullTxt } from "../lib/llms.ts";

/** The whole site's text in one Markdown file (https://llmstxt.org). */
export const GET: APIRoute = async ({ site }) => {
  if (site === undefined) throw new Error("Set `site` in astro.config.ts");
  return new Response(llmsFullTxt(await loadLlmsInput(site, APP_URL)), {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
};
