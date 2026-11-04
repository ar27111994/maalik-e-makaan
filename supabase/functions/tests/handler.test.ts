import { assert, assertEquals, assertMatch, assertThrows } from '@std/assert';
import { ConfigError } from '../_shared/config.ts';
import { HttpError } from '../_shared/errors.ts';
import {
  createHandler,
  defaultDeps,
  type FunctionSpec,
  type RequestContext,
  requireUser,
} from '../_shared/handler.ts';
import { json } from '../_shared/http.ts';
import {
  APP_ORIGIN,
  errorOf,
  fakeContext,
  harness,
  NOW,
  request,
  REQUEST_ID,
  testConfig,
  USER_ID,
} from './_helpers.ts';

function spec(
  handle: FunctionSpec['handle'],
  methods: FunctionSpec['methods'] = ['GET', 'POST'],
): FunctionSpec {
  return { name: 'test-fn', methods, auth: 'user', handle };
}

const ok = () => Promise.resolve(json({ ok: true }));

Deno.test('a successful request gets CORS, security headers, a request id and an access log', async () => {
  const h = harness();
  let seen: RequestContext | undefined;
  const handler = createHandler(
    spec((ctx) => {
      seen = ctx;
      return ok();
    }),
    h.deps,
  );

  const response = await handler(request({ origin: APP_ORIGIN }));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { ok: true });
  assertEquals(response.headers.get('x-request-id'), REQUEST_ID);
  assertEquals(response.headers.get('access-control-allow-origin'), APP_ORIGIN);
  assertEquals(response.headers.get('vary'), 'Origin');
  assertEquals(response.headers.get('cache-control'), 'no-store');

  assertEquals(seen?.requestId, REQUEST_ID);
  assertEquals(seen?.now(), NOW);
  assertEquals(seen?.config, testConfig());
  assertEquals(h.contextRequests.map((entry) => entry.auth), ['user']);

  const access = h.logs.at(-1);
  assertEquals(access?.event, 'request');
  assertEquals(access?.['fn'], 'test-fn');
  assertEquals(access?.['status'], 200);
  assertEquals(access?.['user_id'], USER_ID);
  assertEquals(typeof access?.['duration_ms'], 'number');
});

Deno.test('callers without an Origin header (mobile apps, servers) are served', async () => {
  const response = await createHandler(spec(ok), harness().deps)(request());
  assertEquals(response.status, 200);
  assertEquals(response.headers.get('access-control-allow-origin'), null);
});

Deno.test('a preflight from an allowed origin is answered without authentication', async () => {
  const h = harness();
  const response = await createHandler(spec(ok), h.deps)(
    request({ method: 'OPTIONS', origin: APP_ORIGIN }),
  );
  assertEquals(response.status, 204);
  assertEquals(response.headers.get('access-control-allow-methods'), 'GET, POST, OPTIONS');
  assertEquals(response.headers.get('x-request-id'), REQUEST_ID);
  assertEquals(h.contextRequests.length, 0);
});

Deno.test('requests from unknown browser origins are refused, preflight or not', async () => {
  for (const method of ['OPTIONS', 'POST']) {
    const h = harness();
    const response = await createHandler(spec(ok), h.deps)(
      request({ method, origin: 'https://evil.example', body: method === 'POST' ? {} : undefined }),
    );
    assertEquals(response.status, 403);
    assertEquals((await errorOf(response)).code, 'origin_not_allowed');
    assertEquals(response.headers.get('access-control-allow-origin'), null);
    assertEquals(h.contextRequests.length, 0);
  }
});

Deno.test('unsupported methods get 405 with an Allow header', async () => {
  const response = await createHandler(spec(ok, ['POST']), harness().deps)(
    request({ method: 'DELETE' }),
  );
  assertEquals(response.status, 405);
  assertEquals(response.headers.get('allow'), 'POST, OPTIONS');
  assertEquals((await errorOf(response)).code, 'method_not_allowed');
});

Deno.test('a bad secret is reported as a misconfiguration, naming only the variable', async () => {
  const h = harness({
    config: () => {
      throw new ConfigError('MAIL_FROM', 'is required');
    },
  });
  const response = await createHandler(spec(ok), h.deps)(request());
  assertEquals(response.status, 500);
  const error = await errorOf(response);
  assertEquals([error.code, error.details], ['server_misconfigured', { variable: 'MAIL_FROM' }]);
  assertEquals(h.logs.find((record) => record.event === 'request_failed')?.level, 'error');
});

