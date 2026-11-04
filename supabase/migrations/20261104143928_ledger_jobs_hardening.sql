-- ============================================================================
-- Ledger, daily-job and limiter hardening (findings of the formal models in
-- formal/ and of the Phase 3 review).
--
--   * Receipt numbers never truncate past 99,999 receipts in a year.
--   * Payment idempotency: requests sharing a key are serialised by an
--     advisory lock (a duplicate on another lease no longer fails on the
--     unique constraint), and a retry must repeat the original request
--     exactly (request fingerprint), otherwise it is refused.
--   * Voiding a payment, charge or deposit refund twice is a no-op that
--     reports the current state, so a retried void succeeds.
--   * Raising a lease's security deposit applies any unallocated credit.
--   * The daily job maintains one lease at a time in id order, never waits
--     for a lease a user is writing to (SKIP LOCKED), isolates failures per
--     lease and works in bounded batches, so it cannot deadlock with the
--     dashboard's billing sync, cannot be rolled back by one bad lease and
--     never holds every lease locked at once.
--   * Late fees are capped after rounding (never above the agreed cap) and
--     clamped to what a charge can hold; late_fee_value is bounded.
--   * A prorated first month never exceeds the monthly rent.
--   * The Data API write limiter counts per user only (no per-IP bucket:
--     carrier-grade NAT puts many users behind one address), and every 429
--     carries the exact wait in its hint as well as in Retry-After.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Receipt numbers
-- ---------------------------------------------------------------------------

-- Next receipt number, e.g. MM-2026-00042. Runs inside the payment's
-- transaction, so a rolled-back payment never consumes a number. At least
-- five digits, never truncated (lpad cuts longer strings, which would turn
-- receipt 100000 into a duplicate of 10000).
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
  v_digits text;
  v_prefix text;
begin
  insert into private.receipt_counters as c (portfolio_id, year, last_value)
  values (p_portfolio_id, v_year, 1)
  on conflict (portfolio_id, year) do update set last_value = c.last_value + 1
  returning c.last_value into v_value;

  v_digits := v_value::text;
  select p.receipt_prefix into v_prefix from public.portfolios p where p.id = p_portfolio_id;
  return v_prefix || '-' || v_year::text || '-' || lpad(v_digits, greatest(5, char_length(v_digits)), '0');
end
$$;

-- ---------------------------------------------------------------------------
-- Rate limiting
-- ---------------------------------------------------------------------------

-- Seconds until the current fixed window of length p_window ends (>= 1):
-- the honest Retry-After for a request refused in that window.
create or replace function private.rate_limit_retry_after(p_window interval)
returns integer
language sql
stable
set search_path = ''
as $$
  select greatest(
    1,
    ceil(extract(epoch from
      date_bin(p_window, now(), timestamptz '2000-01-01 00:00:00+00') + p_window - now()
    ))::integer
  )
$$;

-- Aborts the request with HTTP 429 (PostgREST maps SQLSTATE 'PGRST' with a
-- JSON message/detail onto the response). The wait is sent twice: as the
-- Retry-After header for HTTP clients, and as the error hint, because
-- supabase-js exposes the error body but not the response headers.
create or replace function private.raise_rate_limited(p_retry_after_seconds integer, p_details text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_retry_after text := greatest(1, coalesce(p_retry_after_seconds, 60))::text;
begin
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code', 'rate_limited',
      'message', 'Too many requests. Please wait a moment and try again.',
      'details', p_details,
      'hint', v_retry_after
    )::text,
    detail = json_build_object(
      'status', 429,
      'headers', json_build_object('Retry-After', v_retry_after)
    )::text;
end
$$;

