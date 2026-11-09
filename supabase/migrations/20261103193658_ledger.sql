-- ============================================================================
-- Ledger: charges (dues), payments (money in), allocations (which payment
-- settled which due), security-deposit refunds and receipt numbering.
--
-- Invariants (enforced by constraints, functions and pgTAP tests):
--   * charges.paid_amount = Σ allocations; paid + waived ≤ amount
--   * payments.allocated_amount = Σ allocations ≤ amount + tax_withheld
--   * money rows are never deleted; they are voided with a reason
--   * payment writes happen only in SECURITY DEFINER functions that lock the
--     lease row first, so concurrent writes on one lease are serialised
--   * receipt numbers are gapless per portfolio per year
--   * an idempotency key per payment makes client retries safe
-- ============================================================================

create type public.charge_kind as enum (
  'rent', 'security_deposit', 'electricity', 'gas', 'water', 'internet', 'maintenance',
  'society_charges', 'late_fee', 'damages', 'other'
);

create type public.payment_method as enum (
  'cash', 'bank_transfer', 'raast', 'jazzcash', 'easypaisa', 'cheque', 'card',
  'deposit_adjustment', 'other'
);

-- ---------------------------------------------------------------------------
-- Charges
-- ---------------------------------------------------------------------------

create table public.charges (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  kind public.charge_kind not null,
  period_month date
    constraint charges_period_month_check check (extract(day from period_month) = 1),
  due_date date not null,
  amount numeric(14, 2) not null constraint charges_amount_check check (amount > 0),
  paid_amount numeric(14, 2) not null default 0 constraint charges_paid_amount_check check (paid_amount >= 0),
  waived_amount numeric(14, 2) not null default 0
    constraint charges_waived_amount_check check (waived_amount >= 0),
  outstanding numeric(14, 2) generated always as (amount - paid_amount - waived_amount) stored,
  description text
    constraint charges_description_check
      check (char_length(description) <= 200 and app.is_clean_text(description)),
  source text not null default 'manual'
    constraint charges_source_check
      check (source in ('manual', 'auto_rent', 'auto_late_fee', 'deposit', 'utility_bill')),
  related_charge_id uuid references public.charges (id) on delete cascade,
  utility_bill_id uuid,
  waive_reason text
    constraint charges_waive_reason_check
      check (char_length(waive_reason) <= 300 and app.is_clean_text(waive_reason)),
  voided_at timestamptz,
  void_reason text
    constraint charges_void_reason_check
      check (char_length(void_reason) <= 300 and app.is_clean_text(void_reason)),
  voided_by uuid references auth.users (id) on delete set null,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint charges_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete cascade,
  constraint charges_id_portfolio_key unique (id, portfolio_id),
  constraint charges_not_overpaid_check check (paid_amount + waived_amount <= amount),
  constraint charges_void_requires_unpaid_check check (voided_at is null or paid_amount = 0),
  constraint charges_rent_period_check check (kind <> 'rent' or period_month is not null),
  constraint charges_related_kind_check check (related_charge_id is null or kind = 'late_fee')
);

comment on table public.charges is 'Amounts a tenant owes (rent, deposit, utilities, fees…).';
comment on column public.charges.outstanding is 'amount − paid_amount − waived_amount.';
comment on column public.charges.period_month is 'First day of the month the charge relates to (required for rent).';

-- One rent charge per lease per month, ever (a voided month is not re-billed).
create unique index charges_rent_period_key on public.charges (lease_id, period_month) where kind = 'rent';
-- At most one automatic late fee per overdue charge.
create unique index charges_late_fee_key on public.charges (related_charge_id)
  where kind = 'late_fee' and related_charge_id is not null;
-- At most one live deposit due per lease.
create unique index charges_deposit_key on public.charges (lease_id)
  where kind = 'security_deposit' and source = 'deposit' and voided_at is null;
create index charges_portfolio_due_idx on public.charges (portfolio_id, due_date) where voided_at is null;
create index charges_open_idx on public.charges (lease_id, due_date, id)
  where voided_at is null and outstanding > 0;
create index charges_lease_fk_idx on public.charges (lease_id, portfolio_id);
create index charges_related_charge_id_idx on public.charges (related_charge_id);
create index charges_utility_bill_id_idx on public.charges (utility_bill_id);
create index charges_created_by_idx on public.charges (created_by);
create index charges_voided_by_idx on public.charges (voided_by);

create trigger charges_touch_updated_at
  before update on public.charges
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------

