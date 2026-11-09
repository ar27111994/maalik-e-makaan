-- Concurrency findings S1, S2 and M1 (20261105170557_concurrency_findings.sql):
-- client writes take the portfolio key first through their row policies (and,
-- for documents and manual charges, a statement trigger); a document insert
-- locks its file's storage.objects row, and every delete of the row (which
-- must lock it too) runs a trigger that keeps a referenced file; document
-- inserts and the orphan sweep share one gate. The races themselves
-- need several sessions and are run by tool/db/concurrency_test.sh
-- (scenarios 19 to 28); this suite pins the mechanisms and what one session
-- can observe of them.
begin;
\ir _helpers.psql
select plan(61);

set local app.today_override = '2026-11-03';
-- Counts function calls in this transaction (pg_stat_xact_user_functions).
set local track_functions = 'all';

create function tests.calls(p_function text)
returns bigint
language sql
set search_path = ''
as $$
  select coalesce(sum(f.calls), 0)::bigint
  from pg_catalog.pg_stat_xact_user_functions f
  where f.schemaname || '.' || f.funcname = p_function
$$;

-- Whether this transaction has locked (or deleted) the file's storage.objects
-- row: its xmax is this transaction's id.
create function tests.file_row_locked(p_path text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from storage.objects o
    where o.bucket_id = 'documents' and o.name = p_path
      and o.xmax = pg_catalog.xid(pg_catalog.pg_current_xact_id())
  )
$$;

-- The modes in which this session holds the sweep gate.
create function tests.gate_modes()
returns text[]
language sql
set search_path = ''
as $$
  select coalesce(array_agg(l.mode::text order by l.mode::text), '{}') from pg_catalog.pg_locks l
  where l.locktype = 'advisory' and l.pid = pg_catalog.pg_backend_pid() and l.granted
    and l.classid = 1701080943 and l.objid = 0 and l.objsubid = 2
$$;

-- How many advisory locks this session holds.
create function tests.advisory_locks()
returns bigint
language sql
set search_path = ''
as $$
  select count(*) from pg_catalog.pg_locks l
  where l.locktype = 'advisory' and l.pid = pg_catalog.pg_backend_pid() and l.granted
$$;

grant execute on function tests.calls(text), tests.file_row_locked(text), tests.gate_modes(), tests.advisory_locks()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Static facts
-- ---------------------------------------------------------------------------

select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text), '{}')
   from pg_proc p
   where p.oid in ('app.lock_my_portfolio_ids(public.member_role[])'::regprocedure,
                   'app.recheck_my_portfolio_ids(public.member_role[])'::regprocedure,
                   'app.lock_my_notification_portfolios()'::regprocedure,
                   'app.document_object_deletable(text)'::regprocedure,
                   'private.lock_inserted_row_portfolio(text, uuid)'::regprocedure,
                   'private.lock_document_sweep_gate(boolean)'::regprocedure,
                   'private.sweep_orphaned_files(timestamptz)'::regprocedure,
                   'private.before_document_object_delete()'::regprocedure)
     and not (p.prosecdef and p.provolatile = 'v' and coalesce(p.proconfig @> array['search_path=""'], false))),
  '{}'::text[],
  'the new helpers are volatile SECURITY DEFINER functions with an empty search_path'
);

select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text), '{}')
   from pg_proc p
   where p.oid in ('app.lock_my_portfolio_ids(public.member_role[])'::regprocedure,
                   'app.recheck_my_portfolio_ids(public.member_role[])'::regprocedure,
                   'app.lock_my_notification_portfolios()'::regprocedure,
                   'app.document_object_deletable(text)'::regprocedure,
                   'private.lock_inserted_row_portfolio(text, uuid)'::regprocedure,
                   'private.lock_document_sweep_gate(boolean)'::regprocedure,
                   'private.sweep_orphaned_files(timestamptz)'::regprocedure,
                   'private.before_document_object_delete()'::regprocedure,
                   'private.before_client_insert_lock_portfolios()'::regprocedure)
     and (has_function_privilege('anon', p.oid, 'execute')
          or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0))),
  '{}'::text[],
  'none of them is executable by PUBLIC or anon'
);

