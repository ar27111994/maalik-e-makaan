import { assertEquals, assertThrows } from '@std/assert';
import { HttpError } from '../_shared/errors.ts';
import {
  type JsonObject,
  optionalBoolean,
  optionalEnum,
  rejectUnknownFields,
  requireEmail,
  requireEnum,
  requireText,
  requireUuid,
} from '../_shared/validation.ts';
import { USER_ID } from './_helpers.ts';

/** Asserts that [fn] throws the 422 naming [field] with [reason]. */
function assertInvalid(fn: () => unknown, field: string, reason: string, label?: string): void {
  const error = assertThrows(fn, HttpError, undefined, label);
  assertEquals(
    {
      status: error.status,
      code: error.code,
      message: error.message,
      details: error.details,
      headers: error.headers,
    },
    {
      status: 422,
      code: 'validation_failed',
      message: `Invalid value for "${field}".`,
      details: { field, reason },
      headers: {},
    },
    label,
  );
}

const char = (...codePoints: number[]) => String.fromCodePoint(...codePoints);
const NUL = char(0x0000);
const RLO = char(0x202e); // right-to-left override
const ZWSP = char(0x200b); // zero-width space
const BOM = char(0xfeff); // byte-order mark (String.prototype.trim would strip it)
const NBSP = char(0x00a0);
const HOUSE = char(0x1f3e0); // one code point, two UTF-16 code units
// Man, woman, girl, boy joined by zero-width joiners: one grapheme, seven code points.
const FAMILY = char(0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467, 0x200d, 0x1f466);

const ROLES = ['owner', 'viewer'] as const;

interface StringValidator {
  readonly name: string;
  readonly validate: (body: JsonObject) => unknown;
  /** A value the validator accepts. */
  readonly valid: string;
}

const STRING_VALIDATORS: readonly StringValidator[] = [
  { name: 'requireUuid', validate: (body) => requireUuid(body, 'value'), valid: USER_ID },
  {
    name: 'requireEmail',
    validate: (body) => requireEmail(body, 'value'),
    valid: 'owner@example.com',
  },
  {
    name: 'requireText',
    validate: (body) => requireText(body, 'value', 320),
    valid: 'owner@example.com',
  },
  { name: 'requireEnum', validate: (body) => requireEnum(body, 'value', ROLES), valid: 'owner' },
  {
    name: 'optionalEnum',
    validate: (body) => optionalEnum(body, 'value', ROLES, 'viewer'),
    valid: 'owner',
  },
];

// --- Shared rules ------------------------------------------------------------

Deno.test('every string validator rejects a non-string value as not_a_string', () => {
  for (const { name, validate } of STRING_VALIDATORS) {
    for (const value of [42, 0, true, false, [], ['owner'], {}, { value: 'owner' }]) {
      assertInvalid(() => validate({ value }), 'value', 'not_a_string', name);
    }
  }
});

Deno.test('every string validator rejects forbidden characters, even ones trim() drops', () => {
  const forbidden = [
    0x0000, // null
    0x0008, // backspace
    0x000b, // vertical tab, which trim() would drop
    0x000c, // form feed, which trim() would drop
    0x007f, // delete
    0x0085, // next line (C1)
    0x00ad, // soft hyphen
    0x200b, // zero-width space
    0x202e, // right-to-left override
    0xfeff, // byte-order mark, which trim() would drop
  ];
  for (const { name, validate, valid } of STRING_VALIDATORS) {
    for (const codePoint of forbidden) {
      for (const value of [`${char(codePoint)}${valid}`, `${valid}${char(codePoint)}`]) {
        assertInvalid(() => validate({ value }), 'value', 'forbidden_characters', name);
      }
    }
    validate({ value: valid }); // the clean value itself passes
  }
});

Deno.test('every required validator reports a missing or null field as required', () => {
  const required = STRING_VALIDATORS.filter(({ name }) => name !== 'optionalEnum');
  for (const { name, validate } of required) {
    for (const body of [{}, { value: null }, { other: 'owner' }, { value: undefined }]) {
      assertInvalid(() => validate(body), 'value', 'required', name);
    }
  }
});

// --- rejectUnknownFields -------------------------------------------------------

Deno.test('rejectUnknownFields accepts a body within the allowed fields', () => {
  assertEquals(rejectUnknownFields({}, ['a']), undefined);
  assertEquals(rejectUnknownFields({ a: 1, b: null }, ['a', 'b', 'c']), undefined);
});

