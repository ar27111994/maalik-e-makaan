/**
 * health: public liveness for uptime monitors and the token-protected deep
 * readiness check. The admin client, the auth endpoint, fetch and the
 * platform variables are injected through HealthDeps, and performance.now is
 * frozen around every request, so each latency and duration reads 0.
 */

import {
  assert,
  assertEquals,
  assertExists,
  assertFalse,
  assertInstanceOf,
  assertMatch,
  assertStrictEquals,
} from '@std/assert';
import { returnsNext, stub } from '@std/testing/mock';
import {
  ConfigError,
  type FunctionConfig,
  loadConfig,
  MIN_TOKEN_LENGTH,
} from '../_shared/config.ts';
import { defaultDeps } from '../_shared/handler.ts';
import type { LogRecord } from '../_shared/log.ts';
import {
  type AuthEndpoint,
  authEndpointFromEnv,
  CHECK_TIMEOUT_MS,
  type CheckResult,
  createHealthHandler,
  defaultHealthDeps,
  type HealthDeps,
  runCheck,
} from '../health/handler.ts';
import server from '../health/index.ts';
import {
  APP_ORIGIN,
  errorOf,
  type FakeClient,
  fakeClient,
  type FakeClientOptions,
  fakeContext,
  harness,
  logText,
  PORTFOLIO_ID,
  request,
  REQUEST_ID,
  type Result,
  testConfig,
} from './_helpers.ts';

const FN = 'health';
/** A valid HEALTH_CHECK_TOKEN: at least MIN_TOKEN_LENGTH characters. */
const TOKEN = 'h'.repeat(40);
const PROJECT_URL = 'https://project.supabase.co';
const AUTH: AuthEndpoint = { url: PROJECT_URL, publishableKey: 'sb_publishable_test' };
const AUTH_HEALTH_URL = 'https://project.supabase.co/auth/v1/health';
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const SECURITY = {
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-content-type-options': 'nosniff',
};
/** The headers of every JSON answer to a request without an Origin. */
const JSON_HEADERS = {
  ...SECURITY,
  'content-type': 'application/json; charset=utf-8',
  vary: 'Origin',
  'x-request-id': REQUEST_ID,
};

/** The liveness body off the platform (no DENO_DEPLOYMENT_ID or SB_REGION), at NOW. */
const LIVENESS = {
  status: 'ok',
  service: 'maalik-e-makaan',
  version: 'local',
  region: 'local',
  time: '2026-11-03T12:00:00.000Z',
};
const HEALTHY: CheckResult = { ok: true, latency_ms: 0 };
const ALL_HEALTHY = { database: HEALTHY, storage: HEALTHY, auth: HEALTHY };

function failed(error: string): CheckResult {
  return { ok: false, latency_ms: 0, error };
}

/** The recorded database probe: `from('portfolios').select('id').limit(1)`. */
const DATABASE_PROBE = {
  kind: 'select',
  args: ['portfolios', 'id', { filters: {}, limit: 1, columns: 'id' }, undefined],
};
const BUCKET_LOOKUP = { kind: 'getBucket', args: ['documents'] };

function accessLog(method: string, status: number): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    method,
    status,
    duration_ms: 0,
    user_id: null,
    level: 'info',
    event: 'request',
  };
}

function rejectedLog(code: string): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    code,
    details: undefined,
    level: 'warn',
    event: 'request_rejected',
  };
}

function degradedLog(checks: Record<string, CheckResult>): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, checks, level: 'warn', event: 'health_degraded' };
}

function headersOf(response: Response): Record<string, string> {
  return Object.fromEntries(response.headers);
}

interface ProbeChain {
  limit(count: number): ProbeChain;
  abortSignal(signal: AbortSignal): PromiseLike<unknown>;
}

interface ProbeClient {
  from(table: string): { select(columns: string, options?: unknown): ProbeChain };
}

/**
 * Keeps the AbortSignal each `from(…).select(…)` chain of [fake] ends with:
 * the shared fake runs the query on `.abortSignal()` but drops the signal.
 */
function recordProbeSignals(fake: FakeClient): AbortSignal[] {
  const signals: AbortSignal[] = [];
  const client = fake.client as unknown as ProbeClient;
  const from = client.from;
  client.from = (table) => {
    const builder = from(table);
    return {
      select: (columns, options) => {
        const chain = builder.select(columns, options);
        const recorded: ProbeChain = {
          limit: (count) => {
            chain.limit(count);
            return recorded;
          },
          abortSignal: (signal) => {
            signals.push(signal);
            return chain.abortSignal(signal);
          },
        };
        return recorded;
      },
    };
  };
  return signals;
}

interface SetupOptions {
  /** The configuration; by default testConfig with HEALTH_CHECK_TOKEN set to [token]. */
  readonly config?: FunctionConfig;
  /** HEALTH_CHECK_TOKEN of the default configuration (TOKEN unless given). */
  readonly token?: string | null | ConfigError;
  /** Answers of the admin client; every dependency is healthy by default. */
  readonly admin?: FakeClientOptions;
  readonly authEndpoint?: AuthEndpoint | null;
  /** Answers the auth service's health request (default: 200 with a JSON body). */
  readonly authFetch?: (url: string, init: RequestInit | undefined) => Promise<Response>;
  /** The platform variables HealthDeps.env answers from. */
  readonly env?: Readonly<Record<string, string>>;
}

