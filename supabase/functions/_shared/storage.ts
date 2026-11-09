/**
 * Durable storage cleanup: drains `private.storage_cleanup_queue` through the
 * Storage API (deleting rows of storage.objects directly would leave the
 * files behind).
 *
 * The database decides what may go: it queues files when documents,
 * entities or portfolios are deleted, and never lists an object that a live
 * document row references. This module only deletes what it is given, a
 * page at a time, within a time budget, and reports each item back so it is
 * finished, swept again later, or retried with backoff.
 */

import { fromServiceFailure, type HttpError } from './errors.ts';
import type { Context } from './handler.ts';

export const DOCUMENTS_BUCKET = 'documents';
/** Queue items claimed per round trip. */
export const CLAIM_LIMIT = 20;
/** How long a claim is held before another cleaner may take the item. */
export const CLAIM_LEASE_SECONDS = 120;
/** Objects listed and removed per round trip (the Storage API's maximum). */
export const PAGE_SIZE = 1000;

type Admin = Context['supabaseAdmin'];

export interface CleanupItem {
  readonly id: number;
  readonly bucket_id: string;
  readonly path: string;
  readonly is_prefix: boolean;
  readonly attempts: number;
}

export interface CleanupReport {
  /** Items claimed from the queue. */
  claimed: number;
  /** Items finished and removed from the queue. */
  done: number;
  /** Items due again (budget spent, or a folder's final sweep pending). */
  rescheduled: number;
  /** Items that failed and will be retried with backoff. */
  retried: number;
  /** Objects the Storage API reported as deleted. */
  objectsRemoved: number;
  /**
   * The database failure that stopped the run early, or null. The counts
   * cover the work done before it; claimed items lapse on their own and are
   * taken up again by a later run.
   */
  failure: HttpError | null;
}

export interface CleanupOptions {
  /** Milliseconds on [clock] after which no new work starts. */
  readonly deadline: number;
  /** Monotonic milliseconds, e.g. `performance.now`. */
  readonly clock: () => number;
  /** Restrict the run to these queued paths (e.g. folders just deleted). */
  readonly paths?: readonly string[];
}

interface ItemOutcome {
  readonly finished: boolean;
  readonly removed: number;
  readonly error: string | null;
}

/** Deletes every object the database lists for [item], page by page. */
async function cleanItem(
  admin: Admin,
  item: CleanupItem,
  options: CleanupOptions,
): Promise<ItemOutcome> {
  let removed = 0;
  let previousPage: string | null = null;
  while (options.clock() < options.deadline) {
    const listing = await admin.rpc('admin_storage_cleanup_objects', {
      p_item_id: item.id,
      p_limit: PAGE_SIZE,
    });
    if (listing.error !== null) {
      // supabase-js reports a failed fetch with an empty code: fall back to
      // its message, so the queue records why.
      return {
        finished: false,
        removed,
        error: `list: ${listing.error.code || listing.error.message || 'failed'}`,
      };
    }
    const names = (listing.data ?? []).map((row) => row.name);
    if (names.length === 0) return { finished: true, removed, error: null };

    // A page that comes back unchanged was not deleted: stop instead of spinning.
    const page = names.join('\n');
    if (page === previousPage) {
      return { finished: false, removed, error: 'remove: objects were not deleted' };
    }
    previousPage = page;

    const deletion = await admin.storage.from(item.bucket_id).remove(names);
    if (deletion.error !== null) {
      return { finished: false, removed, error: `remove: ${deletion.error.message}` };
    }
    removed += (deletion.data ?? []).length;
  }
  return { finished: false, removed, error: null };
}

function complete(admin: Admin, item: CleanupItem, outcome: ItemOutcome) {
  return admin.rpc('admin_complete_storage_cleanup', {
    p_item_id: item.id,
    p_finished: outcome.finished,
    ...(outcome.error === null ? {} : { p_error: outcome.error }),
  });
}

/**
 * Claims due queue items and cleans them until the queue is empty or the
 * deadline passes. Items claimed but not reached are handed back at once.
 * A database failure stops the run and is returned in the report's
 * `failure`, with the counts of the work done before it.
 */
export async function drainStorageCleanup(
  admin: Admin,
  options: CleanupOptions,
): Promise<CleanupReport> {
  const report: CleanupReport = {
    claimed: 0,
    done: 0,
    rescheduled: 0,
    retried: 0,
    objectsRemoved: 0,
    failure: null,
  };
  while (options.clock() < options.deadline) {
    const { data, error } = await admin.rpc('admin_claim_storage_cleanup', {
      p_limit: CLAIM_LIMIT,
      p_lease_seconds: CLAIM_LEASE_SECONDS,
      ...(options.paths === undefined ? {} : { p_paths: [...options.paths] }),
    });
    if (error !== null) return { ...report, failure: fromServiceFailure(error) };
    const items = (data ?? []) as CleanupItem[];
    if (items.length === 0) break;
    report.claimed += items.length;

    for (const item of items) {
      const outcome = options.clock() < options.deadline
        ? await cleanItem(admin, item, options)
        : { finished: false, removed: 0, error: null };
      report.objectsRemoved += outcome.removed;
      const { data: result, error: failure } = await complete(admin, item, outcome);
      if (failure !== null) return { ...report, failure: fromServiceFailure(failure) };
      if (result === 'done') report.done += 1;
      else if (result === 'retry') report.retried += 1;
      else if (result === 'rescheduled') report.rescheduled += 1;
    }
  }
  return report;
}
