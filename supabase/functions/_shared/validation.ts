/**
 * Strict input validation for JSON request bodies.
 *
 * Every validator either returns a normalised, typed value or throws a 422
 * naming the field. Unknown fields are rejected so typos and smuggled
 * parameters fail loudly instead of being ignored.
 */

import { invalidField } from './errors.ts';
import { isCleanText } from './text.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
// Same rule as the database's e-mail CHECKs (after lower-casing).
const EMAIL = /^[^@\s]+@[^@\s]+\.[a-z]{2,63}$/;

export type JsonObject = Readonly<Record<string, unknown>>;

/** Throws a 422 when [body] has fields outside [allowed]. */
export function rejectUnknownFields(body: JsonObject, allowed: readonly string[]): void {
  const unknown = Object.keys(body).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) {
    throw invalidField(unknown.sort()[0] as string, 'unknown_field');
  }
}

function requireString(body: JsonObject, field: string): string {
  const value = body[field];
  if (value === undefined || value === null) throw invalidField(field, 'required');
  if (typeof value !== 'string') throw invalidField(field, 'not_a_string');
  if (!isCleanText(value)) throw invalidField(field, 'forbidden_characters');
  return value;
}

/** A UUID (any RFC 9562 version), returned in lower case. */
export function requireUuid(body: JsonObject, field: string): string {
  const value = requireString(body, field).trim();
  if (!UUID.test(value)) throw invalidField(field, 'not_a_uuid');
  return value.toLowerCase();
}

/** An e-mail address, trimmed and lower-cased, at most 254 characters. */
export function requireEmail(body: JsonObject, field: string): string {
  const value = requireString(body, field).trim().toLowerCase();
  if (value.length > 254 || !EMAIL.test(value)) throw invalidField(field, 'not_an_email');
  return value;
}

/** One of [allowed]. */
export function requireEnum<T extends string>(
  body: JsonObject,
  field: string,
  allowed: readonly T[],
): T {
  const value = requireString(body, field).trim();
  if (!(allowed as readonly string[]).includes(value)) throw invalidField(field, 'not_allowed');
  return value as T;
}

/** One of [allowed], or [fallback] when the field is absent or null. */
export function optionalEnum<T extends string>(
  body: JsonObject,
  field: string,
  allowed: readonly T[],
  fallback: T,
): T {
  return body[field] === undefined || body[field] === null
    ? fallback
    : requireEnum(body, field, allowed);
}

/** A boolean, or [fallback] when the field is absent or null. */
export function optionalBoolean(body: JsonObject, field: string, fallback: boolean): boolean {
  const value = body[field];
  if (value === undefined || value === null) return fallback;
  if (typeof value !== 'boolean') throw invalidField(field, 'not_a_boolean');
  return value;
}
