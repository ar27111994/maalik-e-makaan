/**
 * delete-account: in-app account deletion (requirement AUTH-03).
 *
 *   GET  → preview: { portfolios_to_delete, reauth_max_age_seconds,
 *          second_factor_required }. Portfolios the caller owns alone are
 *          deleted with the account; from the others the caller is removed.
 *   POST { "confirm_email": "<the account's e-mail>" }
 *        → { deleted, deleted_portfolio_ids, files_removed }
 *
 * Every check fails closed, in this order:
 *   1. at most 10 calls per user per 10 minutes;
 *   2. the session is still live: Auth rejects signed-out sessions. A retry
 *      after a completed deletion finds the account gone and gets success;
 *   3. confirm_email equals the account's e-mail as Auth stores it now (not
 *      the token's copy), ignoring case;
 *   4. a first-factor sign-in (password, one-time code, magic link, OAuth,
 *      SSO, …) within REAUTH_MAX_AGE_SECONDS. A second factor or a token
 *      refresh is not a sign-in, so a stolen session cannot step itself up;
 *   5. accounts with a verified second factor must present it (aal2).
 *
 * Then the database deletes the portfolios the caller owns alone (queuing
 * their files) and removes every membership, under locks that keep a
 * co-owner's simultaneous deletion from orphaning a portfolio; the auth user
 * is deleted (already gone counts as success); and the deleted portfolios'
 * files are removed for up to CLEANUP_BUDGET_MS, the storage-cleanup
 * function finishing whatever is left. Each step can simply be retried.
 */

import type { User } from '@supabase/supabase-js';
import {
  fromServiceFailure,
  HttpError,
  invalidField,
  reauthenticationRequired,
  unauthorized,
} from '../_shared/errors.ts';
import {
  type Context,
  createHandler,
  defaultDeps,
  type PipelineDeps,
  type RequestContext,
  requireUser,
} from '../_shared/handler.ts';
import { json, readJsonObject } from '../_shared/http.ts';
import { hitRateLimit, type RateLimit, rateLimitedError } from '../_shared/rate_limit.ts';
import { drainStorageCleanup } from '../_shared/storage.ts';
import { rejectUnknownFields, requireText } from '../_shared/validation.ts';

type Admin = Context['supabaseAdmin'];

/** Calls per user, shared by the preview and the deletion. */
export const DELETE_ACCOUNT_LIMIT = { limit: 10, windowSeconds: 600 } as const;
/** How long the request itself spends removing files before leaving the rest to storage-cleanup. */
export const CLEANUP_BUDGET_MS = 8_000;
/** Longest accepted confirmation (an e-mail address is at most 320 characters). */
export const MAX_CONFIRMATION_LENGTH = 320;
/** Clock skew tolerated on sign-in timestamps. */
export const MAX_CLOCK_SKEW_SECONDS = 60;

/**
 * `amr` methods that prove the account holder signed in: a first factor.
 * Deliberately absent: `totp` and other second factors, `token_refresh`,
 * `anonymous`, `invite` and `email_change` (they prove no sign-in), and
 * `oauth_provider/*` (consent given to a third-party app).
 */
export const FIRST_FACTOR_METHODS: ReadonlySet<string> = new Set([
  'password',
  'otp',
  'magiclink',
  'oauth',
  'sso/saml',
  'web3',
  'recovery',
  'email/signup',
]);

export interface DeleteAccountDeps extends PipelineDeps {
  /** Monotonic milliseconds. */
  readonly clock: () => number;
}

/**
 * Unix time (seconds) of the caller's latest first-factor sign-in, from the
 * `amr` claim. Entries with a timestamp that is not a whole number of
 * seconds, or lies in the future, are ignored.
 */
