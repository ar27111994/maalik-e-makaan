-- Durable storage cleanup: what gets queued (document rows, portfolios,
-- entities with documents, orphans), how cleaners claim, list and finish
-- items, who may call the queue RPCs, and the invariants that keep a queued
-- file from being referenced again: single-use portfolio ids and document
-- rows that need their file. Membership and deletion races are exercised
-- with real parallel sessions in tool/db/concurrency_test.sh.
begin;
\ir _helpers.psql
select plan(54);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('member@example.com') as member \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_portfolio(:'owner', 'Second') as pid2 \gset
select tests.create_rental(:'pid') as r \gset
select tests.create_lease(:'pid', :'r', '2026-10-01') as lease \gset
select (:'r')::jsonb ->> 'tenant_id' as tenant \gset
select (:'r')::jsonb ->> 'property_id' as property \gset

-- One document on the tenant and one on the property: files first, then rows.
select :'pid' || '/tenant/' || :'tenant' || '/' || gen_random_uuid() || '.jpg' as tenant_file \gset
select :'pid' || '/property/' || :'property' || '/' || gen_random_uuid() || '.pdf' as property_file \gset
insert into storage.objects (bucket_id, name) values ('documents', :'tenant_file'), ('documents', :'property_file');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values (:'pid', 'tenant', :'tenant', :'tenant_file', 'cnic.jpg', 'image/jpeg', 1000),
       (:'pid', 'property', :'property', :'property_file', 'deed.pdf', 'application/pdf', 2000);

-- Queueing ------------------------------------------------------------------------------------
select is_empty($$select 1 from private.storage_cleanup_queue$$, 'nothing is queued while files are in use');

delete from public.documents where storage_path = :'tenant_file';
select results_eq(
  $$select bucket_id, path, is_prefix, reason from private.storage_cleanup_queue$$,
  format($f$values ('documents'::text, %L::text, false, 'document_deleted'::text)$f$, :'tenant_file'),
  'deleting a document row queues its file'
);

-- Deleting an entity deletes its documents, which queues their files.
delete from public.leases where id = :'lease';
delete from public.units where property_id = :'property';
delete from public.properties where id = :'property';
select is_empty(
  format($f$select 1 from public.documents where entity_id = %L$f$, :'property'),
  'deleting an entity deletes its documents'
);
select ok(
  exists (select 1 from private.storage_cleanup_queue where path = :'property_file' and not is_prefix),
  'and queues their files'
);

-- A row whose file is already gone (deleted out of band) has nothing to queue.
select :'pid' || '/tenant/' || :'tenant' || '/' || gen_random_uuid() || '.jpg' as gone_file \gset
insert into storage.objects (bucket_id, name) values ('documents', :'gone_file');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values (:'pid', 'tenant', :'tenant', :'gone_file', 'old.jpg', 'image/jpeg', 1000);
-- Out of band: no delete can remove a file a document references
-- (documents_objects_keep_referenced), so only a superuser that switches
-- triggers off gets here; session_replication_role = replica does that.
set local session_replication_role = replica;
delete from storage.objects where name = :'gone_file';
reset session_replication_role;
delete from public.documents where storage_path = :'gone_file';
select is_empty(
  format($f$select 1 from private.storage_cleanup_queue where path = %L$f$, :'gone_file'),
  'only files that exist are queued'
);

-- Deleting a portfolio queues its whole folder and retires its id.
insert into public.audit_logs (portfolio_id, action, table_name, record_id, changes)
values (:'pid2', 'update', 'portfolios', :'pid2', '{}');
select tests.authenticate_as(:'owner');
select public.delete_portfolio(:'pid2', 'second');
select tests.clear_authentication();
select results_eq(
  format($f$select is_prefix, reason from private.storage_cleanup_queue where path = %L$f$, :'pid2' || '/'),
  $$values (true, 'portfolio_deleted'::text)$$,
  'deleting a portfolio queues its folder'
);
select is_empty(
  format($f$select 1 from public.audit_logs where portfolio_id = %L$f$, :'pid2'),
  'and removes its audit trail'
);
select ok(
  (select retired_at is not null from private.portfolio_ids where id = :'pid2'),
  'its id is retired'
);
select throws_ok(
  $$insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason) values ('documents', 'a/b', true, 'orphaned')$$,
  '23514', null, 'a prefix item must end with a slash'
);

