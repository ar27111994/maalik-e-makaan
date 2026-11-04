/**
 * The invitation e-mail, in English and Urdu.
 *
 * Both languages are always included because the invitee's preference is
 * unknown; the inviter's language comes first. Every interpolated value is
 * escaped, and the inviter's verified e-mail address is shown next to their
 * name so a recipient can tell who is really inviting them.
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

/** "Name (address)" from whichever parts exist; a neutral phrase when neither does. */
export function inviterLabel(name: string, email: string | null, locale: Locale): string {
  const shortName = truncate(singleLine(name), 60);
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

function formatExpiry(date: Date, locale: Locale): string {
  return new Intl.DateTimeFormat(locale === 'ur' ? 'ur-PK' : 'en-PK', {
    timeZone: 'Asia/Karachi',
    dateStyle: 'long',
    timeStyle: 'short',
  }).format(date);
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
  if (locale === 'ur') {
    return {
      heading: 'آپ کو دعوت دی گئی ہے',
      intro:
        `${inviter} نے آپ کو مالکِ مکان پر "${input.portfolioName}" میں بطور ${role} شامل ہونے کی دعوت دی ہے۔`,
      button: 'دعوت قبول کریں',
      validity:
        `یہ لنک صرف ایک بار، ${expiry} تک، اور صرف ${input.recipient} کے لیے کارآمد ہے۔ قبول کرنے کے لیے اسی ای میل سے سائن اِن کریں یا اکاؤنٹ بنائیں۔`,
      fallback: 'اگر بٹن کام نہ کرے تو یہ لنک کھولیں:',
      ignore: 'اگر آپ اس دعوت کی توقع نہیں کر رہے تھے تو اس ای میل کو نظر انداز کر دیں۔',
    };
  }
  return {
    heading: 'You have been invited',
    intro: `${inviter} invited you to join "${input.portfolioName}" on Maalik-e-Makaan as ${role}.`,
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
  const portfolioName = truncate(singleLine(input.portfolioName), 80);
  const safe = { ...input, portfolioName };
  const label = (locale: Locale) => inviterLabel(input.inviterName, input.inviterEmail, locale);
  const inviter = label(input.locale);
  const order: readonly Locale[] = input.locale === 'ur' ? ['ur', 'en'] : ['en', 'ur'];
  const sections = order.map((locale) => ({ locale, text: copy(locale, safe, label(locale)) }));

  const subject = input.locale === 'ur'
    ? `${inviter} کی طرف سے "${portfolioName}" میں شمولیت کی دعوت`
    : `${inviter} invited you to "${portfolioName}" on Maalik-e-Makaan`;

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
