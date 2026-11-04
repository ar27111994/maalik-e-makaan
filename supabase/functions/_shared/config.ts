/**
 * Function configuration, read from Edge Function secrets.
 *
 * | Variable                 | Used by        | Meaning                                                  |
 * | ------------------------ | -------------- | -------------------------------------------------------- |
 * | `APP_URL`                | invite-member  | Public HTTPS URL of the app; invitation links open here. |
 * | `ALLOWED_ORIGINS`        | every function | Comma-separated browser origins (default: APP_URL's).    |
 * | `RESEND_API_KEY`         | invite-member  | Enables invitation e-mails through the Resend API.       |
 * | `MAIL_FROM`              | invite-member  | Sender, e.g. `Maalik-e-Makaan <invites@example.com>`.    |
 * | `MAIL_REPLY_TO`          | invite-member  | Reply-To address for those e-mails.                      |
 * | `HEALTH_CHECK_TOKEN`     | health         | ≥ 32 characters; enables `GET /health?deep=1`.           |
 * | `REAUTH_MAX_AGE_SECONDS` | delete-account | Sign-in age allowed for account deletion (default 600).  |
 * | `STORAGE_CLEANUP_TOKEN`  | storage-cleanup| ≥ 32 characters; the token pg_net presents.              |
 *
 * Only the browser origins are read for every request (CORS needs them).
 * Every other setting is validated when a feature uses it, so a malformed
 * optional secret breaks that feature alone instead of every function.
 * `SUPABASE_URL` and the API keys are provisioned by the platform and read by
 * `@supabase/server` itself.
 */

export type Env = (name: string) => string | undefined;

export interface EmailConfig {
  readonly apiKey: string;
  readonly from: string;
  readonly replyTo: string | null;
}

export interface FunctionConfig {
  /** Browser origins allowed to call the functions (exact match). */
  readonly allowedOrigins: readonly string[];
  /** Public URL of the app without a trailing slash; throws when unset or invalid. */
  appUrl(): string;
  /** Invitation e-mail delivery, or null when e-mail is not configured. */
  email(): EmailConfig | null;
  /** Secret that unlocks deep health checks, or null to disable them. */
  healthCheckToken(): string | null;
  /** Maximum age, in seconds, of the last sign-in for account deletion. */
  reauthMaxAgeSeconds(): number;
  /** Token the database presents to storage-cleanup, or null when unset. */
  storageCleanupToken(): string | null;
}

/** A secret is missing or unusable; the deployment must be fixed. */
export class ConfigError extends Error {
  constructor(readonly variable: string, message: string) {
    super(`${variable}: ${message}`);
    this.name = 'ConfigError';
  }
}

const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);
const MAILBOX = /^[^\s@<>]+@[^\s@<>]+\.[A-Za-z]{2,63}$/;
export const MIN_TOKEN_LENGTH = 32;

function readTrimmed(env: Env, name: string): string | null {
  const value = env(name)?.trim();
  return value ? value : null;
}

/**
 * Parses an absolute URL and checks that it is HTTPS, or HTTP on a loopback
 * host for local development.
 */
function parseWebUrl(variable: string, raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new ConfigError(variable, 'must be an absolute URL');
  }
  const local = url.protocol === 'http:' && LOOPBACK_HOSTS.has(url.hostname);
  if (url.protocol !== 'https:' && !local) {
    throw new ConfigError(variable, 'must use https (http is allowed for localhost only)');
  }
  if (url.username || url.password) {
    throw new ConfigError(variable, 'must not contain credentials');
  }
  return url;
}

function parseAppUrl(env: Env): string {
  const raw = readTrimmed(env, 'APP_URL');
  if (raw === null) throw new ConfigError('APP_URL', 'is required for invitations');
  // Checked on the raw value: URL drops an empty "?" or "#", which would
  // otherwise slip through and break every invitation link.
  if (raw.includes('?') || raw.includes('#')) {
    throw new ConfigError('APP_URL', 'must not contain a query or fragment');
  }
  const url = parseWebUrl('APP_URL', raw);
  return `${url.origin}${url.pathname}`.replace(/\/+$/, '');
}

