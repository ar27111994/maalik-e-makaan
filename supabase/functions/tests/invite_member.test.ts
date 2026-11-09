/**
 * invite-member: POST { portfolio_id, email, role, locale? } creates the invitation as the
 * caller through create_invitation and answers 201 with its link. E-mailing the link is
 * best effort: the outcome is reported as email_delivery and never fails the invitation.
 */

import { assert, assertEquals, assertFalse, assertMatch, assertStrictEquals } from '@std/assert';
import { stub } from '@std/testing/mock';
import {
  ConfigError,
  type EmailConfig,
  type FunctionConfig,
  loadConfig,
} from '../_shared/config.ts';
import { sha256Hex } from '../_shared/crypto.ts';
import { EmailDeliveryError, type EmailMessage, RESEND_ENDPOINT } from '../_shared/email.ts';
import { defaultDeps } from '../_shared/handler.ts';
import { SECURITY_HEADERS } from '../_shared/http.ts';
import type { LogRecord } from '../_shared/log.ts';
import {
  type InvitationEmailInput,
  type Locale,
  renderInvitationEmail,
  SUBJECTS,
} from '../invite-member/email.ts';
import {
  buildInviteUrl,
  canonicalMailbox,
  createInviteMemberHandler,
  defaultInviteDeps,
  EMAIL_LIMITS,
  type EmailDelivery,
  INVITE_ROLES,
  type InviteMemberDeps,
  LOCALES,
} from '../invite-member/handler.ts';
import server from '../invite-member/index.ts';
import {
  APP_ORIGIN,
  type Call,
  type ContextOptions,
  errorOf,
  fakeClient,
  fakeContext,
  harness,
  logText,
  OTHER_PORTFOLIO_ID,
  PORTFOLIO_ID,
  request,
  REQUEST_ID,
  type RequestOptions,
  type Result,
  testConfig,
  USER_ID,
} from './_helpers.ts';

const FN = 'invite-member';
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const INVITATION_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0';
/**
 * The secret half of the token. Real verifiers are base64url, which encodeURIComponent
 * leaves alone; this one has '+', '/' and '=' so that the encoded form differs.
 */
const VERIFIER = 'q83v+EjRW/eJCrze=';
const TOKEN = `${INVITATION_ID}.${VERIFIER}`;
const INVITE_URL = `${APP_ORIGIN}/invite#token=${INVITATION_ID}.q83v%2BEjRW%2FeJCrze%3D`;
/** As Postgres writes a timestamptz into JSON. */
const EXPIRES_AT = '2026-11-10T12:00:00.123456+00:00';
const PORTFOLIO_NAME = 'Raza Family Properties';
const INVITER_NAME = 'Ahmed Raza';
/** The caller's verified address (fakeContext's default claims). */
const INVITER_EMAIL = 'owner@example.com';
const OTHER_USER_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a94';
/** The invitee as typed: mixed case, an alias of a Gmail mailbox. */
const TYPED_EMAIL = 'Imran.Khan+Rent@GoogleMail.com';
/** The invitee as validated (trimmed, lower-cased) and stored by create_invitation. */
const INVITEE = 'imran.khan+rent@googlemail.com';
/** The mailbox the invitee's address delivers to, and its SHA-256: the recipient's quota. */
const MAILBOX = 'imrankhan@gmail.com';
const MAILBOX_SHA256 = 'eff2757f0ff267da1b36a6e86b06626a4ea562ea7340b69ebd0c7cbe520da0c3';
const EMAIL: EmailConfig = {
  apiKey: 're_test_key',
  from: 'Maalik-e-Makaan <invites@example.com>',
  replyTo: null,
};
const BODY = { portfolio_id: PORTFOLIO_ID, email: TYPED_EMAIL, role: 'manager' };

/** Headers of every JSON answer to a request without an Origin (the mobile app). */
const JSON_HEADERS = {
  ...SECURITY_HEADERS,
  'content-type': 'application/json; charset=utf-8',
  vary: 'Origin',
  'x-request-id': REQUEST_ID,
};

// --- the function under test ---------------------------------------------------------

interface Script {
  /** Default: e-mail on, APP_URL = APP_ORIGIN. */
  readonly config?: FunctionConfig;
  /** The caller's claims (null: no session). */
  readonly user?: ContextOptions['user'];
  readonly jwtClaims?: ContextOptions['jwtClaims'];
  /** create_invitation's answer (default: the invitation, echoing the address and role). */
  readonly invitation?: (args: Record<string, unknown>) => Result;
  /** The row of PORTFOLIO_ID; no other portfolio exists. */
  readonly portfolio?: Result;
  /** The profile of USER_ID; no other profile exists. */
  readonly profile?: Result;
  /** The limiter's answers to successive hits; within the limit after them. */
  readonly limits?: readonly Result[];
  /** The provider (default: accepts the message). */
  readonly send?: (message: EmailMessage) => Promise<{ id: string }>;
}

function invitationRow(args: Record<string, unknown>): Record<string, unknown> {
  return {
    invitation_id: INVITATION_ID,
    email: args['p_email'],
    role: args['p_role'],
    expires_at: EXPIRES_AT,
    token: TOKEN,
  };
}