select ok(
  has_function_privilege('authenticated', 'app.lock_my_portfolio_ids(public.member_role[])', 'execute')
  and has_function_privilege('authenticated', 'app.recheck_my_portfolio_ids(public.member_role[])', 'execute')
  and has_function_privilege('authenticated', 'app.lock_my_notification_portfolios()', 'execute')
  and has_function_privilege('authenticated', 'app.document_object_deletable(text)', 'execute')
  and not has_function_privilege('authenticated', 'private.lock_inserted_row_portfolio(text, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.lock_document_sweep_gate(boolean)', 'execute')
  and not has_function_privilege('authenticated', 'private.sweep_orphaned_files(timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'private.before_client_insert_lock_portfolios()', 'execute')
  and not has_function_privilege('authenticated', 'private.before_document_object_delete()', 'execute'),
  'row policies can call the app helpers; the trigger functions, the sweep gate and the sweep are not callable'
);

-- The statement trigger tells a client's own statement from a definer
-- function's by current_user, so it must run as the caller.
select ok(
  (select not p.prosecdef and p.provolatile = 'v' and coalesce(p.proconfig @> array['search_path=""'], false)
   from pg_proc p where p.oid = 'private.before_client_insert_lock_portfolios()'::regprocedure),
  'the insert statement trigger runs as the caller (SECURITY INVOKER) with an empty search_path'
);

-- Every client UPDATE or DELETE policy on a portfolio's rows takes the
-- portfolio key first. Pinned, so a new write policy is reviewed here.
select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relnamespace = 'public'::regnamespace and p.polcmd in ('w', 'd', '*')
     and pg_get_expr(p.polqual, p.polrelid) ~ 'app\.lock_my_(portfolio_ids|notification_portfolios)\('),
  array[
    'documents.documents_delete', 'documents.documents_update',
    'expenses.expenses_delete', 'expenses.expenses_update', 'lease_occupants.lease_occupants_delete',
    'lease_occupants.lease_occupants_update', 'leases.leases_delete', 'leases.leases_update',
    'maintenance_requests.maintenance_requests_delete', 'maintenance_requests.maintenance_requests_update',
    'meter_readings.meter_readings_delete', 'meter_readings.meter_readings_update',
    'notifications.notifications_delete_own', 'notifications.notifications_update_own',
    'portfolios.portfolios_update_owners', 'properties.properties_delete', 'properties.properties_update',
    'tenants.tenants_delete', 'tenants.tenants_update', 'units.units_delete', 'units.units_update',
    'utility_accounts.utility_accounts_delete', 'utility_accounts.utility_accounts_update',
    'utility_bills.utility_bills_delete', 'utility_bills.utility_bills_update'
  ]::text[],
  'these client UPDATE and DELETE policies lock the portfolio key first'
);

select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relnamespace = 'public'::regnamespace and p.polcmd in ('w', 'd', '*')
     and (c.relname = 'portfolios'
          or exists (select 1 from pg_attribute a
                     where a.attrelid = c.oid and a.attname = 'portfolio_id' and not a.attisdropped))
     and pg_get_expr(p.polqual, p.polrelid) !~ 'app\.lock_my_(portfolio_ids|notification_portfolios)\('),
  '{}'::text[],
  'no UPDATE or DELETE policy on a portfolio''s rows skips the portfolio key'
);