create table public.payments (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  amount numeric(14, 2) not null constraint payments_amount_check check (amount > 0),
  tax_withheld numeric(14, 2) not null default 0
    constraint payments_tax_withheld_check check (tax_withheld >= 0 and tax_withheld <= amount),
  applied_amount numeric(14, 2) generated always as (amount + tax_withheld) stored,
  allocated_amount numeric(14, 2) not null default 0
    constraint payments_allocated_amount_check check (allocated_amount >= 0),
  unallocated_amount numeric(14, 2) generated always as (amount + tax_withheld - allocated_amount) stored,
  paid_on date not null,
  method public.payment_method not null,
  reference text
    constraint payments_reference_check check (char_length(reference) <= 80 and app.is_clean_text(reference)),
  tax_certificate_no text
    constraint payments_tax_certificate_no_check
      check (char_length(tax_certificate_no) <= 60 and app.is_clean_text(tax_certificate_no)),
  notes text constraint payments_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  receipt_number text not null,
  received_by uuid default auth.uid() references auth.users (id) on delete set null,
  idempotency_key uuid not null,
  voided_at timestamptz,
  void_reason text
    constraint payments_void_reason_check
      check (char_length(void_reason) <= 300 and app.is_clean_text(void_reason)),
  voided_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete no action,
  constraint payments_id_portfolio_key unique (id, portfolio_id),
  constraint payments_receipt_number_key unique (portfolio_id, receipt_number),
  constraint payments_idempotency_key unique (portfolio_id, idempotency_key),
  constraint payments_allocation_check check (allocated_amount <= amount + tax_withheld),
  constraint payments_void_unallocated_check check (voided_at is null or allocated_amount = 0)
);

comment on table public.payments is
  'Money received for a lease. Written only via record_payment/apply_deposit; voided, never deleted.';
comment on column public.payments.amount is 'Cash actually received.';
comment on column public.payments.tax_withheld is
  'Income tax deducted at source by the tenant (s.155); settles dues together with amount.';

create index payments_lease_paid_idx on public.payments (lease_id, paid_on desc);
create index payments_portfolio_paid_idx on public.payments (portfolio_id, paid_on desc) where voided_at is null;
create index payments_lease_fk_idx on public.payments (lease_id, portfolio_id);
create index payments_unallocated_idx on public.payments (lease_id, paid_on, id)
  where voided_at is null and unallocated_amount > 0;
create index payments_received_by_idx on public.payments (received_by);
create index payments_voided_by_idx on public.payments (voided_by);

create trigger payments_touch_updated_at
  before update on public.payments
  for each row execute function private.touch_updated_at();

create table public.payment_allocations (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  payment_id uuid not null,
  charge_id uuid not null,
  amount numeric(14, 2) not null constraint payment_allocations_amount_check check (amount > 0),
  created_at timestamptz not null default now(),
  constraint payment_allocations_payment_fkey foreign key (payment_id, portfolio_id)
    references public.payments (id, portfolio_id) on delete cascade,
  constraint payment_allocations_charge_fkey foreign key (charge_id, portfolio_id)
    references public.charges (id, portfolio_id) on delete cascade,
  constraint payment_allocations_payment_charge_key unique (payment_id, charge_id)
);

comment on table public.payment_allocations is 'How much of each payment settled each charge.';

create index payment_allocations_portfolio_id_idx on public.payment_allocations (portfolio_id);
create index payment_allocations_charge_fk_idx on public.payment_allocations (charge_id, portfolio_id);
create index payment_allocations_payment_fk_idx on public.payment_allocations (payment_id, portfolio_id);

create table public.deposit_refunds (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  lease_id uuid not null,
  amount numeric(14, 2) not null constraint deposit_refunds_amount_check check (amount > 0),
  refunded_on date not null,
  method public.payment_method not null
    constraint deposit_refunds_method_check check (method <> 'deposit_adjustment'),
  reference text
    constraint deposit_refunds_reference_check check (char_length(reference) <= 80 and app.is_clean_text(reference)),
  notes text
    constraint deposit_refunds_notes_check check (char_length(notes) <= 500 and app.is_clean_text(notes)),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  void_reason text
    constraint deposit_refunds_void_reason_check
      check (char_length(void_reason) <= 300 and app.is_clean_text(void_reason)),
  voided_by uuid references auth.users (id) on delete set null,
  constraint deposit_refunds_lease_fkey foreign key (lease_id, portfolio_id)
    references public.leases (id, portfolio_id) on delete no action
);

comment on table public.deposit_refunds is 'Security deposit paid back to the tenant.';

create index deposit_refunds_portfolio_id_idx on public.deposit_refunds (portfolio_id);
create index deposit_refunds_lease_fk_idx on public.deposit_refunds (lease_id, portfolio_id);
create index deposit_refunds_created_by_idx on public.deposit_refunds (created_by);
create index deposit_refunds_voided_by_idx on public.deposit_refunds (voided_by);

create table private.receipt_counters (
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  year integer not null,
  last_value integer not null,
  primary key (portfolio_id, year)
);

comment on table private.receipt_counters is 'Gapless receipt sequence per portfolio and calendar year.';

-- ---------------------------------------------------------------------------
-- Internal ledger engine
-- ---------------------------------------------------------------------------

