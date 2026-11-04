/**
 * Rate limits shared by every isolate and region, backed by the database's
 * fixed-window limiter (public.admin_hit_rate_limit, secret key only).
 */

import { HttpError } from './errors.ts';

/** The slice of a Supabase client this module needs (the admin client). */
export interface RpcClient {
  rpc(
    fn: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string } | null }>;
}

export interface RateLimit {
  /** Namespaced key, e.g. `invite_email:user:<uuid>`. Never raw personal data. */
  readonly key: string;
  /** Allowed hits per window. */
  readonly limit: number;
  /** Window length in seconds (at most 3600). */
  readonly windowSeconds: number;
}

/**
 * Counts one hit against [rule] and reports whether it is within the limit.
 * Throws an `upstream_error` HttpError when the limiter itself fails, so
 * callers decide whether to fail open or closed.
 */
export async function hitRateLimit(admin: RpcClient, rule: RateLimit): Promise<boolean> {
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
