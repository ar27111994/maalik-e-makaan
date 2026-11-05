-- ============================================================================
-- Concurrency findings S1, S2 and M1 (formal/tla/StorageCleanup and
-- formal/tla/Membership), and every other client write that broke the lock
-- order the same way as M1.
--
-- The global lock order (20261105072426_membership_deletion_storage.sql):
--
--   1. the account      2. the portfolio      3. the lease      4. other rows
--
-- Deletions (delete_portfolio, admin_delete_account_data) and membership
-- changes lock the portfolio FOR UPDATE and then cascade through its rows in
-- foreign-key trigger order. A client's plain UPDATE or DELETE used to lock its
-- own row first, so it could hold a row the cascade needs while it waited for
-- something the deletion already held:
--
--   M1  update leases set security_deposit: the trigger inserts a charge and
--       payment allocations, whose foreign-key checks need the portfolio key
--       (a deletion that lost the deadlock three times failed);
--   and, found by the audit in the same way (each a cycle with the cascade):
--       a multi-row UPDATE or DELETE (rows in scan order, the cascade in its
--       order); an UPDATE whose foreign-key check needs a parent row the
--       cascade deleted earlier (expenses, maintenance requests, utility
--       accounts); a DELETE whose own cascade needs rows the deletion holds
--       (leases, properties, units ...); a multi-row UPDATE of portfolios
--       (scan order against admin_delete_account_data's id order); a
--       multi-row UPDATE or DELETE of notifications (against the cascade and
--       the account deletion's own notification delete, which is not
--       retried); an INSERT whose foreign keys are checked in another order
--       than the migrations created them (a restored database checks a lease,
--       utility account or maintenance request before the portfolio); and an
--       INSERT of rows of several portfolios (row order against the id order
--       of admin_delete_account_data).
--
-- Part 1 makes every one of them take the portfolio key first: the UPDATE and
-- DELETE row policies, and the INSERT policies' WITH CHECK, get the set of
-- writable portfolios from a helper that locks them (FOR KEY SHARE, id order)
-- and then authorises again. A policy's initplan runs when the statement
-- evaluates its first row, before the statement locks any row, and the rows
-- it lets through are exactly the portfolios it locked. Documents and manual
-- charges lock rows in BEFORE ROW triggers, which run before any WITH CHECK,
-- so a statement trigger takes their keys first. Policies apply only to the
-- authenticated role, and the statement trigger acts only for it: SECURITY
-- DEFINER functions, jobs and the service role are unchanged.
--
-- The price (see lock_my_portfolio_ids; the measurements are in
-- docs/architecture/permissions.md, "Concurrency"): every client write locks
-- all the portfolios where the caller has the role, so it costs more the
-- more portfolios the caller belongs to (WAL per one-row update on
-- PostgreSQL 16: 0.8 kB before; 1.9 kB at 20 portfolios, 12.1 kB at 200),
-- writers sharing portfolios create multixacts, and a write waits while any
-- of those portfolios is being deleted or its members changed, also when it
-- writes another portfolio. In turn a deletion or membership change waits
-- for every write in flight by any member of the portfolio, and writes that
-- arrive while it waits go first.
--
--   S1  a user's Storage DELETE of a file and a document INSERT for it each
--       checked the other with a snapshot, so both could commit and leave a
--       document row without its file;
--   S2  the daily sweep queued an old file "without a document row" while a
--       document INSERT for it checked "not queued": the cleaner then deleted
--       a file a committed document row referenced.
--
-- Part 2 serialises a document INSERT and every delete of the same file on
-- the file's storage.objects row (S1). The insert locks the row FOR KEY
-- SHARE before it checks the file; every DELETE of the row must lock it
-- first, and a BEFORE DELETE trigger on storage.objects then reads
-- documents again and keeps a file a document references. The trigger runs
-- in the statement that deletes, whoever issues it: the user (Storage API up
-- to v1.80), the Storage API as superuser after a permission probe in a
-- rolled-back savepoint (from v1.81; the hosted project runs a later one),
-- the service role, or SQL. A lock or check made only in the delete policy
-- protected nothing in the probe flow: the rollback ends the probe's locks,
-- and the superuser's delete does not consult row security. Document
-- INSERTs and the sweep share one shared/exclusive advisory lock, the sweep
-- gate (S2); each re-reads after taking its lock. Neither side takes a
-- lock-table entry per file. Part 3 lets the daily job retry a sweep that
-- found the gate busy.
-- ============================================================================

-- A migration waits at most 5 s for a table lock (ALTER POLICY takes ACCESS
-- EXCLUSIVE for a moment) instead of queueing the app's traffic behind it;
-- `set local` keeps both settings inside this migration's transaction.
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- 1. Client writes take the portfolio key first (M1 and the audit's paths)
-- ---------------------------------------------------------------------------

-- The portfolios the caller may write with one of p_roles, locked FOR KEY
-- SHARE in id order (the order deletions use), then authorised again with a
-- fresh snapshot: a membership change or deletion that held the portfolio
-- while this waited is seen, and its portfolio dropped. KEY SHARE conflicts
-- only with FOR UPDATE, which only deletions and membership changes take, so
-- clients never wait for each other here. Returns only portfolios that are
-- both locked and still authorised; a portfolio joined meanwhile is left out
-- (the statement runs as if it came first).
--
-- It locks every such portfolio, not only those the statement writes: the
-- initplan runs before any row is known, and a statement that writes rows of
-- several portfolios must take all their keys in id order before its first
-- row. So a client write waits while any portfolio where the caller has the
-- role is being deleted or its members changed (FOR UPDATE), even when it
-- writes another one. That is the price of a lock order no statement can
-- break; nothing else waits on these keys, and all of them are taken before
-- any row, so the wait cannot be part of a deadlock.
--
-- What it costs, beyond that wait (measured on PostgreSQL 16; details in
-- docs/architecture/permissions.md, "Concurrency"):
--   * each locked portfolio row is written: about 56 bytes of WAL per
--     portfolio per write, 12.1 kB for a caller in 200 portfolios;
--   * writers sharing portfolios create multixacts (tool/db/stress_test.sh
--     reports them for managers of 1 and of 30 portfolios); watch
--     mxid_age(datminmxid) (docs/operations.md);
--   * a deletion holds its keys for its whole cascade, so its members'
--     writes in their other portfolios wait as long (1.25 s behind a 1.5 s
--     lock, 65 ms before this migration);
--   * a FOR UPDATE that waits does not stop new key-share requests, so a
--     membership change waits until no write of a member holds the key
--     (update_member_role under 8 clients' writes: median 0.08 s -> 0.22 s,
--     max 0.14 s -> 1.2 s).
-- The membership functions and delete_portfolio keep waiting rather than
-- give up: with lock_timeout 1 s or 0.2 s and three tries, a role change
-- behind one 4 s request failed where waiting succeeded after 3.8 s, and
-- under load the tries did not lower its latency. Revisit this design
-- before users hold hundreds of portfolios each.
create or replace function app.lock_my_portfolio_ids(p_roles public.member_role[])
returns uuid[]
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_locked uuid[];
begin
  if v_uid is null then
    return '{}'::uuid[];
  end if;

  select coalesce(array_agg(l.id), '{}'::uuid[]) into v_locked
  from (
    select p.id
    from public.portfolios p
    where p.id = any (app.my_portfolio_ids(p_roles))
    order by p.id
    for key share
  ) l;

  return array(
    select m.portfolio_id
    from public.portfolio_members m
    where m.user_id = v_uid
      and m.role = any (p_roles)
      and m.portfolio_id = any (v_locked)
  );
end
$$;

comment on function app.lock_my_portfolio_ids(public.member_role[]) is
  'Row policies of client UPDATE/DELETE: locks the writable portfolios (key share, id order), then authorises again.';

-- The WITH CHECK of the same UPDATE policies: the caller's portfolios read
-- with a fresh snapshot, without locks (it can run after a row is locked).
-- It always includes what lock_my_portfolio_ids returned: removing a
-- membership needs the portfolio FOR UPDATE, which the statement's key share
-- blocks until it commits.
create or replace function app.recheck_my_portfolio_ids(p_roles public.member_role[])
returns uuid[]
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  return app.my_portfolio_ids(p_roles);
end
$$;

comment on function app.recheck_my_portfolio_ids(public.member_role[]) is
  'WITH CHECK of client UPDATE policies: the caller''s portfolios now (fresh snapshot, no locks).';

-- Notifications are the caller's own, so their policies are not portfolio
-- based. The account key comes first (admin_delete_account_data holds it FOR
-- UPDATE and deletes the user's notifications outside its retry), then the
-- key of every portfolio the caller has notifications for and still belongs
-- to, in id order. A member who left keeps their old notifications, but
-- notifications_select_own hides them, so no statement can write them and
-- their portfolios are not locked. portfolio_id never changes, so every row
-- the statement can see belongs to one of the locked portfolios, unless its
-- portfolio was deleted (then the row is gone too).
create or replace function app.lock_my_notification_portfolios()
returns uuid[]
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    return '{}'::uuid[];
  end if;

  perform 1 from public.profiles p where p.id = v_uid for key share;
  return array(
    select p.id
    from public.portfolios p
    where p.id in (select n.portfolio_id from public.notifications n where n.user_id = v_uid)
      and p.id = any (app.my_portfolio_ids())
    order by p.id
    for key share
  );
end
$$;

comment on function app.lock_my_notification_portfolios() is
  'Row policies of client notification writes: locks the account, then the portfolios of the caller''s notifications.';

revoke all on function app.lock_my_portfolio_ids(public.member_role[]) from public, anon;
revoke all on function app.recheck_my_portfolio_ids(public.member_role[]) from public, anon;
revoke all on function app.lock_my_notification_portfolios() from public, anon;
-- Row policies run as the querying role, so it needs EXECUTE. The app schema
-- is not exposed through the Data API, so clients cannot call these directly.
grant execute on function app.lock_my_portfolio_ids(public.member_role[]) to authenticated;
grant execute on function app.recheck_my_portfolio_ids(public.member_role[]) to authenticated;
grant execute on function app.lock_my_notification_portfolios() to authenticated;

-- The policies keep their roles; only the source of the portfolio set
-- changes. USING is wrapped in a scalar subquery, so it is one initplan per
-- statement, evaluated before the first row is returned to the UPDATE/DELETE.
--
-- An INSERT ... ON CONFLICT DO UPDATE would lock the conflicting row before
-- evaluating the UPDATE policy. No client can run one: the Data API's upsert
-- sets every inserted column, every one of these tables needs portfolio_id
-- (NOT NULL, no default), and no client may UPDATE portfolio_id, so the
-- statement fails its privilege check before it touches a row
-- (15_concurrency_findings.test.sql checks this for every table).

-- M1 (the deposit trigger), the due-day trigger, multi-row updates, and the
-- lease delete's cascade.
alter policy leases_update on public.leases
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy leases_delete on public.leases
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner}'::public.member_role[]))::uuid[]));

alter policy charges_update on public.charges
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));

