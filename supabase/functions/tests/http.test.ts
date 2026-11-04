import { assertEquals, assertRejects } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  DEFAULT_MAX_BODY_BYTES,
  errorResponse,
  json,
  readJsonObject,
  SECURITY_HEADERS,
  withHeaders,
} from '../_shared/http.ts';

function post(body: BodyInit | null, headers: Record<string, string> = {}): Request {
  return new Request('https://example.com/fn', { method: 'POST', body, headers });
}

async function rejectsWith(promise: Promise<unknown>, status: number, code: string) {
  const error = await assertRejects(() => promise, HttpError);
  assertEquals([error.status, error.code], [status, code]);
  return error;
}

Deno.test('json applies the security headers and content type', async () => {
  const response = json({ ok: true }, 201, { 'x-extra': '1' });
  assertEquals(response.status, 201);
  assertEquals(await response.json(), { ok: true });
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    assertEquals(response.headers.get(name), value);
  }
  assertEquals(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assertEquals(response.headers.get('x-extra'), '1');
  assertEquals(json(null).status, 200);
});

Deno.test('errorResponse renders the envelope with the request id', async () => {
  const withDetails = errorResponse(
    new HttpError(429, 'rate_limited', 'Slow down.', {
      details: { limit: 3 },
      headers: { 'retry-after': '60' },
    }),
    'req-1',
  );
  assertEquals(withDetails.status, 429);
  assertEquals(withDetails.headers.get('retry-after'), '60');
  assertEquals(await withDetails.json(), {
    error: {
      code: 'rate_limited',
      message: 'Slow down.',
      details: { limit: 3 },
      request_id: 'req-1',
    },
  });

  const plain = errorResponse(new HttpError(403, 'forbidden', 'No.'), 'req-2');
  assertEquals(await plain.json(), {
    error: { code: 'forbidden', message: 'No.', request_id: 'req-2' },
  });
});

Deno.test('withHeaders merges headers and keeps status and body', async () => {
  const merged = withHeaders(json({ a: 1 }, 202), { 'x-request-id': 'abc', vary: 'Origin' });
  assertEquals(merged.status, 202);
  assertEquals(merged.headers.get('x-request-id'), 'abc');
  assertEquals(merged.headers.get('cache-control'), 'no-store');
  assertEquals(await merged.json(), { a: 1 });
});

Deno.test('readJsonObject parses a JSON object', async () => {
  assertEquals(
    await readJsonObject(post('{"a":1,"b":"x"}', { 'content-type': 'application/json' })),
    { a: 1, b: 'x' },
  );
  assertEquals(
    await readJsonObject(post('{}', { 'content-type': 'application/json; charset=utf-8' })),
    {},
  );
});

Deno.test('readJsonObject requires a JSON content type', async () => {
  await rejectsWith(
    readJsonObject(post('{}', { 'content-type': 'text/plain' })),
    415,
    'unsupported_media_type',
  );
  await rejectsWith(readJsonObject(post('{}')), 415, 'unsupported_media_type');
  await rejectsWith(readJsonObject(post(null)), 415, 'unsupported_media_type');
  await rejectsWith(
    readJsonObject(post('{}', { 'content-type': 'application/jsonp' })),
    415,
    'unsupported_media_type',
  );
});

Deno.test('readJsonObject enforces the size limit from Content-Length', async () => {
  const error = await rejectsWith(
    readJsonObject(post('{}', { 'content-type': 'application/json', 'content-length': '999999' })),
    413,
    'payload_too_large',
  );
  assertEquals(error.details, { max_bytes: DEFAULT_MAX_BODY_BYTES });
});

Deno.test('readJsonObject enforces the size limit while streaming', async () => {
  const big = new ReadableStream<Uint8Array>({
    start(controller) {
      for (let i = 0; i < 4; i++) controller.enqueue(new TextEncoder().encode('x'.repeat(10)));
      controller.close();
    },
  });
  await rejectsWith(
    readJsonObject(post(big, { 'content-type': 'application/json' }), 25),
    413,
    'payload_too_large',
  );
});

Deno.test('readJsonObject reassembles bodies streamed in several chunks', async () => {
  const chunks = ['{"name":', '"Raza', ' Family"}'];
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(new TextEncoder().encode(chunk));
      controller.close();
    },
  });
  assertEquals(
    await readJsonObject(post(body, { 'content-type': 'application/json' })),
    { name: 'Raza Family' },
  );
});

Deno.test('readJsonObject rejects malformed, empty and non-object bodies', async () => {
  const headers = { 'content-type': 'application/json' };
  await rejectsWith(readJsonObject(post('{"a":', headers)), 400, 'invalid_json');
  await rejectsWith(readJsonObject(post(null, headers)), 400, 'invalid_json');
  for (const body of ['[]', 'null', '42', '"text"']) {
    const error = await rejectsWith(readJsonObject(post(body, headers)), 422, 'validation_failed');
    assertEquals(error.details, { field: '$', reason: 'not_an_object' });
  }
});
