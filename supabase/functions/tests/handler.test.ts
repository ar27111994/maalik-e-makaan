import {
  assert,
  assertEquals,
  assertExists,
  assertFalse,
  assertInstanceOf,
  assertMatch,
  assertNotEquals,
  assertStrictEquals,
  assertThrows,
} from '@std/assert';
import { returnsNext, stub } from '@std/testing/mock';
import { ConfigError } from '../_shared/config.ts';
import { HttpError } from '../_shared/errors.ts';
import {
  allowedMethods,
  type Context,
  createHandler,
  defaultDeps,
  type FunctionSpec,
  type RequestContext,
  requireUser,
  type Route,
} from '../_shared/handler.ts';
import { json } from '../_shared/http.ts';
import { consoleSink, createLogger, type LogRecord } from '../_shared/log.ts';
import {
  APP_ORIGIN,
  type ContextOptions,
  errorOf,
  fakeContext,
  harness,
  type HarnessOptions,
  NOW,
  PORTFOLIO_ID,
  request,
  REQUEST_ID,
  testConfig,
  USER_ID,
} from './_helpers.ts';

const FN = 'test-fn';
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const SECURITY = {
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-content-type-options': 'nosniff',
};
const JSON_RESPONSE = { 'content-type': 'application/json; charset=utf-8' };
const BASE = { ...SECURITY, vary: 'Origin', 'x-request-id': REQUEST_ID };

/** The CORS grants for [APP_ORIGIN] on a function answering [methods]. */
function corsFor(methods: string): Record<string, string> {
  return {
    'access-control-allow-headers':
      'authorization, apikey, content-type, x-client-info, x-region, x-health-token',
    'access-control-allow-methods': methods,
    'access-control-allow-origin': APP_ORIGIN,
    'access-control-expose-headers': 'x-request-id, retry-after',
    'access-control-max-age': '86400',
    vary: 'Origin',
  };
}

const ok = (): Promise<Response> => Promise.resolve(json({ ok: true }));

function spec(routes: FunctionSpec['routes'], auth: FunctionSpec['auth'] = 'user'): FunctionSpec {
  return { name: FN, routes, auth };
}

function headersOf(response: Response): Record<string, string> {
  return Object.fromEntries(response.headers);
}

interface Sent {
  readonly response: Response;
  readonly logs: LogRecord[];
  readonly contextRequests: Array<{ req: Request; auth: unknown }>;
}

/** The monotonic clock reads 1000 ms when a request starts and 1012.4 ms when it ends. */
const DURATION_MS = 12;

/**
 * Sends [req] through the handler for [fnSpec] on a fresh harness. The
 * pipeline's monotonic clock reads [clock] in turn, and no more than that.
 */
async function send(
  fnSpec: FunctionSpec,
  req: Request,
  options: HarnessOptions = {},
  clock: number[] = [1_000, 1_012.4],
): Promise<Sent> {
  const h = harness(options);
  const now = stub(performance, 'now', returnsNext(clock));
  try {
    const response = await createHandler(fnSpec, h.deps)(req);
    return { response, logs: h.logs, contextRequests: h.contextRequests };
  } finally {
    now.restore();
  }
}

function accessLog(method: string, status: number, userId: string | null): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    method,
    status,
    duration_ms: DURATION_MS,
    user_id: userId,
    level: 'info',
    event: 'request',
  };
}

function rejectedLog(code: string, details?: Record<string, unknown>): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    code,
    details,
    level: 'warn',
    event: 'request_rejected',
  };
}

function failedLog(code: string, error: unknown): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, code, error, level: 'error', event: 'request_failed' };
}

Deno.test('allowedMethods lists the routes in declaration order and adds HEAD when GET is served', () => {
  const cases: Array<[FunctionSpec['routes'], string[]]> = [
    [{ GET: ok }, ['GET', 'HEAD']],
    [{ POST: ok }, ['POST']],
    [{ GET: ok, POST: ok }, ['GET', 'POST', 'HEAD']],
    [{ POST: ok, GET: ok }, ['POST', 'GET', 'HEAD']],
    [{ PUT: ok, PATCH: ok, DELETE: ok }, ['PUT', 'PATCH', 'DELETE']],
    [{}, []],
  ];
  for (const [routes, methods] of cases) {
    assertEquals(allowedMethods(spec(routes)), methods, Object.keys(routes).join());
  }
});

