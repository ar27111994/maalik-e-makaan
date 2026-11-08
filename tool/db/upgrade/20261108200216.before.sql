-- Rows that exist when 20261108200216_identity_checks.sql is applied: run on
-- a database migrated up to 20261108082804_invitation_findings.sql. Every
-- value passes the old CHECKs and the new rules, and most sit on an edge of
-- the new ones (the shortest and longest Pakistani fixed-line and foreign
-- numbers, a CNIC of an unknown region). The migration must apply, validate
-- its CHECKs and leave every value as it was (20261108200216.after.sql).
-- Values the new rules refuse are 20261108200216.refused.sql.
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-4000-8000-0000000c0001', 'identity-owner@example.com', now()),
  ('00000000-0000-4000-8000-0000000c0002', 'identity-nophone@example.com', now());

update public.profiles set phone = '+924235550123'
where id = '00000000-0000-4000-8000-0000000c0001';

insert into public.portfolios (id, name, created_by, landlord_phone, raast_id) values
  ('00000000-0000-4000-8000-0000000d0001', 'Identity P', '00000000-0000-4000-8000-0000000c0001',
   '+92111123456', '+923211234567');

insert into public.portfolio_members (portfolio_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000d0001', '00000000-0000-4000-8000-0000000c0001', 'owner');

insert into public.properties (id, portfolio_id, name, city, province) values
  ('00000000-0000-4000-8000-0000000e0001', '00000000-0000-4000-8000-0000000d0001', 'Identity House',
   'Lahore', 'punjab');

insert into public.units (id, portfolio_id, property_id, label) values
  ('00000000-0000-4000-8000-0000000e0002', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000e0001', 'Ground floor');

insert into public.tenants
  (id, portfolio_id, full_name, phone, alt_phone, emergency_contact_phone, reference1_phone,
   reference2_phone, cnic)
values
  ('00000000-0000-4000-8000-0000000f0001', '00000000-0000-4000-8000-0000000d0001', 'Edges',
   '+923001234567', '+9251555123', '+9258212345678', '+12345678', '+123456789012345',
   '3520212345671'),
  ('00000000-0000-4000-8000-0000000f0002', '00000000-0000-4000-8000-0000000d0001', 'No numbers',
   null, null, null, null, null, null),
  ('00000000-0000-4000-8000-0000000f0003', '00000000-0000-4000-8000-0000000d0001', 'Abroad',
   '+971501234567', null, '+9112345678', null, null, '1000000000000');

insert into public.leases (id, portfolio_id, unit_id, tenant_id, start_date, billing_starts_on, monthly_rent)
values
  ('00000000-0000-4000-8000-0000000f0101', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000e0002', '00000000-0000-4000-8000-0000000f0001',
   '2026-11-01', '2026-11-01', 45000);

insert into public.lease_occupants (id, portfolio_id, lease_id, full_name, phone, cnic) values
  ('00000000-0000-4000-8000-0000000f0201', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000f0101', 'Occupant', '+92800123456', '9520212345671'),
  ('00000000-0000-4000-8000-0000000f0202', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000f0101', 'Child', null, null);

insert into public.maintenance_requests (id, portfolio_id, property_id, title, vendor_phone) values
  ('00000000-0000-4000-8000-0000000f0301', '00000000-0000-4000-8000-0000000d0001',
   '00000000-0000-4000-8000-0000000e0001', 'Leaking tap', '+92515551234');