-- Every client INSERT policy takes the portfolio key in its WITH CHECK, which
-- runs before the row is inserted and its foreign keys are checked; documents
-- and manual charges, whose BEFORE ROW triggers lock rows earlier still, get
-- the key from a statement trigger instead.
select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relnamespace = 'public'::regnamespace and p.polcmd in ('a', '*')
     and pg_get_expr(p.polwithcheck, p.polrelid) ~ 'app\.lock_my_portfolio_ids\('),
  array[
    'cash_handovers.cash_handovers_insert', 'expenses.expenses_insert', 'lease_occupants.lease_occupants_insert',
    'leases.leases_insert', 'maintenance_requests.maintenance_requests_insert',
    'meter_readings.meter_readings_insert', 'properties.properties_insert', 'reminder_logs.reminder_logs_insert',
    'tenants.tenants_insert', 'units.units_insert', 'utility_accounts.utility_accounts_insert',
    'utility_bills.utility_bills_insert'
  ]::text[],
  'these client INSERT policies lock the portfolio key in their WITH CHECK'
);

select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relnamespace = 'public'::regnamespace and p.polcmd in ('a', '*')
     and exists (select 1 from pg_attribute a
                 where a.attrelid = c.oid and a.attname = 'portfolio_id' and not a.attisdropped)
     and pg_get_expr(p.polwithcheck, p.polrelid) !~ 'app\.lock_my_portfolio_ids\('),
  array['charges.charges_insert', 'documents.documents_insert']::text[],
  'only the document and charge INSERT policies leave the key to a trigger'
);

select is(
  (select coalesce(array_agg(t.tgrelid::regclass::text || ' '
                             || (pg_get_triggerdef(t.oid) ~ 'BEFORE INSERT .* FOR EACH STATEMENT')::text
                             order by t.tgrelid::regclass::text), '{}')
   from pg_trigger t
   where t.tgfoid = 'private.before_client_insert_lock_portfolios()'::regprocedure),
  array['charges true', 'documents true']::text[],
  'documents and charges take the caller''s keys in a BEFORE INSERT statement trigger'
);

select ok(
  (select bool_and(position('app.has_portfolio_role' in p.prosrc) between 1
                     and position('private.lock_inserted_row_portfolio(tg_table_name, new.portfolio_id)' in p.prosrc))
   from pg_proc p
   where p.oid in ('private.before_document_insert()'::regprocedure,
                   'private.before_manual_charge_insert()'::regprocedure)),
  'their row triggers authorise, then take the row''s key through private.lock_inserted_row_portfolio'
);

select ok(
  (select p.prosrc ~ 'mm\.insert_locked_'' \|\| tg_table_name'
          and p.prosrc ~ 'current_user = ''authenticated'''
   from pg_proc p where p.oid = 'private.before_client_insert_lock_portfolios()'::regprocedure)
  and (select p.prosrc ~ 'for key share skip locked'
              and position('for key share;' in p.prosrc) < position('for key share skip locked' in p.prosrc)
       from pg_proc p where p.oid = 'private.lock_inserted_row_portfolio(text, uuid)'::regprocedure),
  'the statement trigger tells the row triggers what it locked; they skip-lock only a portfolio it did not lock'
);

select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where (pg_get_expr(p.polqual, p.polrelid) ~ 'app\.lock_my_'
          or pg_get_expr(p.polwithcheck, p.polrelid) ~ 'app\.lock_my_')
     and p.polroles <> array['authenticated'::regrole::oid]),
  '{}'::text[],
  'the locking policies apply to signed-in clients only (definer functions, jobs and the service role bypass them)'
);

select is(
  (select coalesce(array_agg(c.relname || '.' || p.polname order by c.relname || '.' || p.polname), '{}')
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where p.polcmd in ('w', '*') and pg_get_expr(p.polwithcheck, p.polrelid) ~ 'app\.lock_my_'),
  '{}'::text[],
  'no UPDATE policy''s WITH CHECK locks anything (it runs after the row is locked)'
);