function setup(script: Script = {}) {
  /** Every call to the database and the provider, across clients, in order. */
  const timeline: string[] = [];
  const user = fakeClient({
    rpc: (fn, args) => {
      timeline.push(`rpc ${fn}`);
      return script.invitation?.(args) ?? { data: invitationRow(args) };
    },
    select: (table, query) => {
      timeline.push(`select ${table}`);
      // Rows exist under the expected ids only: a lookup by any other id finds nothing.
      if (table === 'portfolios' && query.filters['id'] === PORTFOLIO_ID) {
        return script.portfolio ?? { data: { name: PORTFOLIO_NAME } };
      }
      if (table === 'profiles' && query.filters['id'] === USER_ID) {
        return script.profile ?? { data: { full_name: INVITER_NAME } };
      }
      return { data: null };
    },
  });
  const limits = [...(script.limits ?? [])];
  const admin = fakeClient({
    rpc: (fn, args) => {
      timeline.push(`rpc ${fn} ${args['p_key']}`);
      return limits.shift() ?? { data: ALLOW };
    },
  });
  const h = harness({
    config: script.config ?? testConfig({ email: EMAIL }),
    context: fakeContext({
      supabase: user,
      supabaseAdmin: admin,
      user: script.user,
      jwtClaims: script.jwtClaims,
    }),
  });
  const senders: EmailConfig[] = [];
  const sent: EmailMessage[] = [];
  const deps: InviteMemberDeps = {
    ...h.deps,
    createSender: (config) => {
      timeline.push('createSender');
      senders.push(config);
      return {
        send: (message) => {
          timeline.push('send');
          sent.push(message);
          return script.send?.(message) ?? Promise.resolve({ id: 'msg_1' });
        },
      };
    },
  };
  const handler = createInviteMemberHandler(deps);
  return {
    user,
    admin,
    timeline,
    senders,
    sent,
    logs: h.logs,
    contextRequests: h.contextRequests,
    /** Sends [req] while the pipeline's clock stands still (duration_ms 0). */
    send: async (req: Request = invite()): Promise<Response> => {
      const now = stub(performance, 'now', () => 1_000);
      try {
        return await handler(req);
      } finally {
        now.restore();
      }
    },
  };
}

/** The caller's POST of [body]. */
function invite(body: unknown = BODY, options: RequestOptions = {}): Request {
  return request({ method: 'POST', body, ...options });
}

function without(field: keyof typeof BODY): Record<string, unknown> {
  const body: Record<string, unknown> = { ...BODY };
  delete body[field];
  return body;
}

// --- what a request is expected to do ------------------------------------------------------

function createCall(role = 'manager', portfolioId = PORTFOLIO_ID): Call {
  return {
    kind: 'rpc',
    args: ['create_invitation', { p_portfolio_id: portfolioId, p_email: INVITEE, p_role: role }],
  };
}

/** The portfolio's name and the caller's full name, read as the caller. */
function lookupCalls(portfolioId = PORTFOLIO_ID, userId = USER_ID): Call[] {
  return [
    {
      kind: 'select',
      args: [
        'portfolios',
        'name',
        { filters: { id: portfolioId }, limit: null, columns: 'name' },
        undefined,
      ],
    },
    {
      kind: 'select',
      args: [
        'profiles',
        'full_name',
        { filters: { id: userId }, limit: null, columns: 'full_name' },
        undefined,
      ],
    },
  ];
}

/** The limiter's verdicts (public.admin_rate_limit_hit). */
const ALLOW = { allowed: true, retry_after_seconds: 3600 };
const DENY = { allowed: false, retry_after_seconds: 3600 };

const RECIPIENT_KEY = `invite_email:to:${MAILBOX_SHA256}`;
const INVITER_KEY = `invite_email:user:${USER_ID}`;

function hitCall(key: string, limit: number): Call {
  return {
    kind: 'rpc',
    args: ['admin_rate_limit_hit', { p_key: key, p_limit: limit, p_window_seconds: 3600 }],
  };
}

const RECIPIENT_HIT = hitCall(RECIPIENT_KEY, 3);
const INVITER_HIT = hitCall(INVITER_KEY, 10);

/** The 201 answer. */
function created(delivery: EmailDelivery, overrides: Record<string, unknown> = {}) {
  return {
    invitation_id: INVITATION_ID,
    email: INVITEE,
    role: 'manager',
    expires_at: EXPIRES_AT,
    invite_url: INVITE_URL,
    email_delivery: delivery,
    ...overrides,
  };
}

/** The e-mail the provider should be handed. */
function expectedEmail(overrides: Partial<InvitationEmailInput> = {}): EmailMessage {
  return renderInvitationEmail({
    invitationId: INVITATION_ID,
    recipient: INVITEE,
    role: 'manager',
    expiresAt: new Date(EXPIRES_AT),
    inviteUrl: INVITE_URL,
    portfolioName: PORTFOLIO_NAME,
    inviterName: INVITER_NAME,
    inviterEmail: INVITER_EMAIL,
    locale: 'en',
    ...overrides,
  });
}

function createdLog(
  delivery: EmailDelivery,
  role = 'manager',
  portfolioId = PORTFOLIO_ID,
): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    invitation_id: INVITATION_ID,
    portfolio_id: portfolioId,
    role,
    delivery,
    level: 'info',
    event: 'invitation_created',
  };
}

function accessLog(status: number, userId: string | null = USER_ID, method = 'POST'): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    method,
    status,
    duration_ms: 0,
    user_id: userId,
    level: 'info',
    event: 'request',
  };
}

function rejectedLog(code: string, details?: Record<string, unknown>): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    code,
    details,
    level: 'warn',
    event: 'request_rejected',
  };
}

function failedLog(code: string, error: Record<string, unknown>): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, code, error, level: 'error', event: 'request_failed' };
}

function emailFailedLog(error: Record<string, unknown>): LogRecord {
  return {
    fn: FN,
    request_id: REQUEST_ID,
    invitation_id: INVITATION_ID,
    error,
    level: 'warn',
    event: 'invitation_email_failed',
  };
}

