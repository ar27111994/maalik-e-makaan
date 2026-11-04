/**
 * The request pipeline every function runs through, in this order:
 *
 *   browser origin check → CORS preflight → method routing →
 *   authentication (`@supabase/server`) → route → response headers.
 *
 * Every response, success or error, carries the security headers, CORS
 * headers for allowed browser origins and an `x-request-id` that also appears
 * in the logs. A HEAD request is answered by the GET route without a body.
 */

import { type AuthConfig, createSupabaseContext, type SupabaseContext } from '@supabase/server';
import { ConfigError, type FunctionConfig, loadConfig } from './config.ts';
import { corsHeaders, isOriginAllowed } from './cors.ts';
import type { Database } from './database.types.ts';
import { type AuthFailure, fromAuthFailure, HttpError, unauthorized } from './errors.ts';
import { errorResponse, withHeaders } from './http.ts';
import { consoleSink, createLogger, type Logger, type LogSink } from './log.ts';

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

/** The clients and caller identity of a request, typed with the database schema. */
export type Context = SupabaseContext<Database>;

export interface RequestContext {
  readonly req: Request;
  readonly requestId: string;
  readonly config: FunctionConfig;
  /** Clients and caller identity from `@supabase/server`. */
  readonly supabase: Context;
  readonly log: Logger;
  readonly now: () => Date;
}

export type Route = (ctx: RequestContext) => Promise<Response>;

export interface FunctionSpec {
  /** Function name, used in logs. */
  readonly name: string;
  /** The route of each method served; OPTIONS (preflight) and HEAD (via GET) are implied. */
  readonly routes: Readonly<Partial<Record<HttpMethod, Route>>>;
  /** Who may call the function (`'user'`, `'secret'`, `'none'`, …). */
  readonly auth: AuthConfig;
}

export type ContextResult =
  | { readonly data: Context; readonly error: null }
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
  // Signed-in callers must hold a user access token (aud "authenticated"),
  // not some other token the project's keys happened to sign.
  createContext: (req, options) =>
    createSupabaseContext<Database>(req, { auth: options.auth, audience: 'authenticated' }),
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

/** The methods [spec] answers, as advertised in Allow and CORS headers. */
export function allowedMethods(spec: FunctionSpec): string[] {
  const methods: string[] = Object.keys(spec.routes);
  return methods.includes('GET') ? [...methods, 'HEAD'] : methods;
}

function routeFor(spec: FunctionSpec, method: string): Route | undefined {
  const name = method === 'HEAD' ? 'GET' : method;
  // Own keys only: a method token such as "constructor" must not reach the prototype.
  return Object.hasOwn(spec.routes, name) ? spec.routes[name as HttpMethod] : undefined;
}

/** Builds the fetch handler for [spec]. */
export function createHandler(
  spec: FunctionSpec,
  deps: PipelineDeps = defaultDeps,
): (req: Request) => Promise<Response> {
  const methods = allowedMethods(spec);
  return async (req) => {
    const started = performance.now();
    const requestId = deps.newRequestId();
    const log = createLogger({ fn: spec.name, request_id: requestId }, deps.logSink);
    const origin = req.headers.get('origin');
    const head = req.method === 'HEAD';
    let cors: Record<string, string> = { vary: 'Origin' };
    let status = 500;
    let userId: string | null = null;

    try {
      const config = deps.loadConfig();
      cors = corsHeaders(origin, config.allowedOrigins, methods);

      // Browsers always send Origin; reject unknown ones outright instead of
      // relying on the browser to discard the response.
      if (origin !== null && !isOriginAllowed(origin, config.allowedOrigins)) {
        throw new HttpError(403, 'origin_not_allowed', 'This origin may not call this function.');
      }
      if (req.method === 'OPTIONS') {
        status = 204;
        return withHeaders(new Response(null, { status }), { ...cors, 'x-request-id': requestId });
      }
      const route = routeFor(spec, req.method);
      if (route === undefined) {
        throw new HttpError(405, 'method_not_allowed', `Use ${methods.join(' or ')}.`, {
          headers: { allow: [...methods, 'OPTIONS'].join(', ') },
        });
      }

      const context = await deps.createContext(req, { auth: spec.auth });
      if (context.error !== null) throw fromAuthFailure(context.error);
      userId = context.data.userClaims?.id ?? null;

      const response = await route({
        req,
        requestId,
        config,
        supabase: context.data,
        log,
        now: deps.now,
      });
      status = response.status;
      return withHeaders(response, { ...cors, 'x-request-id': requestId }, head);
    } catch (caught) {
      const error = toHttpError(caught);
      status = error.status;
      if (error.status >= 500) {
        log.error('request_failed', { code: error.code, error: caught });
      } else {
        log.warn('request_rejected', { code: error.code, details: error.details });
      }
      return withHeaders(
        errorResponse(error, requestId),
        { ...cors, 'x-request-id': requestId },
        head,
      );
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

/**
 * The signed-in caller of a user-only function. Anonymous sign-ins and
 * tokens issued to third-party OAuth clients are refused: inviting people
 * and deleting an account are for the account holder, in this app.
 */
export function requireUser(ctx: RequestContext): { id: string; email: string | null } {
  const claims = ctx.supabase.userClaims;
  if (claims === null) throw unauthorized();
  const jwt = ctx.supabase.jwtClaims;
  if (jwt?.['is_anonymous'] === true) {
    throw new HttpError(403, 'forbidden', 'Create an account to do this.', {
      details: { reason: 'anonymous_user' },
    });
  }
  if (jwt !== null && jwt['client_id'] !== undefined) {
    throw new HttpError(403, 'forbidden', 'Connected apps cannot do this.', {
      details: { reason: 'oauth_client_token' },
    });
  }
  return { id: claims.id, email: claims.email ?? null };
}
