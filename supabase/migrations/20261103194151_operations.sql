-- ============================================================================
-- Operations: expenses, utilities (connections, bills, meter readings),
-- maintenance, caretaker cash handovers and reminder logs.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Maintenance
-- ---------------------------------------------------------------------------

create type public.maintenance_category as enum (
  'plumbing', 'electrical', 'carpentry', 'painting', 'seepage', 'appliance', 'pest_control',
  'cleaning', 'structural', 'water_supply', 'other'
);
create type public.maintenance_priority as enum ('low', 'medium', 'high', 'urgent');
create type public.maintenance_status as enum ('open', 'in_progress', 'on_hold', 'resolved', 'cancelled');

create table public.maintenance_requests (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  property_id uuid not null,
  unit_id uuid,
  lease_id uuid,
  title text not null
    constraint maintenance_requests_title_check
      check (char_length(btrim(title)) between 1 and 120 and app.is_clean_text(title)),
  description text
    constraint maintenance_requests_description_check
      check (char_length(description) <= 2000 and app.is_clean_text(description)),
  category public.maintenance_category not null default 'other',
  priority public.maintenance_priority not null default 'medium',
  status public.maintenance_status not null default 'open',
  reported_by text
    constraint maintenance_requests_reported_by_check
      check (char_length(reported_by) <= 120 and app.is_clean_text(reported_by)),
  reported_on date not null default app.today_pkt(),
  assigned_to text
    constraint maintenance_requests_assigned_to_check
      check (char_length(assigned_to) <= 120 and app.is_clean_text(assigned_to)),
  vendor_phone text
    constraint maintenance_requests_vendor_phone_check check (vendor_phone ~ '^\+[1-9][0-9]{7,14}$'),
  estimated_cost numeric(14, 2)
    constraint maintenance_requests_estimated_cost_check check (estimated_cost >= 0),
  resolved_on date,
  resolution_note text
    constraint maintenance_requests_resolution_note_check
      check (char_length(resolution_note) <= 1000 and app.is_clean_text(resolution_note)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint maintenance_requests_property_fkey foreign key (property_id, portfolio_id)
    references public.properties (id, portfolio_id) on delete cascade,
  constraint maintenance_requests_unit_fkey foreign key (unit_id, property_id)
    references public.units (id, property_id) on delete cascade,
  constraint maintenance_requests_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade,
  constraint maintenance_requests_id_portfolio_key unique (id, portfolio_id),
  constraint maintenance_requests_resolved_check
    check (status <> 'resolved' or resolved_on is not null)
);

comment on table public.maintenance_requests is 'Repair and maintenance jobs (seepage, plumbing, electrical…).';

create index maintenance_requests_portfolio_status_idx
  on public.maintenance_requests (portfolio_id, status, reported_on desc);
create index maintenance_requests_property_fk_idx on public.maintenance_requests (property_id, portfolio_id);
create index maintenance_requests_unit_fk_idx on public.maintenance_requests (unit_id, property_id);
create index maintenance_requests_lease_fk_idx on public.maintenance_requests (lease_id, portfolio_id);
create index maintenance_requests_created_by_idx on public.maintenance_requests (created_by);

create trigger maintenance_requests_touch_updated_at
  before update on public.maintenance_requests
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Expenses
-- ---------------------------------------------------------------------------

create type public.expense_category as enum (
  'repairs_maintenance', 'property_tax', 'utilities', 'society_charges', 'insurance',
  'legal_professional', 'agent_commission', 'staff_salaries', 'cleaning_security', 'renovation',
  'bank_charges', 'loan_interest', 'other'
);

create table public.expenses (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  property_id uuid,
  unit_id uuid,
  maintenance_request_id uuid,
  category public.expense_category not null,
  amount numeric(14, 2) not null constraint expenses_amount_check check (amount > 0),
  spent_on date not null,
  payee text constraint expenses_payee_check check (char_length(payee) <= 120 and app.is_clean_text(payee)),
  method public.payment_method not null default 'cash'
    constraint expenses_method_check check (method <> 'deposit_adjustment'),
  reference text
    constraint expenses_reference_check check (char_length(reference) <= 80 and app.is_clean_text(reference)),
  notes text constraint expenses_notes_check check (char_length(notes) <= 1000 and app.is_clean_text(notes)),
  paid_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_property_fkey foreign key (property_id, portfolio_id)
    references public.properties (id, portfolio_id) on delete no action,
  constraint expenses_unit_fkey foreign key (unit_id, property_id)
    references public.units (id, property_id) on delete no action,
  constraint expenses_maintenance_fkey foreign key (maintenance_request_id, portfolio_id)
    references public.maintenance_requests (id, portfolio_id) on delete no action,
  constraint expenses_unit_requires_property_check check (unit_id is null or property_id is not null)
);

comment on table public.expenses is 'Money spent on the portfolio (repairs, property tax, salaries…).';
comment on column public.expenses.paid_by is 'Member who paid; cash expenses reduce that member''s cash in hand.';

create index expenses_portfolio_spent_idx on public.expenses (portfolio_id, spent_on desc);
create index expenses_property_fk_idx on public.expenses (property_id, portfolio_id);
create index expenses_unit_fk_idx on public.expenses (unit_id, property_id);
create index expenses_maintenance_fk_idx on public.expenses (maintenance_request_id, portfolio_id);
create index expenses_paid_by_idx on public.expenses (paid_by);
create index expenses_created_by_idx on public.expenses (created_by);

create trigger expenses_touch_updated_at
  before update on public.expenses
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------

create type public.utility_type as enum ('electricity', 'gas', 'water', 'internet', 'other');

-- The 12 electricity distribution companies, the two gas utilities, common
-- water authorities and ISPs. 'other' + provider_other covers the rest.
create type public.utility_provider as enum (
  'lesco', 'iesco', 'gepco', 'fesco', 'mepco', 'pesco', 'hesco', 'sepco', 'qesco', 'tesco',
  'hazeco', 'k_electric', 'sngpl', 'ssgc', 'wasa', 'kwsc', 'cda', 'ptcl', 'other'
);

create type public.bill_responsibility as enum ('tenant', 'landlord', 'shared');

create table public.utility_accounts (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  property_id uuid not null,
  unit_id uuid,
  type public.utility_type not null,
  provider public.utility_provider not null default 'other',
  provider_other text
    constraint utility_accounts_provider_other_check
      check (char_length(provider_other) <= 60 and app.is_clean_text(provider_other)),
  reference_number text
    constraint utility_accounts_reference_number_check check (reference_number ~ '^[0-9A-Z-]{4,24}$'),
  customer_id text
    constraint utility_accounts_customer_id_check check (customer_id ~ '^[0-9A-Z-]{1,30}$'),
  meter_number text
    constraint utility_accounts_meter_number_check check (meter_number ~ '^[0-9A-Z/-]{1,30}$'),
  account_title text
    constraint utility_accounts_account_title_check
      check (char_length(account_title) <= 120 and app.is_clean_text(account_title)),
  in_landlord_name boolean not null default true,
  is_sub_meter boolean not null default false,
  is_protected_consumer boolean not null default false,
  responsibility public.bill_responsibility not null default 'tenant',
  notes text
    constraint utility_accounts_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint utility_accounts_property_fkey foreign key (property_id, portfolio_id)
    references public.properties (id, portfolio_id) on delete cascade,
  constraint utility_accounts_unit_fkey foreign key (unit_id, property_id)
    references public.units (id, property_id) on delete cascade,
  constraint utility_accounts_id_portfolio_key unique (id, portfolio_id)
);

comment on table public.utility_accounts is
  'A utility connection/meter. Arrears follow the premises (NEPRA), so connections in the landlord''s name carry risk.';
comment on column public.utility_accounts.is_protected_consumer is
  'Protected domestic tariff: exceeding 200 units in a month loses the subsidy for six months.';

create unique index utility_accounts_reference_key
  on public.utility_accounts (portfolio_id, type, reference_number)
  where reference_number is not null and archived_at is null;
create index utility_accounts_property_fk_idx on public.utility_accounts (property_id, portfolio_id);
create index utility_accounts_unit_fk_idx on public.utility_accounts (unit_id, property_id);
create index utility_accounts_portfolio_id_idx on public.utility_accounts (portfolio_id);
create index utility_accounts_created_by_idx on public.utility_accounts (created_by);

create trigger utility_accounts_touch_updated_at
  before update on public.utility_accounts
  for each row execute function private.touch_updated_at();

create type public.utility_bill_status as enum ('unpaid', 'paid');

create table public.utility_bills (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  utility_account_id uuid not null,
  billing_month date not null
    constraint utility_bills_billing_month_check check (extract(day from billing_month) = 1),
  amount numeric(14, 2) not null constraint utility_bills_amount_check check (amount >= 0),
  due_date date,
  units_consumed numeric(12, 2) constraint utility_bills_units_check check (units_consumed >= 0),
  status public.utility_bill_status not null default 'unpaid',
  paid_on date,
  paid_by text constraint utility_bills_paid_by_check check (paid_by in ('tenant', 'landlord')),
  charge_id uuid references public.charges (id) on delete set null,
  notes text
    constraint utility_bills_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint utility_bills_account_fkey foreign key (utility_account_id, portfolio_id)
    references public.utility_accounts (id, portfolio_id) on delete cascade,
  constraint utility_bills_account_month_key unique (utility_account_id, billing_month),
  constraint utility_bills_paid_consistency_check check ((status = 'paid') = (paid_on is not null))
);

comment on table public.utility_bills is 'Monthly bills per connection; can be charged to the tenant ledger.';

create index utility_bills_portfolio_status_idx on public.utility_bills (portfolio_id, status, due_date);
create index utility_bills_account_fk_idx on public.utility_bills (utility_account_id, portfolio_id);
create index utility_bills_charge_id_idx on public.utility_bills (charge_id);
create index utility_bills_created_by_idx on public.utility_bills (created_by);

create trigger utility_bills_touch_updated_at
  before update on public.utility_bills
  for each row execute function private.touch_updated_at();

alter table public.charges
  add constraint charges_utility_bill_fkey foreign key (utility_bill_id)
    references public.utility_bills (id) on delete set null;

create type public.meter_reading_context as enum ('move_in', 'move_out', 'monthly', 'other');

create table public.meter_readings (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  utility_account_id uuid not null,
  lease_id uuid,
  reading numeric(12, 2) not null constraint meter_readings_reading_check check (reading >= 0),
  read_on date not null,
  context public.meter_reading_context not null default 'other',
  notes text
    constraint meter_readings_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint meter_readings_account_fkey foreign key (utility_account_id, portfolio_id)
    references public.utility_accounts (id, portfolio_id) on delete cascade,
  constraint meter_readings_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade
);

comment on table public.meter_readings is 'Meter readings, especially at move-in and move-out.';

create index meter_readings_account_read_idx on public.meter_readings (utility_account_id, read_on desc);
create index meter_readings_account_fk_idx on public.meter_readings (utility_account_id, portfolio_id);
create index meter_readings_lease_fk_idx on public.meter_readings (lease_id, portfolio_id);
create index meter_readings_portfolio_id_idx on public.meter_readings (portfolio_id);
create index meter_readings_created_by_idx on public.meter_readings (created_by);

-- Charges a utility bill to the tenant of a lease on the same property.
-- Idempotent: returns the existing live charge if already billed.
create or replace function public.bill_utility_to_tenant(p_bill_id uuid, p_lease_id uuid)
returns public.charges
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_bill public.utility_bills;
  v_account public.utility_accounts;
  v_lease public.leases;
  v_charge public.charges;
begin
  select b.* into v_bill from public.utility_bills b where b.id = p_bill_id;
  if not found then
    perform app.forbid();
  end if;
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager', 'accountant']::public.member_role[]);
  if v_lease.portfolio_id <> v_bill.portfolio_id then
    perform app.forbid();
  end if;

  select a.* into v_account from public.utility_accounts a where a.id = v_bill.utility_account_id;
  if not exists (
    select 1 from public.units u
    where u.id = v_lease.unit_id and u.property_id = v_account.property_id
      and (v_account.unit_id is null or v_account.unit_id = u.id)
  ) then
    perform app.fail('lease_not_on_this_connection');
  end if;

  select b.* into v_bill from public.utility_bills b where b.id = p_bill_id for update;
  if v_bill.charge_id is not null then
    select c.* into v_charge from public.charges c where c.id = v_bill.charge_id;
    if found and v_charge.voided_at is null then
      return v_charge;
    end if;
  end if;
  if v_bill.amount <= 0 then
    perform app.fail('invalid_amount');
  end if;

  insert into public.charges (
    portfolio_id, lease_id, kind, period_month, due_date, amount, description, source, utility_bill_id
  )
  values (
    v_lease.portfolio_id, p_lease_id,
    case v_account.type
      when 'electricity' then 'electricity'::public.charge_kind
      when 'gas' then 'gas'::public.charge_kind
      when 'water' then 'water'::public.charge_kind
      when 'internet' then 'internet'::public.charge_kind
      else 'other'::public.charge_kind
    end,
    v_bill.billing_month,
    coalesce(v_bill.due_date, app.today_pkt()),
    v_bill.amount,
    left(initcap(replace(v_account.type::text, '_', ' ')) || ' bill ' || to_char(v_bill.billing_month, 'Mon YYYY'), 200),
    'utility_bill',
    v_bill.id
  )
  returning * into v_charge;

  update public.utility_bills set charge_id = v_charge.id where id = v_bill.id;
  perform private.apply_lease_credit(p_lease_id);

  select c.* into v_charge from public.charges c where c.id = v_charge.id;
  return v_charge;
end
$$;

-- ---------------------------------------------------------------------------
-- Cash handovers (caretaker → owner) for overseas-owner accountability
-- ---------------------------------------------------------------------------

create table public.cash_handovers (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  from_user_id uuid references auth.users (id) on delete set null,
  to_user_id uuid references auth.users (id) on delete set null,
  amount numeric(14, 2) not null constraint cash_handovers_amount_check check (amount > 0),
  handed_over_on date not null,
  method public.payment_method not null default 'cash'
    constraint cash_handovers_method_check check (method <> 'deposit_adjustment'),
  reference text
    constraint cash_handovers_reference_check check (char_length(reference) <= 80 and app.is_clean_text(reference)),
  notes text
    constraint cash_handovers_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users (id) on delete set null,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  voided_at timestamptz,
  void_reason text
    constraint cash_handovers_void_reason_check
      check (char_length(void_reason) <= 300 and app.is_clean_text(void_reason)),
  voided_by uuid references auth.users (id) on delete set null
);

comment on table public.cash_handovers is
  'Cash collected by a caretaker and passed on (in person, bank, Raast). Owners confirm receipt.';

create index cash_handovers_portfolio_date_idx on public.cash_handovers (portfolio_id, handed_over_on desc);
create index cash_handovers_from_user_idx on public.cash_handovers (from_user_id);
create index cash_handovers_to_user_idx on public.cash_handovers (to_user_id);
create index cash_handovers_confirmed_by_idx on public.cash_handovers (confirmed_by);
create index cash_handovers_created_by_idx on public.cash_handovers (created_by);
create index cash_handovers_voided_by_idx on public.cash_handovers (voided_by);

create trigger cash_handovers_touch_updated_at
  before update on public.cash_handovers
  for each row execute function private.touch_updated_at();

-- Owners confirm (or void) handovers; nobody else can.
create or replace function public.confirm_cash_handover(p_handover_id uuid)
returns public.cash_handovers
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_handover public.cash_handovers;
begin
  select h.* into v_handover from public.cash_handovers h where h.id = p_handover_id;
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_handover.portfolio_id, array['owner']::public.member_role[]);
  if v_handover.voided_at is not null then
    perform app.fail('already_voided');
  end if;

  update public.cash_handovers
  set confirmed_at = coalesce(confirmed_at, now()), confirmed_by = coalesce(confirmed_by, (select auth.uid()))
  where id = p_handover_id
  returning * into v_handover;
  return v_handover;