function misconfiguredLog(variable: string): LogRecord {
  return { fn: FN, request_id: REQUEST_ID, variable, level: 'error', event: 'email_misconfigured' };
}

/** An Error as the logger records it. */
function logged(name: string, message: string, cause?: unknown): Record<string, unknown> {
  return { name, message, cause };
}

/** The token in every form and the invitee's address in every form: never logged. */
const NEVER_LOGGED = [
  TOKEN,
  VERIFIER,
  encodeURIComponent(TOKEN),
  encodeURIComponent(VERIFIER),
  INVITE_URL,
  TYPED_EMAIL,
  INVITEE,
  MAILBOX,
  'imran',
];

function assertNothingSecretLogged(logs: readonly LogRecord[], label: string): void {
  const text = logText(logs).toLowerCase();
  for (const secret of NEVER_LOGGED) {
    assertFalse(text.includes(secret.toLowerCase()), `${label}: ${secret}`);
  }
}

// --- a successful invitation ---------------------------------------------------------------------

Deno.test('POST creates the invitation as the caller, e-mails the link and answers 201 with it', async () => {
  const t = setup();
  const res = await t.send();
  assertEquals(res.status, 201);
  assertEquals(Object.fromEntries(res.headers), JSON_HEADERS);
  assertEquals(await res.json(), created('sent'));

  // As the caller: the invitation, then the invited portfolio's name and the caller's own
  // name, by id.
  assertEquals(t.user.calls, [createCall(), ...lookupCalls()]);
  // With the secret key: the quotas, the recipient's (its hashed mailbox) before the inviter's.
  assertEquals(t.admin.calls, [RECIPIENT_HIT, INVITER_HIT]);
  // The quotas are charged only once the message is rendered, and the provider is called last.
  assertEquals(t.timeline, [
    'rpc create_invitation',
    'select portfolios',
    'select profiles',
    `rpc admin_rate_limit_hit ${RECIPIENT_KEY}`,
    `rpc admin_rate_limit_hit ${INVITER_KEY}`,
    'createSender',
    'send',
  ]);
  assertEquals(t.senders, [EMAIL]);
  assertEquals(t.sent, [expectedEmail()]);
  assertEquals(t.logs, [createdLog('sent'), accessLog(201)]);
  assertNothingSecretLogged(t.logs, 'sent');
});

Deno.test('the function asks the pipeline for a user session: auth "user"', async () => {
  const t = setup();
  const req = invite();
  assertEquals((await t.send(req)).status, 201);
  assertEquals(t.contextRequests.length, 1);
  assertStrictEquals(t.contextRequests[0]?.req, req);
  assertEquals(t.contextRequests[0]?.auth, 'user');
});

Deno.test('the portfolio id, address and role are normalised before create_invitation', async () => {
  const t = setup();
  const res = await t.send(invite({
    portfolio_id: ` ${PORTFOLIO_ID.toUpperCase()} `,
    email: `  ${TYPED_EMAIL}\t`,
    role: ' manager ',
  }));
  assertEquals(await res.json(), created('sent'));
  assertEquals(t.user.calls, [createCall(), ...lookupCalls()]);
  assertEquals(t.sent, [expectedEmail()]);
});

Deno.test('each invitable role reaches create_invitation, the answer and the e-mail', async () => {
  assertEquals(INVITE_ROLES, ['owner', 'manager', 'accountant', 'viewer']);
  for (const role of INVITE_ROLES) {
    const t = setup();
    const res = await t.send(invite({ ...BODY, role }));
    assertEquals(await res.json(), created('sent', { role }), role);
    assertEquals(t.user.calls[0], createCall(role), role);
    assertEquals(t.sent, [expectedEmail({ role })], role);
    assertEquals(t.logs, [createdLog('sent', role), accessLog(201)], role);
  }
});

Deno.test('the locale picks the language the e-mail opens with: en unless ur is asked for', async () => {
  assertEquals(LOCALES, ['en', 'ur']);
  const cases: Array<[string, unknown, Locale]> = [
    ['absent', undefined, 'en'],
    ['null', null, 'en'],
    ['en', 'en', 'en'],
    ['ur', 'ur', 'ur'],
  ];
  for (const [label, locale, expected] of cases) {
    const t = setup();
    const res = await t.send(invite({ ...BODY, locale }));
    assertEquals(await res.json(), created('sent'), label);
    assertEquals(t.sent, [expectedEmail({ locale: expected })], label);
    assertEquals(t.sent[0]?.subject, SUBJECTS[expected], label);
  }
});

Deno.test('the inviter is named by their profile and their verified address, whichever exist', async () => {
  const cases: Array<[string, Script, Partial<InvitationEmailInput>]> = [
    ['no address in the claims', { user: { email: undefined } }, { inviterEmail: null }],
    ['an empty address (a phone sign-in)', { user: { email: '' } }, { inviterEmail: '' }],
    ['no profile row', { profile: { data: null } }, { inviterName: '' }],
    ['no full name', { profile: { data: { full_name: null } } }, { inviterName: '' }],
    ['a full name that is not text', { profile: { data: { full_name: 42 } } }, {
      inviterName: '',
    }],
    // The name is optional, so a failed profile lookup does not stop the e-mail.
    ['a failed profile lookup', {
      profile: {
        error: { code: '57014', message: 'canceling statement due to statement timeout' },
      },
    }, { inviterName: '' }],
  ];
  for (const [label, script, input] of cases) {
    const t = setup(script);
    const res = await t.send();
    assertEquals(await res.json(), created('sent'), label);
    assertEquals(t.sent, [expectedEmail(input)], label);
  }
});

