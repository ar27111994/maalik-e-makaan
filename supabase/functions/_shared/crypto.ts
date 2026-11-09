/**
 * Cryptographic helpers built on Web Crypto.
 */

const encoder = new TextEncoder();

/**
 * Compares two secrets in constant time.
 *
 * Both values are HMAC-SHA-256'd with a fresh random key and the digests are
 * compared with an XOR loop that always visits every byte. Hashing first
 * equalises the lengths, so neither the position of the first difference nor
 * the length of the expected secret leaks through timing.
 */
export async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const key = await crypto.subtle.generateKey({ name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.sign('HMAC', key, encoder.encode(a)),
    crypto.subtle.sign('HMAC', key, encoder.encode(b)),
  ]);
  const bytesA = new Uint8Array(digestA);
  const bytesB = new Uint8Array(digestB);
  let diff = 0;
  for (let i = 0; i < bytesA.length; i++) {
    diff |= (bytesA[i] as number) ^ (bytesB[i] as number);
  }
  return diff === 0;
}

/** Lower-case hex SHA-256 of [value], e.g. to key rate limits without storing e-mail addresses. */
export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}
