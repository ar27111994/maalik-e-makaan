/**
 * Test doubles for the function pipeline: configuration, a recording fake of
 * the Supabase client surface the functions use, and pipeline dependencies
 * that capture log records.
 */

import type { JWTClaims, UserClaims } from '@supabase/server';
import { configFromValues, type FunctionConfig } from '../_shared/config.ts';
import type { Context, ContextResult, PipelineDeps } from '../_shared/handler.ts';
import type { LogRecord } from '../_shared/log.ts';

export const USER_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91';
export const PORTFOLIO_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a92';
export const OTHER_PORTFOLIO_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a93';
export const REQUEST_ID = '0192d0c4-0000-7000-8000-00000000beef';
export const APP_ORIGIN = 'https://app.example.com';
/** The caller's access token as the requests carry it. */
export const ACCESS_TOKEN = 'header.payload.signature';
/** 2026-11-03T12:00:00Z. */
export const NOW = new Date(Date.UTC(2026, 10, 3, 12, 0, 0));
export const NOW_SECONDS = Math.floor(NOW.getTime() / 1000);

export type ConfigValues = Parameters<typeof configFromValues>[0];

/** A configuration with test defaults; [overrides] may hold ConfigErrors to simulate bad secrets. */
export function testConfig(overrides: ConfigValues = {}): FunctionConfig {
  return configFromValues({
    allowedOrigins: [APP_ORIGIN],
    appUrl: APP_ORIGIN,
    email: null,
    healthCheckToken: null,
    reauthMaxAgeSeconds: 600,
    storageCleanupToken: null,
    ...overrides,
  });
}

/** A result in the shape supabase-js returns. */
export interface Result {
  readonly data?: unknown;
  readonly error?: unknown;
  readonly status?: number;
}

export interface Call {
  readonly kind: string;
  readonly args: readonly unknown[];
}

export interface FakeClientOptions {
  readonly rpc?: (fn: string, args: Record<string, unknown>) => Result | Promise<Result>;
  /** Answers `from(table).select(...)` chains; [query] holds `.eq()` filters and `.limit()`. */
  readonly select?: (
    table: string,
    query: { filters: Record<string, unknown>; limit: number | null; columns: string },
    options: unknown,
  ) => Result | Promise<Result>;
  readonly remove?: (bucket: string, paths: string[]) => Result | Promise<Result>;
  readonly getBucket?: (id: string) => Result | Promise<Result>;
  readonly getUser?: (jwt: string | undefined) => Result | Promise<Result>;
  readonly getUserById?: (id: string) => Result | Promise<Result>;
  readonly deleteUser?: (id: string) => Result | Promise<Result>;
}

export interface FakeClient {
  readonly client: Context['supabase'];
  readonly calls: Call[];
}

function normalise(result: Result): { data: unknown; error: unknown; status: number } {
  return {
    data: result.data ?? null,
    error: result.error ?? null,
    status: result.status ?? (result.error ? 400 : 200),
  };
}

function unexpected(kind: string): never {
  throw new Error(`unexpected call: ${kind}`);
}

/** A recording fake of the supabase-js client surface used by the functions. */
export function fakeClient(options: FakeClientOptions = {}): FakeClient {
  const calls: Call[] = [];
  const record = async (kind: string, args: unknown[], answer: () => Result | Promise<Result>) => {
    calls.push({ kind, args });
    return normalise(await answer());
  };

  const client = {
    rpc: (fn: string, args: Record<string, unknown>) =>
      record('rpc', [fn, args], () => (options.rpc ?? (() => unexpected(`rpc ${fn}`)))(fn, args)),
    from: (table: string) => ({
      select: (columns: string, selectOptions?: unknown) => {
        const query = {
          filters: {} as Record<string, unknown>,
          limit: null as number | null,
          columns,
        };
        const run = () =>
          record(
            'select',
            [table, columns, query, selectOptions],
            () =>
              (options.select ?? (() => unexpected(`select ${table}`)))(
                table,
                query,
                selectOptions,
              ),
          );
        const chain = {
          eq: (column: string, value: unknown) => {
            query.filters[column] = value;
            return chain;
          },
          limit: (count: number) => {
            query.limit = count;
            return chain;
          },
          maybeSingle: () => run(),
          abortSignal: (_signal: AbortSignal) => run(),
        };
        return chain;
      },
    }),
    storage: {
      from: (bucket: string) => ({
        remove: (paths: string[]) =>
          record(
            'remove',
            [bucket, paths],
            () => (options.remove ?? (() => unexpected('remove')))(bucket, paths),
          ),
      }),
      getBucket: (id: string) =>
        record('getBucket', [id], () => (options.getBucket ?? (() => unexpected('getBucket')))(id)),
    },
    auth: {
      getUser: (jwt?: string) =>
        record('getUser', [jwt], () => (options.getUser ?? (() => unexpected('getUser')))(jwt)),
      admin: {
        getUserById: (id: string) =>
          record(
            'getUserById',
            [id],
            () => (options.getUserById ?? (() => unexpected('getUserById')))(id),
          ),
        deleteUser: (id: string) =>
          record(
            'deleteUser',
            [id],
            () => (options.deleteUser ?? (() => unexpected('deleteUser')))(id),
          ),
      },
    },
  };
  return { client: client as unknown as Context['supabase'], calls };
}