function healthyAuth(): Promise<Response> {
  return Promise.resolve(
    new Response('{"name":"GoTrue","version":"v2.180.0"}', {
      headers: { 'content-type': 'application/json' },
    }),
  );
}

function setup(options: SetupOptions = {}) {
  const admin = fakeClient({
    select: () => ({ data: [{ id: PORTFOLIO_ID }], status: 200 }),
    getBucket: () => ({ data: { id: 'documents', name: 'documents', public: false } }),
    ...options.admin,
  });
  const probeSignals = recordProbeSignals(admin);
  const fetched: Array<{ readonly url: string; readonly init: RequestInit | undefined }> = [];
  const authResponses: Response[] = [];
  const envReads: string[] = [];
  let endpointLookups = 0;

  const h = harness({
    config: options.config ??
      testConfig({ healthCheckToken: options.token === undefined ? TOKEN : options.token }),
    context: fakeContext({ user: null, jwtClaims: null, supabaseAdmin: admin }),
  });
  const deps: HealthDeps = {
    ...h.deps,
    fetch: async (input, init) => {
      const url = String(input);
      fetched.push({ url, init });
      const response = await (options.authFetch ?? healthyAuth)(url, init);
      authResponses.push(response);
      return response;
    },
    authEndpoint: () => {
      endpointLookups += 1;
      return options.authEndpoint === undefined ? AUTH : options.authEndpoint;
    },
    env: (name) => {
      envReads.push(name);
      return options.env?.[name];
    },
  };
  const handler = createHealthHandler(deps);

  const send = async (req: Request): Promise<Response> => {
    const now = stub(performance, 'now', () => 1_000);
    try {
      return await handler(req);
    } finally {
      now.restore();
    }
  };
  return {
    admin,
    probeSignals,
    fetched,
    authResponses,
    envReads,
    endpointLookups: () => endpointLookups,
    logs: h.logs,
    contextRequests: h.contextRequests,
    send,
    /** A GET as uptime monitors send it: no Authorization header. */
    get: (path = '/health', headers: Record<string, string> = {}) =>
      send(request({ path, headers, token: null })),
    /** A deep check presenting the right x-health-token. */
    deep: (path = '/health?deep=1') =>
      send(request({ path, headers: { 'x-health-token': TOKEN }, token: null })),
  };
}

/** A configuration read by loadConfig from an environment holding only [token]. */
function configWithToken(token: string): FunctionConfig {
  return loadConfig((name) => (name === 'HEALTH_CHECK_TOKEN' ? token : undefined));
}

// --- liveness ------------------------------------------------------------------------------------

Deno.test('liveness answers 200 { status, service, version, region, time }, "local" off the platform', async (t) => {
  const cases: ReadonlyArray<{
    name: string;
    env: Record<string, string>;
    version: string;
    region: string;
  }> = [
    { name: 'off the platform', env: {}, version: 'local', region: 'local' },
    {
      name: 'deployed',
      env: { DENO_DEPLOYMENT_ID: 'dpl_7f3a', SB_REGION: 'ap-south-1' },
      version: 'dpl_7f3a',
      region: 'ap-south-1',
    },
    {
      name: 'deployment id only',
      env: { DENO_DEPLOYMENT_ID: 'dpl_7f3a' },
      version: 'dpl_7f3a',
      region: 'local',
    },
    {
      name: 'region only',
      env: { SB_REGION: 'eu-central-1' },
      version: 'local',
      region: 'eu-central-1',
    },
  ];
  for (const { name, env, version, region } of cases) {
    await t.step(name, async () => {
      const s = setup({ env });
      const res = await s.get();
      assertEquals(res.status, 200);
      assertEquals(headersOf(res), JSON_HEADERS);
      assertEquals(await res.json(), { ...LIVENESS, version, region });
      assertEquals(s.envReads, ['DENO_DEPLOYMENT_ID', 'SB_REGION']);
      assertEquals(s.contextRequests.map((sent) => sent.auth), ['none']);
      assertEquals(s.logs, [accessLog('GET', 200)]);
      // No dependency is touched.
      assertEquals([s.admin.calls, s.fetched, s.endpointLookups()], [[], [], 0]);
    });
  }
});

Deno.test('HEAD is answered like GET: 200 with the same headers and no body', async () => {
  const get = await setup().get();
  const s = setup();
  const head = await s.send(request({ method: 'HEAD', path: '/health', token: null }));
  assertEquals(head.status, 200);
  assertEquals(headersOf(head), headersOf(get));
  assertEquals(headersOf(head), JSON_HEADERS);
  assertStrictEquals(head.body, null);
  assertEquals(await head.text(), '');
  assertEquals(s.logs, [accessLog('HEAD', 200)]);
  assertEquals([s.admin.calls, s.fetched], [[], []]);
  assertEquals(await get.json(), LIVENESS);
});

