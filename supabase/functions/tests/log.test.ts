import {
  assert,
  assertEquals,
  assertFalse,
  assertNotStrictEquals,
  assertStrictEquals,
} from '@std/assert';
import { stub } from '@std/testing/mock';
import { HttpError } from '../_shared/errors.ts';
import {
  boundRecord,
  consoleSink,
  createLogger,
  type LogRecord,
  MAX_RECORD_BYTES,
  MAX_STRING_LENGTH,
  redact,
} from '../_shared/log.ts';
import { REQUEST_ID, USER_ID } from './_helpers.ts';

/** The UTF-8 size of [value] serialised as JSON. */
const jsonBytes = (value: unknown) => new TextEncoder().encode(JSON.stringify(value)).byteLength;

const x = (length: number) => 'x'.repeat(length);

interface ConsoleOutput {
  readonly log: unknown[][];
  readonly warn: unknown[][];
  readonly error: unknown[][];
}

/** Runs [fn] with the console methods stubbed and returns what each received. */
function captureConsole(fn: () => void): ConsoleOutput {
  const log = stub(console, 'log');
  const warn = stub(console, 'warn');
  const error = stub(console, 'error');
  try {
    fn();
    return {
      log: log.calls.map((call) => call.args),
      warn: warn.calls.map((call) => call.args),
      error: error.calls.map((call) => call.args),
    };
  } finally {
    log.restore();
    warn.restore();
    error.restore();
  }
}

/** A collecting sink. */
function collect(): { readonly records: LogRecord[]; readonly sink: (r: LogRecord) => void } {
  const records: LogRecord[] = [];
  return { records, sink: (record) => records.push(record) };
}

// --- redact ----------------------------------------------------------------------

const SENSITIVE_KEYS = [
  'email',
  'Email',
  'invite_email',
  'token',
  'access_token',
  'refresh_token',
  'x-health-token',
  'authorization',
  'Authorization',
  'apikey',
  'apiKey',
  'api_key',
  'api-key',
  'x-api-key',
  'cookie',
  'Set-Cookie',
  'jwt',
  'jwt_claims',
  'password',
  'new_password',
  'secret',
  'client_secret',
];

Deno.test('redact replaces the value under every sensitive key, at any depth', () => {
  for (const key of SENSITIVE_KEYS) {
    assertEquals(
      redact({ [key]: 'value', nested: { list: [{ [key]: { any: ['shape'] } }] }, keep: 1 }),
      { [key]: '[redacted]', nested: { list: [{ [key]: '[redacted]' }] }, keep: 1 },
      key,
    );
  }
});

Deno.test('redact replaces sensitive values whatever their type', () => {
  assertEquals(
    redact({ token: null, secret: 42, password: ['p'], email: { address: 'a@example.com' } }),
    { token: '[redacted]', secret: '[redacted]', password: '[redacted]', email: '[redacted]' },
  );
});

Deno.test('redact returns a copy and keeps other keys and primitive values', () => {
  const record = {
    user_id: USER_ID,
    status: 200,
    ok: true,
    missing: null,
    absent: undefined,
    list: [1, 'two', false, null],
    token: 'abc',
  };
  const copy = redact(record);
  assertEquals(copy, { ...record, token: '[redacted]' });
  assertNotStrictEquals(copy, record);
  assertEquals(record.token, 'abc');
  for (const value of [null, undefined, 0, 42, -1.5, true, false, '', 'text']) {
    assertStrictEquals(redact(value), value);
  }
});

Deno.test('redact cuts a string longer than MAX_STRING_LENGTH and says how much it cut', () => {
  assertEquals(MAX_STRING_LENGTH, 1000);
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['', ''],
    [x(999), x(999)],
    [x(1000), x(1000)],
    [x(1001), `${x(1000)}…[1 more]`],
    [x(2500), `${x(1000)}…[1500 more]`],
  ];
  for (const [value, kept] of cases) {
    assertEquals(redact(value), kept, `${value.length} characters`);
    assertEquals(redact({ note: value, list: [value] }), { note: kept, list: [kept] });
  }
});

Deno.test('redact describes an Error by its name, cut message and redacted cause', () => {
  const cases: ReadonlyArray<readonly [Error, unknown]> = [
    [new Error('boom'), { name: 'Error', message: 'boom', cause: undefined }],
    [
      new TypeError('bad input', { cause: { code: '42501', token: 'abc' } }),
      { name: 'TypeError', message: 'bad input', cause: { code: '42501', token: '[redacted]' } },
    ],
    [
      new Error('outer', { cause: new RangeError('inner') }),
      {
        name: 'Error',
        message: 'outer',
        cause: { name: 'RangeError', message: 'inner', cause: undefined },
      },
    ],
    [new Error(x(1001)), { name: 'Error', message: `${x(1000)}…[1 more]`, cause: undefined }],
    // Only name, message and cause are kept: an HttpError's details and headers are not.
    [
      new HttpError(502, 'upstream_error', 'The database failed.', {
        details: { email: 'owner@example.com' },
        headers: { 'retry-after': '1' },
        cause: { message: 'timeout', hint: null, apikey: 'k' },
      }),
      {
        name: 'HttpError',
        message: 'The database failed.',
        cause: { message: 'timeout', hint: null, apikey: '[redacted]' },
      },
    ],
  ];
  for (const [error, described] of cases) {
    assertEquals(redact(error), described, error.message.slice(0, 20));
  }
});

