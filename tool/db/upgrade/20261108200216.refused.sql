-- Rows 20261108200216_identity_checks.sql must refuse to run on: values the
-- old CHECKs accepted and mm_core cannot read back. Seeded on a database
-- migrated up to 20261108082804_invitation_findings.sql; applying the
-- migration must then fail with each "-- expect:" line in its error and
-- leave the database exactly as it was (tool/db/upgrade_test.sh compares a
-- pg_dump from before and after the attempt). One row of each kind the
-- new rules accept is there too, and is not counted.
--
-- expect: identity checks: stored values break the new phone or CNIC rules; nothing was changed
-- expect: lease_occupants.cnic: 1, lease_occupants.phone: 1, maintenance_requests.vendor_phone: 1, portfolios.landlord_phone: 1, profiles.phone: 1, tenants.alt_phone: 1, tenants.cnic: 2, tenants.emergency_contact_phone: 1, tenants.phone: 2, tenants.reference1_phone: 1, tenants.reference2_phone: 1.
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-4000-8000-0000000c0011', 'refused-owner@example.com', now());

update public.profiles set phone = '+9230012345678'
where id = '00000000-0000-4000-8000-0000000c0011';

insert into public.portfolios (id, name, created_by, landlord_phone) values
  ('00000000-0000-4000-8000-0000000d0011', 'Refused P', '00000000-0000-4000-8000-0000000c0011',
   '+92123456789012');

insert into public.portfolio_members (portfolio_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000d0011', '00000000-0000-4000-8000-0000000c0011', 'owner');

insert into public.properties (id, portfolio_id, name, city, province) values
  ('00000000-0000-4000-8000-0000000e0011', '00000000-0000-4000-8000-0000000d0011', 'Refused House',
   'Karachi', 'sindh');

insert into public.units (id, portfolio_id, property_id, label) values
  ('00000000-0000-4000-8000-0000000e0012', '00000000-0000-4000-8000-0000000d0011',
   '00000000-0000-4000-8000-0000000e0011', 'Flat 1');

insert into public.tenants
  (id, portfolio_id, full_name, phone, alt_phone, emergency_contact_phone, reference1_phone,
   reference2_phone, cnic)
values
  ('00000000-0000-4000-8000-0000000f0011', '00000000-0000-4000-8000-0000000d0011', 'Short mobile',
   '+92300123456', '+920300123456', '+921234567', '+92300123456789', '+9230012345678',
   '1111111111111'),
  ('00000000-0000-4000-8000-0000000f0012', '00000000-0000-4000-8000-0000000d0011', 'Also short',
   '+92345123456', null, null, null, null, '9999999999999'),
  ('00000000-0000-4000-8000-0000000f0013', '00000000-0000-4000-8000-0000000d0011', 'Fine',
   '+923001234567', '+924235550123', null, null, null, '3520212345671');

insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, billing_starts_on, monthly_rent)
values
  ('00000000-0000-4000-8000-0000000f0111', '00000000-0000-4000-8000-0000000d0011',
   '00000000-0000-4000-8000-0000000e0012', '00000000-0000-4000-8000-0000000f0013',
   '2026-11-01', '2026-11-01', 30000);

insert into public.lease_occupants (id, portfolio_id, lease_id, full_name, phone, cnic) values
  ('00000000-0000-4000-8000-0000000f0211', '00000000-0000-4000-8000-0000000d0011',
   '00000000-0000-4000-8000-0000000f0111', 'Occupant', '+9230012345', '2222222222222'),
  ('00000000-0000-4000-8000-0000000f0212', '00000000-0000-4000-8000-0000000d0011',
   '00000000-0000-4000-8000-0000000f0111', 'Fine', '+923331234567', '4210198765432');

insert into public.maintenance_requests (id, portfolio_id, property_id, title, vendor_phone) values
  ('00000000-0000-4000-8000-0000000f0311', '00000000-0000-4000-8000-0000000d0011',
   '00000000-0000-4000-8000-0000000e0011', 'Broken lock', '+920511234567');
