-- Identity checks (20261108200216_identity_checks.sql and
-- 20261108200227_identity_checks_validate.sql): every stored phone number and
-- CNIC passes exactly the rules mm_core reads back (PhoneNumber.fromE164,
-- Cnic.parse). The value-by-value agreement is the generated
-- 20_identity_contract.test.sql (contracts/identity_vectors.json); this suite
-- checks that the rules are on every column, validated, and enforced for the
-- app's own writes. What a migration does to existing rows is
-- tool/db/upgrade/20261108200216.*.sql.
begin;
\ir _helpers.psql
select plan(42);

select tests.create_user('identity-owner@example.com') as owner \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_rental(:'pid') as rental \gset
select (:'rental')::jsonb ->> 'tenant_id' as tenant \gset
select (:'rental')::jsonb ->> 'property_id' as property \gset
select tests.create_lease(:'pid', :'rental', '2026-11-01') as lease \gset
insert into public.lease_occupants (portfolio_id, lease_id, full_name)
values (:'pid', :'lease', 'Occupant') returning id as occupant \gset
insert into public.maintenance_requests (portfolio_id, property_id, title)
values (:'pid', :'property', 'Leaking tap') returning id as request \gset

-- ---------------------------------------------------------------------------
-- The rules
-- ---------------------------------------------------------------------------

select ok(
  (select bool_and(p.provolatile = 'i' and p.proisstrict and not p.prosecdef
                   and coalesce(p.proconfig @> array['search_path=""'], false))
   from pg_proc p
   where p.oid in ('app.is_valid_phone(text)'::regprocedure, 'app.is_valid_cnic(text)'::regprocedure)),
  'is_valid_phone and is_valid_cnic are immutable, strict, SECURITY INVOKER, with an empty search_path'
);
select ok(
  has_function_privilege('authenticated', 'app.is_valid_phone(text)', 'execute')
  and has_function_privilege('authenticated', 'app.is_valid_cnic(text)', 'execute')
  and has_function_privilege('service_role', 'app.is_valid_phone(text)', 'execute')
  and has_function_privilege('service_role', 'app.is_valid_cnic(text)', 'execute'),
  'the writing roles can evaluate the rules their CHECKs call'
);
select is(app.is_valid_phone(null), null, 'is_valid_phone(NULL) is NULL, so optional columns pass');
select is(app.is_valid_cnic(null), null, 'is_valid_cnic(NULL) is NULL, so optional columns pass');

-- ---------------------------------------------------------------------------
-- On every column, validated
-- ---------------------------------------------------------------------------

select set_eq(
  $$select c.conrelid::regclass::text || '.' || c.conname
    from pg_constraint c
    where c.contype = 'c' and c.convalidated
      and pg_get_constraintdef(c.oid) ~ '^CHECK \(app\.is_valid_phone\([a-z0-9_]+\)\)$'$$,
  $$values ('tenants.tenants_phone_check'), ('tenants.tenants_alt_phone_check'),
           ('tenants.tenants_emergency_contact_phone_check'), ('tenants.tenants_reference1_phone_check'),
           ('tenants.tenants_reference2_phone_check'), ('profiles.profiles_phone_check'),
           ('portfolios.portfolios_landlord_phone_check'), ('lease_occupants.lease_occupants_phone_check'),
           ('maintenance_requests.maintenance_requests_vendor_phone_check')$$,
  'the nine phone columns have a validated CHECK calling app.is_valid_phone'
);
select set_eq(
  $$select c.conrelid::regclass::text || '.' || c.conname
    from pg_constraint c
    where c.contype = 'c' and c.convalidated
      and pg_get_constraintdef(c.oid) ~ '^CHECK \(app\.is_valid_cnic\(cnic\)\)$'$$,
  $$values ('tenants.tenants_cnic_check'), ('lease_occupants.lease_occupants_cnic_check')$$,
  'both CNIC columns have a validated CHECK calling app.is_valid_cnic'
);
select is(
  (select coalesce(array_agg(format('%s.%s', a.attrelid::regclass, a.attname) order by 1), '{}')
   from pg_attribute a
   join pg_class r on r.oid = a.attrelid and r.relkind = 'r'
   where r.relnamespace = 'public'::regnamespace
     and a.attnum > 0 and not a.attisdropped
     and (a.attname ~ 'phone$' or a.attname = 'cnic')
     and not exists (
       select 1 from pg_constraint c
       where c.conrelid = a.attrelid and c.contype = 'c' and c.convalidated
         and c.conkey = array[a.attnum]
         and pg_get_constraintdef(c.oid) ~ ('app\.is_valid_(phone|cnic)\(' || a.attname || '\)')
     )),
  '{}'::text[],
  'every public column named *phone or cnic has a validated identity CHECK (new columns too)'
);
select is(
  (select coalesce(array_agg(c.conname::text order by c.conname), '{}')
   from pg_constraint c
   where c.connamespace = 'public'::regnamespace and c.contype = 'c' and not c.convalidated),
  '{}'::text[],
  'no CHECK in public is left NOT VALID'
);
select is(
  (select coalesce(array_agg(c.conname::text order by c.conname), '{}')
   from pg_constraint c
   where c.connamespace = 'public'::regnamespace and c.contype = 'c'
     and (pg_get_constraintdef(c.oid) like '%{7,14}%'
          or pg_get_constraintdef(c.oid) like '%[1-9][0-9]{12}%')),
  '{}'::text[],
  'no CHECK keeps the old phone or CNIC pattern'
);

