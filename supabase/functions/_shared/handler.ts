/**
 * The request pipeline every function runs through:
 *
 *   configuration → origin and method checks → CORS preflight →
 *   authentication (`@supabase/server`) → handler → error envelope.
 *
 * Every response carries the security headers, CORS headers for allowed
 * browser origins and an `x-request-id` that also appears in the logs.
 */

import { type AuthConfig, createSupabaseContext, type SupabaseContext } from '@supabase/server';
import { ConfigError, type FunctionConfig, loadConfig } from './config.ts';
import { corsHeaders, isOriginAllowed } from './cors.ts';
import { type AuthFailure, fromAuthFailure, HttpError } from './errors.ts';
import { errorResponse, SECURITY_HEADERS, withHeaders } from './http.ts';
import { consoleSink, createLogger, type Logger, type LogSink } from './log.ts';

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

export interface RequestContext {
  readonly req: Request;
  readonly requestId: string;
  readonly config: FunctionConfig;
  /** Clients and caller identity from `@supabase/server`. */
  readonly supabase: SupabaseContext;
  readonly log: Logger;
  readonly now: () => Date;
}

export interface FunctionSpec {
  /** Function name, used in logs. */
  readonly name: string;
  /** Methods the handler serves (OPTIONS preflight is always handled). */
  readonly methods: readonly HttpMethod[];
  /** Who may call the function (`'user'`, `'secret'`, `'none'`, …). */
  readonly auth: AuthConfig;
  readonly handle: (ctx: RequestContext) => Promise<Response>;
}

export type ContextResult =
  | { readonly data: SupabaseContext; readonly error: null }
  | { readonly data: null; readonly error: AuthFailure };

export type ContextFactory = (
  req: Request,
  options: { readonly auth: AuthConfig },
) => Promise<ContextResult>;

/** Everything the pipeline touches outside the request, injectable for tests. */
export interface PipelineDeps {
  readonly loadConfig: () => FunctionConfig;
  readonly createContext: ContextFactory;
  readonly now: () => Date;
  readonly newRequestId: () => string;
  readonly logSink: LogSink;
}

export const defaultDeps: PipelineDeps = {
  loadConfig: () => loadConfig(),
  createContext: (req, options) => createSupabaseContext(req, { auth: options.auth }),
  now: () => new Date(),
  newRequestId: () => crypto.randomUUID(),
  logSink: consoleSink,
};

function toHttpError(caught: unknown): HttpError {
  if (caught instanceof HttpError) return caught;
  if (caught instanceof ConfigError) {
    return new HttpError(500, 'server_misconfigured', 'The service is not configured correctly.', {
      details: { variable: caught.variable },
      cause: caught,
    });
  }
  return new HttpError(500, 'internal_error', 'Something went wrong. Please try again.', {
    cause: caught,
  });
}

/** Builds the fetch handler for [spec]. */
export function createHandler(
  spec: FunctionSpec,
  deps: PipelineDeps = defaultDeps,
): (req: Request) => Promise<Response> {
  return async (req) => {
    const started = performance.now();
    const requestId = deps.newRequestId();
    const log = createLogger({ fn: spec.name, request_id: requestId }, deps.logSink);
    const origin = req.headers.get('origin');
    let cors: Record<string, string> = { vary: 'Origin' };
    let status = 500;
    let userId: string | null = null;

    try {
      const config = deps.loadConfig();
      cors = corsHeaders(origin, config.allowedOrigins, spec.methods);

      // Browsers always send Origin; reject unknown ones outright instead of
      // relying on the browser to discard the response.
      if (origin !== null && !isOriginAllowed(origin, config.allowedOrigins)) {
        throw new HttpError(403, 'origin_not_allowed', 'This origin may not call this function.');
      }
      if (req.method === 'OPTIONS') {
        status = 204;
        return new Response(null, {
          status,
          headers: { ...SECURITY_HEADERS, ...cors, 'x-request-id': requestId },
        });
      }
      if (!(spec.methods as readonly string[]).includes(req.method)) {
        throw new HttpError(405, 'method_not_allowed', `Use ${spec.methods.join(' or ')}.`, {
          headers: { allow: [...spec.methods, 'OPTIONS'].join(', ') },
        });
      }

      const context = await deps.createContext(req, { auth: spec.auth });
      if (context.error !== null) throw fromAuthFailure(context.error);
      userId = context.data.userClaims?.id ?? null;

      const response = await spec.handle({
        req,
        requestId,
        config,
        supabase: context.data,
        log,
        now: deps.now,
      });
      status = response.status;
      return withHeaders(response, { ...cors, 'x-request-id': requestId });
    } catch (caught) {
      const error = toHttpError(caught);
      status = error.status;
      if (error.status >= 500) {
        log.error('request_failed', { code: error.code, error: caught });
      } else {
        log.warn('request_rejected', { code: error.code, details: error.details });
      }
      return withHeaders(errorResponse(error, requestId), { ...cors, 'x-request-id': requestId });
    } finally {
      log.info('request', {
        method: req.method,
        status,
        duration_ms: Math.round(performance.now() - started),
        user_id: userId,
      });
    }
  };
}

/** The signed-in caller; the pipeline guarantees one for `auth: 'user'`. */
export function requireUser(ctx: RequestContext): { id: string; email: string | null } {
  const claims = ctx.supabase.userClaims;
  if (claims === null) {
    throw new HttpError(401, 'unauthorized', 'Sign in to continue.');
  }
  return { id: claims.id, email: claims.email ?? null };
}
