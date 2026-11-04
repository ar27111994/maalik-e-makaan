/**
 * delete-account: in-app account deletion (requirement AUTH-03).
 *
 *   GET  → preview: the portfolios that would be deleted with the account
 *          (those where the caller is the only owner).
 *   POST → delete. Requires `{ "confirm_email": "<the caller's e-mail>" }`,
 *          a sign-in within REAUTH_MAX_AGE_SECONDS, and a second factor when
 *          the account has one.
 *
 * Deletion order is chosen so that a failure at any step can simply be
 * retried and so that no personal files can outlive their records:
 *   1. files of the sole-owned portfolios (CNIC photos, agreements …);
 *   2. the portfolios themselves, memberships and notifications
 *      (admin_delete_account_data);
 *   3. the auth user (profile and sessions cascade). An already-deleted user
 *      counts as success.
 */

import type { JWTClaims, SupabaseContext } from '@supabase/server';
import { fromDatabaseFailure, HttpError, invalidField } from '../_shared/errors.ts';
import {
  createHandler,
  defaultDeps,
  type PipelineDeps,
  type RequestContext,
  requireUser,
} from '../_shared/handler.ts';
import { json, readJsonObject } from '../_shared/http.ts';
import { rejectUnknownFields, requireEmail } from '../_shared/validation.ts';

export const DOCUMENTS_BUCKET = 'documents';
/** Storage list page size (the API maximum). */
export const LIST_PAGE_SIZE = 1000;
/** Objects removed per storage API call. */
export const REMOVE_BATCH_SIZE = 100;
/** Safety valve against runaway listings. */
export const MAX_OBJECTS = 100_000;

/** Authentication methods that do not prove the account holder signed in recently. */
const NON_INTERACTIVE_METHODS = new Set(['anonymous', 'token_refresh']);

interface ScopeRow {
  readonly portfolio_id: string;
  readonly portfolio_name: string;
  readonly other_members: number;
}

type Admin = SupabaseContext['supabaseAdmin'];

/** Unix time (seconds) of the caller's most recent interactive sign-in, from the `amr` claim. */
export function lastSignInAt(claims: JWTClaims | null): number | null {
  const amr = claims?.['amr'];
  if (!Array.isArray(amr)) return null;
  let latest: number | null = null;
  for (const entry of amr) {
    if (entry === null || typeof entry !== 'object') continue;
    const { method, timestamp } = entry as { method?: unknown; timestamp?: unknown };
    if (typeof method !== 'string' || NON_INTERACTIVE_METHODS.has(method)) continue;
    if (typeof timestamp !== 'number' || !Number.isFinite(timestamp)) continue;
    latest = latest === null ? timestamp : Math.max(latest, timestamp);
  }
  return latest;
}

function ensureRecentSignIn(ctx: RequestContext): void {
  const signedInAt = lastSignInAt(ctx.supabase.jwtClaims);
  const nowSeconds = Math.floor(ctx.now().getTime() / 1000);
  const maxAge = ctx.config.reauthMaxAgeSeconds;
  if (signedInAt === null || nowSeconds - signedInAt > maxAge) {
    throw new HttpError(401, 'reauthentication_required', 'Sign in again to delete your account.', {
      details: { max_age_seconds: maxAge },
    });
  }
}

/** Accounts with a verified second factor must present it (aal2) to delete themselves. */
async function ensureStrongAuthentication(ctx: RequestContext, userId: string): Promise<void> {
  if (ctx.supabase.jwtClaims?.['aal'] === 'aal2') return;
  const { data, error } = await ctx.supabase.supabaseAdmin.auth.admin.mfa.listFactors({ userId });
  if (error !== null) {
    throw new HttpError(502, 'upstream_error', 'Could not check two-step verification.', {
      cause: error,
    });
  }
  if (data.factors.some((factor) => factor.status === 'verified')) {
    throw new HttpError(403, 'mfa_required', 'Verify with your second factor to continue.');
  }
}

async function deletionScope(admin: Admin, userId: string): Promise<ScopeRow[]> {
  const { data, error, status } = await admin.rpc('admin_account_deletion_scope', {
    p_user_id: userId,
  });
  if (error !== null) throw fromDatabaseFailure(error, status);
  return (data ?? []) as ScopeRow[];
}