Deno.test('each method is dispatched to its own route', async () => {
  const seen: string[] = [];
  const route = (name: string): Route => (ctx) => {
    seen.push(`${name} route saw ${ctx.req.method}`);
    return Promise.resolve(json({ route: name }));
  };
  const fnSpec = spec({
    GET: route('GET'),
    POST: route('POST'),
    PUT: route('PUT'),
    PATCH: route('PATCH'),
    DELETE: route('DELETE'),
  });
  for (const method of ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    const { response } = await send(fnSpec, request({ method }));
    assertEquals(response.status, 200, method);
    assertEquals(await response.json(), { route: method });
  }
  assertEquals(seen, [
    'GET route saw GET',
    'POST route saw POST',
    'PUT route saw PUT',
    'PATCH route saw PATCH',
    'DELETE route saw DELETE',
  ]);
});

Deno.test('methods match exactly: a lowercase "patch" does not reach the PATCH route', async () => {
  let called = false;
  const fnSpec = spec({
    PATCH: () => {
      called = true;
      return ok();
    },
  });
  const { response, contextRequests } = await send(fnSpec, request({ method: 'patch' }));
  assertEquals(response.status, 405);
  assertEquals(response.headers.get('allow'), 'PATCH, OPTIONS');
  assertEquals((await errorOf(response)).code, 'method_not_allowed');
  assertFalse(called);
  assertEquals(contextRequests.length, 0);
});

Deno.test('a method token naming an Object.prototype member gets 405 and never reaches the prototype', async () => {
  // Looked up through the prototype, routes["constructor"] would be Object: the
  // request would be authenticated and then fail with a 500 instead of a 405.
  const tokens = [
    'constructor',
    'toString',
    'hasOwnProperty',
    'valueOf',
    'isPrototypeOf',
    '__proto__',
  ];
  for (const method of tokens) {
    const { response, contextRequests, logs } = await send(
      spec({ GET: ok, POST: ok }),
      request({ method }),
    );
    assertEquals(response.status, 405, method);
    assertEquals(response.headers.get('allow'), 'GET, POST, HEAD, OPTIONS', method);
    assertEquals((await errorOf(response)).code, 'method_not_allowed', method);
    assertEquals(contextRequests.length, 0, method);
    assertEquals(logs, [rejectedLog('method_not_allowed'), accessLog(method, 405, null)], method);
  }
});

Deno.test('an unserved method gets 405 with Allow listing the routes, HEAD with GET, and OPTIONS', async () => {
  const cases: Array<[FunctionSpec['routes'], string, string, string]> = [
    [{ POST: ok }, 'GET', 'POST, OPTIONS', 'Use POST.'],
    [{ POST: ok }, 'DELETE', 'POST, OPTIONS', 'Use POST.'],
    [{ GET: ok }, 'POST', 'GET, HEAD, OPTIONS', 'Use GET or HEAD.'],
    [{ GET: ok, DELETE: ok }, 'PUT', 'GET, DELETE, HEAD, OPTIONS', 'Use GET or DELETE or HEAD.'],
    [{ PUT: ok, PATCH: ok }, 'POST', 'PUT, PATCH, OPTIONS', 'Use PUT or PATCH.'],
  ];
  for (const [routes, method, allow, message] of cases) {
    const label = `${method} on ${Object.keys(routes).join()}`;
    const { response, contextRequests, logs } = await send(spec(routes), request({ method }));
    assertEquals(response.status, 405, label);
    assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE, allow }, label);
    assertEquals(
      await errorOf(response),
      { code: 'method_not_allowed', message, request_id: REQUEST_ID },
      label,
    );
    assertEquals(contextRequests.length, 0, `${label}: routing comes before authentication`);
    assertEquals(logs, [rejectedLog('method_not_allowed'), accessLog(method, 405, null)], label);
  }
});

