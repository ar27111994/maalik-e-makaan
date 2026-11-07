/**
 * delete-account through the real request pipeline: the preview (GET), the
 * deletion (POST) and every check in front of it, against a recording fake of
 * the admin client. Time is fixed at NOW and the inline cleanup runs on a
 * stepping clock, so nothing depends on the wall clock or the environment.
 */

import { assert, assertEquals, assertFalse, assertMatch, assertStrictEquals } from '@std/assert';
import { returnsNext, stub } from '@std/testing/mock';
import { ConfigError, type FunctionConfig } from '../_shared/config.ts';
import { defaultDeps } from '../_shared/handler.ts';
import type { LogRecord } from '../_shared/log.ts';
import {
  CLEANUP_BUDGET_MS,
  createDeleteAccountHandler,
  defaultDeleteAccountDeps,
  DELETE_ACCOUNT_LIMIT,
  FIRST_FACTOR_METHODS,
  lastSignInAt,
  MAX_CLOCK_SKEW_SECONDS,
  MAX_CONFIRMATION_LENGTH,
} from '../delete-account/handler.ts';
import deleteAccountFunction from '../delete-account/index.ts';
import {
  ACCESS_TOKEN,
  APP_ORIGIN,
  type Call,
  type ContextOptions,
  type FakeClient,
  fakeClient,
  type FakeClientOptions,
  fakeContext,
  harness,
  logText,
  NOW,
  NOW_SECONDS,
  OTHER_PORTFOLIO_ID,
  PORTFOLIO_ID,
  request,
  REQUEST_ID,
  type Result,
  steppingClock,
  testConfig,
  USER_ID,
} from './_helpers.ts';

// --- fixtures --------------------------------------------------------------------

const FN = 'delete-account';
const EMAIL = 'owner@example.com';
const OTHER_USER_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a99';
const SESSION_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a98';
/**
 * Characters every input refuses, built from code points so that this source never contains
 * them: U+202E RIGHT-TO-LEFT OVERRIDE, U+200B ZERO WIDTH SPACE and U+0000.
 */
const RLO = String.fromCodePoint(0x202e);
const ZWSP = String.fromCodePoint(0x200b);
const NUL = String.fromCodePoint(0x0000);
/** A character outside the BMP: one code point, two UTF-16 code units. */
const HOUSE = '\u{1F3E0}';
/** The longest e-mail address there is (64 + 1 + 255 characters), and one character more. */
const EMAIL_320 = `${'a'.repeat(64)}@${'b'.repeat(251)}.com`;
const EMAIL_321 = `${'a'.repeat(64)}@${'b'.repeat(252)}.com`;

type Claims = NonNullable<ContextOptions['jwtClaims']>;

/** One entry of the `amr` claim. */
function signIn(method: unknown, timestamp: unknown): Record<string, unknown> {
  return { method, timestamp };
}

/** A password sign-in a minute ago, at aal1. */
const FRESH: Claims = {
  aal: 'aal1',
  amr: [signIn('password', NOW_SECONDS - 60)],
  session_id: SESSION_ID,
};
/** The same session an hour after its sign-in. */
const STALE: Claims = { ...FRESH, amr: [signIn('password', NOW_SECONDS - 3_600)] };

const VERIFIED_TOTP = { id: 'factor-1', factor_type: 'totp', status: 'verified' };
const UNVERIFIED_TOTP = { id: 'factor-2', factor_type: 'totp', status: 'unverified' };

/** The caller's account as Auth stores it now: no second factor, so no `factors`. */
function account(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: USER_ID,
    aud: 'authenticated',
    role: 'authenticated',
    email: EMAIL,
    app_metadata: { provider: 'email', providers: ['email'] },
    user_metadata: {},
    created_at: '2026-01-05T09:30:00Z',
    ...overrides,
  };
}

/** What admin_account_deletion_scope returns: the portfolios the caller owns alone. */
const SCOPE_ROWS = [
  { portfolio_id: PORTFOLIO_ID, portfolio_name: 'Raza Family Properties', other_members: 2 },
  { portfolio_id: OTHER_PORTFOLIO_ID, portfolio_name: 'Gulberg Shops', other_members: 0 },
];

/** Queue items of the two deleted portfolios' folders, and the files under them. */
const ITEM_1 = {
  id: 41,
  bucket_id: 'documents',
  path: `${PORTFOLIO_ID}/`,
  is_prefix: true,
  attempts: 0,
};
const ITEM_2 = { ...ITEM_1, id: 42, path: `${OTHER_PORTFOLIO_ID}/` };
const FILES_1 = [
  `${PORTFOLIO_ID}/tenants/t-1/cnic-front.jpg`,
  `${PORTFOLIO_ID}/leases/l-1/agreement.pdf`,
];
const FILES_2 = [`${OTHER_PORTFOLIO_ID}/receipts/2026-10.pdf`];

// --- the admin client ----------------------------------------------------------

type RpcAnswer = Result | ((args: Record<string, unknown>) => Result);
type RpcAnswers = Readonly<Record<string, RpcAnswer>>;

/** A live account that owns nothing alone: every check passes and nothing needs cleaning. */
const DEFAULT_RPC: RpcAnswers = {
  admin_rate_limit_hit: { data: { allowed: true, retry_after_seconds: 600 } },
  admin_account_deletion_scope: { data: SCOPE_ROWS },
  admin_delete_account_data: { data: { deleted_portfolio_ids: [] } },
};

/** Answers one call each, in order; a call beyond the last fails the request. */
function inOrder(...answers: Result[]): RpcAnswer {
  const queue = [...answers];
  return () => {
    const next = queue.shift();
    if (next === undefined) throw new Error('called once too often');
    return next;
  };
}

/** admin_delete_account_data reporting [ids] as deleted. */
function deleted(...ids: string[]): RpcAnswers {
  return { admin_delete_account_data: { data: { deleted_portfolio_ids: ids } } };
}

/** The cleanup queue: one claim of [items], then none; each item lists its [pages], then none. */
function cleanupQueue(
  items: readonly Record<string, unknown>[],
  pages: Readonly<Record<number, string[][]>>,
): RpcAnswers {
  const remaining = new Map(Object.entries(pages).map(([id, list]) => [Number(id), [...list]]));
  return {
    admin_claim_storage_cleanup: inOrder({ data: items }, { data: [] }),
    admin_storage_cleanup_objects: (args) => ({
      data: (remaining.get(Number(args['p_item_id']))?.shift() ?? []).map((name) => ({ name })),
    }),
    admin_complete_storage_cleanup: (args) => ({
      data: args['p_finished'] === true ? 'done' : 'rescheduled',
    }),
  };
}

interface AdminOptions {
  /** RPC answers by name, over DEFAULT_RPC. */
  readonly rpc?: RpcAnswers;
  /** Overrides on the account Auth returns for the caller's token. */
  readonly user?: Record<string, unknown>;
  readonly getUser?: FakeClientOptions['getUser'];
  readonly getUserById?: FakeClientOptions['getUserById'];
  readonly deleteUser?: FakeClientOptions['deleteUser'];
  readonly remove?: FakeClientOptions['remove'];
}

/** The admin client; a call it has no answer for fails the request. */
function adminClient(options: AdminOptions = {}): FakeClient {
  const answers: RpcAnswers = { ...DEFAULT_RPC, ...options.rpc };
  return fakeClient({
    rpc: (fn, args) => {
      const answer = answers[fn];
      if (answer === undefined) throw new Error(`unexpected rpc ${fn}`);
      return typeof answer === 'function' ? answer(args) : answer;
    },
    getUser: options.getUser ?? (() => ({ data: { user: account(options.user) } })),
    getUserById: options.getUserById,
    deleteUser: options.deleteUser ?? (() => ({ data: { user: account() } })),
    remove: options.remove,
  });
}

// --- sending requests ------------------------------------------------------------

interface SendOptions {
  readonly method?: string;
  readonly body?: unknown;
  readonly headers?: Record<string, string>;
  readonly origin?: string;
  /** Bearer token of the Authorization header (default ACCESS_TOKEN); null sends none. */
  readonly token?: string | null;
  /** JWT claims over sub and role (default FRESH); null when there are none. */
  readonly claims?: Claims | null;
  /** The caller's user claims over USER_ID and EMAIL; null when nobody is signed in. */
  readonly user?: ContextOptions['user'];
  readonly admin?: FakeClient;
  readonly config?: FunctionConfig;
  readonly now?: Date;
  /** The monotonic clock of the cleanup budget (default: one that stands still at 0). */
  readonly clock?: () => number;
}

