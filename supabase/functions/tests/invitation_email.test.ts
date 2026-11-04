import { assert, assertEquals, assertFalse, assertStringIncludes } from '@std/assert';
import {
  type InvitationEmailInput,
  inviterLabel,
  renderInvitationEmail,
} from '../invite-member/email.ts';

const INPUT: InvitationEmailInput = {
  invitationId: 'inv-1',
  recipient: 'imran@example.com',
  role: 'manager',
  // 2026-11-10 12:00 UTC is 17:00 in Pakistan.
  expiresAt: new Date(Date.UTC(2026, 10, 10, 12, 0, 0)),
  inviteUrl: 'https://app.example.com/invite#token=abc.def',
  portfolioName: 'Raza Family Properties',
  inviterName: 'Ahmed Raza',
  inviterEmail: 'ahmed@example.com',
  locale: 'en',
};

const URDU = /[؀-ۿ]/;

Deno.test('renders both languages, the inviter language first', () => {
  const english = renderInvitationEmail(INPUT);
  assert(english.html.indexOf('lang="en" dir="ltr"') < english.html.indexOf('lang="ur" dir="rtl"'));
  assertStringIncludes(english.html, '<html lang="en">');
  assertStringIncludes(english.html, 'Accept invitation');
  assertStringIncludes(english.html, 'دعوت قبول کریں');
  assertStringIncludes(english.html, 'manager (caretaker)');
  assertStringIncludes(english.html, 'منیجر (نگران)');

  const urdu = renderInvitationEmail({ ...INPUT, locale: 'ur' });
  assert(urdu.html.indexOf('lang="ur" dir="rtl"') < urdu.html.indexOf('lang="en" dir="ltr"'));
  assertStringIncludes(urdu.html, '<html lang="ur">');
  assert(URDU.test(urdu.subject));
  assertFalse(URDU.test(english.subject));
});

Deno.test('names the inviter with their verified e-mail address', () => {
  const message = renderInvitationEmail(INPUT);
  assertEquals(
    message.subject,
    'Ahmed Raza (ahmed@example.com) invited you to "Raza Family Properties" on Maalik-e-Makaan',
  );
  const nameless = renderInvitationEmail({ ...INPUT, inviterName: '' });
  assert(nameless.subject.startsWith('ahmed@example.com invited you'));
});

Deno.test('escapes every interpolated value in the HTML', () => {
  const message = renderInvitationEmail({
    ...INPUT,
    portfolioName: '<img src=x onerror=alert(1)> & "Co"',
    inviterName: '<b>Mallory</b>',
  });
  assertFalse(message.html.includes('<img src=x'));
  assertFalse(message.html.includes('<b>Mallory</b>'));
  assertStringIncludes(message.html, '&lt;img src=x onerror=alert(1)&gt; &amp; &quot;Co&quot;');
  assertStringIncludes(message.html, '&lt;b&gt;Mallory&lt;/b&gt;');
});

Deno.test('keeps subjects on one line and long names short', () => {
  const message = renderInvitationEmail({
    ...INPUT,
    portfolioName: `Line one\nBcc: victim@example.com ${'x'.repeat(200)}`,
  });
  assertFalse(/[\r\n]/.test(message.subject));
  assertStringIncludes(message.subject, 'Line one Bcc: victim@example.com');
  assertStringIncludes(message.subject, '…');
  assert(message.subject.length < 200);
});

Deno.test('states the expiry in Pakistan time and the single intended recipient', () => {
  const message = renderInvitationEmail(INPUT);
  assertStringIncludes(message.text, 'imran@example.com');
  // en-PK writes dates day first; 12:00 UTC is 17:00 in Pakistan (UTC+5, no DST).
  assertStringIncludes(message.text, '10 November 2026');
  assertStringIncludes(message.text, '5:00');
  assertStringIncludes(message.text, '10 نومبر، 2026');
});

Deno.test('includes the link in the text part and both links in the HTML part', () => {
  const message = renderInvitationEmail(INPUT);
  assertStringIncludes(message.text, `Accept invitation: ${INPUT.inviteUrl}`);
  assertEquals(message.html.split(`href="${INPUT.inviteUrl}"`).length - 1, 4);
});

Deno.test('carries delivery metadata', () => {
  const message = renderInvitationEmail({ ...INPUT, role: 'owner' });
  assertEquals(message.to, 'imran@example.com');
  assertEquals(message.idempotencyKey, 'invitation:inv-1');
  assertEquals(message.tags, { category: 'invitation', role: 'owner' });
  assertStringIncludes(message.html, 'co-owner');
  assertStringIncludes(message.html, 'شریک مالک');
});

Deno.test('inviterLabel uses whatever identity is known', () => {
  assertEquals(
    inviterLabel('Ahmed Raza', 'ahmed@example.com', 'en'),
    'Ahmed Raza (ahmed@example.com)',
  );
  assertEquals(inviterLabel('Ahmed Raza', null, 'en'), 'Ahmed Raza');
  assertEquals(inviterLabel('  ', 'ahmed@example.com', 'en'), 'ahmed@example.com');
  assertEquals(inviterLabel('', '', 'en'), 'A Maalik-e-Makaan user');
  assertEquals(inviterLabel('', null, 'ur'), 'مالکِ مکان کے ایک صارف');
  assertEquals(inviterLabel(`Ahmed\nRaza ${'x'.repeat(80)}`, null, 'en').length, 60);
});

Deno.test('an anonymous inviter is described in each language', () => {
  const message = renderInvitationEmail({ ...INPUT, inviterName: '', inviterEmail: null });
  assert(message.subject.startsWith('A Maalik-e-Makaan user invited you'));
  assertStringIncludes(message.html, 'مالکِ مکان کے ایک صارف نے آپ کو');
});