export function lastSignInAt(claims: Context['jwtClaims'], nowSeconds: number): number | null {
  const amr = claims?.['amr'];
  if (!Array.isArray(amr)) return null;
  let latest: number | null = null;
  for (const entry of amr) {
    if (entry === null || typeof entry !== 'object') continue;
    const { method, timestamp } = entry as { method?: unknown; timestamp?: unknown };
    if (typeof method !== 'string' || !FIRST_FACTOR_METHODS.has(method)) continue;
    if (typeof timestamp !== 'number' || !Number.isSafeInteger(timestamp)) continue;
    if (timestamp > nowSeconds + MAX_CLOCK_SKEW_SECONDS) continue;
    latest = latest === null ? timestamp : Math.max(latest, timestamp);
  }
  return latest;
}

function ensureRecentSignIn(ctx: RequestContext): void {
  const nowSeconds = Math.floor(ctx.now().getTime() / 1000);
  const signedInAt = lastSignInAt(ctx.supabase.jwtClaims, nowSeconds);
  const maxAge = ctx.config.reauthMaxAgeSeconds();
  if (signedInAt === null || nowSeconds - signedInAt > maxAge) {
    throw reauthenticationRequired(maxAge, 'Sign in again to delete your account.');
  }
}

function hasVerifiedFactor(user: User): boolean {
  return (user.factors ?? []).some((factor) => factor.status === 'verified');
}

function ensureStrongAuthentication(ctx: RequestContext, user: User): void {
  if (hasVerifiedFactor(user) && ctx.supabase.jwtClaims?.['aal'] !== 'aal2') {
    throw new HttpError(403, 'mfa_required', 'Verify with your second factor to continue.');
  }
}

async function enforceLimit(ctx: RequestContext, userId: string): Promise<void> {
  const rule: RateLimit = { key: `delete_account:user:${userId}`, ...DELETE_ACCOUNT_LIMIT };
  if (!await hitRateLimit(ctx.supabase.supabaseAdmin, rule)) {
    throw rateLimitedError(ctx.now(), rule);
  }
}

function bearerToken(req: Request): string {
  const match = /^Bearer\s+(\S+)$/i.exec(req.headers.get('authorization') ?? '');
  if (match === null) throw unauthorized();
  return match[1] as string;
}

type Account = { readonly kind: 'live'; readonly user: User } | { readonly kind: 'deleted' };

/** Auth error codes and statuses that mean "this session or user is gone". */
const GONE_CODES = new Set(['session_not_found', 'user_not_found', 'bad_jwt']);
const GONE_STATUSES = new Set([401, 403, 404]);

function isGone(error: { status?: number; code?: string }): boolean {
  return GONE_CODES.has(error.code ?? '') || GONE_STATUSES.has(error.status ?? 0);
}

/**
 * The caller's account as Auth stores it now, read with the caller's own
 * token, so a session that was signed out is refused even though its JWT is
 * still unexpired. When the session is gone, a deleted account is reported
 * as such (for idempotent retries); a live one means the session ended.
 */
async function liveAccount(ctx: RequestContext, userId: string): Promise<Account> {
  const admin = ctx.supabase.supabaseAdmin;
  const { data, error } = await admin.auth.getUser(bearerToken(ctx.req));
  if (error === null) {
    if (data.user.id !== userId) throw unauthorized();
    return { kind: 'live', user: data.user };
  }
  if (!isGone(error)) {
    throw new HttpError(502, 'upstream_error', 'Could not check your session.', { cause: error });
  }
  const lookup = await admin.auth.admin.getUserById(userId);
  if (lookup.error !== null) {
    if (lookup.error.status === 404 || lookup.error.code === 'user_not_found') {
      return { kind: 'deleted' };
    }
    throw new HttpError(502, 'upstream_error', 'Could not check your account.', {
      cause: lookup.error,
    });
  }
  throw unauthorized('Your session has ended. Sign in again.', { reason: 'session_ended' });
}

async function deletionScope(admin: Admin, userId: string) {
  const { data, error } = await admin.rpc('admin_account_deletion_scope', { p_user_id: userId });
  if (error !== null) throw fromServiceFailure(error);
  return data ?? [];
}

function parseDeletedIds(data: unknown): string[] {
  const ids = (data as { deleted_portfolio_ids?: unknown } | null)?.deleted_portfolio_ids;
  if (!Array.isArray(ids) || !ids.every((id) => typeof id === 'string')) {
    throw new HttpError(502, 'upstream_error', 'The account data could not be deleted.', {
      cause: new Error('unexpected admin_delete_account_data response'),
    });
  }
  return ids;
}

