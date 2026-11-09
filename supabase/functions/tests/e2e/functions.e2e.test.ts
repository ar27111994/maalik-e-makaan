/**
 * End-to-end tests against a running Supabase stack (`supabase start`), so
 * real JWTs, row-level security, the RPCs and storage are all exercised.
 * Run with `make test-functions-e2e`; skipped unless MM_FUNCTIONS_E2E=1.
 *
 * Environment (CI exports these from `supabase status -o env`):
 *   SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY
 * The functions must see APP_URL (supabase/functions/.env).
 */

import { assert, assertEquals, assertStringIncludes } from '@std/assert';
import { createClient } from '@supabase/supabase-js';

const ENABLED = Deno.env.get('MM_FUNCTIONS_E2E') === '1';
const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? '';
const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
const PASSWORD = 'E2e-Passw0rd-2026';

function functionUrl(name: string, query = ''): string {
  return `${url}/functions/v1/${name}${query}`;
}

async function signedInUser(label: string) {
  const admin = createClient(url, secretKey, { auth: { persistSession: false } });
  const email = `${label}-${crypto.randomUUID()}@e2e.maalik.local`;
  const created = await admin.auth.admin.createUser({
    email,
    password: PASSWORD,
    email_confirm: true,
  });
  if (created.error) throw created.error;
  const client = createClient(url, publishableKey, { auth: { persistSession: false } });
  const session = await client.auth.signInWithPassword({ email, password: PASSWORD });
  if (session.error || !session.data.session) throw session.error ?? new Error('no session');
  return {
    admin,
    client,
    email,
    token: session.data.session.access_token,
    id: created.data.user.id,
  };
}

function call(name: string, token: string | null, init: RequestInit = {}, query = '') {
  const headers = new Headers(init.headers);
  headers.set('apikey', publishableKey);
  if (token !== null) headers.set('authorization', `Bearer ${token}`);
  if (init.body !== undefined) headers.set('content-type', 'application/json');
  return fetch(functionUrl(name, query), { ...init, headers });
}

Deno.test({
  name: 'health answers liveness publicly',
  ignore: !ENABLED,
  async fn() {
    const response = await fetch(functionUrl('health'));
    assertEquals(response.status, 200);
    assertEquals((await response.json()).status, 'ok');
  },
});

Deno.test({
  name: 'functions refuse unknown browser origins',
  ignore: !ENABLED,
  async fn() {
    // A real request, not a preflight: the local stack's gateway answers
    // preflights itself, while the function's own origin check is what
    // protects every environment (preflights are covered by the unit tests).
    const response = await fetch(functionUrl('invite-member'), {
      method: 'POST',
      headers: { origin: 'https://evil.example', 'content-type': 'application/json' },
      body: '{}',
    });
    assertEquals(response.status, 403);
    assertEquals((await response.json()).error.code, 'origin_not_allowed');
  },
});

Deno.test({
  name: 'invite-member creates a single-use link for owners only',
  ignore: !ENABLED,
  async fn() {
    const owner = await signedInUser('owner');
    const portfolio = await owner.client.rpc('create_portfolio', { p_name: 'E2E Portfolio' });
    if (portfolio.error) throw portfolio.error;

    const anonymous = await call('invite-member', null, {
      method: 'POST',
      body: JSON.stringify({
        portfolio_id: portfolio.data.id,
        email: 'x@example.com',
        role: 'viewer',
      }),
    });
    assertEquals(anonymous.status, 401);
    await anonymous.body?.cancel();

    const response = await call('invite-member', owner.token, {
      method: 'POST',
      body: JSON.stringify({
        portfolio_id: portfolio.data.id,
        email: 'Invitee@Example.com',
        role: 'manager',
      }),
    });
    assertEquals(response.status, 201);
    const body = await response.json();
    assertEquals(body.email, 'invitee@example.com');
    assertStringIncludes(body.invite_url, '/invite#token=');
    assert(['not_configured', 'sent', 'failed', 'rate_limited'].includes(body.email_delivery));

    // A stranger cannot invite people into someone else's portfolio.
    const stranger = await signedInUser('stranger');
    const denied = await call('invite-member', stranger.token, {
      method: 'POST',
      body: JSON.stringify({
        portfolio_id: portfolio.data.id,
        email: 'y@example.com',
        role: 'viewer',
      }),
    });
    assertEquals(denied.status, 403);
    await denied.body?.cancel();
  },
});

Deno.test({
  name: 'delete-account previews, verifies and deletes everything',
  ignore: !ENABLED,
  async fn() {
    const user = await signedInUser('leaver');
    const portfolio = await user.client.rpc('create_portfolio', { p_name: 'Leaving Soon' });
    if (portfolio.error) throw portfolio.error;

    const preview = await call('delete-account', user.token);
    assertEquals(preview.status, 200);
    const scope = await preview.json();
    assertEquals(scope.portfolios_to_delete.map((p: { id: string }) => p.id), [portfolio.data.id]);

    const mismatch = await call('delete-account', user.token, {
      method: 'POST',
      body: JSON.stringify({ confirm_email: 'someone-else@example.com' }),
    });
    assertEquals(mismatch.status, 422);
    await mismatch.body?.cancel();

    const deleted = await call('delete-account', user.token, {
      method: 'POST',
      body: JSON.stringify({ confirm_email: user.email }),
    });
    assertEquals(deleted.status, 200);
    assertEquals((await deleted.json()).deleted_portfolio_ids, [portfolio.data.id]);

    const lookup = await user.admin.auth.admin.getUserById(user.id);
    assert(lookup.error !== null || lookup.data.user === null, 'the auth user is gone');
    const remaining = await user.admin.from('portfolios').select('id').eq('id', portfolio.data.id);
    assertEquals(remaining.data, []);
  },
});