Deno.test('any deep value but "1" or "true" is plain liveness: no token read, nothing checked', async (t) => {
  // The token setting is broken: reading it would fail the request with a 500.
  const broken = new ConfigError('HEALTH_CHECK_TOKEN', 'must be at least 32 characters');
  const paths = [
    '/health?deep=0',
    '/health?deep=yes',
    '/health?deep=',
    '/health?deep',
    '/health?deep=TRUE',
    '/health?deep=false',
    '/health?deep=0&deep=1',
    '/health?verbose=1',
  ];
  for (const path of paths) {
    await t.step(path, async () => {
      const s = setup({ token: broken });
      const res = await s.get(path, { 'x-health-token': TOKEN });
      assertEquals(res.status, 200);
      assertEquals(await res.json(), LIVENESS);
      assertEquals([s.admin.calls, s.fetched, s.endpointLookups()], [[], [], 0]);
      assertEquals(s.logs, [accessLog('GET', 200)]);
    });
  }
});

Deno.test('deep=1 and deep=true run the deep check; the first deep parameter decides', async (t) => {
  const paths = [
    '/health?deep=1',
    '/health?deep=true',
    '/health?deep=1&deep=0',
    '/health?verbose=0&deep=true',
  ];
  for (const path of paths) {
    await t.step(path, async () => {
      const s = setup();
      const res = await s.deep(path);
      assertEquals(res.status, 200);
      assertEquals(await res.json(), { ...LIVENESS, checks: ALL_HEALTHY });
      assertEquals(s.admin.calls, [DATABASE_PROBE, BUCKET_LOOKUP]);
      assertEquals(s.fetched.map((sent) => sent.url), [AUTH_HEALTH_URL]);
    });
  }
});

// --- the deep-check token ------------------------------------------------------------------------

Deno.test('deep checks are refused with 403 deep_check_disabled while HEALTH_CHECK_TOKEN is unset', async (t) => {
  const presented: ReadonlyArray<Record<string, string>> = [{}, { 'x-health-token': TOKEN }];
  for (const path of ['/health?deep=1', '/health?deep=true']) {
    for (const headers of presented) {
      await t.step(`${path} ${JSON.stringify(headers)}`, async () => {
        const s = setup({ token: null });
        const res = await s.get(path, headers);
        assertEquals(res.status, 403);
        assertEquals(headersOf(res), JSON_HEADERS);
        assertEquals(await errorOf(res), {
          code: 'deep_check_disabled',
          message: 'Deep health checks are not enabled.',
          request_id: REQUEST_ID,
        });
        assertEquals([s.admin.calls, s.fetched, s.endpointLookups()], [[], [], 0]);
        assertEquals(s.logs, [rejectedLog('deep_check_disabled'), accessLog('GET', 403)]);
      });
    }
  }
});

Deno.test('a HEALTH_CHECK_TOKEN shorter than MIN_TOKEN_LENGTH fails deep checks with 500, unlogged', async () => {
  const short = 's'.repeat(MIN_TOKEN_LENGTH - 1);
  const s = setup({ config: configWithToken(short) });
  const res = await s.get('/health?deep=1', { 'x-health-token': short });
  assertEquals(res.status, 500);
  assertEquals(headersOf(res), JSON_HEADERS);
  assertEquals(await errorOf(res), {
    code: 'server_misconfigured',
    message: 'The service is not configured correctly.',
    details: { variable: 'HEALTH_CHECK_TOKEN' },
    request_id: REQUEST_ID,
  });
  assertEquals([s.admin.calls, s.fetched, s.endpointLookups()], [[], [], 0]);
  assertEquals(s.logs, [
    {
      fn: FN,
      request_id: REQUEST_ID,
      code: 'server_misconfigured',
      error: {
        name: 'ConfigError',
        message: 'HEALTH_CHECK_TOKEN: must be at least 32 characters',
        cause: undefined,
      },
      level: 'error',
      event: 'request_failed',
    },
    accessLog('GET', 500),
  ]);
  assertFalse(logText(s.logs).includes(short));
});

Deno.test('a HEALTH_CHECK_TOKEN of exactly MIN_TOKEN_LENGTH characters enables deep checks', async () => {
  const exact = 'e'.repeat(MIN_TOKEN_LENGTH);
  const s = setup({ config: configWithToken(exact) });
  const res = await s.get('/health?deep=1', { 'x-health-token': exact });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ...LIVENESS, checks: ALL_HEALTHY });
});

