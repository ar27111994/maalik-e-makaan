import { assert, assertEquals, assertFalse, assertRejects, assertStrictEquals } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  DEFAULT_MAX_BODY_BYTES,
  errorResponse,
  json,
  mergeVary,
  readJsonObject,
  SECURITY_HEADERS,
  withHeaders,
} from '../_shared/http.ts';

const FUNCTION_URL = 'https://project.supabase.co/functions/v1/fn';
const JSON_CONTENT = { 'content-type': 'application/json' };
const JSON_RESPONSE = { 'content-type': 'application/json; charset=utf-8' };
/** The security headers spelled out, so that any change to them is noticed. */
const SECURITY = {
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-content-type-options': 'nosniff',
};
const encoder = new TextEncoder();

function post(body: BodyInit | null, headers: Record<string, string> = JSON_CONTENT): Request {
  return new Request(FUNCTION_URL, { method: 'POST', body, headers });
}

function headersOf(response: Response): Record<string, string> {
  return Object.fromEntries(response.headers);
}

function rejection(promise: Promise<unknown>): Promise<HttpError> {
  return assertRejects(() => promise, HttpError);
}

/** A JSON object serialised to exactly [bytes] bytes: {"a":"xx…x"}. */
function objectOfBytes(bytes: number): string {
  const text = `{"a":"${'x'.repeat(bytes - 8)}"}`;
  assertEquals(encoder.encode(text).byteLength, bytes);
  return text;
}

/** [text] as UTF-8, cut into chunks of at most [size] bytes. */
function chunked(text: string, size: number): Uint8Array[] {
  const bytes = encoder.encode(text);
  const chunks: Uint8Array[] = [];
  for (let offset = 0; offset < bytes.byteLength; offset += size) {
    chunks.push(bytes.subarray(offset, offset + size));
  }
  return chunks;
}

interface TrackedStream {
  readonly stream: ReadableStream<Uint8Array>;
  /** How many chunks a reader has asked for. */
  readonly reads: () => number;
  readonly cancelled: () => boolean;
}

/**
 * A body stream that hands out one of [chunks] per read (nothing is pulled
 * ahead of a read), then ends, or fails with [failure] when one is given.
 */
function tracked(chunks: readonly Uint8Array[], failure?: Error): TrackedStream {
  let reads = 0;
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      const chunk = chunks[reads];
      reads++;
      if (chunk !== undefined) controller.enqueue(chunk);
      else if (failure !== undefined) controller.error(failure);
      else controller.close();
    },
    cancel() {
      cancelled = true;
    },
  }, { highWaterMark: 0 });
  return { stream, reads: () => reads, cancelled: () => cancelled };
}

Deno.test('SECURITY_HEADERS forbid caching, sniffing, framing and referrers', () => {
  assertEquals(SECURITY_HEADERS, SECURITY);
});

Deno.test('json answers 200 with the body as UTF-8 JSON and the security headers', async () => {
  const response = json({ ok: true, name: 'Raza Family' });
  assertEquals(response.status, 200);
  assertEquals(headersOf(response), { ...SECURITY, ...JSON_RESPONSE });
  assertEquals(await response.text(), '{"ok":true,"name":"Raza Family"}');
});

Deno.test('json takes a status, and its extra headers override the defaults', async () => {
  const response = json([1, 2], 201, {
    'cache-control': 'private, max-age=60',
    location: '/fn/1',
  });
  assertEquals(response.status, 201);
  assertEquals(headersOf(response), {
    ...SECURITY,
    ...JSON_RESPONSE,
    'cache-control': 'private, max-age=60',
    location: '/fn/1',
  });
  assertEquals(await response.json(), [1, 2]);
});

Deno.test('errorResponse renders the envelope with details and request id, status and headers', async () => {
  const response = errorResponse(
    new HttpError(429, 'rate_limited', 'Slow down.', {
      details: { limit: 3 },
      headers: { 'retry-after': '60' },
    }),
    'req-1',
  );
  assertEquals(response.status, 429);
  assertEquals(headersOf(response), { ...SECURITY, ...JSON_RESPONSE, 'retry-after': '60' });
  assertEquals(
    await response.text(),
    '{"error":{"code":"rate_limited","message":"Slow down.","details":{"limit":3},"request_id":"req-1"}}',
  );
});

Deno.test('errorResponse leaves details out when the error has none', async () => {
  const response = errorResponse(new HttpError(403, 'forbidden', 'No.'), 'req-2');
  assertEquals(response.status, 403);
  assertEquals(headersOf(response), { ...SECURITY, ...JSON_RESPONSE });
  assertEquals(
    await response.text(),
    '{"error":{"code":"forbidden","message":"No.","request_id":"req-2"}}',
  );
});

