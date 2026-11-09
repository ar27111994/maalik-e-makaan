-- ============================================================================
-- Demo data for LOCAL development and CI end-to-end tests only.
-- Loaded by `supabase db reset` (config.toml [db.seed]); never applied to a
-- hosted project. Dates are relative to "today" so the demo always looks
-- current: some rent is overdue, an agreement is about to expire, a yearly
-- increment was missed, a police registration is pending, an electricity
-- connection in the landlord's name is close to the 200-unit tariff limit.
--
-- Demo logins (password for all: Maalik@2026):
--   ahmed@demo.maalik.local   owner (overseas-based landlord)
--   imran@demo.maalik.local   manager (caretaker in Lahore)
--   sana@demo.maalik.local    accountant
--   usman@demo.maalik.local   viewer (co-owner)
-- ============================================================================

do $$
declare
  v_today date := app.today_pkt();
  v_m0 date := date_trunc('month', app.today_pkt())::date;
  v_password text := extensions.crypt('Maalik@2026', extensions.gen_salt('bf'));
  v_owner uuid := '0d0e0000-0000-4000-8000-000000000001';
  v_manager uuid := '0d0e0000-0000-4000-8000-000000000002';
  v_accountant uuid := '0d0e0000-0000-4000-8000-000000000003';
  v_viewer uuid := '0d0e0000-0000-4000-8000-000000000004';
  v_pid uuid := '0d0e0001-0000-7000-8000-000000000001';
  v_gulberg uuid;
  v_saddar uuid;
  v_clifton uuid;
  v_upper uuid;
  v_lower uuid;
  v_annexe uuid;
  v_shop4 uuid;
  v_shop5 uuid;
  v_shop6 uuid;
  v_flat uuid;
  v_t_bilal uuid;
  v_t_farhan uuid;
  v_t_madina uuid;
  v_t_zafar uuid;
  v_t_ayesha uuid;
  v_l_bilal uuid;
  v_l_farhan uuid;
  v_l_madina uuid;
  v_l_zafar uuid;
  v_l_ayesha uuid;
  v_lesco uuid;
  v_sngpl uuid;
  v_ke uuid;
  v_job uuid;
  v_month date;
  v_user record;
