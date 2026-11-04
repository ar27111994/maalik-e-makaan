/**
 * Rate limits shared by every isolate and region, backed by the database's
 * fixed-window limiter (public.admin_hit_rate_limit, secret key only).
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

/** The origin of the database's fixed windows (`date_bin(..., '2000-01-01')`). */
const WINDOW_ORIGIN_SECONDS = Date.UTC(2000, 0, 1) / 1000;

/**
 * Seconds until the fixed window of [windowSeconds] that contains [now]
 * ends: the honest Retry-After for a request refused in it (at least 1).
 */
export function retryAfterSeconds(now: Date, windowSeconds: number): number {
  const elapsed = Math.floor(now.getTime() / 1000) - WINDOW_ORIGIN_SECONDS;
  const remaining = windowSeconds - (((elapsed % windowSeconds) + windowSeconds) % windowSeconds);
  return Math.max(1, remaining);
}

/** A 429 for [rule], with the wait until its window ends. */
export function rateLimitedError(now: Date, rule: RateLimit): HttpError {
  return new HttpError(429, 'rate_limited', 'Too many requests. Please wait a moment.', {
    headers: { 'retry-after': String(retryAfterSeconds(now, rule.windowSeconds)) },
  });
}

/**
 * Counts one hit against [rule] and reports whether it is within the limit.
 * Throws an `upstream_error` HttpError when the limiter itself fails, so
 * callers decide whether to fail open or closed.
 */
export async function hitRateLimit(admin: Admin, rule: RateLimit): Promise<boolean> {
  const { data, error } = await admin.rpc('admin_hit_rate_limit', {
    p_key: rule.key,
    p_limit: rule.limit,
    p_window_seconds: rule.windowSeconds,
  });
  if (error !== null || typeof data !== 'boolean') {
    throw new HttpError(502, 'upstream_error', 'The rate limiter is unavailable.', {
      cause: error ?? new Error(`unexpected limiter response: ${JSON.stringify(data)}`),
    });
  }
  return data;
}
