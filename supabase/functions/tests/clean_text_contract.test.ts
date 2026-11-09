/**
 * The functions' text rules against contracts/clean_text.json, the contract
 * the database CHECKs, the app's sanitiser and the repository guard share.
 */

import { assert, assertEquals } from '@std/assert';
import { isCleanText, isForbiddenCodePoint } from '../_shared/text.ts';

interface Range {
  readonly from: string;
  readonly to: string;
  readonly label: string;
}

const contract = JSON.parse(
  await Deno.readTextFile(new URL('../../../contracts/clean_text.json', import.meta.url)),
) as { forbidden: Range[]; allowed_samples: { code_point: string; label: string }[] };

const codePoint = (text: string): number => {
  assert(text.startsWith('U+'), `not a code point: ${text}`);
  return Number.parseInt(text.slice(2), 16);
};

const ranges: ReadonlyArray<readonly [number, number]> = contract.forbidden.map(
  (range) => [codePoint(range.from), codePoint(range.to)] as const,
);
const inContract = (cp: number) => ranges.some(([low, high]) => cp >= low && cp <= high);

Deno.test('every code point is forbidden exactly when the contract forbids it', () => {
  const mismatches: string[] = [];
  for (let cp = 0; cp <= 0x10ffff; cp++) {
    if (isForbiddenCodePoint(cp) !== inContract(cp)) {
      mismatches.push(`U+${cp.toString(16).toUpperCase().padStart(4, '0')}`);
    }
  }
  assertEquals(mismatches, []);
});

Deno.test('the contract samples are clean text', () => {
  for (const sample of contract.allowed_samples) {
    assert(
      isCleanText(String.fromCodePoint(codePoint(sample.code_point))),
      `${sample.code_point} ${sample.label}`,
    );
  }
});

Deno.test('text with a forbidden code point anywhere is rejected', () => {
  for (const [low] of ranges) {
    assertEquals(isCleanText(`Ali${String.fromCodePoint(low)}Raza`), false);
  }
});
