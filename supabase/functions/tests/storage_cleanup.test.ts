import { assert, assertEquals, assertFalse, assertMatch, assertStrictEquals } from '@std/assert';
import { returnsNext, spy, stub } from '@std/testing/mock';
import { type FunctionConfig, loadConfig } from '../_shared/config.ts';
import { defaultDeps } from '../_shared/handler.ts';
import { SECURITY_HEADERS } from '../_shared/http.ts';
import type { LogRecord } from '../_shared/log.ts';
import { CLAIM_LEASE_SECONDS, type CleanupItem, DOCUMENTS_BUCKET } from '../_shared/storage.ts';
import {
  createStorageCleanupHandler,
  defaultStorageCleanupDeps,
  TIME_BUDGET_MS,
} from '../storage-cleanup/handler.ts';
import server from '../storage-cleanup/index.ts';
import {
  ACCESS_TOKEN,
  type Call,
  errorOf,
  type FakeClient,
  fakeClient,
  fakeContext,
  harness,
  logText,
  OTHER_PORTFOLIO_ID,
  PORTFOLIO_ID,
  request,
  REQUEST_ID,
  type RequestOptions,
  type Result,
  steppingClock,
  testConfig,
} from './_helpers.ts';

const FN = 'storage-cleanup';
/** STORAGE_CLEANUP_TOKEN, as configured (at least 32 characters). */
const TOKEN = 'stc-7f3a9c1e5b8d2f4a6c0e9b7d5f3a1c8e';
const FOLDER = `${PORTFOLIO_ID}/`;
const OTHER_FOLDER = `${OTHER_PORTFOLIO_ID}/`;
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

/** Headers of every JSON answer to a request without an Origin (pg_net sends none). */
const JSON_HEADERS = {
  ...SECURITY_HEADERS,
  'content-type': 'application/json; charset=utf-8',
  vary: 'Origin',
  'x-request-id': REQUEST_ID,
};

// --- queue fixtures ------------------------------------------------------------------

function folder(id: number, path = FOLDER): CleanupItem {
  return { id, bucket_id: DOCUMENTS_BUCKET, path, is_prefix: true, attempts: 1 };
}

function file(id: number, path: string): CleanupItem {
  return { id, bucket_id: DOCUMENTS_BUCKET, path, is_prefix: false, attempts: 1 };
}

function names(count: number, from = 0): string[] {
  return Array.from(
    { length: count },
    (_, i) => `${FOLDER}docs/${String(from + i).padStart(5, '0')}.pdf`,
  );
}

function page(objects: readonly string[]): Result {
  return { data: objects.map((name) => ({ name })) };
}

/** An answer, or a function producing it when the call is made (to move the clock). */
type Answer = Result | (() => Result);

interface QueueScript {
  /** Answers to successive claims; the queue is empty after them. */
  readonly claims?: readonly Answer[];
  /** Successive listings of each item, by id; no object is left after them. */
  readonly listings?: Readonly<Record<number, readonly Answer[]>>;
  /** The database's answer to completing an item (default 'done'). */
  readonly complete?: (itemId: number) => Result;
}

function take(answers: Answer[] | undefined, otherwise: Result): Result {
  const next = answers?.shift();
  if (next === undefined) return otherwise;
  return typeof next === 'function' ? next() : next;
}

/** The secret-key client: queue RPCs follow [script]; the Storage API deletes what it is given. */
function queue(script: QueueScript): FakeClient {
  const claims = [...(script.claims ?? [])];
  const listings = new Map(
    Object.entries(script.listings ?? {}).map(([id, answers]) => [Number(id), [...answers]]),
  );
  return fakeClient({
    rpc: (fn, args) => {
      const itemId = args['p_item_id'] as number;
      switch (fn) {
        case 'admin_claim_storage_cleanup':
          return take(claims, { data: [] });
        case 'admin_storage_cleanup_objects':
          return take(listings.get(itemId), { data: [] });
        case 'admin_complete_storage_cleanup':
          return script.complete?.(itemId) ?? { data: 'done' };
        default:
          throw new Error(`unexpected rpc ${fn}`);
      }
    },
    remove: (_bucket, objects) => page(objects),
  });
}

// --- the calls a run is expected to make ---------------------------------------------

