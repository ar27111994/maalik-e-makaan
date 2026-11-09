import { assertEquals, assertInstanceOf, assertRejects, assertStrictEquals } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  hitRateLimit,
  type RateLimit,
  rateLimitedError,
  type RateLimitVerdict,
} from '../_shared/rate_limit.ts';
import { fakeClient, type Result, USER_ID } from './_helpers.ts';

const RULE: RateLimit = { key: `delete_account:user:${USER_ID}`, limit: 10, windowSeconds: 600 };

// --- rateLimitedError ----------------------------------------------------------

Deno.test('rateLimitedError is a 429 rate_limited with the given Retry-After', () => {
  for (const seconds of [1, 30, 600, 3600]) {
    const error = rateLimitedError(seconds);
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
        headers: { 'retry-after': String(seconds) },
        details: undefined,
        cause: undefined,
      },
      String(seconds),
    );
  }
});

// --- hitRateLimit ----------------------------------------------------------------

Deno.test('hitRateLimit counts a hit in the database and returns its verdict and wait', async () => {
  const cases: ReadonlyArray<readonly [Record<string, unknown>, RateLimitVerdict]> = [
    [{ allowed: true, retry_after_seconds: 600 }, { allowed: true, retryAfterSeconds: 600 }],
    [{ allowed: false, retry_after_seconds: 1 }, { allowed: false, retryAfterSeconds: 1 }],
    [{ allowed: false, retry_after_seconds: 3600 }, { allowed: false, retryAfterSeconds: 3600 }],
    // Extra fields from a newer database are ignored.
    [{ allowed: false, retry_after_seconds: 42, window: 'x' }, {
      allowed: false,
      retryAfterSeconds: 42,
    }],
  ];
  for (const [data, verdict] of cases) {
    const admin = fakeClient({ rpc: () => ({ data }) });
    assertEquals(await hitRateLimit(admin.client, RULE), verdict, JSON.stringify(data));
    assertEquals(admin.calls, [{
      kind: 'rpc',
      args: [
        'admin_rate_limit_hit',
        { p_key: `delete_account:user:${USER_ID}`, p_limit: 10, p_window_seconds: 600 },
      ],
    }]);
  }
});

/** Asserts that [hit] rejects with the limiter's 502, returning its cause. */
async function assertLimiterFailure(hit: Promise<RateLimitVerdict>): Promise<unknown> {
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
  const results: Result[] = [
    { error: failure },
    { data: { allowed: true, retry_after_seconds: 1 }, error: failure },
  ];
  for (const result of results) {
    const admin = fakeClient({ rpc: () => result });
    assertStrictEquals(await assertLimiterFailure(hitRateLimit(admin.client, RULE)), failure);
    assertEquals(admin.calls.length, 1);
  }
});

Deno.test('hitRateLimit refuses a response that is not a verdict with a wait of 1 to 3600 s', async () => {
  const cases: ReadonlyArray<readonly [unknown, string]> = [
    [null, 'null'],
    [true, 'true'],
    [false, 'false'],
    ['true', '"true"'],
    [1, '1'],
    [[{ allowed: true, retry_after_seconds: 1 }], '[{"allowed":true,"retry_after_seconds":1}]'],
    [{ allowed: true }, '{"allowed":true}'],
    [{ retry_after_seconds: 5 }, '{"retry_after_seconds":5}'],
    [{ allowed: 'true', retry_after_seconds: 5 }, '{"allowed":"true","retry_after_seconds":5}'],
    [{ allowed: false, retry_after_seconds: '5' }, '{"allowed":false,"retry_after_seconds":"5"}'],
    [{ allowed: false, retry_after_seconds: 0 }, '{"allowed":false,"retry_after_seconds":0}'],
    [{ allowed: false, retry_after_seconds: 1.5 }, '{"allowed":false,"retry_after_seconds":1.5}'],
    [{ allowed: false, retry_after_seconds: 3601 }, '{"allowed":false,"retry_after_seconds":3601}'],
  ];
  for (const [data, json] of cases) {
    const admin = fakeClient({ rpc: () => ({ data }) });
    const cause = await assertLimiterFailure(hitRateLimit(admin.client, RULE));
    assertInstanceOf(cause, Error);
    assertEquals(cause.message, `unexpected limiter response: ${json}`, json);
  }
});
