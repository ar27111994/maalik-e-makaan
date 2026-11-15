/// <reference types="astro/client" />

interface ImportMetaEnv {
  /** The web app's address; see website/README.md. Defaults to app.origin in contracts/origins.json. */
  readonly PUBLIC_APP_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