end
$$;

create or replace function public.void_cash_handover(p_handover_id uuid, p_reason text)
returns public.cash_handovers
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_handover public.cash_handovers;
begin
  select h.* into v_handover from public.cash_handovers h where h.id = p_handover_id;
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_handover.portfolio_id, array['owner']::public.member_role[]);
  if char_length(btrim(coalesce(p_reason, ''))) = 0 then
    perform app.fail('reason_required');
  end if;

  update public.cash_handovers
  set voided_at = now(), void_reason = left(btrim(p_reason), 300), voided_by = (select auth.uid())
  where id = p_handover_id and voided_at is null
  returning * into v_handover;
  if not found then
    perform app.fail('already_voided');
  end if;
  return v_handover;
end
$$;

-- ---------------------------------------------------------------------------
-- Reminder log (WhatsApp reminders are sent from the landlord's own phone
-- through wa.me links; this records what was sent and when)
-- ---------------------------------------------------------------------------

create type public.reminder_channel as enum ('whatsapp', 'sms', 'call', 'in_person', 'other');

create table public.reminder_logs (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  channel public.reminder_channel not null,
  template text not null constraint reminder_logs_template_check check (template ~ '^[a-z_]{1,40}$'),
  language text not null constraint reminder_logs_language_check check (language in ('en', 'ur', 'roman_ur')),
  message_preview text
    constraint reminder_logs_message_preview_check
      check (char_length(message_preview) <= 1000 and app.is_clean_text(message_preview)),
  sent_by uuid default auth.uid() references auth.users (id) on delete set null,
  sent_at timestamptz not null default now(),
  constraint reminder_logs_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade
);