-- Raises HTTP 429 when the signed-in caller exceeds p_limit calls of
-- p_action per p_window.
create or replace function private.enforce_rate_limit(
  p_action text,
  p_limit integer,
  p_window interval
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not private.hit_rate_limit(
    p_action || ':' || coalesce((select auth.uid())::text, 'anonymous'),
    p_limit,
    p_window
  ) then
    perform private.raise_rate_limited(private.rate_limit_retry_after(p_window), p_action);
  end if;
end
$$;

-- Data API write limiter (PostgREST pre-request hook): mutating requests
-- (POST/PATCH/PUT/DELETE, which includes RPC calls) are limited to 120/min
-- per signed-in user. GET/HEAD requests and read-only transactions cannot
-- write counters and are skipped; the service role is exempt. There is no
-- per-IP bucket: every write needs a signed-in user anyway, and one bucket
-- per address would throttle everyone behind a carrier-grade NAT (common on
-- Pakistani mobile networks) and serialise all their writes on one row.
create or replace function app.check_request()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_method text := current_setting('request.method', true);
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_sub text;
begin
  if v_method is null
     or v_method in ('GET', 'HEAD', 'OPTIONS')
     or coalesce(v_claims ->> 'role', '') = 'service_role'
     or current_setting('transaction_read_only', true) = 'on' then
    return;
  end if;

  v_sub := v_claims ->> 'sub';
  if v_sub is not null
     and not private.hit_rate_limit('api_write:user:' || v_sub, 120, interval '1 minute') then
    perform private.raise_rate_limited(private.rate_limit_retry_after(interval '1 minute'), 'api_write');
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Rent maths (mirrored by mm_core and pinned by contracts/rent_math_vectors.json)
-- ---------------------------------------------------------------------------

-- Rent for the month p_month when billing starts on p_billing_starts_on:
-- the full rent, or (first month only, when it starts after the 1st) the rent
-- × days billed ÷ days in month, rounded half-up to whole rupees but never
-- above the rent itself (0.90 × 30/31 would otherwise round up to 1).
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
    then least(
      p_rent,
      round(
        p_rent
          * (extract(day from (date_trunc('month', p_month) + interval '1 month - 1 day'))::integer
             - extract(day from p_billing_starts_on)::integer + 1)
          / extract(day from (date_trunc('month', p_month) + interval '1 month - 1 day'))::integer,
        0
      )
    )
    else p_rent
  end
$$;

-- Late fee owed on p_outstanding that is p_days_late days past due under a
-- lease's policy; zero inside the grace period. Rounded half-up to whole
-- rupees first and capped afterwards, so a daily fee never exceeds its cap
-- (a cap of 99.50 used to round up to 100), and never above what a charge
-- can hold (a long-unpaid daily fee used to overflow numeric(14,2)).
-- Mirrors mm_core LateFeePolicy.
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
    else least(
      round(case p_type
        when 'flat' then p_value
        when 'percent' then p_outstanding * p_value / 100
        when 'daily' then p_value * p_days_late
      end, 0),
      coalesce(case when p_type = 'daily' then p_cap end, 999999999999),
      999999999999
    )
  end
$$;

-- A flat fee or daily rate above one crore rupees is a typo, not a policy.
alter table public.leases
  add constraint leases_late_fee_value_max_check check (late_fee_value <= 10000000);

-- ---------------------------------------------------------------------------
-- Payment idempotency
-- ---------------------------------------------------------------------------

-- Fingerprint of the request that created each payment. A retry with the
-- same idempotency key must repeat the request exactly; anything else is a
-- client bug that must not silently return the first payment.
create table private.payment_requests (
  payment_id uuid primary key references public.payments (id) on delete cascade,
  request_hash bytea not null
    constraint payment_requests_request_hash_check check (octet_length(request_hash) = 32)
);

comment on table private.payment_requests is
  'SHA-256 of the canonical request that created a payment (idempotent replays must match).';

revoke all on private.payment_requests from public, anon, authenticated;

-- SHA-256 of an operation name and its canonical arguments. jsonb renders
-- keys in a fixed order; callers pass numbers through trim_scale so 100 and
-- 100.00 fingerprint alike.
create or replace function private.payment_request_hash(p_operation text, p_request jsonb)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select sha256(convert_to(p_operation || ':' || p_request::text, 'UTF8'))
$$;

-- Returns the id of the payment already created with p_key in the portfolio,
-- or null when the key is new. Requests sharing a key are serialised first
-- (callers already hold the lease lock; lease → key is the only order used),
-- so a concurrent duplicate on another lease waits and then sees the first
-- payment instead of failing on payments_idempotency_key.
create or replace function private.replayed_payment(
  p_portfolio_id uuid,
  p_key uuid,
  p_lease_id uuid,
  p_amount numeric,
  p_request_hash bytea
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_existing record;
begin
  if p_key is null then
    perform app.fail('idempotency_key_required');
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('payment-key:' || p_portfolio_id::text || ':' || p_key::text, 0)
  );

  select p.id, p.lease_id, p.amount, r.request_hash into v_existing
  from public.payments p
  left join private.payment_requests r on r.payment_id = p.id
  where p.portfolio_id = p_portfolio_id and p.idempotency_key = p_key;
  if not found then
    return null;
  end if;

  -- Payments without a fingerprint (written by other means) fall back to the
  -- lease and amount.
  if (v_existing.request_hash is not null and v_existing.request_hash <> p_request_hash)
     or (v_existing.request_hash is null
         and (v_existing.lease_id <> p_lease_id or v_existing.amount is distinct from p_amount)) then
    perform app.fail('idempotency_key_reused');
  end if;
  return v_existing.id;
end
$$;

-- Records money received for a lease and allocates it (chosen charges first,
-- then oldest due first). Idempotent per p_idempotency_key: retrying the
-- same request returns the original result; reusing the key for a different
-- request fails. tax_withheld (s.155) settles dues alongside the cash.
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
  v_existing uuid;
  v_tax numeric := coalesce(p_tax_withheld, 0);
  v_hash bytea;
begin
  v_lease := private.lock_lease_for_write(
    p_lease_id, array['owner', 'manager', 'accountant']::public.member_role[]
  );

  v_hash := private.payment_request_hash('record_payment', jsonb_build_object(
    'lease_id', p_lease_id,
    'amount', trim_scale(p_amount),
    'paid_on', p_paid_on,
    'method', p_method,
    'reference', nullif(btrim(p_reference), ''),
    'notes', nullif(btrim(p_notes), ''),
    'tax_withheld', trim_scale(v_tax),
    'tax_certificate_no', nullif(btrim(p_tax_certificate_no), ''),
    'charge_ids', p_charge_ids
  ));
  v_existing := private.replayed_payment(v_lease.portfolio_id, p_idempotency_key, p_lease_id, p_amount, v_hash);
  if v_existing is not null then
    return private.payment_result(v_existing);
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
  insert into private.payment_requests (payment_id, request_hash) values (v_payment.id, v_hash);

  perform private.allocate_payment(v_payment.id, p_charge_ids);
  return private.payment_result(v_payment.id);
end
$$;

-- Uses (part of) the deposit held to settle outstanding dues, typically at
-- move-out. Recorded as a 'deposit_adjustment' payment with its own receipt.
-- Idempotent per p_idempotency_key, like record_payment.
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
  v_existing uuid;
  v_held numeric;
  v_open numeric;
  v_hash bytea;
begin
  v_lease := private.lock_lease_for_write(p_lease_id, array['owner', 'manager']::public.member_role[]);

  v_hash := private.payment_request_hash('apply_deposit', jsonb_build_object(
    'lease_id', p_lease_id,
    'amount', trim_scale(p_amount),
    'applied_on', p_applied_on,
    'notes', nullif(btrim(p_notes), '')
  ));
  v_existing := private.replayed_payment(v_lease.portfolio_id, p_idempotency_key, p_lease_id, p_amount, v_hash);
  if v_existing is not null then
    return private.payment_result(v_existing);
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
  insert into private.payment_requests (payment_id, request_hash) values (v_payment.id, v_hash);

  perform private.allocate_payment(v_payment.id);
  return private.payment_result(v_payment.id);
end
$$;

-- ---------------------------------------------------------------------------
-- Retry-safe voids
-- ---------------------------------------------------------------------------

-- Voids a payment, reversing its allocations, then re-applies other credit.
-- Voiding an already voided payment (a retried request) reports it as is.
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
    return private.payment_result(p_payment_id);
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

-- Voids an unpaid charge (and its unpaid automatic late fee). Voiding an
-- already voided charge reports it as is.
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
    return v_charge;
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

-- Voids a deposit refund. Voiding an already voided refund reports it as is.
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
    select r.* into v_refund from public.deposit_refunds r where r.id = p_refund_id;
  end if;
  return v_refund;
end
$$;

-- ---------------------------------------------------------------------------
-- Deposit changes pick up credit
-- ---------------------------------------------------------------------------

-- Keeps the deposit due in step with leases.security_deposit, then applies
-- any unallocated credit to it (as a new manual charge would). The UPDATE
-- that fired this trigger holds the lease row lock.
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

  perform private.apply_lease_credit(new.id);
  return null;
end
$$;

-- ---------------------------------------------------------------------------
-- Daily job: per-lease, batched, never blocking on user writes
-- ---------------------------------------------------------------------------

-- The old job refreshed every lease's rent in one statement (locking leases
-- in arbitrary order) and then synced billing lease by lease, all in one
-- transaction: it deadlocked against the dashboard's id-ordered billing sync
-- and one overflowing late fee rolled the whole day back.
drop function private.run_daily_jobs(date);
drop function private.assess_late_fees(date);
drop function private.sync_all_billing(date);
drop function private.refresh_current_rents(date);

