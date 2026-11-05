import {
  assert,
  assertEquals,
  assertFalse,
  assertInstanceOf,
  assertStrictEquals,
} from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  CLAIM_LEASE_SECONDS,
  CLAIM_LIMIT,
  type CleanupItem,
  type CleanupOptions,
  type CleanupReport,
  DOCUMENTS_BUCKET,
  drainStorageCleanup,
  PAGE_SIZE,
} from '../_shared/storage.ts';
import {
  type Call,
  type FakeClient,
  fakeClient,
  OTHER_PORTFOLIO_ID,
  PORTFOLIO_ID,
  type Result,
  steppingClock,
} from './_helpers.ts';

// --- fixtures ------------------------------------------------------------------

/** Deadline of a run with time to spare: the clock stands at 0 unless a test moves it. */
const DEADLINE = 25_000;
const FOLDER = `${PORTFOLIO_ID}/`;
const OTHER_FOLDER = `${OTHER_PORTFOLIO_ID}/`;

/** A queued folder: everything under [path] goes. */
function folder(id: number, bucket = DOCUMENTS_BUCKET, path = FOLDER): CleanupItem {
  return { id, bucket_id: bucket, path, is_prefix: true, attempts: 1 };
}

/** A queued single file. */
function file(id: number): CleanupItem {
  return {
    id,
    bucket_id: DOCUMENTS_BUCKET,
    path: `${FOLDER}receipts/${id}.pdf`,
    is_prefix: false,
    attempts: 1,
  };
}

/** [count] object names under [prefix], in the listing's (C collation) order. */
function names(count: number, from = 0, prefix = FOLDER): string[] {
  return Array.from(
    { length: count },
    (_, i) => `${prefix}docs/${String(from + i).padStart(5, '0')}.pdf`,
  );
}

/** A listing answer: one row per object name. */
function page(objects: readonly string[]): Result {
  return { data: objects.map((name) => ({ name })) };
}

function report(counts: Partial<CleanupReport> = {}): CleanupReport {
  return {
    claimed: 0,
    done: 0,
    rescheduled: 0,
    retried: 0,
    objectsRemoved: 0,
    failure: null,
    ...counts,
  };
}

// --- a scripted queue -------------------------------------------------------------

/** An answer, or a function producing it when the call is made (to move the clock). */
type Answer = Result | (() => Result);

interface QueueScript {
  /** Answers to successive claims; the queue is empty after them. */
  readonly claims?: readonly Answer[];
  /** Successive listings of each item, by id; no object is left after them. */
  readonly listings?: Readonly<Record<number, readonly Answer[]>>;
  /** The Storage API's answer to a removal (default: every object deleted). */
  readonly remove?: (bucket: string, objects: string[]) => Result;
  /** The database's answer to completing an item (default 'done'). */
  readonly complete?: (itemId: number, args: Record<string, unknown>) => Result;
}

function take(answers: Answer[] | undefined, otherwise: Result): Result {
  const next = answers?.shift();
  if (next === undefined) return otherwise;
  return typeof next === 'function' ? next() : next;
}

/** A secret-key client whose queue RPCs and Storage removals follow [script]. */
function queue(script: QueueScript = {}): FakeClient {
  const claims = [...(script.claims ?? [])];
  const listings = new Map(
    Object.entries(script.listings ?? {}).map(([id, answers]) => [Number(id), [...answers]]),
  );
  return fakeClient({
    rpc: (fn, args) => {
      const itemId = args['p_item_id'] as number;
      switch (fn) {
        case 'admin_claim_storage_cleanup':
          return take(claims, { data: [] });
        case 'admin_storage_cleanup_objects':
          return take(listings.get(itemId), { data: [] });
        case 'admin_complete_storage_cleanup':
          return script.complete?.(itemId, args) ?? { data: 'done' };
        default:
          throw new Error(`unexpected rpc ${fn}`);
      }
    },
    remove: (bucket, objects) =>
      script.remove?.(bucket, objects) ?? { data: objects.map((name) => ({ name })) },
  });
}

function drain(admin: FakeClient, options: Partial<CleanupOptions> = {}): Promise<CleanupReport> {
  return drainStorageCleanup(admin.client, {
    deadline: DEADLINE,
    clock: steppingClock().clock,
    ...options,
  });
}

