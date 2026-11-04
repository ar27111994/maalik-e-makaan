import { assert, assertEquals, assertFalse } from '@std/assert';
import {
  escapeHtml,
  isCleanText,
  isForbiddenCodePoint,
  singleLine,
  truncate,
} from '../_shared/text.ts';

const char = (codePoint: number) => String.fromCodePoint(codePoint);

// Inclusive forbidden ranges; mirrors app.is_clean_text and tool/check_unicode.py.
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

Deno.test('isCleanText rejects both ends of every forbidden range', () => {
  for (const [low, high] of FORBIDDEN) {
    assertFalse(isCleanText(`a${char(low)}b`), `U+${low.toString(16)} must be rejected`);
    assertFalse(isCleanText(`a${char(high)}b`), `U+${high.toString(16)} must be rejected`);
  }
});

Deno.test('isCleanText allows the neighbours of the forbidden ranges', () => {
  const allowed = [
    0x0009, // tab
    0x000a, // line feed
    0x000d, // carriage return
    0x0020,
    0x00a0, // no-break space
    0x00ae,
    0x061b,
    0x200c, // zero-width non-joiner (needed for Urdu)
    0x200d, // zero-width joiner
    0x200e, // left-to-right mark
    0x200f, // right-to-left mark
    0x2065,
    0x206a,
    0xfefe,
    0x1f3e0, // a house emoji outside the BMP
  ];
  for (const codePoint of allowed) {
    assert(isCleanText(`a${char(codePoint)}b`), `U+${codePoint.toString(16)} must be allowed`);
  }
});

Deno.test('isCleanText accepts ordinary English and Urdu text', () => {
  assert(isCleanText('Raza Family Properties'));
  assert(isCleanText('مالکِ مکان، گلبرگ لاہور'));
  assert(isCleanText(''));
});

Deno.test('isForbiddenCodePoint matches the ranges exactly', () => {
  assert(isForbiddenCodePoint(0x202e));
  assertFalse(isForbiddenCodePoint(0x202f));
  assertFalse(isForbiddenCodePoint(0x41));
});

Deno.test('escapeHtml escapes the five HTML-significant characters', () => {
  assertEquals(
    escapeHtml(`<a href="x" title='y'>Tom & Jerry</a>`),
    '&lt;a href=&quot;x&quot; title=&#39;y&#39;&gt;Tom &amp; Jerry&lt;/a&gt;',
  );
  assertEquals(escapeHtml('plain text, اردو'), 'plain text, اردو');
});

Deno.test('singleLine collapses every kind of whitespace and trims', () => {
  assertEquals(singleLine('  Rent\r\nReminder\t now  '), 'Rent Reminder now');
  assertEquals(singleLine('Bcc: x@example.com\nSubject'), 'Bcc: x@example.com Subject');
});

Deno.test('truncate shortens by code points and marks the cut', () => {
  assertEquals(truncate('short', 10), 'short');
  assertEquals(truncate('exactly10!', 10), 'exactly10!');
  assertEquals(truncate('a longer sentence', 8), 'a longe…');
  // Surrogate pairs count as one character and are never split.
  assertEquals(truncate('🏠🏠🏠🏠', 3), '🏠🏠…');
  assertEquals(truncate('abc', 0), '…');
});
