import { assertEquals, assertInstanceOf, assertStrictEquals, assertThrows } from '@std/assert';
import { stub } from '@std/testing/mock';
import {
  ConfigError,
  configFromValues,
  type Env,
  type FunctionConfig,
  loadConfig,
  MIN_TOKEN_LENGTH,
} from '../_shared/config.ts';
import type { ConfigValues } from './_helpers.ts';

type Values = Readonly<Record<string, string>>;
type Feature = Exclude<keyof FunctionConfig, 'allowedOrigins'>;

const FEATURE_NAMES: readonly Feature[] = [
  'appUrl',
  'email',
  'healthCheckToken',
  'reauthMaxAgeSeconds',
  'storageCleanupToken',
];

/** An environment holding [values] that records the name of every variable read. */
function recordingEnv(values: Values): { readonly env: Env; readonly reads: string[] } {
  const reads: string[] = [];
  return {
    reads,
    env: (name) => {
      reads.push(name);
      return values[name];
    },
  };
}

const env = (values: Values): Env => recordingEnv(values).env;

/** Asserts that [fn] throws a ConfigError for [variable], with [message] when given. */
function assertConfigError(fn: () => unknown, variable: string, message?: string): void {
  const error = assertThrows(fn, ConfigError);
  assertEquals(error.variable, variable);
  if (message !== undefined) assertEquals(error.message, `${variable}: ${message}`);
}

const ABSOLUTE_URL = 'must be an absolute URL';
const HTTPS_ONLY = 'must use https (http is allowed for localhost only)';
const NO_CREDENTIALS = 'must not contain credentials';
const NO_QUERY = 'must not contain a query or fragment';
const MAILBOX = 'must be an e-mail address, optionally with a display name';
const TOKEN_LENGTH = 'must be at least 32 characters';
const REAUTH_RANGE = 'must be a whole number between 60 and 3600';
const bareOrigin = (entry: string) => `"${entry}" must be a bare origin (scheme://host[:port])`;

const TOKEN = 't'.repeat(MIN_TOKEN_LENGTH);

Deno.test('ConfigError carries the variable and names it in its message', () => {
  const error = new ConfigError('APP_URL', 'is broken');
  assertInstanceOf(error, Error);
  assertEquals(
    [error.name, error.variable, error.message],
    ['ConfigError', 'APP_URL', 'APP_URL: is broken'],
  );
});

Deno.test('an empty environment loads with no browser origin and every feature default', () => {
  const config = loadConfig(env({}));
  assertEquals(config.allowedOrigins, []);
  assertConfigError(() => config.appUrl(), 'APP_URL', 'is required for invitations');
  assertEquals(config.email(), null);
  assertEquals(config.healthCheckToken(), null);
  assertEquals(config.reauthMaxAgeSeconds(), 600);
  assertEquals(config.storageCleanupToken(), null);
});

Deno.test('blank and whitespace-only values count as unset', () => {
  for (const blank of ['', '   ', '\t\n ']) {
    const config = loadConfig(env({
      ALLOWED_ORIGINS: blank,
      APP_URL: blank,
      RESEND_API_KEY: blank,
      MAIL_FROM: blank,
      MAIL_REPLY_TO: blank,
      HEALTH_CHECK_TOKEN: blank,
      REAUTH_MAX_AGE_SECONDS: blank,
      STORAGE_CLEANUP_TOKEN: blank,
    }));
    assertEquals(config.allowedOrigins, [], JSON.stringify(blank));
    assertConfigError(() => config.appUrl(), 'APP_URL', 'is required for invitations');
    assertEquals(config.email(), null);
    assertEquals(config.healthCheckToken(), null);
    assertEquals(config.reauthMaxAgeSeconds(), 600);
    assertEquals(config.storageCleanupToken(), null);
  }
});

Deno.test('loading reads only the browser origins (and APP_URL for their default)', () => {
  const unset = recordingEnv({});
  loadConfig(unset.env);
  assertEquals(unset.reads, ['ALLOWED_ORIGINS', 'APP_URL']);

  const set = recordingEnv({ ALLOWED_ORIGINS: 'https://app.example.com' });
  loadConfig(set.env);
  assertEquals(set.reads, ['ALLOWED_ORIGINS']);
});