interface Sent {
  readonly req: Request;
  readonly response: Response;
  /** Calls on the admin client, in order. */
  readonly calls: readonly Call[];
  /** Calls on the caller's own client. */
  readonly userCalls: readonly Call[];
  readonly logs: readonly LogRecord[];
  /** The auth mode the function asked the pipeline for, per authenticated request. */
  readonly authModes: readonly unknown[];
}

async function send(options: SendOptions = {}): Promise<Sent> {
  const admin = options.admin ?? adminClient();
  const caller = fakeClient();
  const h = harness({
    config: options.config,
    now: options.now,
    context: fakeContext({
      user: options.user,
      jwtClaims: options.claims === undefined ? FRESH : options.claims,
      supabase: caller,
      supabaseAdmin: admin,
    }),
  });
  const handler = createDeleteAccountHandler({
    ...h.deps,
    clock: options.clock ?? steppingClock().clock,
  });
  const req = request({
    method: options.method,
    body: options.body,
    headers: options.headers,
    origin: options.origin,
    token: options.token,
  });
  // The pipeline times requests with performance.now: a still clock logs duration_ms 0.
  const timer = stub(performance, 'now', () => 0);
  try {
    const response = await handler(req);
    return {
      req,
      response,
      calls: admin.calls,
      userCalls: caller.calls,
      logs: h.logs,
      authModes: h.contextRequests.map((sent) => sent.auth),
    };
  } finally {
    timer.restore();
  }
}

/** A POST confirming EMAIL, the account's own address. */
function confirm(options: SendOptions = {}): Promise<Sent> {
  return send({ method: 'POST', body: { confirm_email: EMAIL }, ...options });
}

/** A request of [method] that passes the body checks. */
function forMethod(method: string): SendOptions {
  return method === 'POST' ? { method, body: { confirm_email: EMAIL } } : { method };
}

const METHODS = ['GET', 'POST'] as const;

// --- expected calls ------------------------------------------------------------

const LIMIT = 'rpc:admin_rate_limit_hit';
const GET_USER = 'getUser';
const LOOKUP = 'getUserById';
const DELETE_DATA = 'rpc:admin_delete_account_data';
const DELETE_USER = 'deleteUser';
const CLAIM = 'rpc:admin_claim_storage_cleanup';
const LIST = 'rpc:admin_storage_cleanup_objects';
const REMOVE = 'remove';
const COMPLETE = 'rpc:admin_complete_storage_cleanup';

/** The calls as `rpc:<function>` or the client method's name. */
function trail(calls: readonly Call[]): string[] {
  return calls.map((call) => (call.kind === 'rpc' ? `rpc:${String(call.args[0])}` : call.kind));
}

const LIMIT_CALL: Call = {
  kind: 'rpc',
  args: [
    'admin_rate_limit_hit',
    { p_key: `delete_account:user:${USER_ID}`, p_limit: 10, p_window_seconds: 600 },
  ],
};
const GET_USER_CALL: Call = { kind: 'getUser', args: [ACCESS_TOKEN] };
const LOOKUP_CALL: Call = { kind: 'getUserById', args: [USER_ID] };
const SCOPE_CALL: Call = {
  kind: 'rpc',
  args: ['admin_account_deletion_scope', { p_user_id: USER_ID }],
};
const DELETE_DATA_CALL: Call = {
  kind: 'rpc',
  args: ['admin_delete_account_data', { p_user_id: USER_ID }],
};
const DELETE_USER_CALL: Call = { kind: 'deleteUser', args: [USER_ID] };

function claimCall(paths: string[]): Call {
  return {
    kind: 'rpc',
    args: ['admin_claim_storage_cleanup', { p_limit: 20, p_lease_seconds: 120, p_paths: paths }],
  };
}

function listCall(itemId: number): Call {
  return {
    kind: 'rpc',
    args: ['admin_storage_cleanup_objects', { p_item_id: itemId, p_limit: 1000 }],
  };
}

function removeCall(paths: string[]): Call {
  return { kind: 'remove', args: ['documents', paths] };
}

function completeCall(itemId: number, finished: boolean): Call {
  return {
    kind: 'rpc',
    args: ['admin_complete_storage_cleanup', { p_item_id: itemId, p_finished: finished }],
  };
}

// --- expected responses and logs -------------------------------------------------

interface ExpectedError {
  readonly status: number;
  readonly code: string;
  readonly message: string;
  readonly details?: Record<string, unknown>;
  readonly headers?: Record<string, string>;
}

/** Asserts the status, the whole error envelope and [expected.headers] of [response]. */
async function assertError(
  response: Response,
  expected: ExpectedError,
  label?: string,
): Promise<void> {
  const { status, headers = {}, ...error } = expected;
  assertEquals(
    { status: response.status, body: await response.json() },
    { status, body: { error: { ...error, request_id: REQUEST_ID } } },
    label,
  );
  for (const [name, value] of Object.entries({ ...headers, 'x-request-id': REQUEST_ID })) {
    assertEquals(response.headers.get(name), value, `${label ?? ''} ${name}`);
  }
}

const BEARER = { 'www-authenticate': 'Bearer' };
const SIGN_IN: ExpectedError = {
  status: 401,
  code: 'unauthorized',
  message: 'Sign in to continue.',
  headers: BEARER,
};
const SESSION_ENDED: ExpectedError = {
  status: 401,
  code: 'unauthorized',
  message: 'Your session has ended. Sign in again.',
  details: { reason: 'session_ended' },
  headers: BEARER,
};
const SESSION_UNCHECKED: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'Could not check your session.',
};
const ACCOUNT_UNCHECKED: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'Could not check your account.',
};
const LIMITER_DOWN: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'The rate limiter is unavailable.',
};
const DATABASE_FAILED: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'The database could not complete the request.',
};
const BUSY: ExpectedError = {
  status: 503,
  code: 'temporarily_unavailable',
  message: 'The service is busy. Please try again.',
  headers: { 'retry-after': '1' },
};
const DATA_NOT_DELETED: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'The account data could not be deleted.',
};
const USER_NOT_DELETED: ExpectedError = {
  status: 502,
  code: 'upstream_error',
  message: 'The account could not be deleted.',
};
const MFA_REQUIRED: ExpectedError = {
  status: 403,
  code: 'mfa_required',
  message: 'Verify with your second factor to continue.',
};

function rateLimited(retryAfter: string): ExpectedError {
  return {
    status: 429,
    code: 'rate_limited',
    message: 'Too many requests. Please wait a moment.',
    headers: { 'retry-after': retryAfter },
  };
}

function reauthenticate(maxAgeSeconds: number): ExpectedError {
  return {
    status: 401,
    code: 'reauthentication_required',
    message: 'Sign in again to delete your account.',
    details: { reauth_max_age_seconds: maxAgeSeconds },
    headers: {
      'www-authenticate':
        `Bearer error="insufficient_user_authentication", max_age=${maxAgeSeconds}`,
    },
  };
}

function invalid(reason: string, field = 'confirm_email'): ExpectedError {
  return {
    status: 422,
    code: 'validation_failed',
    message: `Invalid value for "${field}".`,
    details: { field, reason },
  };
}

/** The answer to a retry after the account is already gone. */
const ALREADY_DELETED = { deleted: true, deleted_portfolio_ids: [], files_removed: 0 };

const BASE_LOG = { fn: FN, request_id: REQUEST_ID };

function accessLog(method: string, status: number): LogRecord {
  return {
    ...BASE_LOG,
    method,
    status,
    duration_ms: 0,
    user_id: USER_ID,
    level: 'info',
    event: 'request',
  };
}

function rejectedLog(code: string, details?: Record<string, unknown>): LogRecord {
  return { ...BASE_LOG, code, details, level: 'warn', event: 'request_rejected' };
}

function failedLog(code: string, message: string, cause: unknown): LogRecord {
  return {
    ...BASE_LOG,
    code,
    error: { name: 'HttpError', message, cause },
    level: 'error',
    event: 'request_failed',
  };
}

function deletedLog(portfoliosDeleted: number, filesRemoved: number): LogRecord {
  return {
    ...BASE_LOG,
    user_id: USER_ID,
    portfolios_deleted: portfoliosDeleted,
    files_removed: filesRemoved,
    level: 'info',
    event: 'account_deleted',
  };
}

const ALREADY_DELETED_LOG: LogRecord = {
  ...BASE_LOG,
  user_id: USER_ID,
  level: 'info',
  event: 'account_already_deleted',
};

// --- the rules -----------------------------------------------------------------

Deno.test('the rules: 10 calls per user per 10 minutes, 8 s of inline cleanup, 320 characters, 60 s of skew', () => {
  assertEquals(DELETE_ACCOUNT_LIMIT, { limit: 10, windowSeconds: 600 });
  assertEquals(CLEANUP_BUDGET_MS, 8_000);
  assertEquals(MAX_CONFIRMATION_LENGTH, 320);
  assertEquals(EMAIL_320.length, MAX_CONFIRMATION_LENGTH);
  assertEquals(MAX_CLOCK_SKEW_SECONDS, 60);
});

