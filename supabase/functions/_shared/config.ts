/**
 * Function configuration, read from Edge Function secrets.
 *
 * | Variable                 | Required | Meaning                                                  |
 * | ------------------------ | -------- | -------------------------------------------------------- |
 * | `APP_URL`                | invites  | Public HTTPS URL of the app; invitation links open here. |
 * | `ALLOWED_ORIGINS`        | no       | Comma-separated browser origins (default: APP_URL's).    |
 * | `RESEND_API_KEY`         | no       | Enables invitation e-mails through the Resend API.       |
 * | `MAIL_FROM`              | with key | Sender, e.g. `Maalik-e-Makaan <invites@example.com>`.    |
 * | `MAIL_REPLY_TO`          | no       | Reply-To address for those e-mails.                      |
 * | `HEALTH_CHECK_TOKEN`     | no       | ≥ 32 characters; enables `GET /health?deep=1`.           |
 * | `REAUTH_MAX_AGE_SECONDS` | no       | Sign-in age allowed for account deletion (default 600).  |
 *
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
  /** Public URL of the app without a trailing slash, or null when unset. */
  readonly appUrl: string | null;
  /** Browser origins allowed to call the functions (exact match). */
  readonly allowedOrigins: readonly string[];
  /** Invitation e-mail delivery, or null when e-mail is not configured. */
  readonly email: EmailConfig | null;
  /** Secret that unlocks deep health checks, or null to disable them. */
  readonly healthCheckToken: string | null;
  /** Maximum age, in seconds, of the last sign-in for account deletion. */
  readonly reauthMaxAgeSeconds: number;
}

/** A secret is present but unusable; the deployment must be fixed. */
export class ConfigError extends Error {
  constructor(readonly variable: string, message: string) {
    super(`${variable}: ${message}`);
    this.name = 'ConfigError';
  }
}

const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);
const MAILBOX = /^[^\s@<>]+@[^\s@<>]+\.[A-Za-z]{2,63}$/;

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

function parseAppUrl(env: Env): string | null {
  const raw = readTrimmed(env, 'APP_URL');
  if (raw === null) return null;
  const url = parseWebUrl('APP_URL', raw);
  if (url.search || url.hash) {
    throw new ConfigError('APP_URL', 'must not contain a query or fragment');
  }
  return url.toString().replace(/\/+$/, '');
}

function parseOrigins(env: Env, appUrl: string | null): readonly string[] {
  const raw = readTrimmed(env, 'ALLOWED_ORIGINS');
  if (raw === null) {
    return appUrl === null ? [] : [new URL(appUrl).origin];
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

function parseHealthToken(env: Env): string | null {
  const token = readTrimmed(env, 'HEALTH_CHECK_TOKEN');
  if (token === null) return null;
  if (token.length < 32) {
    throw new ConfigError('HEALTH_CHECK_TOKEN', 'must be at least 32 characters');
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

/** Reads and validates the configuration. Throws [ConfigError] on bad values. */
export function loadConfig(env: Env = (name) => Deno.env.get(name)): FunctionConfig {
  const appUrl = parseAppUrl(env);
  return {
    appUrl,
    allowedOrigins: parseOrigins(env, appUrl),
    email: parseEmail(env),
    healthCheckToken: parseHealthToken(env),
    reauthMaxAgeSeconds: parseReauthMaxAge(env),
  };
}
