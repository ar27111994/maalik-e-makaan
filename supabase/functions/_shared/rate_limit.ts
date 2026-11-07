/**
 * Rate limits shared by every isolate and region, backed by the database's
 * fixed-window limiter (public.admin_rate_limit_hit, secret key only).
 */

import { HttpError } from './errors.ts';
import type { Context } from './handler.ts';

type Admin = Context['supabaseAdmin'];

export interface RateLimit {
  /** Namespaced key, e.g. `invite_email:user:<uuid>`. Never raw personal data. */
  readonly key: string;
  /** Allowed hits per window. */
  readonly limit: number;
  /** Window length in seconds (at most 3600). */
  readonly windowSeconds: number;
}

/** The database's verdict on one hit (public.admin_rate_limit_hit). */
export interface RateLimitVerdict {
  /** Whether the hit is within the limit. */
  readonly allowed: boolean;
  /**
   * Seconds until the window the hit was counted in ends (1 to 3600), from
   * the database's clock at the hit. The honest Retry-After for a refusal:
   * the Edge Function's own clock, read later, can be in another window.
   */
  readonly retryAfterSeconds: number;
}

/** A 429 that asks the client to wait [retryAfterSeconds] (the database's wait). */
export function rateLimitedError(retryAfterSeconds: number): HttpError {
  return new HttpError(429, 'rate_limited', 'Too many requests. Please wait a moment.', {
    headers: { 'retry-after': String(retryAfterSeconds) },
  });
}

function isVerdict(data: unknown): data is { allowed: boolean; retry_after_seconds: number } {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return false;
  const { allowed, retry_after_seconds: wait } = data as Record<string, unknown>;
  return typeof allowed === 'boolean' && Number.isInteger(wait) && (wait as number) >= 1 &&
    (wait as number) <= 3600;
}

/**
 * Counts one hit against [rule] and returns the database's verdict with its
 * Retry-After. Throws an `upstream_error` HttpError when the limiter itself
 * fails or answers something else, so callers decide whether to fail open or
 * closed.
 */
export async function hitRateLimit(admin: Admin, rule: RateLimit): Promise<RateLimitVerdict> {
  const { data, error } = await admin.rpc('admin_rate_limit_hit', {
    p_key: rule.key,
    p_limit: rule.limit,
    p_window_seconds: rule.windowSeconds,
  });
  if (error !== null || !isVerdict(data)) {
    throw new HttpError(502, 'upstream_error', 'The rate limiter is unavailable.', {
      cause: error ?? new Error(`unexpected limiter response: ${JSON.stringify(data)}`),
    });
  }
  return { allowed: data.allowed, retryAfterSeconds: data.retry_after_seconds };
}
