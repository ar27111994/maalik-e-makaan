-- ============================================================================
-- Ledger findings of the formal models:
--   formal/tla/LedgerPayments  F1, F2, F3
--   formal/tla/LateFees        F1, F2 (= LedgerPayments F1), F3
--   formal/tla/RateLimit       F5 (F4 is accepted: see the end of this header)
--   formal/smt/overflow.py     A1
--
-- The global lock order (20261105072426_membership_deletion_storage.sql):
--
--   1. the account      2. the portfolio      3. the lease      4. other rows
--
-- Every ledger function and the daily job take the portfolio key and then the
-- lease before they touch a charge or a payment (the job with SKIP LOCKED),
-- so writers of one lease's money wait for each other instead of
-- deadlocking.
--
-- Findings:
--   F1  (low; LateFees F2) A client's UPDATE of charges broke that order.
--       The column grant (`grant update (due_date, amount, description) on
--       charges to authenticated`, 20261103193658_ledger.sql) and the
--       charges_update policy (20261105170557_concurrency_findings.sql:
--       portfolio keys, but no lease) let a statement lock charge rows in its
--       scan order, while allocate_payment and void_payment lock the lease
--       and then the charges in due order, and the daily job locks the lease
--       and then raises its fees. Two rows in opposite orders: PostgreSQL
--       killed a payment, a void, the job's lease or the client with 40P01.
--   F2  (low) Raising a manual charge's amount opened a due next to the
--       lease's unallocated credit, which stayed unapplied until the next
--       rent was created (every other path that opens a due applies it).
--   F3  (low-medium; with LateFees F3) end_lease voided rent for months after
--       the move-out only where paid_amount = 0, and never their automatic
--       late fees. Rent paid in advance, or paid from credit by the billing
--       sync on the first of the month, stayed live on the ended lease (the
--       money stayed spent on it), and so did the fees of the rent it voided.
--   LF1 (low-medium; LateFees F1) A rent paid in full by a payment dated
--       within its grace period, but recorded after the daily job had posted
--       the automatic late fee, kept the fee.
--   A1  (low) record_payment checks p_amount and p_tax_withheld each up to
--       999,999,999,999.99, but payments.applied_amount and
--       unallocated_amount are generated as amount + tax_withheld in
--       numeric(14,2): a large pair failed with an unmapped 22003 (numeric
--       field overflow) instead of invalid_amount.
--   RF5 (low; RateLimit F5) Edge Functions computed Retry-After from their
--       own clock after admin_hit_rate_limit returned; across a window
--       boundary (or with clock skew) it named the wrong window.
--
-- Fixes:
--   F1, F2  Clients lose UPDATE on charges (the column grant and the
--           charges_update policy go). public.update_charge edits a charge's
--           amount, due date or note under the lease lock (portfolio key,
--           lease, then the charge: the order of the payment functions and
--           the job), with the rules before_charge_update enforced for
--           clients (a voided charge is frozen; only a manual charge's amount
--           changes), refuses an amount below what was paid or waived with
--           invalid_amount (the row check charges_not_overpaid_check used to
--           answer with a raw 23514), and applies the lease's credit after an
--           amount change. before_charge_update stays as a second line: no
--           client role can reach it any more.
--   F3      end_lease releases the allocations of rent for months after the
--           move-out and of those rents' automatic late fees
--           (charges.paid_amount, payment_allocations,
--           payments.allocated_amount, as void_payment reverses a payment),
--           voids them, and applies the lease's credit: the money pays the
--           lease's other open dues, and what is left stays as credit on the
--           lease (for a refund or a void of the payment).
--   LF1     record_payment, after allocating, voids the automatic late fee of
--           every rent the payment settled in full when the payment is dated
--           within the rent's grace period, unless other money already paid
--           part of the fee (as void_charge keeps a fee that has payments).
--           What this payment had put on such a fee is released first, and
--           the payment is allocated again.
--   A1      record_payment refuses p_amount + tax_withheld above
--           999,999,999,999.99 with invalid_amount. No table CHECK: the
--           generated columns are computed before CHECK constraints run, so
--           the overflow (22003) would still come first and a CHECK could
--           never fire.
--   RF5     public.admin_rate_limit_hit counts the hit and returns the
--           verdict with the database's Retry-After for the same now()
--           (private.rate_limit_retry_after); the Edge Functions send that.
--           admin_hit_rate_limit stays for Edge Functions deployed before
--           this migration; drop it once none calls it.
--
-- No per-function rate limit on update_charge: like void_charge and
-- waive_charge it creates no receipt, and the Data API write limiter
-- (app.check_request, 120 writes a minute per user) counts every RPC call,
-- exactly as it counted the PATCH it replaces.
--
-- RateLimit F4 is accepted, not fixed: a hit counted inside a request's
-- transaction rolls back with a request that fails after the limiter, so
-- failing requests never use up a quota. Committing the hit on its own needs
-- an autonomous transaction: dblink back into the same database would open a
-- second connection, with stored credentials, on every write (the pooler's
-- connection budget), and PostgREST's pre-request hook shares the request's
-- transaction. The residual risk (a member can repeat failing writes without
-- being limited by these counters; each one still fails validation early,
-- and the platform's gateway limits still apply) is recorded in
-- docs/architecture/permissions.md.
-- ============================================================================

-- A migration waits at most 5 s for a table lock (DROP POLICY takes ACCESS
-- EXCLUSIVE on charges for a moment) instead of queueing the app's traffic
-- behind it; `set local` keeps both settings inside this migration's
-- transaction.
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- F1 and F2: charge edits through an RPC
-- ---------------------------------------------------------------------------

revoke update (due_date, amount, description) on public.charges from authenticated;
-- No client may UPDATE charges any more, so the policy has nothing to allow.
-- (SECURITY DEFINER functions run as the table owner, which bypasses row
-- security, and the service role keeps its table grant.)
drop policy charges_update on public.charges;

-- Edits a charge's amount, due date or note. A null argument keeps the
-- current value; an empty or blank p_description clears the note. Rules (the
-- ones client edits had): a voided charge cannot change (charge_voided); only
-- a manual charge's amount can change (charge_not_editable); the amount is a
-- valid amount (invalid_amount) and at least what was already paid or waived
-- (invalid_amount). Owners, managers and accountants of the lease's
-- portfolio, as with manual charges.
--
-- Locks, in the global order: the portfolio key and the lease
-- (private.lock_lease_for_write), then the charge. allocate_payment,
-- void_payment and the daily job's fee upsert hold the same lease while they
-- lock charges (the job skips a lease an edit holds), so an edit waits for
-- them or they wait for it, never both (F1, LateFees F2). After an amount
-- change the lease's unallocated credit is applied, as for a new manual
-- charge (F2).
create or replace function public.update_charge(
  p_charge_id uuid,
  p_amount numeric default null,
  p_due_date date default null,
  p_description text default null
)
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
  -- Same error for "missing" and "not yours": never confirm existence.
  if not found then
    perform app.forbid();
  end if;
  perform private.lock_lease_for_write(
    v_lease_id, array['owner', 'manager', 'accountant']::public.member_role[]
  );

  select c.* into v_charge from public.charges c where c.id = p_charge_id for update;
  if not found or v_charge.lease_id is distinct from v_lease_id then
    perform app.forbid();
  end if;
  if v_charge.voided_at is not null then
    perform app.fail('charge_voided');
  end if;

  v_amount := coalesce(p_amount, v_charge.amount);
  if v_amount <> v_charge.amount then
    if v_charge.source <> 'manual' then
      perform app.fail('charge_not_editable');
    end if;
    perform private.require_valid_amount(v_amount);
    if v_amount < v_charge.paid_amount + v_charge.waived_amount then
      perform app.fail('invalid_amount', 'amount_below_paid_or_waived');
    end if;
  end if;

  update public.charges
  set amount = v_amount,
      due_date = coalesce(p_due_date, due_date),
      description = case when p_description is null then description else nullif(btrim(p_description), '') end
  where id = p_charge_id;

  if v_amount <> v_charge.amount then
    perform private.apply_lease_credit(v_lease_id);
  end if;

  select c.* into v_charge from public.charges c where c.id = p_charge_id;
  return v_charge;
end
$$;

comment on function public.update_charge(uuid, numeric, date, text) is
  'Edits a charge''s amount (manual charges only), due date or note under the lease lock, then applies credit.';

revoke all on function public.update_charge(uuid, numeric, date, text) from public, anon;
grant execute on function public.update_charge(uuid, numeric, date, text) to authenticated;

-- ---------------------------------------------------------------------------
-- F3 (and LateFees F3): end_lease releases and voids every later month's
-- rent and its automatic late fees
-- ---------------------------------------------------------------------------

-- Ends a tenancy at the actual move-out date: bills through the move-out
-- month, then voids, paid or not, the rent of every later month and the
-- automatic late fees of that rent. Money allocated to them is released first
-- (the allocations are deleted and charges.paid_amount and
-- payments.allocated_amount reduced, as void_payment reverses a payment), and
-- the lease's credit is then applied: it pays the lease's other open dues,
-- and what is left stays on the lease as credit, to refund or to void.
-- Finally the lease is ended and the unit freed.
--
-- Locks: the portfolio key and the lease (lock_lease_for_write), then those
-- charges in due order, then the payments of their allocations (every other
-- writer of them, the daily job included, holds this lease first).
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
  v_month date;
  v_later uuid[];
  v_allocation record;
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
  v_month := date_trunc('month', p_moved_out_on)::date;

  -- The live rent of later months and the live automatic fees of rent of
  -- later months (voided or not), locked in due order.
  select coalesce(array_agg(l.id order by l.due_date, l.id), '{}'::uuid[]) into v_later
  from (
    select c.id, c.due_date
    from public.charges c
    where c.lease_id = p_lease_id
      and c.voided_at is null
      and (
        (c.kind = 'rent' and c.period_month > v_month)
        or (c.kind = 'late_fee' and c.source = 'auto_late_fee' and exists (
              select 1 from public.charges r
              where r.id = c.related_charge_id and r.kind = 'rent' and r.period_month > v_month))
      )
    order by c.due_date, c.id
    for update of c
  ) l;

  for v_allocation in
    select a.id, a.payment_id, a.charge_id, a.amount
    from public.payment_allocations a
    join public.charges c on c.id = a.charge_id
    where a.charge_id = any (v_later)
    order by c.due_date, c.id, a.payment_id
  loop
    update public.charges set paid_amount = paid_amount - v_allocation.amount where id = v_allocation.charge_id;
    update public.payments
    set allocated_amount = allocated_amount - v_allocation.amount
    where id = v_allocation.payment_id;
    delete from public.payment_allocations where id = v_allocation.id;
  end loop;

  update public.charges
  set voided_at = now(), void_reason = 'Lease ended', voided_by = (select auth.uid())
  where id = any (v_later);

  perform private.apply_lease_credit(p_lease_id);

  update public.leases
  set status = 'ended', moved_out_on = p_moved_out_on, end_reason = p_reason, ended_at = now()
  where id = p_lease_id
  returning * into v_lease;

  return v_lease;
end
$$;

comment on function public.end_lease(uuid, date, public.lease_end_reason) is
  'Ends a lease: bills through the move-out month, releases and voids later rent and its late fees, '
  'then re-applies the freed credit.';

-- ---------------------------------------------------------------------------
-- A1 and LateFees F1: record_payment
-- ---------------------------------------------------------------------------

-- Records money received for a lease and allocates it (chosen charges first,
-- then oldest due first). Idempotent per p_idempotency_key: retrying the
-- same request returns the original result; reusing the key for a different
-- request fails. tax_withheld (s.155) settles dues alongside the cash; the
-- two together must fit numeric(14,2) (payments.applied_amount, A1). A rent
-- the payment settles in full within its grace period loses its unpaid
-- automatic late fee (LateFees F1).
--
-- Locks: the portfolio key and the lease (lock_lease_for_write), the
-- idempotency key (advisory), the receipt counter, then the lease's open
-- charges in allocate_payment's order, then the fees it voids (already
-- locked by that cursor when they were open).
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
  v_fee record;
  v_fees_voided boolean := false;
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
  -- payments.applied_amount and unallocated_amount are amount + tax_withheld
  -- in numeric(14,2) (A1).
  if p_amount + v_tax > 999999999999.99 then
    perform app.fail('invalid_amount');
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

  -- LateFees F1: a rent this payment settled in full, dated within the
  -- rent's grace period, owes no late fee. Its automatic fee is voided unless
  -- other money already paid part of it; what this payment put on the fee is
  -- released first, and the payment is allocated again.
  for v_fee in
    select f.id, a.id as allocation_id, coalesce(a.amount, 0) as amount
    from public.charges r
    join public.payment_allocations ra on ra.charge_id = r.id and ra.payment_id = v_payment.id
    join public.charges f on f.related_charge_id = r.id
    left join public.payment_allocations a on a.charge_id = f.id and a.payment_id = v_payment.id
    where r.lease_id = p_lease_id
      and r.kind = 'rent'
      and r.voided_at is null
      and r.outstanding = 0
      and p_paid_on <= r.due_date + v_lease.grace_days
      and f.kind = 'late_fee'
      and f.source = 'auto_late_fee'
      and f.voided_at is null
      and f.paid_amount = coalesce(a.amount, 0)
    order by f.due_date, f.id
    for update of f
  loop
    if v_fee.allocation_id is not null then
      update public.charges set paid_amount = paid_amount - v_fee.amount where id = v_fee.id;
      update public.payments set allocated_amount = allocated_amount - v_fee.amount where id = v_payment.id;
      delete from public.payment_allocations where id = v_fee.allocation_id;
    end if;
    update public.charges
    set voided_at = now(), void_reason = 'Rent paid within the grace period', voided_by = (select auth.uid())
    where id = v_fee.id;
    v_fees_voided := true;
  end loop;
  if v_fees_voided then
    perform private.allocate_payment(v_payment.id, p_charge_ids);
  end if;

  return private.payment_result(v_payment.id);