Deno.test('loadConfig reads the process environment by default', () => {
  const values: Values = {
    ALLOWED_ORIGINS: 'https://app.example.com',
    REAUTH_MAX_AGE_SECONDS: '120',
  };
  const get = stub(Deno.env, 'get', (name: string) => values[name]);
  try {
    const config = loadConfig();
    assertEquals(config.allowedOrigins, ['https://app.example.com']);
    assertEquals(config.reauthMaxAgeSeconds(), 120);
    assertEquals(get.calls.map((call) => call.args[0]), [
      'ALLOWED_ORIGINS',
      'REAUTH_MAX_AGE_SECONDS',
    ]);
  } finally {
    get.restore();
  }
});

// --- ALLOWED_ORIGINS -------------------------------------------------------

Deno.test('ALLOWED_ORIGINS becomes a de-duplicated list of bare origins in the given order', () => {
  const config = loadConfig(env({
    ALLOWED_ORIGINS: [
      ' https://b.example.com/ ',
      '',
      ' https://a.example.com',
      'https://b.example.com',
      'http://localhost:3000 ',
    ].join(','),
  }));
  assertEquals(config.allowedOrigins, [
    'https://b.example.com',
    'https://a.example.com',
    'http://localhost:3000',
  ]);
});

Deno.test('ALLOWED_ORIGINS accepts https origins and http on loopback hosts', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['https://app.example.com', 'https://app.example.com'],
    ['https://app.example.com:8443', 'https://app.example.com:8443'],
    ['https://app.example.com//', 'https://app.example.com'],
    ['http://localhost:3000', 'http://localhost:3000'],
    ['http://127.0.0.1:8080', 'http://127.0.0.1:8080'],
    ['http://[::1]:8080', 'http://[::1]:8080'],
  ];
  for (const [entry, origin] of cases) {
    assertEquals(loadConfig(env({ ALLOWED_ORIGINS: entry })).allowedOrigins, [origin], entry);
  }
});

Deno.test('ALLOWED_ORIGINS of separators only allows no origin rather than the default', () => {
  const config = loadConfig(env({ ALLOWED_ORIGINS: ' , ,', APP_URL: 'https://app.example.com' }));
  assertEquals(config.allowedOrigins, []);
});

Deno.test('a malformed ALLOWED_ORIGINS entry fails loading at once', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['https://app.example.com/app', bareOrigin('https://app.example.com/app')],
    ['https://app.example.com/?', bareOrigin('https://app.example.com/?')],
    ['https://app.example.com?x=1', bareOrigin('https://app.example.com?x=1')],
    ['https://app.example.com#top', bareOrigin('https://app.example.com#top')],
    ['http://app.example.com', HTTPS_ONLY],
    ['ftp://app.example.com', HTTPS_ONLY],
    ['https://user:pw@app.example.com', NO_CREDENTIALS],
    ['*', ABSOLUTE_URL],
    ['null', ABSOLUTE_URL],
    ['app.example.com', ABSOLUTE_URL],
    ['https://a.example.com https://b.example.com', ABSOLUTE_URL],
    ['https://a.example.com, not-an-origin', ABSOLUTE_URL],
  ];
  for (const [value, message] of cases) {
    assertConfigError(
      () => loadConfig(env({ ALLOWED_ORIGINS: value })),
      'ALLOWED_ORIGINS',
      message,
    );
  }
});

Deno.test('ALLOWED_ORIGINS takes precedence over APP_URL and does not need it', () => {
  const config = loadConfig(env({
    ALLOWED_ORIGINS: 'https://a.example.com',
    APP_URL: 'http://app.example.com',
  }));
  assertEquals(config.allowedOrigins, ['https://a.example.com']);
  assertConfigError(() => config.appUrl(), 'APP_URL', HTTPS_ONLY);
});

Deno.test('without ALLOWED_ORIGINS the only allowed origin is the origin of APP_URL', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['https://app.example.com', 'https://app.example.com'],
    ['https://app.example.com/portal/', 'https://app.example.com'],
    ['HTTPS://APP.Example.COM:443/Portal', 'https://app.example.com'],
    ['http://localhost:54321/app', 'http://localhost:54321'],
  ];
  for (const [appUrl, origin] of cases) {
    assertEquals(loadConfig(env({ APP_URL: appUrl })).allowedOrigins, [origin], appUrl);
  }
});

Deno.test('an invalid APP_URL allows no browser origin instead of failing to load', () => {
  const cases = [
    'not a url',
    'http://app.example.com',
    'https://app.example.com/?',
    'https://app.example.com/#',
    'https://user@app.example.com',
  ];
  for (const appUrl of cases) {
    const config = loadConfig(env({ APP_URL: appUrl }));
    assertEquals(config.allowedOrigins, [], appUrl);
    assertConfigError(() => config.appUrl(), 'APP_URL');
  }
});

