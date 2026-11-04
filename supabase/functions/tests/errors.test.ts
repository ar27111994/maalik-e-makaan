import { assert, assertEquals, assertInstanceOf, assertStrictEquals } from '@std/assert';
import {
  type AuthFailure,
  type DatabaseFailure,
  type ErrorCode,
  fromAuthFailure,
  fromDatabaseFailure,
  fromServiceFailure,
  HttpError,
  invalidField,
  reauthenticationRequired,
  retryAfterFromHint,
  unauthorized,
} from '../_shared/errors.ts';

/** Everything a client can observe of an error, plus the cause the logs see. */
function observed(error: HttpError): {
  status: number;
  code: ErrorCode;
  message: string;
  details: Readonly<Record<string, unknown>> | undefined;
  headers: Readonly<Record<string, string>>;
  cause: unknown;
} {
  return {
    status: error.status,
    code: error.code,
    message: error.message,
    details: error.details,
    headers: error.headers,
    cause: error.cause,
  };
}

const BEARER = { 'www-authenticate': 'Bearer' };
const TRANSIENT_SQLSTATES = ['40P01', '40001', '55P03', '57014'];

function upstreamError(cause: unknown): ReturnType<typeof observed> {
  return {
    status: 502,
    code: 'upstream_error',
    message: 'The database could not complete the request.',
    details: undefined,
    headers: {},
    cause,
  };
}

function temporarilyUnavailable(cause: unknown): ReturnType<typeof observed> {
  return {
    status: 503,
    code: 'temporarily_unavailable',
    message: 'The service is busy. Please try again.',
    details: undefined,
    headers: { 'retry-after': '1' },
    cause,
  };
}

Deno.test('HttpError carries its status, code, message, details, headers and cause', () => {
  const cause = new Error('root cause');
  const error = new HttpError(409, 'conflict', 'This already exists.', {
    details: { field: 'email' },
    headers: { 'retry-after': '5' },
    cause,
  });
  assertInstanceOf(error, Error);
  assertEquals(error.name, 'HttpError');
  assertEquals(observed(error), {
    status: 409,
    code: 'conflict',
    message: 'This already exists.',
    details: { field: 'email' },
    headers: { 'retry-after': '5' },
    cause,
  });
  assertStrictEquals(error.cause, cause);
});

Deno.test('HttpError without options has no details, no headers and no cause', () => {
  for (
    const error of [
      new HttpError(500, 'internal_error', 'Oops.'),
      new HttpError(500, 'internal_error', 'Oops.', {}),
    ]
  ) {
    assertEquals(observed(error), {
      status: 500,
      code: 'internal_error',
      message: 'Oops.',
      details: undefined,
      headers: {},
      cause: undefined,
    });
  }
});

Deno.test('invalidField is a 422 that names the field and the reason', () => {
  assertEquals(observed(invalidField('email', 'not_an_email')), {
    status: 422,
    code: 'validation_failed',
    message: 'Invalid value for "email".',
    details: { field: 'email', reason: 'not_an_email' },
    headers: {},
    cause: undefined,
  });
});

Deno.test('unauthorized is a 401 with a bare Bearer challenge', () => {
  assertEquals(observed(unauthorized()), {
    status: 401,
    code: 'unauthorized',
    message: 'Sign in to continue.',
    details: undefined,
    headers: BEARER,
    cause: undefined,
  });
  assertEquals(observed(unauthorized('Your session ended.', { reason: 'expired' })), {
    status: 401,
    code: 'unauthorized',
    message: 'Your session ended.',
    details: { reason: 'expired' },
    headers: BEARER,
    cause: undefined,
  });
});

Deno.test('reauthenticationRequired challenges for a sign-in no older than the given age', () => {
  for (const maxAge of [60, 600, 3600]) {
    assertEquals(observed(reauthenticationRequired(maxAge, 'Sign in again.')), {
      status: 401,
      code: 'reauthentication_required',
      message: 'Sign in again.',
      details: { reauth_max_age_seconds: maxAge },
      headers: {
        'www-authenticate': `Bearer error="insufficient_user_authentication", max_age=${maxAge}`,
      },
      cause: undefined,
    });
  }
  assertEquals(
    reauthenticationRequired(600, 'Sign in again to delete your account.').headers,
    { 'www-authenticate': 'Bearer error="insufficient_user_authentication", max_age=600' },
  );
});

Deno.test('fromAuthFailure blames the caller for a 401, keeping the auth code as the reason', () => {
  for (const code of ['INVALID_JWT', 'MISSING_CREDENTIALS', 'UNUSABLE_CREDENTIAL']) {
    assertEquals(observed(fromAuthFailure({ status: 401, code, message: 'credential problem' })), {
      status: 401,
      code: 'unauthorized',
      message: 'Sign in to continue.',
      details: { reason: code },
      headers: BEARER,
      cause: undefined,
    });
  }
});