Deno.test('FIRST_FACTOR_METHODS are the sign-ins, without second factors, refreshes or consents', () => {
  assertEquals([...FIRST_FACTOR_METHODS].sort(), [
    'email/signup',
    'magiclink',
    'oauth',
    'otp',
    'password',
    'recovery',
    'sso/saml',
    'web3',
  ]);
});

// --- lastSignInAt --------------------------------------------------------------

Deno.test('lastSignInAt finds no sign-in without claims or an amr list', () => {
  const cases: ReadonlyArray<readonly [string, Parameters<typeof lastSignInAt>[0]]> = [
    ['no claims', null],
    ['no amr claim', { sub: USER_ID }],
    ['amr null', { sub: USER_ID, amr: null }],
    ['amr a string', { sub: USER_ID, amr: 'password' }],
    ['amr a single entry', { sub: USER_ID, amr: signIn('password', NOW_SECONDS) }],
    ['amr empty', { sub: USER_ID, amr: [] }],
  ];
  for (const [label, claims] of cases) {
    assertEquals(lastSignInAt(claims, NOW_SECONDS), null, label);
  }
});

Deno.test('lastSignInAt returns the latest first-factor entry with a whole, not future, timestamp', () => {
  const T = NOW_SECONDS;
  const cases: ReadonlyArray<readonly [string, unknown[], number | null]> = [
    ['one password sign-in', [signIn('password', T - 30)], T - 30],
    [
      'the latest of several',
      [signIn('password', T - 500), signIn('otp', T - 100), signIn('oauth', T - 300)],
      T - 100,
    ],
    ['the latest in any order', [signIn('otp', T - 100), signIn('password', T - 500)], T - 100],
    ['null and non-object entries skipped', [null, 'password', 42, true], null],
    ['a valid entry among junk', [null, 'password', signIn('magiclink', T - 5), 7], T - 5],
    ['no method', [{ timestamp: T }], null],
    ['a method that is not a string', [signIn(['password'], T), signIn(1, T)], null],
    ['methods are case-sensitive', [signIn('Password', T), signIn('OTP', T)], null],
    [
      'second factors, refreshes and consents',
      [
        signIn('totp', T),
        signIn('mfa/phone', T),
        signIn('mfa/webauthn', T),
        signIn('token_refresh', T),
        signIn('anonymous', T),
        signIn('invite', T),
        signIn('email_change', T),
        signIn('oauth_provider/authorization_code', T),
        signIn('oauth_provider/x', T),
      ],
      null,
    ],
    ['60 s ahead: clock skew', [signIn('password', T + 60)], T + 60],
    ['61 s ahead: the future', [signIn('password', T + 61)], null],
    [
      'a future entry next to a past one',
      [signIn('password', T + 61), signIn('otp', T - 30)],
      T - 30,
    ],
    ['milliseconds (13 digits) lie in the future', [signIn('password', NOW.getTime())], null],
    ['a fraction of a second', [signIn('password', T - 0.5)], null],
    ['beyond the safe integers', [signIn('password', -(2 ** 53))], null],
    ['a numeric string', [signIn('password', String(T))], null],
    ['no timestamp', [{ method: 'password' }], null],
    ['a null timestamp', [signIn('password', null)], null],
    ['NaN', [signIn('password', Number.NaN)], null],
    ['infinity', [signIn('password', Number.POSITIVE_INFINITY)], null],
  ];
  for (const [label, amr, expected] of cases) {
    assertEquals(lastSignInAt({ sub: USER_ID, amr }, T), expected, label);
  }
});

Deno.test('lastSignInAt counts every first factor and measures the skew from the given time', () => {
  for (const method of FIRST_FACTOR_METHODS) {
    assertEquals(
      lastSignInAt({ sub: USER_ID, amr: [signIn(method, 1_000)] }, 1_000),
      1_000,
      method,
    );
  }
  assertEquals(lastSignInAt({ sub: USER_ID, amr: [signIn('password', 1_060)] }, 1_000), 1_060);
  assertEquals(lastSignInAt({ sub: USER_ID, amr: [signIn('password', 1_061)] }, 1_000), null);
  assertEquals(lastSignInAt({ sub: USER_ID, amr: [signIn('password', 0)] }, 1_000), 0);
});

// --- the pipeline ----------------------------------------------------------------

Deno.test('the function asks the pipeline for a signed-in user and never uses the caller client', async () => {
  for (const options of [forMethod('GET'), forMethod('HEAD'), forMethod('POST')]) {
    const { response, authModes, userCalls } = await send(options);
    assertEquals(response.status, 200, options.method);
    assertEquals(authModes, ['user'], options.method);
    assertEquals(userCalls, [], options.method);
  }
});

Deno.test('only GET, HEAD and POST are served: other methods get 405 before authentication', async () => {
  for (const method of ['PUT', 'PATCH', 'DELETE']) {
    const { response, calls, authModes } = await send({ method });
    await assertError(response, {
      status: 405,
      code: 'method_not_allowed',
      message: 'Use GET or POST or HEAD.',
      headers: { allow: 'GET, POST, HEAD, OPTIONS' },
    }, method);
    assertEquals([calls, authModes], [[], []], method);
  }
  const preflight = await send({ method: 'OPTIONS', origin: APP_ORIGIN, token: null });
  assertEquals(preflight.response.status, 204);
  assertEquals(
    preflight.response.headers.get('access-control-allow-methods'),
    'GET, POST, HEAD, OPTIONS',
  );
  assertEquals([preflight.calls, preflight.authModes], [[], []]);
});

Deno.test('only the account holder may call: no user, anonymous users and OAuth apps are refused first', async () => {
  const cases: ReadonlyArray<readonly [string, SendOptions, ExpectedError]> = [
    ['nobody signed in', { user: null }, SIGN_IN],
    [
      'an anonymous user',
      { claims: { ...FRESH, is_anonymous: true } },
      {
        status: 403,
        code: 'forbidden',
        message: 'Create an account to do this.',
        details: { reason: 'anonymous_user' },
      },
    ],
    [
      'a token issued to an OAuth app',
      { claims: { ...FRESH, client_id: 'third-party-app' } },
      {
        status: 403,
        code: 'forbidden',
        message: 'Connected apps cannot do this.',
        details: { reason: 'oauth_client_token' },
      },
    ],
  ];
  for (const method of METHODS) {
    for (const [label, options, expected] of cases) {
      const { response, calls } = await send({ ...forMethod(method), ...options });
      await assertError(response, expected, `${method}: ${label}`);
      assertEquals(calls, [], `${method}: ${label} is refused before the rate limit`);
    }
  }
});

