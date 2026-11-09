import { assert, assertEquals, assertFalse, assertThrows } from '@std/assert';
import {
  escapeHtml,
  isCleanText,
  isForbiddenCodePoint,
  singleLine,
  truncate,
} from '../_shared/text.ts';

const char = (...codePoints: number[]) => String.fromCodePoint(...codePoints);
const label = (codePoint: number) => `U+${codePoint.toString(16).toUpperCase().padStart(4, '0')}`;

/** The forbidden ranges of contracts/clean_text.json (app.is_clean_text), inclusive. */
const FORBIDDEN: ReadonlyArray<readonly [number, number]> = [
  [0x0000, 0x0008],
  [0x000b, 0x000c],
  [0x000e, 0x001f],
  [0x007f, 0x009f],
  [0x00ad, 0x00ad],
  [0x061c, 0x061c],
  [0x180e, 0x180e],
  [0x200b, 0x200b],
  [0x202a, 0x202e],
  [0x2060, 0x2064],
  [0x2066, 0x2069],
  [0xfeff, 0xfeff],
];

/** The allowed samples of contracts/clean_text.json. */
const ALLOWED_SAMPLES = [
  0x0009, // tab
  0x000a, // line feed
  0x000d, // carriage return
  0x0020, // space
  0x00a0, // no-break space
  0x0627, // Arabic letter alef (Urdu)
  0x06d2, // Arabic letter yeh barree (Urdu)
  0x0650, // Arabic kasra (Urdu diacritic)
  0x200c, // zero-width non-joiner (Urdu)
  0x200d, // zero-width joiner (Urdu, emoji)
  0x200e, // left-to-right mark
  0x200f, // right-to-left mark
  0x2028, // line separator
  0x20a8, // rupee sign
  0x1f3e0, // house emoji
];

// Man, woman, girl, boy joined by zero-width joiners: one grapheme cluster.
const FAMILY = char(0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467, 0x200d, 0x1f466);
// Regional indicators P and K: the flag of Pakistan, one grapheme cluster.
const FLAG = char(0x1f1f5, 0x1f1f0);
// "Shukriya" with damma, kasra and fatha: five clusters over eight code points.
const SHU = char(0x0634, 0x064f);
const KAF = char(0x06a9);
const RE = char(0x0631, 0x0650);
const YE = char(0x06cc, 0x064e);
const HE = char(0x06c1);
const SHUKRIYA = `${SHU}${KAF}${RE}${YE}${HE}`;

// --- isForbiddenCodePoint ------------------------------------------------------

Deno.test('isForbiddenCodePoint forbids both edges and the middle of every range', () => {
  for (const [low, high] of FORBIDDEN) {
    for (const codePoint of [low, Math.floor((low + high) / 2), high]) {
      assert(isForbiddenCodePoint(codePoint), `${label(codePoint)} must be forbidden`);
    }
  }
});

Deno.test('isForbiddenCodePoint allows the code points just outside every range', () => {
  const neighbours = FORBIDDEN.flatMap(([low, high]) => [low - 1, high + 1])
    .filter((codePoint) => codePoint >= 0);
  assertEquals(
    neighbours.map(label).join(' '),
    'U+0009 U+000A U+000D U+000D U+0020 U+007E U+00A0 U+00AC U+00AE U+061B U+061D U+180D ' +
      'U+180F U+200A U+200C U+2029 U+202F U+205F U+2065 U+2065 U+206A U+FEFE U+FF00',
  );
  for (const codePoint of [...neighbours, 0x41, 0x1f3e0, 0x10ffff]) {
    assertFalse(isForbiddenCodePoint(codePoint), `${label(codePoint)} must be allowed`);
  }
});

// --- isCleanText ---------------------------------------------------------------

Deno.test('isCleanText accepts the allowed samples and ordinary English and Urdu text', () => {
  for (const codePoint of ALLOWED_SAMPLES) {
    assert(isCleanText(`a${char(codePoint)}b`), `${label(codePoint)} must be allowed`);
  }
  // "Maalik-e makaan, Gulberg": kaf with a kasra, and an Arabic comma.
  const urdu = [
    char(0x0645, 0x0627, 0x0644, 0x06a9, 0x0650),
    ' ',
    char(0x0645, 0x06a9, 0x0627, 0x0646, 0x060c),
    ' ',
    char(0x06af, 0x0644, 0x0628, 0x0631, 0x06af),
  ].join('');
  for (const text of ['', 'Raza Family Properties', urdu, SHUKRIYA, FAMILY, FLAG]) {
    assert(isCleanText(text), JSON.stringify(text));
  }
});

Deno.test('isCleanText rejects a forbidden character at the start, middle or end', () => {
  for (const [low, high] of FORBIDDEN) {
    for (const forbidden of [char(low), char(high)]) {
      for (const text of [`${forbidden}abc`, `a${forbidden}bc`, `abc${forbidden}`, forbidden]) {
        assertFalse(isCleanText(text), `${label(low)}..${label(high)} in ${JSON.stringify(text)}`);
      }
    }
  }
});

