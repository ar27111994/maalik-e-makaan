-- Checks the rows seeded by 20261108200216.before.sql after
-- 20261108200216_identity_checks.sql and the migrations after it: every
-- value is unchanged, the eleven CHECKs call the new rules and are
-- validated, and a value only the old CHECK accepted is now refused.
do $$
declare
  v_got text;
  v_want text;
  v_checks text;
begin
  select string_agg(format('%s|%s|%s|%s|%s|%s|%s', id, phone, alt_phone, emergency_contact_phone,
                           reference1_phone, reference2_phone, cnic), ' ' order by id)
  into v_got
  from public.tenants
  where portfolio_id = '00000000-0000-4000-8000-0000000d0001';
  v_want := '00000000-0000-4000-8000-0000000f0001|+923001234567|+9251555123|+9258212345678|'
            '+12345678|+123456789012345|3520212345671 '
            '00000000-0000-4000-8000-0000000f0002|||||| '
            '00000000-0000-4000-8000-0000000f0003|+971501234567||+9112345678|||1000000000000';
  if v_got is distinct from v_want then
    raise exception 'tenants changed: %', v_got;
  end if;

  select string_agg(format('%s|%s|%s', id, phone, cnic), ' ' order by id) into v_got
  from public.lease_occupants where portfolio_id = '00000000-0000-4000-8000-0000000d0001';
  if v_got is distinct from '00000000-0000-4000-8000-0000000f0201|+92800123456|9520212345671 '
                            '00000000-0000-4000-8000-0000000f0202||' then
    raise exception 'lease_occupants changed: %', v_got;
  end if;

  select string_agg(format('%s|%s', id, phone), ' ' order by id) into v_got
  from public.profiles
  where id in ('00000000-0000-4000-8000-0000000c0001', '00000000-0000-4000-8000-0000000c0002');
  if v_got is distinct from '00000000-0000-4000-8000-0000000c0001|+924235550123 '
                            '00000000-0000-4000-8000-0000000c0002|' then
    raise exception 'profiles changed: %', v_got;
  end if;

  select format('%s|%s', landlord_phone, raast_id) into v_got
  from public.portfolios where id = '00000000-0000-4000-8000-0000000d0001';
  if v_got is distinct from '+92111123456|+923211234567' then
    raise exception 'portfolio changed: %', v_got;
  end if;

  select vendor_phone into v_got
  from public.maintenance_requests where id = '00000000-0000-4000-8000-0000000f0301';
  if v_got is distinct from '+92515551234' then
    raise exception 'maintenance request changed: %', v_got;
  end if;

  select string_agg(format('%s.%s', c.conrelid::regclass, c.conname), ' '
                    order by c.conrelid::regclass::text, c.conname)
  into v_checks
  from pg_constraint c
  where c.contype = 'c'
    and c.convalidated
    and pg_get_constraintdef(c.oid) ~ '^CHECK \(app\.is_valid_(phone|cnic)\([a-z0-9_]+\)\)$';
  if v_checks is distinct from
     'lease_occupants.lease_occupants_cnic_check lease_occupants.lease_occupants_phone_check '
     'maintenance_requests.maintenance_requests_vendor_phone_check '
     'portfolios.portfolios_landlord_phone_check profiles.profiles_phone_check '
     'tenants.tenants_alt_phone_check tenants.tenants_cnic_check '
     'tenants.tenants_emergency_contact_phone_check tenants.tenants_phone_check '
     'tenants.tenants_reference1_phone_check tenants.tenants_reference2_phone_check' then
    raise exception 'validated identity CHECKs: %', v_checks;
  end if;

  begin
    update public.tenants set phone = '+92300123456'
    where id = '00000000-0000-4000-8000-0000000f0002';
    raise exception 'tenants.phone accepted +92300123456';
  exception when check_violation then
    null;
  end;
  begin
    update public.lease_occupants set cnic = '1111111111111'
    where id = '00000000-0000-4000-8000-0000000f0202';
    raise exception 'lease_occupants.cnic accepted 1111111111111';
  exception when check_violation then
    null;
  end;
end
$$;
