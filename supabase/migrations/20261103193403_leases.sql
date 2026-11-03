-- ============================================================================
-- Leases (tenancies), their rent history and co-occupants.
--
-- A lease binds a tenant to a unit. Pakistani practice drives the shape:
-- 11- or 12-month terms with a yearly increment (10% by default), a due day,
-- a grace period, a security deposit, optional late fees, agreement
-- registration (Punjab Rent Registrar) and police tenant registration.
--
-- Billing continues while a lease is active even after its agreed end date
-- (holding over is common); it stops at the actual move-out date.
-- ============================================================================

create type public.lease_status as enum ('active', 'ended');
create type public.late_fee_type as enum ('none', 'flat', 'percent', 'daily');
create type public.police_registration_status as enum ('not_required', 'pending', 'submitted', 'registered');
create type public.police_registration_channel as enum (
  'online_portal', 'khidmat_markaz', 'police_station', 'other'
);
create type public.rent_registrar_status as enum (
  'not_applicable', 'not_presented', 'presented', 'registered'
);
create type public.lease_end_reason as enum (
  'term_completed', 'tenant_moved_out', 'eviction', 'mutual_agreement', 'other'
);

create table public.leases (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  unit_id uuid not null,
  tenant_id uuid not null,
  status public.lease_status not null default 'active',
  start_date date not null,
  end_date date,
  monthly_rent numeric(14, 2) not null constraint leases_monthly_rent_check check (monthly_rent > 0),
  rent_due_day smallint not null default 5
    constraint leases_rent_due_day_check check (rent_due_day between 1 and 28),
  grace_days smallint not null default 5 constraint leases_grace_days_check check (grace_days between 0 and 60),
  security_deposit numeric(14, 2) not null default 0
    constraint leases_security_deposit_check check (security_deposit >= 0),
  increment_percent numeric(5, 2) not null default 10
    constraint leases_increment_percent_check check (increment_percent between 0 and 100),
  increment_interval_months smallint not null default 12
    constraint leases_increment_interval_check check (increment_interval_months between 1 and 60),
  late_fee_type public.late_fee_type not null default 'none',
  late_fee_value numeric(14, 2) constraint leases_late_fee_value_check check (late_fee_value >= 0),
  late_fee_cap numeric(14, 2) constraint leases_late_fee_cap_check check (late_fee_cap > 0),
  prorate_first_month boolean not null default true,
  billing_starts_on date not null,
  notice_period_days smallint not null default 30
    constraint leases_notice_period_check check (notice_period_days between 0 and 365),
  permitted_use text
    constraint leases_permitted_use_check
      check (char_length(permitted_use) <= 120 and app.is_clean_text(permitted_use)),
  subletting_allowed boolean not null default false,
  agreement_signed_on date,
  e_stamp_number text
    constraint leases_e_stamp_number_check
      check (char_length(e_stamp_number) <= 40 and app.is_clean_text(e_stamp_number)),
  e_stamp_amount numeric(14, 2) constraint leases_e_stamp_amount_check check (e_stamp_amount >= 0),
  rent_registrar_status public.rent_registrar_status not null default 'not_presented',
  rent_registrar_office text
    constraint leases_rent_registrar_office_check
      check (char_length(rent_registrar_office) <= 120 and app.is_clean_text(rent_registrar_office)),
  rent_registration_number text
    constraint leases_rent_registration_number_check
      check (char_length(rent_registration_number) <= 60 and app.is_clean_text(rent_registration_number)),
  rent_registered_on date,
  police_status public.police_registration_status not null default 'pending',
  police_channel public.police_registration_channel,
  police_station text
    constraint leases_police_station_check
      check (char_length(police_station) <= 120 and app.is_clean_text(police_station)),
  police_reference text
    constraint leases_police_reference_check
      check (char_length(police_reference) <= 60 and app.is_clean_text(police_reference)),
  police_registered_on date,
  police_fee numeric(14, 2) constraint leases_police_fee_check check (police_fee >= 0),
  utilities_note text
    constraint leases_utilities_note_check
      check (char_length(utilities_note) <= 500 and app.is_clean_text(utilities_note)),
  notes text constraint leases_notes_check check (char_length(notes) <= 2000 and app.is_clean_text(notes)),
  moved_out_on date,
  end_reason public.lease_end_reason,
  ended_at timestamptz,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leases_unit_fkey foreign key (unit_id, portfolio_id)
    references public.units (id, portfolio_id) on delete no action,
  constraint leases_tenant_fkey foreign key (tenant_id, portfolio_id)
    references public.tenants (id, portfolio_id) on delete no action,
  constraint leases_id_portfolio_key unique (id, portfolio_id),
  constraint leases_end_after_start_check check (end_date is null or end_date >= start_date),
  constraint leases_billing_start_check check (billing_starts_on >= start_date),
  constraint leases_moved_out_check check (moved_out_on is null or moved_out_on >= start_date),
  constraint leases_status_consistency_check
    check ((status = 'ended') = (moved_out_on is not null and ended_at is not null)),
  constraint leases_late_fee_consistency_check
    check ((late_fee_type = 'none') = (late_fee_value is null)),
  constraint leases_late_fee_percent_check check (late_fee_type <> 'percent' or late_fee_value <= 100),
  constraint leases_late_fee_cap_type_check check (late_fee_cap is null or late_fee_type = 'daily'),
  -- Active tenancies of one unit may never overlap in time. A future lease may
  -- be scheduled once the current one has an agreed end date. portfolio_id
  -- leads so that a forged foreign unit id fails the foreign key instead of
  -- revealing (through this constraint) whether another portfolio's unit is let.
  constraint leases_no_overlap_excl exclude using gist (
    portfolio_id with =,
    unit_id with =,
    daterange(start_date, coalesce(moved_out_on, end_date), '[]') with &&
  ) where (status = 'active')
);

