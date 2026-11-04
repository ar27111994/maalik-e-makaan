import { assertEquals, assertGreaterOrEqual } from '@std/assert';
import {
  type AuthEndpoint,
  authEndpointFromEnv,
  createHealthHandler,
  defaultHealthDeps,
  type HealthDeps,
  runCheck,
  SERVICE,
} from '../health/handler.ts';
import {
  errorOf,
  fakeClient,
  type FakeClientOptions,
  fakeContext,
  harness,
  NOW,
  request,
  testConfig,
} from './_helpers.ts';

const TOKEN = 'h'.repeat(40);
const AUTH: AuthEndpoint = {
  url: 'https://project.supabase.co',
  publishableKey: 'sb_publishable_x',
};

function setup(options: {
  token?: string | null;
  admin?: FakeClientOptions;
  authEndpoint?: AuthEndpoint | null;
  authResponse?: () => Promise<Response>;
  env?: Record<string, string>;
} = {}) {
  const admin = fakeClient({
    select: () => ({ data: null }),
    getBucket: () => ({ data: { id: 'documents' } }),
    ...options.admin,
  });
  const fetched: Array<{ url: string; init: RequestInit | undefined }> = [];
  const base = harness({
    config: testConfig({ healthCheckToken: options.token === undefined ? TOKEN : options.token }),
    context: fakeContext({ user: null, supabaseAdmin: admin }),
  });
  const deps: HealthDeps = {
    ...base.deps,
    fetch: (input, init) => {
      fetched.push({ url: String(input), init });
      return options.authResponse?.() ?? Promise.resolve(new Response('{}', { status: 200 }));
    },
    authEndpoint: () => options.authEndpoint === undefined ? AUTH : options.authEndpoint,
    env: (name) => options.env?.[name],
  };
  const handler = createHealthHandler(deps);
  return {
    admin,
    fetched,
    logs: base.logs,
    get: (path = '/health', headers: Record<string, string> = {}) =>
      handler(request({ method: 'GET', path, headers })),
  };
}

Deno.test('liveness answers without touching any dependency', async () => {
  const t = setup({ env: { DENO_DEPLOYMENT_ID: 'ref_fn_7', SB_REGION: 'ap-south-1' } });
  const res = await t.get();
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    status: 'ok',
    service: SERVICE,
    version: 'ref_fn_7',
    region: 'ap-south-1',
    time: NOW.toISOString(),
  });
  assertEquals(t.admin.calls.length, 0);
  assertEquals(t.fetched.length, 0);
  assertEquals(res.headers.get('cache-control'), 'no-store');
});

Deno.test('liveness reports local defaults outside the platform', async () => {
  const body = await (await setup().get()).json();
  assertEquals([body.version, body.region], ['local', 'local']);
});

Deno.test('deep checks are disabled without a configured token', async () => {
  const res = await setup({ token: null }).get('/health?deep=1', { 'x-health-token': TOKEN });
  assertEquals([res.status, (await errorOf(res)).code], [403, 'deep_check_disabled']);
});

Deno.test('deep checks need the right token', async () => {
  const attempts: Array<Record<string, string>> = [
    {},
    { 'x-health-token': 'wrong' },
    { 'x-health-token': `${TOKEN}x` },
  ];
  for (const headers of attempts) {
    const t = setup();
    const res = await t.get('/health?deep=true', headers);
    assertEquals([res.status, (await errorOf(res)).code], [401, 'unauthorized']);
    assertEquals(t.admin.calls.length, 0);
  }
});