Deno.test('the lookups read the invited portfolio and the calling user, by id', async () => {
  // Another portfolio is looked up by its own id (and, here, not found).
  const other = setup();
  const res = await other.send(invite({ ...BODY, portfolio_id: OTHER_PORTFOLIO_ID }));
  assertEquals(await res.json(), created('failed'));
  assertEquals(other.user.calls, [
    createCall('manager', OTHER_PORTFOLIO_ID),
    ...lookupCalls(OTHER_PORTFOLIO_ID),
  ]);
  assertEquals(other.admin.calls, []);

  // Another caller: their own profile is read (here, without a name) and their quota charged.
  const t = setup({
    user: { id: OTHER_USER_ID, email: 'partner@example.com' },
    jwtClaims: { sub: OTHER_USER_ID },
  });
  assertEquals(await (await t.send()).json(), created('sent'));
  assertEquals(t.user.calls, [createCall(), ...lookupCalls(PORTFOLIO_ID, OTHER_USER_ID)]);
  assertEquals(t.admin.calls, [RECIPIENT_HIT, hitCall(`invite_email:user:${OTHER_USER_ID}`, 10)]);
  assertEquals(t.sent, [expectedEmail({ inviterName: '', inviterEmail: 'partner@example.com' })]);
  assertEquals(t.logs.at(-1), accessLog(201, OTHER_USER_ID));
});

// --- refusals before an invitation exists ---------------------------------------------------------

Deno.test('only POST is served: other methods get 405 before authentication', async () => {
  for (const method of ['GET', 'HEAD', 'PUT', 'PATCH', 'DELETE']) {
    const t = setup();
    const res = await t.send(request({ method }));
    assertEquals(res.status, 405, method);
    assertEquals(res.headers.get('allow'), 'POST, OPTIONS', method);
    if (method === 'HEAD') {
      assertEquals(await res.text(), '', method);
    } else {
      assertEquals(await errorOf(res), {
        code: 'method_not_allowed',
        message: 'Use POST.',
        request_id: REQUEST_ID,
      }, method);
    }
    assertEquals(t.contextRequests, [], method);
    assertEquals([t.user.calls, t.admin.calls], [[], []], method);
    assertEquals(t.logs, [rejectedLog('method_not_allowed'), accessLog(405, null, method)], method);
  }
});

Deno.test('a preflight from the app origin is answered 204 for POST, without authentication', async () => {
  const t = setup();
  const res = await t.send(request({
    method: 'OPTIONS',
    origin: APP_ORIGIN,
    token: null,
    headers: { 'access-control-request-method': 'POST' },
  }));
  assertEquals(res.status, 204);
  assertEquals(res.headers.get('access-control-allow-origin'), APP_ORIGIN);
  assertEquals(res.headers.get('access-control-allow-methods'), 'POST, OPTIONS');
  assertEquals(t.contextRequests, []);
  assertEquals(t.logs, [accessLog(204, null, 'OPTIONS')]);
});

Deno.test('only a signed-in account holder may invite: create_invitation is not reached otherwise', async () => {
  type Envelope = { code: string; message: string; details?: Record<string, unknown> };
  const cases: Array<[string, Script, number, Envelope, string | null]> = [
    ['no session', { user: null }, 401, {
      code: 'unauthorized',
      message: 'Sign in to continue.',
    }, null],
    ['an anonymous sign-in', { jwtClaims: { is_anonymous: true } }, 403, {
      code: 'forbidden',
      message: 'Create an account to do this.',
      details: { reason: 'anonymous_user' },
    }, USER_ID],
    ['a connected app', { jwtClaims: { client_id: 'third-party-app' } }, 403, {
      code: 'forbidden',
      message: 'Connected apps cannot do this.',
      details: { reason: 'oauth_client_token' },
    }, USER_ID],
  ];
  for (const [label, script, status, error, userId] of cases) {
    const t = setup(script);
    const res = await t.send();
    assertEquals(res.status, status, label);
    assertEquals(
      res.headers.get('www-authenticate'),
      status === 401 ? 'Bearer' : null,
      label,
    );
    assertEquals(await errorOf(res), { ...error, request_id: REQUEST_ID }, label);
    assertEquals([t.user.calls, t.admin.calls], [[], []], label);
    assertEquals(t.logs, [
      rejectedLog(error.code, error.details),
      accessLog(status, userId),
    ], label);
  }
});