alter policy documents_update on public.documents
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy documents_delete on public.documents
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

-- Expenses: an UPDATE of property_id, unit_id or maintenance_request_id
-- checks the new parent, which the cascade may have deleted already.
alter policy expenses_update on public.expenses
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy expenses_delete on public.expenses
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

alter policy lease_occupants_update on public.lease_occupants
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy lease_occupants_delete on public.lease_occupants
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

-- Maintenance requests: an UPDATE of unit_id or lease_id checks the new
-- parent; a DELETE checks the expenses that reference the request.
alter policy maintenance_requests_update on public.maintenance_requests
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy maintenance_requests_delete on public.maintenance_requests
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

alter policy meter_readings_update on public.meter_readings
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy meter_readings_delete on public.meter_readings
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

-- Properties, units and tenants: a DELETE cascades (units, maintenance
-- requests, utility accounts, readings, bills, charges set null, documents)
-- and checks the leases and expenses that reference the row.
alter policy properties_update on public.properties
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy properties_delete on public.properties
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner}'::public.member_role[]))::uuid[]));

alter policy tenants_update on public.tenants
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy tenants_delete on public.tenants
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner}'::public.member_role[]))::uuid[]));

alter policy units_update on public.units
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy units_delete on public.units
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner}'::public.member_role[]))::uuid[]));

