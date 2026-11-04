/**
 * CORS for browser callers (the Flutter web app).
 *
 * Origins are matched exactly against an allowlist and echoed back; nothing
 * is ever answered with `*`. Mobile apps send no Origin header and are not
 * affected. CORS is not an authorisation mechanism here: every non-public
 * endpoint still requires a bearer token.
 */

export const ALLOWED_REQUEST_HEADERS = [
  'authorization',
  'apikey',
  'content-type',
  'x-client-info',
  'x-region',
  'x-health-token',
] as const;

export const EXPOSED_RESPONSE_HEADERS = ['x-request-id', 'retry-after'] as const;

/** Whether [origin] may call the functions from a browser. */
export function isOriginAllowed(origin: string | null, allowedOrigins: readonly string[]): boolean {
  return origin !== null && allowedOrigins.includes(origin);
}

/**
 * CORS headers for a response to a request from [origin]. Always varies on
 * Origin so caches never serve one origin's response to another.
 */
export function corsHeaders(
  origin: string | null,
  allowedOrigins: readonly string[],
  methods: readonly string[],
): Record<string, string> {
  const headers: Record<string, string> = { vary: 'Origin' };
  if (origin !== null && isOriginAllowed(origin, allowedOrigins)) {
    headers['access-control-allow-origin'] = origin;
    headers['access-control-allow-methods'] = [...methods, 'OPTIONS'].join(', ');
    headers['access-control-allow-headers'] = ALLOWED_REQUEST_HEADERS.join(', ');
    headers['access-control-expose-headers'] = EXPOSED_RESPONSE_HEADERS.join(', ');
    headers['access-control-max-age'] = '86400';
  }
  return headers;
}
