/**
 * The error model of every function.
 *
 * Handlers throw [HttpError]; the request pipeline turns it into the JSON
 * envelope `{ "error": { "code", "message", "details"?, "request_id" } }`.
 * `code` is stable and machine-readable (clients map it to localised text);
 * `message` is a short English explanation for logs and developers.
 */

export type ErrorCode =
  | 'invalid_json'
  | 'payload_too_large'
  | 'unsupported_media_type'
  | 'validation_failed'
  | 'unauthorized'
  | 'reauthentication_required'
  | 'mfa_required'
  | 'forbidden'
  | 'origin_not_allowed'
  | 'method_not_allowed'
  | 'conflict'
  | 'rate_limited'
  | 'deep_check_disabled'
  | 'server_misconfigured'
  | 'upstream_error'
  | 'internal_error';

export class HttpError extends Error {
  readonly status: number;
  readonly code: ErrorCode;
  readonly details: Readonly<Record<string, unknown>> | undefined;
  readonly headers: Readonly<Record<string, string>>;

  constructor(
    status: number,
    code: ErrorCode,
    message: string,
    options: {
      details?: Record<string, unknown>;
      headers?: Record<string, string>;
      cause?: unknown;
    } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
    this.details = options.details;
    this.headers = options.headers ?? {};
  }
}

/** Shorthand for a 422 on one input field. */
export function invalidField(field: string, reason: string): HttpError {
  return new HttpError(422, 'validation_failed', `Invalid value for "${field}".`, {
    details: { field, reason },
  });
}

/** The parts of an `@supabase/server` AuthError the pipeline relies on. */
export interface AuthFailure {
  readonly status: number;
  readonly code: string;
  readonly message: string;
}

/**
 * Maps an authentication failure from `createSupabaseContext`. A 401 means
 * the caller's credentials are at fault; anything else is a server-side
 * misconfiguration (for example a missing JWKS) and must not blame the caller.
 */
export function fromAuthFailure(failure: AuthFailure): HttpError {
  if (failure.status === 401) {
    return new HttpError(401, 'unauthorized', 'Sign in to continue.', {
      details: { reason: failure.code },
    });
  }
  return new HttpError(500, 'server_misconfigured', 'Authentication is not configured.', {
    details: { reason: failure.code },
    cause: failure,
  });
}

/** The parts of a PostgREST error (supabase-js `PostgrestError`) the mapping reads. */
export interface DatabaseFailure {
  readonly code?: string | null;
  readonly message: string;
  readonly details?: string | null;
  readonly hint?: string | null;
}

/**
 * Maps a failed RPC or query to an HttpError.
 *
 * The database reports domain failures as SQLSTATE 22023 with a stable
 * message key (app.fail), authorisation failures as 42501, and rate limits as
 * HTTP 429 with code `rate_limited` (private.raise_rate_limited).
 */
export function fromDatabaseFailure(failure: DatabaseFailure, status?: number): HttpError {
  if (status === 429 || failure.code === 'rate_limited') {
    return new HttpError(429, 'rate_limited', 'Too many requests. Please wait a moment.', {
      headers: { 'retry-after': '60' },
    });
  }
  switch (failure.code) {
    case '42501':
      return new HttpError(403, 'forbidden', 'You do not have access to this.');
    case '22023':
      return new HttpError(422, 'validation_failed', 'The request was rejected.', {
        details: { reason: failure.message },
      });
    case '23505':
      return new HttpError(409, 'conflict', 'This already exists.');
    case '23503':
    case '23514':
    case '22P02':
      return new HttpError(422, 'validation_failed', 'The request was rejected.', {
        details: { reason: 'constraint_violation' },
      });
    case 'PGRST301':
    case 'PGRST302':
      return new HttpError(401, 'unauthorized', 'Sign in to continue.', {
        details: { reason: failure.code },
      });
    default:
      return new HttpError(502, 'upstream_error', 'The database could not complete the request.', {
        cause: failure,
      });
  }
}
