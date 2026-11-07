// ESLint flat config: @eslint/js and typescript-eslint (strict, type-checked)
// for TypeScript; eslint-plugin-astro with eslint-plugin-jsx-a11y's strict
// rules for .astro components.
import js from "@eslint/js";
import astro from "eslint-plugin-astro";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

const TYPESCRIPT = ["**/*.ts"];

export default defineConfig(
  globalIgnores([
    "dist/",
    ".astro/",
    "src/generated/",
    "public/",
    "playwright-report/",
    "test-results/",
    ".lighthouseci/",
  ]),
  js.configs.recommended,
  {
    languageOptions: { globals: { ...globals.node } },
    linterOptions: { reportUnusedDisableDirectives: "error" },
  },
  // TypeScript: the strictest typescript-eslint presets, with type information.
  {
    files: TYPESCRIPT,
    extends: [tseslint.configs.strictTypeChecked, tseslint.configs.stylisticTypeChecked],
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      // Template literals take numbers and booleans; the rule's defaults allow both.
      "@typescript-eslint/restrict-template-expressions": [
        "error",
        { allowNumber: true, allowBoolean: true },
      ],
    },
  },
  // Astro components: the plugin's recommended rules and every jsx-a11y rule it maps, strictly.
  astro.configs["flat/recommended"],
  astro.configs["flat/jsx-a11y-strict"],
  // A table too wide for a phone sits in a named region that scrolls on its own; the region
  // must be focusable so keyboard users can scroll it (WCAG 2.1.1, axe's
  // scrollable-region-focusable).
  {
    files: ["**/*.astro"],
    rules: {
      "astro/jsx-a11y/no-noninteractive-tabindex": [
        "error",
        { tags: [], roles: ["tabpanel", "region"], allowExpressionValues: true },
      ],
    },
  },
  // typescript-eslint's strict rules in components too (its parser stays astro-eslint-parser's).
  {
    files: ["**/*.astro"],
    plugins: { "@typescript-eslint": tseslint.plugin },
    rules: Object.assign({}, ...tseslint.configs.strict.map((config) => config.rules ?? {})),
  },
  // Lighthouse CI reads a CommonJS config.
  {
    files: ["**/*.cjs"],
    languageOptions: { sourceType: "commonjs", globals: { ...globals.node } },
  },
);
