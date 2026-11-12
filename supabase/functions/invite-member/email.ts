/**
 * The invitation e-mail, in English and Urdu.
 *
 * Both languages are always included because the invitee's preference is
 * unknown; the inviter's language comes first. Every interpolated value is
 * escaped, and in the Urdu half isolated, so that it keeps its own direction in
 * the sentence. The inviter's verified e-mail address is shown next to their
 * name so a recipient can tell who is really inviting them.
 *
 * Names are chosen by users, so they never reach the subject (which inboxes
 * show before any context), they appear in the body only as quoted data,
 * and a name that looks like a link, domain or e-mail address is left out
 * altogether: the product's domain must not carry someone's phishing text.
 */

import type { EmailMessage } from '../_shared/email.ts';
import { EMAIL_TYPOGRAPHY } from '../_shared/email_typography.g.ts';
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
  ur: {
    owner: 'شریک مالک',
    manager: 'منیجر (نگران)',
    accountant: 'اکاؤنٹنٹ',
    viewer: 'صرف دیکھنے والا',
  },
};

/**
 * Who invited, when neither a name nor an address can be shown. The Urdu is the
 * oblique "someone", because the Urdu intro reads "{inviter} نے": the sentence
 * then says that someone on the Maalik-e-Makaan app sent the invitation.
 */
const UNNAMED_INVITER: Readonly<Record<Locale, string>> = {
  en: 'A Maalik-e-Makaan user',
  ur: 'کسی',
};

