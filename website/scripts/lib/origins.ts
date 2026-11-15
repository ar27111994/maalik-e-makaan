/**
 * contracts/origins.json, the production origins of the website and the web
 * app and their earlier addresses (decision D-20), for code that runs on Node
 * without a bundler (the deck renderer, the e2e suite). Code that Vite builds
 * imports the file instead (src/config/urls.ts).
 */
import { readFileSync } from "node:fs";

export interface Origins {
  readonly site: {
    readonly origin: string;
    readonly aliases: readonly string[];
    readonly legacy: readonly string[];
  };
  readonly app: { readonly origin: string; readonly legacy: readonly string[] };
}

export function readOrigins(): Origins {
  const url = new URL("../../../contracts/origins.json", import.meta.url);
  return JSON.parse(readFileSync(url, "utf8")) as Origins;
}
