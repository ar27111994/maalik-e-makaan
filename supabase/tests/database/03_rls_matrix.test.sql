-- Role permission matrix and tenant isolation.
--
-- Roles in portfolio A: owner, manager (caretaker), accountant, viewer.
-- Outsider: owner of portfolio B. Each table/operation is checked for the
-- roles that must and must not be able to perform it, and forged
-- cross-portfolio references must be rejected by composite foreign keys.
begin;
\ir _helpers.psql
select plan(63);

select tests.create_user('owner.a@example.com') as owner \gset
select tests.create_user('manager.a@example.com') as manager \gset
select tests.create_user('accountant.a@example.com') as accountant \gset
select tests.create_user('viewer.a@example.com') as viewer \gset
select tests.create_user('owner.b@example.com') as outsider \gset

select tests.create_portfolio(:'owner', 'Portfolio A') as pa \gset
select tests.create_portfolio(:'outsider', 'Portfolio B') as pb \gset
select tests.add_member(:'pa', :'manager', 'manager');
select tests.add_member(:'pa', :'accountant', 'accountant');
select tests.add_member(:'pa', :'viewer', 'viewer');

select tests.create_rental(:'pa') as ra \gset
select tests.create_rental(:'pb') as rb \gset
select tests.create_lease(:'pa', :'ra', '2026-10-01') as la \gset
select tests.create_lease(:'pb', :'rb', '2026-10-01') as lb \gset
select (:'ra')::jsonb ->> 'property_id' as prop_a, (:'ra')::jsonb ->> 'unit_id' as unit_a,
       (:'ra')::jsonb ->> 'tenant_id' as tenant_a \gset
select (:'rb')::jsonb ->> 'property_id' as prop_b, (:'rb')::jsonb ->> 'unit_id' as unit_b,
       (:'rb')::jsonb ->> 'tenant_id' as tenant_b \gset

-- Reads ----------------------------------------------------------------------
select tests.authenticate_as(:'viewer');
select is((select count(*)::integer from public.properties), 1, 'viewer reads properties');
select is((select count(*)::integer from public.leases), 1, 'viewer reads leases');
select ok((select count(*) from public.charges) >= 1, 'viewer reads charges');
select is((select count(*)::integer from public.audit_logs), 0, 'viewer cannot read the audit trail');

select tests.authenticate_as(:'manager');
select ok((select count(*) from public.audit_logs) > 0, 'manager reads the audit trail');

select tests.authenticate_as(:'outsider');
select is((select count(*)::integer from public.properties where portfolio_id = :'pa'), 0, 'outsider sees no properties of A');
select is((select count(*)::integer from public.units where portfolio_id = :'pa'), 0, 'outsider sees no units of A');
select is((select count(*)::integer from public.tenants where portfolio_id = :'pa'), 0, 'outsider sees no tenants of A');
select is((select count(*)::integer from public.leases where portfolio_id = :'pa'), 0, 'outsider sees no leases of A');
select is((select count(*)::integer from public.charges where portfolio_id = :'pa'), 0, 'outsider sees no charges of A');
select is((select count(*)::integer from public.portfolio_members where portfolio_id = :'pa'), 0, 'outsider sees no members of A');
select is((select count(*)::integer from public.rent_changes where portfolio_id = :'pa'), 0, 'outsider sees no rent history of A');
select is((select count(*)::integer from public.unit_occupancy where portfolio_id = :'pa'), 0, 'views respect RLS for outsiders');
select is((select count(*)::integer from public.lease_balances where portfolio_id = :'pa'), 0, 'balance view respects RLS');

select tests.authenticate_as_anon();
select throws_ok($$select count(*) from public.properties$$, '42501', null, 'anon cannot read tables at all');

-- Writes: properties / units / tenants (owner + manager) ---------------------
select tests.authenticate_as(:'manager');
select lives_ok(
  format($f$insert into public.properties (portfolio_id, name, city, province) values (%L, 'Mgr House', 'Lahore', 'punjab')$f$, :'pa'),
  'manager creates properties'
);
select lives_ok(
  format($f$insert into public.tenants (portfolio_id, full_name) values (%L, 'New Tenant')$f$, :'pa'),
  'manager creates tenants'
);
select isnt_empty(
  format($f$update public.units set asking_rent = 47000 where id = %L returning id$f$, :'unit_a'),
  'manager updates units'
);
select is_empty(
  format($f$delete from public.tenants where full_name = 'New Tenant' and portfolio_id = %L returning id$f$, :'pa'),
  'manager cannot delete tenants'
);

select tests.authenticate_as(:'accountant');
select throws_ok(
  format($f$insert into public.properties (portfolio_id, name, city, province) values (%L, 'Acc House', 'Lahore', 'punjab')$f$, :'pa'),
  '42501', null, 'accountant cannot create properties'
);
select is_empty(
  format($f$update public.properties set name = 'Renamed' where id = %L returning id$f$, :'prop_a'),
  'accountant cannot update properties'
);

