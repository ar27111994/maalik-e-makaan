import { assertEquals, assertMatch } from '@std/assert';
import { sha256Hex, timingSafeEqual } from '../_shared/crypto.ts';

const char = (...codePoints: number[]) => String.fromCodePoint(...codePoints);
const MAALIK = char(0x0645, 0x0627, 0x0644, 0x06a9);
const TOKEN = 'a'.repeat(31) + 'Z';

Deno.test('timingSafeEqual is true for identical strings', async () => {
  for (const value of ['', 's3cret-token', TOKEN, 'x'.repeat(4096), MAALIK, char(0x1f3e0)]) {
    assertEquals(await timingSafeEqual(value, value), true, value.slice(0, 20));
  }
});

Deno.test('timingSafeEqual is false when the strings differ anywhere', async () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['s3cret-token', 'x3cret-token'], // first character
    ['s3cret-token', 's3cret-tokeN'], // last character, case only
    ['s3cret-token', 's3cret_token'], // middle
    [TOKEN, TOKEN.toLowerCase()],
    [MAALIK, char(0x0645, 0x0627, 0x0644, 0x06af)],
  ];
  for (const [a, b] of cases) {
    assertEquals(await timingSafeEqual(a, b), false, `${a} / ${b}`);
    assertEquals(await timingSafeEqual(b, a), false, `${b} / ${a}`);
  }
});

Deno.test('timingSafeEqual is false for different lengths, prefixes included', async () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['', 'not empty'],
    ['short', 'a much longer secret value'],
    [TOKEN, `${TOKEN} `],
    [TOKEN, TOKEN.slice(0, -1)],
  ];
  for (const [a, b] of cases) {
    assertEquals(await timingSafeEqual(a, b), false, `${a} / ${b}`);
    assertEquals(await timingSafeEqual(b, a), false, `${b} / ${a}`);
  }
});

Deno.test('sha256Hex is the lower-case hex SHA-256 of the UTF-8 bytes', async () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    // FIPS 180-2 test vectors.
    ['', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'],
    ['abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'],
    [
      'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    ],
    // UTF-8 encoding: d9 85 d8 a7 d9 84 da a9.
    [MAALIK, '157e38d1f67bfa87852d6db3d0fa6669d833bc0bd2799588d3324413327dcc97'],
  ];
  for (const [value, digest] of cases) {
    const hex = await sha256Hex(value);
    assertEquals(hex, digest, JSON.stringify(value));
    // Every byte is two digits: "abc" has a 0x01 byte ("8f01").
    assertMatch(hex, /^[0-9a-f]{64}$/);
  }
});
