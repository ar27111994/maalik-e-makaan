import { assertEquals, assertInstanceOf, assertThrows } from '@std/assert';
import { ConfigError, loadConfig } from '../_shared/config.ts';

const env = (values: Record<string, string>) => (name: string) => values[name];

function configError(values: Record<string, string>, variable: string): void {
  const error = assertThrows(() => loadConfig(env(values)), ConfigError);
  assertEquals(error.variable, variable);
  assertEquals(error.name, 'ConfigError');
}

Deno.test('an empty environment gives safe defaults', () => {
  assertEquals(loadConfig(env({})), {
    appUrl: null,
    allowedOrigins: [],
    email: null,
    healthCheckToken: null,
    reauthMaxAgeSeconds: 600,
  });
});

Deno.test('blank values count as unset', () => {
  const config = loadConfig(env({ APP_URL: '   ', RESEND_API_KEY: '' }));
  assertEquals([config.appUrl, config.email], [null, null]);
});

Deno.test('APP_URL is normalised and its origin becomes the default allowed origin', () => {
  const config = loadConfig(env({ APP_URL: 'https://app.example.com/' }));
  assertEquals(config.appUrl, 'https://app.example.com');
  assertEquals(config.allowedOrigins, ['https://app.example.com']);

  const nested = loadConfig(env({ APP_URL: 'https://example.com/app//' }));
  assertEquals(nested.appUrl, 'https://example.com/app');
  assertEquals(nested.allowedOrigins, ['https://example.com']);
});

Deno.test('APP_URL accepts plain http only for loopback hosts', () => {
  for (const url of ['http://localhost:8080', 'http://127.0.0.1:8080', 'http://[::1]:8080']) {
    assertEquals(loadConfig(env({ APP_URL: url })).appUrl, url);
  }
  configError({ APP_URL: 'http://app.example.com' }, 'APP_URL');
  configError({ APP_URL: 'ftp://app.example.com' }, 'APP_URL');
});

Deno.test('APP_URL rejects malformed URLs, credentials, queries and fragments', () => {
  configError({ APP_URL: 'not a url' }, 'APP_URL');
  configError({ APP_URL: 'https://user:pass@app.example.com' }, 'APP_URL');
  configError({ APP_URL: 'https://app.example.com/?a=1' }, 'APP_URL');
  configError({ APP_URL: 'https://app.example.com/#x' }, 'APP_URL');
});

Deno.test('ALLOWED_ORIGINS is a de-duplicated list of bare origins', () => {
  const config = loadConfig(env({
    APP_URL: 'https://app.example.com',
    ALLOWED_ORIGINS: ' https://a.example.com, https://b.example.com/ ,,https://a.example.com',
  }));
  assertEquals(config.allowedOrigins, ['https://a.example.com', 'https://b.example.com']);
});

Deno.test('ALLOWED_ORIGINS rejects paths and insecure remote origins', () => {
  configError({ ALLOWED_ORIGINS: 'https://a.example.com/app' }, 'ALLOWED_ORIGINS');
  configError({ ALLOWED_ORIGINS: 'http://a.example.com' }, 'ALLOWED_ORIGINS');
});

Deno.test('e-mail needs both an API key and a valid sender', () => {
  configError({ RESEND_API_KEY: 're_123' }, 'MAIL_FROM');
  configError({ RESEND_API_KEY: 're_123', MAIL_FROM: 'not-an-address' }, 'MAIL_FROM');
  configError({ RESEND_API_KEY: 're_123', MAIL_FROM: 'Name <broken>' }, 'MAIL_FROM');

  const plain = loadConfig(env({ RESEND_API_KEY: 're_123', MAIL_FROM: 'invites@example.com' }));
  assertEquals(plain.email, { apiKey: 're_123', from: 'invites@example.com', replyTo: null });

  const named = loadConfig(env({
    RESEND_API_KEY: 're_123',
    MAIL_FROM: 'Maalik-e-Makaan <invites@example.com>',
    MAIL_REPLY_TO: 'support@example.com',
  }));
  assertEquals(named.email, {
    apiKey: 're_123',
    from: 'Maalik-e-Makaan <invites@example.com>',
    replyTo: 'support@example.com',
  });
  configError(
    { RESEND_API_KEY: 're_123', MAIL_FROM: 'invites@example.com', MAIL_REPLY_TO: 'nope' },
    'MAIL_REPLY_TO',
  );
});

Deno.test('HEALTH_CHECK_TOKEN must be long enough to resist guessing', () => {
  configError({ HEALTH_CHECK_TOKEN: 'too-short' }, 'HEALTH_CHECK_TOKEN');
  const token = 'x'.repeat(32);
  assertEquals(loadConfig(env({ HEALTH_CHECK_TOKEN: token })).healthCheckToken, token);
});

Deno.test('REAUTH_MAX_AGE_SECONDS is a whole number between 60 and 3600', () => {
  assertEquals(loadConfig(env({ REAUTH_MAX_AGE_SECONDS: '900' })).reauthMaxAgeSeconds, 900);
  for (const value of ['59', '3601', '12.5', 'ten']) {
    configError({ REAUTH_MAX_AGE_SECONDS: value }, 'REAUTH_MAX_AGE_SECONDS');
  }
});

Deno.test('loadConfig reads the process environment by default', () => {
  const previous = Deno.env.get('REAUTH_MAX_AGE_SECONDS');
  Deno.env.set('REAUTH_MAX_AGE_SECONDS', '120');
  try {
    assertEquals(loadConfig().reauthMaxAgeSeconds, 120);
  } finally {
    if (previous === undefined) Deno.env.delete('REAUTH_MAX_AGE_SECONDS');
    else Deno.env.set('REAUTH_MAX_AGE_SECONDS', previous);
  }
});

Deno.test('ConfigError names the variable in its message', () => {
  const error = new ConfigError('APP_URL', 'must be set');
  assertInstanceOf(error, Error);
  assertEquals(error.message, 'APP_URL: must be set');
});