select tests.authenticate_as(:'viewer');
select throws_ok(
  format($f$insert into public.tenants (portfolio_id, full_name) values (%L, 'Viewer Tenant')$f$, :'pa'),
  '42501', null, 'viewer cannot create tenants'
);
select is_empty(
  format($f$update public.tenants set notes = 'x' where id = %L returning id$f$, :'tenant_a'),
  'viewer cannot update tenants'
);
select is_empty(
  format($f$delete from public.properties where id = %L returning id$f$, :'prop_a'),
  'viewer cannot delete properties'
);

select tests.authenticate_as(:'owner');
select isnt_empty(
  format($f$delete from public.tenants where full_name = 'New Tenant' and portfolio_id = %L returning id$f$, :'pa'),
  'owner deletes tenants without history'
);
select throws_ok(
  format($f$delete from public.tenants where id = %L$f$, :'tenant_a'),
  '23503', null, 'tenants with tenancies cannot be deleted (archive instead)'
);

-- Writes: leases (owner + manager; rent/status only through RPCs) -------------
select tests.authenticate_as(:'manager');
select isnt_empty(
  format($f$update public.leases set police_status = 'submitted', police_reference = 'TRS-123' where id = %L returning id$f$, :'la'),
  'manager records police registration progress'
);
select throws_ok(
  format($f$update public.leases set monthly_rent = 1 where id = %L$f$, :'la'),
  '42501', null, 'rent cannot be edited directly (change_rent RPC only)'
);
select throws_ok(
  format($f$update public.leases set status = 'ended' where id = %L$f$, :'la'),
  '42501', null, 'status cannot be edited directly (end_lease RPC only)'
);
select tests.authenticate_as(:'accountant');
select is_empty(
  format($f$update public.leases set notes = 'x' where id = %L returning id$f$, :'la'),
  'accountant cannot edit leases'
);

-- Writes: charges (owner + manager + accountant; never deleted) --------------
select lives_ok(
  format($f$insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, description)
            values (%L, %L, 'electricity', '2026-11-10', 6200, 'LESCO bill')$f$, :'pa', :'la'),
  'accountant adds manual charges'
);
select throws_ok(
  format($f$insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, paid_amount)
            values (%L, %L, 'other', '2026-11-10', 100, 100)$f$, :'pa', :'la'),
  '42501', null, 'clients cannot set paid_amount'
);
select throws_ok(
  format($f$delete from public.charges where lease_id = %L$f$, :'la'),
  '42501', null, 'charges can never be deleted by clients'
);
select tests.authenticate_as(:'viewer');
select throws_ok(
  format($f$insert into public.charges (portfolio_id, lease_id, kind, due_date, amount)
            values (%L, %L, 'other', '2026-11-10', 100)$f$, :'pa', :'la'),
  '42501', null, 'viewer cannot add charges'
);
select tests.authenticate_as(:'manager');
select throws_ok(
  format($f$update public.charges set description = 'x' where lease_id = %L$f$, :'la'),
  '42501', null, 'charges cannot be updated directly (update_charge RPC only)'
);
select throws_ok(
  format($f$select public.update_charge(id, 1) from public.charges where lease_id = %L and kind = 'rent'$f$, :'la'),
  '22023', 'charge_not_editable', 'automatic rent charges cannot be re-priced by hand'
);

-- Payments are written only through RPCs ---------------------------------------
select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$insert into public.payments (portfolio_id, lease_id, amount, paid_on, method, receipt_number, idempotency_key)
            values (%L, %L, 1, '2026-11-01', 'cash', 'X', gen_random_uuid())$f$, :'pa', :'la'),
  '42501', null, 'even owners cannot insert payments directly'
);
select throws_ok(
  $$update public.payment_allocations set amount = 1$$, '42501', null,
  'allocations are read-only for clients'
);

-- Writes: operations -----------------------------------------------------------
select tests.authenticate_as(:'accountant');
select lives_ok(
  format($f$insert into public.expenses (portfolio_id, property_id, category, amount, spent_on)
            values (%L, %L, 'repairs_maintenance', 3500, '2026-11-02')$f$, :'pa', :'prop_a'),
  'accountant records expenses'
);
select is_empty(
  format($f$delete from public.expenses where portfolio_id = %L returning id$f$, :'pa'),
  'accountant cannot delete expenses'
);
select throws_ok(
  format($f$insert into public.utility_accounts (portfolio_id, property_id, type) values (%L, %L, 'electricity')$f$, :'pa', :'prop_a'),
  '42501', null, 'accountant cannot add utility connections'
);
select throws_ok(
  format($f$insert into public.maintenance_requests (portfolio_id, property_id, title) values (%L, %L, 'Leak')$f$, :'pa', :'prop_a'),
  '42501', null, 'accountant cannot open maintenance jobs'
);
select tests.authenticate_as(:'manager');
select lives_ok(
  format($f$insert into public.utility_accounts (portfolio_id, property_id, type, provider, reference_number)
            values (%L, %L, 'electricity', 'lesco', '09269330553008')$f$, :'pa', :'prop_a'),
  'manager adds utility connections'
);
select lives_ok(
  format($f$insert into public.maintenance_requests (portfolio_id, property_id, unit_id, title, priority)
            values (%L, %L, %L, 'Seepage in bathroom', 'high')$f$, :'pa', :'prop_a', :'unit_a'),
  'manager opens maintenance jobs'
);
select isnt_empty(
  format($f$delete from public.expenses where portfolio_id = %L returning id$f$, :'pa'),
  'manager deletes expenses'
);

