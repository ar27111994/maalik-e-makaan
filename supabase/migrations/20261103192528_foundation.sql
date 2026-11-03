-- ============================================================================
-- Foundation: extensions, schemas, Data API privileges and shared helpers.
--
-- Schema layout
--   public   Exposed through the Data API. Tables (all with RLS) and RPCs.
--   app      NOT exposed. Helpers that API roles must be able to execute
--            implicitly (RLS policies, column defaults, CHECK constraints).
--   private  NOT exposed and not usable by API roles at all: internal tables
--            (rate limits, counters) and SECURITY DEFINER internals.
--
-- Data API exposure is opt-in: Supabase's default grants on new objects in
-- `public` are revoked here, and every table/function later receives explicit,
-- minimal grants next to its RLS policies.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists btree_gist with schema extensions;

create schema if not exists app;
create schema if not exists private;

revoke all on schema app, private from public;
grant usage on schema app to anon, authenticated, service_role;

comment on schema app is
  'Helpers executed implicitly by RLS policies, defaults and constraints. Not exposed via the Data API.';
comment on schema private is
  'Internal tables and SECURITY DEFINER functions. No privileges for API roles.';

-- Opt-in exposure: nothing new in public/app/private is reachable by default.
-- Postgres grants EXECUTE on new functions to PUBLIC through a *global*
-- default privilege; per-schema defaults can only add privileges, so the
-- PUBLIC grant must be revoked globally (this covers every schema).
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete, truncate, references, trigger on tables
  from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke usage, select, update on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema app
  revoke execute on functions from public;
alter default privileges for role postgres in schema private
  revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- Identifiers
-- ---------------------------------------------------------------------------

-- RFC 9562 UUIDv7: 48-bit Unix-millisecond prefix + 74 random bits. Time
-- ordering keeps B-tree inserts append-mostly (no v4 page splits) and lets
-- ids double as a creation-order tie-breaker. Clients may also generate v7
-- ids themselves for idempotent, offline-friendly inserts.
create or replace function app.uuid_generate_v7()
returns uuid
language plpgsql
volatile
parallel safe
set search_path = ''
as $$
declare
  v_bytes bytea := uuid_send(gen_random_uuid());
  v_millis bigint := floor(extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  v_bytes := overlay(v_bytes placing substring(int8send(v_millis) from 3) from 1 for 6);
  -- Version nibble 0111; the RFC 4122 variant bits come from gen_random_uuid().
  v_bytes := set_byte(v_bytes, 6, (get_byte(v_bytes, 6) & 15) | 112);
  return encode(v_bytes, 'hex')::uuid;
end
$$;

comment on function app.uuid_generate_v7() is 'Time-ordered UUID (RFC 9562 version 7).';
grant execute on function app.uuid_generate_v7() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Defensive validation used by CHECK constraints
-- ---------------------------------------------------------------------------

-- Rejects control characters (except tab/LF/CR), bidirectional overrides and
-- isolates ("Trojan Source"), and invisible spoofing characters. Urdu's
-- zero-width (non-)joiner and LRM/RLM marks remain allowed. The app sanitises
-- input first; this is defence in depth for every other client.
create or replace function app.is_clean_text(p_value text)
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
  select p_value is null
    or p_value !~ '[\x0001-\x0008\x000B\x000C\x000E-\x001F\x007F-\x009F\x00AD\x061C\x180E\x200B\x202A-\x202E\x2060-\x2064\x2066-\x2069\xFEFF]'
$$;

comment on function app.is_clean_text(text) is
  'True when text has no control, bidi-override or invisible spoofing characters.';
grant execute on function app.is_clean_text(text) to anon, authenticated, service_role;

-- ISO 13616 MOD-97-10 checksum for IBANs (upper case, no spaces).
create or replace function app.is_valid_iban(p_iban text)
returns boolean
language plpgsql
immutable
strict
parallel safe
set search_path = ''
as $$
declare
  v_rearranged text;
  v_code integer;
  v_digits text;
  v_remainder integer := 0;
begin
  if p_iban !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$' then
    return false;
  end if;
  v_rearranged := substr(p_iban, 5) || substr(p_iban, 1, 4);
  for i in 1 .. length(v_rearranged) loop
    v_code := ascii(substr(v_rearranged, i, 1));
    v_digits := case when v_code between 48 and 57 then chr(v_code) else (v_code - 55)::text end;
    for j in 1 .. length(v_digits) loop
      v_remainder := (v_remainder * 10 + (ascii(substr(v_digits, j, 1)) - 48)) % 97;
    end loop;
  end loop;
  return v_remainder = 1;
end
$$;

comment on function app.is_valid_iban(text) is 'ISO 13616 IBAN checksum validation.';
grant execute on function app.is_valid_iban(text) to anon, authenticated, service_role;

-- Pakistan Standard Time (UTC+05:00, no DST) is the business calendar.
-- `app.today_override` is a clock seam for tests and operational backfills:
-- only direct database sessions can set it (API clients cannot SET settings).
create or replace function app.today_pkt()
returns date
language sql
stable
parallel safe
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('app.today_override', true), '')::date,
    (now() at time zone 'Asia/Karachi')::date
  )