Deno.test('a missing or wrong x-health-token gets 401 with a Bearer challenge before any check', async (t) => {
  const cases: ReadonlyArray<{ name: string; headers: Record<string, string>; bearer?: string }> = [
    { name: 'no x-health-token', headers: {} },
    { name: 'an empty token', headers: { 'x-health-token': '' } },
    { name: 'a wrong token', headers: { 'x-health-token': 'not-the-health-token' } },
    { name: 'one character short', headers: { 'x-health-token': TOKEN.slice(0, -1) } },
    { name: 'one character too many', headers: { 'x-health-token': `${TOKEN}h` } },
    { name: 'in another case', headers: { 'x-health-token': TOKEN.toUpperCase() } },
    { name: 'sent as a bearer token instead', headers: {}, bearer: TOKEN },
  ];
  for (const { name, headers, bearer } of cases) {
    await t.step(name, async () => {
      const s = setup();
      const res = await s.send(request({ path: '/health?deep=1', headers, token: bearer ?? null }));
      assertEquals(res.status, 401);
      assertEquals(headersOf(res), { ...JSON_HEADERS, 'www-authenticate': 'Bearer' });
      assertEquals(await errorOf(res), {
        code: 'unauthorized',
        message: 'A valid health check token is required.',
        request_id: REQUEST_ID,
      });
      assertEquals([s.admin.calls, s.fetched, s.endpointLookups()], [[], [], 0]);
      assertEquals(s.logs, [rejectedLog('unauthorized'), accessLog('GET', 401)]);
      for (const secret of [TOKEN, ...Object.values(headers)].filter((value) => value !== '')) {
        assertFalse(logText(s.logs).includes(secret));
      }
    });
  }
});

// --- the checks ----------------------------------------------------------------------------------

Deno.test('with the right token and every dependency up, the deep check answers 200 "ok"', async () => {
  const s = setup({ env: { DENO_DEPLOYMENT_ID: 'dpl_7f3a', SB_REGION: 'ap-south-1' } });
  const res = await s.deep();
  assertEquals(res.status, 200);
  assertEquals(headersOf(res), JSON_HEADERS);
  assertEquals(await res.json(), {
    ...LIVENESS,
    version: 'dpl_7f3a',
    region: 'ap-south-1',
    checks: ALL_HEALTHY,
  });
  // The database reads one portfolio id and storage looks up the documents bucket ...
  assertEquals(s.admin.calls, [DATABASE_PROBE, BUCKET_LOOKUP]);
  // ... and auth is asked for its health with the publishable key only.
  assertEquals(s.endpointLookups(), 1);
  assertEquals(s.fetched.length, 1);
  const auth = s.fetched[0];
  assertEquals(auth?.url, AUTH_HEALTH_URL);
  assertEquals(Object.keys(auth?.init ?? {}), ['headers', 'signal']);
  assertEquals(auth?.init?.headers, { apikey: 'sb_publishable_test' });
  assertInstanceOf(auth?.init?.signal, AbortSignal);
  // The auth service's answer is released, not read.
  assert(s.authResponses[0]?.bodyUsed);
  assertEquals(s.contextRequests.map((sent) => sent.auth), ['none']);
  assertEquals(s.logs, [accessLog('GET', 200)]);
});

Deno.test('each check runs under its own CHECK_TIMEOUT_MS signal, bound to the query and the request', async () => {
  const controllers: AbortController[] = [];
  const timeout = stub(AbortSignal, 'timeout', () => {
    const controller = new AbortController();
    controllers.push(controller);
    return controller.signal;
  });
  try {
    const s = setup();
    const res = await s.deep();
    assertEquals(await res.json(), { ...LIVENESS, checks: ALL_HEALTHY });
    assertEquals(timeout.calls.map((call) => call.args), [
      [CHECK_TIMEOUT_MS],
      [CHECK_TIMEOUT_MS],
      [CHECK_TIMEOUT_MS],
    ]);
    // Database, storage, auth: the database query is cut off by the first signal ...
    assertEquals(s.admin.calls[0], DATABASE_PROBE);
    assertEquals(s.probeSignals.length, 1);
    assertStrictEquals(s.probeSignals[0], controllers[0]?.signal);
    // ... and the auth request by the third.
    assertStrictEquals(s.fetched[0]?.init?.signal, controllers[2]?.signal);
  } finally {
    timeout.restore();
  }
});

Deno.test('the database check passes on 200 and 206 only, and otherwise names the code or status', async (t) => {
  const cases: ReadonlyArray<{ name: string; answer: Result; check: CheckResult }> = [
    {
      name: '200 with a row',
      answer: { data: [{ id: PORTFOLIO_ID }], status: 200 },
      check: HEALTHY,
    },
    { name: '200 with no rows', answer: { data: [], status: 200 }, check: HEALTHY },
    {
      name: '206 partial content',
      answer: { data: [{ id: PORTFOLIO_ID }], status: 206 },
      check: HEALTHY,
    },
    {
      name: '404 without an error',
      answer: { data: null, status: 404 },
      check: failed('database: HTTP 404'),
    },
    {
      name: '204 without content',
      answer: { data: null, status: 204 },
      check: failed('database: HTTP 204'),
    },
    {
      name: '503 without an error',
      answer: { data: null, status: 503 },
      check: failed('database: HTTP 503'),
    },
    {
      name: 'a PostgREST error',
      answer: {
        error: { code: 'PGRST205', message: "Could not find the table 'public.portfolios'" },
        status: 404,
      },
      check: failed('database: PGRST205'),
    },
    {
      name: 'a Postgres error',
      answer: { error: { code: '57P01', message: 'terminating connection' }, status: 503 },
      check: failed('database: 57P01'),
    },
    {
      name: 'an error that came with a 200',
      answer: { error: { code: '42501', message: 'permission denied' }, status: 200 },
      check: failed('database: 42501'),
    },
    {
      name: 'an error without a code',
      answer: { error: { message: 'upstream connect error' }, status: 502 },
      check: failed('database: error'),
    },
    {
      name: 'an error with a null code',
      answer: { error: { code: null, message: 'no code' }, status: 500 },
      check: failed('database: error'),
    },
  ];
  for (const { name, answer, check } of cases) {
    await t.step(name, async () => {
      const s = setup({ admin: { select: () => answer } });
      const res = await s.deep();
      assertEquals(res.status, check.ok ? 200 : 503);
      assertEquals(await res.json(), {
        ...LIVENESS,
        status: check.ok ? 'ok' : 'degraded',
        checks: { ...ALL_HEALTHY, database: check },
      });
      assertEquals(s.admin.calls[0], DATABASE_PROBE);
    });
  }
});