-- Next receipt number, e.g. MM-2026-00042. Runs inside the payment's
-- transaction, so a rolled-back payment never consumes a number.
create or replace function private.next_receipt_number(p_portfolio_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_year integer := extract(year from app.today_pkt())::integer;
  v_value integer;
  v_prefix text;
begin
  insert into private.receipt_counters as c (portfolio_id, year, last_value)
  values (p_portfolio_id, v_year, 1)
  on conflict (portfolio_id, year) do update set last_value = c.last_value + 1
  returning c.last_value into v_value;

  select p.receipt_prefix into v_prefix from public.portfolios p where p.id = p_portfolio_id;
  return v_prefix || '-' || v_year::text || '-' || lpad(v_value::text, 5, '0');
end
$$;

-- Applies a payment's unallocated amount to the lease's open charges: the
-- explicitly chosen charges first (in the order given), then oldest due date
-- first (ties broken by id, which is time-ordered). Deposit adjustments never
-- pay the deposit itself. The caller must hold the lease row lock.
create or replace function private.allocate_payment(
  p_payment_id uuid,
  p_charge_ids uuid[] default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
  v_remaining numeric(14, 2);
  v_charge record;
  v_apply numeric(14, 2);
begin
  select p.* into v_payment from public.payments p where p.id = p_payment_id for update;
  if not found or v_payment.voided_at is not null then
    return;
  end if;
  v_remaining := v_payment.unallocated_amount;
  if v_remaining <= 0 then
    return;
  end if;

  for v_charge in
    select c.id, c.outstanding
    from public.charges c
    where c.lease_id = v_payment.lease_id
      and c.voided_at is null
      and c.outstanding > 0
      and not (v_payment.method = 'deposit_adjustment' and c.kind = 'security_deposit')
    order by coalesce(array_position(p_charge_ids, c.id), 2147483647), c.due_date, c.id
    for update of c
  loop
    exit when v_remaining <= 0;
    v_apply := least(v_remaining, v_charge.outstanding);

    insert into public.payment_allocations (portfolio_id, payment_id, charge_id, amount)
    values (v_payment.portfolio_id, v_payment.id, v_charge.id, v_apply)
    on conflict (payment_id, charge_id)
      do update set amount = public.payment_allocations.amount + excluded.amount;

    update public.charges set paid_amount = paid_amount + v_apply where id = v_charge.id;
    v_remaining := v_remaining - v_apply;
  end loop;

  update public.payments
  set allocated_amount = amount + tax_withheld - v_remaining
  where id = v_payment.id;
end
$$;

-- Re-applies all unallocated credit on a lease, oldest payment first.
-- The caller must hold the lease row lock.
create or replace function private.apply_lease_credit(p_lease_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_payment_id uuid;
begin
  for v_payment_id in
    select p.id
    from public.payments p
    where p.lease_id = p_lease_id and p.voided_at is null and p.unallocated_amount > 0
    order by p.paid_on, p.id
  loop
    perform private.allocate_payment(v_payment_id);
  end loop;
end
$$;

-- Generates the monthly rent charges of an active lease from its billing
-- start through the month of p_as_of (idempotent), prorating the first
-- billed month by day when configured, then applies any credit.
-- Returns the number of charges created.
create or replace function private.sync_lease_billing(p_lease_id uuid, p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_lease public.leases;
  v_month date;
  v_last_month date;
  v_rent numeric(14, 2);
  v_amount numeric(14, 2);
  v_rows integer;
  v_created integer := 0;
begin
  select l.* into v_lease from public.leases l where l.id = p_lease_id for update;
  if not found or v_lease.status <> 'active' then
    return 0;
  end if;

  v_month := date_trunc('month', v_lease.billing_starts_on)::date;
  v_last_month := date_trunc('month', v_as_of)::date;

  while v_month <= v_last_month loop
    select rc.monthly_rent into v_rent
    from public.rent_changes rc
    where rc.lease_id = v_lease.id and rc.effective_from <= v_month
    order by rc.effective_from desc
    limit 1;
    v_rent := coalesce(v_rent, v_lease.monthly_rent);
    v_amount := case
      when v_lease.prorate_first_month then app.prorated_rent(v_rent, v_month, v_lease.billing_starts_on)
      else v_rent
    end;

    if v_amount > 0 then
      insert into public.charges
        (portfolio_id, lease_id, kind, period_month, due_date, amount, source, created_by)
      values (
        v_lease.portfolio_id, v_lease.id, 'rent', v_month,
        -- A tenant is never due before moving in (first, prorated month).
        greatest(app.due_date_for(v_month, v_lease.rent_due_day), v_lease.billing_starts_on),
        v_amount, 'auto_rent', null
      )
      on conflict (lease_id, period_month) where kind = 'rent' do nothing;
      get diagnostics v_rows = row_count;
      v_created := v_created + v_rows;
    end if;

    v_month := (v_month + interval '1 month')::date;
  end loop;

  if v_created > 0 then
    perform private.apply_lease_credit(v_lease.id);
  end if;
  return v_created;
end
$$;

-- Security deposit position of a lease.
create or replace function private.deposit_position(p_lease_id uuid)
returns table (agreed numeric, received numeric, applied numeric, refunded numeric, held numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with received as (
    select coalesce(sum(a.amount), 0) as value
    from public.payment_allocations a
    join public.charges c on c.id = a.charge_id
    join public.payments p on p.id = a.payment_id
    where c.lease_id = p_lease_id and c.kind = 'security_deposit' and p.voided_at is null
  ),
  applied as (
    select coalesce(sum(p.amount), 0) as value
    from public.payments p
    where p.lease_id = p_lease_id and p.method = 'deposit_adjustment' and p.voided_at is null
  ),
  refunded as (
    select coalesce(sum(r.amount), 0) as value
    from public.deposit_refunds r
    where r.lease_id = p_lease_id and r.voided_at is null
  )
  select
    l.security_deposit,
    received.value,
    applied.value,
    refunded.value,
    received.value - applied.value - refunded.value
  from public.leases l, received, applied, refunded
  where l.id = p_lease_id
$$;

-- Response body shared by the payment RPCs.
create or replace function private.payment_result(p_payment_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'payment', to_jsonb(p),
    'allocations', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'charge_id', a.charge_id,
          'amount', a.amount,
          'kind', c.kind,
          'period_month', c.period_month,
          'due_date', c.due_date
        )
        order by c.due_date, c.id
      )
      from public.payment_allocations a
      join public.charges c on c.id = a.charge_id
      where a.payment_id = p.id
    ), '[]'::jsonb),
    'lease_outstanding', (
      select coalesce(sum(c.outstanding), 0)
      from public.charges c
      where c.lease_id = p.lease_id and c.voided_at is null
    ),
    'lease_credit', (
      select coalesce(sum(x.unallocated_amount), 0)
      from public.payments x
      where x.lease_id = p.lease_id and x.voided_at is null
    )
  )
  from public.payments p
  where p.id = p_payment_id
$$;

-- Loads a lease for a write RPC: authorises the caller and locks the row.
create or replace function private.lock_lease_for_write(
  p_lease_id uuid,
  p_roles public.member_role[]
)
returns public.leases
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
  v_lease public.leases;
begin
  select l.portfolio_id into v_portfolio_id from public.leases l where l.id = p_lease_id;
  -- Same error for "missing" and "not yours": never confirm existence.
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_portfolio_id, p_roles);
  select l.* into v_lease from public.leases l where l.id = p_lease_id for update;
  return v_lease;