Deno.test('HEAD runs the GET route and answers its status and headers without a body', async () => {
  const seen: string[] = [];
  const fnSpec = spec({
    GET: (ctx) => {
      seen.push(ctx.req.method);
      return Promise.resolve(
        json({ status: 'ok' }, 203, { 'cache-control': 'private, max-age=5', etag: '"v1"' }),
      );
    },
    POST: () => Promise.reject(new Error('the POST route must not run')),
  });
  const { response, logs } = await send(fnSpec, request({ method: 'HEAD', origin: APP_ORIGIN }));
  assertEquals(seen, ['HEAD']);
  assertEquals(response.status, 203);
  assertEquals(response.body, null);
  assertEquals(await response.text(), '');
  assertEquals(headersOf(response), {
    ...BASE,
    ...JSON_RESPONSE,
    ...corsFor('GET, POST, HEAD, OPTIONS'),
    'cache-control': 'private, max-age=5',
    etag: '"v1"',
  });
  assertEquals(logs, [accessLog('HEAD', 203, USER_ID)]);
});

Deno.test('HEAD answers an error with its status and headers but no body', async () => {
  const limited = await send(
    spec({
      GET: () =>
        Promise.reject(
          new HttpError(429, 'rate_limited', 'Slow down.', { headers: { 'retry-after': '60' } }),
        ),
    }),
    request({ method: 'HEAD' }),
  );
  assertEquals(limited.response.status, 429);
  assertEquals(headersOf(limited.response), { ...BASE, ...JSON_RESPONSE, 'retry-after': '60' });
  assertEquals(limited.response.body, null);

  const postOnly = await send(spec({ POST: ok }), request({ method: 'HEAD' }));
  assertEquals(postOnly.response.status, 405);
  assertEquals(postOnly.response.headers.get('allow'), 'POST, OPTIONS');
  assertEquals(postOnly.response.body, null);
  assertEquals(postOnly.contextRequests.length, 0);
});

Deno.test('a preflight from an allowed origin is answered 204 with CORS grants, without authentication', async () => {
  let called = false;
  const route: Route = () => {
    called = true;
    return ok();
  };
  const { response, contextRequests, logs } = await send(
    spec({ GET: route, POST: route }),
    request({
      method: 'OPTIONS',
      origin: APP_ORIGIN,
      token: null,
      headers: { 'access-control-request-method': 'POST' },
    }),
  );
  assertEquals(response.status, 204);
  assertEquals(response.body, null);
  assertEquals(headersOf(response), { ...BASE, ...corsFor('GET, POST, HEAD, OPTIONS') });
  assertFalse(called);
  assertEquals(contextRequests.length, 0);
  assertEquals(logs, [accessLog('OPTIONS', 204, null)]);
});

Deno.test('an OPTIONS request without an Origin gets 204 with no CORS grants', async () => {
  const { response, contextRequests } = await send(
    spec({ POST: ok }),
    request({ method: 'OPTIONS' }),
  );
  assertEquals(response.status, 204);
  assertEquals(headersOf(response), BASE);
  assertEquals(contextRequests.length, 0);
});

Deno.test('a browser origin that is not allowed gets 403 origin_not_allowed, preflight included', async () => {
  const origins = [
    'https://evil.example',
    'null',
    'https://app.example.com.evil.test',
    'http://app.example.com',
  ];
  for (const origin of origins) {
    for (const method of ['OPTIONS', 'GET', 'POST', 'DELETE']) {
      const label = `${method} from ${origin}`;
      let called = false;
      const route: Route = () => {
        called = true;
        return ok();
      };
      const { response, contextRequests, logs } = await send(
        spec({ GET: route, POST: route }),
        request({ method, origin }),
      );
      assertEquals(response.status, 403, label);
      assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE }, label);
      assertEquals(await errorOf(response), {
        code: 'origin_not_allowed',
        message: 'This origin may not call this function.',
        request_id: REQUEST_ID,
      }, label);
      assertFalse(called, label);
      assertEquals(contextRequests.length, 0, label);
      assertEquals(logs, [rejectedLog('origin_not_allowed'), accessLog(method, 403, null)], label);
    }
  }
});

Deno.test('a request without an Origin (mobile app, server) is served without CORS grants', async () => {
  const { response, logs } = await send(spec({ GET: ok }), request());
  assertEquals(response.status, 200);
  assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE });
  assertEquals(await response.json(), { ok: true });
  assertEquals(logs, [accessLog('GET', 200, USER_ID)]);
});