$$;

comment on function app.today_pkt() is 'Current calendar date in Pakistan Standard Time.';
grant execute on function app.today_pkt() to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Security primitives
-- ---------------------------------------------------------------------------

-- Constant-time comparison: the loop always visits every byte, so the time
-- taken does not reveal the position of the first mismatch.
create or replace function private.timing_safe_equal(p_a bytea, p_b bytea)
returns boolean
language plpgsql
immutable
strict
parallel safe
set search_path = ''
as $$
declare
  v_diff integer := 0;
begin
  if length(p_a) <> length(p_b) then
    return false;
  end if;
  for i in 0 .. length(p_a) - 1 loop
    v_diff := v_diff | (get_byte(p_a, i) # get_byte(p_b, i));
  end loop;
  return v_diff = 0;
end
$$;

comment on function private.timing_safe_equal(bytea, bytea) is
  'Constant-time byte comparison for secrets (no early exit).';

-- Fixed-window counters. One row per (key, window); old windows are purged
-- by the maintenance job.
create table private.rate_limit_buckets (
  bucket_key text not null,
  window_start timestamptz not null,
  hits integer not null default 1,
  primary key (bucket_key, window_start)
);

comment on table private.rate_limit_buckets is
  'Fixed-window rate-limit counters (pre-request write limits and per-action limits).';

-- Counts one hit and reports whether it is within the limit.
create or replace function private.hit_rate_limit(
  p_key text,
  p_limit integer,
  p_window interval
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_window timestamptz := date_bin(p_window, now(), timestamptz '2000-01-01 00:00:00+00');
  v_hits integer;
begin
  insert into private.rate_limit_buckets as b (bucket_key, window_start, hits)
  values (p_key, v_window, 1)
  on conflict (bucket_key, window_start) do update set hits = b.hits + 1
  returning b.hits into v_hits;
  return v_hits <= p_limit;
end
$$;

-- Aborts the request with HTTP 429 and a Retry-After header (PostgREST maps
-- SQLSTATE 'PGRST' with a JSON message/detail onto the HTTP response).
create or replace function private.raise_rate_limited(p_retry_after_seconds integer, p_details text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code', 'rate_limited',
      'message', 'Too many requests. Please wait a moment and try again.',
      'details', p_details
    )::text,
    detail = json_build_object(
      'status', 429,
      'headers', json_build_object('Retry-After', p_retry_after_seconds::text)
    )::text;
end
$$;

-- Raises HTTP 429 when the signed-in caller exceeds p_limit calls of
-- p_action per p_window.
create or replace function private.enforce_rate_limit(
  p_action text,
  p_limit integer,
  p_window interval
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not private.hit_rate_limit(
    p_action || ':' || coalesce((select auth.uid())::text, 'anonymous'),
    p_limit,
    p_window
  ) then
    perform private.raise_rate_limited(extract(epoch from p_window)::integer, p_action);
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Trigger helpers
-- ---------------------------------------------------------------------------

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

-- Domain error helpers: every RPC reports failures as SQLSTATE 22023 with a
-- stable, machine-readable message key that clients map to localised text
-- (42501 for authorisation). They only raise, so API roles may execute them;
-- SECURITY INVOKER report functions need that.
create or replace function app.fail(p_key text, p_detail text default null)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '22023', message = p_key, detail = coalesce(p_detail, p_key);
end
$$;

create or replace function app.forbid()
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '42501', message = 'forbidden';
end
$$;

grant execute on function app.fail(text, text), app.forbid() to authenticated, service_role;