Deno.test('index.ts serves the delete-account routes on the default dependencies', async () => {
  assertEquals(typeof deleteAccountFunction.fetch, 'function');
  // A preflight reads only the configuration: nothing reaches Auth or the network.
  const env = stub(
    Deno.env,
    'get',
    (name: string) => (name === 'ALLOWED_ORIGINS' ? APP_ORIGIN : undefined),
  );
  const log = stub(console, 'log');
  try {
    const response = await deleteAccountFunction.fetch(
      request({ method: 'OPTIONS', origin: APP_ORIGIN, token: null }),
    );
    assertEquals(response.status, 204);
    assertEquals(response.headers.get('access-control-allow-origin'), APP_ORIGIN);
    assertEquals(
      response.headers.get('access-control-allow-methods'),
      'GET, POST, HEAD, OPTIONS',
    );
    const requestId = response.headers.get('x-request-id') ?? '';
    assertMatch(requestId, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    assertEquals(log.calls.length, 1);
    const record = JSON.parse(String(log.calls[0]?.args[0]));
    assertEquals(
      [record.fn, record.event, record.method, record.status, record.request_id],
      [FN, 'request', 'OPTIONS', 204, requestId],
    );
  } finally {
    log.restore();
    env.restore();
  }
});

Deno.test('defaultDeleteAccountDeps are the default pipeline dependencies plus performance.now', () => {
  assertStrictEquals(defaultDeleteAccountDeps.loadConfig, defaultDeps.loadConfig);
  assertStrictEquals(defaultDeleteAccountDeps.createContext, defaultDeps.createContext);
  assertStrictEquals(defaultDeleteAccountDeps.now, defaultDeps.now);
  assertStrictEquals(defaultDeleteAccountDeps.newRequestId, defaultDeps.newRequestId);
  assertStrictEquals(defaultDeleteAccountDeps.logSink, defaultDeps.logSink);
  const now = stub(performance, 'now', returnsNext([1_234.5, 9_999]));
  try {
    assertEquals([defaultDeleteAccountDeps.clock(), defaultDeleteAccountDeps.clock()], [
      1_234.5,
      9_999,
    ]);
    assertEquals(now.calls.length, 2);
  } finally {
    now.restore();
  }
});

// --- rate limit ----------------------------------------------------------------

Deno.test('every call first counts a hit on delete_account:user:<id>, 10 per 600 s', async () => {
  for (const method of [...METHODS, 'HEAD']) {
    const { calls } = await send(forMethod(method));
    assertEquals(calls[0], LIMIT_CALL, method);
  }
});

Deno.test("over the limit: 429 with the database's Retry-After, whatever the Edge clock, and nothing else", async () => {
  const cases: ReadonlyArray<readonly [number, number]> = [
    // [milliseconds after NOW on the Edge clock, the database's wait]. The
    // database counted the hit in its own window: its wait is sent even when
    // the Edge clock has moved into the next window (RateLimit F5).
    [0, 600],
    [1_000, 599],
    [450_000, 150],
    [599_999, 1],
    [600_000, 1],
    [601_000, 5],
  ];
  for (const method of METHODS) {
    for (const [offset, wait] of cases) {
      const retryAfter = String(wait);
      const label = `${method} at NOW + ${offset} ms, database wait ${wait} s`;
      const admin = adminClient({
        rpc: { admin_rate_limit_hit: { data: { allowed: false, retry_after_seconds: wait } } },
      });
      const now = new Date(NOW.getTime() + offset);
      const { req, response, calls, logs } = await send({ ...forMethod(method), admin, now });
      await assertError(response, rateLimited(retryAfter), label);
      assertEquals(calls, [LIMIT_CALL], label);
      assertFalse(req.bodyUsed, `${label}: the body is not read`);
      assertEquals(logs, [rejectedLog('rate_limited'), accessLog(method, 429)], label);
    }
  }
});

Deno.test('a failing rate limiter fails closed with 502 and nothing else', async () => {
  const failures: ReadonlyArray<readonly [string, Result]> = [
    ['an error', { error: { code: 'XX000', message: 'limiter failed' }, status: 500 }],
    ['no answer', { data: null }],
    ['an answer that is not a verdict', { data: false }],
  ];
  for (const method of METHODS) {
    for (const [label, answer] of failures) {
      const admin = adminClient({ rpc: { admin_rate_limit_hit: answer } });
      const { response, calls } = await send({ ...forMethod(method), admin });
      await assertError(response, LIMITER_DOWN, `${method}: ${label}`);
      assertEquals(calls, [LIMIT_CALL], `${method}: ${label}`);
    }
  }
});

// --- GET: the preview ------------------------------------------------------------

Deno.test('GET previews the portfolios deleted with the account, the sign-in age and the factor', async () => {
  const { response, calls, logs } = await send({ method: 'GET' });
  assertEquals(response.status, 200);
  assertEquals(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assertEquals(response.headers.get('cache-control'), 'no-store');
  assertEquals(response.headers.get('x-request-id'), REQUEST_ID);
  assertEquals(await response.json(), {
    portfolios_to_delete: [
      { id: PORTFOLIO_ID, name: 'Raza Family Properties', other_members: 2 },
      { id: OTHER_PORTFOLIO_ID, name: 'Gulberg Shops', other_members: 0 },
    ],
    reauth_max_age_seconds: 600,
    second_factor_required: false,
  });
  assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, SCOPE_CALL]);
  assertEquals(logs, [accessLog('GET', 200)]);
});

Deno.test('GET reports the configured sign-in age', async () => {
  for (const seconds of [60, 900, 3_600]) {
    const config = testConfig({ reauthMaxAgeSeconds: seconds });
    const { response } = await send({ method: 'GET', config });
    assertEquals((await response.json()).reauth_max_age_seconds, seconds);
  }
});

Deno.test('GET reports second_factor_required only for an account with a verified factor', async () => {
  const cases: ReadonlyArray<readonly [string, Record<string, unknown>, unknown, boolean]> = [
    // [label, account overrides, aal claim, second_factor_required]
    ['a verified factor', { factors: [VERIFIED_TOTP] }, 'aal1', true],
    ['a verified factor, already at aal2', { factors: [VERIFIED_TOTP] }, 'aal2', true],
    [
      'a verified and an unverified factor',
      { factors: [UNVERIFIED_TOTP, VERIFIED_TOTP] },
      'aal1',
      true,
    ],
    ['an unverified factor only', { factors: [UNVERIFIED_TOTP] }, 'aal1', false],
    ['an empty factor list', { factors: [] }, 'aal1', false],
    ['no factors field', {}, 'aal1', false],
  ];
  for (const [label, user, aal, required] of cases) {
    const admin = adminClient({ user });
    const { response } = await send({ method: 'GET', admin, claims: { ...FRESH, aal } });
    assertEquals(response.status, 200, label);
    assertEquals((await response.json()).second_factor_required, required, label);
  }
});

Deno.test('GET needs neither a recent sign-in nor the second factor', async () => {
  const admin = adminClient({ user: { factors: [VERIFIED_TOTP] } });
  const { response } = await send({ method: 'GET', admin, claims: { aal: 'aal1' } });
  assertEquals(response.status, 200);
  assertEquals((await response.json()).second_factor_required, true);
});

Deno.test('GET with no portfolio owned alone previews an empty list', async () => {
  for (const answer of [{ data: [] }, { data: null }]) {
    const admin = adminClient({ rpc: { admin_account_deletion_scope: answer } });
    const { response } = await send({ method: 'GET', admin });
    assertEquals((await response.json()).portfolios_to_delete, [], JSON.stringify(answer));
  }
});

Deno.test('GET reports a failing scope RPC as 502, or 503 when transient, never as 401, 403 or 429', async () => {
  const cases: ReadonlyArray<readonly [string, Result, ExpectedError]> = [
    [
      'permission denied (42501)',
      { error: { code: '42501', message: 'permission denied' }, status: 403 },
      DATABASE_FAILED,
    ],
    [
      'an expired JWT (PGRST301)',
      { error: { code: 'PGRST301', message: 'JWT expired' }, status: 401 },
      DATABASE_FAILED,
    ],
    [
      'a rate limit',
      { error: { code: 'rate_limited', message: 'slow down', hint: '30' }, status: 429 },
      DATABASE_FAILED,
    ],
    [
      'a domain failure (22023)',
      { error: { code: '22023', message: 'invalid_user' }, status: 400 },
      DATABASE_FAILED,
    ],
    [
      'an internal error (XX000)',
      { error: { code: 'XX000', message: 'internal error' }, status: 500 },
      DATABASE_FAILED,
    ],
    [
      'a deadlock (40P01)',
      { error: { code: '40P01', message: 'deadlock detected' }, status: 500 },
      BUSY,
    ],
    [
      'a statement timeout (57014)',
      { error: { code: '57014', message: 'statement timeout' }, status: 500 },
      BUSY,
    ],
  ];
  for (const [label, answer, expected] of cases) {
    const admin = adminClient({ rpc: { admin_account_deletion_scope: answer } });
    const { response, calls, logs } = await send({ method: 'GET', admin });
    await assertError(response, expected, label);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, SCOPE_CALL], label);
    assertEquals(logs, [
      failedLog(expected.code, expected.message, answer.error),
      accessLog('GET', expected.status),
    ], label);
  }
});

Deno.test('HEAD runs the preview, rate limit included, and answers without a body', async () => {
  const { response, calls, logs } = await send({ method: 'HEAD' });
  assertEquals(response.status, 200);
  assertEquals(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assertEquals(await response.text(), '');
  assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, SCOPE_CALL]);
  assertEquals(logs, [accessLog('HEAD', 200)]);
});

// --- the live account (both methods) -----------------------------------------------

Deno.test('the account is read from Auth with the bearer token of the Authorization header', async () => {
  const headers = [
    `Bearer ${ACCESS_TOKEN}`,
    `bearer ${ACCESS_TOKEN}`,
    `BEARER ${ACCESS_TOKEN}`,
    `Bearer   ${ACCESS_TOKEN}`,
    `Bearer\t${ACCESS_TOKEN}`,
  ];
  for (const method of METHODS) {
    for (const authorization of headers) {
      const { response, calls } = await send({ ...forMethod(method), headers: { authorization } });
      assertEquals(response.status, 200, `${method} ${JSON.stringify(authorization)}`);
      assertEquals(calls[1], GET_USER_CALL, `${method} ${JSON.stringify(authorization)}`);
    }
  }
  const other = await send({ method: 'GET', token: 'another.access.token' });
  assertEquals(other.calls[1], { kind: 'getUser', args: ['another.access.token'] });
});