Deno.test('a database the API cannot reach (postgrest-js: empty code, status 0) fails its check', async () => {
  const s = setup({
    admin: {
      select: () => ({
        error: { code: '', message: 'TypeError: error sending request', details: '', hint: '' },
        status: 0,
      }),
    },
  });
  const res = await s.deep();
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals([body.status, body.checks.database.ok], ['degraded', false]);
  // Only the prefix is pinned: the empty code leaves nothing after it yet.
  assertMatch(body.checks.database.error, /^database: /);
});

Deno.test('the storage check looks up the documents bucket and fails when it is unavailable', async (t) => {
  const cases: ReadonlyArray<{
    name: string;
    getBucket: NonNullable<FakeClientOptions['getBucket']>;
    check: CheckResult;
  }> = [
    { name: 'the bucket exists', getBucket: () => ({ data: { id: 'documents' } }), check: HEALTHY },
    {
      name: 'the bucket is missing',
      getBucket: () => ({
        error: { name: 'StorageApiError', message: 'Bucket not found' },
        status: 404,
      }),
      check: failed('storage: bucket unavailable'),
    },
    {
      name: 'storage is down',
      getBucket: () => ({ error: { message: 'fetch failed' }, status: 0 }),
      check: failed('storage: bucket unavailable'),
    },
    {
      name: 'the client throws',
      getBucket: () => Promise.reject(new TypeError('network unreachable')),
      check: failed('network unreachable'),
    },
  ];
  for (const { name, getBucket, check } of cases) {
    await t.step(name, async () => {
      const s = setup({ admin: { getBucket } });
      const res = await s.deep();
      assertEquals(res.status, check.ok ? 200 : 503);
      assertEquals((await res.json()).checks, { ...ALL_HEALTHY, storage: check });
      assertEquals(s.admin.calls[1], BUCKET_LOOKUP);
    });
  }
});

Deno.test('the auth check sends GET <url>/auth/v1/health with the publishable key and needs a 2xx', async (t) => {
  const local: AuthEndpoint = {
    url: 'http://127.0.0.1:54321',
    publishableKey: 'sb_publishable_local',
  };
  const cases: ReadonlyArray<{
    name: string;
    endpoint?: AuthEndpoint | null;
    respond?: () => Promise<Response>;
    check: CheckResult;
    /** Whether the answer has a body, which must then be released. */
    body?: boolean;
  }> = [
    { name: '200 with a body', check: HEALTHY, body: true },
    {
      name: '204 without a body',
      respond: () => Promise.resolve(new Response(null, { status: 204 })),
      check: HEALTHY,
      body: false,
    },
    {
      name: 'the local stack',
      endpoint: local,
      respond: () => Promise.resolve(new Response('{}')),
      check: HEALTHY,
      body: true,
    },
    {
      name: '503',
      respond: () => Promise.resolve(new Response('upstream unavailable', { status: 503 })),
      check: failed('auth: HTTP 503'),
      body: true,
    },
    {
      name: '401 (the key is refused)',
      respond: () =>
        Promise.resolve(new Response('{"message":"Invalid API key"}', { status: 401 })),
      check: failed('auth: HTTP 401'),
      body: true,
    },
    {
      name: 'connection refused',
      respond: () => Promise.reject(new TypeError('error sending request: connection refused')),
      check: failed('error sending request: connection refused'),
    },
    {
      name: 'a rejection that is not an Error',
      respond: () => Promise.reject('offline'),
      check: failed('failed'),
    },
    { name: 'no endpoint', endpoint: null, check: failed('auth: endpoint not configured') },
  ];
  for (const { name, endpoint, respond, check, body } of cases) {
    await t.step(name, async () => {
      const s = setup({ authEndpoint: endpoint, authFetch: respond });
      const res = await s.deep();
      assertEquals(res.status, check.ok ? 200 : 503);
      assertEquals((await res.json()).checks, { ...ALL_HEALTHY, auth: check });
      assertEquals(s.endpointLookups(), 1);
      const target = endpoint === undefined ? AUTH : endpoint;
      assertEquals(
        s.fetched.map((sent) => [sent.url, sent.init?.headers]),
        target === null
          ? []
          : [[`${target.url}/auth/v1/health`, { apikey: target.publishableKey }]],
      );
      if (body !== undefined) assertEquals(s.authResponses[0]?.bodyUsed, body);
    });
  }
});

