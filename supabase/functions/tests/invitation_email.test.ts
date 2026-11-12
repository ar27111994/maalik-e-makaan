/**
 * The invitation e-mail (invite-member/email.ts): English and Urdu, the inviter's
 * language first; a constant subject; user-chosen names only as escaped, single-line,
 * bounded data, and left out altogether when they look like a link.
 */

import {
  assert,
  assertEquals,
  assertFalse,
  assertStrictEquals,
  assertStringIncludes,
} from '@std/assert';
import { assertSnapshot } from '@std/testing/snapshot';
import type { EmailMessage } from '../_shared/email.ts';
import { EMAIL_TYPOGRAPHY } from '../_shared/email_typography.g.ts';
import {
  displayName,
  expiryPieces,
  formatExpiry,
  type InvitationEmailInput,
  inviterLabel,
  type InviteRole,
  inviterPieces,
  type Locale,
  looksLikeLink,
  plainText,
  renderInvitationEmail,
  SUBJECTS,
} from '../invite-member/email.ts';

const LOCALES: readonly Locale[] = ['en', 'ur'];

const INPUT: InvitationEmailInput = {
  invitationId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0',
  recipient: 'imran@example.com',
  role: 'manager',
  // 12:00 UTC is 17:00 in Pakistan (UTC+5 all year).
  expiresAt: new Date(Date.UTC(2026, 10, 10, 12, 0, 0)),
  inviteUrl:
    'https://app.example.com/invite#token=0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0.q83vEjRWeJCrze-_AbCdEf',
  portfolioName: 'Raza Family Properties',
  inviterName: 'Ahmed Raza',
  inviterEmail: 'ahmed@example.com',
  locale: 'en',
};

/** How INPUT's inviter is introduced, in either language. */
const LABEL = 'Ahmed Raza (ahmed@example.com)';

/** Each role with its English and Urdu name. */
const ROLES: ReadonlyArray<readonly [InviteRole, string, string]> = [
  ['owner', 'co-owner', 'شریک مالک'],
  ['manager', 'manager (caretaker)', 'منیجر (نگران)'],
  ['accountant', 'accountant', 'اکاؤنٹنٹ'],
  ['viewer', 'viewer', 'صرف دیکھنے والا'],
];
const MANAGER_EN = 'manager (caretaker)';
const MANAGER_UR = 'منیجر (نگران)';

/**
 * "(پاکستانی وقت)" spelt out by code point, which also pins Urdu's own letters: keheh
 * (U+06A9) and Farsi yeh (U+06CC), not the Arabic kaf and yeh.
 */
const PAKISTAN_TIME_UR = `(${
  String.fromCodePoint(0x067e, 0x0627, 0x06a9, 0x0633, 0x062a, 0x0627, 0x0646, 0x06cc)
} ${String.fromCodePoint(0x0648, 0x0642, 0x062a)})`;

function enIntro(inviter: string, role: string, portfolio?: string): string {
  return portfolio === undefined
    ? `${inviter} invited you to join a portfolio on Maalik-e-Makaan as ${role}.`
    : `${inviter} invited you to join the portfolio named "${portfolio}" on Maalik-e-Makaan as ${role}.`;
}

function urIntro(inviter: string, role: string, portfolio?: string): string {
  return portfolio === undefined
    ? `${inviter} نے آپ کو مالکِ مکان ایپ پر ایک پورٹ فولیو میں شامل ہونے کی دعوت بھیجی ہے۔ آپ کا رول: ${role}۔`
    : `${inviter} نے آپ کو مالکِ مکان ایپ پر "${portfolio}" نام کے پورٹ فولیو میں شامل ہونے کی دعوت بھیجی ہے۔ آپ کا رول: ${role}۔`;
}