-- Which day each lease was last maintained for, and its last failure.
create table private.lease_maintenance (
  lease_id uuid primary key references public.leases (id) on delete cascade,
  maintained_on date not null,
  failures integer not null default 0 constraint lease_maintenance_failures_check check (failures >= 0),
  last_error text,
  updated_at timestamptz not null default now()
);

comment on table private.lease_maintenance is
  'Day each active lease was last maintained by the daily job (rent, dues, late fees) and its last error.';

-- Portfolio-wide daily work already done (e.g. notifications for a day).
create table private.job_runs (
  job_name text not null,
  run_on date not null,
  finished_at timestamptz not null default now(),
  result jsonb,
  primary key (job_name, run_on)
);

comment on table private.job_runs is 'Once-a-day jobs that have completed, by Pakistan calendar day.';

revoke all on private.lease_maintenance, private.job_runs from public, anon, authenticated;

-- One automatic late fee per overdue rent due of the lease once the grace
-- period has passed. Daily fees grow each day (up to their cap) until the
-- rent or the fee is paid, waived or voided; voided fees are never
-- recreated. The caller must hold the lease row lock.
create or replace function private.assess_late_fees(p_lease_id uuid, p_as_of date)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_rows integer;
begin
  select l.* into v_lease from public.leases l where l.id = p_lease_id;
  if not found or v_lease.status <> 'active' or v_lease.late_fee_type = 'none' then
    return 0;
  end if;

  insert into public.charges (
    portfolio_id, lease_id, kind, period_month, due_date, amount, source, related_charge_id, description
  )
  select
    c.portfolio_id, c.lease_id, 'late_fee', c.period_month, p_as_of, f.fee, 'auto_late_fee', c.id,
    'Late fee'
  from public.charges c
  cross join lateral (
    select app.late_fee_amount(
      v_lease.late_fee_type, v_lease.late_fee_value, v_lease.late_fee_cap, c.outstanding,
      p_as_of - c.due_date, v_lease.grace_days
    ) as fee
  ) f
  where c.lease_id = p_lease_id
    and c.kind = 'rent'
    and c.voided_at is null
    and c.outstanding > 0
    and p_as_of - c.due_date > v_lease.grace_days
    and f.fee > 0
  order by c.due_date, c.id
  on conflict (related_charge_id) where kind = 'late_fee' and related_charge_id is not null
  do update set amount = excluded.amount
    where public.charges.voided_at is null
      and public.charges.paid_amount = 0
      and public.charges.waived_amount = 0
      and excluded.amount > public.charges.amount;
  get diagnostics v_rows = row_count;
  return v_rows;
