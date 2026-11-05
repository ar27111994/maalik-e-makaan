/**
 * The invitation e-mail, in English and Urdu.
 *
 * Both languages are always included because the invitee's preference is
 * unknown; the inviter's language comes first. Every interpolated value is
 * escaped, and the inviter's verified e-mail address is shown next to their
 * name so a recipient can tell who is really inviting them.
 *
 * Names are chosen by users, so they never reach the subject (which inboxes
 * show before any context), they appear in the body only as quoted data,
 * and a name that looks like a link, domain or e-mail address is left out
 * altogether: the product's domain must not carry someone's phishing text.
 */

import type { EmailMessage } from '../_shared/email.ts';
import { escapeHtml, singleLine, truncate } from '../_shared/text.ts';

export type InviteRole = 'owner' | 'manager' | 'accountant' | 'viewer';
export type Locale = 'en' | 'ur';

export interface InvitationEmailInput {
  readonly invitationId: string;
  readonly recipient: string;
  readonly role: InviteRole;
  readonly expiresAt: Date;
  readonly inviteUrl: string;
  readonly portfolioName: string;
  readonly inviterName: string;
  /** The inviter's verified address; null when the account has none. */
  readonly inviterEmail: string | null;
  readonly locale: Locale;
}

const ROLE_NAMES: Readonly<Record<Locale, Readonly<Record<InviteRole, string>>>> = {
  en: {
    owner: 'co-owner',
    manager: 'manager (caretaker)',
    accountant: 'accountant',
    viewer: 'viewer',
  },
  ur: { owner: 'شریک مالک', manager: 'منیجر (نگران)', accountant: 'اکاؤنٹنٹ', viewer: 'ناظر' },
};

const UNNAMED_INVITER: Readonly<Record<Locale, string>> = {
  en: 'A Maalik-e-Makaan user',
  ur: 'مالکِ مکان کے ایک صارف',
};

export const SUBJECTS: Readonly<Record<Locale, string>> = {
  en: "You're invited to a portfolio on Maalik-e-Makaan",
  ur: 'مالکِ مکان پر ایک پورٹ فولیو میں شمولیت کی دعوت',
};

const LINK_LIKE = [
  /\p{L}[\p{L}\p{N}+.-]*:\/\//iu, // a URL scheme
  /(?<![\p{L}\p{N}])www\./iu,
  /[^\s@]@[^\s@]/u, // an e-mail address
  /[\p{L}\p{N}-]\.\p{L}{2,63}(?![\p{L}\p{N}-])/u, // a domain name, internationalised ones included
];

/** Dots that IDNA (UTS #46) treats as the label separator. */
const IDEOGRAPHIC_DOTS = /[\u3002\uFF61\uFE52]/g;
/** Invisible formatting characters (joiners, direction marks, soft hyphen). */
const FORMAT_CHARACTERS = /\p{Cf}/gu;

/**
 * Whether [text] contains something a mail client could present as a link.
 * Checked on a normalised copy, so a domain disguised with full-width
 * letters or dots, ideographic dots or invisible joiners and direction
 * marks is still recognised.
 */
export function looksLikeLink(text: string): boolean {
  const normalised = text.normalize('NFKC')
    .replace(FORMAT_CHARACTERS, '')
    .replace(IDEOGRAPHIC_DOTS, '.');
  return LINK_LIKE.some((pattern) => pattern.test(normalised));
}

/** A user-chosen name fit for the e-mail body: one line, bounded, never link-like. */
export function displayName(name: string, max: number): string {
  const clean = truncate(singleLine(name), max);
  return looksLikeLink(clean) ? '' : clean;
}

/** "Name (address)" from whichever parts exist; a neutral phrase when neither does. */
export function inviterLabel(name: string, email: string | null, locale: Locale): string {
  const shortName = displayName(name, 60);
  const address = email === null || email === '' ? null : email;
  if (shortName !== '' && address !== null) return `${shortName} (${address})`;
  return shortName !== '' ? shortName : address ?? UNNAMED_INVITER[locale];
}

const COLORS = {
  ink: '#1F2328',
  muted: '#57606A',
  primary: '#1D3F8F',
  onPrimary: '#FFFFFF',
  accent: '#A07A2C',
  page: '#F4F5F7',
  card: '#FFFFFF',
  rule: '#D8DCE1',
} as const;

/** The expiry in Pakistan time, saying so (recipients may be abroad). */
export function formatExpiry(date: Date, locale: Locale): string {
  const formatted = new Intl.DateTimeFormat(locale === 'ur' ? 'ur-PK' : 'en-PK', {
    timeZone: 'Asia/Karachi',
    dateStyle: 'long',
    timeStyle: 'short',
  }).format(date);
  return locale === 'ur' ? `${formatted} (پاکستانی وقت)` : `${formatted} (Pakistan time)`;
}

interface Copy {
  readonly heading: string;
  readonly intro: string;
  readonly button: string;
  readonly validity: string;
  readonly fallback: string;
  readonly ignore: string;
}