// --- the calls a run is expected to make ---------------------------------------------

function claimCall(paths?: readonly string[]): Call {
  const args: Record<string, unknown> = { p_limit: 20, p_lease_seconds: 120 };
  if (paths !== undefined) args['p_paths'] = paths;
  return { kind: 'rpc', args: ['admin_claim_storage_cleanup', args] };
}

function listCall(itemId: number): Call {
  return {
    kind: 'rpc',
    args: ['admin_storage_cleanup_objects', { p_item_id: itemId, p_limit: 1000 }],
  };
}

function removeCall(bucket: string, objects: readonly string[]): Call {
  return { kind: 'remove', args: [bucket, objects] };
}

function completeCall(itemId: number, finished: boolean, error?: string): Call {
  const args: Record<string, unknown> = { p_item_id: itemId, p_finished: finished };
  if (error !== undefined) args['p_error'] = error;
  return { kind: 'rpc', args: ['admin_complete_storage_cleanup', args] };
}

function argsOf(call: Call | undefined): Record<string, unknown> {
  return call?.args[1] as Record<string, unknown>;
}

// --- sizes -----------------------------------------------------------------------------

Deno.test('the claim, lease and page sizes are within what the database and Storage API accept', () => {
  assertEquals(
    { DOCUMENTS_BUCKET, CLAIM_LIMIT, CLAIM_LEASE_SECONDS, PAGE_SIZE },
    { DOCUMENTS_BUCKET: 'documents', CLAIM_LIMIT: 20, CLAIM_LEASE_SECONDS: 120, PAGE_SIZE: 1000 },
  );
  // admin_claim_storage_cleanup fails (invalid_claim) outside these bounds.
  assert(CLAIM_LIMIT >= 1 && CLAIM_LIMIT <= 100);
  assert(CLAIM_LEASE_SECONDS >= 30 && CLAIM_LEASE_SECONDS <= 900);
  // admin_storage_cleanup_objects caps a page at 1000 names, the most one removal takes.
  assert(PAGE_SIZE >= 1 && PAGE_SIZE <= 1000);
});

// --- claiming ----------------------------------------------------------------------------

Deno.test('an empty queue costs one claim of 20 items for 120 s, without p_paths, and reports nothing', async () => {
  // An empty queue answers []; null is read the same way.
  for (const empty of [{ data: [] }, { data: null }]) {
    const label = JSON.stringify(empty);
    const admin = queue({ claims: [empty] });
    assertEquals(await drain(admin), report(), label);
    assertEquals(admin.calls, [claimCall()], label);
    assertFalse('p_paths' in argsOf(admin.calls[0]), label);
  }
});

Deno.test('the paths option restricts every claim to those queued paths', async () => {
  // The queue holds exactly the items whose path the claim names.
  const cases: ReadonlyArray<readonly [readonly string[], readonly CleanupItem[]]> = [
    [[FOLDER], [folder(1)]],
    [[FOLDER, OTHER_FOLDER], [folder(1), folder(2, DOCUMENTS_BUCKET, OTHER_FOLDER)]],
    [[], []],
  ];
  for (const [paths, items] of cases) {
    const label = JSON.stringify(paths);
    const admin = queue({ claims: [{ data: items }] });
    assertEquals(
      await drain(admin, { paths }),
      report({ claimed: items.length, done: items.length }),
      label,
    );
    const cleaning = items.flatMap((item) => [listCall(item.id), completeCall(item.id, true)]);
    const calls = items.length === 0 ? [claimCall(paths)] : [
      claimCall(paths),
      ...cleaning,
      claimCall(paths),
    ];
    assertEquals(admin.calls, calls, label);
  }
});

Deno.test('claims round after round until the queue answers empty', async () => {
  // A full claim of 20 items, then the last 2.
  const rounds = [
    Array.from({ length: 20 }, (_, i) => file(i + 1)),
    [file(21), file(22)],
  ];
  const admin = queue({
    claims: rounds.map((items) => ({ data: items })),
    listings: Object.fromEntries(rounds.flat().map((item) => [item.id, [page([item.path])]])),
  });

  assertEquals(await drain(admin), report({ claimed: 22, done: 22, objectsRemoved: 22 }));
  const expected: Call[] = [];
  for (const items of rounds) {
    expected.push(claimCall());
    for (const item of items) {
      expected.push(
        listCall(item.id),
        removeCall(DOCUMENTS_BUCKET, [item.path]),
        listCall(item.id),
        completeCall(item.id, true),
      );
    }
  }
  expected.push(claimCall());
  assertEquals(admin.calls, expected);
});