Deno.test('any failing check answers 503 "degraded" and logs health_degraded with every result', async (t) => {
  const cases: ReadonlyArray<{
    name: string;
    options: SetupOptions;
    checks: Record<string, CheckResult>;
  }> = [
    {
      name: 'database',
      options: { admin: { select: () => ({ data: null, status: 404 }) } },
      checks: { ...ALL_HEALTHY, database: failed('database: HTTP 404') },
    },
    {
      name: 'storage',
      options: { admin: { getBucket: () => ({ error: { message: 'Bucket not found' } }) } },
      checks: { ...ALL_HEALTHY, storage: failed('storage: bucket unavailable') },
    },
    {
      name: 'auth',
      options: { authEndpoint: null },
      checks: { ...ALL_HEALTHY, auth: failed('auth: endpoint not configured') },
    },
    {
      name: 'all three',
      options: {
        admin: {
          select: () => ({ error: { code: '57P01', message: 'terminating connection' } }),
          getBucket: () => ({ error: { message: 'Bucket not found' } }),
        },
        authFetch: () => Promise.resolve(new Response(null, { status: 502 })),
      },
      checks: {
        database: failed('database: 57P01'),
        storage: failed('storage: bucket unavailable'),
        auth: failed('auth: HTTP 502'),
      },
    },
  ];
  for (const { name, options, checks } of cases) {
    await t.step(name, async () => {
      const s = setup(options);
      const res = await s.deep();
      assertEquals(res.status, 503);
      assertEquals(headersOf(res), JSON_HEADERS);
      assertEquals(await res.json(), { ...LIVENESS, status: 'degraded', checks });
      assertEquals(s.logs, [degradedLog(checks), accessLog('GET', 503)]);
    });
  }
});

Deno.test('a dependency still silent when its budget runs out fails as "timeout"; the others report', async (t) => {
  const names = ['database', 'storage', 'auth'] as const;
  for (const [index, name] of names.entries()) {
    await t.step(name, async () => {
      const controllers: AbortController[] = [];
      const timeout = stub(AbortSignal, 'timeout', () => {
        const controller = new AbortController();
        controllers.push(controller);
        return controller.signal;
      });
      // Never answers; its budget runs out as soon as the checks are under way.
      const silent = (): Promise<never> => {
        queueMicrotask(() => controllers[index]?.abort());
        return new Promise<never>(() => {});
      };
      const options: Record<typeof name, SetupOptions> = {
        database: { admin: { select: silent } },
        storage: { admin: { getBucket: silent } },
        auth: { authFetch: silent },
      };
      try {
        const s = setup(options[name]);
        const res = await s.deep();
        assertEquals(res.status, 503);
        assertEquals(await res.json(), {
          ...LIVENESS,
          status: 'degraded',
          checks: { ...ALL_HEALTHY, [name]: failed('timeout') },
        });
      } finally {
        timeout.restore();
      }
    });
  }
});

Deno.test('the three checks run concurrently: each starts before any of them finishes', async () => {
  const started = new Set<string>();
  const everyoneStarted = Promise.withResolvers<void>();
  const begin = async (name: string): Promise<void> => {
    started.add(name);
    if (started.size === 3) everyoneStarted.resolve();
    await everyoneStarted.promise;
  };
  const s = setup({
    admin: {
      select: async () => {
        await begin('database');
        return { data: [], status: 200 };
      },
      getBucket: async () => {
        await begin('storage');
        return { data: { id: 'documents' } };
      },
    },
    authFetch: async () => {
      await begin('auth');
      return new Response(null);
    },
  });
  const res = await s.deep();
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ...LIVENESS, checks: ALL_HEALTHY });
});

// --- methods -------------------------------------------------------------------------------------

Deno.test('health serves GET and HEAD only: other methods get 405 with Allow, preflights list them', async (t) => {
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
    await t.step(method, async () => {
      const s = setup();
      const res = await s.send(
        request({
          method,
          path: '/health?deep=1',
          headers: { 'x-health-token': TOKEN },
          token: null,
        }),
      );
      assertEquals(res.status, 405);
      assertEquals(headersOf(res), { ...JSON_HEADERS, allow: 'GET, HEAD, OPTIONS' });
      assertEquals(await errorOf(res), {
        code: 'method_not_allowed',
        message: 'Use GET or HEAD.',
        request_id: REQUEST_ID,
      });
      assertEquals([s.contextRequests, s.admin.calls, s.fetched], [[], [], []]);
      assertEquals(s.logs, [rejectedLog('method_not_allowed'), accessLog(method, 405)]);
    });
  }

  await t.step('OPTIONS preflight from the app', async () => {
    const s = setup();
    const res = await s.send(request({
      method: 'OPTIONS',
      path: '/health?deep=1',
      origin: APP_ORIGIN,
      token: null,
      headers: {
        'access-control-request-method': 'GET',
        'access-control-request-headers': 'x-health-token',
      },
    }));
    assertEquals(res.status, 204);
    assertEquals(headersOf(res), {
      ...SECURITY,
      'access-control-allow-headers':
        'authorization, apikey, content-type, x-client-info, x-region, x-health-token',
      'access-control-allow-methods': 'GET, HEAD, OPTIONS',
      'access-control-allow-origin': APP_ORIGIN,
      'access-control-expose-headers': 'x-request-id, retry-after',
      'access-control-max-age': '86400',
      vary: 'Origin',
      'x-request-id': REQUEST_ID,
    });
    assertEquals([s.contextRequests, s.admin.calls, s.fetched], [[], [], []]);
    assertEquals(s.logs, [accessLog('OPTIONS', 204)]);
  });
});

