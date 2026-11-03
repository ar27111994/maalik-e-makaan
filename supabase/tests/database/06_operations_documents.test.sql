-- Utilities, expenses, maintenance, reminders, documents and storage RLS.
begin;
\ir _helpers.psql
select plan(28);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('accountant@example.com') as accountant \gset
select tests.create_user('viewer@example.com') as viewer \gset
select tests.create_user('other.owner@example.com') as other \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_portfolio(:'other', 'Other') as other_pid \gset
select tests.add_member(:'pid', :'accountant', 'accountant');
select tests.add_member(:'pid', :'viewer', 'viewer');
select tests.create_rental(:'pid') as r \gset
select (:'r')::jsonb ->> 'property_id' as prop, (:'r')::jsonb ->> 'unit_id' as unit \gset
select tests.create_lease(:'pid', :'r', '2026-10-01') as lease \gset
select tests.create_rental(:'pid', 'punjab', 'Ground floor') as r2 \gset
select (:'r2')::jsonb ->> 'property_id' as prop2, (:'r2')::jsonb ->> 'unit_id' as unit2 \gset
select tests.create_lease(:'pid', :'r2', '2026-10-01') as lease2 \gset

-- Utilities ---------------------------------------------------------------------
select tests.authenticate_as(:'owner');
insert into public.utility_accounts (portfolio_id, property_id, unit_id, type, provider, reference_number,
                                     account_title, in_landlord_name, is_protected_consumer)
values (:'pid', :'prop', :'unit', 'electricity', 'lesco', '09269330553008', 'Owner Name', true, true)
returning id as acct \gset
select throws_ok(
  format($f$insert into public.utility_accounts (portfolio_id, property_id, type, reference_number)
            values (%L, %L, 'electricity', '09269330553008')$f$, :'pid', :'prop'),
  '23505', null, 'the same reference number cannot be registered twice'
);
select throws_ok(
  format($f$insert into public.utility_accounts (portfolio_id, property_id, type, reference_number)
            values (%L, %L, 'gas', 'ref with spaces')$f$, :'pid', :'prop'),
  '23514', null, 'reference numbers are digits/letters only'
);

select tests.authenticate_as(:'accountant');
insert into public.utility_bills (portfolio_id, utility_account_id, billing_month, amount, due_date, units_consumed)
values (:'pid', :'acct', '2026-10-01', 7350, '2026-11-12', 212) returning id as bill \gset
select throws_ok(
  format($f$insert into public.utility_bills (portfolio_id, utility_account_id, billing_month, amount)
            values (%L, %L, '2026-10-01', 1)$f$, :'pid', :'acct'),
  '23505', null, 'one bill per connection per month'
);
select throws_ok(
  format($f$update public.utility_bills set status = 'paid' where id = %L$f$, :'bill'),
  '23514', null, 'a paid bill needs a payment date'
);

select is(
  (public.bill_utility_to_tenant(:'bill', :'lease')).amount, 7350.00,
  'a utility bill can be charged to the tenant'
);
select results_eq(
  format($f$select kind::text, period_month, due_date, source from public.charges
            where utility_bill_id = %L$f$, :'bill'),
  $$values ('electricity'::text, '2026-10-01'::date, '2026-11-12'::date, 'utility_bill'::text)$$,
  'the charge mirrors the bill (kind, month, due date)'
);
select is(
  (public.bill_utility_to_tenant(:'bill', :'lease')).id,
  (select charge_id from public.utility_bills where id = :'bill'),
  'charging the same bill twice returns the existing charge'
);
select is((select count(*)::integer from public.charges where utility_bill_id = :'bill'), 1, 'no duplicate utility charges');
select throws_ok(
  format($f$select public.bill_utility_to_tenant(%L, %L)$f$, :'bill', :'lease2'),
  '22023', 'lease_not_on_this_connection', 'only a tenant on the connection''s unit can be charged'
);

-- Meter readings and expenses ------------------------------------------------------
select lives_ok(
  format($f$insert into public.meter_readings (portfolio_id, utility_account_id, lease_id, reading, read_on, context)
            values (%L, %L, %L, 10432.5, '2026-10-01', 'move_in')$f$, :'pid', :'acct', :'lease'),
  'move-in meter readings are recorded'
);
select lives_ok(
  format($f$insert into public.expenses (portfolio_id, property_id, unit_id, category, amount, spent_on, payee, method)
            values (%L, %L, %L, 'repairs_maintenance', 4500, '2026-11-01', 'Plumber Aslam', 'cash')$f$,
         :'pid', :'prop', :'unit'),
  'expenses can be recorded against a unit'
);
select throws_ok(
  format($f$insert into public.expenses (portfolio_id, unit_id, category, amount, spent_on)
            values (%L, %L, 'other', 10, '2026-11-01')$f$, :'pid', :'unit'),
  '23514', null, 'a unit expense must name its property'
);
select throws_ok(
  format($f$insert into public.expenses (portfolio_id, category, amount, spent_on, method)
            values (%L, 'other', 10, '2026-11-01', 'deposit_adjustment')$f$, :'pid'),
  '23514', null, 'expenses cannot be paid by deposit adjustment'
);