/** The text part of a rendering of INPUT, one language per section. */
const LINES: Readonly<Record<Locale, readonly string[]>> = {
  en: [
    'You have been invited',
    '',
    enIntro(LABEL, MANAGER_EN, INPUT.portfolioName),
    '',
    `Accept invitation: ${INPUT.inviteUrl}`,
    '',
    `This link works once, until ${
      formatExpiry(INPUT.expiresAt, 'en')
    }, and only for imran@example.com. Sign in or create an account with that address to accept.`,
    '',
    'If you were not expecting this invitation, you can ignore this e-mail.',
  ],
  ur: [
    'آپ کو دعوت دی گئی ہے',
    '',
    urIntro(LABEL, MANAGER_UR, INPUT.portfolioName),
    '',
    `دعوت قبول کریں: ${INPUT.inviteUrl}`,
    '',
    `یہ لنک صرف ایک بار، ${
      formatExpiry(INPUT.expiresAt, 'ur')
    } تک، اور صرف imran@example.com کے لیے کام کرے گا۔ قبول کرنے کے لیے اسی ای میل سے سائن اِن کریں یا اکاؤنٹ بنائیں۔`,
    '',
    'اگر آپ اس دعوت کی توقع نہیں کر رہے تھے تو اس ای میل کو نظر انداز کر دیں۔',
  ],
};

const SEPARATOR = '\n\n----------------------------------------\n\n';

/** The text part's two sections, in order, each as its lines. */
function sections(message: EmailMessage): [string[], string[]] {
  const parts = message.text.split(SEPARATOR).map((section) => section.split('\n'));
  assertEquals(parts.length, 2);
  return parts as [string[], string[]];
}

/** The intro sentence of each language in [message], rendered with [locale] first. */
function intros(message: EmailMessage, locale: Locale): Record<Locale, string | undefined> {
  const [first, second] = sections(message);
  return locale === 'en' ? { en: first[2], ur: second[2] } : { ur: first[2], en: second[2] };
}

function count(text: string, part: string): number {
  return text.split(part).length - 1;
}

// --- the whole message ---------------------------------------------------------------------

for (const locale of LOCALES) {
  Deno.test(`the ${locale}-first rendering matches its snapshot`, async (t) => {
    const message = renderInvitationEmail({ ...INPUT, locale });
    await assertSnapshot(t, { subject: message.subject, html: message.html, text: message.text });
  });
}

Deno.test('the subject is SUBJECTS[locale], whatever the names', () => {
  assertEquals(SUBJECTS, {
    en: "You're invited to a portfolio on Maalik-e-Makaan",
    ur: 'مالکِ مکان ایپ پر ایک پورٹ فولیو میں شامل ہونے کی دعوت',
  });
  const names = [
    'Raza Family Properties',
    'evil.com',
    '<script>alert(1)</script>',
    'Line one\nBcc: victim@example.com',
    'x'.repeat(500),
    '',
    'احمد رضا',
  ];
  for (const locale of LOCALES) {
    for (const name of names) {
      const message = renderInvitationEmail({
        ...INPUT,
        locale,
        portfolioName: name,
        inviterName: name,
      });
      assertStrictEquals(message.subject, SUBJECTS[locale], `${locale}: ${name}`);
    }
  }
});

Deno.test("both languages are always included, the inviter's first", () => {
  const dir: Record<Locale, string> = { en: 'dir="ltr"', ur: 'dir="rtl"' };
  const align: Record<Locale, string> = { en: 'text-align:left;', ur: 'text-align:right;' };
  for (const [locale, other] of [['en', 'ur'], ['ur', 'en']] as const) {
    const message = renderInvitationEmail({ ...INPUT, locale });
    assertStringIncludes(message.html, `<html lang="${locale}">`);
    const first = message.html.indexOf(`<div lang="${locale}" ${dir[locale]}`);
    const second = message.html.indexOf(`<div lang="${other}" ${dir[other]}`);
    assert(first > 0 && second > first, locale);
    assertStringIncludes(message.html.slice(first, second), align[locale]);
    assertStringIncludes(message.html.slice(second), align[other]);
    assertEquals(count(message.html, '<hr '), 1, locale);
    assertEquals(sections(message), [LINES[locale], LINES[other]], locale);
  }
});

/** The section of [html] in [locale], from its opening tag to its closing one. */
function section(html: string, locale: Locale): string {
  const start = html.indexOf(`<div lang="${locale}" `);
  assert(start >= 0, locale);
  return html.slice(start, html.indexOf('\n</div>', start) + '\n</div>'.length);
}

/** The style attribute of every element in [html] that sets a font-size. */
function sizedStyles(html: string): string[] {
  return [...html.matchAll(/style="([^"]*font-size:[^"]*)"/g)].map((match) => match[1] ?? '');
}