-- An INSERT ... ON CONFLICT DO UPDATE locks the conflicting row before the
-- UPDATE policy runs. The Data API's upsert sets every inserted column, and a
-- row of these tables cannot be inserted without portfolio_id.
select is(
  (select coalesce(array_agg(c.relname::text order by c.relname::text), '{}')
   from pg_class c
   join pg_attribute a on a.attrelid = c.oid and a.attname = 'portfolio_id' and not a.attisdropped
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
     and has_table_privilege('authenticated', c.oid, 'insert')
     and (has_column_privilege('authenticated', c.oid, 'portfolio_id', 'update')
          or not a.attnotnull or a.atthasdef)),
  '{}'::text[],
  'clients must insert portfolio_id and may never update it, so no client upsert can reach an UPDATE'
);

select ok(
  (select pg_get_expr(p.polqual, p.polrelid) ~ 'app\.document_object_deletable\(name\)'
   from pg_policy p where p.polrelid = 'storage.objects'::regclass and p.polname = 'documents_objects_delete'),
  'the Storage delete policy asks app.document_object_deletable'
);

select is(
  (select pg_get_triggerdef(t.oid) ~ 'AFTER INSERT ON public\.documents REFERENCING NEW TABLE AS new_documents FOR EACH STATEMENT'
   from pg_trigger t where t.tgrelid = 'public.documents'::regclass and t.tgname = 'documents_after_insert_check_file'),
  true,
  'the document insert''s file check runs once per statement, over all its rows'
);

select ok(
  (select position('private.lock_document_sweep_gate(false)' in p.prosrc) between 1
          and position('for key share of o' in p.prosrc)
     and position('order by o.name collate "C"' in p.prosrc) between 1 and position('for key share of o' in p.prosrc)
     and position('for key share of o' in p.prosrc) < position('private.storage_cleanup_queue' in p.prosrc)
   from pg_proc p where p.oid = 'private.after_document_insert_check_file()'::regprocedure),
  'it takes the sweep gate, then the files'' rows (key share, in the Storage API''s name order), then reads the queue'
);

select ok(
  (select p.prosrc ~ 'private\.lock_document_sweep_gate\(true\)'
          and p.prosrc !~ 'lock_document_sweep_gate\(false\)'
          and position('private.lock_document_sweep_gate(true)' in p.prosrc)
              < position('from public.documents d where d.storage_path = o.name' in p.prosrc)
   from pg_proc p where p.oid = 'private.sweep_orphaned_files(timestamptz)'::regprocedure)
  and (select p.prosrc ~ 'private\.sweep_orphaned_files\(p_now\)' and p.prosrc !~ 'lock_document_sweep_gate'
       from pg_proc p where p.oid = 'private.enqueue_orphaned_storage(timestamptz)'::regprocedure),
  'the file sweep only tries the gate (it never waits for it) and reads documents after it'
);

select ok(
  (select position('app.my_portfolio_ids' in p.prosrc) between 1 and position('for update of o skip locked' in p.prosrc)
     and position('public.documents' in p.prosrc) > position('for update of o skip locked' in p.prosrc)
   from pg_proc p where p.oid = 'app.document_object_deletable(text)'::regprocedure),
  'the delete helper authorises, then locks the object row without waiting, then reads the documents'
);

select is(
  (select pg_get_triggerdef(t.oid) from pg_trigger t
   where t.tgrelid = 'storage.objects'::regclass and t.tgname = 'documents_objects_keep_referenced'),
  'CREATE TRIGGER documents_objects_keep_referenced BEFORE DELETE ON storage.objects FOR EACH ROW '
    || 'WHEN ((old.bucket_id = ''documents''::text)) EXECUTE FUNCTION private.before_document_object_delete()',
  'every DELETE of a documents-bucket object runs the keep-referenced row trigger, whoever issues it'
);

