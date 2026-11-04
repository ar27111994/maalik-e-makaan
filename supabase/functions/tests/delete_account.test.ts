import { assert, assertEquals, assertRejects } from '@std/assert';
import type { JWTClaims } from '@supabase/server';
import { HttpError } from '../_shared/errors.ts';
import {
  createDeleteAccountHandler,
  DOCUMENTS_BUCKET,
  lastSignInAt,
  LIST_PAGE_SIZE,
  listObjects,
  removePortfolioFiles,
} from '../delete-account/handler.ts';
import {
  errorOf,
  fakeClient,
  type FakeClientOptions,
  fakeContext,
  harness,
  NOW_SECONDS,
  OTHER_PORTFOLIO_ID,
  PORTFOLIO_ID,
  request,
  type Result,
  testConfig,
  USER_ID,
} from './_helpers.ts';

const FRESH = { amr: [{ method: 'password', timestamp: NOW_SECONDS - 60 }], aal: 'aal1' };
const CONFIRM = { confirm_email: 'Owner@Example.com' };
const SCOPE = [
  { portfolio_id: PORTFOLIO_ID, portfolio_name: 'Raza Family Properties', other_members: 2 },
  { portfolio_id: OTHER_PORTFOLIO_ID, portfolio_name: 'Shop', other_members: 0 },
];

interface Folder {
  [name: string]: 'file' | Folder;
}

/** Storage listing over an in-memory tree, paginated like the real API. */
function storageTree(tree: Folder): Pick<FakeClientOptions, 'list'> {
  const find = (path: string): Folder | undefined => {
    let node: Folder | 'file' | undefined = tree;
    for (const part of path.split('/')) {
      node = typeof node === 'object' ? node[part] : undefined;
    }
    return typeof node === 'object' ? node : undefined;
  };
  return {
    list: (path, options) => {
      const { limit, offset } = options as { limit: number; offset: number };
      const entries = Object.entries(find(path) ?? {})
        .sort(([a], [b]) => a.localeCompare(b))
        .slice(offset, offset + limit)
        .map(([name, value]) => ({ name, id: value === 'file' ? `id-${name}` : null }));
      return { data: entries };
    },
  };
}

function adminClient(overrides: FakeClientOptions = {}) {
  return fakeClient({
    rpc: (fn) => {
      if (fn === 'admin_account_deletion_scope') return { data: SCOPE };
      if (fn === 'admin_delete_account_data') {
        return { data: { deleted_portfolio_ids: [PORTFOLIO_ID, OTHER_PORTFOLIO_ID] } };
      }
      throw new Error(fn);
    },
    ...storageTree({
      [PORTFOLIO_ID]: {
        tenant: { 't1': { 'a.jpg': 'file', 'b.pdf': 'file' } },
        lease: { 'l1': { 'agreement.pdf': 'file' } },
      },
    }),
    remove: () => ({ data: [] }),
    deleteUser: () => ({ data: { user: null } }),
    listFactors: () => ({ data: { factors: [] } }),
    ...overrides,
  });
}

function call(options: {
  method?: string;
  body?: unknown;
  jwtClaims?: Partial<JWTClaims>;
  admin?: ReturnType<typeof adminClient>;
  email?: string | undefined;
}) {
  const admin = options.admin ?? adminClient();
  const h = harness({
    context: fakeContext({
      user: { email: 'email' in options ? options.email : 'owner@example.com' },
      jwtClaims: options.jwtClaims ?? FRESH,
      supabaseAdmin: admin,
    }),
  });
  const handler = createDeleteAccountHandler(h.deps);
  const req = request({ method: options.method, body: options.body });
  return { admin, logs: h.logs, response: handler(req) };
}

Deno.test('lastSignInAt picks the latest interactive sign-in', () => {
  assertEquals(lastSignInAt(null), null);
  assertEquals(lastSignInAt({ sub: USER_ID }), null);
  assertEquals(lastSignInAt({ sub: USER_ID, amr: 'password' }), null);
  assertEquals(
    lastSignInAt({
      sub: USER_ID,
      amr: [
        { method: 'password', timestamp: 100 },
        { method: 'totp', timestamp: 300 },
        { method: 'token_refresh', timestamp: 900 },
        { method: 'anonymous', timestamp: 800 },
        { method: 'otp', timestamp: 'yesterday' },
        { timestamp: 700 },
        null,
        'password',
        { method: 'otp', timestamp: Number.POSITIVE_INFINITY },
      ],
    }),
    300,
  );
});

Deno.test('GET previews the sole-owned portfolios that would be deleted', async () => {
  const { response, admin } = call({ method: 'GET' });
  const res = await response;
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    portfolios_to_delete: [
      { id: PORTFOLIO_ID, name: 'Raza Family Properties', other_members: 2 },
      { id: OTHER_PORTFOLIO_ID, name: 'Shop', other_members: 0 },
    ],
    sign_in_max_age_seconds: 600,
  });
  assertEquals(admin.calls.map((c) => c.kind), ['rpc']);
  assertEquals(admin.calls[0]?.args, ['admin_account_deletion_scope', { p_user_id: USER_ID }]);
});