Deno.test('a healthy deep check reports every dependency', async () => {
  const t = setup();
  const res = await t.get('/health?deep=1', { 'x-health-token': TOKEN });
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.status, 'ok');
  assertEquals(Object.keys(body.checks), ['database', 'storage', 'auth']);
  for (const check of Object.values(body.checks) as Array<{ ok: boolean; latency_ms: number }>) {
    assertEquals(check.ok, true);
    assertGreaterOrEqual(check.latency_ms, 0);
  }
  assertEquals(t.admin.calls.map((c) => c.kind).sort(), ['getBucket', 'select']);
  assertEquals(t.admin.calls.find((c) => c.kind === 'select')?.args.slice(0, 2), [
    'portfolios',
    'id',
  ]);
  assertEquals(t.fetched[0]?.url, 'https://project.supabase.co/auth/v1/health');
  assertEquals(t.fetched[0]?.init?.headers, { apikey: 'sb_publishable_x' });
});

Deno.test('a failing dependency degrades the check to 503', async () => {
  const cases: Array<[Parameters<typeof setup>[0], string, string]> = [
    [
      { admin: { select: () => ({ error: { code: '57P01', message: 'x' } }) } },
      'database',
      'database: 57P01',
    ],
    [{ admin: { select: () => ({ error: { message: 'x' } }) } }, 'database', 'database: error'],
    [
      { admin: { getBucket: () => ({ error: { message: 'x' } }) } },
      'storage',
      'storage: bucket unavailable',
    ],
    [{ authEndpoint: null }, 'auth', 'auth: endpoint not configured'],
    [
      { authResponse: () => Promise.resolve(new Response('down', { status: 503 })) },
      'auth',
      'auth: HTTP 503',
    ],
    [
      { authResponse: () => Promise.reject(new TypeError('connection refused')) },
      'auth',
      'connection refused',
    ],
  ];
  for (const [options, name, message] of cases) {
    const t = setup(options);
    const res = await t.get('/health?deep=1', { 'x-health-token': TOKEN });
    assertEquals(res.status, 503, name);
    const body = await res.json();
    assertEquals(body.status, 'degraded');
    assertEquals([body.checks[name].ok, body.checks[name].error], [false, message]);
    assertEquals(t.logs.find((r) => r.event === 'health_degraded')?.level, 'warn');
  }
});

Deno.test('runCheck times out hanging checks', async () => {
  const result = await runCheck(() => new Promise(() => {}), 10);
  assertEquals([result.ok, result.error], [false, 'timeout']);
});

Deno.test('runCheck describes non-Error failures generically', async () => {
  const result = await runCheck(() => Promise.reject('nope'));
  assertEquals([result.ok, result.error], [false, 'failed']);
  const ok = await runCheck(() => Promise.resolve());
  assertEquals(ok.ok, true);
});

Deno.test('authEndpointFromEnv resolves the platform variables', () => {
  const keys = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_PUBLISHABLE_KEY'];
  const previous = Object.fromEntries(keys.map((key) => [key, Deno.env.get(key)]));
  const restore = () => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  };
  try {
    for (const key of keys) Deno.env.delete(key);
    assertEquals(authEndpointFromEnv(), null, 'no project URL');

    Deno.env.set('SUPABASE_URL', 'https://project.supabase.co');
    assertEquals(authEndpointFromEnv(), null, 'no publishable key');

    Deno.env.set('SUPABASE_PUBLISHABLE_KEYS', '{"default":"sb_publishable_live"}');
    assertEquals(authEndpointFromEnv(), {
      url: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_live',
    });
  } finally {
    restore();
  }
});

Deno.test('the default dependencies read the environment and use real fetch', async () => {
  Deno.env.set('MM_HEALTH_TEST', 'yes');
  try {
    assertEquals(defaultHealthDeps.env('MM_HEALTH_TEST'), 'yes');
  } finally {
    Deno.env.delete('MM_HEALTH_TEST');
  }

  const server = Deno.serve(
    { hostname: '127.0.0.1', port: 0, onListen: () => {} },
    () => new Response('pong'),
  );
  try {
    const response = await defaultHealthDeps.fetch(`http://127.0.0.1:${server.addr.port}/`);
    assertEquals(await response.text(), 'pong');
  } finally {
    await server.shutdown();
  }

  const { default: fn } = await import('../health/index.ts');
  assertEquals(typeof fn.fetch, 'function');
});