end
$$;

create or replace function private.require_valid_amount(p_amount numeric, p_allow_zero boolean default false)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_amount is null
     or (p_allow_zero and p_amount < 0)
     or (not p_allow_zero and p_amount <= 0)
     or p_amount > 999999999999.99
     or p_amount <> round(p_amount, 2) then
    perform app.fail('invalid_amount');
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Lease lifecycle triggers (need the ledger tables)
-- ---------------------------------------------------------------------------

create or replace function private.after_lease_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.rent_changes (portfolio_id, lease_id, effective_from, monthly_rent, reason, created_by)
  values (
    new.portfolio_id, new.id, date_trunc('month', new.billing_starts_on)::date,
    new.monthly_rent, 'initial', new.created_by
  );

  if new.security_deposit > 0 then
    insert into public.charges
      (portfolio_id, lease_id, kind, due_date, amount, source, description, created_by)
    values (
      new.portfolio_id, new.id, 'security_deposit', new.start_date, new.security_deposit,
      'deposit', null, new.created_by
    );
  end if;

  perform private.sync_lease_billing(new.id, app.today_pkt());
  return null;
end
$$;

create trigger leases_after_insert
  after insert on public.leases
  for each row execute function private.after_lease_insert();

-- Keeps the deposit due in step with leases.security_deposit.
create or replace function private.after_lease_deposit_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_charge public.charges;
begin
  select c.* into v_charge
  from public.charges c
  where c.lease_id = new.id and c.kind = 'security_deposit' and c.source = 'deposit' and c.voided_at is null
  for update;

  if not found then
    if new.security_deposit > 0 then
      insert into public.charges (portfolio_id, lease_id, kind, due_date, amount, source)
      values (new.portfolio_id, new.id, 'security_deposit', new.start_date, new.security_deposit, 'deposit');
    end if;
  elsif new.security_deposit < v_charge.paid_amount + v_charge.waived_amount then
    perform app.fail('deposit_below_received');
  elsif new.security_deposit = 0 then
    update public.charges
    set voided_at = now(), void_reason = 'Deposit removed from the lease', voided_by = (select auth.uid())
    where id = v_charge.id;
  else
    update public.charges set amount = new.security_deposit where id = v_charge.id;
  end if;
  return null;
end
$$;

create trigger leases_after_deposit_update
  after update of security_deposit on public.leases
  for each row
  when (old.security_deposit is distinct from new.security_deposit)
  execute function private.after_lease_deposit_update();