select ok(
  has_table_privilege((select p.proowner::regrole::text from pg_proc p
                       where p.oid = 'app.document_object_deletable(text)'::regprocedure),
                      'storage.objects', 'update')
  and (select r.rolsuper or r.rolbypassrls from pg_roles r
       where r.oid = (select p.proowner from pg_proc p where p.oid = 'app.document_object_deletable(text)'::regprocedure)),
  'the functions'' owner may lock storage.objects rows (UPDATE privilege, row security bypassed)'
);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_user('viewer@example.com') as viewer \gset
select tests.create_user('outsider@example.com') as outsider \gset
select tests.create_portfolio(:'owner', 'Main') as pid \gset
select tests.create_portfolio(:'owner', 'Side') as side \gset
select tests.create_portfolio(:'outsider', 'Elsewhere') as elsewhere \gset
select tests.add_member(:'pid', :'manager', 'manager');
select tests.add_member(:'side', :'manager', 'viewer');
select tests.add_member(:'pid', :'viewer', 'viewer');
select tests.create_rental(:'pid') as rental \gset
select tests.create_rental(:'pid', 'punjab', 'Spare room') as spare \gset
select tests.create_lease(:'pid', :'rental', '2026-10-01', 40000) as lease \gset
insert into public.tenants (portfolio_id, full_name) select :'pid', 'Bulk ' || g from generate_series(1, 3) g;
-- The third one is in a portfolio the manager does not (any longer) belong to.
insert into public.notifications (portfolio_id, user_id, kind, dedupe_key)
values (:'pid', :'manager', 'rent_due_soon', 'test-1'), (:'side', :'manager', 'rent_due_soon', 'test-2'),
       (:'elsewhere', :'manager', 'rent_due_soon', 'test-3');

-- ---------------------------------------------------------------------------
-- The portfolio key (M1 and the audit's paths)
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'manager');
select is(
  app.lock_my_portfolio_ids('{owner,manager}'),
  array[:'pid']::uuid[],
  'a manager locks (and may write) the portfolios where the role allows it, not those where they only view'
);
select is(
  app.lock_my_notification_portfolios() @> array[:'pid', :'side']::uuid[]
  and cardinality(app.lock_my_notification_portfolios()) = 2,
  true,
  'notification writes lock the portfolios of the caller''s own notifications, only where they are a member'
);
select tests.authenticate_as(:'viewer');
select is(
  app.lock_my_portfolio_ids('{owner,manager}'), '{}'::uuid[],
  'a viewer locks nothing and may write nothing'
);
select tests.clear_authentication();
select is(
  app.lock_my_portfolio_ids('{owner,manager}') || app.lock_my_notification_portfolios(), '{}'::uuid[],
  'without a signed-in user (a job) the helpers lock nothing'
);

-- One initplan per statement: the helper runs once, before the first row.
select tests.clear_authentication();
select tests.calls('app.lock_my_portfolio_ids') as lock_before,
       tests.calls('app.recheck_my_portfolio_ids') as recheck_before \gset
select tests.authenticate_as(:'manager');
update public.leases set notes = 'Repainted', security_deposit = 80000 where id = :'lease';
select tests.clear_authentication();
select is(
  array[tests.calls('app.lock_my_portfolio_ids') - :lock_before,
        tests.calls('app.recheck_my_portfolio_ids') - :recheck_before],
  array[1, 1]::bigint[],
  'a client UPDATE of a lease locks the portfolio key once (USING) and re-reads once (WITH CHECK)'
);
select is(
  (select amount from public.charges
   where lease_id = :'lease' and kind = 'security_deposit' and source = 'deposit' and voided_at is null),
  80000.00::numeric,
  'the deposit trigger (M1) still records the deposit charge'
);

select tests.calls('app.lock_my_portfolio_ids') as lock_before \gset
select tests.authenticate_as(:'owner');
delete from public.units where id = (:'spare'::jsonb ->> 'unit_id')::uuid;
select tests.clear_authentication();
select is(
  tests.calls('app.lock_my_portfolio_ids') - :lock_before, 1::bigint,
  'a client DELETE locks the portfolio key once'
);

-- Several rows in one statement: still once (the scalar subquery makes the
-- helper an initplan; without it, it would run for every row).
select tests.calls('app.lock_my_portfolio_ids') as lock_before,
       tests.calls('app.recheck_my_portfolio_ids') as recheck_before \gset
