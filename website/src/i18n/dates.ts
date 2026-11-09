import type { Locale } from "./locales.ts";

/**
 * Dates written out for readers. Kept apart from the interface strings so the
 * calculators' browser scripts can use them without bundling every string.
 */

function formatter(locale: Locale, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "ur-PK", {
    ...options,
    timeZone: "UTC",
    numberingSystem: "latn",
  });
}

function utc(iso: string): Date {
  const date = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) throw new RangeError(`Not a date: ${JSON.stringify(iso)}`);
  return date;
}

/**
 * A calendar date (YYYY-MM-DD) written out for readers of `locale`:
 * "5 November 2026" in English, "5 نومبر، 2026" in Urdu. The date is read in
 * UTC so the day never shifts with the build machine's time zone.
 */
export function formatDate(iso: string, locale: Locale): string {
  return formatter(locale, { day: "numeric", month: "long", year: "numeric" }).format(utc(iso));
}

/** A day and month without the year: "15 November", "15 نومبر". */
export function formatDayMonth(iso: string, locale: Locale): string {
  return formatter(locale, { day: "numeric", month: "long" }).format(utc(iso));
}

/** A month and year: "November 2026", "نومبر 2026". */
export function formatMonth(iso: string, locale: Locale): string {
  return formatter(locale, { month: "long", year: "numeric" }).format(utc(iso));
}