Deno.test('an invalid body is refused before create_invitation', async () => {
  const cases: Array<[string, Request, number, string, Record<string, unknown> | undefined]> = [
    ['an unknown field', invite({ ...BODY, admin: true }), 422, 'validation_failed', {
      field: 'admin',
      reason: 'unknown_field',
    }],
    ['no portfolio_id', invite(without('portfolio_id')), 422, 'validation_failed', {
      field: 'portfolio_id',
      reason: 'required',
    }],
    [
      'a portfolio_id that is not a UUID',
      invite({ ...BODY, portfolio_id: 'nope' }),
      422,
      'validation_failed',
      {
        field: 'portfolio_id',
        reason: 'not_a_uuid',
      },
    ],
    ['a numeric portfolio_id', invite({ ...BODY, portfolio_id: 42 }), 422, 'validation_failed', {
      field: 'portfolio_id',
      reason: 'not_a_string',
    }],
    ['no email', invite(without('email')), 422, 'validation_failed', {
      field: 'email',
      reason: 'required',
    }],
    [
      'an address without a domain',
      invite({ ...BODY, email: 'imran@' }),
      422,
      'validation_failed',
      {
        field: 'email',
        reason: 'not_an_email',
      },
    ],
    [
      'an address with a bidi override',
      invite({ ...BODY, email: 'imran\u202e@example.com' }),
      422,
      'validation_failed',
      {
        field: 'email',
        reason: 'forbidden_characters',
      },
    ],
    ['no role', invite(without('role')), 422, 'validation_failed', {
      field: 'role',
      reason: 'required',
    }],
    ['an unknown role', invite({ ...BODY, role: 'superuser' }), 422, 'validation_failed', {
      field: 'role',
      reason: 'not_allowed',
    }],
    ['a role in the wrong case', invite({ ...BODY, role: 'Owner' }), 422, 'validation_failed', {
      field: 'role',
      reason: 'not_allowed',
    }],
    ['an unknown locale', invite({ ...BODY, locale: 'fr' }), 422, 'validation_failed', {
      field: 'locale',
      reason: 'not_allowed',
    }],
    ['a locale in the wrong case', invite({ ...BODY, locale: 'UR' }), 422, 'validation_failed', {
      field: 'locale',
      reason: 'not_allowed',
    }],
    ['a body that is not an object', invite('[]'), 422, 'validation_failed', {
      field: '$',
      reason: 'not_an_object',
    }],
    ['malformed JSON', invite('{"portfolio_id":'), 400, 'invalid_json', undefined],
    [
      'a body that is not JSON',
      invite('portfolio_id=1', {
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
      }),
      415,
      'unsupported_media_type',
      undefined,
    ],
  ];
  for (const [label, req, status, code, details] of cases) {
    const t = setup();
    const res = await t.send(req);
    assertEquals(res.status, status, label);
    const error = await errorOf(res);
    assertEquals([error.code, error.details], [code, details], label);
    assertEquals([t.user.calls, t.admin.calls, t.senders], [[], [], []], label);
    assertEquals(t.logs, [rejectedLog(code, details), accessLog(status)], label);
  }
});

Deno.test('an unusable APP_URL is a 500 server_misconfigured naming it, before create_invitation', async () => {
  const env = (vars: Record<string, string>) =>
    loadConfig((name) =>
      ({ RESEND_API_KEY: 're_test_key', MAIL_FROM: 'invites@example.com', ...vars })[name]
    );
  const cases: Array<[string, FunctionConfig, string]> = [
    ['unset', env({}), 'APP_URL: is required for invitations'],
    [
      'not https',
      env({ APP_URL: 'http://app.example.com' }),
      'APP_URL: must use https (http is allowed for localhost only)',
    ],
    [
      'with a fragment',
      env({ APP_URL: 'https://app.example.com/#' }),
      'APP_URL: must not contain a query or fragment',
    ],
    [
      'a ConfigError from the configuration',
      testConfig({ email: EMAIL, appUrl: new ConfigError('APP_URL', 'is not reachable') }),
      'APP_URL: is not reachable',
    ],
  ];
  for (const [label, config, message] of cases) {
    const t = setup({ config });
    const res = await t.send();
    assertEquals(res.status, 500, label);
    assertEquals(await errorOf(res), {
      code: 'server_misconfigured',
      message: 'The service is not configured correctly.',
      details: { variable: 'APP_URL' },
      request_id: REQUEST_ID,
    }, label);
    assertEquals([t.user.calls, t.admin.calls, t.senders], [[], [], []], label);
    assertEquals(t.logs, [
      failedLog('server_misconfigured', logged('ConfigError', message)),
      accessLog(500),
    ], label);
  }
});