// --- APP_URL ---------------------------------------------------------------

Deno.test('APP_URL keeps its path, lower-cases its origin and drops trailing slashes', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['https://app.example.com', 'https://app.example.com'],
    ['  https://app.example.com/  ', 'https://app.example.com'],
    ['https://app.example.com/portal', 'https://app.example.com/portal'],
    ['https://app.example.com/portal/app//', 'https://app.example.com/portal/app'],
    ['HTTPS://APP.Example.COM:443/Portal/', 'https://app.example.com/Portal'],
    ['https://app.example.com:8443/', 'https://app.example.com:8443'],
    ['http://localhost:54321/', 'http://localhost:54321'],
    ['http://127.0.0.1:3000', 'http://127.0.0.1:3000'],
    ['http://[::1]:3000/app/', 'http://[::1]:3000/app'],
  ];
  for (const [value, appUrl] of cases) {
    assertEquals(loadConfig(env({ APP_URL: value })).appUrl(), appUrl, value);
  }
});

Deno.test('APP_URL rejects queries, fragments, other schemes, remote http and credentials', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    // URL itself drops an empty "?" or "#", so these are checked on the raw value.
    ['https://app.example.com/?', NO_QUERY],
    ['https://app.example.com/#', NO_QUERY],
    ['https://app.example.com?', NO_QUERY],
    ['https://app.example.com/invite?next=1', NO_QUERY],
    ['https://app.example.com/#/home', NO_QUERY],
    ['app.example.com', ABSOLUTE_URL],
    ['/invite', ABSOLUTE_URL],
    ['http://app.example.com', HTTPS_ONLY],
    ['http://127.0.0.2', HTTPS_ONLY],
    ['http://localhost.example.com', HTTPS_ONLY],
    ['ftp://app.example.com', HTTPS_ONLY],
    ['https://user@app.example.com', NO_CREDENTIALS],
    ['https://:secret@app.example.com', NO_CREDENTIALS],
    ['https://user:secret@app.example.com', NO_CREDENTIALS],
  ];
  for (const [value, message] of cases) {
    const config = loadConfig(env({ APP_URL: value }));
    assertConfigError(() => config.appUrl(), 'APP_URL', message);
  }
});

// --- Lazy feature settings -------------------------------------------------

interface FeatureCase {
  readonly feature: Feature;
  /** The variable a broken setup is reported under. */
  readonly variable: string;
  readonly invalid: Values;
  readonly valid: Values;
  readonly expected: unknown;
}

const FEATURES: readonly FeatureCase[] = [
  {
    feature: 'appUrl',
    variable: 'APP_URL',
    invalid: { APP_URL: 'http://app.example.com' },
    valid: { APP_URL: 'https://app.example.com/' },
    expected: 'https://app.example.com',
  },
  {
    feature: 'email',
    variable: 'MAIL_FROM',
    invalid: { RESEND_API_KEY: 're_test' },
    valid: { RESEND_API_KEY: 're_test', MAIL_FROM: 'invites@example.com' },
    expected: { apiKey: 're_test', from: 'invites@example.com', replyTo: null },
  },
  {
    feature: 'healthCheckToken',
    variable: 'HEALTH_CHECK_TOKEN',
    invalid: { HEALTH_CHECK_TOKEN: 'too-short' },
    valid: { HEALTH_CHECK_TOKEN: TOKEN },
    expected: TOKEN,
  },
  {
    feature: 'reauthMaxAgeSeconds',
    variable: 'REAUTH_MAX_AGE_SECONDS',
    invalid: { REAUTH_MAX_AGE_SECONDS: '59' },
    valid: { REAUTH_MAX_AGE_SECONDS: '900' },
    expected: 900,
  },
  {
    feature: 'storageCleanupToken',
    variable: 'STORAGE_CLEANUP_TOKEN',
    invalid: { STORAGE_CLEANUP_TOKEN: 'too-short' },
    valid: { STORAGE_CLEANUP_TOKEN: TOKEN },
    expected: TOKEN,
  },
];

Deno.test('a malformed feature setting fails only that feature, and only when it is read', () => {
  for (const { feature, variable, invalid } of FEATURES) {
    const config = loadConfig(env({ APP_URL: 'https://app.example.com', ...invalid }));
    assertConfigError(() => config[feature](), variable);
    for (const other of FEATURE_NAMES.filter((name) => name !== feature)) {
      config[other](); // does not throw
    }
  }
});

