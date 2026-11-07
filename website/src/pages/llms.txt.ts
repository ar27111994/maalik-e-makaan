import type { APIRoute } from "astro";
import { APP_URL } from "../config/app-url.ts";
import { loadLlmsInput } from "../lib/content/load.ts";
import { llmsTxt } from "../lib/llms.ts";

/** The llms.txt index (https://llmstxt.org). */
export const GET: APIRoute = async ({ site }) => {
  if (site === undefined) throw new Error("Set `site` in astro.config.ts");
  return new Response(llmsTxt(await loadLlmsInput(site, APP_URL)), {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
};