end
$$;

-- Generates the monthly rent charges of an active lease from its billing
-- start through the month of p_as_of (idempotent), prorating the first
-- billed month by day when configured, then applies any credit. Returns the
-- number of charges created. Automatic rent months are created in order and
-- never deleted (only voided), so the walk resumes after the newest one
-- instead of revisiting every month since billing started (two statements
-- per month, per lease, every day). A manual 'rent' charge does not count as
-- progress: its month is skipped when reached, as before.
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
  v_latest date;
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
  select max(c.period_month) into v_latest
  from public.charges c
  where c.lease_id = v_lease.id and c.kind = 'rent' and c.source = 'auto_rent';
  if v_latest >= v_month then
    v_month := (v_latest + interval '1 month')::date;
  end if;
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

-- Daily upkeep of one lease under its row lock: brings monthly_rent to the
-- rent in force (as change_rent does), generates due rent and assesses late
-- fees. Returns the charges created and the late fees assessed.
create or replace function private.maintain_lease(p_lease_id uuid, p_as_of date)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lease public.leases;
  v_created integer;
  v_fees integer;
begin
  select l.* into v_lease from public.leases l where l.id = p_lease_id for update;
  if not found or v_lease.status <> 'active' then
    return jsonb_build_object('charges_created', 0, 'late_fees', 0);
  end if;

  update public.leases l
  set monthly_rent = rc.monthly_rent
  from (
    select r.monthly_rent
    from public.rent_changes r
    where r.lease_id = p_lease_id
      and r.effective_from <= greatest(
        date_trunc('month', p_as_of)::date,
        date_trunc('month', v_lease.billing_starts_on)::date
      )
    order by r.effective_from desc
    limit 1
  ) rc
  where l.id = p_lease_id and l.monthly_rent is distinct from rc.monthly_rent;

  v_created := private.sync_lease_billing(p_lease_id, p_as_of);
  v_fees := private.assess_late_fees(p_lease_id, p_as_of);
  return jsonb_build_object('charges_created', v_created, 'late_fees', v_fees);