// --- runCheck ------------------------------------------------------------------------------------

Deno.test('runCheck reports a passing check with its latency on the monotonic clock, rounded', async () => {
  const now = stub(performance, 'now', returnsNext([100, 142.5]));
  try {
    assertEquals(await runCheck(() => Promise.resolve()), { ok: true, latency_ms: 43 });
  } finally {
    now.restore();
  }
});

Deno.test('runCheck never throws: a failure is reported by its Error message, else as "failed"', async (t) => {
  const cases: ReadonlyArray<{
    name: string;
    check: (signal: AbortSignal) => Promise<void>;
    error: string;
  }> = [
    {
      name: 'an Error',
      check: () => Promise.reject(new Error('database: 42P01')),
      error: 'database: 42P01',
    },
    {
      name: 'a TypeError from fetch',
      check: () => Promise.reject(new TypeError('error sending request')),
      error: 'error sending request',
    },
    {
      name: 'an AbortError',
      check: () => Promise.reject(new DOMException('The signal has been aborted', 'AbortError')),
      error: 'The signal has been aborted',
    },
    {
      name: 'a synchronous throw',
      check: () => {
        throw new Error('thrown before any await');
      },
      error: 'thrown before any await',
    },
    { name: 'a string', check: () => Promise.reject('offline'), error: 'failed' },
    { name: 'undefined', check: () => Promise.reject(undefined), error: 'failed' },
    {
      name: 'an error-like object',
      check: () => Promise.reject({ message: 'not an Error' }),
      error: 'failed',
    },
  ];
  for (const { name, check, error } of cases) {
    await t.step(name, async () => {
      const now = stub(performance, 'now', returnsNext([100, 112.4]));
      try {
        assertEquals(await runCheck(check), { ok: false, latency_ms: 12, error });
      } finally {
        now.restore();
      }
    });
  }
});

Deno.test('runCheck gives up after a tiny timeoutMs: "timeout", with the check’s signal aborted', async () => {
  const signals: AbortSignal[] = [];
  const now = stub(performance, 'now', () => 1_000);
  try {
    const result = await runCheck((signal) => {
      signals.push(signal);
      return new Promise<void>(() => {});
    }, 1);
    assertEquals(result, { ok: false, latency_ms: 0, error: 'timeout' });
  } finally {
    now.restore();
  }
  const [signal] = signals;
  assertExists(signal);
  assert(signal.aborted);
  assertInstanceOf(signal.reason, DOMException);
  assertEquals(signal.reason.name, 'TimeoutError');
});

Deno.test('runCheck answers "timeout" as soon as its signal aborts, with the latency so far', async () => {
  const controller = new AbortController();
  const timeout = stub(AbortSignal, 'timeout', () => controller.signal);
  const now = stub(performance, 'now', returnsNext([100, 3_100]));
  try {
    const pending = runCheck(() => new Promise<void>(() => {}));
    controller.abort();
    assertEquals(await pending, { ok: false, latency_ms: 3_000, error: 'timeout' });
  } finally {
    now.restore();
    timeout.restore();
  }
});

Deno.test('runCheck budgets CHECK_TIMEOUT_MS (3 s) unless told otherwise and hands the check that signal', async () => {
  const issued: AbortSignal[] = [];
  const timeout = stub(AbortSignal, 'timeout', () => {
    const signal = new AbortController().signal;
    issued.push(signal);
    return signal;
  });
  const received: AbortSignal[] = [];
  const check = (signal: AbortSignal): Promise<void> => {
    received.push(signal);
    return Promise.resolve();
  };
  try {
    assertEquals((await runCheck(check)).ok, true);
    assertEquals((await runCheck(check, 250)).ok, true);
  } finally {
    timeout.restore();
  }
  assertEquals(CHECK_TIMEOUT_MS, 3_000);
  assertEquals(timeout.calls.map((call) => call.args), [[CHECK_TIMEOUT_MS], [250]]);
  assertEquals(received.length, 2);
  assertStrictEquals(received[0], issued[0]);
  assertStrictEquals(received[1], issued[1]);
});

// --- wiring --------------------------------------------------------------------------------------