async function preview(ctx: RequestContext): Promise<Response> {
  const caller = requireUser(ctx);
  await enforceLimit(ctx, caller.id);
  const account = await liveAccount(ctx, caller.id);
  if (account.kind === 'deleted') {
    throw unauthorized('Your session has ended. Sign in again.', { reason: 'session_ended' });
  }
  const scope = await deletionScope(ctx.supabase.supabaseAdmin, caller.id);
  return json({
    portfolios_to_delete: scope.map((row) => ({
      id: row.portfolio_id,
      name: row.portfolio_name,
      other_members: row.other_members,
    })),
    reauth_max_age_seconds: ctx.config.reauthMaxAgeSeconds(),
    second_factor_required: hasVerifiedFactor(account.user),
  });
}

async function deleteAccount(ctx: RequestContext, deps: DeleteAccountDeps): Promise<Response> {
  const caller = requireUser(ctx);
  await enforceLimit(ctx, caller.id);
  const body = await readJsonObject(ctx.req);
  rejectUnknownFields(body, ['confirm_email']);
  const confirmation = requireText(body, 'confirm_email', MAX_CONFIRMATION_LENGTH);

  const account = await liveAccount(ctx, caller.id);
  if (account.kind === 'deleted') {
    ctx.log.info('account_already_deleted', { user_id: caller.id });
    return json({ deleted: true, deleted_portfolio_ids: [], files_removed: 0 });
  }
  const email = account.user.email?.trim().toLowerCase() ?? '';
  if (email === '') throw invalidField('confirm_email', 'account_has_no_email');
  if (confirmation.toLowerCase() !== email) {
    throw invalidField('confirm_email', 'does_not_match_account');
  }
  ensureRecentSignIn(ctx);
  ensureStrongAuthentication(ctx, account.user);

  const admin = ctx.supabase.supabaseAdmin;
  const deletion = await admin.rpc('admin_delete_account_data', { p_user_id: caller.id });
  if (deletion.error !== null) throw fromServiceFailure(deletion.error);
  const deletedIds = parseDeletedIds(deletion.data);

  const { error: authError } = await admin.auth.admin.deleteUser(caller.id);
  if (authError !== null && authError.status !== 404) {
    throw new HttpError(502, 'upstream_error', 'The account could not be deleted.', {
      cause: authError,
    });
  }

  // The account is gone; files left over are queued and storage-cleanup
  // removes them, so a failure here is logged, not reported.
  let filesRemoved = 0;
  if (deletedIds.length > 0) {
    try {
      const report = await drainStorageCleanup(admin, {
        paths: deletedIds.map((id) => `${id}/`),
        deadline: deps.clock() + CLEANUP_BUDGET_MS,
        clock: deps.clock,
      });
      filesRemoved = report.objectsRemoved;
      if (report.failure !== null) {
        ctx.log.error('account_files_cleanup_deferred', {
          user_id: caller.id,
          error: report.failure,
        });
      }
    } catch (error) {
      // The account is already gone; the queued files are removed later.
      ctx.log.error('account_files_cleanup_deferred', { user_id: caller.id, error });
    }
  }

  ctx.log.info('account_deleted', {
    user_id: caller.id,
    portfolios_deleted: deletedIds.length,
    files_removed: filesRemoved,
  });
  return json({ deleted: true, deleted_portfolio_ids: deletedIds, files_removed: filesRemoved });
}

export const defaultDeleteAccountDeps: DeleteAccountDeps = {
  ...defaultDeps,
  clock: () => performance.now(),
};

export function createDeleteAccountHandler(
  deps: DeleteAccountDeps = defaultDeleteAccountDeps,
): (req: Request) => Promise<Response> {
  return createHandler(
    {
      name: 'delete-account',
      auth: 'user',
      routes: { GET: preview, POST: (ctx) => deleteAccount(ctx, deps) },
    },
    deps,
  );
}