Deno.test('a request from an allowed origin gets security headers, CORS grants and the request id', async () => {
  const { response, logs } = await send(
    spec({ GET: ok, POST: ok }),
    request({ origin: APP_ORIGIN, body: { name: 'Raza Family' } }),
  );
  assertEquals(response.status, 200);
  assertEquals(headersOf(response), {
    ...BASE,
    ...JSON_RESPONSE,
    ...corsFor('GET, POST, HEAD, OPTIONS'),
  });
  assertEquals(await response.json(), { ok: true });
  assertEquals(logs, [accessLog('POST', 200, USER_ID)]);
});

Deno.test('the route gets the request, request id, configuration, Supabase context, logger and clock', async () => {
  const config = testConfig();
  const supabase = fakeContext();
  const h = harness({ config, context: supabase });
  const seen: RequestContext[] = [];
  const handler = createHandler(
    spec({
      POST: (ctx) => {
        seen.push(ctx);
        ctx.log.info('member_invited', { portfolio_id: PORTFOLIO_ID });
        return ok();
      },
    }),
    h.deps,
  );
  const req = request({ body: { email: 'tenant@example.com' } });
  await handler(req);

  const ctx = seen[0];
  assertExists(ctx);
  assertStrictEquals(ctx.req, req);
  assertEquals(ctx.requestId, REQUEST_ID);
  assertStrictEquals(ctx.config, config);
  assertStrictEquals(ctx.supabase, supabase);
  assertStrictEquals(ctx.now, h.deps.now);
  assertEquals(ctx.now(), NOW);
  assertEquals(h.logs[0], {
    fn: FN,
    request_id: REQUEST_ID,
    portfolio_id: PORTFOLIO_ID,
    level: 'info',
    event: 'member_invited',
  });
  assertEquals(h.logs.length, 2);
});

Deno.test('the context factory gets the request and the auth mode the function declares', async () => {
  const modes: Array<FunctionSpec['auth']> = [
    'user',
    'none',
    'secret',
    ['secret', 'user'],
    ['user', 'none'],
  ];
  for (const auth of modes) {
    const req = request();
    const { contextRequests } = await send(spec({ GET: ok }, auth), req);
    assertEquals(contextRequests.length, 1, JSON.stringify(auth));
    assertStrictEquals(contextRequests[0]?.req, req);
    assertEquals(contextRequests[0]?.auth, auth);
  }
});

Deno.test('an authentication failure with status 401 is a 401 with a Bearer challenge', async () => {
  for (const code of ['MISSING_CREDENTIALS', 'INVALID_JWT']) {
    let called = false;
    const { response, logs } = await send(
      spec({
        GET: () => {
          called = true;
          return ok();
        },
      }),
      request({ origin: APP_ORIGIN }),
      { context: { data: null, error: { status: 401, code, message: 'credential problem' } } },
    );
    assertEquals(response.status, 401, code);
    assertEquals(headersOf(response), {
      ...BASE,
      ...JSON_RESPONSE,
      ...corsFor('GET, HEAD, OPTIONS'),
      'www-authenticate': 'Bearer',
    }, code);
    assertEquals(await errorOf(response), {
      code: 'unauthorized',
      message: 'Sign in to continue.',
      details: { reason: code },
      request_id: REQUEST_ID,
    }, code);
    assertFalse(called, code);
    assertEquals(
      logs,
      [rejectedLog('unauthorized', { reason: code }), accessLog('GET', 401, null)],
      code,
    );
  }
});

Deno.test('any other authentication failure is a 500 server_misconfigured, logged as an error', async () => {
  for (const code of ['JWKS_NOT_CONFIGURED', 'JWKS_FETCH_FAILED', 'NO_KEYS_CONFIGURED']) {
    const failure = { status: 500, code, message: 'This is a server configuration problem.' };
    const { response, logs } = await send(spec({ GET: ok }), request(), {
      context: { data: null, error: failure },
    });
    assertEquals(response.status, 500, code);
    assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE }, code);
    assertEquals(await errorOf(response), {
      code: 'server_misconfigured',
      message: 'Authentication is not configured.',
      details: { reason: code },
      request_id: REQUEST_ID,
    }, code);
    assertEquals(logs, [
      failedLog('server_misconfigured', {
        name: 'HttpError',
        message: 'Authentication is not configured.',
        cause: failure,
      }),
      accessLog('GET', 500, null),
    ], code);
  }
});