Deno.test('authEndpointFromEnv takes the project URL and the default publishable key, or gives null', async (t) => {
  const cases: ReadonlyArray<{
    name: string;
    env: Record<string, string>;
    endpoint: AuthEndpoint | null;
  }> = [
    { name: 'nothing provisioned', env: {}, endpoint: null },
    { name: 'a project URL without keys', env: { SUPABASE_URL: PROJECT_URL }, endpoint: null },
    {
      name: 'keys without a project URL',
      env: { SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_live"}' },
      endpoint: null,
    },
    {
      name: 'the platform key map',
      env: {
        SUPABASE_URL: PROJECT_URL,
        SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_live","web":"sb_publishable_web"}',
      },
      endpoint: { url: PROJECT_URL, publishableKey: 'sb_publishable_live' },
    },
    {
      name: 'a key map without a default key',
      env: { SUPABASE_URL: PROJECT_URL, SUPABASE_PUBLISHABLE_KEYS: '{"web":"sb_publishable_web"}' },
      endpoint: null,
    },
    {
      name: 'a single publishable key (the CLI)',
      env: {
        SUPABASE_URL: 'http://127.0.0.1:54321',
        SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_local',
      },
      endpoint: { url: 'http://127.0.0.1:54321', publishableKey: 'sb_publishable_local' },
    },
    {
      name: 'a secret key only: never sent to the auth endpoint',
      env: { SUPABASE_URL: PROJECT_URL, SUPABASE_SECRET_KEYS: '{"default":"sb_secret_live"}' },
      endpoint: null,
    },
  ];
  for (const { name, env, endpoint } of cases) {
    await t.step(name, () => {
      const get = stub(Deno.env, 'get', (key: string) => env[key]);
      try {
        assertEquals(authEndpointFromEnv(), endpoint);
      } finally {
        get.restore();
      }
    });
  }
});

Deno.test('defaultHealthDeps: the default pipeline, the platform endpoint, Deno.env and global fetch', async () => {
  for (const key of Object.keys(defaultDeps) as Array<keyof typeof defaultDeps>) {
    assertStrictEquals(defaultHealthDeps[key], defaultDeps[key], key);
  }
  assertStrictEquals(defaultHealthDeps.authEndpoint, authEndpointFromEnv);

  const env = stub(
    Deno.env,
    'get',
    (name: string) => (name === 'SB_REGION' ? 'eu-central-1' : undefined),
  );
  try {
    assertEquals(
      [defaultHealthDeps.env('SB_REGION'), defaultHealthDeps.env('DENO_DEPLOYMENT_ID')],
      ['eu-central-1', undefined],
    );
    assertEquals(env.calls.map((call) => call.args), [['SB_REGION'], ['DENO_DEPLOYMENT_ID']]);
  } finally {
    env.restore();
  }

  const answer = new Response(null, { status: 204 });
  const globalFetch = stub(globalThis, 'fetch', () => Promise.resolve(answer));
  try {
    const init: RequestInit = {
      headers: { apikey: 'sb_publishable_test' },
      signal: new AbortController().signal,
    };
    assertStrictEquals(await defaultHealthDeps.fetch(AUTH_HEALTH_URL, init), answer);
    assertEquals(globalFetch.calls.length, 1);
    assertStrictEquals(globalFetch.calls[0]?.args[0], AUTH_HEALTH_URL);
    assertStrictEquals(globalFetch.calls[0]?.args[1], init);
  } finally {
    globalFetch.restore();
  }
});

Deno.test('index.ts serves liveness on the default deps: platform env, random request id, console', async () => {
  assertEquals(Object.keys(server), ['fetch']);
  const values: Record<string, string> = {
    SUPABASE_URL: 'http://127.0.0.1:54321',
    SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_test"}',
    SUPABASE_SECRET_KEYS: '{"default":"sb_secret_test"}',
    DENO_DEPLOYMENT_ID: 'dpl_index',
    SB_REGION: 'me-central-1',
  };
  const env = stub(Deno.env, 'get', (name: string) => values[name]);
  const lines: string[] = [];
  const log = stub(console, 'log', (line: string) => void lines.push(line));
  const now = stub(performance, 'now', () => 1_000);
  try {
    const res = await server.fetch(request({ path: '/health', token: null }));
    assertEquals(res.status, 200);
    const requestId = res.headers.get('x-request-id') ?? '';
    assertMatch(requestId, UUID_V4);
    const { time, ...body } = await res.json();
    assertEquals(body, {
      status: 'ok',
      service: 'maalik-e-makaan',
      version: 'dpl_index',
      region: 'me-central-1',
    });
    assertEquals(new Date(time).toISOString(), time);
    assertEquals(lines.map((line) => JSON.parse(line)), [
      { ...accessLog('GET', 200), request_id: requestId },
    ]);
    const names = env.calls.map((call) => call.args[0]);
    assert(names.includes('DENO_DEPLOYMENT_ID') && names.includes('SB_REGION'));
    // Liveness never reads the deep-check secret.
    assertFalse(names.includes('HEALTH_CHECK_TOKEN'));
  } finally {
    now.restore();
    log.restore();
    env.restore();
  }
});