-- Utility accounts: an UPDATE of unit_id checks the new unit.
alter policy utility_accounts_update on public.utility_accounts
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy utility_accounts_delete on public.utility_accounts
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner}'::public.member_role[]))::uuid[]));

alter policy utility_bills_update on public.utility_bills
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.recheck_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy utility_bills_delete on public.utility_bills
  using (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));

-- Portfolios: a multi-row UPDATE locked them in scan order, against the id
-- order of admin_delete_account_data. The key share comes first, in id order;
-- the UPDATE then upgrades its own rows to NO KEY UPDATE, which never
-- conflicts with another client's key share.
alter policy portfolios_update_owners on public.portfolios
  using (id = any ((select app.lock_my_portfolio_ids(array['owner']::public.member_role[]))::uuid[]))
  with check (id = any ((select app.recheck_my_portfolio_ids(array['owner']::public.member_role[]))::uuid[]));

alter policy notifications_update_own on public.notifications
  using (
    user_id = (select auth.uid())
    and portfolio_id = any ((select app.lock_my_notification_portfolios())::uuid[])
  );
alter policy notifications_delete_own on public.notifications
  using (
    user_id = (select auth.uid())
    and portfolio_id = any ((select app.lock_my_notification_portfolios())::uuid[])
  );

-- Client INSERTs. A row's foreign keys are checked by AFTER ROW triggers in
-- trigger-name order, which is the order the constraints were created in.
-- The migrations created every portfolio_id key first, but pg_dump re-creates
-- foreign keys by constraint name, so a restored database checks a lease,
-- utility account or maintenance request (key share) before the portfolio
-- (lease_occupants, maintenance_requests, meter_readings, reminder_logs,
-- expenses, utility_bills): the insert held a row the deletion's cascade
-- needed while it waited for the portfolio the deletion held. And an INSERT of rows of two
-- portfolios checked their keys in row order, against the id order of
-- admin_delete_account_data, in any database. The INSERT policies' WITH
-- CHECK now gets its portfolios from the locking helper: its initplan runs at
-- the first row's check, after that row's BEFORE ROW triggers (on these
-- tables only leases has one, and it locks nothing) and before any row is
-- inserted or any foreign key checked.
alter policy cash_handovers_insert on public.cash_handovers
  with check (
    portfolio_id = any ((select app.lock_my_portfolio_ids(
      '{owner,manager,accountant}'::public.member_role[]))::uuid[])
    and (
      from_user_id = (select auth.uid())
      or portfolio_id = any ((select app.recheck_my_portfolio_ids('{owner}'::public.member_role[]))::uuid[])
    )
  );