/** A claim of every due item: the function never restricts it to paths. */
const claimCall: Call = {
  kind: 'rpc',
  args: ['admin_claim_storage_cleanup', { p_limit: 20, p_lease_seconds: 120 }],
};

function listCall(itemId: number): Call {
  return {
    kind: 'rpc',
    args: ['admin_storage_cleanup_objects', { p_item_id: itemId, p_limit: 1000 }],
  };
}

function removeCall(objects: readonly string[]): Call {
  return { kind: 'remove', args: [DOCUMENTS_BUCKET, objects] };
}

function completeCall(itemId: number, finished: boolean, error?: string): Call {
  const args: Record<string, unknown> = { p_item_id: itemId, p_finished: finished };
  if (error !== undefined) args['p_error'] = error;
  return { kind: 'rpc', args: ['admin_complete_storage_cleanup', args] };
}

// --- the function under test ------------------------------------------------------------

interface SetupOptions extends QueueScript {
  /** STORAGE_CLEANUP_TOKEN (default TOKEN; null when unset). */
  readonly token?: string | null;
  /** A whole configuration instead of [token]. */
  readonly config?: FunctionConfig;
  /** The injected monotonic clock (default: standing at 0). */
  readonly time?: ReturnType<typeof steppingClock>;
}

function setup(options: SetupOptions = {}) {
  const admin = queue(options);
  const time = options.time ?? steppingClock();
  const h = harness({
    config: options.config ??
      testConfig({ storageCleanupToken: options.token === undefined ? TOKEN : options.token }),
    // No caller identity: the function works with the secret-key client only.
    context: fakeContext({ user: null, jwtClaims: null, supabaseAdmin: admin }),
  });
  const handler = createStorageCleanupHandler({ ...h.deps, clock: time.clock });
  return {
    admin,
    logs: h.logs,
    contextRequests: h.contextRequests,
    /** Sends [req] while the pipeline's own clock stands still (duration_ms 0). */
    send: async (req: Request): Promise<Response> => {
      const now = stub(performance, 'now', () => 1_000);
      try {
        return await handler(req);
      } finally {
        now.restore();
      }
    },
  };
}

/** The request pg_net sends: POST {} with the cleanup token and no Authorization header. */
function cleanupRequest(headers: Record<string, string> = { 'x-cleanup-token': TOKEN }): Request {
  return request({ method: 'POST', body: {}, token: null, headers });
}

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

function failedLog(code: string, error: Record<string, unknown>): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, code, error, level: 'error', event: 'request_failed' };
}

function cleanupLog(counts: Record<string, number>): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, ...counts, level: 'info', event: 'storage_cleanup' };
}

// --- a successful run -----------------------------------------------------------------------

Deno.test('POST with the cleanup token drains the queue and answers what it did', async () => {
  const receipt = `${FOLDER}receipts/1.pdf`;
  const objects = names(3);
  // A file that goes, a folder whose final sweep is pending, and a folder retried later.
  const answers: Record<number, string> = { 1: 'done', 2: 'rescheduled', 3: 'retry' };
  const t = setup({
    claims: [{ data: [file(1, receipt), folder(2), folder(3, OTHER_FOLDER)] }],
    listings: {
      1: [page([receipt])],
      2: [page(objects)],
      3: [{ error: { code: '57014', message: 'canceling statement due to statement timeout' } }],
    },
    complete: (itemId) => ({ data: answers[itemId] }),
  });

  const res = await t.send(cleanupRequest());
  assertEquals(res.status, 200);
  assertEquals(Object.fromEntries(res.headers), JSON_HEADERS);
  assertEquals(await res.json(), {
    claimed: 3,
    done: 1,
    rescheduled: 1,
    retried: 1,
    objects_removed: 4,
  });
  assertEquals(t.admin.calls, [
    claimCall,
    listCall(1),
    removeCall([receipt]),
    listCall(1),
    completeCall(1, true),
    listCall(2),
    removeCall(objects),
    listCall(2),
    completeCall(2, true),
    listCall(3),
    completeCall(3, false, 'list: 57014'),
    claimCall,
  ]);
  assertEquals(t.logs, [
    cleanupLog({ claimed: 3, done: 1, rescheduled: 1, retried: 1, objectsRemoved: 4 }),
    accessLog('POST', 200),
  ]);
  assertFalse(logText(t.logs).includes(TOKEN));
});