Deno.test('withHeaders adds only the security headers a response lacks and keeps its body', async () => {
  const original = new Response('plain text', {
    status: 202,
    statusText: 'Accepted Later',
    headers: { 'cache-control': 'public, max-age=60', 'content-type': 'text/plain' },
  });
  const response = withHeaders(original, { 'x-request-id': 'req-1' });
  assertEquals([response.status, response.statusText], [202, 'Accepted Later']);
  assertEquals(headersOf(response), {
    ...SECURITY,
    'cache-control': 'public, max-age=60',
    'content-type': 'text/plain',
    'x-request-id': 'req-1',
  });
  assertEquals(await response.text(), 'plain text');
});

Deno.test('withHeaders lets the given headers override the response and the security defaults', () => {
  const original = json({}, 200, { 'x-request-id': 'from-route', 'cache-control': 'max-age=5' });
  const response = withHeaders(original, {
    'x-request-id': 'from-pipeline',
    'cache-control': 'no-cache',
    'referrer-policy': 'same-origin',
  });
  assertEquals(headersOf(response), {
    ...SECURITY,
    ...JSON_RESPONSE,
    'cache-control': 'no-cache',
    'referrer-policy': 'same-origin',
    'x-request-id': 'from-pipeline',
  });
});

Deno.test('withHeaders keeps every Set-Cookie of the response', () => {
  const original = new Response('{}', {
    headers: [['set-cookie', 'a=1'], ['set-cookie', 'b=2']],
  });
  assertEquals(withHeaders(original, {}).headers.getSetCookie(), ['a=1', 'b=2']);
});

Deno.test("withHeaders merges a Vary into the response's own instead of replacing it", () => {
  const cases: ReadonlyArray<readonly [string | null, string, string]> = [
    [null, 'Origin', 'Origin'],
    ['Accept-Language', 'Origin', 'Accept-Language, Origin'],
    ['origin', 'Origin', 'origin'],
    ['Accept-Language, Origin', 'Origin', 'Accept-Language, Origin'],
    ['*', 'Origin', '*'],
  ];
  for (const [own, added, merged] of cases) {
    const original = new Response('{}', own === null ? {} : { headers: { vary: own } });
    assertEquals(withHeaders(original, { vary: added }).headers.get('vary'), merged, String(own));
  }
});

Deno.test('mergeVary lists each field once, ignores empty entries and lets * win', () => {
  assertEquals(mergeVary(null, 'Origin'), 'Origin');
  assertEquals(mergeVary('', ''), '');
  assertEquals(mergeVary(' Accept ,, Origin ', 'ORIGIN, Cookie'), 'Accept, Origin, Cookie');
  assertEquals(mergeVary('Accept', '*'), '*');
});

Deno.test('withHeaders with dropBody answers no body, keeps status and headers, cancels the original', async () => {
  const body = tracked([encoder.encode('{"a":1}')]);
  const original = new Response(body.stream, {
    status: 203,
    statusText: 'Partial',
    headers: { ...JSON_RESPONSE, etag: '"v1"' },
  });
  const response = withHeaders(original, { 'x-request-id': 'req-1' }, true);
  assertEquals(response.body, null);
  assertEquals(await response.text(), '');
  assertEquals([response.status, response.statusText], [203, 'Partial']);
  assertEquals(headersOf(response), {
    ...SECURITY,
    ...JSON_RESPONSE,
    etag: '"v1"',
    'x-request-id': 'req-1',
  });
  assert(body.cancelled(), 'the dropped body is cancelled');
  assertEquals(body.reads(), 0);
});

Deno.test('withHeaders with dropBody accepts a response that has no body', () => {
  const response = withHeaders(new Response(null, { status: 204 }), {}, true);
  assertEquals(response.status, 204);
  assertEquals(response.body, null);
  assertEquals(headersOf(response), SECURITY);
});

Deno.test('DEFAULT_MAX_BODY_BYTES is 16 KiB', () => {
  assertEquals(DEFAULT_MAX_BODY_BYTES, 16_384);
});

Deno.test('readJsonObject returns the parsed JSON object', async () => {
  assertEquals(
    await readJsonObject(post('{"name":"Raza Family","members":[{"role":"owner"}],"active":true}')),
    { name: 'Raza Family', members: [{ role: 'owner' }], active: true },
  );
  assertEquals(await readJsonObject(post(' {} ')), {});
});

Deno.test('readJsonObject accepts the JSON media type with a UTF-8 charset or none', async () => {
  const contentTypes = [
    'application/json',
    'application/json; charset=utf-8',
    'application/json;charset=UTF-8',
    'application/json; charset="utf-8"',
    'application/json; charset=utf8',
    'application/json ; charset=utf-8',
    'Application/JSON; Charset=UTF-8',
    'application/json; profile="https://example.com/invite"',
  ];
  for (const contentType of contentTypes) {
    assertEquals(
      await readJsonObject(post('{"a":1}', { 'content-type': contentType })),
      { a: 1 },
      contentType,
    );
  }
});