export const SUBJECTS: Readonly<Record<Locale, string>> = {
  en: "You're invited to a portfolio on Maalik-e-Makaan",
  ur: 'مالکِ مکان ایپ پر ایک پورٹ فولیو میں شامل ہونے کی دعوت',
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

/** What a value from outside the copy is, which decides how the HTML sets it apart. */
type ValueKind = 'name' | 'address' | 'time';

/** A piece of copy: its own text, or a value from outside it. */
export type Piece = string | { readonly kind: ValueKind; readonly value: string };

/** [pieces] as plain text, for the text part. */
export function plainText(pieces: readonly Piece[]): string {
  return pieces.map((piece) => typeof piece === 'string' ? piece : piece.value).join('');
}

/** "Name (address)" from whichever parts exist; a neutral phrase when neither does. */
export function inviterPieces(name: string, email: string | null, locale: Locale): Piece[] {
  const shortName = displayName(name, 60);
  const who: Piece | null = shortName === '' ? null : { kind: 'name', value: shortName };
  const at: Piece | null = email === null || email === ''
    ? null
    : { kind: 'address', value: email };
  if (who !== null && at !== null) return [who, ' (', at, ')'];
  return [who ?? at ?? UNNAMED_INVITER[locale]];
}

/** The inviter as plain text: "Name (address)", either part alone, or a neutral phrase. */
export function inviterLabel(name: string, email: string | null, locale: Locale): string {
  return plainText(inviterPieces(name, email, locale));
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

/** The parts of a formatted date that make up its time of day. */
const TIME_PARTS: ReadonlySet<string> = new Set(['hour', 'minute', 'dayPeriod']);

/**
 * The expiry in Pakistan time, saying so (recipients may be abroad), with the time of day
 * ("5:00 PM") as a value of its own: in an Urdu sentence it must keep its left-to-right order.
 */
export function expiryPieces(date: Date, locale: Locale): Piece[] {
  const parts = new Intl.DateTimeFormat(locale === 'ur' ? 'ur-PK' : 'en-PK', {
    timeZone: 'Asia/Karachi',
    dateStyle: 'long',
    timeStyle: 'short',
  }).formatToParts(date);
  const first = parts.findIndex((part) => TIME_PARTS.has(part.type));
  const last = parts.findLastIndex((part) => TIME_PARTS.has(part.type)) + 1;
  const text = (from: number, to: number) =>
    parts.slice(from, to).map((part) => part.value).join('');
  const zone = locale === 'ur' ? ' (پاکستانی وقت)' : ' (Pakistan time)';
  return [
    text(0, first),
    { kind: 'time', value: text(first, last) },
    text(last, parts.length) + zone,
  ];
}

/** The expiry in Pakistan time as plain text. */
export function formatExpiry(date: Date, locale: Locale): string {
  return plainText(expiryPieces(date, locale));
}

interface Copy {
  readonly heading: string;
  readonly intro: readonly Piece[];
  readonly button: string;
  readonly validity: readonly Piece[];
  readonly fallback: string;
  readonly ignore: string;
}

function copy(locale: Locale, input: InvitationEmailInput, inviter: readonly Piece[]): Copy {
  const role = ROLE_NAMES[locale][input.role];
  const expiry = expiryPieces(input.expiresAt, locale);
  const recipient: Piece = { kind: 'address', value: input.recipient };
  // The quotes go with the name, so that they stay round it when the name wraps.
  const portfolio: Piece | null = input.portfolioName === ''
    ? null
    : { kind: 'name', value: `"${input.portfolioName}"` };
  if (locale === 'ur') {
    return {
      heading: 'آپ کو دعوت دی گئی ہے',
      intro: portfolio === null
        ? [
          ...inviter,
          ` نے آپ کو مالکِ مکان ایپ پر ایک پورٹ فولیو میں شامل ہونے کی دعوت بھیجی ہے۔ آپ کا رول: ${role}۔`,
        ]
        : [
          ...inviter,
          ' نے آپ کو مالکِ مکان ایپ پر ',
          portfolio,
          ` نام کے پورٹ فولیو میں شامل ہونے کی دعوت بھیجی ہے۔ آپ کا رول: ${role}۔`,
        ],
      button: 'دعوت قبول کریں',
      validity: [
        'یہ لنک صرف ایک بار، ',
        ...expiry,
        ' تک، اور صرف ',
        recipient,
        ' کے لیے کام کرے گا۔ قبول کرنے کے لیے اسی ای میل سے سائن اِن کریں یا اکاؤنٹ بنائیں۔',
      ],
      fallback: 'اگر بٹن کام نہ کرے تو یہ لنک کھولیں:',
      ignore: 'اگر آپ اس دعوت کی توقع نہیں کر رہے تھے تو اس ای میل کو نظر انداز کر دیں۔',
    };
  }
  return {
    heading: 'You have been invited',
    intro: portfolio === null
      ? [...inviter, ` invited you to join a portfolio on Maalik-e-Makaan as ${role}.`]
      : [
        ...inviter,
        ' invited you to join the portfolio named ',
        portfolio,
        ` on Maalik-e-Makaan as ${role}.`,
      ],
    button: 'Accept invitation',
    validity: [
      'This link works once, until ',
      ...expiry,
      ', and only for ',
      recipient,
      '. Sign in or create an account with that address to accept.',
    ],
    fallback: 'If the button does not work, open this link:',
    ignore: 'If you were not expecting this invitation, you can ignore this e-mail.',
  };
}

/**
 * How each kind of value is set apart in the Urdu half's HTML. Each is isolated (an element
 * with dir), so that a Latin value keeps its own order in the Urdu sentence: "5:00 PM" does not
 * become "PM 5:00", and the brackets round an address stay the right way round. A name may be
 * in either script, so its direction is its own (auto).
 */
const URDU_ISOLATE: Readonly<Record<ValueKind, string>> = {
  name: ' dir="auto"',
  address: ' dir="ltr"',
  time: ' dir="ltr"',
};

/**
 * [pieces] as HTML, escaped. An address breaks anywhere, so that a long one cannot widen the
 * e-mail past a phone's screen; in Urdu, every value is isolated (URDU_ISOLATE).
 */
function htmlPieces(pieces: readonly Piece[], locale: Locale): string {
  return pieces.map((piece) => {
    if (typeof piece === 'string') return escapeHtml(piece);
    const dir = locale === 'ur' ? URDU_ISOLATE[piece.kind] : '';
    const style = piece.kind === 'address' ? ' style="word-break:break-word;"' : '';
    const value = escapeHtml(piece.value);
    return dir === '' && style === '' ? value : `<span${dir}${style}>${value}</span>`;
  }).join('');
}

/** The English half's face, as the English e-mail has always set it. */
const ENGLISH_FONT =
  "'Atkinson Hyperlegible Next', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

/** The Urdu type generated from the design tokens. */
const URDU = EMAIL_TYPOGRAPHY.urdu;

/** An Urdu type role as a style: its size, and its line height (a whole number of pixels). */
function urduRole(role: { readonly fontSize: number; readonly lineHeight: number }): string {
  return `font-size:${role.fontSize}px;line-height:${role.lineHeight};`;
}

/** The type of one language's half: its own, and that of each kind of text in it. */
interface SectionType {
  /** The face, and the size and line height that what sets neither inherits. */
  readonly section: string;
  readonly heading: string;
  readonly body: string;
  readonly small: string;
  readonly caption: string;
  /** The fallback link's attributes and type: Latin text, whichever half it is in. */
  readonly link: { readonly attributes: string; readonly style: string };
}

/**
 * Each language's type. Urdu is generated from the design tokens (D-19): Noto Sans Arabic and
 * installed sans faces, a size larger than the English in each role (its letters are small for
 * their size), on lines of whole pixels.
 */
const TYPE: Readonly<Record<Locale, SectionType>> = {
  en: {
    section: `font-family:${ENGLISH_FONT};line-height:1.55;`,
    heading: 'font-size:22px;',
    body: 'font-size:16px;',
    small: 'font-size:14px;',
    caption: 'font-size:13px;',
    link: { attributes: '', style: 'font-size:13px;' },
  },
  ur: {
    section: `font-family:${URDU.fontFamily};${urduRole(URDU.body)}`,
    heading: urduRole(URDU.headline),
    body: urduRole(URDU.body),
    small: urduRole(URDU.bodySmall),
    caption: urduRole(URDU.caption),
    // In the English face, aligned left, at the size and on the line of the Urdu around it.
    link: {
      attributes: ' lang="en"',
      style: `font-family:${ENGLISH_FONT};${urduRole(URDU.caption)}text-align:left;`,
    },
  },
};

function htmlSection(locale: Locale, text: Copy, url: string): string {
  const dir = locale === 'ur' ? 'rtl' : 'ltr';
  const type = TYPE[locale];
  const e = escapeHtml;
  return `<div lang="${locale}" dir="${dir}" style="${type.section}text-align:${
    dir === 'rtl' ? 'right' : 'left'
  };">
<h1 style="margin:0 0 12px;${type.heading}color:${COLORS.ink};">${e(text.heading)}</h1>
<p style="margin:0 0 20px;${type.body}color:${COLORS.ink};">${htmlPieces(text.intro, locale)}</p>
<p style="margin:0 0 20px;"><a href="${
    e(url)
  }" style="display:inline-block;padding:12px 22px;background:${COLORS.primary};color:${COLORS.onPrimary};text-decoration:none;border-radius:8px;${type.body}font-weight:600;">${
    e(text.button)
  }</a></p>
<p style="margin:0 0 12px;${type.small}color:${COLORS.muted};">${
    htmlPieces(text.validity, locale)
  }</p>
<p style="margin:0 0 4px;${type.caption}color:${COLORS.muted};">${e(text.fallback)}</p>
<p dir="ltr"${type.link.attributes} style="margin:0 0 12px;${type.link.style}word-break:break-all;"><a href="${
    e(url)
  }" style="color:${COLORS.primary};">${e(url)}</a></p>
<p style="margin:0;${type.caption}color:${COLORS.muted};">${e(text.ignore)}</p>
</div>`;
}

/** Renders the invitation as a complete e-mail message. */
export function renderInvitationEmail(input: InvitationEmailInput): EmailMessage {
  const portfolioName = displayName(input.portfolioName, 80);
  const safe = { ...input, portfolioName };
  const inviter = (locale: Locale) => inviterPieces(input.inviterName, input.inviterEmail, locale);
  const order: readonly Locale[] = input.locale === 'ur' ? ['ur', 'en'] : ['en', 'ur'];
  const sections = order.map((locale) => ({ locale, text: copy(locale, safe, inviter(locale)) }));
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
<p style="max-width:560px;margin:16px auto 0;font-family:Arial,sans-serif;font-size:12px;color:${COLORS.muted};text-align:center;">Maalik-e-Makaan · <span lang="ur" dir="rtl" style="font-family:${EMAIL_TYPOGRAPHY.urduWordmark.fontFamily};">مالکِ مکان</span></p>
</body>
</html>
`;

  const text = sections
    .map(({ text: t }) =>
      [
        t.heading,
        '',
        plainText(t.intro),
        '',
        `${t.button}: ${input.inviteUrl}`,
        '',
        plainText(t.validity),
        '',
        t.ignore,
      ].join('\n')
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