Deno.test('an empty queue is answered with a zero report after a single claim', async () => {
  const t = setup();
  const res = await t.send(cleanupRequest());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    claimed: 0,
    done: 0,
    rescheduled: 0,
    retried: 0,
    objects_removed: 0,
  });
  assertEquals(t.admin.calls, [claimCall]);
  assertEquals(t.logs, [
    cleanupLog({ claimed: 0, done: 0, rescheduled: 0, retried: 0, objectsRemoved: 0 }),
    accessLog('POST', 200),
  ]);
});

Deno.test('the function asks the pipeline for no user session: auth "none"', async () => {
  const t = setup();
  const req = cleanupRequest();
  assertEquals((await t.send(req)).status, 200);
  assertEquals(t.contextRequests.length, 1);
  assertStrictEquals(t.contextRequests[0]?.req, req);
  assertEquals(t.contextRequests[0]?.auth, 'none');
});

Deno.test('the request body is never read: pg_net posts {}, but any body is accepted', async () => {
  const cases: ReadonlyArray<readonly [string, RequestOptions]> = [
    ['{}', { body: {} }],
    ['no body', {}],
    ['not JSON', { body: 'not json', headers: { 'content-type': 'text/plain' } }],
    ['a JSON array', { body: [1, 2] }],
  ];
  for (const [label, options] of cases) {
    const t = setup();
    const res = await t.send(request({
      ...options,
      method: 'POST',
      token: null,
      headers: { ...options.headers, 'x-cleanup-token': TOKEN },
    }));
    assertEquals(res.status, 200, label);
    assertEquals(t.admin.calls, [claimCall], label);
  }
});

// --- the time budget --------------------------------------------------------------------------

Deno.test('the time budget ends well within the 60 s pg_net waits and the 120 s claim lease', () => {
  assertEquals(TIME_BUDGET_MS, 25_000);
  assert(TIME_BUDGET_MS < 60_000);
  assert(TIME_BUDGET_MS < CLAIM_LEASE_SECONDS * 1000);
});

Deno.test('no new work starts once TIME_BUDGET_MS has passed on the injected clock', async () => {
  const time = steppingClock();
  // The budget counts from the request, not from the clock's origin.
  time.advance(7_000);
  const first = names(2);
  const second = names(2, 2);
  const t = setup({
    time,
    claims: [{ data: [folder(1), file(2, `${FOLDER}receipts/2.pdf`)] }],
    listings: {
      1: [
        () => {
          time.advance(TIME_BUDGET_MS - 1); // 1 ms left: the next page still starts
          return page(first);
        },
        () => {
          time.advance(1); // the budget is spent: nothing new starts
          return page(second);
        },
        page(names(2, 4)),
      ],
    },
    complete: () => ({ data: 'rescheduled' }),
  });

  const res = await t.send(cleanupRequest());
  assertEquals(await res.json(), {
    claimed: 2,
    done: 0,
    rescheduled: 2,
    retried: 0,
    objects_removed: 4,
  });
  assertEquals(t.admin.calls, [
    claimCall,
    listCall(1),
    removeCall(first),
    listCall(1),
    removeCall(second),
    completeCall(1, false),
    // Claimed but not reached: handed back without a listing, and no further claim.
    completeCall(2, false),
  ]);
});

// --- refusals ---------------------------------------------------------------------------------

Deno.test('only POST is served: GET, HEAD and the rest get 405 before authentication', async () => {
  for (const method of ['GET', 'HEAD', 'PUT', 'PATCH', 'DELETE']) {
    const t = setup();
    const res = await t.send(
      request({ method, token: null, headers: { 'x-cleanup-token': TOKEN } }),
    );
    assertEquals(res.status, 405, method);
    assertEquals(
      Object.fromEntries(res.headers),
      { ...JSON_HEADERS, allow: 'POST, OPTIONS' },
      method,
    );
    if (method === 'HEAD') {
      assertEquals(res.body, null, method);
    } else {
      assertEquals(
        await errorOf(res),
        { code: 'method_not_allowed', message: 'Use POST.', request_id: REQUEST_ID },
        method,
      );
    }
    assertEquals(t.contextRequests, [], method);
    assertEquals(t.admin.calls, [], method);
    assertEquals(t.logs, [rejectedLog('method_not_allowed'), accessLog(method, 405)], method);
  }
});