Deno.test('readJsonObject refuses charsets other than UTF-8 with 415 before reading', async () => {
  const contentTypes = [
    'application/json; charset=iso-8859-1',
    'application/json; charset=utf-16',
    'application/json; charset="utf-16le"',
    'application/json; charset=us-ascii',
    'application/json; charset=windows-1252',
  ];
  for (const contentType of contentTypes) {
    const req = post('{"a":1}', { 'content-type': contentType });
    const error = await rejection(readJsonObject(req));
    assertEquals(
      [error.status, error.code, error.message],
      [415, 'unsupported_media_type', 'Send the body as UTF-8.'],
      contentType,
    );
    assertFalse(req.bodyUsed, contentType);
  }
});

Deno.test('readJsonObject refuses other media types with 415 before reading', async () => {
  const requests: Array<[string, Request]> = [
    ['text/plain', post('{"a":1}', { 'content-type': 'text/plain' })],
    ['the implicit text/plain of a string body', post('{"a":1}', {})],
    ['no content type', post(encoder.encode('{"a":1}'), {})],
    ['no content type and no body', post(null, {})],
    ['application/jsonp', post('{"a":1}', { 'content-type': 'application/jsonp' })],
    ['a +json type', post('[]', { 'content-type': 'application/json-patch+json' })],
    ['problem+json', post('{"a":1}', { 'content-type': 'application/problem+json' })],
    ['text/json', post('{"a":1}', { 'content-type': 'text/json' })],
    ['a form', post('a=1', { 'content-type': 'application/x-www-form-urlencoded' })],
  ];
  for (const [label, req] of requests) {
    const error = await rejection(readJsonObject(req));
    assertEquals(
      [error.status, error.code, error.message],
      [415, 'unsupported_media_type', 'Send the body as application/json.'],
      label,
    );
    assertFalse(req.bodyUsed, label);
  }
});

Deno.test('readJsonObject accepts a declared Content-Length of exactly the limit', async () => {
  const req = post(objectOfBytes(16_384), { ...JSON_CONTENT, 'content-length': '16384' });
  assertEquals(await readJsonObject(req), { a: 'x'.repeat(16_376) });
});

Deno.test('readJsonObject refuses a declared Content-Length over the limit with 413 before reading', async () => {
  for (const declared of ['16385', '1048576']) {
    const body = tracked([encoder.encode('{}')]);
    const req = post(body.stream, { ...JSON_CONTENT, 'content-length': declared });
    const error = await rejection(readJsonObject(req));
    assertEquals(
      [error.status, error.code, error.message, error.details],
      [413, 'payload_too_large', 'The request body is too large.', { max_bytes: 16_384 }],
      declared,
    );
    assertEquals(body.reads(), 0, declared);
    assertFalse(req.bodyUsed, declared);
    assertEquals(req.body?.locked, false, declared);
  }
});

Deno.test('readJsonObject reads a streamed body of exactly the limit without Content-Length', async () => {
  const body = tracked(chunked(objectOfBytes(16_384), 4_096));
  const req = post(body.stream);
  assertEquals(req.headers.get('content-length'), null);
  assertEquals(await readJsonObject(req), { a: 'x'.repeat(16_376) });
  assertEquals(body.reads(), 5, 'four chunks, then the end of the stream');
  assertFalse(body.cancelled());
});

Deno.test('readJsonObject stops a streamed body one byte over the limit with 413 and cancels it', async () => {
  const body = tracked(chunked(objectOfBytes(16_385), 4_096));
  const req = post(body.stream);
  assertEquals(req.headers.get('content-length'), null);
  const error = await rejection(readJsonObject(req));
  assertEquals(
    [error.status, error.code, error.details],
    [413, 'payload_too_large', { max_bytes: 16_384 }],
  );
  assertEquals(body.reads(), 5, 'four full chunks and the one byte too many');
  assert(body.cancelled(), 'the rest of the body is cancelled');
});

Deno.test('readJsonObject enforces the limit while streaming, so a low Content-Length cannot bypass it', async () => {
  const body = tracked(chunked('x'.repeat(1_048_576), 16_384));
  const req = post(body.stream, { ...JSON_CONTENT, 'content-length': '2' });
  const error = await rejection(readJsonObject(req));
  assertEquals([error.status, error.code], [413, 'payload_too_large']);
  assertEquals(body.reads(), 2, 'reading stops at the first chunk past the limit');
  assert(body.cancelled());
});