Deno.test('isCleanText checks every code point after an astral character', () => {
  assertFalse(isCleanText(`${FAMILY}${char(0x202e)}`));
  assertFalse(isCleanText(`${char(0x1f3e0)}${char(0xfeff)}`));
});

// --- escapeHtml ----------------------------------------------------------------

Deno.test('escapeHtml escapes each HTML-significant character', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['&', '&amp;'],
    ['<', '&lt;'],
    ['>', '&gt;'],
    ['"', '&quot;'],
    ["'", '&#39;'],
  ];
  for (const [raw, escaped] of cases) {
    assertEquals(escapeHtml(raw), escaped);
  }
  assertEquals(
    escapeHtml(`<a href="x" title='y'>Tom & Jerry</a>`),
    '&lt;a href=&quot;x&quot; title=&#39;y&#39;&gt;Tom &amp; Jerry&lt;/a&gt;',
  );
});

Deno.test('escapeHtml escapes ampersands first, so its own entities stay single', () => {
  assertEquals(escapeHtml('<&>"\''), '&lt;&amp;&gt;&quot;&#39;');
  // Text that already looks escaped is escaped again: it is text, not markup.
  assertEquals(escapeHtml('&lt;b&gt; &amp;'), '&amp;lt;b&amp;gt; &amp;amp;');
});

Deno.test('escapeHtml leaves text without special characters unchanged', () => {
  for (const text of ['', 'plain text, 42%', SHUKRIYA, FAMILY]) {
    assertEquals(escapeHtml(text), text);
  }
});

// --- singleLine ----------------------------------------------------------------

Deno.test('singleLine collapses every run of whitespace to one space and trims', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['  Rent\r\nReminder\t now  ', 'Rent Reminder now'],
    ['Bcc: x@example.com\nSubject: hi', 'Bcc: x@example.com Subject: hi'],
    [`a${char(0x2028)}b${char(0x2029)}c`, 'a b c'],
    [`a${char(0x00a0)}b${char(0x3000)}c`, 'a b c'],
    ['a\v\fb', 'a b'],
    ['one', 'one'],
    ['', ''],
    [' \r\n\t ', ''],
  ];
  for (const [raw, line] of cases) {
    assertEquals(singleLine(raw), line, JSON.stringify(raw));
  }
});

// --- truncate ------------------------------------------------------------------

Deno.test('truncate refuses a max that is not a positive whole number', () => {
  for (const max of [0, -5, 1.5, Number.NaN]) {
    assertThrows(
      () => truncate('abc', max),
      RangeError,
      'max must be a positive integer',
      String(max),
    );
  }
  assertEquals(truncate('abc', 1), '…');
});

Deno.test('truncate keeps text of at most max grapheme clusters unchanged', () => {
  const cases: ReadonlyArray<readonly [string, number]> = [
    ['', 1],
    ['ab', 3],
    ['abc', 3],
    // 33 UTF-16 code units, but only three clusters.
    [FAMILY.repeat(3), 3],
    [FLAG.repeat(2), 2],
    [SHUKRIYA, 5],
  ];
  for (const [text, max] of cases) {
    assertEquals(truncate(text, max), text, `${JSON.stringify(text)} / ${max}`);
  }
});

Deno.test('truncate cuts longer text to max clusters, the last one an ellipsis', () => {
  const cases: ReadonlyArray<readonly [string, number, string]> = [
    ['abcd', 3, 'ab…'],
    ['abcdef', 2, 'a…'],
    ['abcdef', 1, '…'],
    ['Raza Family Properties', 12, 'Raza Family…'],
  ];
  for (const [text, max, cut] of cases) {
    assertEquals(truncate(text, max), cut, `${JSON.stringify(text)} / ${max}`);
  }
});

Deno.test('truncate never splits an emoji sequence, a flag or a letter from its diacritic', () => {
  const cases: ReadonlyArray<readonly [string, number, string]> = [
    [FAMILY.repeat(3), 2, `${FAMILY}…`],
    [`${FAMILY}abc`, 2, `${FAMILY}…`],
    [`a${FAMILY}bc`, 3, `a${FAMILY}…`],
    [FLAG.repeat(4), 3, `${FLAG}${FLAG}…`],
    [`${FLAG}${FLAG}x`, 2, `${FLAG}…`],
    [SHUKRIYA, 4, `${SHU}${KAF}${RE}…`],
    [SHUKRIYA, 2, `${SHU}…`],
    [`${FAMILY}${FLAG}${SHUKRIYA}`, 4, `${FAMILY}${FLAG}${SHU}…`],
  ];
  for (const [text, max, cut] of cases) {
    assertEquals(truncate(text, max), cut, `${JSON.stringify(text)} / ${max}`);
  }
});