Deno.test('GET with nothing in scope returns an empty list', async () => {
  const admin = adminClient({ rpc: () => ({ data: null }) });
  const res = await call({ method: 'GET', admin }).response;
  assertEquals((await res.json()).portfolios_to_delete, []);
});

Deno.test('GET surfaces database failures', async () => {
  const admin = adminClient({
    rpc: () => ({ error: { code: 'XX000', message: 'down' }, status: 500 }),
  });
  const res = await call({ method: 'GET', admin }).response;
  assertEquals(res.status, 502);
});

Deno.test('POST deletes files, then data, then the auth user', async () => {
  const { response, admin, logs } = call({ body: CONFIRM });
  const res = await response;
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    deleted: true,
    deleted_portfolio_ids: [PORTFOLIO_ID, OTHER_PORTFOLIO_ID],
    files_removed: 3,
  });

  const kinds = admin.calls.map((c) => c.kind);
  assertEquals(kinds.slice(0, 2), ['listFactors', 'rpc']);
  assert(kinds.indexOf('remove') < kinds.lastIndexOf('rpc'), 'files go before data');
  assertEquals(kinds.at(-2), 'rpc');
  assertEquals(kinds.at(-1), 'deleteUser');

  const removed = admin.calls.filter((c) => c.kind === 'remove').flatMap((c) =>
    c.args[1] as string[]
  );
  assertEquals(removed.sort(), [
    `${PORTFOLIO_ID}/lease/l1/agreement.pdf`,
    `${PORTFOLIO_ID}/tenant/t1/a.jpg`,
    `${PORTFOLIO_ID}/tenant/t1/b.pdf`,
  ]);
  for (const c of admin.calls.filter((c) => c.kind === 'list' || c.kind === 'remove')) {
    assertEquals(c.args[0], DOCUMENTS_BUCKET);
  }
  assertEquals(admin.calls.at(-1)?.args, [USER_ID]);
  const event = logs.find((r) => r.event === 'account_deleted');
  assertEquals([event?.['portfolios_deleted'], event?.['files_removed']], [2, 3]);
});

Deno.test('POST validates the body strictly', async () => {
  const unknown = await call({ body: { confirm_email: 'owner@example.com', force: true } })
    .response;
  assertEquals((await errorOf(unknown)).details, { field: 'force', reason: 'unknown_field' });

  const missing = await call({ body: {} }).response;
  assertEquals((await errorOf(missing)).details, { field: 'confirm_email', reason: 'required' });
});

Deno.test('POST requires a recent sign-in', async () => {
  for (
    const jwtClaims of [
      { amr: [{ method: 'password', timestamp: NOW_SECONDS - 601 }] },
      { amr: [] },
      {},
    ]
  ) {
    const { response, admin } = call({ body: CONFIRM, jwtClaims });
    const res = await response;
    assertEquals(res.status, 401);
    const error = await errorOf(res);
    assertEquals([error.code, error.details], ['reauthentication_required', {
      max_age_seconds: 600,
    }]);
    assertEquals(admin.calls.length, 0, 'nothing is touched');
  }
});

Deno.test('POST requires the second factor when the account has one', async () => {
  const admin = adminClient({
    listFactors: () => ({ data: { factors: [{ status: 'unverified' }, { status: 'verified' }] } }),
  });
  const res = await call({ body: CONFIRM, admin }).response;
  assertEquals(res.status, 403);
  assertEquals((await errorOf(res)).code, 'mfa_required');
  assertEquals(admin.calls.map((c) => c.kind), ['listFactors']);
});

Deno.test('POST with an aal2 session skips the factor lookup', async () => {
  const { response, admin } = call({ body: CONFIRM, jwtClaims: { ...FRESH, aal: 'aal2' } });
  assertEquals((await response).status, 200);
  assertEquals(admin.calls.some((c) => c.kind === 'listFactors'), false);
});

Deno.test('POST proceeds when only unverified factors exist', async () => {
  const admin = adminClient({
    listFactors: () => ({ data: { factors: [{ status: 'unverified' }] } }),
  });
  assertEquals((await call({ body: CONFIRM, admin }).response).status, 200);
});

Deno.test('POST fails safely when factors cannot be checked', async () => {
  const admin = adminClient({ listFactors: () => ({ error: { message: 'down', status: 500 } }) });
  const res = await call({ body: CONFIRM, admin }).response;
  assertEquals([res.status, (await errorOf(res)).code], [502, 'upstream_error']);
  assertEquals(admin.calls.map((c) => c.kind), ['listFactors']);
});

