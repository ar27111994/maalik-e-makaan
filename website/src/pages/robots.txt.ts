import type { APIRoute } from "astro";
import { robotsTxt } from "../lib/robots.ts";

export const GET: APIRoute = ({ site }) => {
  if (site === undefined) throw new Error("Set `site` in astro.config.ts");
  return new Response(robotsTxt(site), {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
};
