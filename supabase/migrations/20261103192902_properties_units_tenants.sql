-- ============================================================================
-- Properties, units and tenants
--
-- Every portfolio-owned table carries `portfolio_id` and exposes the composite
-- key (id, portfolio_id). Child tables reference that composite key, so a row
-- can never point at a parent in another portfolio, even if a client forges
-- ids: tenant isolation is enforced by the data model, not only by RLS.
-- ============================================================================

-- Standard RLS for portfolio-scoped tables:
--   select  any member of the portfolio
--   insert  members holding one of p_writers
--   update  members holding one of p_writers (USING + WITH CHECK)
--   delete  members holding one of p_deleters (no policy when null)
-- Generated policy names: <table>_select | _insert | _update | _delete.
create or replace function private.apply_portfolio_policies(
  p_table regclass,
  p_writers public.member_role[],
  p_deleters public.member_role[] default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_name text := (select c.relname from pg_catalog.pg_class c where c.oid = p_table);
  v_writers text := quote_literal(p_writers::text) || '::public.member_role[]';
begin
  execute format('alter table %s enable row level security', p_table);

  execute format(
    'create policy %I on %s for select to authenticated
       using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]))',
    v_name || '_select', p_table
  );
  execute format(
    'create policy %I on %s for insert to authenticated
       with check (portfolio_id = any ((select app.my_portfolio_ids(%s))::uuid[]))',
    v_name || '_insert', p_table, v_writers
  );
  execute format(
    'create policy %I on %s for update to authenticated
       using (portfolio_id = any ((select app.my_portfolio_ids(%s))::uuid[]))
       with check (portfolio_id = any ((select app.my_portfolio_ids(%s))::uuid[]))',
    v_name || '_update', p_table, v_writers, v_writers
  );
  if p_deleters is not null then
    execute format(
      'create policy %I on %s for delete to authenticated
         using (portfolio_id = any ((select app.my_portfolio_ids(%s))::uuid[]))',
      v_name || '_delete', p_table, quote_literal(p_deleters::text) || '::public.member_role[]'
    );
  end if;

  execute format('grant select, insert, update, delete on %s to service_role', p_table);
end
$$;

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------

create type public.property_type as enum (
  'house', 'apartment_building', 'apartment', 'plaza', 'shop', 'office',
  'hostel', 'farmhouse', 'warehouse', 'plot', 'other'
);

