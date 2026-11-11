import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import {
  downloadSchema,
  faqSchema,
  featuresSchema,
  guideSchema,
  homeSchema,
  howItWorksSchema,
  licencesSchema,
  pricingSchema,
  textPageSchema,
  toolSchema,
} from "./lib/content/schemas.ts";

/** A page of copy in YAML: src/content/<folder>/en.yaml and ur.yaml. */
const yamlPair = (folder: string) => glob({ pattern: "*.yaml", base: `./src/content/${folder}` });

/**
 * Content collections. Each language has its own file; see website/README.md
 * ("Content and translations").
 */
export const collections = {
  /** The home page copy: src/content/home/en.yaml and ur.yaml. */
  home: defineCollection({ loader: yamlPair("home"), schema: homeSchema }),
  /** The licences page copy: src/content/licences/en.yaml and ur.yaml. */
  licences: defineCollection({ loader: yamlPair("licences"), schema: licencesSchema }),
  /** The questions page (/faq/). */
  faq: defineCollection({ loader: yamlPair("faq"), schema: faqSchema }),
  /** The features page (/features/). */
  features: defineCollection({ loader: yamlPair("features"), schema: featuresSchema }),
  /** The how-it-works page (/how-it-works/). */
  howItWorks: defineCollection({ loader: yamlPair("how-it-works"), schema: howItWorksSchema }),
  /** The pricing page (/pricing/). */
  pricing: defineCollection({ loader: yamlPair("pricing"), schema: pricingSchema }),
  /** The app page (/download/). */
  download: defineCollection({ loader: yamlPair("download"), schema: downloadSchema }),
  /** Guides: src/content/guides/<en|ur>/<slug>.md or .mdx, the same slug in both folders. */
  guides: defineCollection({
    loader: glob({ pattern: "{en,ur}/*.{md,mdx}", base: "./src/content/guides" }),
    schema: guideSchema,
  }),
  /** Calculators: src/content/tools/<en|ur>/<slug>.md, served at /tools/<slug>/. */
  tools: defineCollection({
    loader: glob({ pattern: "{en,ur}/*.md", base: "./src/content/tools" }),
    schema: toolSchema,
  }),
  /** Pages of running text: src/content/pages/<en|ur>/<slug>.md, served at /<slug>/. */
  pages: defineCollection({
    loader: glob({ pattern: "{en,ur}/*.md", base: "./src/content/pages" }),
    schema: textPageSchema,
  }),
};
