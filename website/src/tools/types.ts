/**
 * The calculators' shared shapes. Each calculator is a pure module (inputs in,
 * a `ResultView` out) that both the page (rendered at build time, so the page
 * shows a worked result without JavaScript) and the browser script (after the
 * reader changes the inputs) render the same way.
 */
import type { Locale } from "../i18n/locales.ts";

/**
 * A run of text: plain words, or `math` (figures and operators such as
 * "45,000 × 16 ÷ 30"), which is set in the Latin face, left to right, as a
 * unit inside Urdu sentences too.
 */
export type Segment = string | { readonly math: string };

/** A link inside running text. */
export interface LinkSegment {
  readonly text: string;
  readonly href: string;
}

/** Running text with links: plain strings and links. */
export type RichText = readonly (string | LinkSegment)[];

export interface Figure {
  readonly label: string;
  /** The value, e.g. "Rs 49,500"; set as an amount (tabular Latin figures). */
  readonly value: string;
  /** The one figure the reader came for. */
  readonly primary?: boolean;
}

export interface ResultTable {
  readonly caption: string;
  readonly head: readonly string[];
  /** Cells; the first cell of each row is its header. */
  readonly rows: readonly (readonly string[])[];
}

/** What a calculation shows: a sentence for screen readers, figures, the working and caveats. */
export interface ResultView {
  /** One sentence, announced by the live region when the result changes. */
  readonly summary: string;
  readonly figures: readonly Figure[];
  /** "How this was worked out": one step per item, in order. */
  readonly steps: readonly (readonly Segment[])[];
  readonly table?: ResultTable;
  /** Caveats that apply to this result. */
  readonly notes: readonly string[];
}

export interface Option {
  readonly value: string;
  readonly label: string;
}

/** One input. Text inputs accept Western and Urdu digits. */
export type Field =
  | {
      readonly kind: "text";
      readonly name: string;
      readonly label: string;
      readonly hint?: string;
      /** "Rs" or "روپے", shown at the field's start or end. */
      readonly prefix?: string;
      readonly suffix?: string;
      readonly inputMode: "decimal" | "numeric";
      /** The width in characters the value needs. */
      readonly size: number;
      readonly defaultValue: string;
    }
  | {
      readonly kind: "select";
      readonly name: string;
      readonly label: string;
      readonly hint?: string;
      readonly options: readonly Option[];
      readonly defaultValue: string;
    }
  | {
      readonly kind: "radio";
      readonly name: string;
      readonly legend: string;
      readonly hint?: string;
      readonly options: readonly Option[];
      readonly defaultValue: string;
    };

/** Text fields that belong together, such as day, month and year, under one legend. */
export interface FieldGroup {
  readonly kind: "group";
  readonly name: string;
  readonly legend: string;
  readonly hint?: string;
  readonly fields: readonly Extract<Field, { kind: "text" }>[];
}

export type FormItem = Field | FieldGroup;

/** Field errors by field or group name, each a sentence saying what to fix. */
export type FieldErrors = Readonly<Record<string, string>>;

export type Parsed<T> =
  { readonly ok: true; readonly value: T } | { readonly ok: false; readonly errors: FieldErrors };

/** The words every calculator shares. */
export interface CalculatorChrome {
  readonly submit: string;
  readonly resultHeading: string;
  readonly stepsHeading: string;
  readonly errorSummary: string;
}

/** A calculator: its inputs, how to read them and what to show. */
export interface Calculator<T> {
  /** The id prefix of the form's elements, e.g. "increment". */
  readonly id: string;
  items(locale: Locale): readonly FormItem[];
  parse(values: Readonly<Record<string, string>>, locale: Locale): Parsed<T>;
  view(value: T, locale: Locale): ResultView;
}