select tests.authenticate_as(:'owner');
update public.tenants set notes = 'Reviewed' where portfolio_id = :'pid';
delete from public.tenants where portfolio_id = :'pid' and full_name like 'Bulk %';
select tests.clear_authentication();
select is(
  array[tests.calls('app.lock_my_portfolio_ids') - :lock_before,
        tests.calls('app.recheck_my_portfolio_ids') - :recheck_before],
  array[2, 1]::bigint[],
  'a multi-row UPDATE and a multi-row DELETE each lock once (and the UPDATE re-reads once)'
);
select is(
  (select count(*) from public.tenants where portfolio_id = :'pid' and full_name like 'Bulk %'),
  0::bigint,
  'and the DELETE removed all of its rows'
);

-- Client INSERTs: the key comes first, once per statement, whatever the
-- number of rows.
select tests.calls('app.lock_my_portfolio_ids') as lock_before \gset
select tests.authenticate_as(:'manager');
insert into public.tenants (portfolio_id, full_name) values (:'pid', 'First applicant'), (:'pid', 'Second applicant');
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'lease', 'other', '2026-11-10', 1500, 'Plumber'), (:'pid', :'lease', 'other', '2026-11-12', 500, 'Key');
select tests.clear_authentication();
select is(
  tests.calls('app.lock_my_portfolio_ids') - :lock_before, 2::bigint,
  'a client INSERT (policy or statement trigger) locks the portfolio keys once per statement'
);
select is(
  current_setting('mm.insert_locked_charges', true),
  (array[:'pid']::uuid[])::text,
  'the charge statement trigger tells its row triggers which portfolios it locked'
);
-- A SECURITY DEFINER function's insert runs as the function's owner, even
-- with a signed-in caller (here a lease's rent charges, written by the lease
-- trigger): the statement trigger locks nothing, so the rows wait for the key.
select tests.authenticate_as(:'owner');
select tests.create_rental(:'pid', 'punjab', 'Annex') as annex \gset
select tests.create_lease(:'pid', :'annex', '2026-10-01', 30000) as annex_lease \gset
select tests.clear_authentication();
select is(
  array[current_setting('mm.insert_locked_charges', true),
        ((select count(*) from public.charges where lease_id = :'annex_lease') > 0)::text],
  array['', 'true'],
  'a definer function''s insert into charges tells its row triggers it locked nothing'
);
select tests.authenticate_as(:'outsider');
select throws_ok(
  format($f$insert into public.tenants (portfolio_id, full_name) values (%L, 'Intruder')$f$, :'pid'),
  '42501', null,
  'an insert into another landlord''s portfolio is still refused by the policy'
);
select throws_ok(
  format($f$insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
            values (%L, %L, 'other', '2026-11-10', 100, 'Intruder')$f$, :'pid', :'lease'),
  '42501', 'forbidden',
  'and a manual charge by the row trigger'
);
select tests.clear_authentication();

select tests.calls('app.lock_my_notification_portfolios') as notes_before \gset
select tests.authenticate_as(:'manager');
select is(public.mark_notifications_read(), 2, 'mark_notifications_read (SECURITY INVOKER) still marks the caller''s notifications');
select tests.clear_authentication();
select is(
  tests.calls('app.lock_my_notification_portfolios') - :notes_before, 1::bigint,
  'and locks the account and the notifications'' portfolios once'
);

-- Definer functions, jobs and the service role bypass row security, so they
-- keep their own lock order and never call the helpers.
select tests.calls('app.lock_my_portfolio_ids') as lock_before \gset
select tests.authenticate_as_service_role();
update public.leases set notes = 'Checked by support' where id = :'lease';
insert into public.tenants (portfolio_id, full_name) values (:'pid', 'Added by support');
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
values (:'pid', :'lease', 'other', '2026-11-10', 100, 'Added by support');
select tests.authenticate_as(:'owner');
select public.change_rent(:'lease', '2026-12-01', 42000) is not null as rent_changed \gset
select tests.clear_authentication();
select private.run_daily_jobs('2026-11-04', 100) is not null as job_ran \gset
select is(
  tests.calls('app.lock_my_portfolio_ids') - :lock_before, 0::bigint,
  'the service role (updates and inserts), a write RPC and the daily job never call the client lock helper'
);

