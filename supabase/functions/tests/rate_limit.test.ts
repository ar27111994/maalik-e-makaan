import { assertEquals, assertInstanceOf, assertRejects, assertStrictEquals } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  hitRateLimit,
  type RateLimit,
  rateLimitedError,
  retryAfterSeconds,
} from '../_shared/rate_limit.ts';
import { fakeClient, NOW, type Result, USER_ID } from './_helpers.ts';

const RULE: RateLimit = { key: `delete_account:user:${USER_ID}`, limit: 10, windowSeconds: 600 };

const at = (iso: string) => new Date(iso);

// --- retryAfterSeconds -----------------------------------------------------------

Deno.test('retryAfterSeconds counts down the fixed window from its start to one second', () => {
  const cases: ReadonlyArray<readonly [string, number, number]> = [
    // [now, window, seconds left]
    ['2026-11-03T12:00:00.000Z', 3600, 3600], // a window start: the full window
    ['2026-11-03T12:00:00.999Z', 3600, 3600], // milliseconds count with their second
    ['2026-11-03T12:00:01.000Z', 3600, 3599],
    ['2026-11-03T12:30:00.000Z', 3600, 1800],
    ['2026-11-03T12:59:59.000Z', 3600, 1], // one second before the end
    ['2026-11-03T12:59:59.999Z', 3600, 1],
    ['2026-11-03T13:00:00.000Z', 3600, 3600], // the next window
    ['2026-11-03T12:00:30.000Z', 60, 30],
    ['2026-11-03T12:00:59.000Z', 60, 1],
    ['2026-11-03T12:05:00.000Z', 600, 300],
    ['2026-11-03T12:10:00.000Z', 600, 600],
    ['2026-11-03T00:00:00.000Z', 86400, 86400],
    ['2026-11-03T12:00:00.000Z', 86400, 43200],
    ['2026-11-03T12:00:00.500Z', 1, 1],
  ];
  for (const [iso, windowSeconds, seconds] of cases) {
    assertEquals(retryAfterSeconds(at(iso), windowSeconds), seconds, `${iso} / ${windowSeconds}s`);
  }
});

Deno.test('retryAfterSeconds counts windows from 2000-01-01T00:00:00Z, not the Unix epoch', () => {
  // 7 s and 1000 s windows do not divide the 946 684 800 s between the two
  // origins, so windows aligned to the Unix epoch would give 2, 2, 800 and 7.
  const cases: ReadonlyArray<readonly [string, number, number]> = [
    ['2000-01-01T00:00:00.000Z', 7, 7],
    ['2026-11-03T12:00:00.000Z', 7, 7],
    ['2026-11-03T12:00:00.000Z', 1000, 600],
    ['1970-01-01T00:00:00.000Z', 7, 5],
  ];
  for (const [iso, windowSeconds, seconds] of cases) {
    assertEquals(retryAfterSeconds(at(iso), windowSeconds), seconds, `${iso} / ${windowSeconds}s`);
  }
});

Deno.test('retryAfterSeconds aligns windows before the origin too', () => {
  const cases: ReadonlyArray<readonly [string, number, number]> = [
    ['1999-12-31T23:59:59.000Z', 60, 1],
    ['1999-12-31T23:59:00.000Z', 60, 60],
    ['1999-12-31T23:59:59.000Z', 7, 1],
    ['1999-12-31T23:00:00.000Z', 3600, 3600],
  ];
  for (const [iso, windowSeconds, seconds] of cases) {
    assertEquals(retryAfterSeconds(at(iso), windowSeconds), seconds, `${iso} / ${windowSeconds}s`);
  }
});

Deno.test('retryAfterSeconds stays within one second and the full window at every second', () => {
  // NOW (2026-11-03T12:00:00Z) starts a window of each of these sizes.
  for (const windowSeconds of [1, 7, 60, 600, 3600]) {
    for (let offset = 0; offset < windowSeconds; offset++) {
      const now = new Date(NOW.getTime() + offset * 1000);
      assertEquals(retryAfterSeconds(now, windowSeconds), windowSeconds - offset);
    }
  }
  // The floor holds even for a window shorter than a second.
  assertEquals(retryAfterSeconds(NOW, 0.5), 1);
});

// --- rateLimitedError ----------------------------------------------------------

Deno.test('rateLimitedError is a 429 rate_limited with Retry-After until the window ends', () => {
  const cases: ReadonlyArray<readonly [string, RateLimit, string]> = [
    ['2026-11-03T12:59:30.000Z', { key: 'k', limit: 3, windowSeconds: 3600 }, '30'],
    ['2026-11-03T12:00:00.000Z', { key: 'k', limit: 3, windowSeconds: 3600 }, '3600'],
    ['2026-11-03T12:09:59.000Z', RULE, '1'],
  ];
  for (const [iso, rule, retryAfter] of cases) {
    const error = rateLimitedError(at(iso), rule);
    assertInstanceOf(error, HttpError);
    assertEquals(
      {
        status: error.status,
        code: error.code,
        message: error.message,
        headers: error.headers,
        details: error.details,
        cause: error.cause,
      },
      {
        status: 429,
        code: 'rate_limited',
        message: 'Too many requests. Please wait a moment.',
        headers: { 'retry-after': retryAfter },
        details: undefined,
        cause: undefined,
      },
      iso,
    );
  }
});

// --- hitRateLimit ----------------------------------------------------------------

Deno.test('hitRateLimit counts a hit in the database and returns the verdict', async () => {
  for (const allowed of [true, false]) {
    const admin = fakeClient({ rpc: () => ({ data: allowed }) });
    assertEquals(await hitRateLimit(admin.client, RULE), allowed);
    assertEquals(admin.calls, [{
      kind: 'rpc',
      args: [
        'admin_hit_rate_limit',
        { p_key: `delete_account:user:${USER_ID}`, p_limit: 10, p_window_seconds: 600 },
      ],
    }]);
  }
});

/** Asserts that [hit] rejects with the limiter's 502, returning its cause. */
async function assertLimiterFailure(hit: Promise<boolean>): Promise<unknown> {
  const error = await assertRejects(() => hit, HttpError);
  assertEquals(
    { status: error.status, code: error.code, message: error.message, headers: error.headers },
    {
      status: 502,
      code: 'upstream_error',
      message: 'The rate limiter is unavailable.',
      headers: {},
    },
  );
  return error.cause;
}

Deno.test('hitRateLimit turns a limiter error into a 502 upstream_error caused by it', async () => {
  const failure = { code: 'PGRST202', message: 'Could not find the function' };
  // An error wins even when data came back with it.
  const results: Result[] = [{ error: failure }, { data: true, error: failure }];
  for (const result of results) {
    const admin = fakeClient({ rpc: () => result });
    assertStrictEquals(await assertLimiterFailure(hitRateLimit(admin.client, RULE)), failure);
    assertEquals(admin.calls.length, 1);
  }
});

Deno.test('hitRateLimit refuses a response that is not a boolean', async () => {
  const cases: ReadonlyArray<readonly [unknown, string]> = [
    [null, 'null'],
    ['true', '"true"'],
    [1, '1'],
    [0, '0'],
    [{ allowed: true }, '{"allowed":true}'],
    [[true], '[true]'],
  ];
  for (const [data, json] of cases) {
    const admin = fakeClient({ rpc: () => ({ data }) });
    const cause = await assertLimiterFailure(hitRateLimit(admin.client, RULE));
    assertInstanceOf(cause, Error);
    assertEquals(cause.message, `unexpected limiter response: ${json}`);
  }
});
