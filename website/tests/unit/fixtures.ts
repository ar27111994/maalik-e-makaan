// Content fixtures for unit tests, read from the real content files.
import { readFileSync } from "node:fs";
import { parse } from "yaml";
import {
  downloadSchema,
  faqSchema,
  featuresSchema,
  homeSchema,
  howItWorksSchema,
  licencesSchema,
  pricingSchema,
  companySchema,
  type DownloadContent,
  type FaqContent,
  type FeaturesContent,
  type HomeContent,
  type HowItWorksContent,
  type LicencesContent,
  type PricingContent,
  type CompanyContent,
} from "../../src/lib/content/schemas.ts";

const read = (path: string): unknown =>
  parse(readFileSync(new URL(`../../src/content/${path}`, import.meta.url), "utf8"));

export const home: Record<"en" | "ur", HomeContent> = {
  en: homeSchema.parse(read("home/en.yaml")),
  ur: homeSchema.parse(read("home/ur.yaml")),
};

export const licences: Record<"en" | "ur", LicencesContent> = {
  en: licencesSchema.parse(read("licences/en.yaml")),
  ur: licencesSchema.parse(read("licences/ur.yaml")),
};

export const features: Record<"en" | "ur", FeaturesContent> = {
  en: featuresSchema.parse(read("features/en.yaml")),
  ur: featuresSchema.parse(read("features/ur.yaml")),
};

export const howItWorks: Record<"en" | "ur", HowItWorksContent> = {
  en: howItWorksSchema.parse(read("how-it-works/en.yaml")),
  ur: howItWorksSchema.parse(read("how-it-works/ur.yaml")),
};

export const faq: Record<"en" | "ur", FaqContent> = {
  en: faqSchema.parse(read("faq/en.yaml")),
  ur: faqSchema.parse(read("faq/ur.yaml")),
};

export const download: Record<"en" | "ur", DownloadContent> = {
  en: downloadSchema.parse(read("download/en.yaml")),
  ur: downloadSchema.parse(read("download/ur.yaml")),
};

export const licenceTexts: Record<string, string> = {
  "ofl-atkinson-hyperlegible-next": readFileSync(
    new URL(
      "../../../packages/mm_ui/assets/fonts/OFL-AtkinsonHyperlegibleNext.txt",
      import.meta.url,
    ),
    "utf8",
  ),
  "ofl-noto-sans-arabic": readFileSync(
    new URL("../../../packages/mm_ui/assets/fonts/OFL-NotoSansArabic.txt", import.meta.url),
    "utf8",
  ),
  "ofl-noto-nastaliq-urdu": readFileSync(
    new URL("../../../packages/mm_ui/assets/fonts/OFL-NotoNastaliqUrdu.txt", import.meta.url),
    "utf8",
  ),
};

export const pricing: Record<"en" | "ur", PricingContent> = {
  en: pricingSchema.parse(read("pricing/en.yaml")),
  ur: pricingSchema.parse(read("pricing/ur.yaml")),
};

export const company: Record<"en" | "ur", CompanyContent> = {
  en: companySchema.parse(read("company/en.yaml")),
  ur: companySchema.parse(read("company/ur.yaml")),
};