end
$$;

create or replace function private.cleanup(p_now timestamptz default now())
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  delete from private.rate_limit_buckets where window_start < p_now - interval '2 hours';
  delete from public.notifications where created_at < p_now - interval '180 days';
  delete from public.portfolio_invitations
  where accepted_at is null and expires_at < p_now - interval '90 days';
  delete from private.job_runs where run_on < (p_now - interval '400 days')::date;
  delete from private.lease_maintenance m
  using public.leases l
  where l.id = m.lease_id and l.status <> 'active';
  -- pg_cron keeps a row per run; keep two weeks of history where it runs.
  if to_regclass('cron.job_run_details') is not null then
    execute 'delete from cron.job_run_details where end_time < $1' using p_now - interval '14 days';
  end if;
end
$$;

-- Maintains up to p_batch_size active leases not yet maintained for p_as_of
-- (Pakistan date), one at a time in id order, each in its own subtransaction:
--   * a lease locked by a user's write is skipped (SKIP LOCKED) and picked up
--     by the next run, so the job never waits on a lease while holding
--     others — no deadlock with id-ordered user syncs is possible;
--   * a failing lease is rolled back alone, recorded with its error and
--     retried the next day; the rest of the batch carries on;
--   * once no lease is pending for the day, a run that maintained no lease
--     (so holds no lease locks) runs notifications and cleanup, once a day.
-- pg_cron runs it every 10 minutes, so a day's work spreads over short
-- transactions and a missed or failed run catches up by itself.
create or replace function private.run_daily_jobs(p_as_of date default null, p_batch_size integer default 500)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_lease_id uuid;
  v_step jsonb;
  v_processed integer := 0;
  v_busy integer := 0;
  v_failed integer := 0;
  v_charges integer := 0;
  v_fees integer := 0;
  v_pending integer;
  v_notifications integer;
  v_state text;
  v_message text;