-- Single-use portfolio ids ------------------------------------------------------------------------
select ok(
  exists (select 1 from private.portfolio_ids where id = :'pid' and retired_at is null),
  'every portfolio id is registered when the portfolio is created'
);
select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$select public.create_portfolio('Second again', %L)$f$, :'pid2'),
  '42501', 'forbidden', 'a deleted portfolio''s id cannot be claimed again, even by its creator'
);
select tests.authenticate_as(:'member');
select throws_ok(
  format($f$select public.create_portfolio('Mine now', %L)$f$, :'pid2'),
  '42501', 'forbidden', 'nor by anybody else'
);
select tests.clear_authentication();
select is_empty(
  format($f$select 1 from private.rate_limit_buckets where bucket_key like %L$f$, 'create_portfolio%' || :'member' || '%'),
  'refused claims are not even counted against the rate limit'
);
select throws_ok(
  format($f$insert into public.portfolios (id, name, created_by) values (%L, 'Direct', %L)$f$, :'pid2', :'owner'),
  '42501', 'forbidden', 'no insert path reuses a retired id'
);
select tests.authenticate_as(:'member');
select lives_ok(
  $$select public.create_portfolio('Fresh', '01a1a2ff-0000-7000-8000-000000000001')$$,
  'new client-supplied ids still work'
);
select tests.clear_authentication();

-- Orphan sweep ------------------------------------------------------------------------------
-- A folder of a portfolio that no longer exists, an unregistered old file,
-- an unregistered new file (an upload in progress) and a malformed name.
select '00000000-0000-4000-8000-0000000000aa' as gone \gset
insert into storage.objects (bucket_id, name, created_at) values
  ('documents', :'gone' || '/tenant/00000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000002.jpg', now()),
  ('documents', :'pid' || '/tenant/' || :'tenant' || '/00000000-0000-4000-8000-000000000003.jpg', now() - interval '2 days'),
  ('documents', :'pid' || '/tenant/' || :'tenant' || '/00000000-0000-4000-8000-000000000004.jpg', now()),
  ('documents', 'not-a-uuid/whatever.jpg', now());
select is(private.enqueue_orphaned_storage(now()), 2, 'the daily sweep queues orphans');
select ok(
  exists (select 1 from private.storage_cleanup_queue where path = :'gone' || '/' and is_prefix and reason = 'orphaned'),
  'files of a portfolio that no longer exists are queued by folder'
);
select ok(
  (select retired_at is not null from private.portfolio_ids where id = :'gone'),
  'and that folder''s id is retired, so it can never be claimed'
);
select ok(
  exists (select 1 from private.storage_cleanup_queue
          where path = :'pid' || '/tenant/' || :'tenant' || '/00000000-0000-4000-8000-000000000003.jpg'),
  'a file without a document row for a day is queued'
);
select ok(
  not exists (select 1 from private.storage_cleanup_queue
              where path = :'pid' || '/tenant/' || :'tenant' || '/00000000-0000-4000-8000-000000000004.jpg'),
  'a fresh upload is left alone'
);
select is(private.enqueue_orphaned_storage(now()), 0, 'sweeping again queues nothing new');

-- A row left behind by an entity deleted before inserts locked their entity
-- (simulated by deleting the tenant with its trigger off) is repaired.
select :'pid' || '/tenant/' || :'tenant' || '/' || gen_random_uuid() || '.jpg' as legacy_file \gset
insert into storage.objects (bucket_id, name) values ('documents', :'legacy_file');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values (:'pid', 'tenant', :'tenant', :'legacy_file', 'cnic-back.jpg', 'image/jpeg', 1000);
alter table public.tenants disable trigger tenants_after_delete_documents;
delete from public.tenants where id = :'tenant';
alter table public.tenants enable trigger tenants_after_delete_documents;
select is(private.delete_orphaned_documents(), 1, 'documents whose entity is gone are deleted');
select ok(
  exists (select 1 from private.storage_cleanup_queue where path = :'legacy_file' and reason = 'document_deleted'),
  'and their files queued'
);