begin
  -- Users ------------------------------------------------------------------
  for v_user in
    select * from (values
      (v_owner, 'ahmed@demo.maalik.local', 'Ahmed Raza', 'en'),
      (v_manager, 'imran@demo.maalik.local', 'Imran Bhatti', 'ur'),
      (v_accountant, 'sana@demo.maalik.local', 'Sana Malik', 'en'),
      (v_viewer, 'usman@demo.maalik.local', 'Usman Raza', 'en')
    ) as u (id, email, full_name, locale)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    )
    values (
      '00000000-0000-0000-0000-000000000000', v_user.id, 'authenticated', 'authenticated',
      v_user.email, v_password, now(),
      '{"provider": "email", "providers": ["email"]}',
      jsonb_build_object('full_name', v_user.full_name, 'locale', v_user.locale),
      now(), now(), '', '', '', ''
    );
    insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at)
    values (
      v_user.id::text, v_user.id,
      jsonb_build_object('sub', v_user.id::text, 'email', v_user.email, 'email_verified', true),
      'email', now()
    );
  end loop;

  -- Portfolio & team -----------------------------------------------------------
  insert into public.portfolios (
    id, name, receipt_prefix, landlord_name, landlord_phone, raast_id, bank_account_title, bank_iban, created_by
  )
  values (
    v_pid, 'Raza Family Properties', 'RFP', 'Ahmed Raza', '+923004567890', '+923004567890',
    'AHMED RAZA', 'PK36SCBL0000001123456702', v_owner
  );
  insert into public.portfolio_members (portfolio_id, user_id, role, invited_by) values
    (v_pid, v_owner, 'owner', null),
    (v_pid, v_manager, 'manager', v_owner),
    (v_pid, v_accountant, 'accountant', v_owner),
    (v_pid, v_viewer, 'viewer', v_owner);

  -- Act as the caretaker for day-to-day records (exercises RLS + RPCs).
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_manager, 'role', 'authenticated')::text, true);

  -- Properties & units -----------------------------------------------------------
  insert into public.properties (portfolio_id, name, type, address_line, locality, city, province,
                                 plot_size, plot_size_unit, covered_area_sqft, estimated_value, value_estimated_on)
  values (v_pid, 'Gulberg House', 'house', 'House 12, Street 4', 'Gulberg III', 'Lahore', 'punjab',
          1, 'kanal', 4500, 95000000, v_m0)
  returning id into v_gulberg;
  insert into public.properties (portfolio_id, name, type, address_line, locality, city, province,
                                 covered_area_sqft, estimated_value, value_estimated_on)
  values (v_pid, 'Saddar Shops', 'plaza', 'Bank Road', 'Saddar', 'Rawalpindi', 'punjab', 1800, 60000000, v_m0)
  returning id into v_saddar;
  insert into public.properties (portfolio_id, name, type, address_line, locality, city, province,
                                 covered_area_sqft, estimated_value, value_estimated_on)
  values (v_pid, 'Clifton Flat', 'apartment', 'Block 5, Sea View Apartments', 'Clifton', 'Karachi', 'sindh',
          1450, 42000000, v_m0)
  returning id into v_clifton;

  insert into public.units (portfolio_id, property_id, label, type, floor_label, bedrooms, bathrooms, covered_area_sqft, asking_rent)
  values (v_pid, v_gulberg, 'Upper portion', 'portion', 'First floor', 3, 3, 1900, 70000) returning id into v_upper;
  insert into public.units (portfolio_id, property_id, label, type, floor_label, bedrooms, bathrooms, covered_area_sqft, asking_rent)
  values (v_pid, v_gulberg, 'Lower portion', 'portion', 'Ground floor', 4, 3, 2100, 85000) returning id into v_lower;
  insert into public.units (portfolio_id, property_id, label, type, bedrooms, bathrooms, covered_area_sqft, asking_rent, furnished)
  values (v_pid, v_gulberg, 'Annexe', 'portion', 1, 1, 500, 35000, true) returning id into v_annexe;
  insert into public.units (portfolio_id, property_id, label, type, floor_label, covered_area_sqft, asking_rent)
  values (v_pid, v_saddar, 'Shop 4', 'shop', 'Ground floor', 600, 125000) returning id into v_shop4;
  insert into public.units (portfolio_id, property_id, label, type, floor_label, covered_area_sqft, asking_rent)
  values (v_pid, v_saddar, 'Shop 5', 'shop', 'Ground floor', 600, 95000) returning id into v_shop5;
  insert into public.units (portfolio_id, property_id, label, type, floor_label, covered_area_sqft, asking_rent, is_available, notes)
  values (v_pid, v_saddar, 'Shop 6', 'shop', 'Ground floor', 600, 90000, false, 'Under renovation (new shutter and wiring).')
  returning id into v_shop6;
  insert into public.units (portfolio_id, property_id, label, type, floor_label, bedrooms, bathrooms, covered_area_sqft, asking_rent)
  values (v_pid, v_clifton, 'Flat 2B', 'apartment', '2nd floor', 3, 2, 1450, 55000) returning id into v_flat;

  -- Tenants ------------------------------------------------------------------------
  insert into public.tenants (portfolio_id, full_name, guardian_name, guardian_relation, cnic, cnic_expiry, phone,
                              occupation, employer, permanent_address, household_size,
                              reference1_name, reference1_phone, consent_recorded_at, consent_note)
  values (v_pid, 'Bilal Ahmed', 'Mushtaq Ahmed', 'son_of', '3520212345671', v_today + 20, '+923001234567',
          'Software engineer', 'Arbisoft', 'Mohalla Islamabad, Sialkot', 4,
          'Kashif Mehmood', '+923211234567', now() - interval '10 months', 'Informed in Urdu: CNIC kept for police registration')
  returning id into v_t_bilal;
  insert into public.tenants (portfolio_id, full_name, guardian_name, guardian_relation, cnic, phone, occupation, household_size)
  values (v_pid, 'Farhan Qureshi', 'Naeem Qureshi', 'son_of', '3520187654321', '+923334567812', 'Pharmacist', 5)
  returning id into v_t_farhan;
  insert into public.tenants (portfolio_id, kind, full_name, ntn, phone, email, deducts_withholding_tax)
  values (v_pid, 'company', 'Al-Madina Traders (Pvt) Ltd', '4231876-5', '+92515551234', 'accounts@almadina.example',
          true)
  returning id into v_t_madina;
  insert into public.tenants (portfolio_id, full_name, guardian_name, guardian_relation, cnic, phone, occupation)
  values (v_pid, 'Zafar Iqbal (Zafar Mobiles)', 'Iqbal Hussain', 'son_of', '3740554321987', '+923455551234', 'Shopkeeper')
  returning id into v_t_zafar;
  insert into public.tenants (portfolio_id, full_name, guardian_name, guardian_relation, cnic, phone, email, occupation)
  values (v_pid, 'Ayesha Siddiqui', 'Kamran Siddiqui', 'wife_of', '4210198765432', '+923012345678',
          'ayesha@example.com', 'Doctor')
  returning id into v_t_ayesha;

  -- Leases ---------------------------------------------------------------------------
  -- Bilal: 11-month agreement that ends soon; police registration done.
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, end_date, monthly_rent, security_deposit,
                             rent_due_day, police_status, police_channel, police_reference, police_registered_on,
                             agreement_signed_on, rent_registrar_status, permitted_use)
  values (v_pid, v_upper, v_t_bilal, (v_m0 - interval '10 months')::date + 14,
          ((v_m0 - interval '10 months')::date + 14 + interval '11 months' - interval '1 day')::date,
          65000, 130000, 5, 'registered', 'online_portal', 'TRS-LHR-88412',
          (v_m0 - interval '10 months')::date + 18, (v_m0 - interval '10 months')::date + 10, 'registered', 'Residential')
  returning id into v_l_bilal;

  -- Farhan: started 14 months ago; yearly increment not yet applied; police pending.
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, security_deposit, rent_due_day,
                             billing_starts_on, police_status, permitted_use)
  values (v_pid, v_lower, v_t_farhan, (v_m0 - interval '14 months')::date, 80000, 160000, 5,
          (v_m0 - interval '6 months')::date, 'pending', 'Residential')
  returning id into v_l_farhan;

  -- Al-Madina Traders: company tenant deducting withholding tax.
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, end_date, monthly_rent, security_deposit,
                             rent_due_day, police_status, permitted_use, increment_percent)
  values (v_pid, v_shop4, v_t_madina, (v_m0 - interval '6 months')::date, (v_m0 + interval '30 months')::date,
          120000, 360000, 1, 'not_required', 'Wholesale trading', 10)
  returning id into v_l_madina;

  -- Zafar Mobiles: daily late fee, two months behind.
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, security_deposit, rent_due_day,
                             grace_days, late_fee_type, late_fee_value, late_fee_cap, police_status, permitted_use)
  values (v_pid, v_shop5, v_t_zafar, (v_m0 - interval '4 months')::date, 90000, 180000, 5,
          5, 'daily', 200, 5000, 'registered', 'Mobile phone retail')
  returning id into v_l_zafar;

  -- Ayesha (Karachi): Sindh's default due date is the 10th.
  insert into public.leases (portfolio_id, unit_id, tenant_id, start_date, monthly_rent, security_deposit, rent_due_day,
                             police_status, police_channel, police_reference, police_registered_on, permitted_use)
  values (v_pid, v_flat, v_t_ayesha, (v_m0 - interval '3 months')::date + 7, 55000, 110000, 10,
          'registered', 'online_portal', 'TRUST-KHI-20931', (v_m0 - interval '3 months')::date + 8, 'Residential')
  returning id into v_l_ayesha;

  insert into public.lease_occupants (portfolio_id, lease_id, full_name, relation, cnic)
  values (v_pid, v_l_bilal, 'Hina Bilal', 'wife', '3520223456789');

  -- Payments (as the caretaker; each through record_payment) --------------------------
  -- Bilal: deposit + every month on time, in cash.
  perform public.record_payment(v_l_bilal, 130000, (v_m0 - interval '10 months')::date + 14, 'cash', gen_random_uuid(), null, 'Security deposit');
  for v_month in select generate_series(v_m0 - interval '10 months', v_m0 - interval '1 month', interval '1 month')::date loop
    perform public.record_payment(
      v_l_bilal,
      (select c.outstanding from public.charges c
       where c.lease_id = v_l_bilal and c.kind = 'rent' and c.period_month = v_month),
      greatest(v_month + 3, (v_m0 - interval '10 months')::date + 14), 'cash', gen_random_uuid());
  end loop;

  -- Farhan: Raast, usually 10-12 days late; current month unpaid.
  perform public.record_payment(v_l_farhan, 160000, (v_m0 - interval '6 months')::date, 'bank_transfer', gen_random_uuid(), 'IBFT-DEP', 'Security deposit (onboarded)');
  for v_month in select generate_series(v_m0 - interval '6 months', v_m0 - interval '1 month', interval '1 month')::date loop
    perform public.record_payment(v_l_farhan, 80000, v_month + 15, 'raast', gen_random_uuid(), 'RAAST-' || to_char(v_month, 'YYMM'));
  end loop;

  -- Al-Madina: bank transfer net of 5% withholding (s.155), with CPR numbers.
  perform public.record_payment(v_l_madina, 360000, (v_m0 - interval '6 months')::date, 'cheque', gen_random_uuid(), 'CHQ-004512', 'Security deposit');
  for v_month in select generate_series(v_m0 - interval '6 months', v_m0, interval '1 month')::date loop
    perform public.record_payment(v_l_madina, 114000, v_month + 2, 'bank_transfer', gen_random_uuid(),
                                  'IBFT-' || to_char(v_month, 'YYMM'), null, 6000, 'CPR-' || to_char(v_month, 'YYYYMM'));
  end loop;

  -- Zafar: deposit and first two months, then partial.
  perform public.record_payment(v_l_zafar, 180000, (v_m0 - interval '4 months')::date, 'cash', gen_random_uuid(), null, 'Security deposit');
  perform public.record_payment(v_l_zafar, 90000, (v_m0 - interval '4 months')::date + 6, 'cash', gen_random_uuid());
  perform public.record_payment(v_l_zafar, 90000, (v_m0 - interval '3 months')::date + 12, 'easypaisa', gen_random_uuid(), 'EP-77123');
  perform public.record_payment(v_l_zafar, 40000, (v_m0 - interval '2 months')::date + 20, 'cash', gen_random_uuid(), null, 'Promised rest next week');

  -- Ayesha: JazzCash, on time.
  perform public.record_payment(v_l_ayesha, 110000, (v_m0 - interval '3 months')::date + 7, 'bank_transfer', gen_random_uuid(), 'IBFT-AYE', 'Security deposit');
  for v_month in select generate_series(v_m0 - interval '3 months', v_m0 - interval '1 month', interval '1 month')::date loop
    perform public.record_payment(
      v_l_ayesha,
      (select c.outstanding from public.charges c
       where c.lease_id = v_l_ayesha and c.kind = 'rent' and c.period_month = v_month),
      least(v_month + 9, v_today), 'jazzcash', gen_random_uuid(), 'JC-' || to_char(v_month, 'YYMM'));
  end loop;

  -- Utilities ---------------------------------------------------------------------------
  insert into public.utility_accounts (portfolio_id, property_id, unit_id, type, provider, reference_number, customer_id,
                                       meter_number, account_title, in_landlord_name, is_protected_consumer, responsibility)
  values (v_pid, v_gulberg, v_upper, 'electricity', 'lesco', '09269330553008', '4312987', 'LE-778812', 'AHMED RAZA',
          true, true, 'tenant')
  returning id into v_lesco;
  insert into public.utility_accounts (portfolio_id, property_id, type, provider, reference_number, account_title,
                                       in_landlord_name, responsibility, is_sub_meter)
  values (v_pid, v_gulberg, 'gas', 'sngpl', '13894567210', 'AHMED RAZA', true, 'shared', false)
  returning id into v_sngpl;
  insert into public.utility_accounts (portfolio_id, property_id, unit_id, type, provider, reference_number, account_title,
                                       in_landlord_name, responsibility)
  values (v_pid, v_clifton, v_flat, 'electricity', 'k_electric', '0400012345678', 'AYESHA SIDDIQUI', false, 'tenant')
  returning id into v_ke;

  insert into public.utility_bills (portfolio_id, utility_account_id, billing_month, amount, due_date, units_consumed,
                                    status, paid_on, paid_by)
  values
    (v_pid, v_lesco, (v_m0 - interval '2 months')::date, 9850, (v_m0 - interval '1 month')::date + 10, 171, 'paid',
     (v_m0 - interval '1 month')::date + 8, 'tenant'),
    (v_pid, v_lesco, (v_m0 - interval '1 month')::date, 11420, v_m0 + 12, 192, 'unpaid', null, null),
    (v_pid, v_sngpl, (v_m0 - interval '1 month')::date, 4380, v_m0 + 15, null, 'unpaid', null, null),
    (v_pid, v_ke, (v_m0 - interval '1 month')::date, 15210, v_m0 + 14, 341, 'paid', v_m0 + 3, 'tenant');

  insert into public.meter_readings (portfolio_id, utility_account_id, lease_id, reading, read_on, context)
  values (v_pid, v_lesco, v_l_bilal, 18744, (v_m0 - interval '10 months')::date + 14, 'move_in');

  -- Maintenance & expenses ------------------------------------------------------------------
  insert into public.maintenance_requests (portfolio_id, property_id, unit_id, lease_id, title, description, category,
                                           priority, status, reported_by, reported_on, assigned_to, vendor_phone, estimated_cost)
  values (v_pid, v_gulberg, v_lower, v_l_farhan, 'Seepage in kitchen wall', 'Damp patch spreading near the sink.',
          'seepage', 'high', 'in_progress', 'Farhan Qureshi', v_today - 6, 'Ustad Rafiq (mason)', '+923006789012', 18000)
  returning id into v_job;
  insert into public.maintenance_requests (portfolio_id, property_id, unit_id, title, category, priority, status,
                                           reported_on, resolved_on, resolution_note, estimated_cost)
  values (v_pid, v_saddar, v_shop6, 'Rewire Shop 6 before letting', 'electrical', 'medium', 'resolved',
          v_m0 - 40, v_m0 - 20, 'Full rewiring and new DB box.', 65000);

  insert into public.expenses (portfolio_id, property_id, unit_id, maintenance_request_id, category, amount, spent_on, payee, method, paid_by)
  values
    (v_pid, v_gulberg, v_lower, v_job, 'repairs_maintenance', 9500, v_today - 2, 'Ustad Rafiq', 'cash', v_manager),
    (v_pid, v_saddar, v_shop6, null, 'renovation', 65000, v_m0 - 20, 'Shah Electric Works', 'bank_transfer', v_owner),
    (v_pid, v_gulberg, null, null, 'property_tax', 42000, (v_m0 - interval '2 months')::date + 20, 'Excise & Taxation Punjab (ePay)', 'bank_transfer', v_owner),
    (v_pid, v_gulberg, null, null, 'staff_salaries', 25000, v_m0 + 1, 'Chowkidar - Akbar', 'cash', v_manager),
    (v_pid, v_clifton, null, null, 'society_charges', 8000, v_m0 + 2, 'Sea View Apartments association', 'raast', v_owner);

  -- Caretaker cash handovers ------------------------------------------------------------------
  insert into public.cash_handovers (portfolio_id, from_user_id, to_user_id, amount, handed_over_on, method, reference, notes)
  values
    (v_pid, v_manager, v_owner, 300000, v_m0 - 25, 'bank_transfer', 'IBFT-HO-1', 'Rent collected last month'),
    (v_pid, v_manager, v_owner, 120000, v_today - 1, 'raast', 'RAAST-HO-2', null);
  update public.cash_handovers set confirmed_at = now(), confirmed_by = v_owner where reference = 'IBFT-HO-1';

  -- Reminders already sent -------------------------------------------------------------------
  insert into public.reminder_logs (portfolio_id, lease_id, channel, template, language, message_preview, sent_by, sent_at)
  values (v_pid, v_l_zafar, 'whatsapp', 'overdue_gentle', 'roman_ur',
          'Assalam-o-Alaikum Zafar sahib, hamare record ke mutabiq…', v_manager, now() - interval '3 days');

  perform set_config('request.jwt.claims', '', true);
end
$$;

-- Late fees, notifications and current rents for "today".
select private.run_daily_jobs();