-- Moves the due date of untouched current/future rent charges when the
-- lease's due day changes.
create or replace function private.after_lease_due_day_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.charges c
  set due_date = greatest(app.due_date_for(c.period_month, new.rent_due_day), new.billing_starts_on)
  where c.lease_id = new.id
    and c.kind = 'rent'
    and c.voided_at is null
    and c.paid_amount = 0
    and c.period_month >= date_trunc('month', app.today_pkt())::date;
  return null;
end
$$;

create trigger leases_after_due_day_update
  after update of rent_due_day on public.leases
  for each row
  when (old.rent_due_day is distinct from new.rent_due_day)
  execute function private.after_lease_due_day_update();

-- Manual charges pick up any unallocated credit immediately.
create or replace function private.after_manual_charge_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.leases where id = new.lease_id for update;
  perform private.apply_lease_credit(new.lease_id);
  return null;
end
$$;

create trigger charges_after_manual_insert
  after insert on public.charges
  for each row
  when (new.source = 'manual')
  execute function private.after_manual_charge_insert();

-- Client edits may only touch the amount of manual charges, and only before
-- they are voided. System functions (running as the table owner) are exempt.
create or replace function private.before_charge_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if old.voided_at is not null then
      perform app.fail('charge_voided');
    end if;
    if new.amount is distinct from old.amount and old.source <> 'manual' then
      perform app.fail('charge_not_editable');
    end if;
  end if;
  return new;
end
$$;

create trigger charges_before_update
  before update on public.charges
  for each row execute function private.before_charge_update();

-- ---------------------------------------------------------------------------
-- Public RPCs
-- ---------------------------------------------------------------------------