Deno.test('the Urdu half is set in the generated e-mail type, never Nastaliq (D-19); the English half keeps its own', () => {
  const urdu = EMAIL_TYPOGRAPHY.urdu;
  for (const locale of LOCALES) {
    const html = renderInvitationEmail({ ...INPUT, locale }).html;
    assertStringIncludes(
      html,
      `<div lang="ur" dir="rtl" style="font-family:${urdu.fontFamily};font-size:17px;line-height:${urdu.body.lineHeight};text-align:right;">\n` +
        `<h1 style="margin:0 0 12px;font-size:25px;line-height:${urdu.headline.lineHeight};color:#1F2328;">`,
    );
    assertStringIncludes(
      html,
      `<div lang="en" dir="ltr" style="font-family:'Atkinson Hyperlegible Next', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;line-height:1.55;text-align:left;">\n` +
        '<h1 style="margin:0 0 12px;font-size:22px;color:#1F2328;">',
    );
    // The two halves, the Urdu half's link, and the footer and its wordmark.
    assertEquals(count(html, 'font-family:'), 5, locale);
    // Nastaliq only for the brand name in the footer, where it stands as the wordmark.
    const wordmark =
      `<span lang="ur" dir="rtl" style="font-family:${EMAIL_TYPOGRAPHY.urduWordmark.fontFamily};">مالکِ مکان</span></p>`;
    assertStringIncludes(html, `>Maalik-e-Makaan · ${wordmark}`);
    assertEquals(count(html, EMAIL_TYPOGRAPHY.urduWordmark.fontFamily), 1, locale);
    assertFalse(/nastaliq|nastaleeq/i.test(html.replace(wordmark, '')), locale);
  }
});

Deno.test('each Urdu text is a size larger than its English, on a line of whole, even pixels', () => {
  const html = renderInvitationEmail(INPUT).html;
  // The section, heading, intro, button, validity, fallback, link and last line, in order.
  const sizes = (locale: Locale) =>
    sizedStyles(section(html, locale)).map((style) => /font-size:(\d+)px/.exec(style)?.[1]);
  assertEquals(sizes('en'), ['22', '16', '16', '14', '13', '13', '13']);
  assertEquals(sizes('ur'), ['17', '25', '17', '17', '15', '13', '13', '13']);
  for (const style of sizedStyles(section(html, 'ur'))) {
    const size = Number(/font-size:(\d+)px/.exec(style)?.[1]);
    const ratio = Number(/line-height:([\d.]+);/.exec(style)?.[1]);
    const line = size * ratio;
    // Never under the whole line, and within a layout unit (1/64 px) over it.
    assert(line >= Math.round(line) && line - Math.round(line) < 1 / 64, style);
    assertEquals(Math.round(line) % 2, 0, style);
  }
});

/** Elements that have no end tag. */
const VOID_ELEMENTS = new Set(['br', 'hr', 'img', 'meta', 'link', 'input']);

/** Each run of text in [html], with the attributes of the elements it is in, outermost first. */
function textRuns(html: string): Array<{ text: string; within: Array<Record<string, string>> }> {
  const runs: Array<{ text: string; within: Array<Record<string, string>> }> = [];
  const open: Array<{ tag: string; attributes: Record<string, string> }> = [];
  for (const match of html.matchAll(/<(\/?)([a-z][a-z0-9]*)([^>]*)>|<![^>]*>|([^<]+)/gi)) {
    const [, closing, tag, attributes = '', text] = match;
    if (text !== undefined) {
      runs.push({ text, within: open.map((element) => element.attributes) });
    } else if (tag !== undefined && closing === '/') {
      open.splice(open.findLastIndex((element) => element.tag === tag.toLowerCase()));
    } else if (tag !== undefined && !VOID_ELEMENTS.has(tag.toLowerCase())) {
      const pairs = [...attributes.matchAll(/([a-z-]+)="([^"]*)"/g)];
      open.push({
        tag: tag.toLowerCase(),
        attributes: Object.fromEntries(pairs.map((pair) => [pair[1], pair[2]])),
      });
    }
  }
  return runs;
}

/** The language of the innermost element with a lang attribute. */
function langOf(within: Array<Record<string, string>>): string | undefined {
  return within.findLast((attributes) => attributes.lang !== undefined)?.lang;
}

Deno.test('every Urdu letter of the e-mail is in an element marked lang="ur", the footer too', () => {
  for (const locale of LOCALES) {
    const runs = textRuns(renderInvitationEmail({ ...INPUT, locale }).html);
    const urdu = runs.filter((run) => /[؀-ۿ]/.test(run.text));
    // The heading, the intro and validity between their values, the button, the two notes and
    // the wordmark; with Urdu first, the title (the Urdu subject) too.
    assertEquals(urdu.length, locale === 'ur' ? 11 : 10, locale);
    for (const run of urdu) assertEquals(langOf(run.within), 'ur', run.text);
  }
});