end
$$;

comment on function public.record_payment(
  uuid, numeric, date, public.payment_method, uuid, text, text, numeric, text, uuid[]
) is
  'Records a payment (idempotent per key) and allocates it: chosen charges first, then oldest due first.';

-- ---------------------------------------------------------------------------
-- RateLimit F5: the database's Retry-After for Edge Functions
-- ---------------------------------------------------------------------------

-- Counts one hit for an Edge Function rate limit (keys prefixed `fn:`, as
-- admin_hit_rate_limit does) and returns {"allowed": boolean,
-- "retry_after_seconds": integer}: the seconds until the window the hit was
-- counted in ends, from the same now(), so the Edge Function's clock plays
-- no part.
create or replace function public.admin_rate_limit_hit(
  p_key text,
  p_limit integer,
  p_window_seconds integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_window interval;
  v_allowed boolean;
begin
  if p_key is null
     or char_length(p_key) not between 1 and 200
     or not app.is_clean_text(p_key)
     or p_limit is null or p_limit not between 1 and 100000
     or p_window_seconds is null or p_window_seconds not between 1 and 3600 then
    perform app.fail('invalid_rate_limit');
  end if;
  v_window := make_interval(secs => p_window_seconds);
  v_allowed := private.hit_rate_limit('fn:' || p_key, p_limit, v_window);
  return jsonb_build_object(
    'allowed', v_allowed,
    'retry_after_seconds', private.rate_limit_retry_after(v_window)
  );
end
$$;

comment on function public.admin_rate_limit_hit(text, integer, integer) is
  'Counts one hit for an Edge Function rate limit; returns the verdict and the database''s Retry-After. '
  'Secret key only.';

revoke all on function public.admin_rate_limit_hit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.admin_rate_limit_hit(text, integer, integer) to service_role;

comment on function public.admin_hit_rate_limit(text, integer, integer) is
  'Deprecated (use admin_rate_limit_hit): kept for Edge Functions deployed before 20261107181820.';
