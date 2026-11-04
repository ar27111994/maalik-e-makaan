import { assertEquals, assertThrows } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  optionalBoolean,
  optionalEnum,
  rejectUnknownFields,
  requireEmail,
  requireEnum,
  requireUuid,
} from '../_shared/validation.ts';

function rejects(fn: () => unknown, field: string, reason: string): void {
  const error = assertThrows(fn, HttpError);
  assertEquals([error.status, error.code], [422, 'validation_failed']);
  assertEquals(error.details, { field, reason });
}

const RLO = String.fromCodePoint(0x202e); // right-to-left override

Deno.test('rejectUnknownFields reports the first unknown field alphabetically', () => {
  rejectUnknownFields({ a: 1, b: 2 }, ['a', 'b', 'c']);
  rejects(() => rejectUnknownFields({ a: 1, zeta: 1, beta: 2 }, ['a']), 'beta', 'unknown_field');
});

Deno.test('requireUuid accepts any RFC 9562 version and lower-cases it', () => {
  assertEquals(
    requireUuid({ id: ' 0192D0C4-7A5E-7C1E-9A4B-2F6D1E3C8A91 ' }, 'id'),
    '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
  );
  assertEquals(
    requireUuid({ id: '9b2f3c1e-1d2e-4f5a-8b6c-7d8e9f0a1b2c' }, 'id'),
    '9b2f3c1e-1d2e-4f5a-8b6c-7d8e9f0a1b2c',
  );
});

Deno.test('requireUuid rejects missing, non-string and malformed values', () => {
  rejects(() => requireUuid({}, 'id'), 'id', 'required');
  rejects(() => requireUuid({ id: null }, 'id'), 'id', 'required');
  rejects(() => requireUuid({ id: 42 }, 'id'), 'id', 'not_a_string');
  rejects(() => requireUuid({ id: 'not-a-uuid' }, 'id'), 'id', 'not_a_uuid');
  // Version nibble 0 and variant nibble c are not valid RFC 9562 UUIDs.
  rejects(
    () => requireUuid({ id: '0192d0c4-7a5e-0c1e-9a4b-2f6d1e3c8a91' }, 'id'),
    'id',
    'not_a_uuid',
  );
  rejects(
    () => requireUuid({ id: '0192d0c4-7a5e-7c1e-ca4b-2f6d1e3c8a91' }, 'id'),
    'id',
    'not_a_uuid',
  );
});

Deno.test('requireEmail trims and lower-cases valid addresses', () => {
  assertEquals(requireEmail({ email: '  Imran@Example.COM ' }, 'email'), 'imran@example.com');
});

Deno.test('requireEmail rejects malformed, overlong and spoofed addresses', () => {
  rejects(() => requireEmail({ email: 'imran' }, 'email'), 'email', 'not_an_email');
  rejects(() => requireEmail({ email: 'a@b' }, 'email'), 'email', 'not_an_email');
  rejects(() => requireEmail({ email: 'a b@example.com' }, 'email'), 'email', 'not_an_email');
  rejects(
    () => requireEmail({ email: `${'x'.repeat(250)}@example.com` }, 'email'),
    'email',
    'not_an_email',
  );
  rejects(
    () => requireEmail({ email: `moc.elpmaxe${RLO}@evil.com` }, 'email'),
    'email',
    'forbidden_characters',
  );
});

Deno.test('requireEnum accepts listed values only', () => {
  const roles = ['owner', 'viewer'] as const;
  assertEquals(requireEnum({ role: ' viewer ' }, 'role', roles), 'viewer');
  rejects(() => requireEnum({ role: 'admin' }, 'role', roles), 'role', 'not_allowed');
  rejects(() => requireEnum({ role: 'Owner' }, 'role', roles), 'role', 'not_allowed');
});

Deno.test('optionalEnum falls back when the field is absent or null', () => {
  const locales = ['en', 'ur'] as const;
  assertEquals(optionalEnum({}, 'locale', locales, 'en'), 'en');
  assertEquals(optionalEnum({ locale: null }, 'locale', locales, 'en'), 'en');
  assertEquals(optionalEnum({ locale: 'ur' }, 'locale', locales, 'en'), 'ur');
  rejects(() => optionalEnum({ locale: 'fr' }, 'locale', locales, 'en'), 'locale', 'not_allowed');
});

Deno.test('optionalBoolean falls back when absent and rejects non-booleans', () => {
  assertEquals(optionalBoolean({}, 'flag', true), true);
  assertEquals(optionalBoolean({ flag: null }, 'flag', false), false);
  assertEquals(optionalBoolean({ flag: false }, 'flag', true), false);
  rejects(() => optionalBoolean({ flag: 'yes' }, 'flag', true), 'flag', 'not_a_boolean');
});
