import { assertEquals, assertInstanceOf } from '@std/assert';
import {
  fromAuthFailure,
  fromDatabaseFailure,
  HttpError,
  invalidField,
} from '../_shared/errors.ts';

Deno.test('HttpError carries status, code, details, headers and cause', () => {
  const cause = new Error('root');
  const error = new HttpError(409, 'conflict', 'Exists.', {
    details: { id: 1 },
    headers: { 'retry-after': '5' },
    cause,
  });
  assertInstanceOf(error, Error);
  assertEquals(error.name, 'HttpError');
  assertEquals([error.status, error.code, error.message], [409, 'conflict', 'Exists.']);
  assertEquals(error.details, { id: 1 });
  assertEquals(error.headers, { 'retry-after': '5' });
  assertEquals(error.cause, cause);
});

Deno.test('HttpError defaults to no details and no headers', () => {
  const error = new HttpError(500, 'internal_error', 'Oops.');
  assertEquals(error.details, undefined);
  assertEquals(error.headers, {});
});

Deno.test('invalidField names the field and the reason', () => {
  const error = invalidField('email', 'not_an_email');
  assertEquals([error.status, error.code], [422, 'validation_failed']);
  assertEquals(error.details, { field: 'email', reason: 'not_an_email' });
});

Deno.test('fromAuthFailure blames the caller only for 401s', () => {
  const unauthorized = fromAuthFailure({ status: 401, code: 'INVALID_JWT', message: 'x' });
  assertEquals([unauthorized.status, unauthorized.code], [401, 'unauthorized']);
  assertEquals(unauthorized.details, { reason: 'INVALID_JWT' });

  const misconfigured = fromAuthFailure({ status: 500, code: 'JWKS_NOT_CONFIGURED', message: 'x' });
  assertEquals([misconfigured.status, misconfigured.code], [500, 'server_misconfigured']);
  assertEquals(misconfigured.details, { reason: 'JWKS_NOT_CONFIGURED' });
});

Deno.test('fromDatabaseFailure maps rate limits with a Retry-After header', () => {
  for (
    const error of [
      fromDatabaseFailure({ message: 'x' }, 429),
      fromDatabaseFailure({ code: 'rate_limited', message: 'x' }),
    ]
  ) {
    assertEquals([error.status, error.code], [429, 'rate_limited']);
    assertEquals(error.headers, { 'retry-after': '60' });
  }
});

Deno.test('fromDatabaseFailure maps SQLSTATEs to statuses', () => {
  const cases: Array<[string | null, number, string, Record<string, unknown> | undefined]> = [
    ['42501', 403, 'forbidden', undefined],
    ['22023', 422, 'validation_failed', { reason: 'already_member' }],
    ['23505', 409, 'conflict', undefined],
    ['23503', 422, 'validation_failed', { reason: 'constraint_violation' }],
    ['23514', 422, 'validation_failed', { reason: 'constraint_violation' }],
    ['22P02', 422, 'validation_failed', { reason: 'constraint_violation' }],
    ['PGRST301', 401, 'unauthorized', { reason: 'PGRST301' }],
    ['PGRST302', 401, 'unauthorized', { reason: 'PGRST302' }],
    ['XX000', 502, 'upstream_error', undefined],
    [null, 502, 'upstream_error', undefined],
  ];
  for (const [code, status, errorCode, details] of cases) {
    const error = fromDatabaseFailure({ code, message: 'already_member' }, 400);
    assertEquals(
      [error.status, error.code, error.details],
      [status, errorCode, details],
      `${code}`,
    );
  }
});

Deno.test('fromDatabaseFailure keeps the original failure as the cause of a 502', () => {
  const failure = { code: 'XX000', message: 'internal', details: 'd', hint: 'h' };
  assertEquals(fromDatabaseFailure(failure).cause, failure);
});