/** Every object path under [prefix] (recursive; folders have a null id). */
export async function listObjects(
  admin: Admin,
  prefix: string,
  maxObjects: number = MAX_OBJECTS,
): Promise<string[]> {
  const bucket = admin.storage.from(DOCUMENTS_BUCKET);
  const files: string[] = [];
  const folders = [prefix];
  while (folders.length > 0) {
    const folder = folders.pop() as string;
    for (let offset = 0;; offset += LIST_PAGE_SIZE) {
      const { data, error } = await bucket.list(folder, {
        limit: LIST_PAGE_SIZE,
        offset,
        sortBy: { column: 'name', order: 'asc' },
      });
      if (error !== null) {
        throw new HttpError(502, 'upstream_error', 'Could not list stored documents.', {
          cause: error,
        });
      }
      for (const entry of data) {
        const path = `${folder}/${entry.name}`;
        if (entry.id === null) {
          folders.push(path);
        } else {
          files.push(path);
        }
        if (files.length > maxObjects) {
          throw new HttpError(
            502,
            'upstream_error',
            'Too many stored documents to delete at once.',
          );
        }
      }
      if (data.length < LIST_PAGE_SIZE) break;
    }
  }
  return files;
}

/** Removes every object of a portfolio's folder; returns how many were removed. */
export async function removePortfolioFiles(admin: Admin, portfolioId: string): Promise<number> {
  const paths = await listObjects(admin, portfolioId);
  const bucket = admin.storage.from(DOCUMENTS_BUCKET);
  for (let start = 0; start < paths.length; start += REMOVE_BATCH_SIZE) {
    const { error } = await bucket.remove(paths.slice(start, start + REMOVE_BATCH_SIZE));
    if (error !== null) {
      throw new HttpError(502, 'upstream_error', 'Could not delete stored documents.', {
        cause: error,
      });
    }
  }
  return paths.length;
}

async function preview(ctx: RequestContext): Promise<Response> {
  const user = requireUser(ctx);
  const scope = await deletionScope(ctx.supabase.supabaseAdmin, user.id);
  return json({
    portfolios_to_delete: scope.map((row) => ({
      id: row.portfolio_id,
      name: row.portfolio_name,
      other_members: row.other_members,
    })),
    sign_in_max_age_seconds: ctx.config.reauthMaxAgeSeconds,
  });
}

async function deleteAccount(ctx: RequestContext): Promise<Response> {
  const user = requireUser(ctx);
  const body = await readJsonObject(ctx.req);
  rejectUnknownFields(body, ['confirm_email']);
  const confirmEmail = requireEmail(body, 'confirm_email');

  ensureRecentSignIn(ctx);
  await ensureStrongAuthentication(ctx, user.id);
  if (user.email === null || confirmEmail !== user.email.trim().toLowerCase()) {
    throw invalidField('confirm_email', 'does_not_match_account');
  }

  const admin = ctx.supabase.supabaseAdmin;
  const scope = await deletionScope(admin, user.id);
  let filesRemoved = 0;
  for (const row of scope) {
    filesRemoved += await removePortfolioFiles(admin, row.portfolio_id);
  }

  const { data, error, status } = await admin.rpc('admin_delete_account_data', {
    p_user_id: user.id,
  });
  if (error !== null) throw fromDatabaseFailure(error, status);
  const deletedPortfolioIds = (data as { deleted_portfolio_ids?: string[] } | null)
    ?.deleted_portfolio_ids ?? [];

  const { error: authError } = await admin.auth.admin.deleteUser(user.id);
  if (authError !== null && authError.status !== 404) {
    throw new HttpError(502, 'upstream_error', 'The account could not be deleted.', {
      cause: authError,
    });
  }

  ctx.log.info('account_deleted', {
    user_id: user.id,
    portfolios_deleted: deletedPortfolioIds.length,
    files_removed: filesRemoved,
  });
  return json({
    deleted: true,
    deleted_portfolio_ids: deletedPortfolioIds,
    files_removed: filesRemoved,
  });
}

export function createDeleteAccountHandler(
  deps: PipelineDeps = defaultDeps,
): (req: Request) => Promise<Response> {
  return createHandler(
    {
      name: 'delete-account',
      methods: ['GET', 'POST'],
      auth: 'user',
      handle: (ctx) => ctx.req.method === 'GET' ? preview(ctx) : deleteAccount(ctx),
    },
    deps,
  );
}