Deno.test('a ConfigError from a route is a 500 server_misconfigured that names only the variable', async () => {
  const { response, logs } = await send(
    spec({ POST: (ctx) => Promise.resolve(json({ link: ctx.config.appUrl() })) }),
    request({ body: {} }),
    { config: testConfig({ appUrl: new ConfigError('APP_URL', 'is required for invitations') }) },
  );
  assertEquals(response.status, 500);
  assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE });
  assertEquals(await errorOf(response), {
    code: 'server_misconfigured',
    message: 'The service is not configured correctly.',
    details: { variable: 'APP_URL' },
    request_id: REQUEST_ID,
  });
  assertEquals(logs, [
    failedLog('server_misconfigured', {
      name: 'ConfigError',
      message: 'APP_URL: is required for invitations',
      cause: undefined,
    }),
    accessLog('POST', 500, USER_ID),
  ]);
});

Deno.test('a configuration that cannot load is a 500 without CORS grants, preflight included', async () => {
  const problem = '"https://app.example.com/path" must be a bare origin (scheme://host[:port])';
  for (const method of ['OPTIONS', 'GET']) {
    const { response, contextRequests, logs } = await send(
      spec({ GET: ok }),
      request({ method, origin: APP_ORIGIN }),
      {
        config: () => {
          throw new ConfigError('ALLOWED_ORIGINS', problem);
        },
      },
    );
    assertEquals(response.status, 500, method);
    assertEquals(headersOf(response), { ...BASE, ...JSON_RESPONSE }, method);
    assertEquals(await errorOf(response), {
      code: 'server_misconfigured',
      message: 'The service is not configured correctly.',
      details: { variable: 'ALLOWED_ORIGINS' },
      request_id: REQUEST_ID,
    }, method);
    assertEquals(contextRequests.length, 0, method);
    assertEquals(logs, [
      failedLog('server_misconfigured', {
        name: 'ConfigError',
        message: `ALLOWED_ORIGINS: ${problem}`,
        cause: undefined,
      }),
      accessLog(method, 500, null),
    ], method);
  }
});

Deno.test('an unexpected failure in a route is a generic 500 internal_error that reveals nothing', async () => {
  const cases: Array<[string, Route, unknown]> = [
    [
      'a thrown TypeError',
      () => {
        throw new TypeError('Cannot read properties of undefined');
      },
      { name: 'TypeError', message: 'Cannot read properties of undefined', cause: undefined },
    ],
    [
      'a rejected Error with a secret in its cause',
      () => Promise.reject(new Error('boom', { cause: { token: 'leak-me', table: 'portfolios' } })),
      { name: 'Error', message: 'boom', cause: { token: '[redacted]', table: 'portfolios' } },
    ],
    ['a rejected non-Error value', () => Promise.reject({ reason: 'odd' }), { reason: 'odd' }],
  ];
  for (const [label, route, logged] of cases) {
    const { response, logs } = await send(spec({ GET: route }), request({ origin: APP_ORIGIN }));
    assertEquals(response.status, 500, label);
    assertEquals(
      headersOf(response),
      { ...BASE, ...JSON_RESPONSE, ...corsFor('GET, HEAD, OPTIONS') },
      label,
    );
    assertEquals(await response.json(), {
      error: {
        code: 'internal_error',
        message: 'Something went wrong. Please try again.',
        request_id: REQUEST_ID,
      },
    }, label);
    assertEquals(
      logs,
      [failedLog('internal_error', logged), accessLog('GET', 500, USER_ID)],
      label,
    );
  }
});

Deno.test('an HttpError from a route keeps its status, code, details and headers', async () => {
  const { response, logs } = await send(
    spec({
      POST: () =>
        Promise.reject(
          new HttpError(429, 'rate_limited', 'Slow down.', {
            details: { limit: 3 },
            headers: { 'retry-after': '60' },
          }),
        ),
    }),
    request({ origin: APP_ORIGIN, body: {} }),
  );
  assertEquals(response.status, 429);
  assertEquals(headersOf(response), {
    ...BASE,
    ...JSON_RESPONSE,
    ...corsFor('POST, OPTIONS'),
    'retry-after': '60',
  });
  assertEquals(await errorOf(response), {
    code: 'rate_limited',
    message: 'Slow down.',
    details: { limit: 3 },
    request_id: REQUEST_ID,
  });
  assertEquals(logs, [rejectedLog('rate_limited', { limit: 3 }), accessLog('POST', 429, USER_ID)]);
});