Deno.test('an unset STORAGE_CLEANUP_TOKEN is a 500 server_misconfigured naming the variable', async () => {
  // Checked before the presented token, so a caller with none learns the same.
  const cases: ReadonlyArray<Record<string, string>> = [{ 'x-cleanup-token': TOKEN }, {}];
  for (const headers of cases) {
    const label = JSON.stringify(headers);
    const t = setup({ token: null });
    const res = await t.send(cleanupRequest(headers));
    assertEquals(res.status, 500, label);
    assertEquals(Object.fromEntries(res.headers), JSON_HEADERS, label);
    assertEquals(await errorOf(res), {
      code: 'server_misconfigured',
      message: 'Storage cleanup is not configured.',
      details: { variable: 'STORAGE_CLEANUP_TOKEN' },
      request_id: REQUEST_ID,
    }, label);
    assertEquals(t.admin.calls, [], label);
    assertEquals(t.logs, [
      failedLog('server_misconfigured', {
        name: 'HttpError',
        message: 'Storage cleanup is not configured.',
        cause: undefined,
      }),
      accessLog('POST', 500),
    ], label);
  }
});

Deno.test('a STORAGE_CLEANUP_TOKEN under 32 characters is a 500 naming the variable, never the value', async () => {
  const cases: ReadonlyArray<readonly [string, number]> = [
    ['too-short-cleanup-token', 500],
    ['s'.repeat(31), 500],
    ['s'.repeat(32), 200],
  ];
  for (const [secret, status] of cases) {
    const env: Record<string, string> = { STORAGE_CLEANUP_TOKEN: secret };
    const t = setup({ config: loadConfig((name) => env[name]) });
    const res = await t.send(cleanupRequest({ 'x-cleanup-token': secret }));
    assertEquals(res.status, status, secret);
    if (status === 200) {
      assertEquals(t.admin.calls, [claimCall], secret);
      continue;
    }
    const body = await res.text();
    assertEquals(JSON.parse(body).error, {
      code: 'server_misconfigured',
      message: 'The service is not configured correctly.',
      details: { variable: 'STORAGE_CLEANUP_TOKEN' },
      request_id: REQUEST_ID,
    }, secret);
    assertFalse(body.includes(secret), secret);
    assertEquals(t.logs, [
      failedLog('server_misconfigured', {
        name: 'ConfigError',
        message: 'STORAGE_CLEANUP_TOKEN: must be at least 32 characters',
        cause: undefined,
      }),
      accessLog('POST', 500),
    ], secret);
    assertFalse(logText(t.logs).includes(secret), secret);
    assertEquals(t.admin.calls, [], secret);
  }
});

Deno.test('a missing or wrong x-cleanup-token is a 401 with a Bearer challenge; the queue is untouched', async () => {
  const cases: ReadonlyArray<readonly [string, Record<string, string>]> = [
    ['no token', {}],
    ['an empty token', { 'x-cleanup-token': '' }],
    ['another secret', { 'x-cleanup-token': 'wrong' }],
    ['the last character changed', { 'x-cleanup-token': `${TOKEN.slice(0, -1)}X` }],
    ['a prefix', { 'x-cleanup-token': TOKEN.slice(0, -1) }],
    ['an extension', { 'x-cleanup-token': `${TOKEN}0` }],
    ['another case', { 'x-cleanup-token': TOKEN.toUpperCase() }],
    ['the token as a bearer token', { authorization: `Bearer ${TOKEN}` }],
    ['a user access token', { authorization: `Bearer ${ACCESS_TOKEN}` }],
    ['the health check header', { 'x-health-token': TOKEN }],
  ];
  for (const [label, headers] of cases) {
    const t = setup();
    const res = await t.send(cleanupRequest(headers));
    assertEquals(res.status, 401, label);
    assertEquals(
      Object.fromEntries(res.headers),
      { ...JSON_HEADERS, 'www-authenticate': 'Bearer' },
      label,
    );
    assertEquals(await errorOf(res), {
      code: 'unauthorized',
      message: 'A valid cleanup token is required.',
      request_id: REQUEST_ID,
    }, label);
    assertEquals(t.admin.calls, [], label);
    assertEquals(t.logs, [rejectedLog('unauthorized'), accessLog('POST', 401)], label);
    assertFalse(logText(t.logs).includes(TOKEN), label);
  }
});

