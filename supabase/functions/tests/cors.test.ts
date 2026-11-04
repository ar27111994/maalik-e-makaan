import { assertEquals } from '@std/assert';
import {
  ALLOWED_REQUEST_HEADERS,
  corsHeaders,
  EXPOSED_RESPONSE_HEADERS,
  isOriginAllowed,
} from '../_shared/cors.ts';
import { APP_ORIGIN } from './_helpers.ts';

const ALLOWED = [APP_ORIGIN, 'http://localhost:3000'];

/** Origins that differ from an allowlisted one in some way a browser would send. */
const NOT_ALLOWED = [
  'https://app.example.com/',
  'HTTPS://APP.EXAMPLE.COM',
  'http://app.example.com',
  'https://app.example.com:443',
  'https://app.example.com:8443',
  'https://app.example.com.evil.test',
  'https://evil.test',
  'http://localhost:3001',
  'null',
  '',
];

Deno.test('isOriginAllowed matches an allowlisted origin exactly', () => {
  for (const origin of ALLOWED) {
    assertEquals(isOriginAllowed(origin, ALLOWED), true, origin);
  }
  for (const origin of [...NOT_ALLOWED, null]) {
    assertEquals(isOriginAllowed(origin, ALLOWED), false, String(origin));
  }
  assertEquals(isOriginAllowed(APP_ORIGIN, []), false);
});

Deno.test('the CORS header lists name what clients send and may read', () => {
  assertEquals(ALLOWED_REQUEST_HEADERS, [
    'authorization',
    'apikey',
    'content-type',
    'x-client-info',
    'x-region',
    'x-health-token',
  ]);
  assertEquals(EXPOSED_RESPONSE_HEADERS, ['x-request-id', 'retry-after']);
});

Deno.test('corsHeaders echoes an allowed origin with the methods plus OPTIONS', () => {
  const cases: ReadonlyArray<readonly [string, readonly string[], string]> = [
    [APP_ORIGIN, ['GET', 'HEAD'], 'GET, HEAD, OPTIONS'],
    ['http://localhost:3000', ['POST'], 'POST, OPTIONS'],
    [APP_ORIGIN, [], 'OPTIONS'],
  ];
  for (const [origin, methods, allowMethods] of cases) {
    assertEquals(corsHeaders(origin, ALLOWED, methods), {
      vary: 'Origin',
      'access-control-allow-origin': origin,
      'access-control-allow-methods': allowMethods,
      'access-control-allow-headers':
        'authorization, apikey, content-type, x-client-info, x-region, x-health-token',
      'access-control-expose-headers': 'x-request-id, retry-after',
      'access-control-max-age': '86400',
    });
  }
});

Deno.test('corsHeaders gives any other or a missing origin only Vary: Origin', () => {
  for (const origin of [...NOT_ALLOWED, null]) {
    assertEquals(corsHeaders(origin, ALLOWED, ['GET']), { vary: 'Origin' }, String(origin));
  }
  assertEquals(corsHeaders(APP_ORIGIN, [], ['GET']), { vary: 'Origin' });
});
