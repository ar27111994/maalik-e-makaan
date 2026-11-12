/**
 * The Urdu words that follow a figure as its unit, and the months that follow a
 * day: "30 یونٹس", "10 فیصد", "48 گھنٹے", "5 نومبر". On the Urdu pages a figure is
 * joined to them by a no-break space (U+00A0), as amounts are joined to "روپے"
 * and "لاکھ", so a line never ends on the figure and starts the next with its
 * unit. The content test (tests/unit/content-markdown.test.ts) checks the copy
 * in src/content/, and the e2e suite every Urdu page as it is built, dates and
 * the calculators' worked examples included.
 */
export const URDU_UNITS: readonly string[] = [
  "یونٹس",
  "یونٹ",
  "فیصد",
  "دنوں",
  "دن",
  "گھنٹوں",
  "گھنٹے",
  "مہینوں",
  "مہینے",
  "ہفتوں",
  "ہفتے",
  "سالوں",
  "سال",
  "منٹ",
  "جنوری",
  "فروری",
  "مارچ",
  "اپریل",
  "مئی",
  "جون",
  "جولائی",
  "اگست",
  "ستمبر",
  "اکتوبر",
  "نومبر",
  "دسمبر",
];

/**
 * A figure followed by an ordinary space or line break and one of `URDU_UNITS`
 * as a whole word ("30 یونٹس", "3 دن؛"): what the Urdu copy must not hold.
 */
export const URDU_UNIT_SPLIT = new RegExp(
  `[0-9%][ \\t\\n]+(?:${URDU_UNITS.join("|")})(?!\\p{L})`,
  "u",
);