Deno.test('redact keeps six levels below the top and cuts the seventh', () => {
  const sixLevels = { a: { b: { c: { d: { e: { f: 'kept' } } } } } };
  assertEquals(redact(sixLevels), sixLevels);
  assertEquals(
    redact({ a: { b: { c: { d: { e: { f: { g: 'lost' } } } } } } }),
    { a: { b: { c: { d: { e: { f: { g: '[truncated]' } } } } } } },
  );
  assertEquals(redact([[[[[['kept']]]]]]), [[[[[['kept']]]]]]);
  assertEquals(redact([[[[[[['lost']]]]]]]), [[[[[[['[truncated]']]]]]]]);
});

Deno.test('redact ends a circular structure at the depth limit', () => {
  const loop: Record<string, unknown> = { id: 1 };
  loop['self'] = loop;
  const truncated = { id: '[truncated]', self: '[truncated]' };
  assertEquals(
    redact(loop),
    {
      id: 1,
      self: {
        id: 1,
        self: { id: 1, self: { id: 1, self: { id: 1, self: { id: 1, self: truncated } } } },
      },
    },
  );
});

// --- consoleSink ------------------------------------------------------------------

Deno.test('consoleSink writes each level to its console method as one JSON line', () => {
  const output = captureConsole(() => {
    consoleSink({ level: 'info', event: 'a', n: 1 });
    consoleSink({ level: 'warn', event: 'b' });
    consoleSink({ level: 'error', event: 'c', text: 'line\nbreak' });
  });
  assertEquals(output, {
    log: [['{"level":"info","event":"a","n":1}']],
    warn: [['{"level":"warn","event":"b"}']],
    error: [['{"level":"error","event":"c","text":"line\\nbreak"}']],
  });
});

// --- boundRecord ------------------------------------------------------------------

const BASE = {
  level: 'error',
  event: 'request_failed',
  fn: 'invite-member',
  request_id: REQUEST_ID,
} as const;

/** A record whose JSON form is exactly [size] bytes. */
function recordOfSize(size: number): LogRecord {
  const record = { ...BASE, pad: x(size - jsonBytes({ ...BASE, pad: '' })) };
  assertEquals(jsonBytes(record), size);
  return record;
}

Deno.test('boundRecord passes a record of up to MAX_RECORD_BYTES through as it is', () => {
  assertEquals(MAX_RECORD_BYTES, 8192);
  for (const size of [200, MAX_RECORD_BYTES - 1, MAX_RECORD_BYTES]) {
    const record = recordOfSize(size);
    assertStrictEquals(boundRecord(record), record, `${size} bytes`);
  }
});

Deno.test('boundRecord replaces a larger record with a marker of its size and identity', () => {
  for (const size of [MAX_RECORD_BYTES + 1, 20_000]) {
    assertEquals(boundRecord(recordOfSize(size)), { ...BASE, truncated_bytes: size });
  }
});

Deno.test('boundRecord measures UTF-8 bytes, not characters', () => {
  // 4100 two-byte letters: 4137 UTF-16 code units, but 8237 bytes.
  const record: LogRecord = {
    level: 'info',
    event: 'e',
    pad: String.fromCodePoint(0x0645).repeat(4100),
  };
  assert(JSON.stringify(record).length < MAX_RECORD_BYTES);
  const marker = boundRecord(record);
  assertEquals(marker, {
    level: 'info',
    event: 'e',
    fn: undefined,
    request_id: undefined,
    truncated_bytes: 8237,
  });
  // Keys without a value disappear from the serialised marker.
  assertEquals(JSON.stringify(marker), '{"level":"info","event":"e","truncated_bytes":8237}');
});

// --- createLogger -----------------------------------------------------------------

Deno.test('createLogger writes the base and event fields with the level and event', () => {
  const { records, sink } = collect();
  const log = createLogger({ fn: 'invite-member', request_id: REQUEST_ID }, sink);
  log.info('invitation_created', { invitation_id: 'i1', delivery: 'sent' });
  log.warn('request_rejected');
  log.error('request_failed', { code: 'internal_error' });
  assertEquals(records, [
    {
      fn: 'invite-member',
      request_id: REQUEST_ID,
      invitation_id: 'i1',
      delivery: 'sent',
      level: 'info',
      event: 'invitation_created',
    },
    { fn: 'invite-member', request_id: REQUEST_ID, level: 'warn', event: 'request_rejected' },
    {
      fn: 'invite-member',
      request_id: REQUEST_ID,
      code: 'internal_error',
      level: 'error',
      event: 'request_failed',
    },
  ]);
});

