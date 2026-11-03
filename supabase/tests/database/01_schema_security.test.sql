-- Schema-wide security invariants: every exposed table has RLS, nothing is
-- reachable by default, privileged functions are hardened, foreign keys are
-- indexed. These tests fail the build if a future migration regresses.
begin;
\ir _helpers.psql
select plan(17);

select is(
  (select coalesce(array_agg(c.relname order by c.relname), '{}')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  '{}'::name[],
  'every table in public has row level security enabled'
);

select is(
  (select coalesce(array_agg(c.relname order by c.relname), '{}')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p')
     and not exists (select 1 from pg_policy p where p.polrelid = c.oid)),
  '{}'::name[],
  'every table in public has at least one policy'
);

-- Privileges are read from the ACLs themselves rather than from
-- information_schema, which omits non-standard privilege types such as
-- PostgreSQL 17's MAINTAIN.
select is(
  (select coalesce(array_agg(g.entry order by g.entry), '{}')
   from (
     select format('%s:%s', c.relname, a.privilege_type) as entry
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     cross join lateral aclexplode(c.relacl) a
     where n.nspname in ('public', 'private') and a.grantee = 'anon'::regrole::oid
   ) g),
  '{}'::text[],
  'the anon role holds no privilege on any relation'
);

select is(
  (select coalesce(array_agg(g.entry order by g.entry), '{}')
   from (
     select format('%s:%s:%s', c.relname, a.grantee::regrole, a.privilege_type) as entry
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     cross join lateral aclexplode(c.relacl) a
     where n.nspname in ('public', 'private')
       and a.grantee in ('authenticated'::regrole::oid, 'service_role'::regrole::oid)
       and a.privilege_type not in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
   ) g),
  '{}'::text[],
  'API roles hold only SELECT/INSERT/UPDATE/DELETE (never TRUNCATE, REFERENCES, TRIGGER or MAINTAIN)'
);

select is(
  (select coalesce(array_agg(g.entry order by g.entry), '{}')
   from (
     select format('%s:%s:%s', coalesce(d.defaclnamespace::regnamespace::text, '*'), d.defaclobjtype,
                   a.grantee::regrole) as entry
     from pg_default_acl d
     cross join lateral aclexplode(d.defaclacl) a
     where d.defaclrole = 'postgres'::regrole
       and (d.defaclnamespace = 0
            or d.defaclnamespace in ('public'::regnamespace, 'app'::regnamespace, 'private'::regnamespace))
       and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid, 'service_role'::regrole::oid)
   ) g),
  '{}'::text[],
  'objects created later in our schemas grant nothing to API roles by default'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app', 'private') and p.prosecdef
     and not coalesce(p.proconfig @> array['search_path=""'], false)),
  '{}'::text[],
  'every SECURITY DEFINER function pins an empty search_path'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app', 'private') and p.prokind = 'f'
     and not coalesce(p.proconfig @> array['search_path=""'], false)),
  '{}'::text[],
  'every function in our schemas pins an empty search_path'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  '{}'::text[],
  'anon can execute no public function'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and (has_function_privilege('authenticated', p.oid, 'execute')
          or has_function_privilege('anon', p.oid, 'execute'))),
  '{}'::text[],
  'private functions are not executable by API roles'
);

select ok(
  not has_schema_privilege('authenticated', 'private', 'usage')
  and not has_schema_privilege('anon', 'private', 'usage'),
  'API roles have no access to the private schema'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  '{}'::text[],
  'admin_* functions are reserved for the service role'
);

-- SECURITY DEFINER RPCs bypass row-level security, so the set reachable by
-- signed-in users is pinned (Supabase lint 0029): adding one means reviewing
-- it and updating this list. Read-only RPCs must use SECURITY INVOKER.
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('authenticated', p.oid, 'execute')),
  array[
    'accept_invitation', 'apply_deposit', 'bill_utility_to_tenant', 'change_rent', 'confirm_cash_handover',
    'create_invitation', 'create_portfolio', 'delete_portfolio', 'end_lease', 'record_payment',
    'refund_deposit', 'remove_member', 'revoke_invitation', 'sync_portfolio_billing', 'update_member_role',
    'void_cash_handover', 'void_charge', 'void_deposit_refund', 'void_payment', 'waive_charge'
  ]::text[],
  'only the reviewed write RPCs run as SECURITY DEFINER for signed-in users'
);

-- Each of them authorises the caller: by portfolio role (directly or through
-- the lease lock) or, for operations on the caller's own identity, by
-- rejecting anonymous calls. Behaviour is covered by 03_rls_matrix.
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('authenticated', p.oid, 'execute')
     and p.prosrc !~ '(app\.require_portfolio_role|private\.lock_lease_for_write)\('
     and not (p.prosrc ~ 'v_uid uuid := \(select auth\.uid\(\)\);'
              and p.prosrc ~ 'if v_uid is null then\s+perform app\.forbid\(\);')),
  '{}'::text[],
  'every SECURITY DEFINER RPC authorises its caller'
);

-- Foreign keys must be covered by an index whose leading columns match.
select is(
  (select coalesce(array_agg(g.entry order by g.entry), '{}')
   from (
     select format('%s(%s)', c.conrelid::regclass, c.conname) as entry
     from pg_constraint c
     join pg_namespace n on n.oid = (select relnamespace from pg_class where oid = c.conrelid)
     where c.contype = 'f' and n.nspname = 'public'
       and not exists (
         select 1 from pg_index i
         where i.indrelid = c.conrelid
           and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] @> c.conkey
           and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] <@ c.conkey
       )
   ) g),
  '{}'::text[],
  'every foreign key is backed by an index'
);

select is(
  (select coalesce(array_agg(c.relname order by c.relname), '{}')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v'
     and not coalesce(c.reloptions @> array['security_invoker=true'], false)),
  '{}'::name[],
  'views run with the privileges of the caller (security_invoker)'
);

select ok(
  (select bool_and(pg_catalog.has_column_privilege('authenticated', 'public.portfolio_invitations', a.attname, 'select')
                   = (a.attname <> 'verifier_hash'))
   from pg_attribute a
   where a.attrelid = 'public.portfolio_invitations'::regclass and a.attnum > 0 and not a.attisdropped),
  'invitation verifier hashes are not readable by clients'
);

select is(
  (select count(*)::integer from storage.buckets where id = 'documents' and public is false
     and file_size_limit = 10485760),
  1,
  'the documents bucket exists, is private and capped at 10 MB'
);

select * from finish();
rollback;