-- Jurisdiction drives compliance rules (police registration deadlines, the
-- Punjab Rent Registrar, Sindh's default due date).
create type public.province as enum (
  'punjab', 'sindh', 'khyber_pakhtunkhwa', 'balochistan', 'islamabad',
  'gilgit_baltistan', 'azad_kashmir'
);

create type public.area_unit as enum ('marla', 'kanal', 'sq_ft', 'sq_yd', 'sq_m', 'acre');

create table public.properties (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  name text not null
    constraint properties_name_check
      check (char_length(btrim(name)) between 1 and 100 and app.is_clean_text(name)),
  type public.property_type not null default 'house',
  address_line text
    constraint properties_address_line_check
      check (char_length(address_line) <= 200 and app.is_clean_text(address_line)),
  locality text
    constraint properties_locality_check
      check (char_length(locality) <= 100 and app.is_clean_text(locality)),
  city text not null
    constraint properties_city_check
      check (char_length(btrim(city)) between 1 and 60 and app.is_clean_text(city)),
  province public.province not null,
  plot_size numeric(10, 2) constraint properties_plot_size_check check (plot_size > 0),
  plot_size_unit public.area_unit,
  covered_area_sqft integer
    constraint properties_covered_area_check check (covered_area_sqft between 1 and 9999999),
  year_built smallint constraint properties_year_built_check check (year_built between 1850 and 2100),
  purchase_price numeric(14, 2) constraint properties_purchase_price_check check (purchase_price >= 0),
  purchased_on date,
  estimated_value numeric(14, 2)
    constraint properties_estimated_value_check check (estimated_value >= 0),
  value_estimated_on date,
  property_tax_ref text
    constraint properties_property_tax_ref_check
      check (char_length(property_tax_ref) <= 60 and app.is_clean_text(property_tax_ref)),
  notes text
    constraint properties_notes_check check (char_length(notes) <= 2000 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint properties_plot_size_unit_check check ((plot_size is null) = (plot_size_unit is null)),
  constraint properties_id_portfolio_key unique (id, portfolio_id)
);

comment on table public.properties is 'A building or plot owned in a portfolio.';
comment on column public.properties.province is 'Jurisdiction: drives police-registration and rent-registration rules.';

create index properties_portfolio_id_idx on public.properties (portfolio_id);
create index properties_created_by_idx on public.properties (created_by);
create unique index properties_portfolio_name_key
  on public.properties (portfolio_id, lower(name))
  where archived_at is null;
create index properties_name_trgm_idx on public.properties using gin (name extensions.gin_trgm_ops);

create trigger properties_touch_updated_at
  before update on public.properties
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Units (the rentable thing: portion, flat, shop, room, bed …)
-- ---------------------------------------------------------------------------

create type public.unit_type as enum (
  'entire_property', 'portion', 'apartment', 'room', 'bed', 'shop', 'office',
  'floor', 'warehouse', 'other'
);

create table public.units (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  property_id uuid not null,
  label text not null
    constraint units_label_check
      check (char_length(btrim(label)) between 1 and 60 and app.is_clean_text(label)),
  type public.unit_type not null default 'portion',
  floor_label text
    constraint units_floor_label_check
      check (char_length(floor_label) <= 30 and app.is_clean_text(floor_label)),
  bedrooms smallint constraint units_bedrooms_check check (bedrooms between 0 and 50),
  bathrooms smallint constraint units_bathrooms_check check (bathrooms between 0 and 50),
  covered_area_sqft integer
    constraint units_covered_area_check check (covered_area_sqft between 1 and 9999999),
  furnished boolean not null default false,
  asking_rent numeric(14, 2) constraint units_asking_rent_check check (asking_rent >= 0),
  is_available boolean not null default true,
  notes text constraint units_notes_check check (char_length(notes) <= 2000 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint units_property_fkey foreign key (property_id, portfolio_id)
    references public.properties (id, portfolio_id) on delete cascade,
  constraint units_id_portfolio_key unique (id, portfolio_id),
  constraint units_id_property_key unique (id, property_id)
);

comment on table public.units is 'A rentable unit of a property (portion, flat, shop, room, bed …).';
comment on column public.units.is_available is 'False while under renovation or owner-occupied.';

create index units_property_id_idx on public.units (property_id, portfolio_id);
create index units_portfolio_id_idx on public.units (portfolio_id);
create index units_created_by_idx on public.units (created_by);
create unique index units_property_label_key
  on public.units (property_id, lower(label))
  where archived_at is null;
create index units_label_trgm_idx on public.units using gin (label extensions.gin_trgm_ops);

create trigger units_touch_updated_at
  before update on public.units
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Tenants
-- ---------------------------------------------------------------------------

create type public.guardian_relation as enum ('son_of', 'daughter_of', 'wife_of', 'other');
create type public.tenant_kind as enum ('individual', 'company', 'government', 'other');

create table public.tenants (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  kind public.tenant_kind not null default 'individual',
  full_name text not null
    constraint tenants_full_name_check
      check (char_length(btrim(full_name)) between 1 and 120 and app.is_clean_text(full_name)),
  guardian_name text
    constraint tenants_guardian_name_check
      check (char_length(guardian_name) <= 120 and app.is_clean_text(guardian_name)),
  guardian_relation public.guardian_relation,
  cnic text constraint tenants_cnic_check check (cnic ~ '^[1-9][0-9]{12}$'),
  cnic_expiry date,
  ntn text constraint tenants_ntn_check check (ntn ~ '^[0-9A-Z][0-9A-Z-]{5,14}$'),
  phone text constraint tenants_phone_check check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  alt_phone text constraint tenants_alt_phone_check check (alt_phone ~ '^\+[1-9][0-9]{7,14}$'),
  email text
    constraint tenants_email_check
      check (
        email = lower(btrim(email))
        and char_length(email) <= 254
        and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,63}$'
      ),
  occupation text
    constraint tenants_occupation_check
      check (char_length(occupation) <= 80 and app.is_clean_text(occupation)),
  employer text
    constraint tenants_employer_check
      check (char_length(employer) <= 120 and app.is_clean_text(employer)),
  permanent_address text
    constraint tenants_permanent_address_check
      check (char_length(permanent_address) <= 300 and app.is_clean_text(permanent_address)),
  previous_address text
    constraint tenants_previous_address_check
      check (char_length(previous_address) <= 300 and app.is_clean_text(previous_address)),
  emergency_contact_name text
    constraint tenants_emergency_contact_name_check
      check (char_length(emergency_contact_name) <= 120 and app.is_clean_text(emergency_contact_name)),
  emergency_contact_phone text
    constraint tenants_emergency_contact_phone_check
      check (emergency_contact_phone ~ '^\+[1-9][0-9]{7,14}$'),
  emergency_contact_relation text
    constraint tenants_emergency_contact_relation_check
      check (char_length(emergency_contact_relation) <= 40 and app.is_clean_text(emergency_contact_relation)),
  reference1_name text
    constraint tenants_reference1_name_check
      check (char_length(reference1_name) <= 120 and app.is_clean_text(reference1_name)),
  reference1_phone text
    constraint tenants_reference1_phone_check check (reference1_phone ~ '^\+[1-9][0-9]{7,14}$'),
  reference2_name text
    constraint tenants_reference2_name_check
      check (char_length(reference2_name) <= 120 and app.is_clean_text(reference2_name)),
  reference2_phone text
    constraint tenants_reference2_phone_check check (reference2_phone ~ '^\+[1-9][0-9]{7,14}$'),
  household_size smallint constraint tenants_household_size_check check (household_size between 1 and 50),
  deducts_withholding_tax boolean not null default false,
  consent_recorded_at timestamptz,
  consent_note text
    constraint tenants_consent_note_check
      check (char_length(consent_note) <= 300 and app.is_clean_text(consent_note)),
  notes text constraint tenants_notes_check check (char_length(notes) <= 2000 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint tenants_id_portfolio_key unique (id, portfolio_id)
);

comment on table public.tenants is 'A tenant (person or organisation). CNIC is sensitive: mask in UIs.';
comment on column public.tenants.cnic is '13 digits, no dashes. Never used to infer gender.';
comment on column public.tenants.deducts_withholding_tax is
  'True for prescribed persons (companies, government…) that deduct s.155 tax from rent.';
comment on column public.tenants.consent_recorded_at is
  'When the landlord recorded that the tenant was told what data is kept and why.';

create index tenants_portfolio_id_idx on public.tenants (portfolio_id);
create index tenants_created_by_idx on public.tenants (created_by);
create unique index tenants_portfolio_cnic_key
  on public.tenants (portfolio_id, cnic)
  where cnic is not null and archived_at is null;
create index tenants_portfolio_phone_idx on public.tenants (portfolio_id, phone) where phone is not null;
create index tenants_full_name_trgm_idx on public.tenants using gin (full_name extensions.gin_trgm_ops);

create trigger tenants_touch_updated_at
  before update on public.tenants
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security & column grants
-- ---------------------------------------------------------------------------

select private.apply_portfolio_policies(
  'public.properties', array['owner', 'manager']::public.member_role[], array['owner']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.units', array['owner', 'manager']::public.member_role[], array['owner']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.tenants', array['owner', 'manager']::public.member_role[], array['owner']::public.member_role[]
);

grant select, delete on public.properties, public.units, public.tenants to authenticated;

-- Clients may supply ids (UUIDv7) so that retried inserts are idempotent.
grant insert (
  id, portfolio_id, name, type, address_line, locality, city, province, plot_size, plot_size_unit,
  covered_area_sqft, year_built, purchase_price, purchased_on, estimated_value, value_estimated_on,
  property_tax_ref, notes
) on public.properties to authenticated;
grant update (
  name, type, address_line, locality, city, province, plot_size, plot_size_unit, covered_area_sqft,
  year_built, purchase_price, purchased_on, estimated_value, value_estimated_on, property_tax_ref,
  notes, archived_at
) on public.properties to authenticated;

grant insert (
  id, portfolio_id, property_id, label, type, floor_label, bedrooms, bathrooms, covered_area_sqft,
  furnished, asking_rent, is_available, notes
) on public.units to authenticated;
grant update (
  label, type, floor_label, bedrooms, bathrooms, covered_area_sqft, furnished, asking_rent,
  is_available, notes, archived_at
) on public.units to authenticated;

grant insert (
  id, portfolio_id, kind, full_name, guardian_name, guardian_relation, cnic, cnic_expiry, ntn, phone,
  alt_phone, email, occupation, employer, permanent_address, previous_address,
  emergency_contact_name, emergency_contact_phone, emergency_contact_relation, reference1_name,
  reference1_phone, reference2_name, reference2_phone, household_size, deducts_withholding_tax,
  consent_recorded_at, consent_note, notes
) on public.tenants to authenticated;
grant update (
  kind, full_name, guardian_name, guardian_relation, cnic, cnic_expiry, ntn, phone, alt_phone, email,
  occupation, employer, permanent_address, previous_address, emergency_contact_name,
  emergency_contact_phone, emergency_contact_relation, reference1_name, reference1_phone,
  reference2_name, reference2_phone, household_size, deducts_withholding_tax, consent_recorded_at,
  consent_note, notes, archived_at
) on public.tenants to authenticated;
