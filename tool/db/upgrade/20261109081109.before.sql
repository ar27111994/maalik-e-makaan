-- Rows that exist when 20261109081109_uat_display_fixes.sql is applied (D6
-- of docs/uat.md): run on a database migrated up to
-- 20261108200227_identity_checks_validate.sql. Checked by
-- 20261109081109.after.sql.
--
-- One lease (rent 1,000 due on the 5th, 5 days' grace, a fixed 100 late
-- fee) with October's and November's rent overdue on 12 November, so the
-- old daily job writes two automatic fees noted 'Late fee'. Then:
--   October's fee   keeps the job's note                -> note removed
--   November's fee  is voided                           -> note kept
--   a manual charge noted 'Late fee' by a member        -> note kept
--   October's rent  noted 'Paid late' by a member       -> note kept
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-4000-8000-0000000c0001', 'owner-d6@example.com', now());
insert into public.portfolios (id, name, created_by) values
  ('00000000-0000-4000-8000-0000000d0001', 'Upgrade D6', '00000000-0000-4000-8000-0000000c0001');
insert into public.portfolio_members (portfolio_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000d0001', '00000000-0000-4000-8000-0000000c0001', 'owner');
insert into public.properties (id, portfolio_id, name, city, province) values
  ('00000000-0000-4000-8000-0000000e0001', '00000000-0000-4000-8000-0000000d0001', 'House D6', 'Lahore', 'punjab');
insert into public.units (id, portfolio_id, property_id, label) values
  ('00000000-0000-4000-8000-0000000e0002', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000e0001', 'Ground floor');
insert into public.tenants (id, portfolio_id, full_name) values
  ('00000000-0000-4000-8000-0000000e0003', '00000000-0000-4000-8000-0000000d0001', 'Tenant D6');
insert into public.leases
  (id, portfolio_id, unit_id, tenant_id, start_date, billing_starts_on, monthly_rent, rent_due_day,
   grace_days, late_fee_type, late_fee_value)
values
  ('00000000-0000-4000-8000-0000000e0004', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000e0002', '00000000-0000-4000-8000-0000000e0003',
   '2026-10-01', '2026-10-01', 1000, 5, 5, 'flat', 100);

select private.sync_lease_billing('00000000-0000-4000-8000-0000000e0004', '2026-11-12');
select private.assess_late_fees('00000000-0000-4000-8000-0000000e0004', '2026-11-12');

do $$
begin
  if (select count(*) from public.charges
      where lease_id = '00000000-0000-4000-8000-0000000e0004' and kind = 'late_fee'
        and source = 'auto_late_fee' and description = 'Late fee') <> 2 then
    raise exception 'upgrade 20261109081109: the old job did not write two fees noted ''Late fee''';
  end if;
end
$$;

update public.charges set voided_at = now(), void_reason = 'Waived by the owner'
where lease_id = '00000000-0000-4000-8000-0000000e0004' and kind = 'late_fee' and period_month = '2026-11-01';
update public.charges set description = 'Paid late'
where lease_id = '00000000-0000-4000-8000-0000000e0004' and kind = 'rent' and period_month = '2026-10-01';
insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, source, description)
values ('00000000-0000-4000-8000-0000000d0001', '00000000-0000-4000-8000-0000000e0004', 'other',
        '2026-11-12', 50, 'manual', 'Late fee');