Deno.test('errors from 500 up are logged at error level with the error, 4xx at warn level with details', async () => {
  const cause = { code: '40001', message: 'could not serialize access' };
  const cases: Array<[HttpError, LogRecord]> = [
    [
      new HttpError(503, 'temporarily_unavailable', 'Busy.', { cause }),
      failedLog('temporarily_unavailable', { name: 'HttpError', message: 'Busy.', cause }),
    ],
    [
      new HttpError(500, 'internal_error', 'Broken.'),
      failedLog('internal_error', { name: 'HttpError', message: 'Broken.', cause: undefined }),
    ],
    [
      new HttpError(422, 'validation_failed', 'Invalid.', { details: { field: 'email' } }),
      rejectedLog('validation_failed', { field: 'email' }),
    ],
    [new HttpError(409, 'conflict', 'Exists.'), rejectedLog('conflict')],
  ];
  for (const [error, logged] of cases) {
    const { response, logs } = await send(
      spec({ GET: () => Promise.reject(error) }),
      request(),
    );
    assertEquals(response.status, error.status);
    assertEquals(logs, [logged, accessLog('GET', error.status, USER_ID)], error.code);
  }
});

Deno.test('a raw Response from a route still gets the security headers, CORS grants and request id', async () => {
  const { response } = await send(
    spec({ GET: () => Promise.resolve(new Response('x')) }),
    request({ origin: APP_ORIGIN }),
  );
  assertEquals(response.status, 200);
  assertEquals(headersOf(response), {
    ...BASE,
    ...corsFor('GET, HEAD, OPTIONS'),
    'content-type': 'text/plain;charset=UTF-8',
  });
  assertEquals(await response.text(), 'x');
});

Deno.test('headers a route sets survive, except the request id and CORS grants the pipeline owns', async () => {
  const { response } = await send(
    spec({
      GET: () =>
        Promise.resolve(
          new Response('x', {
            status: 201,
            headers: {
              'cache-control': 'public, max-age=60',
              'x-request-id': 'spoofed',
              'access-control-allow-origin': '*',
            },
          }),
        ),
    }),
    request({ origin: APP_ORIGIN }),
  );
  assertEquals(response.status, 201);
  assertEquals(response.headers.get('cache-control'), 'public, max-age=60');
  assertEquals(response.headers.get('x-request-id'), REQUEST_ID);
  assertEquals(response.headers.get('access-control-allow-origin'), APP_ORIGIN);
});

Deno.test('the access log names the signed-in caller, or null when nobody is signed in', async () => {
  const signedIn = await send(spec({ GET: ok }), request());
  assertEquals(signedIn.logs, [accessLog('GET', 200, USER_ID)]);

  const open = await send(spec({ GET: ok }, 'none'), request({ token: null }), {
    context: fakeContext({ user: null }),
  });
  assertEquals(open.logs, [accessLog('GET', 200, null)]);
});

Deno.test('the access log measures the duration on the monotonic clock in whole milliseconds', async () => {
  const cases: Array<[number, number]> = [[1_000, 0], [1_000.49, 0], [1_000.5, 1], [1_250.4, 250]];
  for (const [end, durationMs] of cases) {
    const { logs } = await send(spec({ GET: ok }), request(), {}, [1_000, end]);
    assertEquals(logs.at(-1)?.['duration_ms'], durationMs, `${end}`);
  }
});

/** A route context around [supabase], as the pipeline would build it. */
function routeContext(supabase: Context): RequestContext {
  return {
    req: request(),
    requestId: REQUEST_ID,
    config: testConfig(),
    supabase,
    log: createLogger({ fn: FN, request_id: REQUEST_ID }, () => {}),
    now: () => NOW,
  };
}