-- Listing --------------------------------------------------------------------------------------
-- A queued file cannot be attached again: the cleaner may already have
-- listed it. Re-adding a file means uploading it under a new name.
insert into public.properties (id, portfolio_id, name, city, province)
values (:'property', :'pid', 'Rebuilt', 'Lahore', 'punjab');
select throws_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'property', %L, %L, 'deed.pdf', 'application/pdf', 2000)$f$,
         :'pid', :'property', :'property_file'),
  '22023', 'document_file_pending_deletion', 'a file queued for deletion cannot be attached again'
);
-- Whatever was queued, a referenced object is never offered for deletion.
select :'pid' || '/property/' || :'property' || '/' || gen_random_uuid() || '.pdf' as live_file \gset
insert into storage.objects (bucket_id, name) values ('documents', :'live_file');
insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
values (:'pid', 'property', :'property', :'live_file', 'plan.pdf', 'application/pdf', 3000);
insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
values ('documents', :'live_file', false, 'orphaned');
select id as live_item from private.storage_cleanup_queue where path = :'live_file' \gset
select id as property_item from private.storage_cleanup_queue where path = :'property_file' \gset
select id as tenant_item from private.storage_cleanup_queue where path = :'tenant_file' \gset
select id as gone_item from private.storage_cleanup_queue where path = :'gone' || '/' \gset
select is_empty(
  format($f$select * from public.admin_storage_cleanup_objects(%s)$f$, :live_item),
  'objects referenced by a live document are never listed'
);
select results_eq(
  format($f$select name from public.admin_storage_cleanup_objects(%s)$f$, :tenant_item),
  format($f$values (%L::text)$f$, :'tenant_file'),
  'a file item lists its object'
);
insert into storage.objects (bucket_id, name) values
  ('documents', :'gone' || '/lease/00000000-0000-4000-8000-000000000005/00000000-0000-4000-8000-000000000006.pdf'),
  ('documents', '00000000-0000-4000-8000-0000000000ab/tenant/00000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000007.jpg');
select is(
  (select count(*)::integer from public.admin_storage_cleanup_objects(:gone_item)), 2,
  'a folder item lists everything under the folder, and nothing beside it'
);
select is(
  (select count(*)::integer from public.admin_storage_cleanup_objects(:gone_item, 1)), 1,
  'listings are paged'
);
select is_empty($$select * from public.admin_storage_cleanup_objects(-1)$$, 'an unknown item lists nothing');

-- Claiming ----------------------------------------------------------------------------------
select throws_ok(
  $$select * from public.admin_claim_storage_cleanup(0)$$,
  '22023', 'invalid_claim', 'claims are bounded'
);
select results_eq(
  format($f$select id from public.admin_claim_storage_cleanup(100, 120, array[%L])$f$, :'gone' || '/'),
  format($f$values (%s::bigint)$f$, :gone_item),
  'a claim can be restricted to given items'
);
update private.storage_cleanup_queue set claimed_until = null, attempts = 0 where id = :gone_item;
select is(
  (select count(*)::integer from public.admin_claim_storage_cleanup(100, 120)),
  (select count(*)::integer from private.storage_cleanup_queue),
  'a cleaner claims every due item'
);
select is_empty($$select * from public.admin_claim_storage_cleanup(100, 120)$$, 'claimed items are not handed out twice');
update private.storage_cleanup_queue set claimed_until = now() - interval '1 second' where id = :tenant_item;
select results_eq(
  $$select id, attempts from public.admin_claim_storage_cleanup(100, 120)$$,
  format($f$values (%s::bigint, 2)$f$, :tenant_item),
  'an item whose cleaner died is claimable again once its lease expires'
);

