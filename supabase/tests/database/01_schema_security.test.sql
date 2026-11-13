-- Schema-wide security invariants: every exposed table has RLS, nothing is
-- reachable by default, privileged functions are hardened, foreign keys are
-- indexed. These tests fail the build if a future migration regresses.
begin;
\ir _helpers.psql
select plan(24);

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
    'refund_deposit', 'remove_member', 'revoke_invitation', 'set_caretaker', 'set_owner_abroad',
    'sync_portfolio_billing', 'update_charge', 'update_member_role', 'void_cash_handover', 'void_charge',
    'void_deposit_refund', 'void_payment', 'waive_charge'
  ]::text[],
  'only the reviewed write RPCs run as SECURITY DEFINER for signed-in users'
);

-- Each of them authorises the caller: by portfolio role (directly or through
-- the lease or portfolio lock helpers) or, for operations on the caller's own identity, by
-- rejecting anonymous calls. Behaviour is covered by 03_rls_matrix.
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('authenticated', p.oid, 'execute')
     and p.prosrc !~ '(app\.require_portfolio_role|private\.lock_lease_for_write|private\.lock_portfolio_for_change)\('
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

-- Residence (20261112092618_residence.sql). A person's row is made by a
-- trigger for every profile and read and written by that person only; the
-- client may change the two declared values, never when they were stated.
select ok(
  not has_table_privilege('authenticated', 'public.profile_residences', 'insert')
  and not has_table_privilege('authenticated', 'public.profile_residences', 'delete'),
  'clients can neither insert nor delete residence rows'
);

select is(
  (select array_agg(a.attname::text order by a.attname)
   from pg_attribute a
   where a.attrelid = 'public.profile_residences'::regclass and a.attnum > 0 and not a.attisdropped
     and has_column_privilege('authenticated', a.attrelid, a.attnum, 'update')),
  array['residence_country', 'time_zone'],
  'clients may update only the declared country and time zone of a residence row'
);

-- The owner-abroad answer and the caretaker change only through
-- set_owner_abroad and set_caretaker (and create_portfolio's answer).
select is(
  (select array_agg(format('%s:%s:%s', a.attname,
                           has_column_privilege('authenticated', a.attrelid, a.attnum, 'insert'),
                           has_column_privilege('authenticated', a.attrelid, a.attnum, 'update'))
                    order by a.attname)
   from pg_attribute a
   where a.attrelid = 'public.portfolios'::regclass
     and a.attname in ('owner_abroad', 'caretaker_user_id', 'caretaker_since')),
  array['caretaker_since:f:f', 'caretaker_user_id:f:f', 'owner_abroad:f:f'],
  'clients can write neither the owner-abroad answer nor the caretaker directly'
);

-- Released 1.0.x apps embed portfolios!inner from portfolio_members with no
-- hint. A second foreign key between the two tables, in either direction,
-- makes that embed ambiguous and PostgREST answers it with PGRST201: the
-- caretaker is kept a manager by triggers instead of a composite key.
select is(
  (select count(*)::integer
   from pg_constraint c
   where c.contype = 'f'
     and ((c.conrelid = 'public.portfolio_members'::regclass and c.confrelid = 'public.portfolios'::regclass)
          or (c.conrelid = 'public.portfolios'::regclass
              and c.confrelid = 'public.portfolio_members'::regclass))),
  1,
  'exactly one foreign key links portfolio_members and portfolios, so the app''s embed stays unambiguous'
);

-- D-16: nationality and immigration status are never stored, residence
-- never returns to the table teammates read, and amounts stay in rupees.
select is(
  (select coalesce(array_agg(format('%s.%s', c.relname, a.attname) order by c.relname, a.attname), '{}')
   from pg_attribute a
   join pg_class c on c.oid = a.attrelid
   where a.attrelid in ('public.profiles'::regclass, 'public.profile_residences'::regclass)
     and a.attnum > 0 and not a.attisdropped
     and a.attname ~* '(nationality|citizenship|immigration|visa|passport)'),
  '{}'::text[],
  'no nationality, citizenship, immigration, visa or passport column on a person'
);

select is(
  (select coalesce(array_agg(format('%s.%s', c.relname, a.attname) order by c.relname), '{}')
   from pg_attribute a
   join pg_class c on c.oid = a.attrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and a.attnum > 0 and not a.attisdropped and a.attname = 'display_currency'),
  '{}'::text[],
  'no display_currency column: amounts stay in rupees at launch'
);

select is(
  (select coalesce(array_agg(a.attname::text order by a.attname), '{}')
   from pg_attribute a
   where a.attrelid = 'public.profiles'::regclass and a.attnum > 0 and not a.attisdropped
     and a.attname in ('residence_country', 'time_zone')),
  '{}'::text[],
  'residence is not on profiles, which teammates can read'
);

select * from finish();
rollback;
