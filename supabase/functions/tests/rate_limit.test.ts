import { assertEquals, assertRejects } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import { hitRateLimit, type RpcClient } from '../_shared/rate_limit.ts';

function client(data: unknown, error: { message: string } | null = null) {
  const calls: Array<[string, Record<string, unknown>]> = [];
  const rpc: RpcClient = {
    rpc: (fn, args) => {
      calls.push([fn, args]);
      return Promise.resolve({ data, error });
    },
  };
  return { rpc, calls };
}

const RULE = { key: 'invite_email:user:u1', limit: 10, windowSeconds: 3600 };

Deno.test('hitRateLimit calls the database limiter with the rule', async () => {
  const { rpc, calls } = client(true);
  assertEquals(await hitRateLimit(rpc, RULE), true);
  assertEquals(calls, [[
    'admin_hit_rate_limit',
    { p_key: 'invite_email:user:u1', p_limit: 10, p_window_seconds: 3600 },
  ]]);
});

Deno.test('hitRateLimit reports a refused hit', async () => {
  assertEquals(await hitRateLimit(client(false).rpc, RULE), false);
});

Deno.test('hitRateLimit turns limiter failures into upstream errors', async () => {
  for (const { rpc } of [client(null, { message: 'down' }), client('yes')]) {
    const error = await assertRejects(() => hitRateLimit(rpc, RULE), HttpError);
    assertEquals([error.status, error.code], [502, 'upstream_error']);
  }
});