create index reminder_logs_lease_sent_idx on public.reminder_logs (lease_id, sent_at desc);
create index reminder_logs_lease_fk_idx on public.reminder_logs (lease_id, portfolio_id);
create index reminder_logs_portfolio_id_idx on public.reminder_logs (portfolio_id);
create index reminder_logs_sent_by_idx on public.reminder_logs (sent_by);

-- ---------------------------------------------------------------------------
-- Row Level Security & grants
-- ---------------------------------------------------------------------------

select private.apply_portfolio_policies(
  'public.maintenance_requests', array['owner', 'manager']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.expenses', array['owner', 'manager', 'accountant']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.utility_accounts', array['owner', 'manager']::public.member_role[],
  array['owner']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.utility_bills', array['owner', 'manager', 'accountant']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);
select private.apply_portfolio_policies(
  'public.meter_readings', array['owner', 'manager', 'accountant']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);

-- Handovers: members who handle money record them (only as the giver unless
-- an owner); confirmation and voiding go through owner-only RPCs.
alter table public.cash_handovers enable row level security;
create policy cash_handovers_select on public.cash_handovers
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
create policy cash_handovers_insert on public.cash_handovers
  for insert to authenticated
  with check (
    portfolio_id = any ((select app.my_portfolio_ids(
      array['owner', 'manager', 'accountant']::public.member_role[]))::uuid[])
    and (
      from_user_id = (select auth.uid())
      or portfolio_id = any ((select app.my_portfolio_ids(array['owner']::public.member_role[]))::uuid[])
    )
  );

-- Reminder log: money-handling members append; everyone reads.
alter table public.reminder_logs enable row level security;
create policy reminder_logs_select on public.reminder_logs
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
create policy reminder_logs_insert on public.reminder_logs
  for insert to authenticated
  with check (portfolio_id = any ((select app.my_portfolio_ids(
    array['owner', 'manager', 'accountant']::public.member_role[]))::uuid[]));

grant select, delete on public.maintenance_requests to authenticated;
grant insert (
  id, portfolio_id, property_id, unit_id, lease_id, title, description, category, priority, status,
  reported_by, reported_on, assigned_to, vendor_phone, estimated_cost, resolved_on, resolution_note
) on public.maintenance_requests to authenticated;
grant update (
  unit_id, lease_id, title, description, category, priority, status, reported_by, reported_on,
  assigned_to, vendor_phone, estimated_cost, resolved_on, resolution_note
) on public.maintenance_requests to authenticated;

grant select, delete on public.expenses to authenticated;
grant insert (
  id, portfolio_id, property_id, unit_id, maintenance_request_id, category, amount, spent_on, payee,
  method, reference, notes, paid_by
) on public.expenses to authenticated;
grant update (
  property_id, unit_id, maintenance_request_id, category, amount, spent_on, payee, method, reference,
  notes, paid_by
) on public.expenses to authenticated;

grant select, delete on public.utility_accounts to authenticated;
grant insert (
  id, portfolio_id, property_id, unit_id, type, provider, provider_other, reference_number,
  customer_id, meter_number, account_title, in_landlord_name, is_sub_meter, is_protected_consumer,
  responsibility, notes
) on public.utility_accounts to authenticated;
grant update (
  unit_id, type, provider, provider_other, reference_number, customer_id, meter_number,
  account_title, in_landlord_name, is_sub_meter, is_protected_consumer, responsibility, notes,
  archived_at
) on public.utility_accounts to authenticated;

grant select, delete on public.utility_bills to authenticated;
grant insert (
  id, portfolio_id, utility_account_id, billing_month, amount, due_date, units_consumed, status,
  paid_on, paid_by, notes
) on public.utility_bills to authenticated;
grant update (amount, due_date, units_consumed, status, paid_on, paid_by, notes)
  on public.utility_bills to authenticated;

grant select, delete on public.meter_readings to authenticated;
grant insert (id, portfolio_id, utility_account_id, lease_id, reading, read_on, context, notes)
  on public.meter_readings to authenticated;
grant update (reading, read_on, context, notes) on public.meter_readings to authenticated;

grant select on public.cash_handovers to authenticated;
grant insert (
  id, portfolio_id, from_user_id, to_user_id, amount, handed_over_on, method, reference, notes
) on public.cash_handovers to authenticated;
grant select, insert, update, delete on public.cash_handovers to service_role;

grant select on public.reminder_logs to authenticated;
grant insert (id, portfolio_id, lease_id, channel, template, language, message_preview)
  on public.reminder_logs to authenticated;
grant select, insert, update, delete on public.reminder_logs to service_role;

grant execute on function public.bill_utility_to_tenant(uuid, uuid) to authenticated;
grant execute on function public.confirm_cash_handover(uuid) to authenticated;
grant execute on function public.void_cash_handover(uuid, text) to authenticated;