-- Reviewed and unchanged: these already match their validators exactly.
select is(
  (select pg_get_constraintdef(oid) from pg_constraint where conname = 'portfolios_raast_id_check'),
  'CHECK ((raast_id ~ ''^\+923[0-9]{9}$''::text))',
  'raast_id stays a Pakistani mobile (the app requires PhoneNumber.isMobile)'
);
select is(
  (select pg_get_constraintdef(oid) from pg_constraint where conname = 'portfolios_bank_iban_check'),
  'CHECK (((bank_iban ~ ''^PK[0-9]{2}[A-Z]{4}[A-Z0-9]{16}$''::text) AND app.is_valid_iban(bank_iban)))',
  'bank_iban stays Iban.parse without foreign IBANs'
);
select is(
  (select pg_get_constraintdef(oid) from pg_constraint where conname = 'tenants_ntn_check'),
  'CHECK ((ntn ~ ''^[0-9A-Z][0-9A-Z-]{5,14}$''::text))',
  'ntn stays the app''s Tenant.ntnPattern'
);

-- ---------------------------------------------------------------------------
-- Enforced on each column
-- ---------------------------------------------------------------------------

-- '+92300123456' (a mobile one digit short) is the value the review found
-- breaking the dashboard; the old CHECK accepted it everywhere.
select throws_ok(format('update public.tenants set phone = %L where id = %L', '+92300123456', :'tenant'),
  '23514', null, 'tenants.phone refuses +92300123456');
select throws_ok(format('update public.tenants set alt_phone = %L where id = %L', '+92300123456', :'tenant'),
  '23514', null, 'tenants.alt_phone refuses +92300123456');
select throws_ok(format('update public.tenants set emergency_contact_phone = %L where id = %L',
  '+92300123456', :'tenant'), '23514', null, 'tenants.emergency_contact_phone refuses +92300123456');
select throws_ok(format('update public.tenants set reference1_phone = %L where id = %L',
  '+92300123456', :'tenant'), '23514', null, 'tenants.reference1_phone refuses +92300123456');
select throws_ok(format('update public.tenants set reference2_phone = %L where id = %L',
  '+92300123456', :'tenant'), '23514', null, 'tenants.reference2_phone refuses +92300123456');
select throws_ok(format('update public.profiles set phone = %L where id = %L', '+92300123456', :'owner'),
  '23514', null, 'profiles.phone refuses +92300123456');
select throws_ok(format('update public.portfolios set landlord_phone = %L where id = %L',
  '+92300123456', :'pid'), '23514', null, 'portfolios.landlord_phone refuses +92300123456');
select throws_ok(format('update public.lease_occupants set phone = %L where id = %L',
  '+92300123456', :'occupant'), '23514', null, 'lease_occupants.phone refuses +92300123456');
select throws_ok(format('update public.maintenance_requests set vendor_phone = %L where id = %L',
  '+92300123456', :'request'), '23514', null, 'maintenance_requests.vendor_phone refuses +92300123456');
select throws_ok(format('update public.tenants set cnic = %L where id = %L', '1111111111111', :'tenant'),
  '23514', null, 'tenants.cnic refuses one digit repeated');
select throws_ok(format('update public.lease_occupants set cnic = %L where id = %L',
  '1111111111111', :'occupant'), '23514', null, 'lease_occupants.cnic refuses one digit repeated');

