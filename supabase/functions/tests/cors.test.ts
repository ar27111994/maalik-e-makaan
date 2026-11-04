import { assert, assertEquals, assertFalse } from '@std/assert';
import { corsHeaders, isOriginAllowed } from '../_shared/cors.ts';

const ALLOWED = ['https://app.example.com'];

Deno.test('isOriginAllowed matches origins exactly', () => {
  assert(isOriginAllowed('https://app.example.com', ALLOWED));
  assertFalse(isOriginAllowed('https://app.example.com.evil.test', ALLOWED));
  assertFalse(isOriginAllowed('http://app.example.com', ALLOWED));
  assertFalse(isOriginAllowed(null, ALLOWED));
  assertFalse(isOriginAllowed('https://app.example.com', []));
});

Deno.test('allowed origins are echoed back, never answered with a wildcard', () => {
  assertEquals(corsHeaders('https://app.example.com', ALLOWED, ['GET', 'POST']), {
    vary: 'Origin',
    'access-control-allow-origin': 'https://app.example.com',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers':
      'authorization, apikey, content-type, x-client-info, x-region, x-health-token',
    'access-control-expose-headers': 'x-request-id, retry-after',
    'access-control-max-age': '86400',
  });
});

Deno.test('other or missing origins only get Vary', () => {
  assertEquals(corsHeaders('https://evil.test', ALLOWED, ['GET']), { vary: 'Origin' });
  assertEquals(corsHeaders(null, ALLOWED, ['GET']), { vary: 'Origin' });
});