-- Records money received for a lease and allocates it (chosen charges first,
-- then oldest due first). Idempotent per p_idempotency_key: retrying returns
-- the original result. tax_withheld (s.155) settles dues alongside the cash.
create or replace function public.record_payment(
  p_lease_id uuid,
  p_amount numeric,
  p_paid_on date,
  p_method public.payment_method,
  p_idempotency_key uuid,
  p_reference text default null,
  p_notes text default null,
  p_tax_withheld numeric default 0,
  p_tax_certificate_no text default null,
  p_charge_ids uuid[] default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_payment public.payments;
  v_tax numeric := coalesce(p_tax_withheld, 0);
begin
  v_lease := private.lock_lease_for_write(
    p_lease_id, array['owner', 'manager', 'accountant']::public.member_role[]
  );

  if p_idempotency_key is null then
    perform app.fail('idempotency_key_required');
  end if;
  select p.* into v_payment
  from public.payments p
  where p.portfolio_id = v_lease.portfolio_id and p.idempotency_key = p_idempotency_key;
  if found then
    if v_payment.lease_id <> p_lease_id or v_payment.amount <> p_amount then
      perform app.fail('idempotency_key_reused');
    end if;
    return private.payment_result(v_payment.id);
  end if;

  perform private.enforce_rate_limit('record_payment', 60, interval '1 minute');
  perform private.require_valid_amount(p_amount);
  perform private.require_valid_amount(v_tax, true);
  if v_tax > p_amount then
    perform app.fail('invalid_tax_withheld');
  end if;
  if p_method is null or p_method = 'deposit_adjustment' then
    perform app.fail('invalid_method');
  end if;
  if p_paid_on is null
     or p_paid_on > app.today_pkt() + 1
     or p_paid_on < v_lease.start_date - 366 then
    perform app.fail('invalid_date');
  end if;
  if p_charge_ids is not null and exists (
    select 1
    from unnest(p_charge_ids) as chosen(id)
    where not exists (
      select 1 from public.charges c
      where c.id = chosen.id and c.lease_id = p_lease_id and c.voided_at is null and c.outstanding > 0
    )
  ) then
    perform app.fail('invalid_charge_selection');
  end if;

  insert into public.payments (
    portfolio_id, lease_id, amount, tax_withheld, paid_on, method, reference,
    tax_certificate_no, notes, receipt_number, received_by, idempotency_key
  )
  values (
    v_lease.portfolio_id, p_lease_id, p_amount, v_tax, p_paid_on, p_method,
    nullif(btrim(p_reference), ''), nullif(btrim(p_tax_certificate_no), ''),
    nullif(btrim(p_notes), ''), private.next_receipt_number(v_lease.portfolio_id),
    (select auth.uid()), p_idempotency_key
  )
  returning * into v_payment;

  perform private.allocate_payment(v_payment.id, p_charge_ids);
  return private.payment_result(v_payment.id);
end
$$;

-- Voids a payment, reversing its allocations, then re-applies other credit.
create or replace function public.void_payment(p_payment_id uuid, p_reason text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_payment public.payments;
  v_allocation record;
  v_held numeric;
begin
  select p.lease_id into v_lease_id from public.payments p where p.id = p_payment_id;
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_lease_for_write(v_lease_id, array['owner', 'manager']::public.member_role[]);

  if char_length(btrim(coalesce(p_reason, ''))) = 0 then
    perform app.fail('reason_required');
  end if;

  select p.* into v_payment from public.payments p where p.id = p_payment_id for update;
  if v_payment.voided_at is not null then
    perform app.fail('already_voided');
  end if;

  for v_allocation in
    select a.charge_id, a.amount
    from public.payment_allocations a
    join public.charges c on c.id = a.charge_id
    where a.payment_id = p_payment_id
    order by c.due_date, c.id
  loop
    update public.charges set paid_amount = paid_amount - v_allocation.amount where id = v_allocation.charge_id;
  end loop;
  delete from public.payment_allocations where payment_id = p_payment_id;

  update public.payments
  set voided_at = now(), void_reason = btrim(p_reason), voided_by = (select auth.uid()), allocated_amount = 0
  where id = p_payment_id;

  perform private.apply_lease_credit(v_lease_id);

  select d.held into v_held from private.deposit_position(v_lease_id) d;
  if v_held < 0 then
    perform app.fail('deposit_already_used');
  end if;

  return private.payment_result(p_payment_id);
end
$$;

-- Waives all (p_amount null) or part of a charge's outstanding balance.
create or replace function public.waive_charge(p_charge_id uuid, p_reason text, p_amount numeric default null)
returns public.charges
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_charge public.charges;
  v_amount numeric;
begin
  select c.lease_id into v_lease_id from public.charges c where c.id = p_charge_id;
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_lease_for_write(v_lease_id, array['owner', 'manager']::public.member_role[]);

  if char_length(btrim(coalesce(p_reason, ''))) = 0 then
    perform app.fail('reason_required');
  end if;
  select c.* into v_charge from public.charges c where c.id = p_charge_id for update;
  if v_charge.voided_at is not null then
    perform app.fail('charge_voided');
  end if;

  v_amount := coalesce(p_amount, v_charge.outstanding);
  perform private.require_valid_amount(v_amount);
  if v_amount > v_charge.outstanding then
    perform app.fail('amount_exceeds_outstanding');
  end if;

  update public.charges
  set waived_amount = waived_amount + v_amount,
      waive_reason = left(btrim(p_reason), 300)
  where id = p_charge_id
  returning * into v_charge;
  return v_charge;
end
$$;

-- Voids an unpaid charge (and its unpaid automatic late fee).
create or replace function public.void_charge(p_charge_id uuid, p_reason text)
returns public.charges
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_charge public.charges;
begin
  select c.lease_id into v_lease_id from public.charges c where c.id = p_charge_id;
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_lease_for_write(v_lease_id, array['owner', 'manager']::public.member_role[]);

  if char_length(btrim(coalesce(p_reason, ''))) = 0 then
    perform app.fail('reason_required');
  end if;
  select c.* into v_charge from public.charges c where c.id = p_charge_id for update;
  if v_charge.voided_at is not null then
    perform app.fail('charge_voided');
  end if;
  if v_charge.paid_amount > 0 then
    perform app.fail('charge_has_payments');
  end if;

  update public.charges
  set voided_at = now(), void_reason = left(btrim(p_reason), 300), voided_by = (select auth.uid())
  where (id = p_charge_id or (related_charge_id = p_charge_id and paid_amount = 0))
    and voided_at is null;

  select c.* into v_charge from public.charges c where c.id = p_charge_id;
  return v_charge;
end
$$;

-- Changes the rent from a month onwards (increment, renegotiation or
-- correction) and re-prices untouched rent charges from that month.
create or replace function public.change_rent(
  p_lease_id uuid,
  p_effective_month date,
  p_monthly_rent numeric,
  p_reason text default 'annual_increment',
  p_note text default null
)
returns public.leases
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_month date := date_trunc('month', p_effective_month)::date;
begin
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager']::public.member_role[]);

  if v_lease.status <> 'active' then
    perform app.fail('lease_not_active');
  end if;
  perform private.require_valid_amount(p_monthly_rent);
  if p_reason is null or p_reason not in ('annual_increment', 'renegotiation', 'correction') then
    perform app.fail('invalid_reason');
  end if;
  if v_month is null or v_month < date_trunc('month', v_lease.billing_starts_on)::date then
    perform app.fail('invalid_date');
  end if;

  insert into public.rent_changes (portfolio_id, lease_id, effective_from, monthly_rent, reason, note, created_by)
  values (v_lease.portfolio_id, p_lease_id, v_month, p_monthly_rent, p_reason,
          nullif(btrim(p_note), ''), (select auth.uid()))
  on conflict (lease_id, effective_from) do update
    set monthly_rent = excluded.monthly_rent,
        reason = excluded.reason,
        note = excluded.note,
        created_by = excluded.created_by;

  -- Re-price generated rent that nobody has paid or waived yet. A prorated
  -- first month keeps its proportional amount.
  update public.charges c
  set amount = case
    when v_lease.prorate_first_month
    then app.prorated_rent(p_monthly_rent, c.period_month, v_lease.billing_starts_on)
    else p_monthly_rent
  end
  where c.lease_id = p_lease_id
    and c.kind = 'rent'
    and c.source = 'auto_rent'
    and c.period_month >= v_month
    and c.voided_at is null
    and c.paid_amount = 0
    and c.waived_amount = 0;

  update public.leases l
  set monthly_rent = (
    select rc.monthly_rent
    from public.rent_changes rc
    where rc.lease_id = l.id
      and rc.effective_from <= greatest(
        date_trunc('month', app.today_pkt())::date,
        date_trunc('month', l.billing_starts_on)::date
      )
    order by rc.effective_from desc
    limit 1
  )
  where l.id = p_lease_id
  returning * into v_lease;

  return v_lease;
end
$$;

-- Ends a tenancy at the actual move-out date: bills through the move-out
-- month, voids untouched rent for later months and frees the unit.
create or replace function public.end_lease(
  p_lease_id uuid,
  p_moved_out_on date,
  p_reason public.lease_end_reason
)
returns public.leases
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
begin
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager']::public.member_role[]);

  if v_lease.status <> 'active' then
    perform app.fail('lease_not_active');
  end if;
  if p_moved_out_on is null or p_moved_out_on < v_lease.start_date or p_moved_out_on > app.today_pkt() then
    perform app.fail('invalid_date');
  end if;
  if p_reason is null then
    perform app.fail('reason_required');
  end if;

  perform private.sync_lease_billing(p_lease_id, p_moved_out_on);

  update public.charges
  set voided_at = now(), void_reason = 'Lease ended', voided_by = (select auth.uid())
  where lease_id = p_lease_id
    and kind = 'rent'
    and period_month > date_trunc('month', p_moved_out_on)::date
    and paid_amount = 0
    and voided_at is null;

  update public.leases
  set status = 'ended', moved_out_on = p_moved_out_on, end_reason = p_reason, ended_at = now()
  where id = p_lease_id
  returning * into v_lease;

  return v_lease;
end
$$;

-- Uses (part of) the deposit held to settle outstanding dues, typically at
-- move-out. Recorded as a 'deposit_adjustment' payment with its own receipt.
create or replace function public.apply_deposit(
  p_lease_id uuid,
  p_amount numeric,
  p_applied_on date,
  p_idempotency_key uuid,
  p_notes text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_payment public.payments;
  v_held numeric;
  v_open numeric;
begin
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager']::public.member_role[]);

  if p_idempotency_key is null then
    perform app.fail('idempotency_key_required');
  end if;
  select p.* into v_payment
  from public.payments p
  where p.portfolio_id = v_lease.portfolio_id and p.idempotency_key = p_idempotency_key;
  if found then
    if v_payment.lease_id <> p_lease_id or v_payment.amount <> p_amount then
      perform app.fail('idempotency_key_reused');
    end if;
    return private.payment_result(v_payment.id);
  end if;

  perform private.require_valid_amount(p_amount);
  if p_applied_on is null or p_applied_on > app.today_pkt() + 1 or p_applied_on < v_lease.start_date then
    perform app.fail('invalid_date');
  end if;

  select d.held into v_held from private.deposit_position(p_lease_id) d;
  if p_amount > v_held then
    perform app.fail('insufficient_deposit');
  end if;

  select coalesce(sum(c.outstanding), 0) into v_open
  from public.charges c
  where c.lease_id = p_lease_id and c.voided_at is null and c.kind <> 'security_deposit';
  if p_amount > v_open then
    perform app.fail('amount_exceeds_outstanding');
  end if;

  insert into public.payments (
    portfolio_id, lease_id, amount, paid_on, method, notes, receipt_number, received_by, idempotency_key
  )
  values (
    v_lease.portfolio_id, p_lease_id, p_amount, p_applied_on, 'deposit_adjustment',
    nullif(btrim(p_notes), ''), private.next_receipt_number(v_lease.portfolio_id),
    (select auth.uid()), p_idempotency_key
  )
  returning * into v_payment;

  perform private.allocate_payment(v_payment.id);
  return private.payment_result(v_payment.id);
end
$$;

-- Pays (part of) the deposit held back to the tenant.
create or replace function public.refund_deposit(
  p_lease_id uuid,
  p_amount numeric,
  p_refunded_on date,
  p_method public.payment_method,
  p_reference text default null,
  p_notes text default null
)
returns public.deposit_refunds
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_held numeric;
  v_refund public.deposit_refunds;
begin
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager']::public.member_role[]);

  perform private.require_valid_amount(p_amount);
  if p_method is null or p_method = 'deposit_adjustment' then
    perform app.fail('invalid_method');
  end if;
  if p_refunded_on is null or p_refunded_on > app.today_pkt() + 1 or p_refunded_on < v_lease.start_date then
    perform app.fail('invalid_date');
  end if;

  select d.held into v_held from private.deposit_position(p_lease_id) d;
  if p_amount > v_held then
    perform app.fail('insufficient_deposit');
  end if;

  insert into public.deposit_refunds (portfolio_id, lease_id, amount, refunded_on, method, reference, notes)
  values (
    v_lease.portfolio_id, p_lease_id, p_amount, p_refunded_on, p_method,
    nullif(btrim(p_reference), ''), nullif(btrim(p_notes), '')
  )
  returning * into v_refund;
  return v_refund;
end
$$;

create or replace function public.void_deposit_refund(p_refund_id uuid, p_reason text)
returns public.deposit_refunds
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_refund public.deposit_refunds;
begin
  select r.lease_id into v_lease_id from public.deposit_refunds r where r.id = p_refund_id;
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_lease_for_write(v_lease_id, array['owner']::public.member_role[]);
  if char_length(btrim(coalesce(p_reason, ''))) = 0 then
    perform app.fail('reason_required');
  end if;

  update public.deposit_refunds
  set voided_at = now(), void_reason = left(btrim(p_reason), 300), voided_by = (select auth.uid())
  where id = p_refund_id and voided_at is null
  returning * into v_refund;
  if not found then
    perform app.fail('already_voided');
  end if;
  return v_refund;
end
$$;

-- Deposit position for the app (agreed / received / applied / refunded / held).
create or replace function public.get_deposit_position(p_lease_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
  v_result jsonb;
begin
  select l.portfolio_id into v_portfolio_id from public.leases l where l.id = p_lease_id;
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_portfolio_id);
  select to_jsonb(d) into v_result from private.deposit_position(p_lease_id) d;
  return v_result;
end
$$;

-- Generates any missing rent dues for a portfolio's active leases. The app
-- calls this when the dashboard opens, so dues stay correct even if a
-- scheduled run was missed (e.g. a paused free-tier project).
create or replace function public.sync_portfolio_billing(p_portfolio_id uuid)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease_id uuid;
  v_created integer := 0;
begin
  perform app.require_portfolio_role(
    p_portfolio_id, array['owner', 'manager', 'accountant']::public.member_role[]
  );
  perform private.enforce_rate_limit('sync_portfolio_billing', 30, interval '1 minute');

  for v_lease_id in
    select l.id from public.leases l
    where l.portfolio_id = p_portfolio_id and l.status = 'active'
    order by l.id
  loop
    v_created := v_created + private.sync_lease_billing(v_lease_id, app.today_pkt());
  end loop;
  return v_created;
end
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security & grants
-- ---------------------------------------------------------------------------

-- Charges: members read; owners/managers/accountants add manual charges and
-- edit descriptions/due dates/amounts of manual charges; voiding and waiving
-- go through RPCs. No deletes.
alter table public.charges enable row level security;
create policy charges_select on public.charges
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
create policy charges_insert on public.charges
  for insert to authenticated
  with check (portfolio_id = any ((select app.my_portfolio_ids(
    array['owner', 'manager', 'accountant']::public.member_role[]))::uuid[]));
create policy charges_update on public.charges
  for update to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids(
    array['owner', 'manager', 'accountant']::public.member_role[]))::uuid[]))
  with check (portfolio_id = any ((select app.my_portfolio_ids(
    array['owner', 'manager', 'accountant']::public.member_role[]))::uuid[]));