Deno.test('fromAuthFailure reports any other status as a server misconfiguration', () => {
  const failures: AuthFailure[] = [
    { status: 500, code: 'JWKS_NOT_CONFIGURED', message: 'no JWKS' },
    { status: 500, code: 'JWKS_FETCH_FAILED', message: 'JWKS unreachable' },
    { status: 500, code: 'NO_KEYS_CONFIGURED', message: 'no keys' },
    { status: 500, code: 'MISSING_SUPABASE_URL', message: 'no URL' },
    { status: 400, code: 'AUTH_ERROR', message: 'unexpected' },
    { status: 403, code: 'AUTH_ERROR', message: 'unexpected' },
  ];
  for (const failure of failures) {
    const error = fromAuthFailure(failure);
    assertEquals(observed(error), {
      status: 500,
      code: 'server_misconfigured',
      message: 'Authentication is not configured.',
      details: { reason: failure.code },
      headers: {},
      cause: failure,
    }, `${failure.status} ${failure.code}`);
    assertStrictEquals(error.cause, failure);
  }
});

Deno.test('retryAfterFromHint copies only whole seconds from 1 to 86400 without leading zeros', () => {
  const cases: Array<[string | null | undefined, Record<string, string>]> = [
    ['1', { 'retry-after': '1' }],
    ['9', { 'retry-after': '9' }],
    ['10', { 'retry-after': '10' }],
    ['60', { 'retry-after': '60' }],
    ['86400', { 'retry-after': '86400' }],
    ['86401', {}],
    ['99999', {}],
    ['999999', {}],
    ['1000000', {}],
    ['0', {}],
    ['00', {}],
    ['01', {}],
    ['-1', {}],
    ['+5', {}],
    ['1.5', {}],
    ['1e3', {}],
    [' 5', {}],
    ['5 ', {}],
    ['5\n', {}],
    ['\u0665', {}], // ARABIC-INDIC DIGIT FIVE is not an ASCII digit
    ['x', {}],
    ['', {}],
    [null, {}],
    [undefined, {}],
  ];
  for (const [hint, expected] of cases) {
    assertEquals(retryAfterFromHint(hint), expected, JSON.stringify(hint));
  }
});

Deno.test('fromDatabaseFailure answers 429 for a 429 status or a rate_limited code, first', () => {
  const retryAfter = (seconds: string) => ({ 'retry-after': seconds });
  const cases: Array<[string, DatabaseFailure, number | undefined, Record<string, string>]> = [
    ['code with a hint', { code: 'rate_limited', message: 'm', hint: '30' }, 400, retryAfter('30')],
    ['code alone', { code: 'rate_limited', message: 'm', hint: '30' }, undefined, retryAfter('30')],
    ['status alone', { message: 'm', hint: '86400' }, 429, retryAfter('86400')],
    ['status before 42501', { code: '42501', message: 'm', hint: '5' }, 429, retryAfter('5')],
    ['status before a JWT code', { code: 'PGRST301', message: 'm' }, 429, {}],
    ['status before a transient code', { code: '40001', message: 'm' }, 429, {}],
    ['code before a 401 status', { code: 'rate_limited', message: 'm' }, 401, {}],
    ['hint 0', { code: 'rate_limited', message: 'm', hint: '0' }, 429, {}],
    ['hint 86401', { code: 'rate_limited', message: 'm', hint: '86401' }, 429, {}],
    ['hint 01', { code: 'rate_limited', message: 'm', hint: '01' }, 429, {}],
    ['hint 1.5', { code: 'rate_limited', message: 'm', hint: '1.5' }, 429, {}],
    ['hint x', { code: 'rate_limited', message: 'm', hint: 'x' }, 429, {}],
    ['hint null', { code: 'rate_limited', message: 'm', hint: null }, 429, {}],
  ];
  for (const [label, failure, status, headers] of cases) {
    assertEquals(observed(fromDatabaseFailure(failure, status)), {
      status: 429,
      code: 'rate_limited',
      message: 'Too many requests. Please wait a moment.',
      details: undefined,
      headers,
      cause: undefined,
    }, label);
  }
});

Deno.test('fromDatabaseFailure answers 401 with a Bearer challenge for a 401 status or a PostgREST JWT code', () => {
  const cases: Array<[string, DatabaseFailure, number | undefined, string]> = [
    ['PGRST301 with 401', { code: 'PGRST301', message: 'JWT expired' }, 401, 'PGRST301'],
    ['PGRST301 alone', { code: 'PGRST301', message: 'JWT expired' }, undefined, 'PGRST301'],
    ['PGRST302 with 400', { code: 'PGRST302', message: 'anonymous access' }, 400, 'PGRST302'],
    ['PGRST303 alone', { code: 'PGRST303', message: 'bad claims' }, undefined, 'PGRST303'],
    ['401 with a null code', { code: null, message: 'm' }, 401, 'unauthorized'],
    ['401 without a code', { message: 'm' }, 401, 'unauthorized'],
    ['401 before 42501', { code: '42501', message: 'permission denied' }, 401, '42501'],
    ['401 before a transient code', { code: '40P01', message: 'deadlock' }, 401, '40P01'],
  ];
  for (const [label, failure, status, reason] of cases) {
    assertEquals(observed(fromDatabaseFailure(failure, status)), {
      status: 401,
      code: 'unauthorized',
      message: 'Sign in to continue.',
      details: { reason },
      headers: BEARER,
      cause: undefined,
    }, label);
  }
});