function copy(locale: Locale, input: InvitationEmailInput, inviter: string): Copy {
  const role = ROLE_NAMES[locale][input.role];
  const expiry = formatExpiry(input.expiresAt, locale);
  const named = input.portfolioName !== '';
  if (locale === 'ur') {
    return {
      heading: 'آپ کو دعوت دی گئی ہے',
      intro: named
        ? `${inviter} نے آپ کو مالکِ مکان پر "${input.portfolioName}" نامی پورٹ فولیو میں بطور ${role} شامل ہونے کی دعوت دی ہے۔`
        : `${inviter} نے آپ کو مالکِ مکان پر ایک پورٹ فولیو میں بطور ${role} شامل ہونے کی دعوت دی ہے۔`,
      button: 'دعوت قبول کریں',
      validity:
        `یہ لنک صرف ایک بار، ${expiry} تک، اور صرف ${input.recipient} کے لیے کارآمد ہے۔ قبول کرنے کے لیے اسی ای میل سے سائن اِن کریں یا اکاؤنٹ بنائیں۔`,
      fallback: 'اگر بٹن کام نہ کرے تو یہ لنک کھولیں:',
      ignore: 'اگر آپ اس دعوت کی توقع نہیں کر رہے تھے تو اس ای میل کو نظر انداز کر دیں۔',
    };
  }
  return {
    heading: 'You have been invited',
    intro: named
      ? `${inviter} invited you to join the portfolio named "${input.portfolioName}" on Maalik-e-Makaan as ${role}.`
      : `${inviter} invited you to join a portfolio on Maalik-e-Makaan as ${role}.`,
    button: 'Accept invitation',
    validity:
      `This link works once, until ${expiry}, and only for ${input.recipient}. Sign in or create an account with that address to accept.`,
    fallback: 'If the button does not work, open this link:',
    ignore: 'If you were not expecting this invitation, you can ignore this e-mail.',
  };
}

function htmlSection(locale: Locale, text: Copy, url: string): string {
  const dir = locale === 'ur' ? 'rtl' : 'ltr';
  const font = locale === 'ur'
    ? "'Noto Nastaliq Urdu', 'Jameel Noori Nastaleeq', 'Noto Naskh Arabic', serif"
    : "'Atkinson Hyperlegible Next', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
  const lineHeight = locale === 'ur' ? '2.1' : '1.55';
  const e = escapeHtml;
  return `<div lang="${locale}" dir="${dir}" style="font-family:${font};line-height:${lineHeight};text-align:${
    dir === 'rtl' ? 'right' : 'left'
  };">
<h1 style="margin:0 0 12px;font-size:22px;color:${COLORS.ink};">${e(text.heading)}</h1>
<p style="margin:0 0 20px;font-size:16px;color:${COLORS.ink};">${e(text.intro)}</p>
<p style="margin:0 0 20px;"><a href="${
    e(url)
  }" style="display:inline-block;padding:12px 22px;background:${COLORS.primary};color:${COLORS.onPrimary};text-decoration:none;border-radius:8px;font-size:16px;font-weight:600;">${
    e(text.button)
  }</a></p>
<p style="margin:0 0 12px;font-size:14px;color:${COLORS.muted};">${e(text.validity)}</p>
<p style="margin:0 0 4px;font-size:13px;color:${COLORS.muted};">${e(text.fallback)}</p>
<p dir="ltr" style="margin:0 0 12px;font-size:13px;word-break:break-all;"><a href="${
    e(url)
  }" style="color:${COLORS.primary};">${e(url)}</a></p>
<p style="margin:0;font-size:13px;color:${COLORS.muted};">${e(text.ignore)}</p>
</div>`;
}

/** Renders the invitation as a complete e-mail message. */
export function renderInvitationEmail(input: InvitationEmailInput): EmailMessage {
  const portfolioName = displayName(input.portfolioName, 80);
  const safe = { ...input, portfolioName };
  const label = (locale: Locale) => inviterLabel(input.inviterName, input.inviterEmail, locale);
  const order: readonly Locale[] = input.locale === 'ur' ? ['ur', 'en'] : ['en', 'ur'];
  const sections = order.map((locale) => ({ locale, text: copy(locale, safe, label(locale)) }));
  const subject = SUBJECTS[input.locale];

  const html = `<!doctype html>
<html lang="${input.locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${escapeHtml(singleLine(subject))}</title>
</head>
<body style="margin:0;padding:24px 12px;background:${COLORS.page};">
<div style="max-width:560px;margin:0 auto;background:${COLORS.card};border-radius:12px;border-top:4px solid ${COLORS.accent};padding:28px 24px;">
${
    sections.map(({ locale, text }) => htmlSection(locale, text, input.inviteUrl)).join(
      `\n<hr style="border:0;border-top:1px solid ${COLORS.rule};margin:24px 0;">\n`,
    )
  }
</div>
<p style="max-width:560px;margin:16px auto 0;font-family:Arial,sans-serif;font-size:12px;color:${COLORS.muted};text-align:center;">Maalik-e-Makaan · مالکِ مکان</p>
</body>
</html>
`;

  const text = sections
    .map(({ text: t }) =>
      [t.heading, '', t.intro, '', `${t.button}: ${input.inviteUrl}`, '', t.validity, '', t.ignore]
        .join('\n')
    )
    .join('\n\n----------------------------------------\n\n');

  return {
    to: input.recipient,
    subject,
    html,
    text,
    idempotencyKey: `invitation:${input.invitationId}`,
    tags: { category: 'invitation', role: input.role },
  };
}
