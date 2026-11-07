import { existsSync } from "node:fs";

export default function globalSetup(): void {
  if (!existsSync(new URL("../../dist/index.html", import.meta.url))) {
    throw new Error("dist/ is missing: run `npm run build` before `npm run test:e2e`.");
  }
}