grant select on public.charges to authenticated;
grant insert (id, portfolio_id, lease_id, kind, period_month, due_date, amount, description)
  on public.charges to authenticated;
grant update (due_date, amount, description) on public.charges to authenticated;
grant select, insert, update, delete on public.charges to service_role;

-- Payments, allocations and refunds are read-only for clients.
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.deposit_refunds enable row level security;

create policy payments_select on public.payments
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
create policy payment_allocations_select on public.payment_allocations
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));
create policy deposit_refunds_select on public.deposit_refunds
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids())::uuid[]));

grant select on public.payments, public.payment_allocations, public.deposit_refunds to authenticated;
grant select, insert, update, delete on public.payments, public.payment_allocations, public.deposit_refunds
  to service_role;

grant execute on function public.record_payment(
  uuid, numeric, date, public.payment_method, uuid, text, text, numeric, text, uuid[]
) to authenticated;
grant execute on function public.void_payment(uuid, text) to authenticated;
grant execute on function public.waive_charge(uuid, text, numeric) to authenticated;
grant execute on function public.void_charge(uuid, text) to authenticated;
grant execute on function public.change_rent(uuid, date, numeric, text, text) to authenticated;
grant execute on function public.end_lease(uuid, date, public.lease_end_reason) to authenticated;
grant execute on function public.apply_deposit(uuid, numeric, date, uuid, text) to authenticated;
grant execute on function public.refund_deposit(uuid, numeric, date, public.payment_method, text, text)
  to authenticated;
grant execute on function public.void_deposit_refund(uuid, text) to authenticated;
grant execute on function public.get_deposit_position(uuid) to authenticated;
grant execute on function public.sync_portfolio_billing(uuid) to authenticated;
