-- ============================================================================
-- Identity checks: the CHECKs on stored phone numbers and CNICs accept
-- exactly what mm_core reads back.
--
-- The app writes these columns from mm_core's canonical forms and reads them
-- back strictly in every fromRow (PhoneNumber.fromE164, Cnic.parse), so a
-- stored value the database accepts but mm_core refuses makes every screen
-- that lists the row fail (the dashboard's arrears, the money screen, the
-- tenant list), whoever wrote it: another client, SQL, an import.
--
-- Findings (the review of the app's features, operations 8 and insights 5):
--   P1  The nine phone columns checked only '^\+[1-9][0-9]{7,14}$' (E.164
--       shape). mm_core applies Pakistan's numbering plan to +92 numbers, so
--       the CHECK let in values the app cannot read: '+92300123456' (a
--       mobile one digit short), '+9230012345678' (one long), '+920300…'
--       (the trunk 0 after the country code), +92 national numbers of 7 or
--       of 12 digits.
--   C1  The two CNIC columns checked '^[1-9][0-9]{12}$'. mm_core also
--       refuses one digit repeated thirteen times (a placeholder such as
--       '1111111111111'), so such a row broke the tenant and the tenancy
--       screens.
--
-- The rules now (contracts/identity_vectors.json holds the vectors; mm_core's
-- test/contract/identity_contract_test.dart and the generated
-- supabase/tests/database/20_identity_contract.test.sql assert both sides):
--   app.is_valid_phone(v): '+' and ASCII digits only, and either
--     +92 3 and 9 more digits                    (Pakistani mobile), or
--     +92 [1-2,4-9] and 7 to 10 more digits      (fixed line, UAN 111,
--                                                 toll-free 800: a national
--                                                 number of 8 to 11 digits),
--     or another country code: 8 to 15 digits in all, the first not 0 and
--     the first two not 92.
--     regex: ^\+(92(3[0-9]{9}|[1-24-9][0-9]{7,10})|(9[013-9]|[1-8][0-9])[0-9]{6,13})$
--     on tenants.phone, alt_phone, emergency_contact_phone, reference1_phone,
--     reference2_phone; profiles.phone; portfolios.landlord_phone;
--     lease_occupants.phone; maintenance_requests.vendor_phone.
--   app.is_valid_cnic(v): ^[1-9][0-9]{12}$ and not one digit repeated
--     thirteen times; on tenants.cnic and lease_occupants.cnic.
--
-- Reviewed and unchanged, because they already match their validator
-- exactly (the contract asserts the first two on both sides):
--   portfolios_raast_id_check '^\+923[0-9]{9}$' = a valid phone number that
--     is a mobile (the app's Raast field requires PhoneNumber.isMobile);
--   portfolios_bank_iban_check = Iban.parse without foreign IBANs (PK, 24
--     characters, MOD-97-10 in app.is_valid_iban);
--   tenants_ntn_check, utility_accounts_reference_number_check,
--     customer_id_check and meter_number_check: the same regexes as the
--     app's Tenant.ntnPattern and UtilityAccount's patterns;
--   the e-mail CHECKs: the same rule as the Edge Functions
--     (_shared/validation.ts); the app's EmailAddress is stricter on input
--     and nothing reads an e-mail back strictly;
--   the text length limits count code points (char_length). The app's
--     sanitizer truncates, and Validators.name counts, grapheme clusters, so
--     an Urdu name with diacritics can pass the form and be refused here;
--     that is for the app to change (count code points), not this CHECK.
--
-- Rows that already exist: none are changed or deleted. Before any CHECK
-- changes, the block below counts the stored values the new rules refuse
-- and, if there is one, stops the migration (SQLSTATE 23514) with the count
-- per column and nothing applied. Such values cannot be repaired without
-- their owners (a mobile one digit short has no right digit to add), so the
-- portfolio's owner corrects them in the app, or an operator sets them to
-- NULL with the owner's agreement, and the migration is applied again.
-- On the hosted project, run this before the push; every count must be 0:
--
--   with r as (
--     select '^\+(92(3[0-9]{9}|[1-24-9][0-9]{7,10})|(9[013-9]|[1-8][0-9])[0-9]{6,13})$' as re
--   )
--   select 'tenants.phone' as col, count(*) from public.tenants, r where phone !~ r.re
--   union all select 'tenants.alt_phone', count(*) from public.tenants, r where alt_phone !~ r.re
--   union all select 'tenants.emergency_contact_phone', count(*) from public.tenants, r
--     where emergency_contact_phone !~ r.re
--   union all select 'tenants.reference1_phone', count(*) from public.tenants, r
--     where reference1_phone !~ r.re
--   union all select 'tenants.reference2_phone', count(*) from public.tenants, r
--     where reference2_phone !~ r.re
--   union all select 'profiles.phone', count(*) from public.profiles, r where phone !~ r.re
--   union all select 'portfolios.landlord_phone', count(*) from public.portfolios, r
--     where landlord_phone !~ r.re
--   union all select 'lease_occupants.phone', count(*) from public.lease_occupants, r
--     where phone !~ r.re
--   union all select 'maintenance_requests.vendor_phone', count(*) from public.maintenance_requests, r
--     where vendor_phone !~ r.re
--   union all select 'tenants.cnic', count(*) from public.tenants
--     where cnic = repeat(left(cnic, 1), 13)
--   union all select 'lease_occupants.cnic', count(*) from public.lease_occupants
--     where cnic = repeat(left(cnic, 1), 13);
--
-- (The old CHECKs already hold for every stored row, so a CNIC that is not
-- one digit repeated, or a phone the new expression matches, needs no other
-- test.) Checked by tool/db/upgrade_test.sh with
-- tool/db/upgrade/20261108200216.*.sql: rows the new rules accept survive
-- unchanged, and rows they refuse stop the migration with nothing applied.
--
-- Each CHECK is replaced NOT VALID in one ALTER TABLE per table, so there is
-- no moment without a check, and new writes meet the new rule from the
-- commit on. The next migration, 20261108200227_identity_checks_validate.sql,
-- validates them in its own transaction (supabase db push runs each file in
-- one), where VALIDATE takes only SHARE UPDATE EXCLUSIVE and the app keeps
-- reading and writing. Here, the five tables are locked against writes
-- (reads go on) from the count to the commit, so no write slips between them;
-- the ACCESS EXCLUSIVE lock of the ADDs is brief (no scan), and lock_timeout
-- bounds the wait for each lock.
--
-- If 20261108200227 fails anyway on the hosted project, run the count query
-- above, have the values fixed, and push again: only the validate file is
-- left to apply, and the CHECKs stay enforced on new writes meanwhile.
--
-- The CHECKs call immutable functions: changing either function later must
-- come with a migration that validates the CHECKs again (as this one does).
-- ============================================================================

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- 1. The rules
-- ---------------------------------------------------------------------------

create or replace function app.is_valid_phone(p_phone text)
returns boolean
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select p_phone ~ '^\+(92(3[0-9]{9}|[1-24-9][0-9]{7,10})|(9[013-9]|[1-8][0-9])[0-9]{6,13})$'
$$;

comment on function app.is_valid_phone(text) is
  'A phone number as stored: the E.164 form mm_core''s PhoneNumber.fromE164 reads back '
  '(contracts/identity_vectors.json). NULL for NULL, so optional columns pass.';
grant execute on function app.is_valid_phone(text) to authenticated, service_role;

create or replace function app.is_valid_cnic(p_cnic text)
returns boolean
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select p_cnic ~ '^[1-9][0-9]{12}$' and p_cnic <> repeat(left(p_cnic, 1), 13)
$$;

comment on function app.is_valid_cnic(text) is
  'A CNIC as stored: 13 digits that mm_core''s Cnic.parse reads back (not starting with 0, '
  'not one digit repeated; contracts/identity_vectors.json). NULL for NULL.';
grant execute on function app.is_valid_cnic(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Refuse to run while a stored value breaks the new rules
-- ---------------------------------------------------------------------------

-- The count below must see every write that commits before the CHECKs
-- change: a write committed between an unlocked count and the ALTERs would
-- pass the old CHECK, escape the count and the NOT VALID ADD (which does not
-- scan), and leave the next migration's VALIDATE to fail. SHARE ROW
-- EXCLUSIVE waits for open writes to commit and blocks new ones until this
-- migration commits; reads go on, and lock_timeout bounds the wait.
-- (tool/db/upgrade/20261108200216.race.sql checks this.)
lock table public.tenants, public.profiles, public.portfolios, public.lease_occupants,
  public.maintenance_requests in share row exclusive mode;

do $$
declare
  v_report text;
begin
  select string_agg(format('%s: %s', c.col, c.n), ', ' order by c.col)
  into v_report
  from (
    select 'tenants.phone' as col, count(*) as n from public.tenants where not app.is_valid_phone(phone)
    union all
    select 'tenants.alt_phone', count(*) from public.tenants where not app.is_valid_phone(alt_phone)
    union all
    select 'tenants.emergency_contact_phone', count(*) from public.tenants
    where not app.is_valid_phone(emergency_contact_phone)
    union all
    select 'tenants.reference1_phone', count(*) from public.tenants
    where not app.is_valid_phone(reference1_phone)
    union all
    select 'tenants.reference2_phone', count(*) from public.tenants
    where not app.is_valid_phone(reference2_phone)
    union all
    select 'profiles.phone', count(*) from public.profiles where not app.is_valid_phone(phone)
    union all
    select 'portfolios.landlord_phone', count(*) from public.portfolios
    where not app.is_valid_phone(landlord_phone)
    union all
    select 'lease_occupants.phone', count(*) from public.lease_occupants
    where not app.is_valid_phone(phone)
    union all
    select 'maintenance_requests.vendor_phone', count(*) from public.maintenance_requests
    where not app.is_valid_phone(vendor_phone)
    union all
    select 'tenants.cnic', count(*) from public.tenants where not app.is_valid_cnic(cnic)
    union all
    select 'lease_occupants.cnic', count(*) from public.lease_occupants
    where not app.is_valid_cnic(cnic)
  ) c
  where c.n > 0;

  if v_report is not null then
    raise exception 'identity checks: stored values break the new phone or CNIC rules; nothing was changed'
      using errcode = 'check_violation',
            detail = 'Rows per column: ' || v_report || '.',
            hint = 'Have the owners correct these values in the app (or set them to NULL with their '
                   'agreement), then apply this migration again. The count query is in its header.';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. The CHECKs, replaced NOT VALID (validated by the next migration)
-- ---------------------------------------------------------------------------

-- Each old CHECK is dropped in the statement that adds its replacement under
-- the same name, and every value the new rule accepts the old one accepted
-- too, so no client loses a guarantee.
alter table public.tenants
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_phone_check,
  add constraint tenants_phone_check check (app.is_valid_phone(phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_alt_phone_check,
  add constraint tenants_alt_phone_check check (app.is_valid_phone(alt_phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_emergency_contact_phone_check,
  add constraint tenants_emergency_contact_phone_check
    check (app.is_valid_phone(emergency_contact_phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_reference1_phone_check,
  add constraint tenants_reference1_phone_check
    check (app.is_valid_phone(reference1_phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_reference2_phone_check,
  add constraint tenants_reference2_phone_check
    check (app.is_valid_phone(reference2_phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint tenants_cnic_check,
  add constraint tenants_cnic_check check (app.is_valid_cnic(cnic)) not valid;

alter table public.profiles
  -- squawk-ignore ban-drop-constraint
  drop constraint profiles_phone_check,
  add constraint profiles_phone_check check (app.is_valid_phone(phone)) not valid;

alter table public.portfolios
  -- squawk-ignore ban-drop-constraint
  drop constraint portfolios_landlord_phone_check,
  add constraint portfolios_landlord_phone_check check (app.is_valid_phone(landlord_phone)) not valid;

alter table public.lease_occupants
  -- squawk-ignore ban-drop-constraint
  drop constraint lease_occupants_phone_check,
  add constraint lease_occupants_phone_check check (app.is_valid_phone(phone)) not valid,
  -- squawk-ignore ban-drop-constraint
  drop constraint lease_occupants_cnic_check,
  add constraint lease_occupants_cnic_check check (app.is_valid_cnic(cnic)) not valid;

alter table public.maintenance_requests
  -- squawk-ignore ban-drop-constraint
  drop constraint maintenance_requests_vendor_phone_check,
  add constraint maintenance_requests_vendor_phone_check
    check (app.is_valid_phone(vendor_phone)) not valid;