Deno.test('authentication failures become 401s, or 500s when the server is at fault', async () => {
  const unauthorized = harness({
    context: { data: null, error: { status: 401, code: 'MISSING_CREDENTIALS', message: 'm' } },
  });
  const denied = await createHandler(spec(ok), unauthorized.deps)(request());
  assertEquals(denied.status, 401);
  assertEquals((await errorOf(denied)).details, { reason: 'MISSING_CREDENTIALS' });
  assertEquals(
    unauthorized.logs.find((record) => record.event === 'request_rejected')?.level,
    'warn',
  );

  const broken = harness({
    context: { data: null, error: { status: 500, code: 'JWKS_NOT_CONFIGURED', message: 'm' } },
  });
  const failed = await createHandler(spec(ok), broken.deps)(request());
  assertEquals(failed.status, 500);
  assertEquals((await errorOf(failed)).code, 'server_misconfigured');
});

Deno.test('HttpErrors thrown by handlers keep their status, code and headers', async () => {
  const handler = createHandler(
    spec(() => {
      throw new HttpError(429, 'rate_limited', 'Slow down.', { headers: { 'retry-after': '60' } });
    }),
    harness().deps,
  );
  const response = await handler(request({ origin: APP_ORIGIN }));
  assertEquals(response.status, 429);
  assertEquals(response.headers.get('retry-after'), '60');
  assertEquals(response.headers.get('access-control-allow-origin'), APP_ORIGIN);
  const error = await errorOf(response);
  assertEquals([error.code, error.request_id], ['rate_limited', REQUEST_ID]);
});

Deno.test('unexpected errors become a generic 500 and are logged without secrets', async () => {
  const h = harness();
  const handler = createHandler(
    spec(() => Promise.reject(new Error('boom', { cause: { token: 'leak-me' } }))),
    h.deps,
  );
  const response = await handler(request());
  assertEquals(response.status, 500);
  const error = await errorOf(response);
  assertEquals(error.code, 'internal_error');
  assertEquals(JSON.stringify(error).includes('boom'), false);

  const failure = h.logs.find((record) => record.event === 'request_failed');
  assertEquals(failure?.['error'], {
    name: 'Error',
    message: 'boom',
    cause: { token: '[redacted]' },
  });
});

Deno.test('requireUser returns the caller or rejects anonymous requests', () => {
  const base = { requestId: 'r', config: testConfig(), log: undefined, now: () => NOW };
  const withUser = { ...base, supabase: fakeContext() } as unknown as RequestContext;
  assertEquals(requireUser(withUser), { id: USER_ID, email: 'owner@example.com' });

  const noEmail = {
    ...base,
    supabase: fakeContext({ user: { email: undefined } }),
  } as unknown as RequestContext;
  assertEquals(requireUser(noEmail).email, null);

  const anonymous = { ...base, supabase: fakeContext({ user: null }) } as unknown as RequestContext;
  const error = assertThrows(() => requireUser(anonymous), HttpError);
  assertEquals([error.status, error.code], [401, 'unauthorized']);
});

Deno.test('default dependencies: ids, time and configuration', () => {
  assertMatch(defaultDeps.newRequestId(), /^[0-9a-f-]{36}$/);
  assert(defaultDeps.now() instanceof Date);
  assertEquals(defaultDeps.loadConfig().reauthMaxAgeSeconds, testConfig().reauthMaxAgeSeconds);
});

Deno.test('default dependencies: authentication through @supabase/server', async () => {
  const values: Record<string, string> = {
    SUPABASE_URL: 'http://127.0.0.1:54321',
    SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_test"}',
    SUPABASE_SECRET_KEYS: '{"default":"sb_secret_test"}',
    SUPABASE_JWKS: '{"keys":[]}',
  };
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, Deno.env.get(key)]));
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
  try {
    const open = await defaultDeps.createContext(request(), { auth: 'none' });
    assertEquals(open.error, null);
    assertEquals(open.data?.authMode, 'none');
    assertEquals(open.data?.userClaims, null);

    const denied = await defaultDeps.createContext(request(), { auth: 'user' });
    assertEquals(denied.data, null);
    assertEquals(denied.error?.status, 401);

    const forged = await defaultDeps.createContext(
      request({ headers: { authorization: 'Bearer not.a.jwt' } }),
      { auth: 'user' },
    );
    assertEquals(forged.error?.status, 401);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