Deno.test('requireUser returns the id and e-mail of the signed-in caller', () => {
  const cases: Array<[string, Context, { id: string; email: string | null }]> = [
    ['a user token', fakeContext(), { id: USER_ID, email: 'owner@example.com' }],
    ['no e-mail claim', fakeContext({ user: { email: undefined } }), { id: USER_ID, email: null }],
    ['a permanent account', fakeContext({ jwtClaims: { is_anonymous: false } }), {
      id: USER_ID,
      email: 'owner@example.com',
    }],
    ['no raw JWT claims', fakeContext({ jwtClaims: null }), {
      id: USER_ID,
      email: 'owner@example.com',
    }],
  ];
  for (const [label, supabase, caller] of cases) {
    assertEquals(requireUser(routeContext(supabase)), caller, label);
  }
});

Deno.test('requireUser refuses a request without a signed-in user with 401 and a Bearer challenge', () => {
  const error = assertThrows(
    () => requireUser(routeContext(fakeContext({ user: null }))),
    HttpError,
  );
  assertEquals(
    [error.status, error.code, error.message, error.details, error.headers],
    [401, 'unauthorized', 'Sign in to continue.', undefined, { 'www-authenticate': 'Bearer' }],
  );
});

Deno.test('requireUser refuses anonymous sign-ins and OAuth client tokens with 403', () => {
  const cases: Array<[string, NonNullable<ContextOptions['jwtClaims']>, string, string]> = [
    [
      'an anonymous sign-in',
      { is_anonymous: true },
      'Create an account to do this.',
      'anonymous_user',
    ],
    [
      'an OAuth client token',
      { client_id: 'third-party-app' },
      'Connected apps cannot do this.',
      'oauth_client_token',
    ],
    [
      'an anonymous OAuth client token',
      { is_anonymous: true, client_id: 'third-party-app' },
      'Create an account to do this.',
      'anonymous_user',
    ],
  ];
  for (const [label, jwtClaims, message, reason] of cases) {
    const error = assertThrows(
      () => requireUser(routeContext(fakeContext({ jwtClaims }))),
      HttpError,
      undefined,
      label,
    );
    assertEquals(
      [error.status, error.code, error.message, error.details, error.headers],
      [403, 'forbidden', message, { reason }, {}],
      label,
    );
  }
});

Deno.test('requireUser refusals reach the caller through the pipeline', async () => {
  const fnSpec = spec({ GET: (ctx) => Promise.resolve(json(requireUser(ctx))) });

  const allowed = await send(fnSpec, request());
  assertEquals(await allowed.response.json(), { id: USER_ID, email: 'owner@example.com' });

  const oauth = await send(fnSpec, request(), {
    context: fakeContext({ jwtClaims: { client_id: 'third-party-app' } }),
  });
  assertEquals(oauth.response.status, 403);
  assertEquals(await errorOf(oauth.response), {
    code: 'forbidden',
    message: 'Connected apps cannot do this.',
    details: { reason: 'oauth_client_token' },
    request_id: REQUEST_ID,
  });
  assertEquals(oauth.logs, [
    rejectedLog('forbidden', { reason: 'oauth_client_token' }),
    accessLog('GET', 403, USER_ID),
  ]);
});

/** Answers Deno.env.get from [values] alone, so no ambient variable is read. */
function stubEnv(values: Record<string, string>) {
  return stub(Deno.env, 'get', (name: string) => values[name]);
}

Deno.test('defaultDeps issue random UUIDs, read the system clock and log to the console', () => {
  const first = defaultDeps.newRequestId();
  assertMatch(first, UUID_V4);
  assertNotEquals(defaultDeps.newRequestId(), first);
  const now = defaultDeps.now();
  assertInstanceOf(now, Date);
  assert(Number.isFinite(now.getTime()));
  assertStrictEquals(defaultDeps.logSink, consoleSink);
});

Deno.test('defaultDeps.loadConfig reads the function secrets through Deno.env.get', () => {
  const env = stubEnv({
    ALLOWED_ORIGINS: 'https://a.example, https://b.example',
    REAUTH_MAX_AGE_SECONDS: '900',
  });
  try {
    const config = defaultDeps.loadConfig();
    assertEquals(env.calls.map((call) => call.args[0]), ['ALLOWED_ORIGINS']);
    assertEquals(config.allowedOrigins, ['https://a.example', 'https://b.example']);
    assertEquals(config.reauthMaxAgeSeconds(), 900);
    assertEquals(config.healthCheckToken(), null);
  } finally {
    env.restore();
  }
});

