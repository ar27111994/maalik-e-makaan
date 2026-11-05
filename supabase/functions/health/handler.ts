/**
 * health: liveness for uptime monitors, plus an authenticated readiness check.
 *
 *   GET|HEAD /health     → 200 { status: "ok", … } (no dependencies touched)
 *   GET /health?deep=1   → checks the database, storage and auth services.
 *                          Requires `x-health-token: <HEALTH_CHECK_TOKEN>`
 *                          (compared in constant time); 200 when every check
 *                          passes, 503 otherwise.
 *
 * Deep checks are opt-in and token-protected so the public endpoint cannot be
 * used to put load on the database.
 */

import { resolveEnv } from '@supabase/server/core';
import { timingSafeEqual } from '../_shared/crypto.ts';
import { HttpError, unauthorized } from '../_shared/errors.ts';
import {
  createHandler,
  defaultDeps,
  type PipelineDeps,
  type RequestContext,
} from '../_shared/handler.ts';
import { json } from '../_shared/http.ts';
import { DOCUMENTS_BUCKET } from '../_shared/storage.ts';

export const SERVICE = 'maalik-e-makaan';
export const CHECK_TIMEOUT_MS = 3_000;

export interface AuthEndpoint {
  readonly url: string;
  readonly publishableKey: string;
}

export interface HealthDeps extends PipelineDeps {
  readonly fetch: typeof fetch;
  /** Where the auth service lives, or null when it cannot be resolved. */
  readonly authEndpoint: () => AuthEndpoint | null;
  readonly env: (name: string) => string | undefined;
}

export interface CheckResult {
  readonly ok: boolean;
  readonly latency_ms: number;
  readonly error?: string;
}

/** Runs [check] with a timeout, measuring its latency; never throws. */
export async function runCheck(
  check: (signal: AbortSignal) => Promise<void>,
  timeoutMs = CHECK_TIMEOUT_MS,
): Promise<CheckResult> {
  const started = performance.now();
  const signal = AbortSignal.timeout(timeoutMs);
  try {
    await Promise.race([
      check(signal),
      new Promise<never>((_, reject) => {
        signal.addEventListener('abort', () => reject(new Error('timeout')), { once: true });
      }),
    ]);
    return { ok: true, latency_ms: Math.round(performance.now() - started) };
  } catch (error) {
    return {
      ok: false,
      latency_ms: Math.round(performance.now() - started),
      error: error instanceof Error ? error.message : 'failed',
    };
  }
}

async function requireHealthToken(ctx: RequestContext): Promise<void> {
  const expected = ctx.config.healthCheckToken();
  if (expected === null) {
    throw new HttpError(403, 'deep_check_disabled', 'Deep health checks are not enabled.');
  }
  const presented = ctx.req.headers.get('x-health-token') ?? '';
  if (!await timingSafeEqual(presented, expected)) {
    throw unauthorized('A valid health check token is required.');
  }
}

async function deepChecks(
  ctx: RequestContext,
  deps: HealthDeps,
): Promise<Record<string, CheckResult>> {
  const admin = ctx.supabase.supabaseAdmin;
  const [database, storage, auth] = await Promise.all([
    runCheck(async (signal) => {
      // A real read (not HEAD): error bodies are parsed, and only 200/206
      // count, so a missing table or a misrouted request is not "healthy".
      const { error, status } = await admin
        .from('portfolios')
        .select('id')
        .limit(1)
        .abortSignal(signal);
      // supabase-js reports a failed fetch with an empty code.
      if (error !== null) throw new Error(`database: ${error.code || 'unreachable'}`);
      if (status !== 200 && status !== 206) throw new Error(`database: HTTP ${status}`);
    }),
    runCheck(async () => {
      const { error } = await admin.storage.getBucket(DOCUMENTS_BUCKET);
      if (error !== null) throw new Error('storage: bucket unavailable');
    }),
    runCheck(async (signal) => {
      const endpoint = deps.authEndpoint();
      if (endpoint === null) throw new Error('auth: endpoint not configured');
      const response = await deps.fetch(`${endpoint.url.replace(/\/+$/, '')}/auth/v1/health`, {
        headers: { apikey: endpoint.publishableKey },
        signal,
      });
      await response.body?.cancel();
      if (!response.ok) throw new Error(`auth: HTTP ${response.status}`);
    }),
  ]);
  return { database, storage, auth };
}

async function health(ctx: RequestContext, deps: HealthDeps): Promise<Response> {
  const url = new URL(ctx.req.url);
  const deep = ['1', 'true'].includes(url.searchParams.get('deep') ?? '');
  const base = {
    service: SERVICE,
    version: deps.env('DENO_DEPLOYMENT_ID') ?? 'local',
    region: deps.env('SB_REGION') ?? 'local',
    time: ctx.now().toISOString(),
  };
  if (!deep) return json({ status: 'ok', ...base });

  await requireHealthToken(ctx);
  const checks = await deepChecks(ctx, deps);
  const healthy = Object.values(checks).every((check) => check.ok);
  if (!healthy) ctx.log.warn('health_degraded', { checks });
  return json({ status: healthy ? 'ok' : 'degraded', ...base, checks }, healthy ? 200 : 503);
}

/** The auth endpoint from the platform environment (`@supabase/server` rules). */
export function authEndpointFromEnv(): AuthEndpoint | null {
  const { data } = resolveEnv();
  const publishableKey = data?.publishableKeys['default'];
  return data === null || publishableKey === undefined ? null : { url: data.url, publishableKey };
}

export const defaultHealthDeps: HealthDeps = {
  ...defaultDeps,
  fetch: (input, init) => fetch(input, init),
  authEndpoint: authEndpointFromEnv,
  env: (name) => Deno.env.get(name),
};

export function createHealthHandler(
  deps: HealthDeps = defaultHealthDeps,
): (req: Request) => Promise<Response> {
  return createHandler(
    { name: 'health', auth: 'none', routes: { GET: (ctx) => health(ctx, deps) } },
    deps,
  );
}