Deno.test('a feature setting throws again on every call until it parses, then is memoised', () => {
  for (const { feature, variable, invalid, valid, expected } of FEATURES) {
    let values: Values = invalid;
    const reads: string[] = [];
    const config = loadConfig((name) => {
      reads.push(name);
      return values[name];
    });
    reads.length = 0;

    assertConfigError(() => config[feature](), variable);
    const readsPerAttempt = reads.length;
    assertConfigError(() => config[feature](), variable);
    assertEquals(reads.length, 2 * readsPerAttempt, `${feature} is parsed again after a failure`);

    values = valid;
    const parsed = config[feature]();
    assertEquals(parsed, expected, feature);
    const readsWhenParsed = reads.length;
    values = invalid;
    assertStrictEquals(config[feature](), parsed, `${feature} keeps its first parse`);
    assertEquals(reads.length, readsWhenParsed, `${feature} is not read again once parsed`);
  }
});

// --- E-mail ----------------------------------------------------------------

Deno.test('e-mail is off without RESEND_API_KEY, whatever the sender settings hold', () => {
  const config = loadConfig(env({ MAIL_FROM: 'not an address', MAIL_REPLY_TO: 'nope' }));
  assertEquals(config.email(), null);
});

Deno.test('RESEND_API_KEY without MAIL_FROM is a configuration error', () => {
  const config = loadConfig(env({ RESEND_API_KEY: 're_test', MAIL_REPLY_TO: 'help@example.com' }));
  assertConfigError(() => config.email(), 'MAIL_FROM', 'is required when RESEND_API_KEY is set');
});

Deno.test('MAIL_FROM accepts an address or a display-name mailbox and keeps it as written', () => {
  const tld63 = `invites@example.${'a'.repeat(63)}`;
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['invites@example.com', 'invites@example.com'],
    ['  invites@example.com  ', 'invites@example.com'],
    ['Maalik-e-Makaan <invites@example.com>', 'Maalik-e-Makaan <invites@example.com>'],
    ['"Maalik, e-Makaan" <invites@example.com>', '"Maalik, e-Makaan" <invites@example.com>'],
    ['<invites@example.com>', '<invites@example.com>'],
    ['invites@mail.example.pk', 'invites@mail.example.pk'],
    [tld63, tld63],
  ];
  for (const [value, from] of cases) {
    const config = loadConfig(env({ RESEND_API_KEY: ' re_test ', MAIL_FROM: value }));
    assertEquals(config.email(), { apiKey: 're_test', from, replyTo: null }, value);
  }
});

Deno.test('MAIL_FROM must be exactly one mailbox', () => {
  const cases = [
    'not-an-address',
    'invites@example',
    'invites@example.c',
    `invites@example.${'a'.repeat(64)}`,
    'invites@example.c0m',
    'a@b@example.com',
    'Maalik invites@example.com',
    'Maalik <invites@example.com> extra',
    'Maalik <invites example@example.com>',
    'Maalik <<invites@example.com>>',
    'Maalik <>',
    'Maalik\r\nBcc: victim@example.com <invites@example.com>',
  ];
  for (const value of cases) {
    const config = loadConfig(env({ RESEND_API_KEY: 're_test', MAIL_FROM: value }));
    assertConfigError(() => config.email(), 'MAIL_FROM', MAILBOX);
  }
});

Deno.test('MAIL_REPLY_TO is optional and follows the mailbox rules', () => {
  const base = { RESEND_API_KEY: 're_test', MAIL_FROM: 'invites@example.com' };
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['help@example.com', 'help@example.com'],
    ['  Support <help@example.com> ', 'Support <help@example.com>'],
  ];
  for (const [value, replyTo] of cases) {
    const config = loadConfig(env({ ...base, MAIL_REPLY_TO: value }));
    assertEquals(config.email(), { apiKey: 're_test', from: 'invites@example.com', replyTo });
  }
  for (const value of ['nope', 'Support help@example.com', 'help@example']) {
    const config = loadConfig(env({ ...base, MAIL_REPLY_TO: value }));
    assertConfigError(() => config.email(), 'MAIL_REPLY_TO', MAILBOX);
  }
});

// --- Tokens and the re-authentication age ------------------------------------