export interface ContextOptions {
  readonly user?: Partial<UserClaims> | null;
  readonly jwtClaims?: Partial<JWTClaims> | null;
  readonly supabase?: FakeClient;
  readonly supabaseAdmin?: FakeClient;
  readonly authMode?: Context['authMode'];
}

/** A Context for an authenticated caller unless `user: null`. */
export function fakeContext(options: ContextOptions = {}): Context {
  const user = options.user === null
    ? null
    : { id: USER_ID, email: 'owner@example.com', role: 'authenticated', ...options.user };
  return {
    supabase: (options.supabase ?? fakeClient()).client,
    supabaseAdmin: (options.supabaseAdmin ?? fakeClient()).client,
    userClaims: user as UserClaims | null,
    jwtClaims: options.jwtClaims === null
      ? null
      : ({ sub: USER_ID, role: 'authenticated', ...options.jwtClaims } as JWTClaims),
    authMode: options.authMode ?? (user === null ? 'none' : 'user'),
  };
}

export interface Harness<D extends PipelineDeps = PipelineDeps> {
  readonly deps: D;
  readonly logs: LogRecord[];
  readonly contextRequests: Array<{ req: Request; auth: unknown }>;
}

export interface HarnessOptions {
  readonly config?: FunctionConfig | (() => FunctionConfig);
  readonly context?: ContextResult | Context;
  readonly now?: Date;
}

/** Pipeline dependencies with fixed time, request id and configuration. */
export function harness(options: HarnessOptions = {}): Harness {
  const logs: LogRecord[] = [];
  const contextRequests: Array<{ req: Request; auth: unknown }> = [];
  const config = options.config ?? testConfig();
  const context = options.context ?? fakeContext();
  const result: ContextResult = 'error' in context && 'data' in context
    ? context as ContextResult
    : { data: context as Context, error: null };
  return {
    logs,
    contextRequests,
    deps: {
      loadConfig: typeof config === 'function' ? config : () => config,
      createContext: (req, { auth }) => {
        contextRequests.push({ req, auth });
        return Promise.resolve(result);
      },
      now: () => options.now ?? NOW,
      newRequestId: () => REQUEST_ID,
      logSink: (record) => logs.push(record),
    },
  };
}

/**
 * A monotonic clock for time budgets: starts at 0 and advances by [step]
 * milliseconds on every reading (0 keeps it still).
 */
export function steppingClock(
  step = 0,
): { readonly clock: () => number; advance(ms: number): void } {
  let now = 0;
  return {
    clock: () => {
      const value = now;
      now += step;
      return value;
    },
    advance: (ms) => {
      now += ms;
    },
  };
}

export interface RequestOptions {
  readonly method?: string;
  readonly body?: unknown;
  readonly headers?: Record<string, string>;
  readonly origin?: string | null;
  readonly path?: string;
  /** Bearer token for the Authorization header; null sends none (default ACCESS_TOKEN). */
  readonly token?: string | null;
}

/** A request to a function, JSON-encoding [body] unless it is already a string. */
export function request(options: RequestOptions = {}): Request {
  const headers: Record<string, string> = { ...options.headers };
  if (options.origin !== undefined && options.origin !== null) headers['origin'] = options.origin;
  const token = options.token === undefined ? ACCESS_TOKEN : options.token;
  if (token !== null) headers['authorization'] ??= `Bearer ${token}`;
  let body: string | undefined;
  if (options.body !== undefined) {
    body = typeof options.body === 'string' ? options.body : JSON.stringify(options.body);
    headers['content-type'] ??= 'application/json';
  }
  return new Request(`https://project.supabase.co/functions/v1${options.path ?? '/fn'}`, {
    method: options.method ?? (body === undefined ? 'GET' : 'POST'),
    headers,
    body,
  });
}

/** Reads the error envelope of a failed response. */
export async function errorOf(response: Response): Promise<{
  code: string;
  message: string;
  details?: Record<string, unknown>;
  request_id: string;
}> {
  const body = await response.json();
  return body.error;
}

/** The serialised logs, for asserting that nothing secret or personal leaked. */
export function logText(logs: readonly LogRecord[]): string {
  return JSON.stringify(logs);
}
