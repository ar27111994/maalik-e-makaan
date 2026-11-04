import { assert, assertEquals, assertFalse } from '@std/assert';
import { sha256Hex, timingSafeEqual } from '../_shared/crypto.ts';

Deno.test('timingSafeEqual is true only for identical strings', async () => {
  assert(await timingSafeEqual('s3cret-token', 's3cret-token'));
  assert(await timingSafeEqual('', ''));
  assert(await timingSafeEqual('مالک', 'مالک'));
  assertFalse(await timingSafeEqual('s3cret-token', 's3cret-tokeN'));
  assertFalse(await timingSafeEqual('s3cret-token', 'x3cret-token'));
});

Deno.test('timingSafeEqual handles different lengths without throwing', async () => {
  assertFalse(await timingSafeEqual('short', 'a much longer secret value'));
  assertFalse(await timingSafeEqual('', 'not empty'));
});

Deno.test('sha256Hex matches the FIPS 180-2 test vectors', async () => {
  assertEquals(
    await sha256Hex('abc'),
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
  );
  assertEquals(
    await sha256Hex(''),
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  );
});