Deno.test('fromDatabaseFailure answers a retryable 503 for transient SQLSTATEs', () => {
  for (const code of TRANSIENT_SQLSTATES) {
    for (const status of [undefined, 400, 500, 503]) {
      const failure = { code, message: 'canceling statement due to statement timeout' };
      const error = fromDatabaseFailure(failure, status);
      assertEquals(observed(error), temporarilyUnavailable(failure), `${code} ${status}`);
      assertStrictEquals(error.cause, failure);
    }
  }
});

Deno.test('fromDatabaseFailure maps domain SQLSTATEs to client errors without leaking the failure', () => {
  const rejected = 'The request was rejected.';
  const cases: Array<[string, number, ErrorCode, string, Record<string, unknown> | undefined]> = [
    ['42501', 403, 'forbidden', 'You do not have access to this.', undefined],
    ['22023', 422, 'validation_failed', rejected, { reason: 'already_member' }],
    ['23505', 409, 'conflict', 'This already exists.', undefined],
    ['23503', 422, 'validation_failed', rejected, { reason: 'constraint_violation' }],
    ['23514', 422, 'validation_failed', rejected, { reason: 'constraint_violation' }],
    ['22P02', 422, 'validation_failed', rejected, { reason: 'constraint_violation' }],
  ];
  for (const [sqlstate, status, code, message, details] of cases) {
    for (const httpStatus of [undefined, 400, 403, 409]) {
      const failure = {
        code: sqlstate,
        message: 'already_member',
        details: 'Key (email)=(owner@example.com) already exists.',
        hint: 'internal hint',
      };
      assertEquals(
        observed(fromDatabaseFailure(failure, httpStatus)),
        { status, code, message, details, headers: {}, cause: undefined },
        `${sqlstate} ${httpStatus}`,
      );
    }
  }
});

Deno.test('fromDatabaseFailure reports anything else as a 502 that keeps the failure as cause', () => {
  const cases: Array<[DatabaseFailure, number | undefined]> = [
    [{ code: 'XX000', message: 'internal error' }, 500],
    [{ code: 'P0001', message: 'raise_exception' }, 400],
    [{ code: '42883', message: 'function does not exist' }, 404],
    [{ code: 'PGRST202', message: 'Could not find the function' }, 404],
    [{ code: 'PGRST116', message: 'multiple rows returned' }, 406],
    [{ code: 'PGRST3', message: 'not a JWT code' }, 400],
    [{ code: 'rate_limit', message: 'not the rate limit code' }, 400],
    [{ code: '', message: 'TypeError: fetch failed' }, 0],
    [{ code: null, message: 'm' }, 400],
    [{ message: 'no code at all' }, undefined],
  ];
  for (const [failure, status] of cases) {
    const error = fromDatabaseFailure(failure, status);
    assertEquals(observed(error), upstreamError(failure), `${failure.code} ${status}`);
    assertStrictEquals(error.cause, failure);
  }
});

Deno.test('fromServiceFailure answers 503 for transient SQLSTATEs and 502 for everything else', () => {
  for (const code of TRANSIENT_SQLSTATES) {
    const failure = { code, message: 'deadlock detected' };
    const error = fromServiceFailure(failure);
    assertEquals(observed(error), temporarilyUnavailable(failure), code);
    assertStrictEquals(error.cause, failure);
  }
  const notTransient: DatabaseFailure[] = [
    { code: '42501', message: 'permission denied' },
    { code: '22023', message: 'already_member' },
    { code: '23505', message: 'duplicate key' },
    { code: '23503', message: 'foreign key' },
    { code: '23514', message: 'check constraint' },
    { code: '22P02', message: 'invalid input syntax' },
    { code: 'rate_limited', message: 'slow down', hint: '30' },
    { code: 'PGRST301', message: 'JWT expired' },
    { code: 'XX000', message: 'internal error' },
    { code: '', message: 'fetch failed' },
    { code: null, message: 'm' },
    { message: 'no code at all' },
  ];
  for (const failure of notTransient) {
    const error = fromServiceFailure(failure);
    assertEquals(observed(error), upstreamError(failure), `${failure.code}`);
    assertStrictEquals(error.cause, failure);
    assert(error.status >= 500, 'a service failure never blames the caller');
  }
});