begin
  if p_batch_size is null or p_batch_size not between 1 and 10000 then
    perform app.fail('invalid_batch_size');
  end if;
  -- One coordinator at a time; an overlapping run simply skips.
  if not pg_try_advisory_xact_lock(hashtext('maalik_e_makaan.run_daily_jobs')) then
    return jsonb_build_object('skipped', true);
  end if;

  for v_lease_id in
    select l.id
    from public.leases l
    left join private.lease_maintenance m on m.lease_id = l.id
    where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of)
    order by l.id
    limit p_batch_size
  loop
    begin
      perform 1 from public.leases l where l.id = v_lease_id for update skip locked;
      if not found then
        v_busy := v_busy + 1;
        continue;
      end if;

      v_step := private.maintain_lease(v_lease_id, v_as_of);
      insert into private.lease_maintenance as m (lease_id, maintained_on)
      values (v_lease_id, v_as_of)
      on conflict (lease_id) do update
        set maintained_on = excluded.maintained_on, failures = 0, last_error = null, updated_at = now();

      v_charges := v_charges + (v_step ->> 'charges_created')::integer;
      v_fees := v_fees + (v_step ->> 'late_fees')::integer;
      v_processed := v_processed + 1;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_message = message_text;
      v_failed := v_failed + 1;
      raise warning 'run_daily_jobs: lease % failed (%): %', v_lease_id, v_state, v_message;
      begin
        insert into private.lease_maintenance as m (lease_id, maintained_on, failures, last_error)
        values (v_lease_id, v_as_of, 1, v_state || ': ' || left(v_message, 500))
        on conflict (lease_id) do update
          set maintained_on = excluded.maintained_on,
              failures = m.failures + 1,
              last_error = excluded.last_error,
              updated_at = now();
      exception when foreign_key_violation then
        null; -- the lease was deleted in the meantime
      end;
    end;
  end loop;

  select count(*)::integer into v_pending
  from public.leases l
  left join private.lease_maintenance m on m.lease_id = l.id
  where l.status = 'active' and (m.maintained_on is null or m.maintained_on < v_as_of);

  -- The portfolio-wide work runs once a day after every lease is done, and
  -- only in a run that maintained no lease itself, so it never holds lease
  -- locks while it fans out notifications (the next run, 10 minutes later).
  if v_pending = 0 and v_processed = 0 then
    insert into private.job_runs (job_name, run_on) values ('daily_notifications', v_as_of)
    on conflict (job_name, run_on) do nothing;
    if found then
      v_notifications := private.generate_notifications(v_as_of);
      perform private.cleanup(now());
      update private.job_runs
      set finished_at = now(), result = jsonb_build_object('notifications', v_notifications)
      where job_name = 'daily_notifications' and run_on = v_as_of;
    end if;
  end if;

  return jsonb_build_object(
    'as_of', v_as_of,
    'leases_processed', v_processed,
    'leases_busy', v_busy,
    'leases_failed', v_failed,
    'leases_pending', v_pending,
    'charges_created', v_charges,
    'late_fees', v_fees,
    'notifications', v_notifications
  );
end
$$;

revoke all on function
  private.rate_limit_retry_after(interval),
  private.payment_request_hash(text, jsonb),
  private.replayed_payment(uuid, uuid, uuid, numeric, bytea),
  private.assess_late_fees(uuid, date),
  private.maintain_lease(uuid, date),
  private.run_daily_jobs(date, integer)
from public, anon, authenticated;

-- Every 10 minutes instead of once a day (each run is a no-op once the day
-- is done). Only where pg_cron runs; plain test databases skip it.
do $$
begin
  if exists (select 1 from pg_catalog.pg_extension where extname = 'pg_cron') then
    perform cron.schedule('mm-daily-jobs', '*/10 * * * *', 'select private.run_daily_jobs()');
  end if;
end
$$;
