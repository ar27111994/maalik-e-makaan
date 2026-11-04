/**
 * JSON responses and request bodies.
 */

import { HttpError } from './errors.ts';

/** Headers on every response: no caching of personal data, no sniffing, no framing. */
export const SECURITY_HEADERS: Readonly<Record<string, string>> = {
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-content-type-options': 'nosniff',
};

/** A JSON response with the security headers applied. */
export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...SECURITY_HEADERS,
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    },
  });
}

/** The error envelope for [error], tagged with the request id. */
export function errorResponse(error: HttpError, requestId: string): Response {
  return json(
    {
      error: {
        code: error.code,
        message: error.message,
        ...(error.details === undefined ? {} : { details: error.details }),
        request_id: requestId,
      },
    },
    error.status,
    error.headers,
  );
}

/** Copies [response] with extra headers (CORS, request id) merged in. */
export function withHeaders(response: Response, headers: Record<string, string>): Response {
  const merged = new Headers(response.headers);
  for (const [name, value] of Object.entries(headers)) merged.set(name, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: merged,
  });
}

export const DEFAULT_MAX_BODY_BYTES = 16 * 1024;

/**
 * Reads a JSON object from the request body.
 *
 * Rejects non-JSON content types (415), bodies larger than [maxBytes] (413,
 * checked against Content-Length and again while streaming, so a lying
 * header cannot bypass it), malformed JSON (400) and anything that is not a
 * plain object (422).
 */
export async function readJsonObject(
  req: Request,
  maxBytes = DEFAULT_MAX_BODY_BYTES,
): Promise<Record<string, unknown>> {
  const contentType = req.headers.get('content-type') ?? '';
  if (!/^application\/json\s*(;|$)/i.test(contentType)) {
    throw new HttpError(415, 'unsupported_media_type', 'Send the body as application/json.');
  }
  const declared = Number(req.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw tooLarge(maxBytes);
  }

  const text = await readTextLimited(req, maxBytes);
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new HttpError(400, 'invalid_json', 'The request body is not valid JSON.');
  }
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(422, 'validation_failed', 'The request body must be a JSON object.', {
      details: { field: '$', reason: 'not_an_object' },
    });
  }
  return value as Record<string, unknown>;
}

function tooLarge(maxBytes: number): HttpError {
  return new HttpError(413, 'payload_too_large', 'The request body is too large.', {
    details: { max_bytes: maxBytes },
  });
}

async function readTextLimited(req: Request, maxBytes: number): Promise<string> {
  if (req.body === null) return '';
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw tooLarge(maxBytes);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
}
