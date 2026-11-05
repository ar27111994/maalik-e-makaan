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
  | 'temporarily_unavailable'
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

/** 401 with the `WWW-Authenticate: Bearer` challenge RFC 6750 asks for. */
export function unauthorized(
  message = 'Sign in to continue.',
  details?: Record<string, unknown>,
): HttpError {
  return new HttpError(401, 'unauthorized', message, {
    details,
    headers: { 'www-authenticate': 'Bearer' },
  });
}

/**
 * 401 asking for a fresh sign-in (RFC 9470 step-up authentication): the
 * challenge names the maximum sign-in age the operation accepts.
 */
export function reauthenticationRequired(maxAgeSeconds: number, message: string): HttpError {
  return new HttpError(401, 'reauthentication_required', message, {
    details: { reauth_max_age_seconds: maxAgeSeconds },
    headers: {
      'www-authenticate':
        `Bearer error="insufficient_user_authentication", max_age=${maxAgeSeconds}`,
    },
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
    return unauthorized('Sign in to continue.', { reason: failure.code });
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

/** The longest wait a database 429 may announce (one day). */
const MAX_RETRY_AFTER_SECONDS = 86_400;

/**
 * Retry-After for a database 429: the database puts the exact wait in the
 * error hint (private.raise_rate_limited). Anything else is ignored, and the
 * header is then omitted rather than guessed.
 */
export function retryAfterFromHint(hint: string | null | undefined): Record<string, string> {
  if (typeof hint !== 'string' || !/^[1-9][0-9]{0,5}$/.test(hint)) return {};
  return Number(hint) <= MAX_RETRY_AFTER_SECONDS ? { 'retry-after': hint } : {};
}

function rateLimited(failure: DatabaseFailure): HttpError {
  return new HttpError(429, 'rate_limited', 'Too many requests. Please wait a moment.', {
    headers: retryAfterFromHint(failure.hint),
  });
}

/**
 * Transient database conditions worth retrying: deadlock (40P01),
 * serialisation failure (40001), lock not available (55P03) and statement
 * timeout (57014).
 */
const TRANSIENT_CODES = new Set(['40P01', '40001', '55P03', '57014']);

function temporarilyUnavailable(failure: DatabaseFailure): HttpError {
  return new HttpError(503, 'temporarily_unavailable', 'The service is busy. Please try again.', {
    headers: { 'retry-after': '1' },
    cause: failure,
  });
}

/**
 * Maps a failed RPC or query made **as the caller** (the context client).
 *
 * The database reports domain failures as SQLSTATE 22023 with a stable
 * message key (app.fail), authorisation failures as 42501, and rate limits as
 * HTTP 429 with code `rate_limited`. PostgREST reports JWT problems as 401
 * with PGRST301-PGRST303 (PGRST300, a server without a JWT secret, is a
 * misconfiguration and must not send the user back to sign in).
 */
const JWT_FAILURE_CODES = /^PGRST30[1-3]$/;

export function fromDatabaseFailure(failure: DatabaseFailure, status?: number): HttpError {
  if (status === 429 || failure.code === 'rate_limited') return rateLimited(failure);
  if (status === 401 || JWT_FAILURE_CODES.test(failure.code ?? '')) {
    return unauthorized('Sign in to continue.', { reason: failure.code ?? 'unauthorized' });
  }
  if (TRANSIENT_CODES.has(failure.code ?? '')) return temporarilyUnavailable(failure);
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
    default:
      return new HttpError(502, 'upstream_error', 'The database could not complete the request.', {
        cause: failure,
      });
  }
}

/**
 * Maps a failed RPC or query made **by the function itself** with the secret
 * key. Such a call never fails because of the caller's input or rights (the
 * function validated both), so nothing here is reported as the caller's
 * fault: transient conditions are 503, everything else is 502.
 */
export function fromServiceFailure(failure: DatabaseFailure): HttpError {
  if (TRANSIENT_CODES.has(failure.code ?? '')) return temporarilyUnavailable(failure);
  return new HttpError(502, 'upstream_error', 'The database could not complete the request.', {
    cause: failure,
  });
}
