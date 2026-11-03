-- In-app notifications (generation, idempotency, visibility) and the audit trail.
begin;
\ir _helpers.psql
select plan(17);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_user('viewer@example.com') as viewer \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.add_member(:'pid', :'manager', 'manager');
select tests.add_member(:'pid', :'viewer', 'viewer');
select tests.create_rental(:'pid') as r \gset

-- Lease started 2025-11-20: the increment anniversary (2026-11-20) is within
-- 30 days, the agreed end (2026-11-30) is within both the 90- and 30-day
-- horizons, police registration is overdue (Punjab: 15 days), November rent
-- (due 11-05) is due within 3 days and October is past its grace period.
select tests.create_lease(:'pid', :'r', '2025-11-20', 45000,
  '{"end_date": "2026-11-30", "billing_starts_on": "2026-10-01"}') as lease \gset
update public.tenants set cnic = '3520212345671', cnic_expiry = '2026-11-20'
where id = ((:'r')::jsonb ->> 'tenant_id')::uuid;

select is(private.generate_notifications('2026-11-03') > 0, true, 'notifications are generated');
select is(private.generate_notifications('2026-11-03'), 0, 'regeneration is idempotent');

select set_eq(
  $$select distinct kind::text from public.notifications$$,
  $$values ('rent_due_soon'), ('rent_overdue'), ('lease_expiring'), ('increment_due'),
           ('police_registration_overdue'), ('cnic_expiring')$$,
  'every applicable kind is produced'
);
select is(
  (select count(distinct user_id)::integer from public.notifications),
  2, 'owners and managers are notified, viewers are not'
);
select is(
  (select count(*)::integer from public.notifications
   where kind = 'lease_expiring' and user_id = :'owner'),
  2, 'agreement expiry is announced at 90 and at 30 days'
);
select ok(
  (select params ? 'tenant_name' and params ? 'amount' and params ? 'due_date'
   from public.notifications where kind = 'rent_due_soon' limit 1),
  'notification params carry what the app needs to render localised text'
);

-- Visibility and marking read ------------------------------------------------------
select tests.authenticate_as(:'manager');
select ok(
  (select bool_and(user_id = :'manager') from public.notifications),
  'members only see their own notifications'
);
select is(public.mark_notifications_read() > 0, true, 'members mark their notifications read');
select is((select count(*)::integer from public.notifications where read_at is null), 0, 'all marked read');
select throws_ok(
  $$update public.notifications set kind = 'rent_overdue'$$, '42501', null,
  'only read_at is updatable'
);

select tests.clear_authentication();
delete from public.portfolio_members where user_id = :'manager';
select tests.authenticate_as(:'manager');
select is((select count(*)::integer from public.notifications), 0, 'notifications disappear for removed members');

-- Audit trail -------------------------------------------------------------------------
select tests.authenticate_as(:'owner');
update public.tenants set full_name = 'Bilal Ahmed Khan', cnic = '3520212345672'
where id = ((:'r')::jsonb ->> 'tenant_id')::uuid;
select is(
  (select changes -> 'full_name' ->> 1 from public.audit_logs
   where table_name = 'tenants' and action = 'update' order by id desc limit 1),
  'Bilal Ahmed Khan',
  'updates store the new value of changed columns'
);
select is(
  (select changes -> 'cnic' ->> 1 from public.audit_logs
   where table_name = 'tenants' and action = 'update' order by id desc limit 1),
  '[redacted]',
  'CNIC values never reach the audit trail'
);
select is(
  (select actor_id from public.audit_logs where table_name = 'tenants' and action = 'update' order by id desc limit 1),
  (:'owner')::uuid,
  'the actor is recorded'
);
select ok(
  not exists (select 1 from public.audit_logs where changes ? 'updated_at' and action = 'update'),
  'updated_at churn is not recorded as a change'
);
select throws_ok(
  $$delete from public.audit_logs$$, '42501', null, 'the audit trail is append-only for clients'
);

select tests.authenticate_as(:'viewer');
select is((select count(*)::integer from public.audit_logs), 0, 'viewers cannot read the audit trail');

select * from finish();
rollback;
