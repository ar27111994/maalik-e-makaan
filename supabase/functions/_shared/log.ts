/**
 * Structured logging: one JSON object per line, which the Supabase log
 * explorer indexes. Values under sensitive keys are redacted recursively, and
 * callers log user ids rather than e-mail addresses or names.
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

/** Returns a copy of [value] with sensitive fields replaced by "[redacted]". */
export function redact(value: unknown, depth = 0): unknown {
  if (depth > MAX_DEPTH) return '[truncated]';
  if (value instanceof Error) {
    return { name: value.name, message: value.message, cause: redact(value.cause, depth + 1) };
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

/** Writes records to stdout/stderr as JSON lines. */
export function consoleSink(record: LogRecord): void {
  const line = JSON.stringify(record);
  // The platform collects function logs from the console.
  // deno-lint-ignore no-console
  (record.level === 'info' ? console.log : console.error)(line);
}

/** A logger whose records all carry [base] fields (function name, request id). */
export function createLogger(base: Record<string, unknown>, sink: LogSink = consoleSink): Logger {
  const write = (level: LogLevel, event: string, fields: Record<string, unknown> = {}) => {
    sink({ ...(redact({ ...base, ...fields }) as Record<string, unknown>), level, event });
  };
  return {
    info: (event, fields) => write('info', event, fields),
    warn: (event, fields) => write('warn', event, fields),
    error: (event, fields) => write('error', event, fields),
  };
}
