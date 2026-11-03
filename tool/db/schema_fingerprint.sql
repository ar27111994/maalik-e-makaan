-- Schema fingerprint: one JSON object mapping every database object this
-- project owns to an md5 of its definition (functions, relations, columns,
-- constraints, indexes, triggers, policies, enums, privileges and the storage
-- bucket).
--
-- Run it against two databases and diff the results to detect drift, e.g.
-- the local migration chain against the hosted project:
--
--   psql -X -At -d db_a -f tool/db/schema_fingerprint.sql > a.json
--   psql -X -At -d db_b -f tool/db/schema_fingerprint.sql > b.json
--   tool/db/fingerprint_diff.py a.json b.json
--
-- Privileges are listed per grantee and privilege type (aclexplode), leaving
-- out the owner's implicit entry, so PostgreSQL 16 and 17 fingerprints are
-- comparable (17 adds MAINTAIN to the owner) while every grant to another
-- role, including MAINTAIN, still counts.
with objects (k, v) as (
  -- Functions: body, configuration, security, volatility, signature, ACL, owner.
  select
    'function:' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
    concat_ws(
      '|', p.prosrc, array_to_string(p.proconfig, ','), p.prosecdef, p.provolatile, p.proparallel,
      p.proisstrict, pg_get_function_result(p.oid), pg_get_function_arguments(p.oid),
      (select string_agg(g.entry, ',' order by g.entry)
       from (
         select format('%s=%s%s', case when x.grantee = 0 then 'public' else x.grantee::regrole::text end,
                       x.privilege_type, case when x.is_grantable then '*' else '' end) as entry
         from aclexplode(p.proacl) x
         where x.grantee <> p.proowner
       ) g),
      p.proowner::regrole
    )
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'app', 'private')

  union all
  -- Relations: kind, RLS flags, ACL, owner, view definition, options.
  select
    'relation:' || n.nspname || '.' || c.relname,
    concat_ws(
      '|', c.relkind, c.relrowsecurity, c.relforcerowsecurity,
      (select string_agg(g.entry, ',' order by g.entry)
       from (
         select format('%s=%s%s', case when x.grantee = 0 then 'public' else x.grantee::regrole::text end,
                       x.privilege_type, case when x.is_grantable then '*' else '' end) as entry
         from aclexplode(c.relacl) x
         where x.grantee <> c.relowner
       ) g),
      c.relowner::regrole,
      case when c.relkind in ('v', 'm') then pg_get_viewdef(c.oid) end,
      array_to_string(c.reloptions, ',')
    )
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'private') and c.relkind in ('r', 'p', 'v', 'm', 'S')

  union all
  -- Columns: type, nullability, generation/identity, default, column ACL.
  select
    'column:' || n.nspname || '.' || c.relname || '.' || a.attname,
    concat_ws(
      '|', format_type(a.atttypid, a.atttypmod), a.attnotnull, a.attgenerated, a.attidentity,
      pg_get_expr(d.adbin, d.adrelid),
      (select string_agg(g.entry, ',' order by g.entry)
       from (
         select format('%s=%s%s', case when x.grantee = 0 then 'public' else x.grantee::regrole::text end,
                       x.privilege_type, case when x.is_grantable then '*' else '' end) as entry
         from aclexplode(a.attacl) x
         where x.grantee <> c.relowner
       ) g)
    )
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where n.nspname in ('public', 'private')
    and c.relkind in ('r', 'p', 'v', 'm')
    and a.attnum > 0
    and not a.attisdropped

  union all
  select 'constraint:' || n.nspname || '.' || c.relname || '.' || con.conname, pg_get_constraintdef(con.oid)
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'private')

  union all
  select 'index:' || schemaname || '.' || indexname, indexdef
  from pg_indexes
  where schemaname in ('public', 'private')

  union all
  -- Triggers on our tables, plus our triggers on platform tables (auth.users).
  select
    'trigger:' || n.nspname || '.' || c.relname || '.' || t.tgname,
    pg_get_triggerdef(t.oid)
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc f on f.oid = t.tgfoid
  join pg_namespace fn on fn.oid = f.pronamespace
  where not t.tgisinternal
    and (n.nspname in ('public', 'private') or fn.nspname in ('app', 'private'))

  union all
  select
    'policy:' || schemaname || '.' || tablename || '.' || policyname,
    concat_ws('|', permissive, array_to_string(roles, ','), cmd, qual, with_check)
  from pg_policies
  where schemaname = 'public' or (schemaname = 'storage' and policyname like 'documents\_objects\_%')

  union all
  select
    'enum:' || n.nspname || '.' || t.typname,
    (select string_agg(e.enumlabel, ',' order by e.enumsortorder) from pg_enum e where e.enumtypid = t.oid)
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  where t.typtype = 'e' and n.nspname = 'public'

  union all
  select
    'schema:' || s.nspname,
    (select string_agg(g.entry, ',' order by g.entry)
     from (
       select format('%s=%s%s', case when x.grantee = 0 then 'public' else x.grantee::regrole::text end,
                     x.privilege_type, case when x.is_grantable then '*' else '' end) as entry
       from aclexplode(s.nspacl) x
       where x.grantee <> s.nspowner
     ) g)
  from pg_namespace s
  where s.nspname in ('app', 'private')

  union all
  select
    'bucket:' || id,
    concat_ws('|', public, file_size_limit, array_to_string(allowed_mime_types, ','))
  from storage.buckets
  where id = 'documents'
)
select json_object_agg(k, md5(coalesce(v, '')) order by k)
from objects;