-- The Data API's upsert: refused by privileges before it touches a row.
select tests.authenticate_as(:'manager');
select throws_ok(
  format(
    $f$insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, monthly_rent, notes)
       values (%L, %L, %L, %L, '2026-10-01', 40000, 'upsert')
       on conflict (id) do update set id = excluded.id, portfolio_id = excluded.portfolio_id,
         unit_id = excluded.unit_id, tenant_id = excluded.tenant_id, start_date = excluded.start_date,
         monthly_rent = excluded.monthly_rent, notes = excluded.notes$f$,
    :'lease', :'pid', :'rental'::jsonb ->> 'unit_id', :'rental'::jsonb ->> 'tenant_id'
  ),
  '42501', null,
  'an upsert shaped like the Data API''s is refused by privileges'
);
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- The file's storage.objects row (S1) and the sweep gate (S2)
-- ---------------------------------------------------------------------------

select format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid()) as attached \gset
select format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid()) as loose \gset
select format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid()) as old_file \gset
-- Two old files (the sweep looks at files older than a day) and a new one.
insert into storage.objects (bucket_id, name, created_at)
values ('documents', :'attached', now() - interval '2 days'), ('documents', :'old_file', now() - interval '2 days'),
       ('documents', :'loose', now());

select tests.advisory_locks() as advisory_before \gset
select ok(not tests.file_row_locked(:'attached'), 'before the insert, nothing locks the file''s row');
select tests.authenticate_as(:'manager');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values (:'pid', 'tenant', (:'rental'::jsonb ->> 'tenant_id')::uuid, :'attached', 'cnic.jpg', 'image/jpeg', 1000);
select ok(tests.file_row_locked(:'attached'), 'a document insert locks its file''s storage.objects row until it commits');
select is(tests.gate_modes(), array['ShareLock'], 'and the sweep gate, shared');
select is(tests.advisory_locks() - :advisory_before, 1::bigint, 'and no advisory lock for the file itself');
select throws_ok(
  format(
    $f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
       values (%L, 'tenant', %L, %L, 'gone.jpg', 'image/jpeg', 1000)$f$,
    :'pid', :'rental'::jsonb ->> 'tenant_id', format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid())
  ),
  '22023', 'document_file_missing',
  'a document whose file was never uploaded is refused'
);

-- The Storage API deletes as the user (or asks as the user in a probe),
-- allowing deletes on storage tables.
select set_config('storage.allow_delete_query', 'true', true) as allow_delete \gset
select tests.authenticate_as(:'outsider');
select is_empty(
  format($f$delete from storage.objects where bucket_id = 'documents' and name = %L returning name$f$, :'loose'),
  'another landlord cannot delete the file'
);
select ok(not tests.file_row_locked(:'loose'), 'and their attempt locks nothing (authorised before locking)');
select tests.authenticate_as(:'owner');
select is_empty(
  format($f$delete from storage.objects where bucket_id = 'documents' and name = %L returning name$f$, :'attached'),
  'a file a document references cannot be deleted'
);
select results_eq(
  format($f$delete from storage.objects where bucket_id = 'documents' and name = %L returning name$f$, :'loose'),
  array[:'loose'],
  'an unreferenced file of the owner''s portfolio can be deleted, its row locked by this request'
);
select is(
  tests.advisory_locks() - :advisory_before, 1::bigint,
  'the deletes took no advisory lock (still only the insert''s sweep gate)'
);
select tests.clear_authentication();