Deno.test('createLogger never throws: BigInts become digits, an unserialisable record a marker', () => {
  const { records, sink } = collect();
  const log = createLogger({ fn: 'delete-account', request_id: REQUEST_ID }, sink);
  log.error('request_failed', { error: new Error('x', { cause: { rows: 10n } }), count: 2n });
  const explosive = {
    toJSON() {
      throw new TypeError('cannot serialise');
    },
  };
  log.warn('odd', { value: explosive });
  assertEquals(records, [
    {
      fn: 'delete-account',
      request_id: REQUEST_ID,
      error: { name: 'Error', message: 'x', cause: { rows: '10' } },
      count: '2',
      level: 'error',
      event: 'request_failed',
    },
    {
      level: 'warn',
      event: 'odd',
      fn: 'delete-account',
      request_id: REQUEST_ID,
      unserialisable: 'TypeError',
    },
  ]);
});

Deno.test('createLogger marks a failure that is not an Error as unknown', () => {
  const { records, sink } = collect();
  const thrower = {
    toJSON() {
      throw 'nope';
    },
  };
  createLogger({ fn: 'health' }, sink).info('event', { thrower });
  assertEquals(records, [
    {
      level: 'info',
      event: 'event',
      fn: 'health',
      request_id: undefined,
      unserialisable: 'unknown',
    },
  ]);
});

Deno.test('createLogger does not let event fields overwrite the level or the event', () => {
  const { records, sink } = collect();
  createLogger({ fn: 'health' }, sink).warn('real', { level: 'info', event: 'fake' });
  assertEquals(records, [{ fn: 'health', level: 'warn', event: 'real' }]);
});

Deno.test('createLogger redacts base and event fields', () => {
  const { records, sink } = collect();
  const log = createLogger({ fn: 'delete-account', request_id: REQUEST_ID, apikey: 'k' }, sink);
  log.error('account_files_cleanup_deferred', {
    user_id: USER_ID,
    email: 'owner@example.com',
    error: new Error('storage down', { cause: { authorization: 'Bearer abc', status: 503 } }),
  });
  assertEquals(records, [{
    fn: 'delete-account',
    request_id: REQUEST_ID,
    apikey: '[redacted]',
    user_id: USER_ID,
    email: '[redacted]',
    error: {
      name: 'Error',
      message: 'storage down',
      cause: { authorization: '[redacted]', status: 503 },
    },
    level: 'error',
    event: 'account_files_cleanup_deferred',
  }]);
  const text = JSON.stringify(records);
  assertFalse(text.includes('owner@example.com'));
  assertFalse(text.includes('Bearer abc'));
});

Deno.test('createLogger bounds the redacted record, keeping the function and request id', () => {
  const { records, sink } = collect();
  const items = Array.from({ length: 9 }, () => x(5000));
  createLogger({ fn: 'storage-cleanup', request_id: REQUEST_ID }, sink).warn('cleanup', { items });
  // Strings are cut before the size is measured.
  const redacted = {
    fn: 'storage-cleanup',
    request_id: REQUEST_ID,
    items: items.map(() => `${x(1000)}…[4000 more]`),
    level: 'warn',
    event: 'cleanup',
  };
  assert(jsonBytes(redacted) > MAX_RECORD_BYTES);
  assertEquals(records, [{
    level: 'warn',
    event: 'cleanup',
    fn: 'storage-cleanup',
    request_id: REQUEST_ID,
    truncated_bytes: jsonBytes(redacted),
  }]);
});

Deno.test('createLogger writes JSON lines to the console by default', () => {
  const output = captureConsole(() => {
    const log = createLogger({ fn: 'health', request_id: REQUEST_ID });
    log.info('request', { status: 200 });
    log.warn('health_degraded', { token: 'abc' });
    log.error('request_failed');
  });
  const parse = (calls: unknown[][]) => calls.map((args) => JSON.parse(String(args[0])));
  assertEquals(
    { log: parse(output.log), warn: parse(output.warn), error: parse(output.error) },
    {
      log: [{ fn: 'health', request_id: REQUEST_ID, status: 200, level: 'info', event: 'request' }],
      warn: [{
        fn: 'health',
        request_id: REQUEST_ID,
        token: '[redacted]',
        level: 'warn',
        event: 'health_degraded',
      }],
      error: [{ fn: 'health', request_id: REQUEST_ID, level: 'error', event: 'request_failed' }],
    },
  );
  for (const args of [...output.log, ...output.warn, ...output.error]) {
    assertEquals(args.length, 1);
    assertFalse(String(args[0]).includes('\n'));
  }
});
