/**
 * Text safety shared by every function.
 *
 * The forbidden set matches the database's `app.is_clean_text` CHECK, the
 * Dart sanitiser in mm_core and tool/check_unicode.py: control characters
 * (except tab, line feed and carriage return), bidirectional overrides and
 * isolates ("Trojan Source"), and invisible spoofing characters. Urdu's
 * zero-width (non-)joiner and the LRM/RLM marks remain allowed.
 */

/**
 * Forbidden code points as inclusive ranges. Written as numbers rather than
 * regex escapes so the source itself never contains (or can be decoded into)
 * the invisible characters it rejects.
 */
const FORBIDDEN_RANGES: ReadonlyArray<readonly [number, number]> = [
  [0x0000, 0x0008], // C0 controls before tab
  [0x000b, 0x000c], // vertical tab, form feed
  [0x000e, 0x001f], // remaining C0 controls
  [0x007f, 0x009f], // DEL and C1 controls
  [0x00ad, 0x00ad], // soft hyphen
  [0x061c, 0x061c], // Arabic letter mark
  [0x180e, 0x180e], // Mongolian vowel separator
  [0x200b, 0x200b], // zero-width space
  [0x202a, 0x202e], // bidi embeddings and overrides
  [0x2060, 0x2064], // word joiner and invisible operators
  [0x2066, 0x2069], // bidi isolates
  [0xfeff, 0xfeff], // byte-order mark
];

/** Whether [codePoint] is one of the forbidden characters. */
export function isForbiddenCodePoint(codePoint: number): boolean {
  return FORBIDDEN_RANGES.some(([low, high]) => codePoint >= low && codePoint <= high);
}

/** True when [value] contains no control, bidi-override or invisible characters. */
export function isCleanText(value: string): boolean {
  for (const char of value) {
    if (isForbiddenCodePoint(char.codePointAt(0) as number)) return false;
  }
  return true;
}

/** Escapes text for HTML element content and quoted attribute values. */
export function escapeHtml(value: string): string {
  // `&` first, so the entities introduced below are not escaped twice.
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

/**
 * Collapses whitespace (including line breaks) to single spaces and trims,
 * for single-line contexts such as e-mail subjects and headers, where a line
 * break could inject extra headers.
 */
export function singleLine(value: string): string {
  return value.replace(/\s+/g, ' ').trim();
}

/** Shortens [value] to at most [max] characters, ending with an ellipsis. */
export function truncate(value: string, max: number): string {
  const chars = Array.from(value);
  return chars.length <= max ? value : `${chars.slice(0, Math.max(0, max - 1)).join('')}…`;
}
