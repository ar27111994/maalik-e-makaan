/**
 * invite-member: owners invite people by e-mail and role (requirement TEAM-03).
 *
 *   POST { "portfolio_id", "email", "role", "locale"? }
 *     → 201 { invitation_id, email, role, expires_at, invite_url, email_delivery }
 *
 * The invitation is created by the database (`create_invitation`), as the
 * caller, so ownership, the per-owner rate limit, e-mail validation and the
 * split selector/verifier token all stay in one place. This function adds
 * the shareable link and, when e-mail is configured, sends it. The link is
 * returned either way so the owner can also share it over WhatsApp.
 *
 * The token travels in the URL fragment (`#token=…`), which browsers never
 * send to servers, so it cannot leak into access logs or Referer headers.
 */

import { ConfigError, type EmailConfig } from '../_shared/config.ts';
import { sha256Hex } from '../_shared/crypto.ts';
import { createResendSender, type EmailSender } from '../_shared/email.ts';
import { fromDatabaseFailure, HttpError } from '../_shared/errors.ts';
import {
  createHandler,
  defaultDeps,
  type PipelineDeps,
  type RequestContext,
  requireUser,
} from '../_shared/handler.ts';
import { json, readJsonObject } from '../_shared/http.ts';
import { hitRateLimit, type RateLimit } from '../_shared/rate_limit.ts';
import {
  optionalEnum,
  rejectUnknownFields,
  requireEmail,
  requireEnum,
  requireUuid,
} from '../_shared/validation.ts';
import { type InviteRole, type Locale, renderInvitationEmail } from './email.ts';

export const INVITE_ROLES: readonly InviteRole[] = ['owner', 'manager', 'accountant', 'viewer'];
export const LOCALES: readonly Locale[] = ['en', 'ur'];

/** Caps on outgoing e-mail, on top of the database's 20 invitations per owner per hour. */
export const EMAIL_LIMITS = {
  perInviter: { limit: 10, windowSeconds: 3600 },
  perRecipient: { limit: 3, windowSeconds: 3600 },
} as const;

export type EmailDelivery = 'sent' | 'not_configured' | 'rate_limited' | 'failed';

export interface InviteMemberDeps extends PipelineDeps {
  readonly createSender: (config: EmailConfig) => EmailSender;
}

interface Invitation {
  readonly invitation_id: string;
  readonly email: string;
  readonly role: InviteRole;
  readonly expires_at: string;
  readonly token: string;
}

/** The link that opens the invitation in the app. */
export function buildInviteUrl(appUrl: string, token: string): string {
  return `${appUrl}/invite#token=${encodeURIComponent(token)}`;
}

function parseInvitation(data: unknown): Invitation {
  const value = data as Partial<Record<keyof Invitation, unknown>> | null;
  if (
    typeof value?.invitation_id !== 'string' || typeof value.email !== 'string' ||
    typeof value.role !== 'string' || typeof value.expires_at !== 'string' ||
    typeof value.token !== 'string'
  ) {
    throw new HttpError(502, 'upstream_error', 'The invitation could not be created.', {
      cause: new Error('unexpected create_invitation response'),
    });
  }
  return value as Invitation;
}

const GMAIL_DOMAINS = new Set(['gmail.com', 'googlemail.com']);

/**
 * The mailbox an address delivers to, for counting e-mails per recipient:
 * lower-cased, without a `+tag`, and for Gmail without dots and with
 * googlemail.com folded into gmail.com, so aliases of one mailbox share one
 * quota. The invitation itself keeps the address as typed.
 */
export function canonicalMailbox(address: string): string {
  const at = address.lastIndexOf('@');
  let local = address.slice(0, at).toLowerCase();
  let domain = address.slice(at + 1).toLowerCase();
  const plus = local.indexOf('+');
  if (plus > 0) local = local.slice(0, plus);
  if (GMAIL_DOMAINS.has(domain)) {
    local = local.replaceAll('.', '');
    domain = 'gmail.com';
  }
  return `${local}@${domain}`;
}

/**
 * Charges the e-mail quotas, the recipient's first so that an inviter is not
 * charged for a message the recipient's cap would stop anyway.
 */
async function withinEmailLimits(ctx: RequestContext, inviterId: string, recipient: string) {
  const admin = ctx.supabase.supabaseAdmin;
  const rules: RateLimit[] = [
    {
      key: `invite_email:to:${await sha256Hex(canonicalMailbox(recipient))}`,
      ...EMAIL_LIMITS.perRecipient,
    },
    { key: `invite_email:user:${inviterId}`, ...EMAIL_LIMITS.perInviter },
  ];
  for (const rule of rules) {
    if (!await hitRateLimit(admin, rule)) return false;
  }
  return true;
}

