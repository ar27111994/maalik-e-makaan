-- ============================================================================
set client_min_messages = warning;
-- Local Supabase emulation for database tests on a plain PostgreSQL server.
--
-- The hosted platform and `supabase start` provide these objects. This file
-- recreates the parts our migrations and pgTAP suites depend on, so that the
-- complete migration chain and test suite also run against a vanilla
-- Postgres 15+ (see tool/db-test.sh). It is NEVER applied to a real project.
--
-- Fidelity notes:
--   * auth.uid()/auth.jwt()/auth.role() are copied from the GoTrue schema and
--     read the same `request.jwt.claims` GUC that PostgREST sets.
--   * Roles mirror Supabase's: anon, authenticated, service_role (BYPASSRLS),
--     authenticator (NOINHERIT login role that switches into the others).
--   * storage.objects/buckets carry the columns and helper functions that
--     storage RLS policies use.
-- ============================================================================
\set ON_ERROR_STOP on

-- Roles ----------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_storage_admin') then
    create role supabase_storage_admin nologin noinherit;
  end if;
end
$$;

grant anon, authenticated, service_role to authenticator;
grant anon, authenticated, service_role to postgres;

-- Schemas & extensions --------------------------------------------------------
create schema if not exists extensions;
create schema if not exists auth;
create schema if not exists storage;

grant usage on schema public, extensions to anon, authenticated, service_role;
grant usage on schema auth, storage to anon, authenticated, service_role;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pgtap with schema extensions;

do $$
begin
  execute format('alter database %I set search_path = "$user", public, extensions', current_database());
end
$$;
set search_path = "$user", public, extensions;

-- Supabase's platform-level default privileges: every table/function created
-- by postgres in public is granted to the API roles. Our first migration
-- revokes these, exactly as it must on the hosted platform.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- auth schema (subset of GoTrue) ----------------------------------------------
create table if not exists auth.users (
  instance_id uuid,
  id uuid primary key,
  aud varchar(255) default 'authenticated',
  role varchar(255) default 'authenticated',
  email varchar(255),
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  phone text,
  phone_confirmed_at timestamptz,
  raw_app_meta_data jsonb default '{}'::jsonb,
  raw_user_meta_data jsonb default '{}'::jsonb,
  confirmation_token varchar(255) default '',
  recovery_token varchar(255) default '',
  email_change_token_new varchar(255) default '',
  email_change varchar(255) default '',
  is_anonymous boolean not null default false,
  is_sso_user boolean not null default false,
  banned_until timestamptz,
  deleted_at timestamptz,
  last_sign_in_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create unique index if not exists users_email_partial_key on auth.users (email) where is_sso_user = false;

create table if not exists auth.identities (
  id uuid primary key default gen_random_uuid(),
  provider_id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  identity_data jsonb not null,
  provider text not null,
  last_sign_in_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (provider_id, provider)
);

create table if not exists auth.sessions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  not_after timestamptz
);

create or replace function auth.uid() returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create or replace function auth.role() returns text
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

create or replace function auth.email() returns text
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;

create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;

grant execute on function auth.uid(), auth.role(), auth.email(), auth.jwt()
  to anon, authenticated, service_role;
grant select on auth.users to service_role;

-- storage schema (subset of supabase/storage) -------------------------------
create table if not exists storage.buckets (
  id text primary key,
  name text not null unique,
  owner uuid,
  owner_id text,
  public boolean default false,
  avif_autodetection boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid,
  owner_id text,
  metadata jsonb,
  user_metadata jsonb,
  version text,
  path_tokens text[] generated always as (string_to_array(name, '/')) stored,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_accessed_at timestamptz default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
alter table storage.buckets enable row level security;

create or replace function storage.foldername(name text) returns text[]
language plpgsql immutable
as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end
$$;

create or replace function storage.filename(name text) returns text
language plpgsql immutable
as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[array_length(_parts, 1)];
end
$$;

create or replace function storage.extension(name text) returns text
language plpgsql immutable
as $$
declare
  _parts text[];
  _filename text;
begin
  select string_to_array(name, '/') into _parts;
  select _parts[array_length(_parts, 1)] into _filename;
  return reverse(split_part(reverse(_filename), '.', 1));
end
$$;

grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;
grant all on storage.buckets to service_role;
grant execute on function storage.foldername(text), storage.filename(text), storage.extension(text)
  to anon, authenticated, service_role;
