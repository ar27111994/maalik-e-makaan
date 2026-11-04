import { assertEquals } from '@std/assert';
import { stub } from '@std/testing/mock';
import { consoleSink, createLogger, type LogRecord, redact } from '../_shared/log.ts';

Deno.test('redact hides sensitive keys at any depth, including e-mail addresses', () => {
  assertEquals(
    redact({
      user_id: 'u1',
      token: 'abc',
      nested: { apiKey: 'k', Authorization: 'Bearer x', list: [{ password: 'p', ok: 1 }] },
      email: 'owner@example.com',
      invite_email: 'x@example.com',
    }),
    {
      user_id: 'u1',
      token: '[redacted]',
      nested: {
        apiKey: '[redacted]',
        Authorization: '[redacted]',
        list: [{ password: '[redacted]', ok: 1 }],
      },
      email: '[redacted]',
      invite_email: '[redacted]',
    },
  );
});

Deno.test('redact describes errors with their causes', () => {
  const error = new Error('outer', { cause: { message: 'inner', secret: 's' } });
  assertEquals(redact(error), {
    name: 'Error',
    message: 'outer',
    cause: { message: 'inner', secret: '[redacted]' },
  });
});

Deno.test('redact stops at a maximum depth and passes primitives through', () => {
  const deep = { a: { b: { c: { d: { e: { f: { g: { h: 1 } } } } } } } };
  assertEquals(redact(deep), { a: { b: { c: { d: { e: { f: { g: '[truncated]' } } } } } } });
  assertEquals(redact(null), null);
  assertEquals(redact(42), 42);
  assertEquals(redact('text'), 'text');
});

Deno.test('createLogger merges base fields, redacts, and sets level and event', () => {
  const records: LogRecord[] = [];
  const log = createLogger({ fn: 'test', request_id: 'r1' }, (record) => records.push(record));
  log.info('started', { user_id: 'u1', token: 'secret' });
  log.warn('slow');
  log.error('failed', { level: 'spoofed', event: 'spoofed' });
  assertEquals(records, [
    {
      fn: 'test',
      request_id: 'r1',
      user_id: 'u1',
      token: '[redacted]',
      level: 'info',
      event: 'started',
    },
    { fn: 'test', request_id: 'r1', level: 'warn', event: 'slow' },
    { fn: 'test', request_id: 'r1', level: 'error', event: 'failed' },
  ]);
});

Deno.test('consoleSink writes info to stdout and everything else to stderr as JSON', () => {
  const out = stub(console, 'log');
  const err = stub(console, 'error');
  try {
    consoleSink({ level: 'info', event: 'a' });
    consoleSink({ level: 'warn', event: 'b' });
    consoleSink({ level: 'error', event: 'c' });
    assertEquals(out.calls.map((call) => call.args), [['{"level":"info","event":"a"}']]);
    assertEquals(err.calls.map((call) => call.args), [
      ['{"level":"warn","event":"b"}'],
      ['{"level":"error","event":"c"}'],
    ]);
  } finally {
    out.restore();
    err.restore();
  }
});
