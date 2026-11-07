// Stylelint: stylelint-config-standard, logical properties only (so every
// margin, padding, inset, border and text alignment mirrors for Urdu), and
// colours only from the design tokens' --mm-color-* custom properties.

/** Colour properties whose value must be a token (or a keyword with no colour of its own). */
const COLOUR_PROPERTIES =
  /^(color|background-color|border(-(block|inline|top|right|bottom|left))?(-(start|end))?-color|outline-color|text-decoration-color|caret-color|accent-color|column-rule-color|fill|stroke)$/;

/** @type {import("stylelint").Config} */
export default {
  extends: ["stylelint-config-standard"],
  plugins: ["stylelint-use-logical"],
  ignoreFiles: [
    "dist/**",
    ".astro/**",
    "node_modules/**",
    "src/generated/**",
    "public/**",
    "playwright-report/**",
    "test-results/**",
    ".lighthouseci/**",
  ],
  overrides: [{ files: ["**/*.astro"], customSyntax: "postcss-html" }],
  rules: {
    // Right-to-left safety: logical properties and values only.
    "csstools/use-logical": "always",
    // Colours come from the design tokens, never from literals.
    "color-no-hex": true,
    "color-named": "never",
    "function-disallowed-list": [
      "rgb",
      "rgba",
      "hsl",
      "hsla",
      "hwb",
      "lab",
      "lch",
      "oklab",
      "oklch",
      "color",
    ],
    "declaration-property-value-allowed-list": {
      [`/${COLOUR_PROPERTIES.source}/`]: [
        /^var\(--mm-color-[a-z0-9-]+\)$/,
        "currentcolor",
        "transparent",
        "inherit",
      ],
    },
    // Class names: block__element--modifier.
    "selector-class-pattern": [
      /^[a-z][a-z0-9]*(-[a-z0-9]+)*(__[a-z0-9]+(-[a-z0-9]+)*)?(--[a-z0-9]+(-[a-z0-9]+)*)?$/,
      { message: (selector) => `Expected class "${selector}" to be block__element--modifier` },
    ],
    // Astro's scoped styles reach into child components with :global().
    "selector-pseudo-class-no-unknown": [true, { ignorePseudoClasses: ["global"] }],
  },
};