-- Finishing ---------------------------------------------------------------------------------
select is(public.admin_complete_storage_cleanup(:tenant_item, true), 'done', 'a finished file item is done');
select is_empty(format($f$select 1 from private.storage_cleanup_queue where id = %s$f$, :tenant_item), 'and leaves the queue');
select is(public.admin_complete_storage_cleanup(:gone_item, true), 'rescheduled', 'a finished folder is swept once more');
select ok(
  (select not_before = enqueued_at + interval '15 minutes' and claimed_until is null
   from private.storage_cleanup_queue where id = :gone_item),
  '15 minutes after it was queued (uploads in flight at deletion)'
);
update private.storage_cleanup_queue set enqueued_at = now() - interval '16 minutes' where id = :gone_item;
select is(public.admin_complete_storage_cleanup(:gone_item, true), 'done', 'then it is done');
update private.storage_cleanup_queue set attempts = 9 where id = :property_item;
select is(public.admin_complete_storage_cleanup(:property_item, false), 'rescheduled', 'an unfinished item is due again');
select ok(
  (select not_before <= now() and claimed_until is null and attempts = 0
   from private.storage_cleanup_queue where id = :property_item),
  'at once, and handing it back is not counted as a failure'
);
select is(public.admin_complete_storage_cleanup(:property_item, false, 'storage 503'), 'retry', 'a failure is retried');
select ok(
  (select not_before > now() and not_before <= now() + interval '1 minute'
          and last_error = 'storage 503' and claimed_until is null
   from private.storage_cleanup_queue where id = :property_item),
  'a minute later after a first failure, with the error recorded'
);
update private.storage_cleanup_queue set attempts = 4 where id = :property_item;
select is(public.admin_complete_storage_cleanup(:property_item, false, 'storage 503'), 'retry', 'failures back off');
select ok(
  (select not_before > now() + interval '7 minutes' and not_before <= now() + interval '8 minutes'
   from private.storage_cleanup_queue where id = :property_item),
  'exponentially with consecutive failed claims'
);
select is(public.admin_complete_storage_cleanup(-1, true), 'missing', 'unknown items are reported');

-- Folders take turns: one portfolio's backlog does not hold up another's.
insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason, not_before)
select 'documents', '11111111-1111-4111-8111-111111111111/tenant/t/' || g || '.jpg', false, 'document_deleted',
       now() - interval '1 hour' + g * interval '1 second'
from generate_series(1, 5) g;
insert into private.storage_cleanup_queue (bucket_id, path, is_prefix, reason)
values ('documents', '22222222-2222-4222-8222-222222222222/', true, 'portfolio_deleted');
select set_eq(
  $$select split_part(path, '/', 1) from public.admin_claim_storage_cleanup(2, 120,
      array(select path from private.storage_cleanup_queue
            where path like '11111111-%' or path like '22222222-%'))$$,
  $$values ('11111111-1111-4111-8111-111111111111'::text), ('22222222-2222-4222-8222-222222222222'::text)$$,
  'folders take turns, so a backlog in one portfolio does not delay another''s deletions'
);

-- Late audit rows ---------------------------------------------------------------------------------
-- A transaction racing a deletion can write an audit row after it (audit rows
-- no longer reference the portfolio); the daily cleanup removes it.
insert into public.audit_logs (portfolio_id, action, table_name, record_id, changes)
values (:'pid2', 'update', 'documents', gen_random_uuid(), '{}');
select private.cleanup(now());
select is_empty(
  format($f$select 1 from public.audit_logs where portfolio_id = %L$f$, :'pid2'),
  'audit rows of a deleted portfolio are swept'
);

-- Scheduling and access ---------------------------------------------------------------------
-- What the scheduler does depends on the platform: plain PostgreSQL
-- (tool/db/test.sh) has neither pg_net nor Vault; the Supabase stack has both,
-- and the scheduler calls the function only once its Vault secrets exist.
select (to_regnamespace('net') is not null and to_regclass('vault.decrypted_secrets') is not null)
  as has_net \gset
\if :has_net
select is(private.request_storage_cleanup(), 'not_configured', 'without its Vault secrets the scheduler does nothing');
select vault.create_secret('http://127.0.0.1:54321', 'mm_project_url') is not null;
select vault.create_secret(repeat('t', 40), 'mm_storage_cleanup_token') is not null;
select is(
  private.request_storage_cleanup(), 'requested',
  'with them it asks the storage-cleanup function to drain the queue'
);
\else
select is(private.request_storage_cleanup(), 'unavailable', 'without pg_net the scheduler does nothing');
select skip('the request path needs pg_net and Vault (the Supabase stack)', 1);
\endif
select tests.authenticate_as(:'owner');
select throws_ok($$select * from public.admin_claim_storage_cleanup()$$, '42501', null, 'users cannot claim cleanup work');
select throws_ok(
  format($f$select * from public.admin_storage_cleanup_objects(%s)$f$, :property_item),
  '42501', null, 'users cannot list cleanup objects'
);
select throws_ok(
  format($f$select public.admin_complete_storage_cleanup(%s, true)$f$, :property_item),
  '42501', null, 'users cannot finish cleanup work'
);
select tests.authenticate_as_service_role();
select lives_ok($$select * from public.admin_claim_storage_cleanup(1, 30)$$, 'the secret key can claim cleanup work');

select * from finish();
rollback;
