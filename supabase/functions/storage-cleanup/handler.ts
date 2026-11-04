/**
 * storage-cleanup: deletes the files the database queued for deletion.
 *
 *   POST (any body) → 200 { claimed, done, rescheduled, retried, objects_removed }
 *
 * pg_cron calls it every 10 minutes through pg_net while the queue has due
 * work (private.request_storage_cleanup), presenting
 * `x-cleanup-token: <STORAGE_CLEANUP_TOKEN>`, which is compared in constant
 * time. There is no user context: the function works with the secret key
 * only, and only on what the queue lists.
 */

import { timingSafeEqual } from '../_shared/crypto.ts';
import { HttpError, unauthorized } from '../_shared/errors.ts';
import {
  createHandler,
  defaultDeps,
  type PipelineDeps,
  type RequestContext,
} from '../_shared/handler.ts';
import { json } from '../_shared/http.ts';
import { drainStorageCleanup } from '../_shared/storage.ts';

/** Work stops being started after this long (pg_net waits up to 60 s). */
export const TIME_BUDGET_MS = 25_000;

export interface StorageCleanupDeps extends PipelineDeps {
  /** Monotonic milliseconds. */
  readonly clock: () => number;
}

async function requireCleanupToken(ctx: RequestContext): Promise<void> {
  const expected = ctx.config.storageCleanupToken();
  if (expected === null) {
    throw new HttpError(500, 'server_misconfigured', 'Storage cleanup is not configured.', {
      details: { variable: 'STORAGE_CLEANUP_TOKEN' },
    });
  }
  const presented = ctx.req.headers.get('x-cleanup-token') ?? '';
  if (!await timingSafeEqual(presented, expected)) {
    throw unauthorized('A valid cleanup token is required.');
  }
}

async function cleanup(ctx: RequestContext, deps: StorageCleanupDeps): Promise<Response> {
  await requireCleanupToken(ctx);
  const report = await drainStorageCleanup(ctx.supabase.supabaseAdmin, {
    deadline: deps.clock() + TIME_BUDGET_MS,
    clock: deps.clock,
  });
  ctx.log.info('storage_cleanup', { ...report });
  return json({
    claimed: report.claimed,
    done: report.done,
    rescheduled: report.rescheduled,
    retried: report.retried,
    objects_removed: report.objectsRemoved,
  });
}

export const defaultStorageCleanupDeps: StorageCleanupDeps = {
  ...defaultDeps,
  clock: () => performance.now(),
};

export function createStorageCleanupHandler(
  deps: StorageCleanupDeps = defaultStorageCleanupDeps,
): (req: Request) => Promise<Response> {
  return createHandler(
    { name: 'storage-cleanup', auth: 'none', routes: { POST: (ctx) => cleanup(ctx, deps) } },
    deps,
  );
}