comment on table public.leases is 'A tenancy of a unit by a tenant, with its commercial and compliance terms.';
comment on column public.leases.monthly_rent is 'Rent currently in force (latest rent_changes row on or before today).';
comment on column public.leases.billing_starts_on is
  'First day billed by the app; later than start_date when onboarding an existing tenancy.';

create index leases_portfolio_id_idx on public.leases (portfolio_id);
create index leases_unit_id_idx on public.leases (unit_id, portfolio_id);
create index leases_tenant_id_idx on public.leases (tenant_id, portfolio_id);
create index leases_created_by_idx on public.leases (created_by);
create index leases_active_idx on public.leases (portfolio_id, unit_id) where status = 'active';

create trigger leases_touch_updated_at
  before update on public.leases
  for each row execute function private.touch_updated_at();

-- Defaults and integrity rules that need other tables.
create or replace function private.before_lease_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.billing_starts_on := coalesce(new.billing_starts_on, new.start_date);
  if exists (
    select 1 from public.units u
    where u.id = new.unit_id and u.portfolio_id = new.portfolio_id and u.archived_at is not null
  ) then
    perform app.fail('unit_archived');
  end if;
  if exists (
    select 1 from public.tenants t
    where t.id = new.tenant_id and t.portfolio_id = new.portfolio_id and t.archived_at is not null
  ) then
    perform app.fail('tenant_archived');
  end if;
  return new;
end
$$;

create trigger leases_before_insert
  before insert on public.leases
  for each row execute function private.before_lease_insert();

-- ---------------------------------------------------------------------------
-- Rent history
-- ---------------------------------------------------------------------------