Deno.test('rejectUnknownFields names the first unknown field in sorted order', () => {
  const cases: ReadonlyArray<readonly [JsonObject, readonly string[], string]> = [
    [{ zeta: 1, beta: 2, a: 3 }, ['a'], 'beta'],
    [
      { portfolio_id: USER_ID, role: 'owner', Email: 'x' },
      ['portfolio_id', 'email', 'role'],
      'Email',
    ],
    // Code-unit order: upper case sorts before lower case.
    [{ b: 1, B: 1, a: 1 }, ['a'], 'B'],
    [{ constructor: 1 }, [], 'constructor'],
    // JSON.parse makes "__proto__" an own key; it must not be smuggled through.
    [JSON.parse('{"a": 1, "__proto__": {"admin": true}}'), ['a'], '__proto__'],
  ];
  for (const [body, allowed, field] of cases) {
    assertInvalid(() => rejectUnknownFields(body, allowed), field, 'unknown_field');
  }
});

// --- requireUuid -------------------------------------------------------------

Deno.test('requireUuid accepts any 8-4-4-4-12 hex value, trimmed and lower-cased', () => {
  const cases: ReadonlyArray<readonly [string, string]> = [
    [USER_ID, USER_ID],
    ['00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000'],
    ['ffffffff-ffff-ffff-ffff-ffffffffffff', 'ffffffff-ffff-ffff-ffff-ffffffffffff'],
    // Version 0 and version 9 with variant c: the database's uuid type takes any.
    ['0192d0c4-7a5e-0c1e-9a4b-2f6d1e3c8a91', '0192d0c4-7a5e-0c1e-9a4b-2f6d1e3c8a91'],
    ['0192d0c4-7a5e-9c1e-ca4b-2f6d1e3c8a91', '0192d0c4-7a5e-9c1e-ca4b-2f6d1e3c8a91'],
    [' 0192D0C4-7A5E-7C1E-9A4B-2F6D1E3C8A91 ', USER_ID],
    [`\t${USER_ID}\r\n`, USER_ID],
    [`${NBSP}${USER_ID}`, USER_ID],
  ];
  for (const [value, uuid] of cases) {
    assertEquals(requireUuid({ id: value }, 'id'), uuid, JSON.stringify(value));
  }
});

Deno.test('requireUuid rejects every other shape as not_a_uuid', () => {
  const cases = [
    '',
    '   ',
    'not-a-uuid',
    '0192d0c47a5e7c1e9a4b2f6d1e3c8a91',
    `{${USER_ID}}`,
    `urn:uuid:${USER_ID}`,
    '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a9',
    '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a911',
    '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a9g',
    '0192d0c4-7a5e7-c1e-9a4b-2f6d1e3c8a91',
    '0192d0c4 7a5e 7c1e 9a4b 2f6d1e3c8a91',
    `${USER_ID}\n${USER_ID}`,
    // Full-width digits look like hex but are not.
    `${char(0xff10)}192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91`,
  ];
  for (const value of cases) {
    assertInvalid(() => requireUuid({ id: value }, 'id'), 'id', 'not_a_uuid');
  }
});

// --- requireEmail --------------------------------------------------------------

/** An address of exactly [length] characters. */
const addressOfLength = (length: number) =>
  `${'a'.repeat(length - '@example.com'.length)}@example.com`;

Deno.test('requireEmail trims and lower-cases an address of up to 254 characters', () => {
  assertEquals(addressOfLength(254).length, 254);
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['  Imran@Example.COM ', 'imran@example.com'],
    ['a@b.co', 'a@b.co'],
    ['first.last+rent@mail.example.pk', 'first.last+rent@mail.example.pk'],
    [`a@example.${'a'.repeat(63)}`, `a@example.${'a'.repeat(63)}`],
    [addressOfLength(254), addressOfLength(254)],
    [`  ${addressOfLength(254).toUpperCase()}  `, addressOfLength(254)],
  ];
  for (const [value, email] of cases) {
    assertEquals(requireEmail({ email: value }, 'email'), email, value);
  }
});

Deno.test('requireEmail rejects malformed and overlong addresses as not_an_email', () => {
  const cases = [
    '',
    '   ',
    'imran',
    'imran@',
    '@example.com',
    'a@b',
    'a@b.c',
    'a@b.c0m',
    `a@example.${'a'.repeat(64)}`,
    'a b@example.com',
    'a@b@example.com',
    'Imran <imran@example.com>',
    addressOfLength(255),
  ];
  for (const value of cases) {
    assertInvalid(() => requireEmail({ email: value }, 'email'), 'email', 'not_an_email');
  }
});

Deno.test('requireEmail rejects a bidi-spoofed address as forbidden_characters', () => {
  assertInvalid(
    () => requireEmail({ email: `moc.elpmaxe${RLO}@evil.com` }, 'email'),
    'email',
    'forbidden_characters',
  );
});

