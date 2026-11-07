// subset-font ships no type declarations. These cover the options this site uses;
// see node_modules/subset-font/README.md for the rest.
declare module "subset-font" {
  export interface SubsetFontOptions {
    targetFormat?: "sfnt" | "truetype" | "woff" | "woff2";
    /** Pin an axis to one value, or narrow its range. */
    variationAxes?: Record<string, number | { min: number; max: number; default?: number }>;
    /** OpenType features to keep; all are kept when omitted. */
    keepFeatures?: string[];
    preserveNameIds?: number[];
  }

  export default function subsetFont(
    font: Uint8Array,
    text: string,
    options?: SubsetFontOptions,
  ): Promise<Uint8Array>;
}
