/**
 * Structured logging: one JSON object per line, which the Supabase log
 * explorer indexes. Values under sensitive keys are redacted recursively, and
 * callers log user ids rather than e-mail addresses or names. Records are
 * kept small: long strings are cut, and an oversized record is replaced by a
 * marker that keeps its level, event and request id.
 */

export type LogLevel = 'info' | 'warn' | 'error';

export interface LogRecord {
  readonly level: LogLevel;
  readonly event: string;
  readonly [field: string]: unknown;
}

export type LogSink = (record: LogRecord) => void;

export interface Logger {
  info(event: string, fields?: Record<string, unknown>): void;
  warn(event: string, fields?: Record<string, unknown>): void;
  error(event: string, fields?: Record<string, unknown>): void;
}

const SENSITIVE_KEY = /token|secret|password|authorization|apikey|api_key|cookie|email|jwt/i;
const MAX_DEPTH = 6;
/** Longest string value kept in a record. */
export const MAX_STRING_LENGTH = 1_000;
/** Largest serialised record written as is. */
export const MAX_RECORD_BYTES = 8_192;

/**
 * Returns a copy of [value] with sensitive fields replaced by "[redacted]"
 * and long strings shortened.
 */
export function redact(value: unknown, depth = 0): unknown {
  if (depth > MAX_DEPTH) return '[truncated]';
  if (typeof value === 'string') {
    return value.length <= MAX_STRING_LENGTH
      ? value
      : `${value.slice(0, MAX_STRING_LENGTH)}…[${value.length - MAX_STRING_LENGTH} more]`;
  }
  if (value instanceof Error) {
    return {
      name: value.name,
      message: redact(value.message, depth + 1),
      cause: redact(value.cause, depth + 1),
    };
  }
  if (Array.isArray(value)) return value.map((item) => redact(item, depth + 1));
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        SENSITIVE_KEY.test(key) ? '[redacted]' : redact(item, depth + 1),
      ]),
    );
  }
  return value;
}

// The platform collects function logs from the console, by level.
const CONSOLE: Readonly<Record<LogLevel, (line: string) => void>> = {
  // deno-lint-ignore no-console
  info: (line) => console.log(line),
  // deno-lint-ignore no-console
  warn: (line) => console.warn(line),
  // deno-lint-ignore no-console
  error: (line) => console.error(line),
};

/** Writes records to the console as JSON lines, at the matching console level. */
export function consoleSink(record: LogRecord): void {
  CONSOLE[record.level](JSON.stringify(record));
}

/** [record] itself, or a marker when its serialised form is too large. */
export function boundRecord(record: LogRecord): LogRecord {
  const size = new TextEncoder().encode(JSON.stringify(record)).byteLength;
  if (size <= MAX_RECORD_BYTES) return record;
  return {
    level: record.level,
    event: record.event,
    fn: record['fn'],
    request_id: record['request_id'],
    truncated_bytes: size,
  };
}

/** A logger whose records all carry [base] fields (function name, request id). */
export function createLogger(base: Record<string, unknown>, sink: LogSink = consoleSink): Logger {
  const write = (level: LogLevel, event: string, fields: Record<string, unknown> = {}) => {
    sink(
      boundRecord({ ...(redact({ ...base, ...fields }) as Record<string, unknown>), level, event }),
    );
  };
  return {
    info: (event, fields) => write('info', event, fields),
    warn: (event, fields) => write('warn', event, fields),
    error: (event, fields) => write('error', event, fields),
  };
}