Deno.test('a failing claim stops the run with a 502 upstream_error, or a 503 on deadlock', async () => {
  const cases: ReadonlyArray<
    readonly [Record<string, unknown>, number, string, Record<string, string>]
  > = [
    [{ code: 'XX000', message: 'internal error' }, 502, 'upstream_error', {}],
    // supabase-js reports a network failure with an empty code.
    [{ code: '', message: 'TypeError: fetch failed' }, 502, 'upstream_error', {}],
    [{ code: '40P01', message: 'deadlock detected' }, 503, 'temporarily_unavailable', {
      'retry-after': '1',
    }],
  ];
  for (const [error, status, code, headers] of cases) {
    const label = JSON.stringify(error);
    const admin = queue({ claims: [{ error }] });
    const { failure, ...counts } = await drain(admin);
    assertInstanceOf(failure, HttpError, label);
    assertEquals(
      { status: failure.status, code: failure.code, headers: failure.headers },
      { status, code, headers },
      label,
    );
    assertStrictEquals(failure.cause, error, label);
    assertEquals({ ...counts, failure: null }, report(), label);
    assertEquals(admin.calls, [claimCall()], label);
  }
});

Deno.test('a claim failing in a later round reports the work of the earlier rounds', async () => {
  const error = { code: '40001', message: 'could not serialize access' };
  const admin = queue({
    claims: [{ data: [file(1)] }, { error }],
    listings: { 1: [page([file(1).path])] },
  });
  const { failure, ...counts } = await drain(admin);
  assertInstanceOf(failure, HttpError);
  assertEquals([failure.status, failure.code], [503, 'temporarily_unavailable']);
  assertEquals({ ...counts, failure: null }, report({ claimed: 1, done: 1, objectsRemoved: 1 }));
  assertEquals(admin.calls, [
    claimCall(),
    listCall(1),
    removeCall(DOCUMENTS_BUCKET, [file(1).path]),
    listCall(1),
    completeCall(1, true),
    claimCall(),
  ]);
});

// --- cleaning an item ------------------------------------------------------------------------

Deno.test('a folder listed over two pages is removed from its own bucket and completed as finished', async () => {
  const first = names(PAGE_SIZE);
  const second = names(3, PAGE_SIZE);
  // The database answers 'done', or 'rescheduled' while a folder's final sweep is pending.
  const cases: ReadonlyArray<readonly [string, Partial<CleanupReport>]> = [
    ['done', { done: 1 }],
    ['rescheduled', { rescheduled: 1 }],
  ];
  for (const [answer, counted] of cases) {
    const admin = queue({
      // Not DOCUMENTS_BUCKET: objects are removed from the bucket the item names.
      claims: [{ data: [folder(7, 'archive')] }],
      listings: { 7: [page(first), page(second)] },
      complete: () => ({ data: answer }),
    });
    assertEquals(
      await drain(admin),
      report({ claimed: 1, objectsRemoved: 1003, ...counted }),
      answer,
    );
    assertEquals(admin.calls, [
      claimCall(),
      listCall(7),
      removeCall('archive', first),
      listCall(7),
      removeCall('archive', second),
      listCall(7),
      completeCall(7, true),
      claimCall(),
    ], answer);
  }
});

Deno.test('an item whose listing is empty or null is finished without any removal', async () => {
  for (const empty of [{ data: [] }, { data: null }]) {
    const label = JSON.stringify(empty);
    const admin = queue({ claims: [{ data: [file(2)] }], listings: { 2: [empty] } });
    assertEquals(await drain(admin), report({ claimed: 1, done: 1 }), label);
    assertEquals(
      admin.calls,
      [claimCall(), listCall(2), completeCall(2, true), claimCall()],
      label,
    );
  }
});