const encoder = new TextEncoder();
const SIGNING_KEY_ID = 'test-hs256';
const SIGNING_SECRET = encoder.encode('a-test-only-hs256-signing-secret');

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

/** An HS256 token with [claims], signed with the key of the inline JWKS below. */
async function signedToken(claims: Record<string, unknown>): Promise<string> {
  const segment = (value: unknown) => base64url(encoder.encode(JSON.stringify(value)));
  const header = segment({ alg: 'HS256', typ: 'JWT', kid: SIGNING_KEY_ID });
  const signingInput = `${header}.${segment(claims)}`;
  const key = await crypto.subtle.importKey(
    'raw',
    SIGNING_SECRET,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(signingInput));
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

/** What the platform provisions, with the JWKS inline so that nothing is fetched. */
const PLATFORM_ENV: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:54321',
  SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_test"}',
  SUPABASE_SECRET_KEYS: '{"default":"sb_secret_test"}',
  SUPABASE_JWKS: JSON.stringify({
    keys: [{ kty: 'oct', alg: 'HS256', kid: SIGNING_KEY_ID, k: base64url(SIGNING_SECRET) }],
  }),
};

Deno.test('defaultDeps.createContext accepts only user access tokens (audience "authenticated")', async () => {
  const env = stubEnv(PLATFORM_ENV);
  try {
    const token = await signedToken({
      sub: USER_ID,
      aud: 'authenticated',
      role: 'authenticated',
      email: 'owner@example.com',
    });
    const accepted = await defaultDeps.createContext(request({ token }), { auth: 'user' });
    assertEquals(accepted.error, null);
    assertEquals(accepted.data?.authMode, 'user');
    assertEquals(accepted.data?.userClaims?.id, USER_ID);
    assertEquals(accepted.data?.userClaims?.email, 'owner@example.com');

    for (const aud of ['anon', 'service_role', undefined]) {
      const other = await signedToken({ sub: USER_ID, aud, role: 'authenticated' });
      const refused = await defaultDeps.createContext(request({ token: other }), { auth: 'user' });
      assertEquals(refused.data, null, `aud ${aud}`);
      assertEquals(
        [refused.error?.status, refused.error?.code],
        [401, 'INVALID_JWT'],
        `aud ${aud}`,
      );
    }
  } finally {
    env.restore();
  }
});

Deno.test('defaultDeps.createContext serves auth "none" and reports a missing project URL as a 500', async () => {
  const env = stubEnv(PLATFORM_ENV);
  try {
    const open = await defaultDeps.createContext(request({ token: null }), { auth: 'none' });
    assertEquals(open.error, null);
    assertEquals(
      [open.data?.authMode, open.data?.userClaims, open.data?.jwtClaims],
      ['none', null, null],
    );
  } finally {
    env.restore();
  }

  const bare = stubEnv({});
  try {
    const failed = await defaultDeps.createContext(request(), { auth: 'user' });
    assertEquals(failed.data, null);
    assertEquals([failed.error?.status, failed.error?.code], [500, 'MISSING_SUPABASE_URL']);
  } finally {
    bare.restore();
  }
});

Deno.test('createHandler without deps uses defaultDeps: random request ids, Deno.env and the console', async () => {
  const env = stubEnv({ ALLOWED_ORIGINS: APP_ORIGIN });
  const log = stub(console, 'log');
  try {
    const response = await createHandler(spec({ POST: ok }))(
      request({ method: 'OPTIONS', origin: APP_ORIGIN, token: null }),
    );
    assertEquals(response.status, 204);
    assertEquals(response.headers.get('access-control-allow-origin'), APP_ORIGIN);
    const requestId = response.headers.get('x-request-id');
    assertExists(requestId);
    assertMatch(requestId, UUID_V4);

    assertEquals(log.calls.length, 1);
    const record = JSON.parse(String(log.calls[0]?.args[0]));
    assertEquals(
      [record.level, record.event, record.fn, record.request_id, record.method, record.status],
      ['info', 'request', FN, requestId, 'OPTIONS', 204],
    );
    assertEquals(record.user_id, null);
    assertEquals(typeof record.duration_ms, 'number');
  } finally {
    log.restore();
    env.restore();
  }
});