-- Cash handovers: the giver records; only owners confirm ----------------------
select lives_ok(
  format($f$insert into public.cash_handovers (portfolio_id, from_user_id, to_user_id, amount, handed_over_on)
            values (%L, %L, %L, 45000, '2026-11-02')$f$, :'pa', :'manager', :'owner'),
  'a caretaker records handing over cash'
);
select throws_ok(
  format($f$insert into public.cash_handovers (portfolio_id, from_user_id, amount, handed_over_on)
            values (%L, %L, 45000, '2026-11-02')$f$, :'pa', :'accountant'),
  '42501', null, 'members cannot record handovers on behalf of others'
);
select throws_ok(
  format('select public.confirm_cash_handover(%L)', (select id from public.cash_handovers limit 1)),
  '42501', 'forbidden', 'only owners confirm handovers'
);
select tests.authenticate_as(:'owner');
select isnt(
  (public.confirm_cash_handover((select id from public.cash_handovers limit 1))).confirmed_at,
  null,
  'owners confirm handovers'
);

-- Tenant isolation through composite foreign keys ------------------------------
select tests.authenticate_as(:'manager');
select throws_ok(
  format($f$insert into public.units (portfolio_id, property_id, label) values (%L, %L, 'Forged')$f$, :'pa', :'prop_b'),
  '23503', null, 'a unit cannot point at another portfolio''s property'
);
select throws_ok(
  format($f$insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent)
            values (%L, %L, %L, '2026-11-01', 1000)$f$, :'pa', :'unit_b', :'tenant_a'),
  '23503', null, 'a lease cannot use another portfolio''s unit'
);
select throws_ok(
  format($f$insert into public.charges (portfolio_id, lease_id, kind, due_date, amount)
            values (%L, %L, 'other', '2026-11-10', 1)$f$, :'pa', :'lb'),
  '23503', null, 'a charge cannot target another portfolio''s lease'
);
select throws_ok(
  format($f$insert into public.units (portfolio_id, property_id, label) values (%L, %L, 'Forged')$f$, :'pb', :'prop_b'),
  '42501', null, 'members cannot write into portfolios they do not belong to'
);
select throws_ok(
  format($f$insert into public.expenses (portfolio_id, property_id, unit_id, category, amount, spent_on)
            values (%L, %L, %L, 'other', 1, '2026-11-01')$f$, :'pa', :'prop_a', :'unit_b'),
  '23503', null, 'an expense unit must belong to the expense''s property'
);
select throws_ok(
  format($f$update public.properties set portfolio_id = %L where id = %L$f$, :'pb', :'prop_a'),
  '42501', null, 'rows cannot be moved to another portfolio (portfolio_id is not updatable)'
);

-- Payment RPCs enforce roles ---------------------------------------------------
select tests.authenticate_as(:'viewer');
select throws_ok(
  format($f$select public.record_payment(%L, 1000, '2026-11-02', 'cash', gen_random_uuid())$f$, :'la'),
  '42501', 'forbidden', 'viewers cannot record payments'
);
select tests.authenticate_as(:'outsider');
select throws_ok(
  format($f$select public.record_payment(%L, 1000, '2026-11-02', 'cash', gen_random_uuid())$f$, :'la'),
  '42501', 'forbidden', 'outsiders cannot record payments on foreign leases'
);
select throws_ok(
  format($f$select public.get_dashboard(%L)$f$, :'pa'),
  '42501', 'forbidden', 'outsiders cannot read foreign dashboards'
);
select tests.authenticate_as(:'accountant');
select lives_ok(
  format($f$select public.record_payment(%L, 1000, '2026-11-02', 'cash', gen_random_uuid())$f$, :'la'),
  'accountants record payments'
);
select throws_ok(
  format($f$select public.void_payment((select id from public.payments where lease_id = %L limit 1), 'mistake')$f$, :'la'),
  '42501', 'forbidden', 'accountants cannot void payments'
);
select throws_ok(
  format($f$select public.change_rent(%L, '2026-12-01', 50000)$f$, :'la'),
  '42501', 'forbidden', 'accountants cannot change rent'
);

-- Service role and admin functions ---------------------------------------------
select tests.authenticate_as(:'owner');
select throws_ok(
  format('select public.admin_delete_account_data(%L)', :'owner'),
  '42501', null, 'end users cannot call admin functions'
);
select tests.authenticate_as_service_role();
select is(
  (select count(*)::integer from public.admin_account_deletion_scope(:'owner')),
  1, 'the service role can inspect the account-deletion scope'
);

select * from finish();
rollback;
