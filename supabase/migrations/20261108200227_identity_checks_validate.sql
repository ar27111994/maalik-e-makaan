-- ============================================================================
-- Validates the phone and CNIC CHECKs that 20261108200216_identity_checks.sql
-- replaced NOT VALID. This file is its own transaction under supabase db
-- push, so each VALIDATE holds SHARE UPDATE EXCLUSIVE on its table while it
-- scans: reads and writes go on, and only DDL on the same table waits.
--
-- The previous migration refused to run while a stored value broke the new
-- rules and every write since its commit has met them, so these scans find
-- nothing to refuse. If one fails anyway, nothing here is applied, the
-- CHECKs stay NOT VALID (still enforced on every new write), and the count
-- query in the header of the previous migration names the column.
-- ============================================================================

set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table public.tenants validate constraint tenants_phone_check;
alter table public.tenants validate constraint tenants_alt_phone_check;
alter table public.tenants validate constraint tenants_emergency_contact_phone_check;
alter table public.tenants validate constraint tenants_reference1_phone_check;
alter table public.tenants validate constraint tenants_reference2_phone_check;
alter table public.tenants validate constraint tenants_cnic_check;
alter table public.profiles validate constraint profiles_phone_check;
alter table public.portfolios validate constraint portfolios_landlord_phone_check;
alter table public.lease_occupants validate constraint lease_occupants_phone_check;
alter table public.lease_occupants validate constraint lease_occupants_cnic_check;
alter table public.maintenance_requests validate constraint maintenance_requests_vendor_phone_check;