Deno.test('in the Urdu half every Latin value is isolated, so it keeps its order in the sentence', () => {
  for (const locale of LOCALES) {
    const html = renderInvitationEmail({ ...INPUT, locale }).html;
    const urdu = section(html, 'ur');
    // The inviter's name and address, the quoted portfolio name, the time and the recipient.
    assertStringIncludes(
      urdu,
      '<span dir="auto">Ahmed Raza</span> (<span dir="ltr" style="word-break:break-word;">ahmed@example.com</span>) نے',
    );
    assertStringIncludes(
      urdu,
      ' پر <span dir="auto">&quot;Raza Family Properties&quot;</span> نام',
    );
    assertStringIncludes(urdu, ' کو <span dir="ltr">5:00 PM</span> (پاکستانی وقت) تک');
    assertStringIncludes(
      urdu,
      ' صرف <span dir="ltr" style="word-break:break-word;">imran@example.com</span> کے لیے',
    );
    for (const run of textRuns(urdu)) {
      if (!/[A-Za-z]/.test(run.text) || langOf(run.within) !== 'ur') continue;
      // Inside an element of its own direction, within the section (whose dir is rtl).
      assert(run.within.slice(1).some((attributes) => attributes.dir !== undefined), run.text);
    }
    // The English half sets no direction of its own, but lets an address break.
    const english = section(html, 'en');
    assertFalse(english.includes('<span dir='), locale);
    assertStringIncludes(
      english,
      ' only for <span style="word-break:break-word;">imran@example.com</span>. Sign in',
    );
  }
});

Deno.test("the Urdu half's link is English text: lang en, the English face, aligned left", () => {
  const urdu = section(renderInvitationEmail(INPUT).html, 'ur');
  assertStringIncludes(
    urdu,
    `<p dir="ltr" lang="en" style="margin:0 0 12px;font-family:'Atkinson Hyperlegible Next', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;font-size:13px;line-height:${EMAIL_TYPOGRAPHY.urdu.caption.lineHeight};text-align:left;word-break:break-all;"><a href="${INPUT.inviteUrl}"`,
  );
  const link = textRuns(urdu).filter((run) => run.text === INPUT.inviteUrl);
  assertEquals(link.map((run) => langOf(run.within)), ['en']);
});

Deno.test('a value is marked by its kind in the pieces, and the text part reads as before', () => {
  assertEquals(inviterPieces('Ahmed Raza', 'ahmed@example.com', 'ur'), [
    { kind: 'name', value: 'Ahmed Raza' },
    ' (',
    { kind: 'address', value: 'ahmed@example.com' },
    ')',
  ]);
  assertEquals(inviterPieces('', 'ahmed@example.com', 'en'), [
    { kind: 'address', value: 'ahmed@example.com' },
  ]);
  assertEquals(inviterPieces('', null, 'ur'), ['کسی']);
  for (const locale of LOCALES) {
    const pieces = expiryPieces(INPUT.expiresAt, locale);
    assertEquals(pieces.filter((piece) => typeof piece !== 'string'), [
      { kind: 'time', value: locale === 'ur' ? '5:00 PM' : '5:00 pm' },
    ]);
    assertEquals(plainText(pieces), formatExpiry(INPUT.expiresAt, locale));
  }
  // An Urdu name sets its own direction (auto), whatever the half.
  const urduName = renderInvitationEmail({
    ...INPUT,
    inviterName: 'احمد رضا',
    portfolioName: 'رضا خاندان',
  });
  assertStringIncludes(section(urduName.html, 'ur'), '<span dir="auto">احمد رضا</span> (');
  assertStringIncludes(
    section(urduName.html, 'ur'),
    '<span dir="auto">&quot;رضا خاندان&quot;</span>',
  );
  assertStringIncludes(section(urduName.html, 'en'), '>احمد رضا (<span style="word-break:');
});

