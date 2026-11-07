import type { APIRoute, GetStaticPaths } from "astro";
import { licenceText } from "../../lib/licence-texts.ts";
import { FONT_LICENCES } from "../../lib/licences.ts";

/** Serves each font's SIL Open Font License text, which must travel with the fonts. */
export const getStaticPaths = (() =>
  FONT_LICENCES.map((font) => ({ params: { licence: font.slug } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(licenceText(params.licence ?? ""), {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