function parseOrigins(env: Env): readonly string[] {
  const raw = readTrimmed(env, 'ALLOWED_ORIGINS');
  if (raw === null) {
    // Default to the app's own origin; without a usable APP_URL no browser
    // origin is allowed (mobile apps send no Origin and are unaffected).
    try {
      return [new URL(parseAppUrl(env)).origin];
    } catch {
      return [];
    }
  }
  const origins = raw.split(',').map((entry) => entry.trim()).filter((entry) => entry !== '');
  return [
    ...new Set(origins.map((entry) => {
      const url = parseWebUrl('ALLOWED_ORIGINS', entry);
      if (url.origin !== entry.replace(/\/+$/, '')) {
        throw new ConfigError(
          'ALLOWED_ORIGINS',
          `"${entry}" must be a bare origin (scheme://host[:port])`,
        );
      }
      return url.origin;
    })),
  ];
}

/** Accepts `addr@example.com` or `Display Name <addr@example.com>`. */
function parseMailbox(variable: string, raw: string): string {
  const match = /^(?:[^<>\r\n]*<([^<>\s]+)>|([^<>\s]+))$/.exec(raw);
  const address = match?.[1] ?? match?.[2];
  if (address === undefined || !MAILBOX.test(address)) {
    throw new ConfigError(variable, 'must be an e-mail address, optionally with a display name');
  }
  return raw;
}

function parseEmail(env: Env): EmailConfig | null {
  const apiKey = readTrimmed(env, 'RESEND_API_KEY');
  if (apiKey === null) return null;
  const from = readTrimmed(env, 'MAIL_FROM');
  if (from === null) {
    throw new ConfigError('MAIL_FROM', 'is required when RESEND_API_KEY is set');
  }
  const replyTo = readTrimmed(env, 'MAIL_REPLY_TO');
  return {
    apiKey,
    from: parseMailbox('MAIL_FROM', from),
    replyTo: replyTo === null ? null : parseMailbox('MAIL_REPLY_TO', replyTo),
  };
}

function parseToken(env: Env, variable: string): string | null {
  const token = readTrimmed(env, variable);
  if (token === null) return null;
  if (token.length < MIN_TOKEN_LENGTH) {
    throw new ConfigError(variable, `must be at least ${MIN_TOKEN_LENGTH} characters`);
  }
  return token;
}

function parseReauthMaxAge(env: Env): number {
  const raw = readTrimmed(env, 'REAUTH_MAX_AGE_SECONDS');
  if (raw === null) return 600;
  const seconds = Number(raw);
  if (!Number.isInteger(seconds) || seconds < 60 || seconds > 3600) {
    throw new ConfigError('REAUTH_MAX_AGE_SECONDS', 'must be a whole number between 60 and 3600');
  }
  return seconds;
}

/** Memoises a successful parse; a failing parse throws again on every call. */
function lazy<T>(parse: () => T): () => T {
  let parsed: { readonly value: T } | null = null;
  return () => (parsed ??= { value: parse() }).value;
}

/**
 * Reads the configuration. Throws [ConfigError] at once only for malformed
 * ALLOWED_ORIGINS; every other setting throws when its feature reads it.
 */
export function loadConfig(env: Env = (name) => Deno.env.get(name)): FunctionConfig {
  return {
    allowedOrigins: parseOrigins(env),
    appUrl: lazy(() => parseAppUrl(env)),
    email: lazy(() => parseEmail(env)),
    healthCheckToken: lazy(() => parseToken(env, 'HEALTH_CHECK_TOKEN')),
    reauthMaxAgeSeconds: lazy(() => parseReauthMaxAge(env)),
    storageCleanupToken: lazy(() => parseToken(env, 'STORAGE_CLEANUP_TOKEN')),
  };
}

/** A configuration from plain values (tests and local tooling). */
export function configFromValues(values: {
  readonly allowedOrigins?: readonly string[];
  readonly appUrl?: string | ConfigError;
  readonly email?: EmailConfig | null | ConfigError;
  readonly healthCheckToken?: string | null | ConfigError;
  readonly reauthMaxAgeSeconds?: number | ConfigError;
  readonly storageCleanupToken?: string | null | ConfigError;
}): FunctionConfig {
  const read = <T>(value: T | ConfigError): T => {
    if (value instanceof ConfigError) throw value;
    return value;
  };
  return {
    allowedOrigins: values.allowedOrigins ?? [],
    appUrl: () => read(values.appUrl ?? new ConfigError('APP_URL', 'is required for invitations')),
    email: () => read(values.email ?? null),
    healthCheckToken: () => read(values.healthCheckToken ?? null),
    reauthMaxAgeSeconds: () => read(values.reauthMaxAgeSeconds ?? 600),
    storageCleanupToken: () => read(values.storageCleanupToken ?? null),
  };
}