Deno.test('the generated e-mail type starts with Noto Sans Arabic, ends sans-serif and keeps Nastaliq for the wordmark', () => {
  const urdu = EMAIL_TYPOGRAPHY.urdu.fontFamily.split(', ');
  assertEquals(urdu[0], "'Noto Sans Arabic'");
  assertEquals(urdu.at(-1), 'sans-serif');
  assertFalse(urdu.some((face) => /nastaliq|nastaleeq/i.test(face)));
  // Sans Urdu lines need far less than Nastaliq's twice the size.
  for (const role of [EMAIL_TYPOGRAPHY.urdu.body, EMAIL_TYPOGRAPHY.urdu.headline]) {
    assert(role.lineHeight >= 1.4 && role.lineHeight < 2);
  }
  assertEquals(EMAIL_TYPOGRAPHY.urduWordmark.fontFamily.split(', ')[0], "'Noto Nastaliq Urdu'");
});

Deno.test('the html title is the escaped subject', () => {
  assertStringIncludes(
    renderInvitationEmail(INPUT).html,
    '<title>You&#39;re invited to a portfolio on Maalik-e-Makaan</title>',
  );
  assertStringIncludes(
    renderInvitationEmail({ ...INPUT, locale: 'ur' }).html,
    `<title>${SUBJECTS.ur}</title>`,
  );
});

Deno.test('the message goes to the invitee only, keyed by the invitation and tagged with its role', () => {
  for (const [role, en, ur] of ROLES) {
    const message = renderInvitationEmail({ ...INPUT, role });
    assertEquals(Object.keys(message), ['to', 'subject', 'html', 'text', 'idempotencyKey', 'tags']);
    assertEquals(
      [message.to, message.idempotencyKey, message.tags],
      [
        'imran@example.com',
        'invitation:0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0',
        { category: 'invitation', role },
      ],
      role,
    );
    // The role is named in each language.
    assertEquals(intros(message, 'en'), {
      en: enIntro(LABEL, en, INPUT.portfolioName),
      ur: urIntro(LABEL, ur, INPUT.portfolioName),
    }, role);
  }
});

// --- names ---------------------------------------------------------------------------------

Deno.test('a link-like or blank portfolio name gives the generic intro, without the name, in both languages', () => {
  const names = [
    'evil.com',
    'Pay your rent at pay.ly',
    'www.raza-properties',
    'rent@raza.pk',
    'https://raza.example',
    '',
    '   \n  ',
  ];
  for (const portfolioName of names) {
    for (const locale of LOCALES) {
      const message = renderInvitationEmail({ ...INPUT, portfolioName, locale });
      const label = `${locale}: ${JSON.stringify(portfolioName)}`;
      assertEquals(intros(message, locale), {
        en: enIntro(LABEL, MANAGER_EN),
        ur: urIntro(LABEL, MANAGER_UR),
      }, label);
      if (portfolioName.trim() !== '') {
        assertFalse(message.html.includes(portfolioName), label);
        assertFalse(message.text.includes(portfolioName), label);
      }
    }
  }
});

Deno.test('a portfolio name is quoted on one line, cut at 80 graphemes', () => {
  const cases: Array<[string, string]> = [
    ['Raza Family Properties', 'Raza Family Properties'],
    ['Raza\nFamily \t Properties', 'Raza Family Properties'],
    ['P'.repeat(80), 'P'.repeat(80)],
    ['P'.repeat(81), `${'P'.repeat(79)}…`],
  ];
  for (const [portfolioName, shown] of cases) {
    const message = renderInvitationEmail({ ...INPUT, portfolioName });
    assertEquals(intros(message, 'en'), {
      en: enIntro(LABEL, MANAGER_EN, shown),
      ur: urIntro(LABEL, MANAGER_UR, shown),
    }, portfolioName);
  }
});

Deno.test('the inviter is introduced by name and verified address, or by a neutral phrase per language', () => {
  const cases: Array<[string, string, string | null, string, string]> = [
    ['name and address', 'Ahmed Raza', 'ahmed@example.com', LABEL, LABEL],
    ['address only', '', 'ahmed@example.com', 'ahmed@example.com', 'ahmed@example.com'],
    [
      'a link-like name',
      'pay.ly/raza',
      'ahmed@example.com',
      'ahmed@example.com',
      'ahmed@example.com',
    ],
    ['name only', 'احمد رضا', null, 'احمد رضا', 'احمد رضا'],
    ['neither', '', null, 'A Maalik-e-Makaan user', 'کسی'],
  ];
  for (const [label, inviterName, inviterEmail, en, ur] of cases) {
    const message = renderInvitationEmail({ ...INPUT, inviterName, inviterEmail });
    assertEquals(intros(message, 'en'), {
      en: enIntro(en, MANAGER_EN, INPUT.portfolioName),
      ur: urIntro(ur, MANAGER_UR, INPUT.portfolioName),
    }, label);
  }
});