/** The e-mail settings, or null when e-mail is off; a broken setup is logged and treated as failed delivery. */
function emailSettings(ctx: RequestContext): EmailConfig | null | 'misconfigured' {
  try {
    return ctx.config.email();
  } catch (error) {
    if (!(error instanceof ConfigError)) throw error;
    ctx.log.error('email_misconfigured', { variable: error.variable });
    return 'misconfigured';
  }
}

async function sendInvitationEmail(
  ctx: RequestContext,
  deps: InviteMemberDeps,
  invitation: Invitation,
  inviter: { id: string; email: string | null },
  portfolioId: string,
  inviteUrl: string,
  locale: Locale,
): Promise<EmailDelivery> {
  const email = emailSettings(ctx);
  if (email === null) return 'not_configured';
  if (email === 'misconfigured') return 'failed';

  try {
    // Look up and render before charging any quota: a failure here costs nothing.
    const client = ctx.supabase.supabase;
    const [portfolio, profile] = await Promise.all([
      client.from('portfolios').select('name').eq('id', portfolioId).maybeSingle(),
      client.from('profiles').select('full_name').eq('id', inviter.id).maybeSingle(),
    ]);
    const portfolioName = (portfolio.data as { name?: unknown } | null)?.name;
    if (portfolio.error !== null || typeof portfolioName !== 'string') {
      throw new Error('portfolio name unavailable');
    }
    const fullName = (profile.data as { full_name?: unknown } | null)?.full_name;
    const message = renderInvitationEmail({
      invitationId: invitation.invitation_id,
      recipient: invitation.email,
      role: invitation.role,
      expiresAt: new Date(invitation.expires_at),
      inviteUrl,
      portfolioName,
      inviterName: typeof fullName === 'string' ? fullName : '',
      inviterEmail: inviter.email,
      locale,
    });

    if (!await withinEmailLimits(ctx, inviter.id, invitation.email)) return 'rate_limited';
    await deps.createSender(email).send(message);
    return 'sent';
  } catch (error) {
    // The invitation exists and its link is returned; e-mail is best effort.
    ctx.log.warn('invitation_email_failed', {
      invitation_id: invitation.invitation_id,
      error,
    });
    return 'failed';
  }
}

async function inviteMember(ctx: RequestContext, deps: InviteMemberDeps): Promise<Response> {
  const inviter = requireUser(ctx);
  const body = await readJsonObject(ctx.req);
  rejectUnknownFields(body, ['portfolio_id', 'email', 'role', 'locale']);
  const portfolioId = requireUuid(body, 'portfolio_id');
  const email = requireEmail(body, 'email');
  const role = requireEnum(body, 'role', INVITE_ROLES);
  const locale = optionalEnum(body, 'locale', LOCALES, 'en');
  // Fail before creating an invitation that could not be linked to.
  const appUrl = ctx.config.appUrl();

  const { data, error, status } = await ctx.supabase.supabase.rpc('create_invitation', {
    p_portfolio_id: portfolioId,
    p_email: email,
    p_role: role,
  });
  if (error !== null) throw fromDatabaseFailure(error, status);
  const invitation = parseInvitation(data);
  const inviteUrl = buildInviteUrl(appUrl, invitation.token);

  const delivery = await sendInvitationEmail(
    ctx,
    deps,
    invitation,
    inviter,
    portfolioId,
    inviteUrl,
    locale,
  );
  ctx.log.info('invitation_created', {
    invitation_id: invitation.invitation_id,
    portfolio_id: portfolioId,
    role,
    delivery,
  });

  return json(
    {
      invitation_id: invitation.invitation_id,
      email: invitation.email,
      role: invitation.role,
      expires_at: invitation.expires_at,
      invite_url: inviteUrl,
      email_delivery: delivery,
    },
    201,
  );
}

export const defaultInviteDeps: InviteMemberDeps = {
  ...defaultDeps,
  createSender: (config) => createResendSender(config),
};

export function createInviteMemberHandler(
  deps: InviteMemberDeps = defaultInviteDeps,
): (req: Request) => Promise<Response> {
  return createHandler(
    { name: 'invite-member', auth: 'user', routes: { POST: (ctx) => inviteMember(ctx, deps) } },
    deps,
  );
}