// --- requireText ---------------------------------------------------------------

Deno.test('requireText returns the trimmed text when it has at most max code points', () => {
  // "Maalik-e makaan": ten code points, one of them a kasra.
  const urdu = char(0x0645, 0x0627, 0x0644, 0x06a9, 0x0650, 0x0020, 0x0645, 0x06a9, 0x0627, 0x0646);
  const cases: ReadonlyArray<readonly [string, number, string]> = [
    ['  owner@example.com  ', 320, 'owner@example.com'],
    ['abc', 3, 'abc'],
    ['  abc\n', 3, 'abc'],
    ['line one\n\tline two', 20, 'line one\n\tline two'],
    [HOUSE.repeat(3), 3, HOUSE.repeat(3)],
    [urdu, 10, urdu],
    // Code points, like the database's char_length: the family emoji counts seven.
    [FAMILY, 7, FAMILY],
  ];
  for (const [value, max, text] of cases) {
    assertEquals(requireText({ confirm: value }, 'confirm', max), text, JSON.stringify(value));
  }
});

Deno.test('requireText rejects text longer than max code points as too_long', () => {
  const cases: ReadonlyArray<readonly [string, number]> = [
    ['abcd', 3],
    ['  abcd  ', 3],
    [HOUSE.repeat(4), 3],
    [FAMILY, 6],
  ];
  for (const [value, max] of cases) {
    assertInvalid(() => requireText({ confirm: value }, 'confirm', max), 'confirm', 'too_long');
  }
});

Deno.test('requireText reports empty and whitespace-only text as required', () => {
  for (const value of ['', ' ', '\t\r\n ', `${NBSP}${NBSP}`]) {
    assertInvalid(() => requireText({ confirm: value }, 'confirm', 10), 'confirm', 'required');
  }
});

Deno.test('requireText rejects forbidden characters before trimming or measuring', () => {
  for (const value of [NUL, `  ${ZWSP}  `, `ok${RLO}`, `${BOM}ok`, `ok${BOM}`]) {
    assertInvalid(
      () => requireText({ confirm: value }, 'confirm', 1),
      'confirm',
      'forbidden_characters',
    );
  }
});

// --- requireEnum and optionalEnum ------------------------------------------------

Deno.test('requireEnum accepts a listed value, trimmed', () => {
  assertEquals(requireEnum({ role: 'owner' }, 'role', ROLES), 'owner');
  assertEquals(requireEnum({ role: ' viewer\n' }, 'role', ROLES), 'viewer');
});

Deno.test('requireEnum rejects an unlisted value as not_allowed, case-sensitively', () => {
  for (const value of ['admin', 'Owner', 'VIEWER', '', '  ', 'owner viewer']) {
    assertInvalid(() => requireEnum({ role: value }, 'role', ROLES), 'role', 'not_allowed');
  }
});

Deno.test('optionalEnum falls back only when the field is absent or null', () => {
  const locales = ['en', 'ur'] as const;
  assertEquals(optionalEnum({}, 'locale', locales, 'en'), 'en');
  assertEquals(optionalEnum({ locale: undefined }, 'locale', locales, 'ur'), 'ur');
  assertEquals(optionalEnum({ locale: null }, 'locale', locales, 'en'), 'en');
  assertEquals(optionalEnum({ locale: 'ur' }, 'locale', locales, 'en'), 'ur');
  assertEquals(optionalEnum({ locale: ' ur ' }, 'locale', locales, 'en'), 'ur');
  for (const value of ['fr', '', ' ']) {
    assertInvalid(
      () => optionalEnum({ locale: value }, 'locale', locales, 'en'),
      'locale',
      'not_allowed',
    );
  }
});

// --- optionalBoolean -------------------------------------------------------------

Deno.test('optionalBoolean returns a boolean, or the fallback when absent or null', () => {
  const cases: ReadonlyArray<readonly [JsonObject, boolean, boolean]> = [
    [{}, true, true],
    [{}, false, false],
    [{ flag: null }, true, true],
    [{ flag: undefined }, false, false],
    [{ flag: true }, false, true],
    [{ flag: false }, true, false],
  ];
  for (const [body, fallback, expected] of cases) {
    assertEquals(optionalBoolean(body, 'flag', fallback), expected, JSON.stringify(body));
  }
});

Deno.test('optionalBoolean rejects anything else as not_a_boolean', () => {
  for (const value of ['true', 'false', '', 1, 0, [], {}, [true]]) {
    assertInvalid(() => optionalBoolean({ flag: value }, 'flag', true), 'flag', 'not_a_boolean');
  }
});