Deno.test('without a usable bearer token the request is refused with 401 after the rate limit', async () => {
  const cases: ReadonlyArray<readonly [string, SendOptions]> = [
    ['no Authorization header', { token: null }],
    ['an empty header', { headers: { authorization: '' } }],
    ['the scheme alone', { headers: { authorization: 'Bearer' } }],
    ['another scheme', { headers: { authorization: 'Basic b3duZXI6c2VjcmV0' } }],
    ['a token without a scheme', { headers: { authorization: ACCESS_TOKEN } }],
    ['two tokens', { headers: { authorization: `Bearer ${ACCESS_TOKEN} ${ACCESS_TOKEN}` } }],
  ];
  for (const method of METHODS) {
    for (const [label, options] of cases) {
      const { response, calls } = await send({ ...forMethod(method), ...options });
      await assertError(response, SIGN_IN, `${method}: ${label}`);
      assertEquals(calls, [LIMIT_CALL], `${method}: ${label}`);
    }
  }
});

Deno.test('a token that Auth resolves to another user is refused with 401', async () => {
  for (const method of METHODS) {
    const admin = adminClient({ user: { id: OTHER_USER_ID } });
    const { response, calls } = await send({ ...forMethod(method), admin });
    await assertError(response, SIGN_IN, method);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], method);
  }
});

/** Auth errors that mean the session or the user is gone: by code alone, or by status alone. */
const GONE: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
  ['code session_not_found', { message: 'Session not found', code: 'session_not_found' }],
  ['code user_not_found', { message: 'User not found', code: 'user_not_found', status: 400 }],
  ['code bad_jwt', { message: 'invalid JWT', code: 'bad_jwt', status: 400 }],
  ['status 401', { message: 'Unauthorized', status: 401 }],
  ['status 403', { message: 'Forbidden', status: 403, code: 'unexpected_failure' }],
  ['status 404', { message: 'Not Found', status: 404 }],
];

/** Auth errors that say nothing about the session. */
const NOT_GONE: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
  ['status 500', { message: 'Internal Server Error', status: 500, code: 'unexpected_failure' }],
  ['status 429', { message: 'Rate limit reached', status: 429, code: 'over_request_rate_limit' }],
  ['neither status nor code', { message: 'fetch failed' }],
];

/** What looking the user up by id can answer once the session is gone. */
const LOOKUPS: ReadonlyArray<readonly [string, Result, 'deleted' | ExpectedError]> = [
  [
    '404 user_not_found',
    { error: { message: 'User not found', status: 404, code: 'user_not_found' } },
    'deleted',
  ],
  ['404 without a code', { error: { message: 'Not Found', status: 404 } }, 'deleted'],
  [
    'user_not_found with another status',
    { error: { message: 'User not found', status: 422, code: 'user_not_found' } },
    'deleted',
  ],
  [
    'a server error',
    { error: { message: 'Database error', status: 500, code: 'unexpected_failure' } },
    ACCOUNT_UNCHECKED,
  ],
  ['a rejected key', { error: { message: 'Invalid API key', status: 401 } }, ACCOUNT_UNCHECKED],
  ['the user', { data: { user: account() } }, SESSION_ENDED],
];

Deno.test('Auth errors that do not mean "gone" fail with 502 without looking the user up', async () => {
  for (const method of METHODS) {
    for (const [label, error] of NOT_GONE) {
      const admin = adminClient({ getUser: () => ({ error }) });
      const { response, calls, logs } = await send({ ...forMethod(method), admin });
      await assertError(response, SESSION_UNCHECKED, `${method}: ${label}`);
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], `${method}: ${label}`);
      assertEquals(logs, [
        failedLog('upstream_error', 'Could not check your session.', error),
        accessLog(method, 502),
      ], `${method}: ${label}`);
    }
  }
});

Deno.test('POST after the session is gone: a deleted account is success again, with no deletion calls', async () => {
  for (const [gone, error] of GONE) {
    for (const [lookupLabel, lookup, outcome] of LOOKUPS) {
      const label = `${gone}, lookup: ${lookupLabel}`;
      const admin = adminClient({ getUser: () => ({ error }), getUserById: () => lookup });
      const { response, calls, logs } = await confirm({ admin });
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, LOOKUP_CALL], label);
      if (outcome === 'deleted') {
        assertEquals(response.status, 200, label);
        assertEquals(await response.json(), ALREADY_DELETED, label);
        assertEquals(logs, [ALREADY_DELETED_LOG, accessLog('POST', 200)], label);
      } else {
        await assertError(response, outcome, label);
      }
    }
  }
});

Deno.test('GET after the session is gone: 401 session_ended, deleted account or not', async () => {
  for (const [gone, error] of GONE) {
    for (const [lookupLabel, lookup, outcome] of LOOKUPS) {
      const label = `${gone}, lookup: ${lookupLabel}`;
      const admin = adminClient({ getUser: () => ({ error }), getUserById: () => lookup });
      const { response, calls, logs } = await send({ method: 'GET', admin });
      const expected = outcome === 'deleted' ? SESSION_ENDED : outcome;
      await assertError(response, expected, label);
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, LOOKUP_CALL], label);
      if (expected === SESSION_ENDED) {
        assertEquals(logs, [
          rejectedLog('unauthorized', { reason: 'session_ended' }),
          accessLog('GET', 401),
        ], label);
      }
    }
  }
});

// --- POST: the body ------------------------------------------------------------

Deno.test('POST validates the body after the rate limit and before reading the account', async () => {
  const notJson = { status: 415, code: 'unsupported_media_type' };
  const cases: ReadonlyArray<
    readonly [string, Pick<SendOptions, 'body' | 'headers'>, ExpectedError]
  > = [
    [
      'an unknown field',
      { body: { confirm_email: EMAIL, force: true } },
      invalid('unknown_field', 'force'),
    ],
    ['an unknown field alone', { body: { email: EMAIL } }, invalid('unknown_field', 'email')],
    ['no confirm_email', { body: {} }, invalid('required')],
    ['a null confirm_email', { body: { confirm_email: null } }, invalid('required')],
    ['an empty confirm_email', { body: { confirm_email: '' } }, invalid('required')],
    ['a blank confirm_email', { body: { confirm_email: ' \t\n ' } }, invalid('required')],
    ['a number', { body: { confirm_email: 42 } }, invalid('not_a_string')],
    ['a boolean', { body: { confirm_email: true } }, invalid('not_a_string')],
    ['a list', { body: { confirm_email: [EMAIL] } }, invalid('not_a_string')],
    ['an object', { body: { confirm_email: { address: EMAIL } } }, invalid('not_a_string')],
    ['321 characters', { body: { confirm_email: EMAIL_321 } }, invalid('too_long')],
    ['321 astral characters', { body: { confirm_email: HOUSE.repeat(321) } }, invalid('too_long')],
    [
      'a right-to-left override',
      { body: { confirm_email: `${RLO}moc.elpmaxe@renwo` } },
      invalid('forbidden_characters'),
    ],
    [
      'a zero-width space',
      { body: { confirm_email: `owner${ZWSP}@example.com` } },
      invalid('forbidden_characters'),
    ],
    [
      'a NUL character',
      { body: { confirm_email: `${EMAIL}${NUL}` } },
      invalid('forbidden_characters'),
    ],
    [
      'invalid JSON',
      { body: '{"confirm_email": ' },
      { status: 400, code: 'invalid_json', message: 'The request body is not valid JSON.' },
    ],
    [
      'a JSON list',
      { body: [EMAIL] },
      {
        status: 422,
        code: 'validation_failed',
        message: 'The request body must be a JSON object.',
        details: { field: '$', reason: 'not_an_object' },
      },
    ],
    [
      'plain text',
      { body: EMAIL, headers: { 'content-type': 'text/plain' } },
      { ...notJson, message: 'Send the body as application/json.' },
    ],
    ['no body', {}, { ...notJson, message: 'Send the body as application/json.' }],
  ];
  for (const [label, options, expected] of cases) {
    const { req, response, calls, logs } = await send({ method: 'POST', ...options });
    await assertError(response, expected, label);
    assertEquals(calls, [LIMIT_CALL], label);
    assertEquals(req.bodyUsed, options.body !== undefined && expected.status !== 415, label);
    assertEquals(logs, [
      rejectedLog(expected.code, expected.details),
      accessLog('POST', expected.status),
    ], label);
  }
});