Deno.test('POST requires the confirmation to match the account e-mail', async () => {
  const mismatch = call({ body: { confirm_email: 'someone@example.com' } });
  const res = await mismatch.response;
  assertEquals((await errorOf(res)).details, {
    field: 'confirm_email',
    reason: 'does_not_match_account',
  });
  assertEquals(mismatch.admin.calls.map((c) => c.kind), ['listFactors']);

  const noEmail = await call({ body: CONFIRM, email: undefined }).response;
  assertEquals(noEmail.status, 422);
});

Deno.test('POST stops before deleting anything when storage fails', async () => {
  const listing = adminClient({ list: () => ({ error: { message: 'storage down' } }) });
  const res = await call({ body: CONFIRM, admin: listing }).response;
  assertEquals(res.status, 502);
  assertEquals(listing.calls.some((c) => c.kind === 'deleteUser'), false);

  const removing = adminClient({ remove: () => ({ error: { message: 'storage down' } }) });
  const res2 = await call({ body: CONFIRM, admin: removing }).response;
  assertEquals(res2.status, 502);
  assertEquals(
    removing.calls.filter((c) => c.kind === 'rpc').map((c) => c.args[0]),
    ['admin_account_deletion_scope'],
  );
});

Deno.test('POST surfaces failures of the scope and data deletion steps', async () => {
  const scopeDown = adminClient({
    rpc: () => ({ error: { code: '42501', message: 'x' }, status: 403 }),
  });
  assertEquals((await call({ body: CONFIRM, admin: scopeDown }).response).status, 403);

  const dataDown = adminClient({
    rpc: (fn) =>
      fn === 'admin_account_deletion_scope'
        ? { data: [] }
        : { error: { code: 'XX000', message: 'x' }, status: 500 },
  });
  const res = await call({ body: CONFIRM, admin: dataDown }).response;
  assertEquals(res.status, 502);
  assertEquals(dataDown.calls.some((c) => c.kind === 'deleteUser'), false);
});

Deno.test('POST treats an already-deleted auth user as success, other failures not', async () => {
  const gone = adminClient({
    deleteUser: () => ({ error: { message: 'User not found', status: 404 } }),
  });
  assertEquals((await call({ body: CONFIRM, admin: gone }).response).status, 200);

  const down = adminClient({ deleteUser: () => ({ error: { message: 'boom', status: 500 } }) });
  const res = await call({ body: CONFIRM, admin: down }).response;
  assertEquals([res.status, (await errorOf(res)).code], [502, 'upstream_error']);
});

Deno.test('POST copes with a data step that returns nothing', async () => {
  const admin = adminClient({ rpc: () => ({ data: null }) });
  const res = await call({ body: CONFIRM, admin }).response;
  assertEquals(await res.json(), { deleted: true, deleted_portfolio_ids: [], files_removed: 0 });
});

Deno.test('listObjects pages through large folders', async () => {
  const many: Folder = {};
  for (let i = 0; i < LIST_PAGE_SIZE + 5; i++) many[`f${String(i).padStart(5, '0')}.jpg`] = 'file';
  const admin = adminClient(storageTree({ p: { tenant: { t: many } } }));
  const paths = await listObjects(admin.client, 'p');
  assertEquals(paths.length, LIST_PAGE_SIZE + 5);
  const lists = admin.calls.filter((c) => c.kind === 'list').map((
    c,
  ) => [c.args[1], (c.args[2] as { offset: number }).offset]);
  assertEquals(lists, [['p', 0], ['p/tenant', 0], ['p/tenant/t', 0], [
    'p/tenant/t',
    LIST_PAGE_SIZE,
  ]]);
});

Deno.test('listObjects refuses runaway listings', async () => {
  const admin = adminClient(
    storageTree({ p: { 'a.jpg': 'file', 'b.jpg': 'file', 'c.jpg': 'file' } }),
  );
  const error = await assertRejects(() => listObjects(admin.client, 'p', 2), HttpError);
  assertEquals([error.status, error.code], [502, 'upstream_error']);
});

Deno.test('removePortfolioFiles removes in batches of 100', async () => {
  const files: Folder = {};
  for (let i = 0; i < 250; i++) files[`f${String(i).padStart(3, '0')}.pdf`] = 'file';
  const removed: number[] = [];
  const admin = adminClient({
    ...storageTree({ p: { lease: { l: files } } }),
    remove: (paths): Result => {
      removed.push(paths.length);
      return { data: [] };
    },
  });
  assertEquals(await removePortfolioFiles(admin.client, 'p'), 250);
  assertEquals(removed, [100, 100, 50]);
});

Deno.test('removePortfolioFiles is a no-op for empty folders', async () => {
  const admin = adminClient(storageTree({}));
  assertEquals(await removePortfolioFiles(admin.client, 'missing'), 0);
  assertEquals(admin.calls.filter((c) => c.kind === 'remove').length, 0);
});

Deno.test('the default handler wires the default dependencies', async () => {
  const { default: fn } = await import('../delete-account/index.ts');
  assertEquals(typeof fn.fetch, 'function');
  assertEquals(testConfig().reauthMaxAgeSeconds, 600);
});