Deno.test('every name and the link are HTML-escaped in the html part and verbatim in the text part', () => {
  const portfolioName = `<script>alert("pwned")</script> & 'Co'`;
  const inviterName = `O'Brien "The Boss" <b>`;
  const inviteUrl = `https://app.example.com/invite#token=a"b'c<d>&e`;
  const message = renderInvitationEmail({ ...INPUT, portfolioName, inviterName, inviteUrl });

  for (const raw of ['<script', '</script>', '<b>', '"pwned"', inviteUrl]) {
    assertFalse(message.html.includes(raw), raw);
  }
  const portfolio = '&lt;script&gt;alert(&quot;pwned&quot;)&lt;/script&gt; &amp; &#39;Co&#39;';
  const inviter = 'O&#39;Brien &quot;The Boss&quot; &lt;b&gt;';
  const url = 'https://app.example.com/invite#token=a&quot;b&#39;c&lt;d&gt;&amp;e';
  // Each language's intro, inside the quotes the template adds.
  assertEquals(count(message.html, `&quot;${portfolio}&quot;`), 2);
  assertStringIncludes(message.html, `>${inviter} (<span style="word-break:break-word;">`);
  assertStringIncludes(message.html, `<span dir="auto">${inviter}</span> (<span dir="ltr" `);
  // Each language's button and fallback link: the URL as attribute twice, as text once.
  assertEquals(count(message.html, `href="${url}"`), 4);
  assertEquals(count(message.html, `>${url}</a>`), 2);

  assertStringIncludes(message.text, `"${portfolioName}"`);
  assertStringIncludes(message.text, `${inviterName} (ahmed@example.com)`);
  assertStringIncludes(message.text, `Accept invitation: ${inviteUrl}`);
});

// --- the helpers ---------------------------------------------------------------------------

Deno.test('looksLikeLink flags URL schemes, www., e-mail addresses and domain names', () => {
  const cases: Array<[string, boolean]> = [
    // Each pattern on its own: a scheme, www., an address, a domain.
    ['ftp://files', true],
    ['WWW.', true],
    ['a@b', true],
    ['pay.ly', true],
    ['http://x.y', true],
    ['https://', true],
    ['www.evil', true],
    ['evil.com', true],
    ['EVIL.COM', true],
    ['a.Khan', true],
    ['Pay rent at evil.com/pay today', true],
    ['ahmed@example.com', true],
    ['Raza Family Properties', false],
    ['Gulberg III, Lahore', false],
    ['احمد رضا', false],
    ['A. Khan', false],
    ['Plot 12.5', false],
    ['Block A.B', false],
    ['Ahmed @ Raza', false],
    ['', false],
  ];
  for (const [text, expected] of cases) assertEquals(looksLikeLink(text), expected, text);
});

Deno.test('looksLikeLink sees through disguised domains', () => {
  const zwnj = '\u200c';
  const zwj = '\u200d';
  const lrm = '\u200e';
  const rlm = '\u200f';
  const disguised = [
    `evil${zwnj}.com`, // a joiner before the dot renders as evil.com
    `evil.${zwj}com`,
    `evil${lrm}.com`,
    `evil.${rlm}com`,
    'evil\uff0ecom', // full-width full stop
    'evil\u3002com', // ideographic full stop (IDNA maps it to a dot)
    'evil\uff61com', // half-width ideographic full stop
    '\uff45\uff56\uff49\uff4c.\uff43\uff4f\uff4d', // full-width letters
    '\u043f\u0440\u0438\u043c\u0435\u0440.\u0440\u0444', // an internationalised domain
    `w${zwnj}ww.example`,
    `https${zwj}://x`,
  ];
  for (const text of disguised) assertEquals(looksLikeLink(text), true, JSON.stringify(text));
  // Urdu with its own full stop, and names with joiners, stay names.
  for (
    const text of [
      '\u0627\u062d\u0645\u062f \u0631\u0636\u0627\u06d4',
      `\u0646\u06cc${zwnj}\u0645`,
      'Block A.B',
    ]
  ) {
    assertEquals(looksLikeLink(text), false, JSON.stringify(text));
  }
});