create table public.rent_changes (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  effective_from date not null
    constraint rent_changes_effective_month_check check (extract(day from effective_from) = 1),
  monthly_rent numeric(14, 2) not null constraint rent_changes_monthly_rent_check check (monthly_rent > 0),
  reason text not null
    constraint rent_changes_reason_check
      check (reason in ('initial', 'annual_increment', 'renegotiation', 'correction')),
  note text constraint rent_changes_note_check check (char_length(note) <= 300 and app.is_clean_text(note)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint rent_changes_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade,
  constraint rent_changes_lease_month_key unique (lease_id, effective_from)
);

comment on table public.rent_changes is 'Rent in force from a given month; the latest row on or before a month applies.';

create index rent_changes_portfolio_id_idx on public.rent_changes (portfolio_id);
create index rent_changes_lease_fk_idx on public.rent_changes (lease_id, portfolio_id);
create index rent_changes_created_by_idx on public.rent_changes (created_by);

-- ---------------------------------------------------------------------------
-- Co-occupants (adults living with the tenant; needed for police registration)
-- ---------------------------------------------------------------------------

create table public.lease_occupants (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  full_name text not null
    constraint lease_occupants_full_name_check
      check (char_length(btrim(full_name)) between 1 and 120 and app.is_clean_text(full_name)),
  relation text
    constraint lease_occupants_relation_check
      check (char_length(relation) <= 40 and app.is_clean_text(relation)),
  cnic text constraint lease_occupants_cnic_check check (cnic ~ '^[1-9][0-9]{12}$'),
  phone text constraint lease_occupants_phone_check check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lease_occupants_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade
);

create index lease_occupants_portfolio_id_idx on public.lease_occupants (portfolio_id);
create index lease_occupants_lease_fk_idx on public.lease_occupants (lease_id, portfolio_id);

create trigger lease_occupants_touch_updated_at
  before update on public.lease_occupants
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Derived helpers shared by jobs, reports and the app's previews. They mirror
-- mm_core's RentMath and are tested against the same contract vectors.
-- ---------------------------------------------------------------------------

-- Due date of a month for a due day, clamped to the month's length.
create or replace function app.due_date_for(p_month date, p_due_day integer)
returns date
language sql
immutable
parallel safe
set search_path = ''
as $$
  select (date_trunc('month', p_month)::date
    + (least(p_due_day, extract(day from (date_trunc('month', p_month) + interval '1 month - 1 day'))::integer) - 1))
$$;

-- First anniversary of p_start (every p_interval_months) on or after p_as_of;
-- before the first anniversary this is p_start + p_interval_months.
create or replace function app.next_anniversary(p_start date, p_as_of date, p_interval_months integer)
returns date
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  v_cycles integer := 1;
  v_candidate date;
begin
  if p_interval_months <= 0 then
    raise exception using errcode = '22023', message = 'invalid_interval';
  end if;
  if p_as_of > p_start then
    v_cycles := greatest(
      1,
      (((extract(year from p_as_of) * 12 + extract(month from p_as_of))
        - (extract(year from p_start) * 12 + extract(month from p_start)))::integer) / p_interval_months
    );
  end if;
  -- Adding months to a date clamps to the month's last day (Jan 31 + 1 month = Feb 28/29).
  v_candidate := (p_start + make_interval(months => v_cycles * p_interval_months))::date;
  while v_candidate < p_as_of loop
    v_cycles := v_cycles + 1;
    v_candidate := (p_start + make_interval(months => v_cycles * p_interval_months))::date;
  end loop;
  return v_candidate;
end
$$;

-- Police registration deadline in days after possession, by province.
-- Punjab (15 days) and Sindh (48 hours) are statutory; the 1-day default for
-- other jurisdictions is an app default, labelled as such in the UI.
create or replace function app.police_registration_deadline_days(p_province public.province)
returns integer
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case p_province
    when 'punjab' then 15
    when 'sindh' then 2
    else 1
  end
$$;

-- Rent for the month p_month when billing starts on p_billing_starts_on:
-- the full rent, or (first month only, when it starts after the 1st) the rent
-- × days billed ÷ days in month, rounded half-up to whole rupees.
create or replace function app.prorated_rent(p_rent numeric, p_month date, p_billing_starts_on date)
returns numeric
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when date_trunc('month', p_billing_starts_on) = date_trunc('month', p_month)
         and extract(day from p_billing_starts_on) > 1
    then round(
      p_rent
        * (extract(day from (date_trunc('month', p_month) + interval '1 month - 1 day'))::integer
           - extract(day from p_billing_starts_on)::integer + 1)
        / extract(day from (date_trunc('month', p_month) + interval '1 month - 1 day'))::integer,
      0
    )
    else p_rent
  end
$$;

-- Late fee owed on p_outstanding that is p_days_late days past due under a
-- lease's policy; zero inside the grace period. Mirrors mm_core LateFeePolicy.
create or replace function app.late_fee_amount(
  p_type public.late_fee_type,
  p_value numeric,
  p_cap numeric,
  p_outstanding numeric,
  p_days_late integer,
  p_grace_days integer
)
returns numeric
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when p_type = 'none' or p_outstanding <= 0 or p_days_late <= p_grace_days then 0::numeric
    else round(case p_type
      when 'flat' then p_value
      when 'percent' then p_outstanding * p_value / 100
      when 'daily' then least(p_value * p_days_late, coalesce(p_cap, p_value * p_days_late))
    end, 0)
  end
$$;

grant execute on function app.prorated_rent(numeric, date, date) to authenticated, service_role;
grant execute on function app.late_fee_amount(public.late_fee_type, numeric, numeric, numeric, integer, integer)
  to authenticated, service_role;

grant execute on function app.due_date_for(date, integer) to authenticated, service_role;
grant execute on function app.next_anniversary(date, date, integer) to authenticated, service_role;
grant execute on function app.police_registration_deadline_days(public.province) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Row Level Security & column grants
-- ---------------------------------------------------------------------------

select private.apply_portfolio_policies(
  'public.leases', array['owner', 'manager']::public.member_role[], array['owner']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.lease_occupants', array['owner', 'manager']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);

-- Rent history is written only by SECURITY DEFINER functions (initial rent,
-- change_rent); clients read it.
alter table public.rent_changes enable row level security;
create policy rent_changes_select on public.rent_changes
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
grant select on public.rent_changes to authenticated;
grant select, insert, update, delete on public.rent_changes to service_role;

grant select, delete on public.leases to authenticated;
-- Rent, status and move-out are changed only through RPCs (change_rent,
-- end_lease) so the ledger stays consistent.
grant insert (
  id, portfolio_id, unit_id, tenant_id, start_date, end_date, monthly_rent, rent_due_day, grace_days,
  security_deposit, increment_percent, increment_interval_months, late_fee_type, late_fee_value,
  late_fee_cap, prorate_first_month, billing_starts_on, notice_period_days, permitted_use,
  subletting_allowed, agreement_signed_on, e_stamp_number, e_stamp_amount, rent_registrar_status,
  rent_registrar_office, rent_registration_number, rent_registered_on, police_status,
  police_channel, police_station, police_reference, police_registered_on, police_fee,
  utilities_note, notes
) on public.leases to authenticated;
grant update (
  end_date, rent_due_day, grace_days, security_deposit, increment_percent,
  increment_interval_months, late_fee_type, late_fee_value, late_fee_cap, notice_period_days,
  permitted_use, subletting_allowed, agreement_signed_on, e_stamp_number, e_stamp_amount,
  rent_registrar_status, rent_registrar_office, rent_registration_number, rent_registered_on,
  police_status, police_channel, police_station, police_reference, police_registered_on,
  police_fee, utilities_note, notes
) on public.leases to authenticated;

grant select, delete on public.lease_occupants to authenticated;
grant insert (id, portfolio_id, lease_id, full_name, relation, cnic, phone)
  on public.lease_occupants to authenticated;
grant update (full_name, relation, cnic, phone) on public.lease_occupants to authenticated;