-- Deletes that row security does not see: the Storage API's own delete as
-- superuser (from v1.81, after its probe), and the service role's (the
-- cleaner, an admin). The trigger keeps a referenced file; others go.
select format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid()) as spare \gset
insert into storage.objects (bucket_id, name) values ('documents', :'spare');
select is_empty(
  format($f$delete from storage.objects where bucket_id = 'documents' and name = %L returning name$f$, :'attached'),
  'the Storage API''s superuser delete skips a file a document references'
);
select tests.authenticate_as_service_role();
select is_empty(
  format($f$delete from storage.objects where bucket_id = 'documents' and name = %L returning name$f$, :'attached'),
  'so does a service-role delete'
);
select results_eq(
  format($f$delete from storage.objects where bucket_id = 'documents' and name in (%L, %L) returning name$f$,
         :'attached', :'spare'),
  array[:'spare'],
  'a batch delete removes the unreferenced file and keeps the referenced one'
);
select tests.clear_authentication();
select is(
  (select count(*) from storage.objects where bucket_id = 'documents' and name = :'attached'),
  1::bigint,
  'the referenced file is still there'
);

-- Fifty more old files without a document row: the sweep's locks must not
-- grow with them (a lock per file filled the shared lock table).
insert into storage.objects (bucket_id, name, created_at)
select 'documents', format('%s/tenant/%s/%s.jpg', :'pid', :'rental'::jsonb ->> 'tenant_id', gen_random_uuid()),
       now() - interval '2 days'
from generate_series(1, 50);
select tests.advisory_locks() as advisory_before \gset
select ok(private.enqueue_orphaned_storage(now()) >= 51, 'the sweep queues the old unreferenced files');
select ok(
  exists (select 1 from private.storage_cleanup_queue where path = :'old_file')
  and not exists (select 1 from private.storage_cleanup_queue where path = :'attached'),
  'only the unreferenced file, never the referenced one'
);
select is(
  tests.gate_modes(), array['ExclusiveLock', 'ShareLock'],
  'the sweep holds the gate exclusively until the job commits (this session''s insert above holds it shared)'
);
select is(tests.advisory_locks() - :advisory_before, 1::bigint, 'and only the gate: one lock for 51 files');
select is(
  (select (result ->> 'queued')::integer >= 51 from private.job_runs
   where job_name = 'orphaned_file_sweep' and run_on = app.today_pkt()),
  true,
  'a sweep that got the gate records the day (orphaned_file_sweep)'
);
select is(private.enqueue_orphaned_storage(now()), 0, 'a second sweep queues nothing new');

-- A sweep that found the gate busy leaves no record; the next run of the
-- daily job (every 10 minutes) then sweeps again. Simulated here by removing
-- the record after the day's once-a-day work has run.
select private.run_daily_jobs(app.today_pkt(), 100) is not null as day_done \gset
delete from private.job_runs where job_name = 'orphaned_file_sweep';
select tests.calls('private.sweep_orphaned_files') as sweeps_before \gset
select private.run_daily_jobs(app.today_pkt(), 100) is not null as day_retried \gset
select private.run_daily_jobs(app.today_pkt(), 100) is not null as day_quiet \gset
select is(
  array[tests.calls('private.sweep_orphaned_files') - :sweeps_before,
        (select count(*) from private.job_runs where job_name = 'orphaned_file_sweep' and run_on = app.today_pkt())],
  array[1, 1]::bigint[],
  'a later run of the daily job sweeps again until a sweep is recorded, then stops'
);

select tests.authenticate_as(:'manager');
select throws_ok(
  format(
    $f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
       values (%L, 'tenant', %L, %L, 'old.jpg', 'image/jpeg', 1000)$f$,
    :'pid', :'rental'::jsonb ->> 'tenant_id', :'old_file'
  ),
  '22023', 'document_file_pending_deletion',
  'a document cannot be attached to a file the sweep queued'
);
select tests.clear_authentication();

select * from finish();
rollback;