Deno.test('readJsonObject ignores a Content-Length that is not a number and still enforces the limit', async () => {
  const header = { ...JSON_CONTENT, 'content-length': 'unknown' };
  assertEquals(await readJsonObject(post('{"a":1}', header)), { a: 1 });
  const body = tracked(chunked(objectOfBytes(16_385), 4_096));
  const error = await rejection(readJsonObject(post(body.stream, header)));
  assertEquals([error.status, error.code], [413, 'payload_too_large']);
});

Deno.test('readJsonObject counts the limit in bytes, not characters', async () => {
  const fits = `{"a":"${'é'.repeat(8_188)}"}`;
  assertEquals(encoder.encode(fits).byteLength, 16_384);
  assertEquals(await readJsonObject(post(fits)), { a: 'é'.repeat(8_188) });

  const over = `{"a":"${'é'.repeat(8_189)}"}`;
  assert(over.length < 16_384, 'fewer characters than the limit');
  const error = await rejection(readJsonObject(post(over)));
  assertEquals([error.status, error.code], [413, 'payload_too_large']);
});

Deno.test('readJsonObject honours a custom limit, declared or streamed', async () => {
  assertEquals(await readJsonObject(post('{"abc":12}'), 10), { abc: 12 });

  const streamed = await rejection(readJsonObject(post('{"abcd":12}'), 10));
  assertEquals([streamed.status, streamed.details], [413, { max_bytes: 10 }]);

  const declared = await rejection(
    readJsonObject(post('{}', { ...JSON_CONTENT, 'content-length': '11' }), 10),
  );
  assertEquals([declared.status, declared.details], [413, { max_bytes: 10 }]);
});

Deno.test('readJsonObject reassembles a chunked body, even when a chunk splits a character', async () => {
  const bytes = encoder.encode('{"name":"Razé Family"}');
  const split = bytes.indexOf(0xc3) + 1;
  const body = tracked([bytes.subarray(0, split), bytes.subarray(split)]);
  assertEquals(await readJsonObject(post(body.stream)), { name: 'Razé Family' });
});

Deno.test('readJsonObject rejects malformed UTF-8 with 400 instead of replacing it', async () => {
  const cases: Array<[string, number[]]> = [
    ['an invalid continuation (0xC3 0x28)', [0xc3, 0x28]],
    ['a lone continuation byte', [0x80]],
    ['an overlong encoding', [0xc0, 0xaf]],
    ['an encoded UTF-16 surrogate', [0xed, 0xa0, 0x80]],
    ['a truncated sequence', [0xe2, 0x82]],
    ['the byte 0xFF', [0xff]],
  ];
  for (const [label, malformed] of cases) {
    const bytes = new Uint8Array([
      ...encoder.encode('{"a":"'),
      ...malformed,
      ...encoder.encode('"}'),
    ]);
    const error = await rejection(readJsonObject(post(bytes)));
    assertEquals(
      [error.status, error.code, error.message],
      [400, 'invalid_json', 'The request body is not valid UTF-8.'],
      label,
    );
  }
});

Deno.test('readJsonObject reports a body that fails mid-read as 400, keeping the failure as cause', async () => {
  const failure = new Error('connection reset');
  const body = tracked([encoder.encode('{"a":')], failure);
  const error = await rejection(readJsonObject(post(body.stream)));
  assertEquals(
    [error.status, error.code, error.message],
    [400, 'invalid_json', 'The request body could not be read.'],
  );
  assertStrictEquals(error.cause, failure);
  assertEquals(body.reads(), 2);
});

Deno.test('readJsonObject rejects an empty or malformed body with 400', async () => {
  const bodies: Array<[string, BodyInit | null]> = [
    ['no body', null],
    ['an empty body', ''],
    ['only whitespace', '  \n'],
    ['truncated JSON', '{"a":'],
    ['an unquoted key', '{a:1}'],
    ['single quotes', "{'a':1}"],
    ['a trailing comma', '{"a":1,}'],
    ['two values', '{}{}'],
  ];
  for (const [label, body] of bodies) {
    const error = await rejection(readJsonObject(post(body)));
    assertEquals(
      [error.status, error.code, error.message],
      [400, 'invalid_json', 'The request body is not valid JSON.'],
      label,
    );
  }
});

Deno.test('readJsonObject rejects JSON that is not an object with 422 not_an_object', async () => {
  for (const body of ['null', '[]', '[{"a":1}]', '42', '"text"', 'true']) {
    const error = await rejection(readJsonObject(post(body)));
    assertEquals(
      [error.status, error.code, error.message, error.details],
      [422, 'validation_failed', 'The request body must be a JSON object.', {
        field: '$',
        reason: 'not_an_object',
      }],
      body,
    );
  }
});