Deno.test('the health and storage-cleanup tokens need at least 32 characters', () => {
  assertEquals(MIN_TOKEN_LENGTH, 32);
  const tokens: ReadonlyArray<readonly [Feature, string]> = [
    ['healthCheckToken', 'HEALTH_CHECK_TOKEN'],
    ['storageCleanupToken', 'STORAGE_CLEANUP_TOKEN'],
  ];
  const t31 = 'x'.repeat(31);
  const t32 = 'x'.repeat(32);
  for (const [feature, variable] of tokens) {
    assertEquals(loadConfig(env({}))[feature](), null, `${variable} unset`);
    assertEquals(loadConfig(env({ [variable]: t32 }))[feature](), t32, `${variable} of 32`);
    assertEquals(loadConfig(env({ [variable]: ` ${t32}\n` }))[feature](), t32, 'trimmed');
    for (const value of [t31, ` ${t31} `, 'short']) {
      const config = loadConfig(env({ [variable]: value }));
      assertConfigError(() => config[feature](), variable, TOKEN_LENGTH);
    }
  }
});

Deno.test('REAUTH_MAX_AGE_SECONDS is a whole number from 60 to 3600, 600 by default', () => {
  const accepted: ReadonlyArray<readonly [string | undefined, number]> = [
    [undefined, 600],
    ['', 600],
    ['60', 60],
    ['600', 600],
    [' 900 ', 900],
    ['3600', 3600],
  ];
  for (const [value, seconds] of accepted) {
    const values: Values = value === undefined ? {} : { REAUTH_MAX_AGE_SECONDS: value };
    assertEquals(loadConfig(env(values)).reauthMaxAgeSeconds(), seconds, String(value));
  }
  for (const value of ['59', '3601', '0', '-600', '1.5', '599.5', 'abc', '600s', 'Infinity']) {
    const config = loadConfig(env({ REAUTH_MAX_AGE_SECONDS: value }));
    assertConfigError(() => config.reauthMaxAgeSeconds(), 'REAUTH_MAX_AGE_SECONDS', REAUTH_RANGE);
  }
});

// --- configFromValues --------------------------------------------------------

Deno.test('configFromValues defaults every setting like an empty environment', () => {
  const config = configFromValues({});
  assertEquals(config.allowedOrigins, []);
  assertConfigError(() => config.appUrl(), 'APP_URL', 'is required for invitations');
  assertEquals(config.email(), null);
  assertEquals(config.healthCheckToken(), null);
  assertEquals(config.reauthMaxAgeSeconds(), 600);
  assertEquals(config.storageCleanupToken(), null);
});

Deno.test('configFromValues returns the values it was given', () => {
  const allowedOrigins = ['https://app.example.com'];
  const email = { apiKey: 're_test', from: 'invites@example.com', replyTo: null };
  const config = configFromValues({
    allowedOrigins,
    appUrl: 'https://app.example.com/portal',
    email,
    healthCheckToken: TOKEN,
    reauthMaxAgeSeconds: 120,
    storageCleanupToken: `${TOKEN}-cleanup`,
  });
  assertStrictEquals(config.allowedOrigins, allowedOrigins);
  assertEquals(config.appUrl(), 'https://app.example.com/portal');
  assertStrictEquals(config.email(), email);
  assertEquals(config.healthCheckToken(), TOKEN);
  assertEquals(config.reauthMaxAgeSeconds(), 120);
  assertEquals(config.storageCleanupToken(), `${TOKEN}-cleanup`);
});

Deno.test('configFromValues throws a given ConfigError from its accessor on every call', () => {
  const error = new ConfigError('SOME_SECRET', 'is broken');
  const cases: ReadonlyArray<readonly [Feature, ConfigValues]> = [
    ['appUrl', { appUrl: error }],
    ['email', { appUrl: 'https://app.example.com', email: error }],
    ['healthCheckToken', { appUrl: 'https://app.example.com', healthCheckToken: error }],
    ['reauthMaxAgeSeconds', { appUrl: 'https://app.example.com', reauthMaxAgeSeconds: error }],
    ['storageCleanupToken', { appUrl: 'https://app.example.com', storageCleanupToken: error }],
  ];
  for (const [feature, values] of cases) {
    const config = configFromValues(values);
    for (let call = 1; call <= 2; call++) {
      assertStrictEquals(assertThrows(() => config[feature](), ConfigError), error, feature);
    }
    for (const other of FEATURE_NAMES.filter((name) => name !== feature)) {
      config[other](); // does not throw
    }
  }
});