Deno.test('a listing error completes the item for a retry with "list: <code>", or the message without a code', async () => {
  const cases: ReadonlyArray<readonly [Record<string, unknown>, string]> = [
    [
      { code: '57014', message: 'canceling statement due to statement timeout', hint: null },
      'list: 57014',
    ],
    [{ code: 'PGRST202', message: 'Could not find the function' }, 'list: PGRST202'],
    // A gateway error page that is not JSON: supabase-js passes on only its text.
    [{ message: 'upstream connect error' }, 'list: upstream connect error'],
    [{ code: null, message: 'no code' }, 'list: no code'],
  ];
  for (const [error, recorded] of cases) {
    const admin = queue({
      claims: [{ data: [folder(3)] }],
      listings: { 3: [{ error }] },
      complete: () => ({ data: 'retry' }),
    });
    assertEquals(await drain(admin), report({ claimed: 1, retried: 1 }), recorded);
    assertEquals(
      admin.calls,
      [claimCall(), listCall(3), completeCall(3, false, recorded), claimCall()],
      recorded,
    );
  }
});

Deno.test('a removal error completes the item for a retry with "remove: <message>"', async () => {
  const removed = names(2);
  const failing = names(5, 2);
  const storageError = { name: 'StorageApiError', message: 'Internal Server Error', status: 500 };
  const cases: ReadonlyArray<readonly [string, Answer[], Call[], number]> = [
    [
      'first page',
      [page(failing)],
      [listCall(4), removeCall(DOCUMENTS_BUCKET, failing)],
      0,
    ],
    [
      // The pages removed before the failure stay counted; the failed one does not.
      'second page',
      [page(removed), page(failing)],
      [
        listCall(4),
        removeCall(DOCUMENTS_BUCKET, removed),
        listCall(4),
        removeCall(DOCUMENTS_BUCKET, failing),
      ],
      2,
    ],
  ];
  for (const [label, listings, cleaning, objectsRemoved] of cases) {
    const admin = queue({
      claims: [{ data: [folder(4)] }],
      listings: { 4: listings },
      remove: (_bucket, objects) =>
        objects[0] === failing[0] ? { error: storageError, status: 500 } : page(objects),
      complete: () => ({ data: 'retry' }),
    });
    assertEquals(await drain(admin), report({ claimed: 1, retried: 1, objectsRemoved }), label);
    assertEquals(admin.calls, [
      claimCall(),
      ...cleaning,
      completeCall(4, false, 'remove: Internal Server Error'),
      claimCall(),
    ], label);
  }
});

Deno.test('a page listed again unchanged stops the item with "remove: objects were not deleted"', async () => {
  const stuck = names(2);
  const admin = queue({
    claims: [{ data: [folder(5)] }],
    // The removal is acknowledged, yet the same objects come back every time.
    listings: { 5: Array.from({ length: 50 }, () => page(stuck)) },
    complete: () => ({ data: 'retry' }),
  });
  assertEquals(await drain(admin), report({ claimed: 1, retried: 1, objectsRemoved: 2 }));
  assertEquals(admin.calls, [
    claimCall(),
    listCall(5),
    removeCall(DOCUMENTS_BUCKET, stuck),
    listCall(5),
    completeCall(5, false, 'remove: objects were not deleted'),
    claimCall(),
  ]);
});

Deno.test('a page that differs from the previous one in any name is removed as usual', async () => {
  // One object of the first page survived the removal, but a new one appeared after it.
  const first = names(2);
  const second = [...names(1, 1), ...names(1, 2)];
  const admin = queue({
    claims: [{ data: [folder(6)] }],
    listings: { 6: [page(first), page(second)] },
  });
  assertEquals(await drain(admin), report({ claimed: 1, done: 1, objectsRemoved: 4 }));
  assertEquals(admin.calls, [
    claimCall(),
    listCall(6),
    removeCall(DOCUMENTS_BUCKET, first),
    listCall(6),
    removeCall(DOCUMENTS_BUCKET, second),
    listCall(6),
    completeCall(6, true),
    claimCall(),
  ]);
});

// --- the deadline ----------------------------------------------------------------------------

Deno.test('a run whose deadline has already passed claims nothing', async () => {
  for (const deadline of [0, -1]) {
    const admin = queue({ claims: [{ data: [file(1)] }] });
    assertEquals(await drain(admin, { deadline }), report(), `${deadline}`);
    assertEquals(admin.calls, [], `${deadline}`);
  }
});