-- Valid values, the shortest and longest of each kind, and NULL still pass.
select lives_ok(format(
  'update public.tenants set phone = %L, alt_phone = %L, emergency_contact_phone = %L, '
  'reference1_phone = %L, reference2_phone = %L, cnic = %L where id = %L',
  '+923001234567', '+9251555123', '+9258212345678', '+12345678', '+123456789012345',
  '3520212345671', :'tenant'), 'tenants accept a mobile, fixed lines of 8 and 11 digits and foreign numbers');
select lives_ok(format('update public.profiles set phone = %L where id = %L', '+924235550123', :'owner'),
  'profiles.phone accepts a Lahore fixed line');
select lives_ok(format('update public.portfolios set landlord_phone = %L where id = %L',
  '+92111123456', :'pid'), 'portfolios.landlord_phone accepts a UAN');
select lives_ok(format('update public.lease_occupants set phone = %L, cnic = %L where id = %L',
  '+92800123456', '9520212345671', :'occupant'), 'lease_occupants accept a toll-free number and any region');
select lives_ok(format('update public.maintenance_requests set vendor_phone = %L where id = %L',
  '+971501234567', :'request'), 'maintenance_requests.vendor_phone accepts a foreign mobile');
select lives_ok(format(
  'update public.tenants set phone = null, alt_phone = null, emergency_contact_phone = null, '
  'reference1_phone = null, reference2_phone = null, cnic = null where id = %L', :'tenant'),
  'tenants accept NULL in every phone and CNIC column');
select lives_ok(format('update public.lease_occupants set phone = null, cnic = null where id = %L',
  :'occupant'), 'lease_occupants accept NULL');
select lives_ok(format('update public.profiles set phone = null where id = %L', :'owner'),
  'profiles accept NULL');

-- ---------------------------------------------------------------------------
-- Through the API, as the owner
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'owner');
select throws_ok(format(
  'insert into public.tenants (portfolio_id, full_name, phone) values (%L, %L, %L)',
  :'pid', 'Short Number', '+92300123456'),
  '23514', null, 'an owner cannot add a tenant with a mobile one digit short');
select throws_ok(format(
  'insert into public.tenants (portfolio_id, full_name, cnic) values (%L, %L, %L)',
  :'pid', 'Placeholder CNIC', '1111111111111'),
  '23514', null, 'an owner cannot add a tenant with a placeholder CNIC');
select throws_ok(format(
  'insert into public.tenants (portfolio_id, full_name, phone) values (%L, %L, %L)',
  :'pid', 'Trunk Zero', '+920300123456'),
  '23514', null, 'an owner cannot add a tenant with +92 followed by the trunk 0');
select throws_ok(format(
  'insert into public.tenants (portfolio_id, full_name, emergency_contact_phone) values (%L, %L, %L)',
  :'pid', 'Seven Digits', '+921234567'),
  '23514', null, 'an owner cannot add a 7-digit Pakistani fixed line');
select lives_ok(format(
  'insert into public.tenants (portfolio_id, full_name, phone, cnic) values (%L, %L, %L, %L)',
  :'pid', 'Good Numbers', '+923451234567', '4210198765432'),
  'an owner adds a tenant with a valid mobile and CNIC');
select throws_ok(format('update public.profiles set phone = %L where id = %L', '+9230012345678', :'owner'),
  '23514', null, 'a user cannot save a mobile one digit long on their profile');
select lives_ok(format('update public.profiles set phone = %L where id = %L', '+923001234567', :'owner'),
  'a user saves a valid mobile on their profile');
select throws_ok(format('update public.portfolios set landlord_phone = %L where id = %L',
  '+92123456789012', :'pid'), '23514', null, 'an owner cannot save a 12-digit Pakistani fixed line');
select throws_ok(format(
  'insert into public.lease_occupants (portfolio_id, lease_id, full_name, cnic) values (%L, %L, %L, %L)',
  :'pid', :'lease', 'Zeros', '0000000000000'),
  '23514', null, 'an owner cannot add an occupant with a CNIC of zeros');
select throws_ok(format(
  'insert into public.maintenance_requests (portfolio_id, property_id, title, vendor_phone) values (%L, %L, %L, %L)',
  :'pid', :'property', 'Paint', '+92 300 1234567'),
  '23514', null, 'an owner cannot save a vendor number with spaces (the app stores E.164)');
select is(
  (select phone from public.profiles where id = :'owner'::uuid),
  '+923001234567',
  'the valid profile number was saved'
);
select tests.clear_authentication();

select * from finish();
rollback;
