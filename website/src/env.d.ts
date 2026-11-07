/// <reference types="astro/client" />

interface ImportMetaEnv {
  /** The web app's address; see website/README.md. Defaults to https://maalik-e-makaan.vercel.app. */
  readonly PUBLIC_APP_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