Deno.test('the deadline stops an item between pages: completed unfinished, without p_error', async () => {
  const first = names(2);
  const second = names(2, 2);
  // The first listing takes the clock to [reached]; a page starts only while clock() < deadline.
  const cases: ReadonlyArray<readonly [number, Call[], CleanupReport]> = [
    [
      DEADLINE - 1,
      [
        claimCall(),
        listCall(1),
        removeCall(DOCUMENTS_BUCKET, first),
        listCall(1),
        removeCall(DOCUMENTS_BUCKET, second),
        listCall(1),
        completeCall(1, true),
        claimCall(),
      ],
      report({ claimed: 1, done: 1, objectsRemoved: 4 }),
    ],
    [
      DEADLINE,
      [claimCall(), listCall(1), removeCall(DOCUMENTS_BUCKET, first), completeCall(1, false)],
      report({ claimed: 1, rescheduled: 1, objectsRemoved: 2 }),
    ],
  ];
  for (const [reached, calls, expected] of cases) {
    const time = steppingClock();
    const admin = queue({
      claims: [{ data: [folder(1)] }],
      listings: {
        1: [() => {
          time.advance(reached);
          return page(first);
        }, page(second)],
      },
      complete: (_itemId, args) => ({ data: args['p_finished'] ? 'done' : 'rescheduled' }),
    });
    assertEquals(await drain(admin, { clock: time.clock }), expected, `${reached}`);
    assertEquals(admin.calls, calls, `${reached}`);
  }
});

Deno.test('the items after the one the deadline interrupted are handed back without a listing', async () => {
  const time = steppingClock();
  const objects = names(2);
  const admin = queue({
    claims: [{ data: [folder(1), file(2), file(3)] }],
    listings: {
      1: [() => {
        time.advance(DEADLINE);
        return page(objects);
      }],
    },
    complete: () => ({ data: 'rescheduled' }),
  });
  assertEquals(
    await drain(admin, { clock: time.clock }),
    report({ claimed: 3, rescheduled: 3, objectsRemoved: 2 }),
  );
  assertEquals(admin.calls, [
    claimCall(),
    listCall(1),
    removeCall(DOCUMENTS_BUCKET, objects),
    completeCall(1, false),
    completeCall(2, false),
    completeCall(3, false),
  ]);
  for (const call of admin.calls.slice(3)) assertFalse('p_error' in argsOf(call));
});

Deno.test('items claimed as the deadline passes are all handed back without any listing', async () => {
  const time = steppingClock();
  const admin = queue({
    claims: [() => {
      time.advance(DEADLINE);
      return { data: [folder(1), file(2), file(3)] };
    }],
    complete: () => ({ data: 'rescheduled' }),
  });
  assertEquals(
    await drain(admin, { clock: time.clock }),
    report({ claimed: 3, rescheduled: 3 }),
  );
  assertEquals(admin.calls, [
    claimCall(),
    completeCall(1, false),
    completeCall(2, false),
    completeCall(3, false),
  ]);
});

Deno.test('the clock is read again before the first page: a deadline passing in between hands the item back', async () => {
  // Every reading moves the clock 10 ms on: 0 before the claim, 10 before the item, 20 before its page.
  const admin = queue({ claims: [{ data: [file(1)] }], complete: () => ({ data: 'rescheduled' }) });
  assertEquals(
    await drain(admin, { deadline: 15, clock: steppingClock(10).clock }),
    report({ claimed: 1, rescheduled: 1 }),
  );
  assertEquals(admin.calls, [claimCall(), completeCall(1, false)]);
});

// --- completing an item --------------------------------------------------------------------

Deno.test('each item is counted under the answer of the database: done, rescheduled or retry', async () => {
  const answers: Record<number, string> = { 1: 'done', 2: 'rescheduled', 3: 'retry' };
  const admin = queue({
    claims: [{ data: [file(1), folder(2), folder(3, DOCUMENTS_BUCKET, OTHER_FOLDER)] }],
    listings: { 3: [{ error: { code: '57014', message: 'statement timeout' } }] },
    complete: (itemId) => ({ data: answers[itemId] }),
  });
  assertEquals(await drain(admin), report({ claimed: 3, done: 1, rescheduled: 1, retried: 1 }));
  assertEquals(admin.calls, [
    claimCall(),
    listCall(1),
    completeCall(1, true),
    listCall(2),
    completeCall(2, true),
    listCall(3),
    completeCall(3, false, 'list: 57014'),
    claimCall(),
  ]);
});

