import { resolveAppUrl } from "./urls.ts";

/** The web app's address, from PUBLIC_APP_URL (validated when the site is built). */
export const APP_URL = resolveAppUrl(import.meta.env.PUBLIC_APP_URL);