alter policy expenses_insert on public.expenses
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy lease_occupants_insert on public.lease_occupants
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy leases_insert on public.leases
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy maintenance_requests_insert on public.maintenance_requests
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy meter_readings_insert on public.meter_readings
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy properties_insert on public.properties
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy reminder_logs_insert on public.reminder_logs
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));
alter policy tenants_insert on public.tenants
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy units_insert on public.units
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy utility_accounts_insert on public.utility_accounts
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager}'::public.member_role[]))::uuid[]));
alter policy utility_bills_insert on public.utility_bills
  with check (portfolio_id = any ((select app.lock_my_portfolio_ids(
    '{owner,manager,accountant}'::public.member_role[]))::uuid[]));

-- Documents and manual charges: their BEFORE ROW triggers lock the row's
-- portfolio and then its entity or lease, and BEFORE ROW triggers run before
-- any WITH CHECK, so a policy would lock too late. A statement trigger takes
-- the caller's keys first (id order), before any row, so a multi-row insert
-- never takes a portfolio key after an entity or lease. The trigger runs as
-- the caller and acts only for a client's own statement (current_user
-- authenticated): an insert by a SECURITY DEFINER function runs as its owner,
-- and those functions lock their portfolio themselves.
--
-- It also tells the row triggers, through the transaction-local setting
-- mm.insert_locked_<table>, which portfolios it locked: '' when it locked
-- nothing (not a client's statement), otherwise the locked ids. Every INSERT
-- on the table runs this trigger before its first row, so the row triggers
-- always read the value of their own statement, never one a previous
-- statement left behind. (No trigger on documents or charges inserts into
-- them, so no nested statement overwrites it while the rows run.)
create or replace function private.before_client_insert_lock_portfolios()
returns trigger
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_locked text := '';
begin
  if current_user = 'authenticated' then
    v_locked := app.lock_my_portfolio_ids(tg_argv[0]::public.member_role[])::text;
  end if;
  perform pg_catalog.set_config('mm.insert_locked_' || tg_table_name, v_locked, true);
  return null;
end
$$;

comment on function private.before_client_insert_lock_portfolios() is
  'Statement trigger of client document and manual charge inserts: the caller''s portfolio keys before any row lock.';

-- The row triggers' portfolio key, after they have authorised the row:
--   * not a client's own statement (a SECURITY DEFINER function, a job, the
--     service role): wait for the key, as before;
--   * a client's statement, and the statement trigger locked this portfolio:
--     take it again, which returns at once (this transaction holds it);
--   * a client's statement and a portfolio the statement trigger did not
--     lock (joined since): take it without waiting; if a deletion or a
--     membership change holds it, refuse the row (the statement runs as if
--     it came first) instead of waiting out of the id order.
create or replace function private.lock_inserted_row_portfolio(p_table text, p_portfolio_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_locked text := pg_catalog.current_setting('mm.insert_locked_' || p_table, true);
begin
  if coalesce(v_locked, '') = '' or p_portfolio_id = any (v_locked::uuid[]) then
    perform 1 from public.portfolios p where p.id = p_portfolio_id for key share;
  else
    perform 1 from public.portfolios p where p.id = p_portfolio_id for key share skip locked;
    if not found then
      perform app.forbid();
    end if;
  end if;
end
$$;

comment on function private.lock_inserted_row_portfolio(text, uuid) is
  'Row triggers of document and manual charge inserts: the row''s portfolio key, in the statement trigger''s order.';

revoke all on function private.lock_inserted_row_portfolio(text, uuid) from public, anon, authenticated;

revoke all on function private.before_client_insert_lock_portfolios() from public, anon, authenticated;

create trigger documents_before_insert_lock_portfolios
  before insert on public.documents
  for each statement
  execute function private.before_client_insert_lock_portfolios('{owner,manager,accountant}');

create trigger charges_before_insert_lock_portfolios
  before insert on public.charges
  for each statement
  execute function private.before_client_insert_lock_portfolios('{owner,manager,accountant}');

-- Checks a new document row before it is written (latest, now with the
-- statement trigger above):
--   * the caller may write documents in the portfolio (checked first, so a
--     non-member's insert never locks or probes another landlord's rows
--     before the row policy refuses it);
--   * the portfolio key (private.lock_inserted_row_portfolio);
--   * the entity exists and is locked for key share, after the portfolio key
--     (the global order): an entity delete then waits for this insert, and
--     its trigger deletes this row too, or the insert finds the entity gone.
create or replace function private.before_document_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_found boolean;
begin
  if (select auth.uid()) is not null and not app.has_portfolio_role(
    new.portfolio_id, array['owner', 'manager', 'accountant']::public.member_role[]
  ) then
    perform app.forbid();
  end if;
  perform private.lock_inserted_row_portfolio(tg_table_name, new.portfolio_id);

  execute format(
    'select true from public.%I e where e.id = $1 and e.portfolio_id = $2 for key share',
    private.document_entity_table(new.entity_type)
  ) into v_found using new.entity_id, new.portfolio_id;
  if v_found is null then
    perform app.fail('document_entity_not_found');
  end if;
  return new;
end
$$;

-- A manual charge locks its lease before it is inserted (portfolio key, then
-- the lease), as before; the portfolio key comes from
-- private.lock_inserted_row_portfolio, exactly as in before_document_insert.
create or replace function private.before_manual_charge_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not app.has_portfolio_role(
    new.portfolio_id, array['owner', 'manager', 'accountant']::public.member_role[]
  ) then
    perform app.forbid();
  end if;
  perform private.lock_inserted_row_portfolio(tg_table_name, new.portfolio_id);
  perform 1 from public.leases l
  where l.id = new.lease_id and l.portfolio_id = new.portfolio_id
  for update;
  return new;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. The file's storage.objects row (S1) and the sweep gate (S2)
-- ---------------------------------------------------------------------------

-- S1 serialises a document insert and every delete of its file on the
-- file's storage.objects row:
--
--   * the insert locks the row FOR KEY SHARE (after_document_insert_check_file)
--     and holds it until it commits;
--   * a DELETE locks the row (as FOR UPDATE does) before a BEFORE ROW
--     trigger runs, so it waits for that insert; the trigger then reads
--     documents with a fresh snapshot and keeps (skips) a row a document
--     references (private.before_document_object_delete);
--   * an insert that comes second waits for the delete's lock, then finds
--     the row gone (document_file_missing).
--
-- The trigger acts in the statement that removes the row, so it holds for
-- every way a file is deleted: up to v1.80 the Storage API deleted as the
-- user under documents_objects_delete (one object after locking its row FOR
-- UPDATE as superuser; a batch without it); from v1.81 it locks the rows FOR
-- UPDATE (ordered by name COLLATE "C"), asks documents_objects_delete in a
-- savepoint that is always rolled back (a "probe" DELETE as the user), then
-- deletes as superuser, which row security does not see; the cleaner and
-- admins delete as the service role. The hosted project's storage.migrations
-- has 80 rows, which only storage-api v1.86 or later creates, so it deletes
-- the v1.81 way. A file skipped by the trigger is not returned by the DELETE,
-- so the Storage API keeps its bytes and reports it as not deleted.
--
-- A row lock is kept in the row itself, so neither side fills PostgreSQL's
-- shared lock table, however many files a request touches. Locking and
-- triggering on another schema's table needs SELECT, UPDATE and TRIGGER on
-- storage.objects and row security out of the way for the role that owns
-- these functions (on Supabase, postgres: storage-api grants it every
-- privilege on the storage tables, and it has BYPASSRLS). Without them every
-- document insert would fail, so the migration stops here instead. The
-- documents bucket must keep versioning off: a versioned bucket's delete
-- writes a delete marker (an UPDATE), which the trigger does not see; the
-- block below refuses to run while it is on.
do $$
declare
  v_table regclass := 'storage.objects'::regclass;
  v_versioned boolean := false;
begin
  if not (has_table_privilege(v_table, 'select') and has_table_privilege(v_table, 'update')
          and has_table_privilege(v_table, 'trigger')) then
    raise exception 'concurrency findings: % needs SELECT, UPDATE and TRIGGER on storage.objects',
      current_user;
  end if;
  if not exists (
       select 1 from pg_catalog.pg_roles r
       where r.rolname = current_user and (r.rolsuper or r.rolbypassrls)
     )
     and not pg_has_role(current_user, (select c.relowner from pg_catalog.pg_class c where c.oid = v_table), 'usage')
  then
    raise exception 'concurrency findings: % is subject to row security on storage.objects', current_user;
  end if;
  if (select c.relforcerowsecurity from pg_catalog.pg_class c where c.oid = v_table) then
    raise exception 'concurrency findings: storage.objects forces row security';
  end if;
  -- Storage API versions without bucket versioning have no such column.
  if exists (
       select 1 from information_schema.columns c
       where c.table_schema = 'storage' and c.table_name = 'buckets' and c.column_name = 'versioning_status'
     ) then
    execute $q$select exists (
      select 1 from storage.buckets b
      where b.id = 'documents' and b.versioning_status is distinct from 'DISABLED'
    )$q$ into v_versioned;
  end if;
  if v_versioned then
    raise exception 'concurrency findings: the documents bucket must keep versioning off';
  end if;
end
$$;

-- The sweep gate (S2): one advisory lock, (1701080943, 0), in the two-key
-- form, which PostgreSQL never confuses with the app's one-key advisory
-- locks (the daily job's, payment idempotency keys). Every document insert's
-- check takes it shared (p_sweep = false: waits while the sweep holds it);
-- the daily sweep takes it exclusively, trying once (p_sweep = true: never
-- waits). One lock for the whole sweep, however many files it queues: a lock
-- per file filled PostgreSQL's shared lock table (max_locks_per_transaction
-- x connections) once enough orphaned files existed, and the daily job then
-- failed on every run.
create or replace function private.lock_document_sweep_gate(p_sweep boolean)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not p_sweep then
    perform pg_advisory_xact_lock_shared(1701080943, 0);
    return true;
  end if;
  return pg_try_advisory_xact_lock(1701080943, 0);
end
$$;

comment on function private.lock_document_sweep_gate(boolean) is
  'S2: document inserts take this gate shared, the orphan sweep exclusively (try only).';

revoke all on function private.lock_document_sweep_gate(boolean) from public, anon, authenticated;

-- The check of a document INSERT's files, once per statement after all its
-- rows (it replaces the row trigger of the same name):
--   * the sweep gate, shared (S2), first: a waiter for it holds no file;
--   * the files' storage.objects rows FOR KEY SHARE (S1), in one statement,
--     ordered by name COLLATE "C", the order in which the Storage API locks
--     a batch, so a multi-row insert and a batch delete of the same files
--     cannot wait for each other in a cycle. The lock waits for a Storage
--     delete (or an overwrite or move) of the file that holds the row, then
--     reads its latest version: a deleted or renamed file is not found;
--   * document_file_missing unless every path was locked;
--   * document_file_pending_deletion if a path, or its portfolio folder, is
--     queued for deletion, read after the gate (fresh snapshot).
-- While this transaction holds a row, every DELETE of that file waits and
-- then keeps it (private.before_document_object_delete), and the delete
-- policy refuses it at once; while it holds the gate, the sweep cannot queue
-- the file. What it waits for never waits for it: the gate's exclusive
-- holder is the daily job, which after the sweep only finishes its own rows
-- and commits; a row's FOR UPDATE holder is a Storage request, which locks
-- its rows in the same order and otherwise only tries locks.
create or replace function private.after_document_insert_check_file()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text[];
  v_locked integer;
begin
  select array_agg(distinct n.storage_path) into v_paths from new_documents n;
  if v_paths is null then
    return null;
  end if;

  perform private.lock_document_sweep_gate(false);
  perform 1
  from storage.objects o
  where o.bucket_id = 'documents' and o.name = any (v_paths)
  order by o.name collate "C"
  for key share of o;
  get diagnostics v_locked = row_count;
  if v_locked < cardinality(v_paths) then
    perform app.fail('document_file_missing');
  end if;

  if exists (
    select 1
    from unnest(v_paths) f (path)
    join private.storage_cleanup_queue q
      on q.bucket_id = 'documents' and q.path in (f.path, split_part(f.path, '/', 1) || '/')
  ) then
    perform app.fail('document_file_pending_deletion');
  end if;
  return null;
end
$$;

comment on function private.after_document_insert_check_file() is
  'S1, S2: a document insert''s files exist (locked for key share) and are not queued for deletion.';

drop trigger documents_after_insert_check_file on public.documents;
create trigger documents_after_insert_check_file
  after insert on public.documents
  referencing new table as new_documents
  for each statement execute function private.after_document_insert_check_file();

-- Whether a user's Storage delete may remove an object (the delete policy).
-- Authorises first (owner or manager of the folder's portfolio), so a caller
-- never locks a file it may not delete; then locks the object's row FOR
-- UPDATE without waiting (SKIP LOCKED): a document insert holding it is
-- attaching the file right now, so the delete is refused (the object stays;
-- if the insert rolls back, the daily sweep queues the file after a day). A
-- row the request already locked itself (the Storage API locks it first) is
-- returned at once. Then documents are read with a fresh snapshot. This is
-- the answer the user sees; private.before_document_object_delete enforces
-- it in the statement that deletes. Not waiting means a delete as the user
-- (Storage API up to v1.80) never waits for a document insert, so a batch
-- delete and a multi-row insert of the same files cannot deadlock.
create or replace function app.document_object_deletable(p_name text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if app.document_object_portfolio(p_name) is null
     or not app.document_object_portfolio(p_name) = any (
       app.my_portfolio_ids(array['owner', 'manager']::public.member_role[])::text[]
     ) then
    return false;
  end if;
  perform 1 from storage.objects o
  where o.bucket_id = 'documents' and o.name = p_name
  for update of o skip locked;
  if not found then
    return false;
  end if;
  return not exists (select 1 from public.documents d where d.storage_path = p_name);
end
$$;

comment on function app.document_object_deletable(text) is
  'Storage delete policy (S1): authorise, lock the object row without waiting, then check no document references it.';

revoke all on function app.document_object_deletable(text) from public, anon;
grant execute on function app.document_object_deletable(text) to authenticated;

-- The Storage API asks this policy before it deletes a user's objects (or
-- deletes as the user, up to v1.80): it decides who may delete what. Its
-- first two conditions are kept for the planner and readers; the helper
-- checks them again before it locks anything. The cleaner deletes as the
-- service role (row security bypassed): it removes only what
-- admin_storage_cleanup_objects listed for a queued item, and a document
-- insert for a queued path is refused while the item exists.
alter policy documents_objects_delete on storage.objects
  using (
    bucket_id = 'documents'
    and app.document_object_portfolio(name) = any ((select app.my_portfolio_ids(
      array['owner', 'manager']::public.member_role[]))::text[])
    and app.document_object_deletable(name)
  );

-- S1, for every delete: a BEFORE DELETE row trigger on storage.objects that
-- keeps a file of the documents bucket while a document references it. By
-- the time it runs, PostgreSQL has locked the row for the DELETE (waiting
-- for a document insert holding it FOR KEY SHARE to end), and its query
-- takes a fresh snapshot, so it sees a document committed while the DELETE
-- waited. Returning null skips the row: the DELETE neither removes nor
-- returns it, so the Storage API keeps the file's bytes and reports it not
-- deleted (one object: AccessDenied; a batch: left out of the result).
-- Legitimate deletes are unaffected: a user's upload without a document, the
-- cleaner's files (listed only while no document references them; portfolio
-- and account deletion remove the document rows before queueing the files),
-- and any file whose document was deleted first. It runs as its owner, which
-- may read public.documents; the Storage API's role may not.
create or replace function private.before_document_object_delete()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.documents d where d.storage_path = old.name) then
    return null;
  end if;
  return old;