Deno.test('POST accepts 320 characters, counted as code points after trimming', async () => {
  for (const typed of [EMAIL_320, `  ${EMAIL_320}\t`, EMAIL_320.toUpperCase()]) {
    const admin = adminClient({ user: { email: EMAIL_320 } });
    const { response, calls } = await confirm({ body: { confirm_email: typed }, admin });
    assertEquals(response.status, 200, typed);
    assertEquals(trail(calls), [LIMIT, GET_USER, DELETE_DATA, DELETE_USER]);
  }
  // 320 characters outside the BMP are 640 UTF-16 code units, yet within the limit:
  // the confirmation is compared, and does not match.
  const astral = await confirm({ body: { confirm_email: HOUSE.repeat(320) } });
  await assertError(astral.response, invalid('does_not_match_account'));
  assertEquals(astral.calls, [LIMIT_CALL, GET_USER_CALL]);
});

// --- POST: the e-mail confirmation -------------------------------------------------

Deno.test('POST compares the confirmation with the stored e-mail, ignoring case and outer whitespace', async () => {
  const cases: ReadonlyArray<readonly [string, string, boolean]> = [
    // [stored by Auth, typed, matches]
    [EMAIL, EMAIL, true],
    [EMAIL, 'OWNER@EXAMPLE.COM', true],
    [EMAIL, '  Owner@Example.com\t\n', true],
    ['  Owner@Example.COM ', EMAIL, true],
    [EMAIL, 'someone@example.com', false],
    [EMAIL, 'owner@example.co', false],
    [EMAIL, 'owner@example.com.pk', false],
    [EMAIL, 'owner @example.com', false],
  ];
  for (const [stored, typed, matches] of cases) {
    const label = `${JSON.stringify(stored)} / ${JSON.stringify(typed)}`;
    const admin = adminClient({ user: { email: stored } });
    const { response, calls, logs } = await confirm({ body: { confirm_email: typed }, admin });
    if (matches) {
      assertEquals(response.status, 200, label);
      assertEquals(trail(calls), [LIMIT, GET_USER, DELETE_DATA, DELETE_USER], label);
    } else {
      await assertError(response, invalid('does_not_match_account'), label);
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], label);
      assertEquals(logs, [
        rejectedLog('validation_failed', {
          field: 'confirm_email',
          reason: 'does_not_match_account',
        }),
        accessLog('POST', 422),
      ], label);
    }
  }
});

Deno.test("POST confirms against the e-mail Auth stores now, not the token's copy", async () => {
  const previous = {
    user: { email: 'old@example.com' },
    claims: { ...FRESH, email: 'old@example.com' },
  };
  const typedOld = await confirm({
    ...previous,
    body: { confirm_email: 'old@example.com' },
    admin: adminClient({ user: { email: 'new@example.com' } }),
  });
  await assertError(typedOld.response, invalid('does_not_match_account'));
  const typedNew = await confirm({
    ...previous,
    body: { confirm_email: 'new@example.com' },
    admin: adminClient({ user: { email: 'new@example.com' } }),
  });
  assertEquals(typedNew.response.status, 200);
});

Deno.test('POST cannot confirm an account without an e-mail address: 422 account_has_no_email', async () => {
  for (const email of [undefined, '', '   ']) {
    const admin = adminClient({ user: { email, phone: '923001234567' } });
    const { response, calls } = await confirm({ admin });
    await assertError(response, invalid('account_has_no_email'), JSON.stringify(email));
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], JSON.stringify(email));
  }
});

// --- POST: the sign-in age -------------------------------------------------------

Deno.test('POST needs a first-factor sign-in within REAUTH_MAX_AGE_SECONDS (600 s)', async () => {
  const T = NOW_SECONDS;
  const cases: ReadonlyArray<readonly [string, unknown, boolean]> = [
    // [label, amr claim, accepted]
    ['a password sign-in exactly 600 s ago', [signIn('password', T - 600)], true],
    ['a password sign-in 601 s ago', [signIn('password', T - 601)], false],
    ['a sign-in now', [signIn('password', T)], true],
    ['a sign-in 60 s ahead (clock skew)', [signIn('otp', T + 60)], true],
    ['a sign-in 61 s ahead', [signIn('otp', T + 61)], false],
    ['a timestamp in milliseconds', [signIn('magiclink', NOW.getTime())], false],
    ['a fractional timestamp', [signIn('password', T - 1.5)], false],
    ['a string timestamp', [signIn('password', String(T))], false],
    ['no timestamp', [{ method: 'password' }], false],
    [
      'a recent totp after a stale password',
      [signIn('password', T - 601), signIn('totp', T)],
      false,
    ],
    ['a token refresh', [signIn('password', T - 601), signIn('token_refresh', T)], false],
    ['an invitation', [signIn('invite', T)], false],
    ['an e-mail change', [signIn('email_change', T)], false],
    ['consent given to an OAuth app', [signIn('oauth_provider/x', T)], false],
    ['an anonymous sign-in', [signIn('anonymous', T)], false],
    ['the latest first factor', [signIn('password', T - 3_000), signIn('oauth', T - 10)], true],
    ['amr not a list', 'password', false],
    ['amr of null entries', [null, null], false],
  ];
  for (const [label, amr, accepted] of cases) {
    const { response, calls, logs } = await confirm({ claims: { aal: 'aal1', amr } });
    if (accepted) {
      assertEquals(response.status, 200, label);
      assertEquals(trail(calls), [LIMIT, GET_USER, DELETE_DATA, DELETE_USER], label);
    } else {
      await assertError(response, reauthenticate(600), label);
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], label);
      assertEquals(logs, [
        rejectedLog('reauthentication_required', { reauth_max_age_seconds: 600 }),
        accessLog('POST', 401),
      ], label);
    }
  }
  for (const claims of [{ aal: 'aal1' }, null]) {
    const { response, calls } = await confirm({ claims });
    await assertError(response, reauthenticate(600), `claims ${JSON.stringify(claims)}`);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL]);
  }
});

Deno.test('POST accepts each first-factor method as the recent sign-in', async () => {
  for (const method of FIRST_FACTOR_METHODS) {
    const claims = { aal: 'aal1', amr: [signIn(method, NOW_SECONDS - 600)] };
    const { response } = await confirm({ claims });
    assertEquals(response.status, 200, method);
  }
});

Deno.test('POST measures the sign-in age against the configured maximum', async () => {
  for (const maxAge of [60, 3_600]) {
    const config = testConfig({ reauthMaxAgeSeconds: maxAge });
    const atLimit = { aal: 'aal1', amr: [signIn('password', NOW_SECONDS - maxAge)] };
    assertEquals((await confirm({ config, claims: atLimit })).response.status, 200, `${maxAge}`);
    const beyond = { aal: 'aal1', amr: [signIn('password', NOW_SECONDS - maxAge - 1)] };
    const { response } = await confirm({ config, claims: beyond });
    await assertError(response, reauthenticate(maxAge), `${maxAge}`);
  }
});

Deno.test('an unusable REAUTH_MAX_AGE_SECONDS fails closed with 500 and deletes nothing', async () => {
  const config = testConfig({
    reauthMaxAgeSeconds: new ConfigError(
      'REAUTH_MAX_AGE_SECONDS',
      'must be a whole number between 60 and 3600',
    ),
  });
  const misconfigured: ExpectedError = {
    status: 500,
    code: 'server_misconfigured',
    message: 'The service is not configured correctly.',
    details: { variable: 'REAUTH_MAX_AGE_SECONDS' },
  };
  const deletion = await confirm({ config });
  await assertError(deletion.response, misconfigured, 'POST');
  assertEquals(deletion.calls, [LIMIT_CALL, GET_USER_CALL]);
  const preview = await send({ method: 'GET', config });
  await assertError(preview.response, misconfigured, 'GET');
  assertEquals(preview.calls, [LIMIT_CALL, GET_USER_CALL, SCOPE_CALL]);
});

// --- POST: the second factor -----------------------------------------------------

Deno.test('POST asks an account with a verified factor for the second factor (aal2)', async () => {
  const cases: ReadonlyArray<readonly [string, Record<string, unknown>, unknown, boolean]> = [
    // [label, account overrides, aal claim, allowed]
    ['a verified factor at aal1', { factors: [VERIFIED_TOTP] }, 'aal1', false],
    ['a verified factor without an aal claim', { factors: [VERIFIED_TOTP] }, undefined, false],
    ['a verified factor at "AAL2"', { factors: [VERIFIED_TOTP] }, 'AAL2', false],
    [
      'an unverified and a verified factor',
      { factors: [UNVERIFIED_TOTP, VERIFIED_TOTP] },
      'aal1',
      false,
    ],
    ['a verified factor at aal2', { factors: [VERIFIED_TOTP] }, 'aal2', true],
    ['an unverified factor only', { factors: [UNVERIFIED_TOTP] }, 'aal1', true],
    ['an empty factor list', { factors: [] }, 'aal1', true],
    ['no factors field', {}, 'aal1', true],
  ];
  for (const [label, user, aal, allowed] of cases) {
    const admin = adminClient({ user });
    const { response, calls, logs } = await confirm({ admin, claims: { amr: FRESH['amr'], aal } });
    if (allowed) {
      assertEquals(response.status, 200, label);
      assertEquals(trail(calls), [LIMIT, GET_USER, DELETE_DATA, DELETE_USER], label);
    } else {
      await assertError(response, MFA_REQUIRED, label);
      assertEquals(calls, [LIMIT_CALL, GET_USER_CALL], label);
      assertEquals(logs, [rejectedLog('mfa_required'), accessLog('POST', 403)], label);
    }
  }
});