Deno.test('create_invitation refusals keep their meaning, and nothing is looked up or e-mailed', async () => {
  const cases: Array<
    [string, Result, number, string, Record<string, string>, Record<string, unknown> | undefined]
  > = [
    [
      'not an owner of the portfolio (42501)',
      { error: { code: '42501', message: 'forbidden', details: null, hint: null }, status: 403 },
      403,
      'forbidden',
      {},
      undefined,
    ],
    [
      'the database limit of 20 an hour (429, hint 3600)',
      {
        error: {
          code: 'rate_limited',
          message: 'Too many requests. Please wait a moment and try again.',
          details: 'create_invitation',
          hint: '3600',
        },
        status: 429,
      },
      429,
      'rate_limited',
      { 'retry-after': '3600' },
      undefined,
    ],
    [
      'already a member (22023)',
      {
        error: { code: '22023', message: 'already_member', details: 'already_member', hint: null },
        status: 400,
      },
      422,
      'validation_failed',
      {},
      { reason: 'already_member' },
    ],
    [
      'an expired session (PGRST301)',
      {
        error: { code: 'PGRST301', message: 'JWT expired', details: null, hint: null },
        status: 401,
      },
      401,
      'unauthorized',
      { 'www-authenticate': 'Bearer' },
      { reason: 'PGRST301' },
    ],
  ];
  for (const [label, answer, status, code, headers, details] of cases) {
    const t = setup({ invitation: () => answer });
    const res = await t.send();
    assertEquals(res.status, status, label);
    assertEquals(Object.fromEntries(res.headers), { ...JSON_HEADERS, ...headers }, label);
    const error = await errorOf(res);
    assertEquals([error.code, error.details], [code, details], label);
    assertEquals(t.user.calls, [createCall()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [rejectedLog(code, details), accessLog(status)], label);
  }
});

Deno.test('create_invitation failing on the database side is a 503 when transient, else a 502', async () => {
  const cases: Array<[string, Record<string, unknown>, number, string, string, string | null]> = [
    [
      'a serialisation failure',
      { code: '40001', message: 'could not serialize access', details: null, hint: null },
      503,
      'temporarily_unavailable',
      'The service is busy. Please try again.',
      '1',
    ],
    [
      'an internal error',
      { code: 'XX000', message: 'internal error', details: null, hint: null },
      502,
      'upstream_error',
      'The database could not complete the request.',
      null,
    ],
  ];
  for (const [label, failure, status, code, message, retryAfter] of cases) {
    const t = setup({ invitation: () => ({ error: failure, status: 500 }) });
    const res = await t.send();
    assertEquals(res.status, status, label);
    assertEquals(res.headers.get('retry-after'), retryAfter, label);
    assertEquals(await errorOf(res), { code, message, request_id: REQUEST_ID }, label);
    assertEquals(t.user.calls, [createCall()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [
      failedLog(code, logged('HttpError', message, failure)),
      accessLog(status),
    ], label);
  }
});

Deno.test('a create_invitation answer without every field as text is a 502 upstream_error', async () => {
  const complete = invitationRow({ p_email: INVITEE, p_role: 'manager' });
  const cases: Array<[string, unknown]> = [
    ['null', null],
    ['a string', 'ok'],
    ['an array', [complete]],
  ];
  for (const field of Object.keys(complete)) {
    cases.push([`no ${field}`, { ...complete, [field]: undefined }]);
    cases.push([`a numeric ${field}`, { ...complete, [field]: 7 }]);
  }
  for (const [label, data] of cases) {
    const t = setup({ invitation: () => ({ data }) });
    const res = await t.send();
    assertEquals(res.status, 502, label);
    assertEquals(await errorOf(res), {
      code: 'upstream_error',
      message: 'The invitation could not be created.',
      request_id: REQUEST_ID,
    }, label);
    assertEquals(t.user.calls, [createCall()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [
      failedLog(
        'upstream_error',
        logged(
          'HttpError',
          'The invitation could not be created.',
          logged('Error', 'unexpected create_invitation response'),
        ),
      ),
      accessLog(502),
    ], label);
    assertNothingSecretLogged(t.logs, label);
  }
});

// --- e-mail delivery: never fails the invitation ---------------------------------------------------

Deno.test('without e-mail configured the link is returned as not_configured, and no quota is charged', async () => {
  const cases: Array<[string, FunctionConfig]> = [
    ['email() is null', testConfig({ email: null })],
    ['RESEND_API_KEY is unset', loadConfig((name) => ({ APP_URL: `${APP_ORIGIN}/` })[name])],
  ];
  for (const [label, config] of cases) {
    const t = setup({ config });
    const res = await t.send();
    assertEquals(res.status, 201, label);
    assertEquals(await res.json(), created('not_configured'), label);
    assertEquals(t.user.calls, [createCall()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [createdLog('not_configured'), accessLog(201)], label);
  }
});

Deno.test('a broken e-mail setup fails delivery only: email_misconfigured names the variable', async () => {
  const env = (vars: Record<string, string>) =>
    loadConfig((name) => ({ APP_URL: APP_ORIGIN, RESEND_API_KEY: 're_test_key', ...vars })[name]);
  const cases: Array<[string, FunctionConfig, string]> = [
    ['MAIL_FROM unset', env({}), 'MAIL_FROM'],
    ['MAIL_FROM not an address', env({ MAIL_FROM: 'invites' }), 'MAIL_FROM'],
    [
      'MAIL_REPLY_TO not an address',
      env({ MAIL_FROM: 'invites@example.com', MAIL_REPLY_TO: 'support' }),
      'MAIL_REPLY_TO',
    ],
    [
      'a ConfigError from the configuration',
      testConfig({ email: new ConfigError('RESEND_API_KEY', 'is revoked') }),
      'RESEND_API_KEY',
    ],
  ];
  for (const [label, config, variable] of cases) {
    const t = setup({ config });
    const res = await t.send();
    assertEquals(res.status, 201, label);
    assertEquals(await res.json(), created('failed'), label);
    // Nothing is looked up, charged or sent.
    assertEquals(t.user.calls, [createCall()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [
      misconfiguredLog(variable),
      createdLog('failed'),
      accessLog(201),
    ], label);
  }
});

Deno.test('settings that cannot be read at all are failed delivery too: 201, the error logged', async () => {
  const config: FunctionConfig = {
    ...testConfig({ email: EMAIL }),
    email: () => {
      throw new TypeError('email settings unreadable');
    },
  };
  const t = setup({ config });
  const res = await t.send();
  assertEquals(res.status, 201);
  assertEquals(await res.json(), created('failed'));
  assertEquals(t.user.calls, [createCall()]);
  assertEquals([t.admin.calls, t.senders], [[], []]);
  assertEquals(t.logs, [
    {
      fn: FN,
      request_id: REQUEST_ID,
      error: logged('TypeError', 'email settings unreadable'),
      level: 'error',
      event: 'email_misconfigured',
    },
    createdLog('failed'),
    accessLog(201),
  ]);
});

Deno.test('when the portfolio cannot be read, delivery fails before any quota is charged', async () => {
  const cases: Array<[string, Result]> = [
    ['a failed lookup', {
      error: { code: '42501', message: 'permission denied for table portfolios' },
    }],
    // The error decides, even beside a row.
    ['a failed lookup that still carries a row', {
      data: { name: PORTFOLIO_NAME },
      error: { code: '57014', message: 'canceling statement due to statement timeout' },
    }],
    ['no row', { data: null }],
    ['no name', { data: { name: null } }],
    ['a name that is not text', { data: { name: 42 } }],
  ];
  for (const [label, portfolio] of cases) {
    const t = setup({ portfolio });
    const res = await t.send();
    assertEquals(res.status, 201, label);
    assertEquals(await res.json(), created('failed'), label);
    assertEquals(t.user.calls, [createCall(), ...lookupCalls()], label);
    assertEquals([t.admin.calls, t.senders], [[], []], label);
    assertEquals(t.logs, [
      emailFailedLog(logged('Error', 'portfolio name unavailable')),
      createdLog('failed'),
      accessLog(201),
    ], label);
  }
});

Deno.test('when the message cannot be rendered, delivery fails before any quota is charged', async () => {
  const t = setup({
    invitation: (args) => ({ data: { ...invitationRow(args), expires_at: 'not-a-date' } }),
  });
  const res = await t.send();
  assertEquals(res.status, 201);
  assertEquals(await res.json(), created('failed', { expires_at: 'not-a-date' }));
  assertEquals(t.user.calls, [createCall(), ...lookupCalls()]);
  assertEquals([t.admin.calls, t.senders], [[], []]);
  assertEquals(t.logs, [
    emailFailedLog(logged('RangeError', 'Invalid time value')),
    createdLog('failed'),
    accessLog(201),
  ]);
});

Deno.test('the recipient quota is keyed by the SHA-256 of the mailbox, so its aliases share it', async () => {
  const aliases = [
    'imrankhan@gmail.com',
    'Imran.Khan@gmail.com',
    'imran.khan+rent@googlemail.com',
    'I.M.R.A.N.K.H.A.N+a+b@GMAIL.COM',
  ];
  for (const email of aliases) {
    const t = setup();
    assertEquals((await t.send(invite({ ...BODY, email }))).status, 201, email);
    assertEquals(t.admin.calls, [RECIPIENT_HIT, INVITER_HIT], email);
  }
  // Elsewhere dots matter: another provider's dotted address is another mailbox.
  const t = setup();
  await t.send(invite({ ...BODY, email: 'Imran.Khan@example.com' }));
  assertEquals(t.admin.calls, [
    hitCall(`invite_email:to:${await sha256Hex('imran.khan@example.com')}`, 3),
    INVITER_HIT,
  ]);
});

Deno.test('a recipient over its quota is not e-mailed, and the inviter is not charged for it', async () => {
  const t = setup({ limits: [{ data: DENY }] });
  const res = await t.send();
  assertEquals(res.status, 201);
  assertEquals(await res.json(), created('rate_limited'));
  assertEquals(t.admin.calls, [RECIPIENT_HIT]);
  assertEquals(t.senders, []);
  assertEquals(t.logs, [createdLog('rate_limited'), accessLog(201)]);
});

Deno.test('an inviter over their quota is not e-mailed for: rate_limited after both quotas', async () => {
  const t = setup({ limits: [{ data: ALLOW }, { data: DENY }] });
  const res = await t.send();
  assertEquals(res.status, 201);
  assertEquals(await res.json(), created('rate_limited'));
  assertEquals(t.admin.calls, [RECIPIENT_HIT, INVITER_HIT]);
  assertEquals(t.senders, []);
  assertEquals(t.logs, [createdLog('rate_limited'), accessLog(201)]);
});

Deno.test('a limiter that fails or answers oddly fails delivery closed, with a warning', async () => {
  const down = { code: '08006', message: 'connection failure' };
  const cases: Array<[string, Result[], Call[], Record<string, unknown>]> = [
    [
      'the recipient check fails',
      [{ error: down, status: 503 }],
      [RECIPIENT_HIT],
      logged('HttpError', 'The rate limiter is unavailable.', down),
    ],
    [
      'the inviter check answers null',
      [{ data: ALLOW }, { data: null }],
      [RECIPIENT_HIT, INVITER_HIT],
      logged(
        'HttpError',
        'The rate limiter is unavailable.',
        logged('Error', 'unexpected limiter response: null'),
      ),
    ],
  ];
  for (const [label, limits, calls, error] of cases) {
    const t = setup({ limits });
    const res = await t.send();
    assertEquals(res.status, 201, label);
    assertEquals(await res.json(), created('failed'), label);
    assertEquals(t.admin.calls, calls, label);
    assertEquals(t.senders, [], label);
    assertEquals(t.logs, [emailFailedLog(error), createdLog('failed'), accessLog(201)], label);
  }
});

Deno.test('a provider failure leaves the invitation in place: delivery failed and a warning naming it', async () => {
  const cases: Array<[string, () => Promise<{ id: string }>, Record<string, unknown>]> = [
    [
      'a refusal',
      () => Promise.reject(new EmailDeliveryError(422, 'validation_error')),
      logged('EmailDeliveryError', 'e-mail delivery failed (422): validation_error'),
    ],
    [
      'a timeout',
      () => Promise.reject(new EmailDeliveryError(0, 'TimeoutError')),
      logged('EmailDeliveryError', 'e-mail delivery failed (0): TimeoutError'),
    ],
    ['a synchronous throw', () => {
      throw new TypeError('sender broken');
    }, logged('TypeError', 'sender broken')],
  ];
  for (const [label, send, error] of cases) {
    const t = setup({ send });
    const res = await t.send();
    assertEquals(res.status, 201, label);
    assertEquals(await res.json(), created('failed'), label);
    assertEquals(t.admin.calls, [RECIPIENT_HIT, INVITER_HIT], label);
    assertEquals(t.sent, [expectedEmail()], label);
    assertEquals(t.logs, [emailFailedLog(error), createdLog('failed'), accessLog(201)], label);
  }
});

Deno.test('no log holds the token, the encoded link or the invitee address, whatever happens', async () => {
  const scenarios: Array<[string, Script]> = [
    ['sent', {}],
    ['sent in Urdu', {}],
    ['not configured', { config: testConfig({ email: null }) }],
    ['misconfigured', {
      config: testConfig({ email: new ConfigError('MAIL_FROM', 'is required') }),
    }],
    ['portfolio lookup failed', { portfolio: { error: { message: 'boom' } } }],
    ['recipient over its quota', { limits: [{ data: DENY }] }],
    ['limiter down', { limits: [{ error: { message: 'down' } }] }],
    ['provider refused', {
      send: () => Promise.reject(new EmailDeliveryError(422, 'validation_error')),
    }],
    ['a malformed answer holding the token', {
      invitation: () => ({ data: { invitation_id: INVITATION_ID, email: INVITEE, token: TOKEN } }),
    }],
    ['refused by the database', {
      invitation: () => ({ error: { code: '22023', message: 'already_member' }, status: 400 }),
    }],
  ];
  for (const [label, script] of scenarios) {
    const t = setup(script);
    const locale = label === 'sent in Urdu' ? 'ur' : undefined;
    await t.send(invite({ ...BODY, locale }));
    assert(t.logs.length >= 2, label);
    assertNothingSecretLogged(t.logs, label);
  }
});

// --- the helpers -------------------------------------------------------------------------------

Deno.test('buildInviteUrl puts the URI-encoded token in the fragment of <app>/invite', () => {
  const cases: Array<[string, string, string]> = [
    [APP_ORIGIN, TOKEN, INVITE_URL],
    [
      'https://example.com/app',
      'a b&c=d#e?f/g',
      'https://example.com/app/invite#token=a%20b%26c%3Dd%23e%3Ff%2Fg',
    ],
    // A real token (uuid "." base64url) needs no encoding.
    [
      'http://localhost:3000',
      `${INVITATION_ID}.AbC-dEf_g`,
      `http://localhost:3000/invite#token=${INVITATION_ID}.AbC-dEf_g`,
    ],
  ];
  for (const [app, token, url] of cases) assertEquals(buildInviteUrl(app, token), url, token);
});

Deno.test('canonicalMailbox folds the aliases of one mailbox', () => {
  const cases: Array<[string, string, string]> = [
    ['upper case', 'Imran@Example.COM', 'imran@example.com'],
    ['a +tag', 'imran+rent@example.com', 'imran@example.com'],
    ['several +tags', 'imran+a+b@example.com', 'imran@example.com'],
    ['a leading + is not a tag', '+imran@example.com', '+imran@example.com'],
    ['dots kept for other domains', 'imran.khan@example.com', 'imran.khan@example.com'],
    ['Gmail ignores dots', 'i.m.r.a.n@gmail.com', 'imran@gmail.com'],
    ['googlemail.com is gmail.com', 'imran@googlemail.com', 'imran@gmail.com'],
    ['everything at once', TYPED_EMAIL, MAILBOX],
    [
      'a Gmail subdomain is another domain',
      'imran.khan@mail.gmail.com',
      'imran.khan@mail.gmail.com',
    ],
    ['the last @ separates the domain', '"imran@home"@example.com', '"imran@home"@example.com'],
  ];
  for (const [label, address, mailbox] of cases) {
    assertEquals(canonicalMailbox(address), mailbox, label);
  }
});

Deno.test('e-mail quotas: 3 an hour per recipient mailbox, 10 an hour per inviter', () => {
  assertEquals(EMAIL_LIMITS, {
    perInviter: { limit: 10, windowSeconds: 3600 },
    perRecipient: { limit: 3, windowSeconds: 3600 },
  });
});

// --- wiring ------------------------------------------------------------------------------------

Deno.test('defaultInviteDeps is the default pipeline plus a Resend sender on the global fetch', async () => {
  for (const key of Object.keys(defaultDeps) as Array<keyof typeof defaultDeps>) {
    assertStrictEquals(defaultInviteDeps[key], defaultDeps[key], key);
  }
  const requests: Array<{ url: string; init: RequestInit }> = [];
  const fetchStub = stub(globalThis, 'fetch', (input, init) => {
    requests.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(Response.json({ id: 'msg_default' }));
  });
  const timeout = stub(AbortSignal, 'timeout', () => new AbortController().signal);
  try {
    const sender = defaultInviteDeps.createSender(EMAIL);
    assertEquals(await sender.send(expectedEmail()), { id: 'msg_default' });
  } finally {
    timeout.restore();
    fetchStub.restore();
  }
  assertEquals(
    requests.map((
      { url, init },
    ) => [url, (init.headers as Record<string, string>)['authorization']]),
    [[RESEND_ENDPOINT, 'Bearer re_test_key']],
  );
});

Deno.test('index.ts exports { fetch }: the POST-only invite-member handler on the default deps', async () => {
  assertEquals(Object.keys(server), ['fetch']);
  assertEquals(typeof server.fetch, 'function');

  // A GET is refused before authentication: only the configuration is read, from the
  // environment, and the records go to the console as JSON lines.
  const env = stub(Deno.env, 'get', () => undefined);
  const lines: string[] = [];
  const info = stub(console, 'log', (line: string) => void lines.push(line));
  const warn = stub(console, 'warn', (line: string) => void lines.push(line));
  try {
    const res = await server.fetch(request({ method: 'GET', token: null }));
    assertEquals(res.status, 405);
    assertEquals(res.headers.get('allow'), 'POST, OPTIONS');
    const requestId = res.headers.get('x-request-id') ?? '';
    assertMatch(requestId, UUID_V4);
    assertEquals(await errorOf(res), {
      code: 'method_not_allowed',
      message: 'Use POST.',
      request_id: requestId,
    });
    assertEquals(
      lines.map((line) => {
        const record = JSON.parse(line);
        return [record.level, record.event, record.fn, record.request_id];
      }),
      [['warn', 'request_rejected', FN, requestId], ['info', 'request', FN, requestId]],
    );
    assert(env.calls.length > 0);
  } finally {
    warn.restore();
    info.restore();
    env.restore();
  }
});