-- Maintenance ------------------------------------------------------------------------
select tests.authenticate_as(:'owner');
insert into public.maintenance_requests (portfolio_id, property_id, unit_id, lease_id, title, category, priority)
values (:'pid', :'prop', :'unit', :'lease', 'Seepage in kitchen wall', 'seepage', 'high')
returning id as job \gset
select throws_ok(
  format($f$update public.maintenance_requests set status = 'resolved' where id = %L$f$, :'job'),
  '23514', null, 'resolving a job requires a resolution date'
);
select lives_ok(
  format($f$update public.maintenance_requests set status = 'resolved', resolved_on = '2026-11-03',
            resolution_note = 'Re-plastered and sealed' where id = %L$f$, :'job'),
  'jobs are resolved with a date and note'
);

-- Reminder log --------------------------------------------------------------------------
select tests.authenticate_as(:'accountant');
select lives_ok(
  format($f$insert into public.reminder_logs (portfolio_id, lease_id, channel, template, language, message_preview)
            values (%L, %L, 'whatsapp', 'overdue_gentle', 'roman_ur', 'Assalam-o-Alaikum…')$f$, :'pid', :'lease'),
  'reminders sent through WhatsApp are logged'
);
select throws_ok(
  format($f$insert into public.reminder_logs (portfolio_id, lease_id, channel, template, language)
            values (%L, %L, 'whatsapp', 'DROP TABLE', 'en')$f$, :'pid', :'lease'),
  '23514', null, 'template keys are constrained'
);

-- Documents --------------------------------------------------------------------------------
\set doc_id '01a1a2d2-0000-7000-8000-000000000001'
select format('%s/tenant/%s/%s.jpg', :'pid', (:'r')::jsonb ->> 'tenant_id', :'doc_id') as doc_path \gset
select lives_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, kind, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'tenant', %L, 'cnic_front', %L, 'cnic-front.jpg', 'image/jpeg', 182344)$f$,
         :'pid', (:'r')::jsonb ->> 'tenant_id', :'doc_path'),
  'documents are attached under <portfolio>/<entity>/<id>/<uuid>.<ext>'
);
select throws_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'tenant', %L, %L, 'x.jpg', 'image/jpeg', 1)$f$,
         :'pid', (:'r')::jsonb ->> 'tenant_id', :'pid' || '/tenant/../../etc/passwd'),
  '23514', null, 'path traversal and non-canonical paths are rejected'
);
select throws_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'tenant', %L, %L, 'x.exe', 'application/x-msdownload', 1)$f$,
         :'pid', (:'r')::jsonb ->> 'tenant_id',
         format('%s/tenant/%s/%s.pdf', :'pid', (:'r')::jsonb ->> 'tenant_id', gen_random_uuid())),
  '23514', null, 'only images and PDFs are accepted'
);
select throws_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'lease', %L, %L, 'x.pdf', 'application/pdf', 1)$f$,
         :'pid', :'lease2', format('%s/lease/%s/%s.pdf', :'pid', '01a1a2d2-ffff-7000-8000-000000000000', gen_random_uuid())),
  '23514', null, 'the path must match the entity the document belongs to'
);
select throws_ok(
  format($f$insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
            values (%L, 'lease', %L, %L, 'x.pdf', 'application/pdf', 1)$f$,
         :'pid', '01a1a2d2-ffff-7000-8000-000000000000',
         format('%s/lease/%s/%s.pdf', :'pid', '01a1a2d2-ffff-7000-8000-000000000000', gen_random_uuid())),
  '22023', 'document_entity_not_found', 'documents must belong to an existing entity of the same portfolio'
);

-- Storage object policies --------------------------------------------------------------------
select lives_ok(
  format($f$insert into storage.objects (bucket_id, name, owner) values ('documents', %L, auth.uid())$f$, :'doc_path'),
  'members upload into their portfolio folder'
);
select throws_ok(
  format($f$insert into storage.objects (bucket_id, name) values ('documents', %L)$f$,
         format('%s/tenant/%s/%s.jpg', :'other_pid', gen_random_uuid(), gen_random_uuid())),
  '42501', null, 'members cannot upload into another portfolio''s folder'
);
select throws_ok(
  format($f$insert into storage.objects (bucket_id, name) values ('documents', %L)$f$,
         format('%s/tenant/%s/evil.svg', :'pid', gen_random_uuid())),
  '42501', null, 'object names must follow the canonical layout and extensions'
);

select tests.authenticate_as(:'viewer');
select is((select count(*)::integer from storage.objects where bucket_id = 'documents'), 1, 'viewers can read their portfolio files');
select throws_ok(
  format($f$insert into storage.objects (bucket_id, name) values ('documents', %L)$f$,
         format('%s/tenant/%s/%s.jpg', :'pid', gen_random_uuid(), gen_random_uuid())),
  '42501', null, 'viewers cannot upload'
);

select tests.authenticate_as(:'other');
select is((select count(*)::integer from storage.objects where bucket_id = 'documents'), 0, 'other portfolios cannot see the files');

select * from finish();
rollback;