// --- POST: the order of the checks -------------------------------------------------

Deno.test('POST checks in order: rate limit, body, live account, e-mail, sign-in age, second factor', async () => {
  const mismatch = { confirm_email: 'someone@example.com' };
  const sessionEnded: AdminOptions = {
    getUser: () => ({
      error: { message: 'Session not found', status: 403, code: 'session_not_found' },
    }),
    getUserById: () => ({ data: { user: account() } }),
  };
  const withFactor: AdminOptions = { user: { factors: [VERIFIED_TOTP] } };
  const cases: ReadonlyArray<
    readonly [string, SendOptions, ExpectedError | null, string[]]
  > = [
    [
      'the rate limit before the body',
      {
        body: { force: true },
        admin: adminClient({
          rpc: { admin_rate_limit_hit: { data: { allowed: false, retry_after_seconds: 600 } } },
        }),
      },
      rateLimited('600'),
      [LIMIT],
    ],
    [
      'the body before the account',
      { body: { confirm_email: EMAIL, force: true }, admin: adminClient(sessionEnded) },
      invalid('unknown_field', 'force'),
      [LIMIT],
    ],
    [
      'the account before the e-mail',
      { body: mismatch, admin: adminClient(sessionEnded) },
      SESSION_ENDED,
      [LIMIT, GET_USER, LOOKUP],
    ],
    [
      'the e-mail before the sign-in age',
      { body: mismatch, claims: STALE, admin: adminClient(withFactor) },
      invalid('does_not_match_account'),
      [LIMIT, GET_USER],
    ],
    [
      'the sign-in age before the second factor',
      { claims: STALE, admin: adminClient(withFactor) },
      reauthenticate(600),
      [LIMIT, GET_USER],
    ],
    [
      'the second factor before the deletion',
      { admin: adminClient(withFactor) },
      MFA_REQUIRED,
      [LIMIT, GET_USER],
    ],
    ['then the deletion', {}, null, [LIMIT, GET_USER, DELETE_DATA, DELETE_USER]],
  ];
  for (const [label, options, expected, calls] of cases) {
    const sent = await confirm(options);
    if (expected === null) {
      assertEquals(sent.response.status, 200, label);
    } else {
      await assertError(sent.response, expected, label);
    }
    assertEquals(trail(sent.calls), calls, label);
  }
});

// --- POST: the deletion ------------------------------------------------------------

Deno.test('POST deletes the data, then the auth user, then the files of the deleted portfolios', async () => {
  const admin = adminClient({
    rpc: {
      ...deleted(PORTFOLIO_ID, OTHER_PORTFOLIO_ID),
      ...cleanupQueue([ITEM_1, ITEM_2], { 41: [FILES_1], 42: [FILES_2] }),
    },
    remove: (_bucket, paths) => ({ data: paths.map((name) => ({ name })) }),
  });
  const { response, calls, logs } = await confirm({ admin });
  assertEquals(response.status, 200);
  assertEquals(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assertEquals(response.headers.get('x-request-id'), REQUEST_ID);
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID, OTHER_PORTFOLIO_ID],
    files_removed: 3,
  });
  const folders = [`${PORTFOLIO_ID}/`, `${OTHER_PORTFOLIO_ID}/`];
  assertEquals(calls, [
    LIMIT_CALL,
    GET_USER_CALL,
    DELETE_DATA_CALL,
    DELETE_USER_CALL,
    claimCall(folders),
    listCall(41),
    removeCall(FILES_1),
    listCall(41),
    completeCall(41, true),
    listCall(42),
    removeCall(FILES_2),
    listCall(42),
    completeCall(42, true),
    claimCall(folders),
  ]);
  assertEquals(logs, [deletedLog(2, 3), accessLog('POST', 200)]);
});

Deno.test('POST with no portfolio deleted claims no cleanup', async () => {
  const { response, calls, logs } = await confirm();
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [],
    files_removed: 0,
  });
  assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, DELETE_DATA_CALL, DELETE_USER_CALL]);
  assertEquals(logs, [deletedLog(0, 0), accessLog('POST', 200)]);
});

Deno.test('POST reports a failing data deletion as 502, or 503 when transient, and keeps the user', async () => {
  const cases: ReadonlyArray<readonly [string, Result, ExpectedError]> = [
    [
      'an internal error (XX000)',
      { error: { code: 'XX000', message: 'internal error' }, status: 500 },
      DATABASE_FAILED,
    ],
    [
      'permission denied (42501)',
      { error: { code: '42501', message: 'permission denied' }, status: 403 },
      DATABASE_FAILED,
    ],
    [
      'a domain failure (22023)',
      { error: { code: '22023', message: 'invalid_user' }, status: 400 },
      DATABASE_FAILED,
    ],
    [
      'a deadlock (40P01)',
      { error: { code: '40P01', message: 'deadlock detected' }, status: 500 },
      BUSY,
    ],
    [
      'a lock not available (55P03)',
      { error: { code: '55P03', message: 'lock not available' }, status: 500 },
      BUSY,
    ],
  ];
  for (const [label, answer, expected] of cases) {
    const admin = adminClient({ rpc: { admin_delete_account_data: answer } });
    const { response, calls, logs } = await confirm({ admin });
    await assertError(response, expected, label);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, DELETE_DATA_CALL], label);
    assertEquals(logs, [
      failedLog(expected.code, expected.message, answer.error),
      accessLog('POST', expected.status),
    ], label);
  }
});

Deno.test('POST refuses a data deletion answer without a list of string ids with 502', async () => {
  const answers: ReadonlyArray<readonly [string, unknown]> = [
    ['no data', null],
    ['no ids', {}],
    ['null ids', { deleted_portfolio_ids: null }],
    ['a single id', { deleted_portfolio_ids: PORTFOLIO_ID }],
    ['numbers', { deleted_portfolio_ids: [1, 2] }],
    ['a null among the ids', { deleted_portfolio_ids: [PORTFOLIO_ID, null] }],
    ['a bare list', [PORTFOLIO_ID]],
  ];
  for (const [label, data] of answers) {
    const admin = adminClient({ rpc: { admin_delete_account_data: { data } } });
    const { response, calls, logs } = await confirm({ admin });
    await assertError(response, DATA_NOT_DELETED, label);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, DELETE_DATA_CALL], label);
    assertEquals(logs, [
      failedLog('upstream_error', DATA_NOT_DELETED.message, {
        name: 'Error',
        message: 'unexpected admin_delete_account_data response',
        cause: undefined,
      }),
      accessLog('POST', 502),
    ], label);
  }
});

Deno.test('POST treats an auth user that is already gone (404) as deleted', async () => {
  const admin = adminClient({
    rpc: { ...deleted(PORTFOLIO_ID), ...cleanupQueue([ITEM_1], { 41: [FILES_1] }) },
    deleteUser: () => ({
      error: { message: 'User not found', status: 404, code: 'user_not_found' },
    }),
    remove: (_bucket, paths) => ({ data: paths.map((name) => ({ name })) }),
  });
  const { response, calls, logs } = await confirm({ admin });
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID],
    files_removed: 2,
  });
  assertEquals(trail(calls), [
    LIMIT,
    GET_USER,
    DELETE_DATA,
    DELETE_USER,
    CLAIM,
    LIST,
    REMOVE,
    LIST,
    COMPLETE,
    CLAIM,
  ]);
  assertEquals(logs, [deletedLog(1, 2), accessLog('POST', 200)]);
});

Deno.test('POST reports any other failure to delete the auth user as 502, before any cleanup', async () => {
  const failures: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
    ['a server error', { message: 'Database error deleting user', status: 500 }],
    ['a rejected key', { message: 'Invalid API key', status: 401 }],
    ['neither status nor code', { message: 'fetch failed' }],
  ];
  for (const [label, error] of failures) {
    const admin = adminClient({
      rpc: deleted(PORTFOLIO_ID),
      deleteUser: () => ({ error }),
    });
    const { response, calls, logs } = await confirm({ admin });
    await assertError(response, USER_NOT_DELETED, label);
    assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, DELETE_DATA_CALL, DELETE_USER_CALL], label);
    assertEquals(logs, [
      failedLog('upstream_error', USER_NOT_DELETED.message, error),
      accessLog('POST', 502),
    ], label);
  }
});

