/**
 * Transactional e-mail through the Resend HTTP API (https://resend.com).
 *
 * Supabase Edge Functions cannot open SMTP ports 25/587, so e-mail goes out
 * over HTTPS. Every message carries an idempotency key, so a retried request
 * never sends a second copy.
 */

import type { EmailConfig } from './config.ts';
import { singleLine } from './text.ts';

export const RESEND_ENDPOINT = 'https://api.resend.com/emails';
const TIMEOUT_MS = 10_000;

export interface EmailMessage {
  readonly to: string;
  readonly subject: string;
  readonly html: string;
  readonly text: string;
  /** Stable per logical message, e.g. `invitation:<id>`; at most 256 characters. */
  readonly idempotencyKey: string;
  /** Resend tags (ASCII letters, digits, `_` and `-` only). */
  readonly tags?: Readonly<Record<string, string>>;
}

export interface EmailSender {
  send(message: EmailMessage): Promise<{ id: string }>;
}

/** Delivery failed; [status] is the provider's HTTP status (0 for network errors). */
export class EmailDeliveryError extends Error {
  constructor(readonly status: number, readonly reason: string) {
    super(`e-mail delivery failed (${status}): ${reason}`);
    this.name = 'EmailDeliveryError';
  }
}

const TAG = /^[A-Za-z0-9_-]{1,256}$/;

export function createResendSender(
  config: EmailConfig,
  fetchImpl: typeof fetch = fetch,
): EmailSender {
  return {
    async send(message) {
      const tags = Object.entries(message.tags ?? {}).map(([name, value]) => {
        if (!TAG.test(name) || !TAG.test(value)) {
          throw new EmailDeliveryError(0, `invalid tag ${name}`);
        }
        return { name, value };
      });

      let response: Response;
      try {
        response = await fetchImpl(RESEND_ENDPOINT, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${config.apiKey}`,
            'content-type': 'application/json',
            'idempotency-key': message.idempotencyKey,
          },
          body: JSON.stringify({
            from: config.from,
            to: [message.to],
            subject: singleLine(message.subject),
            html: message.html,
            text: message.text,
            ...(config.replyTo === null ? {} : { reply_to: config.replyTo }),
            ...(tags.length === 0 ? {} : { tags }),
          }),
          signal: AbortSignal.timeout(TIMEOUT_MS),
        });
      } catch (error) {
        const reason = error instanceof Error ? error.name : 'network_error';
        throw new EmailDeliveryError(0, reason);
      }

      const body = await response.json().catch(() => null) as
        | { id?: unknown; name?: unknown }
        | null;
      if (!response.ok) {
        // Resend reports `{ statusCode, name, message }`; keep the machine-readable name only.
        const reason = typeof body?.name === 'string' ? body.name : 'unknown_error';
        throw new EmailDeliveryError(response.status, reason);
      }
      if (typeof body?.id !== 'string') {
        throw new EmailDeliveryError(response.status, 'missing_message_id');
      }
      return { id: body.id };
    },
  };
}
