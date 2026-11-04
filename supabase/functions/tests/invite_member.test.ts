import { assert, assertEquals, assertStringIncludes } from '@std/assert';
import type { EmailConfig } from '../_shared/config.ts';
import type { EmailMessage, EmailSender } from '../_shared/email.ts';
import {
  buildInviteUrl,
  createInviteMemberHandler,
  defaultInviteDeps,
  EMAIL_LIMITS,
  type InviteMemberDeps,
} from '../invite-member/handler.ts';
import {
  APP_ORIGIN,
  errorOf,
  fakeClient,
  type FakeClientOptions,
  fakeContext,
  harness,
  PORTFOLIO_ID,
  request,
  testConfig,
  USER_ID,
} from './_helpers.ts';

const EMAIL: EmailConfig = { apiKey: 're_test', from: 'invites@example.com', replyTo: null };
const INVITATION_ID = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0';
const TOKEN = `${INVITATION_ID}.AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE`;
const BODY = { portfolio_id: PORTFOLIO_ID, email: 'Imran@Example.com', role: 'manager' };

function userClient(overrides: FakeClientOptions = {}) {
  return fakeClient({
    rpc: () => ({
      data: {
        invitation_id: INVITATION_ID,
        email: 'imran@example.com',
        role: 'manager',
        expires_at: '2026-11-10T12:00:00+00:00',
        token: TOKEN,
      },
    }),
    select: (table) =>
      table === 'portfolios'
        ? { data: { name: 'Raza Family Properties' } }
        : { data: { full_name: 'Ahmed Raza' } },
    ...overrides,
  });
}

function setup(options: {
  email?: EmailConfig | null;
  appUrl?: string | null;
  user?: ReturnType<typeof userClient>;
  admin?: ReturnType<typeof fakeClient>;
  send?: (message: EmailMessage) => Promise<{ id: string }>;
} = {}) {
  const user = options.user ?? userClient();
  const admin = options.admin ?? fakeClient({ rpc: () => ({ data: true }) });
  const sent: EmailMessage[] = [];
  const senders: EmailConfig[] = [];
  const base = harness({
    config: testConfig({
      email: options.email === undefined ? EMAIL : options.email,
      appUrl: options.appUrl === undefined ? APP_ORIGIN : options.appUrl,
    }),
    context: fakeContext({ supabase: user, supabaseAdmin: admin }),
  });
  const deps: InviteMemberDeps = {
    ...base.deps,
    createSender: (config): EmailSender => {
      senders.push(config);
      return {
        send: options.send ?? ((message) => {
          sent.push(message);
          return Promise.resolve({ id: 'msg_1' });
        }),
      };
    },
  };
  const invoke = (body: unknown = BODY) => createInviteMemberHandler(deps)(request({ body }));
  return { user, admin, sent, senders, logs: base.logs, invoke };
}

Deno.test('buildInviteUrl keeps the token in the fragment', () => {
  assertEquals(
    buildInviteUrl('https://app.example.com', 'id.tok-en_'),
    'https://app.example.com/invite#token=id.tok-en_',
  );
});

Deno.test('creates the invitation as the caller and e-mails the link', async () => {
  const t = setup();
  const res = await t.invoke();
  assertEquals(res.status, 201);
  const invite_url = `${APP_ORIGIN}/invite#token=${encodeURIComponent(TOKEN)}`;
  assertEquals(await res.json(), {
    invitation_id: INVITATION_ID,
    email: 'imran@example.com',
    role: 'manager',
    expires_at: '2026-11-10T12:00:00+00:00',
    invite_url,
    email_delivery: 'sent',
  });

  assertEquals(t.user.calls[0]?.args, [
    'create_invitation',
    { p_portfolio_id: PORTFOLIO_ID, p_email: 'imran@example.com', p_role: 'manager' },
  ]);
  assertEquals(
    t.admin.calls.map((c) =>
      (c.args[1] as { p_key: string }).p_key.replace(/[0-9a-f]{64}$/, '<sha256>')
    ),
    [`invite_email:user:${USER_ID}`, 'invite_email:to:<sha256>'],
  );
  assertEquals(
    t.admin.calls.map((c) => (c.args[1] as { p_limit: number }).p_limit),
    [EMAIL_LIMITS.perInviter.limit, EMAIL_LIMITS.perRecipient.limit],
  );
  // The recipient is never stored in clear text in the limiter.
  assertEquals(JSON.stringify(t.admin.calls).includes('imran'), false);

  assertEquals(t.senders, [EMAIL]);
  const [message] = t.sent as [EmailMessage];
  assertEquals(message.to, 'imran@example.com');
  assertEquals(message.idempotencyKey, `invitation:${INVITATION_ID}`);
  assertStringIncludes(message.subject, 'Raza Family Properties');
  assertStringIncludes(message.subject, 'Ahmed Raza (owner@example.com)');
  assertStringIncludes(message.text, invite_url);

  const created = t.logs.find((r) => r.event === 'invitation_created');
  assertEquals(created?.['delivery'], 'sent');
});

Deno.test('returns the link without e-mail when e-mail is not configured', async () => {
  const t = setup({ email: null });
  const res = await t.invoke();
  assertEquals(res.status, 201);
  assertEquals((await res.json()).email_delivery, 'not_configured');
  assertEquals(t.admin.calls.length, 0);
  assertEquals(t.sent.length, 0);
});

Deno.test('refuses to create invitations without an app URL to link to', async () => {
  const t = setup({ appUrl: null });
  const res = await t.invoke();
  assertEquals(res.status, 500);
  const error = await errorOf(res);
  assertEquals([error.code, error.details], ['server_misconfigured', { variable: 'APP_URL' }]);
  assertEquals(t.user.calls.length, 0, 'no invitation is created');
});