// --- POST: the inline cleanup ------------------------------------------------------

Deno.test('a failing cleanup is left to storage-cleanup: still 200, and the deferral is logged', async () => {
  const failures: ReadonlyArray<readonly [string, Record<string, unknown>, string]> = [
    [
      'a failing claim',
      { code: 'XX000', message: 'could not claim' },
      'The database could not complete the request.',
    ],
    [
      'a deadlocked claim',
      { code: '40P01', message: 'deadlock detected' },
      'The service is busy. Please try again.',
    ],
  ];
  for (const [label, error, message] of failures) {
    const admin = adminClient({
      rpc: { ...deleted(PORTFOLIO_ID), admin_claim_storage_cleanup: { error } },
    });
    const { response, calls, logs } = await confirm({ admin });
    assertEquals(response.status, 200, label);
    assertEquals(await response.json(), {
      deleted: true,
      deleted_portfolio_ids: [PORTFOLIO_ID],
      files_removed: 0,
    }, label);
    assertEquals(calls, [
      LIMIT_CALL,
      GET_USER_CALL,
      DELETE_DATA_CALL,
      DELETE_USER_CALL,
      claimCall([`${PORTFOLIO_ID}/`]),
    ], label);
    assertEquals(logs, [
      {
        ...BASE_LOG,
        user_id: USER_ID,
        error: { name: 'HttpError', message, cause: error },
        level: 'error',
        event: 'account_files_cleanup_deferred',
      },
      deletedLog(1, 0),
      accessLog('POST', 200),
    ], label);
  }
});

Deno.test('files removed before the cleanup failed are still reported', async () => {
  const error = { code: 'XX000', message: 'could not complete' };
  const admin = adminClient({
    rpc: {
      ...deleted(PORTFOLIO_ID),
      ...cleanupQueue([ITEM_1], { 41: [FILES_1] }),
      admin_complete_storage_cleanup: { error },
    },
    remove: (_bucket, paths) => ({ data: paths.map((name) => ({ name })) }),
  });
  const { response, calls, logs } = await confirm({ admin });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID],
    files_removed: FILES_1.length,
  });
  assertEquals(calls, [
    LIMIT_CALL,
    GET_USER_CALL,
    DELETE_DATA_CALL,
    DELETE_USER_CALL,
    claimCall([`${PORTFOLIO_ID}/`]),
    listCall(41),
    removeCall(FILES_1),
    listCall(41),
    completeCall(41, true),
  ]);
  assertEquals(logs, [
    {
      ...BASE_LOG,
      user_id: USER_ID,
      error: {
        name: 'HttpError',
        message: 'The database could not complete the request.',
        cause: error,
      },
      level: 'error',
      event: 'account_files_cleanup_deferred',
    },
    deletedLog(1, FILES_1.length),
    accessLog('POST', 200),
  ]);
});

Deno.test('an unexpected Storage exception during the cleanup still answers 200', async () => {
  const thrown = new TypeError('storage client exploded');
  const admin = adminClient({
    rpc: { ...deleted(PORTFOLIO_ID), ...cleanupQueue([ITEM_1], { 41: [FILES_1] }) },
    remove: () => {
      throw thrown;
    },
  });
  const { response, logs } = await confirm({ admin });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID],
    files_removed: 0,
  });
  assertEquals(logs, [
    {
      ...BASE_LOG,
      user_id: USER_ID,
      error: { name: 'TypeError', message: 'storage client exploded', cause: undefined },
      level: 'error',
      event: 'account_files_cleanup_deferred',
    },
    deletedLog(1, 0),
    accessLog('POST', 200),
  ]);
});

Deno.test('the cleanup stops when CLEANUP_BUDGET_MS have passed since it started', async () => {
  const cases: ReadonlyArray<readonly [string, number, boolean]> = [
    // [label, milliseconds the first page takes, the folder is finished]
    ['1 ms of the budget left', CLEANUP_BUDGET_MS - 1, true],
    ['the budget spent', CLEANUP_BUDGET_MS, false],
    ['the budget overrun', CLEANUP_BUDGET_MS + 5_000, false],
  ];
  const folder = [`${PORTFOLIO_ID}/`];
  for (const [label, pageMs, finished] of cases) {
    const time = steppingClock();
    time.advance(5_000); // the monotonic clock reads 5 s when the request starts
    const admin = adminClient({
      rpc: { ...deleted(PORTFOLIO_ID), ...cleanupQueue([ITEM_1], { 41: [FILES_1] }) },
      remove: (_bucket, paths) => {
        time.advance(pageMs);
        return { data: paths.map((name) => ({ name })) };
      },
    });
    const { response, calls, logs } = await confirm({ admin, clock: time.clock });
    assertEquals(await response.json(), {
      deleted: true,
      deleted_portfolio_ids: [PORTFOLIO_ID],
      files_removed: 2,
    }, label);
    assertEquals(
      calls.slice(4),
      finished
        // Within the budget: the folder is listed again, found empty and finished.
        ? [
          claimCall(folder),
          listCall(41),
          removeCall(FILES_1),
          listCall(41),
          completeCall(41, true),
          claimCall(folder),
        ]
        // Out of budget: the folder is handed back unfinished and nothing more is claimed.
        : [claimCall(folder), listCall(41), removeCall(FILES_1), completeCall(41, false)],
      label,
    );
    assertEquals(logs, [deletedLog(1, 2), accessLog('POST', 200)], label);
  }
});

Deno.test('a cleanup clock that has already spent the budget claims nothing', async () => {
  // Each reading advances the clock by the whole budget: the deadline passes before the claim.
  const admin = adminClient({ rpc: deleted(PORTFOLIO_ID) });
  const { response, calls, logs } = await confirm({
    admin,
    clock: steppingClock(CLEANUP_BUDGET_MS).clock,
  });
  assertEquals(await response.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID],
    files_removed: 0,
  });
  assertEquals(calls, [LIMIT_CALL, GET_USER_CALL, DELETE_DATA_CALL, DELETE_USER_CALL]);
  assertEquals(logs, [deletedLog(1, 0), accessLog('POST', 200)]);
});

// --- logs ------------------------------------------------------------------------

Deno.test('the logs never contain the e-mail addresses or the access token', async () => {
  const typed = 'Someone.Else@Example.com';
  const gone = { error: { message: 'Session not found', status: 403, code: 'session_not_found' } };
  const post = (options: SendOptions = {}): SendOptions => ({ ...forMethod('POST'), ...options });
  const scenarios: ReadonlyArray<readonly [string, SendOptions]> = [
    ['a preview', forMethod('GET')],
    [
      'a deletion with cleanup',
      post({
        admin: adminClient({
          rpc: { ...deleted(PORTFOLIO_ID), ...cleanupQueue([ITEM_1], { 41: [FILES_1] }) },
          remove: (_bucket, paths) => ({ data: paths.map((name) => ({ name })) }),
        }),
      }),
    ],
    [
      'a deferred cleanup',
      post({
        admin: adminClient({
          rpc: {
            ...deleted(PORTFOLIO_ID),
            admin_claim_storage_cleanup: { error: { code: 'XX000', message: 'down' } },
          },
        }),
      }),
    ],
    ['a mismatch', post({ body: { confirm_email: typed } })],
    ['an unknown field', post({ body: { confirm_email: EMAIL, note: typed } })],
    ['a stale sign-in', post({ claims: STALE })],
    [
      'a missing second factor',
      post({ admin: adminClient({ user: { factors: [VERIFIED_TOTP] } }) }),
    ],
    [
      'a failing session check',
      post({
        admin: adminClient({ getUser: () => ({ error: { message: 'Internal', status: 500 } }) }),
      }),
    ],
    [
      'an ended session',
      post({
        admin: adminClient({
          getUser: () => gone,
          getUserById: () => ({ data: { user: account() } }),
        }),
      }),
    ],
    [
      'an account already deleted',
      post({
        admin: adminClient({
          getUser: () => gone,
          getUserById: () => ({ error: { message: 'User not found', status: 404 } }),
        }),
      }),
    ],
  ];
  for (const [label, options] of scenarios) {
    const { response, logs } = await send(options);
    await response.body?.cancel();
    assert(logs.length > 0, label);
    const text = logText(logs).toLowerCase();
    assertFalse(text.includes(EMAIL), `${label}: the account's e-mail`);
    assertFalse(text.includes(typed.toLowerCase()), `${label}: the typed e-mail`);
    assertFalse(text.includes(ACCESS_TOKEN.toLowerCase()), `${label}: the access token`);
  }
});