Deno.test('displayName keeps one line of at most max graphemes, or nothing when link-like', () => {
  const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
  const meemKasra = 'مِ';
  const cases: Array<[string, string, number, string]> = [
    ['a plain name', 'Raza Family Properties', 80, 'Raza Family Properties'],
    [
      'line breaks and runs of spaces',
      '  Raza\n\tFamily  Properties ',
      80,
      'Raza Family Properties',
    ],
    ['an Urdu name', 'رضا فیملی پراپرٹیز', 80, 'رضا فیملی پراپرٹیز'],
    ['a domain', 'evil.com', 80, ''],
    ['a link inside a name', 'Raza Properties (pay at www.raza-pay.pk)', 80, ''],
    ['an e-mail address', 'rent@raza.example', 60, ''],
    ['60 graphemes for 60', 'x'.repeat(60), 60, 'x'.repeat(60)],
    ['61 graphemes for 60', 'x'.repeat(61), 60, `${'x'.repeat(59)}…`],
    ['80 graphemes for 80', 'y'.repeat(80), 80, 'y'.repeat(80)],
    ['81 graphemes for 80', 'y'.repeat(81), 80, `${'y'.repeat(79)}…`],
    ['an emoji sequence is one grapheme', family.repeat(61), 60, `${family.repeat(59)}…`],
    ['an Urdu letter with its mark is one', meemKasra.repeat(81), 80, `${meemKasra.repeat(79)}…`],
    ['a link cut off by the limit', `${'x'.repeat(70)} evil.com`, 60, `${'x'.repeat(59)}…`],
    ['a link before the cut', `evil.com ${'x'.repeat(70)}`, 60, ''],
  ];
  for (const [label, name, max, shown] of cases) {
    assertEquals(displayName(name, max), shown, label);
  }
});

Deno.test('inviterLabel is "name (address)" from whichever parts exist, else a neutral phrase', () => {
  const long = `Ahmed\nRaza ${'x'.repeat(80)}`;
  const cut = `Ahmed Raza ${'x'.repeat(48)}…`;
  const cases: Array<[string, string | null, Locale, string]> = [
    ['Ahmed Raza', 'ahmed@example.com', 'en', LABEL],
    ['Ahmed Raza', null, 'en', 'Ahmed Raza'],
    ['Ahmed Raza', '', 'ur', 'Ahmed Raza'],
    ['', 'ahmed@example.com', 'en', 'ahmed@example.com'],
    ['  \n ', 'ahmed@example.com', 'ur', 'ahmed@example.com'],
    ['evil.com', 'ahmed@example.com', 'en', 'ahmed@example.com'],
    ['evil.com', null, 'en', 'A Maalik-e-Makaan user'],
    ['', null, 'en', 'A Maalik-e-Makaan user'],
    ['', '', 'en', 'A Maalik-e-Makaan user'],
    ['', null, 'ur', 'کسی'],
    ['', '', 'ur', 'کسی'],
    [long, null, 'en', cut],
    [long, 'ahmed@example.com', 'en', `${cut} (ahmed@example.com)`],
  ];
  for (const [name, email, locale, label] of cases) {
    assertEquals(inviterLabel(name, email, locale), label, `${locale}: ${name} / ${email}`);
  }
  assertEquals(Array.from(new Intl.Segmenter().segment(cut)).length, 60);
});

Deno.test('formatExpiry gives the date and time in Pakistan, saying so in each language', () => {
  // 20:30 UTC is 01:30 the next day in Pakistan.
  const late = new Date(Date.UTC(2026, 10, 10, 20, 30, 0));
  const en = formatExpiry(late, 'en');
  const ur = formatExpiry(late, 'ur');
  assert(en.endsWith(' (Pakistan time)'), en);
  assert(ur.endsWith(` ${PAKISTAN_TIME_UR}`), ur);
  const days: Array<[string, string]> = [[en, '11 November 2026'], [ur, '11 نومبر، 2026']];
  for (const [text, date] of days) {
    assertStringIncludes(text, date);
    assertStringIncludes(text, '1:30');
  }
  // 12:00 UTC is 17:00 in Pakistan, on the same day.
  assertStringIncludes(formatExpiry(INPUT.expiresAt, 'en'), '10 November 2026');
  assertStringIncludes(formatExpiry(INPUT.expiresAt, 'en'), '5:00');
});