end
$$;

comment on function private.before_document_object_delete() is
  'S1: storage.objects BEFORE DELETE (documents bucket): keeps a file a document references, whoever deletes it.';

revoke all on function private.before_document_object_delete() from public, anon, authenticated;

create trigger documents_objects_keep_referenced
  before delete on storage.objects
  for each row
  when (old.bucket_id = 'documents')
  execute function private.before_document_object_delete();

-- S2: queues files older than a day without a document row, only while it
-- holds the sweep gate, reading documents after taking it. It only tries the
-- gate: while a document insert is between its check and its commit (a few
-- milliseconds) the gate is busy, so it tries 20 times, 50 ms apart, and
-- otherwise returns null (the files wait for the next try). It never waits
-- for a lock a client holds. The gate is held until the caller commits; a
-- document insert meanwhile waits and then sees what was queued. A sweep
-- that ran records the day (Pakistan date) in private.job_runs as
-- 'orphaned_file_sweep', so run_daily_jobs knows whether to try again.
-- Returns how many files it queued.
create or replace function private.sweep_orphaned_files(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
  v_gate boolean := false;
begin
  for v_try in 1 .. 20 loop
    v_gate := private.lock_document_sweep_gate(true);
    exit when v_gate;
    perform pg_sleep(0.05);
  end loop;
  if not v_gate then
    raise warning 'sweep_orphaned_files: document inserts kept the sweep gate busy; the next daily-job run tries again';
    return null;
  end if;

  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', o.name, false, 'orphaned'
  from storage.objects o
  where o.bucket_id = 'documents'
    and o.created_at < p_now - interval '1 day'
    and right(o.name, 1) <> '/'
    and not exists (select 1 from public.documents d where d.storage_path = o.name)
  on conflict (bucket_id, path) do nothing;
  get diagnostics v_rows = row_count;

  insert into private.job_runs as j (job_name, run_on, result)
  values ('orphaned_file_sweep', app.today_pkt(), jsonb_build_object('queued', v_rows))
  on conflict (job_name, run_on) do update
    set finished_at = now(), result = jsonb_build_object('queued', coalesce((j.result ->> 'queued')::integer, 0) + v_rows);
  return v_rows;
end
$$;

comment on function private.sweep_orphaned_files(timestamptz) is
  'S2: queues files older than a day without a document row while holding the sweep gate (null: gate busy).';

-- Queues files that no trigger saw, after deleting document rows whose
-- entity is gone: the folders of portfolios that no longer exist (no gate:
-- a document cannot be inserted into a portfolio that does not exist), then
-- old files without a document row (private.sweep_orphaned_files; skipped
-- while the gate stays busy). Run once a day by private.cleanup(). Returns
-- how many items it queued.
create or replace function private.enqueue_orphaned_storage(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  perform private.delete_orphaned_documents();

  -- The CASE guards the cast: AND does not fix an evaluation order.
  with folders as (
    select distinct f.portfolio_id
    from (
      select case
               when split_part(o.name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
               then split_part(o.name, '/', 1)::uuid
             end as portfolio_id
      from storage.objects o
      where o.bucket_id = 'documents'
    ) f
    where f.portfolio_id is not null
      and not exists (select 1 from public.portfolios p where p.id = f.portfolio_id)
  ), retired as (
    insert into private.portfolio_ids (id, retired_at)
    select f.portfolio_id, p_now from folders f
    on conflict (id) do nothing
  )
  insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
  select 'documents', f.portfolio_id::text || '/', true, 'orphaned'
  from folders f
  on conflict (bucket_id, path) do nothing;
  get diagnostics v_rows = row_count;

  return v_rows + coalesce(private.sweep_orphaned_files(p_now), 0);
end
$$;

revoke all on function private.sweep_orphaned_files(timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. The daily job tries a skipped file sweep again
-- ---------------------------------------------------------------------------

-- As in 20261105072426_membership_deletion_storage.sql, plus: once the day's
-- notifications and cleanup have run, every later run that maintained no
-- lease (so holds no lease locks) runs the orphaned-file sweep again until
-- one gets the sweep gate ('orphaned_file_sweep' in private.job_runs), so a
-- busy gate delays the sweep by ten minutes, not a day.
create or replace function private.run_daily_jobs(p_as_of date default null, p_batch_size integer default 500)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_lease record;
  v_step jsonb;
  v_processed integer := 0;
  v_busy integer := 0;
  v_failed integer := 0;
  v_charges integer := 0;
  v_fees integer := 0;
  v_pending integer;
  v_notifications integer;
  v_state text;
  v_message text;
begin
  if p_batch_size is null or p_batch_size not between 1 and 10000 then
    perform app.fail('invalid_batch_size');
  end if;
  -- One coordinator at a time; an overlapping run simply skips.
  if not pg_try_advisory_xact_lock(hashtext('maalik_e_makaan.run_daily_jobs')) then
    return jsonb_build_object('skipped', true);
  end if;

  for v_lease in
    select l.id, l.portfolio_id
    from public.leases l
    left join private.lease_maintenance m on m.lease_id = l.id
    where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of)
    order by l.id
    limit p_batch_size
  loop
    begin
      perform 1 from public.portfolios p where p.id = v_lease.portfolio_id for key share skip locked;
      if not found then
        v_busy := v_busy + 1;
        continue;
      end if;
      perform 1 from public.leases l where l.id = v_lease.id for update skip locked;
      if not found then
        v_busy := v_busy + 1;
        continue;
      end if;

      v_step := private.maintain_lease(v_lease.id, v_as_of);
      insert into private.lease_maintenance as m (lease_id, maintained_on)
      values (v_lease.id, v_as_of)
      on conflict (lease_id) do update
        set maintained_on = excluded.maintained_on, failures = 0, last_error = null, updated_at = now();

      v_charges := v_charges + (v_step ->> 'charges_created')::integer;
      v_fees := v_fees + (v_step ->> 'late_fees')::integer;
      v_processed := v_processed + 1;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_message = message_text;
      v_failed := v_failed + 1;
      raise warning 'run_daily_jobs: lease % failed (%): %', v_lease.id, v_state, v_message;
      begin
        insert into private.lease_maintenance as m (lease_id, maintained_on, failures, last_error)
        values (v_lease.id, v_as_of, 1, v_state || ': ' || left(v_message, 500))
        on conflict (lease_id) do update
          set maintained_on = excluded.maintained_on,
              failures = m.failures + 1,
              last_error = excluded.last_error,
              updated_at = now();
      exception when foreign_key_violation then
        null; -- the lease was deleted in the meantime
      end;
    end;
  end loop;

  select count(*)::integer into v_pending
  from public.leases l
  left join private.lease_maintenance m on m.lease_id = l.id
  where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of);

  -- The portfolio-wide work runs once a day after every lease is done, and
  -- only in a run that maintained no lease itself, so it never holds lease
  -- locks while it fans out notifications (the next run, 10 minutes later).
  if v_pending = 0 and v_processed = 0 then
    insert into private.job_runs (job_name, run_on) values ('daily_notifications', v_as_of)
    on conflict (job_name, run_on) do nothing;
    if found then
      v_notifications := private.generate_notifications(v_as_of);
      perform private.cleanup(now());
      update private.job_runs
      set finished_at = now(), result = jsonb_build_object('notifications', v_notifications)
      where job_name = 'daily_notifications' and run_on = v_as_of;
    elsif not exists (
      select 1 from private.job_runs j where j.job_name = 'orphaned_file_sweep' and j.run_on = app.today_pkt()
    ) then
      perform private.sweep_orphaned_files(now());
    end if;
  end if;

  return jsonb_build_object(
    'as_of', v_as_of,
    'leases_processed', v_processed,
    'leases_busy', v_busy,
    'leases_failed', v_failed,
    'leases_pending', v_pending,
    'charges_created', v_charges,
    'late_fees', v_fees,
    'notifications', v_notifications
  );
end
$$;