Deno.test('validates the request body before touching the database', async () => {
  const cases: Array<[unknown, string, string]> = [
    [{ ...BODY, admin: true }, 'admin', 'unknown_field'],
    [{ ...BODY, portfolio_id: 'nope' }, 'portfolio_id', 'not_a_uuid'],
    [{ ...BODY, email: 'not-an-email' }, 'email', 'not_an_email'],
    [{ ...BODY, role: 'superuser' }, 'role', 'not_allowed'],
    [{ ...BODY, locale: 'fr' }, 'locale', 'not_allowed'],
  ];
  for (const [body, field, reason] of cases) {
    const t = setup();
    const res = await t.invoke(body);
    assertEquals(res.status, 422);
    assertEquals((await errorOf(res)).details, { field, reason });
    assertEquals(t.user.calls.length, 0);
  }
});

Deno.test('maps database refusals to client errors', async () => {
  const cases: Array<[Record<string, unknown>, number, number, string]> = [
    [{ code: '42501', message: 'forbidden' }, 403, 403, 'forbidden'],
    [{ code: '22023', message: 'already_member' }, 400, 422, 'validation_failed'],
    [{ code: 'rate_limited', message: 'Too many' }, 429, 429, 'rate_limited'],
  ];
  for (const [failure, status, expected, code] of cases) {
    const t = setup({ user: userClient({ rpc: () => ({ error: failure, status }) }) });
    const res = await t.invoke();
    assertEquals([res.status, (await errorOf(res)).code], [expected, code]);
    assertEquals(t.sent.length, 0);
  }
});

Deno.test('rejects an unexpected response from the database', async () => {
  const t = setup({
    user: userClient({ rpc: () => ({ data: { invitation_id: INVITATION_ID } }) }),
  });
  const res = await t.invoke();
  assertEquals([res.status, (await errorOf(res)).code], [502, 'upstream_error']);
});

Deno.test('skips the e-mail when the inviter or the recipient is over the limit', async () => {
  for (const refuseAt of [0, 1]) {
    let hit = 0;
    const admin = fakeClient({ rpc: () => ({ data: hit++ !== refuseAt }) });
    const t = setup({ admin });
    const res = await t.invoke();
    assertEquals(res.status, 201);
    assertEquals((await res.json()).email_delivery, 'rate_limited');
    assertEquals(t.sent.length, 0);
    assertEquals(admin.calls.length, refuseAt + 1, 'later limits are not charged');
  }
});

Deno.test('e-mail problems never fail the invitation', async () => {
  const limiterDown = setup({ admin: fakeClient({ rpc: () => ({ error: { message: 'down' } }) }) });
  assertEquals((await (await limiterDown.invoke()).json()).email_delivery, 'failed');

  const noPortfolio = setup({
    user: userClient({
      select: (table) => table === 'portfolios' ? { data: null } : { data: null },
    }),
  });
  const res = await noPortfolio.invoke();
  assertEquals([res.status, (await res.json()).email_delivery], [201, 'failed']);
  assertEquals(noPortfolio.sent.length, 0);

  const lookupFailed = setup({
    user: userClient({ select: () => ({ error: { message: 'x' } }) }),
  });
  assertEquals((await (await lookupFailed.invoke()).json()).email_delivery, 'failed');

  const providerDown = setup({ send: () => Promise.reject(new Error('provider down')) });
  const failed = await providerDown.invoke();
  assertEquals([failed.status, (await failed.json()).email_delivery], [201, 'failed']);
  const warning = providerDown.logs.find((r) => r.event === 'invitation_email_failed');
  assertEquals(warning?.level, 'warn');
  assertEquals(warning?.['invitation_id'], INVITATION_ID);
});

Deno.test('falls back to the inviter e-mail when the profile has no name', async () => {
  const t = setup({
    user: userClient({
      select: (table) => table === 'portfolios' ? { data: { name: 'Shop' } } : { data: null },
    }),
  });
  await t.invoke();
  const [message] = t.sent as [EmailMessage];
  assertStringIncludes(message.subject, 'owner@example.com invited you to "Shop"');
});

Deno.test('describes an inviter without an e-mail address by name only', async () => {
  const user = userClient();
  const admin = fakeClient({ rpc: () => ({ data: true }) });
  const sent: EmailMessage[] = [];
  const base = harness({
    config: testConfig({ email: EMAIL }),
    context: fakeContext({ user: { email: undefined }, supabase: user, supabaseAdmin: admin }),
  });
  const handler = createInviteMemberHandler({
    ...base.deps,
    createSender: () => ({
      send: (message) => {
        sent.push(message);
        return Promise.resolve({ id: 'msg' });
      },
    }),
  });
  assertEquals((await handler(request({ body: BODY }))).status, 201);
  assertStringIncludes(sent[0]?.subject ?? '', 'Ahmed Raza invited you');
});

Deno.test('uses the inviter language for the subject', async () => {
  const t = setup();
  await t.invoke({ ...BODY, locale: 'ur' });
  const [message] = t.sent as [EmailMessage];
  assert(/[؀-ۿ]/.test(message.subject), 'the subject is in Urdu');
});

Deno.test('the default handler and sender factory are wired', async () => {
  const { default: fn } = await import('../invite-member/index.ts');
  assertEquals(typeof fn.fetch, 'function');
  assertEquals(typeof defaultInviteDeps.createSender(EMAIL).send, 'function');
});