Deno.test('a "missing" answer (the item already left the queue) is counted nowhere', async () => {
  const admin = queue({
    claims: [{ data: [file(1), file(2)] }],
    complete: (itemId) => ({ data: itemId === 1 ? 'missing' : 'done' }),
  });
  assertEquals(await drain(admin), report({ claimed: 2, done: 1 }));
});

Deno.test('a failing completion stops the run, keeps its count and leaves the rest to lapse', async () => {
  const cases: ReadonlyArray<readonly [Record<string, unknown>, number, string]> = [
    [{ code: 'XX000', message: 'internal error' }, 502, 'upstream_error'],
    [{ code: '40001', message: 'could not serialize access' }, 503, 'temporarily_unavailable'],
  ];
  for (const [error, status, code] of cases) {
    const admin = queue({
      claims: [{ data: [file(1), file(2)] }],
      listings: { 1: [page([file(1).path])] },
      complete: () => ({ error }),
    });
    const { failure, ...counts } = await drain(admin);
    assertInstanceOf(failure, HttpError, code);
    assertEquals([failure.status, failure.code], [status, code], code);
    assertStrictEquals(failure.cause, error, code);
    // The file was removed before the completion failed: it is counted.
    assertEquals({ ...counts, failure: null }, report({ claimed: 2, objectsRemoved: 1 }), code);
    assertEquals(admin.calls, [
      claimCall(),
      listCall(1),
      removeCall(DOCUMENTS_BUCKET, [file(1).path]),
      listCall(1),
      completeCall(1, true),
    ], code);
  }
});

Deno.test('only objects the Storage API reports as deleted are counted', async () => {
  const admin = queue({
    claims: [{ data: [folder(1)] }],
    listings: { 1: [page(['a', 'b', 'c'])] },
    // Storage deleted one of the three (the others were already gone).
    remove: () => ({ data: [{ name: 'a' }] }),
  });
  assertEquals(await drain(admin), report({ claimed: 1, done: 1, objectsRemoved: 1 }));
  const nothing = queue({
    claims: [{ data: [folder(1)] }],
    listings: { 1: [page(['a'])] },
    remove: () => ({ data: null }),
  });
  assertEquals(await drain(nothing), report({ claimed: 1, done: 1, objectsRemoved: 0 }));
});

Deno.test('a listing failing with an empty code records the message; with neither, "failed"', async () => {
  const cases: ReadonlyArray<readonly [Record<string, unknown>, string]> = [
    [{ code: '', message: 'TypeError: fetch failed' }, 'list: TypeError: fetch failed'],
    [{ code: '', message: '' }, 'list: failed'],
    [{ code: '57014', message: 'canceling statement' }, 'list: 57014'],
  ];
  for (const [error, recorded] of cases) {
    const admin = queue({ claims: [{ data: [file(9)] }], listings: { 9: [{ error }] } });
    await drain(admin);
    assertEquals(admin.calls, [
      claimCall(),
      listCall(9),
      completeCall(9, false, recorded),
      claimCall(),
    ], recorded);
  }
});

Deno.test('objectsRemoved totals the objects of every page removed, across items', async () => {
  const admin = queue({
    claims: [{ data: [folder(1), file(2), folder(3, DOCUMENTS_BUCKET, OTHER_FOLDER)] }],
    listings: {
      1: [page(names(PAGE_SIZE)), page(names(3, PAGE_SIZE))],
      2: [page([file(2).path])],
      // Two objects go before the next listing fails: they still count.
      3: [page(names(2, 0, OTHER_FOLDER)), { error: { code: '57014', message: 'timeout' } }],
    },
    complete: (itemId) => ({ data: itemId === 3 ? 'retry' : 'done' }),
  });
  assertEquals(
    await drain(admin),
    report({ claimed: 3, done: 2, retried: 1, objectsRemoved: 1000 + 3 + 1 + 2 }),
  );
});