Deno.test('the token is compared in constant time: presented and expected values are HMAC-signed under one key', async () => {
  const decoder = new TextDecoder();
  const cases: ReadonlyArray<readonly [string | null, number]> = [
    [TOKEN, 200],
    ['wrong', 401],
    [null, 401], // a missing header is compared as ''
  ];
  for (const [presented, status] of cases) {
    const label = String(presented);
    const t = setup();
    const signs = spy(crypto.subtle, 'sign');
    try {
      const res = await t.send(
        cleanupRequest(presented === null ? {} : { 'x-cleanup-token': presented }),
      );
      assertEquals(res.status, status, label);
      assertEquals(signs.calls.map((call) => call.args[0]), ['HMAC', 'HMAC'], label);
      assertEquals(
        signs.calls.map((call) => decoder.decode(call.args[2] as Uint8Array)),
        [presented ?? '', TOKEN],
        label,
      );
      assertStrictEquals(signs.calls[0]?.args[1], signs.calls[1]?.args[1], label);
    } finally {
      signs.restore();
    }
  }
});

Deno.test('a failing claim is a 502 upstream_error, or a 503 with Retry-After on deadlock', async () => {
  const cases: ReadonlyArray<
    readonly [Record<string, unknown>, number, string, string, Record<string, string>]
  > = [
    [
      { code: 'XX000', message: 'internal error' },
      502,
      'upstream_error',
      'The database could not complete the request.',
      {},
    ],
    [
      { code: '40P01', message: 'deadlock detected' },
      503,
      'temporarily_unavailable',
      'The service is busy. Please try again.',
      { 'retry-after': '1' },
    ],
  ];
  for (const [error, status, code, message, headers] of cases) {
    const t = setup({ claims: [{ error }] });
    const res = await t.send(cleanupRequest());
    assertEquals(res.status, status, code);
    assertEquals(Object.fromEntries(res.headers), { ...JSON_HEADERS, ...headers }, code);
    assertEquals(await errorOf(res), { code, message, request_id: REQUEST_ID }, code);
    assertEquals(t.admin.calls, [claimCall], code);
    // No storage_cleanup record: the run did not finish.
    assertEquals(t.logs, [
      failedLog(code, { name: 'HttpError', message, cause: error }),
      accessLog('POST', status),
    ], code);
  }
});

// --- wiring -------------------------------------------------------------------------------------

Deno.test('defaultStorageCleanupDeps is the default pipeline plus performance.now as the clock', () => {
  for (const key of Object.keys(defaultDeps) as Array<keyof typeof defaultDeps>) {
    assertStrictEquals(defaultStorageCleanupDeps[key], defaultDeps[key], key);
  }
  const reading = defaultStorageCleanupDeps.clock();
  assertEquals(typeof reading, 'number');
  assert(Number.isFinite(reading));

  const now = stub(performance, 'now', returnsNext([1_234.5]));
  try {
    assertEquals(defaultStorageCleanupDeps.clock(), 1_234.5);
    assertEquals(now.calls.length, 1);
  } finally {
    now.restore();
  }
});

Deno.test('index.ts exports { fetch }: the POST-only storage-cleanup handler on the default deps', async () => {
  assertEquals(Object.keys(server), ['fetch']);
  assertEquals(typeof server.fetch, 'function');

  // A GET is refused before authentication: only the configuration is read, from the
  // environment, and the records go to the console as JSON lines.
  const env = stub(Deno.env, 'get', () => undefined);
  const lines: string[] = [];
  const info = stub(console, 'log', (line: string) => void lines.push(line));
  const warn = stub(console, 'warn', (line: string) => void lines.push(line));
  try {
    const res = await server.fetch(request({ method: 'GET', token: null }));
    assertEquals(res.status, 405);
    assertEquals(res.headers.get('allow'), 'POST, OPTIONS');
    const requestId = res.headers.get('x-request-id') ?? '';
    assertMatch(requestId, UUID_V4);
    assertEquals(await errorOf(res), {
      code: 'method_not_allowed',
      message: 'Use POST.',
      request_id: requestId,
    });
    assertEquals(
      lines.map((line) => {
        const record = JSON.parse(line);
        return [record.level, record.event, record.fn, record.request_id];
      }),
      [['warn', 'request_rejected', FN, requestId], ['info', 'request', FN, requestId]],
    );
    assert(env.calls.length > 0);
  } finally {
    warn.restore();
    info.restore();
    env.restore();
  }
});
