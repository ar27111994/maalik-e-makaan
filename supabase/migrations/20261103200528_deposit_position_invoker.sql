-- ============================================================================
-- get_deposit_position runs with the caller's privileges.
--
-- The RPC only reads rows that every member of the lease's portfolio can
-- already select, so it does not need SECURITY DEFINER (Supabase database
-- lint 0029, option 2: row-level security stays in force). The calculation
-- moves to app.deposit_position, a SECURITY INVOKER function shared by the
-- RPC and the ledger; private.deposit_position remains the entry point of
-- the SECURITY DEFINER ledger RPCs and simply delegates to it.
-- ============================================================================

create or replace function app.deposit_position(p_lease_id uuid)
returns table (agreed numeric, received numeric, applied numeric, refunded numeric, held numeric)
language sql
stable
security invoker
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

comment on function app.deposit_position(uuid) is
  'Security deposit of a lease: agreed, received, applied to dues, refunded and still held. Runs as the caller.';
grant execute on function app.deposit_position(uuid) to authenticated, service_role;

-- Called only from SECURITY DEFINER ledger functions, which already run as
-- the owner; the wrapper itself needs no elevated rights.
create or replace function private.deposit_position(p_lease_id uuid)
returns table (agreed numeric, received numeric, applied numeric, refunded numeric, held numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select d.agreed, d.received, d.applied, d.refunded, d.held
  from app.deposit_position(p_lease_id) d
$$;

-- Deposit position for the app (agreed / received / applied / refunded / held).
create or replace function public.get_deposit_position(p_lease_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
  v_result jsonb;
begin
  -- Row-level security hides other portfolios' leases, so a missing lease
  -- and someone else's lease produce the same error.
  select l.portfolio_id into v_portfolio_id from public.leases l where l.id = p_lease_id;
  if not found then
    perform app.forbid();
  end if;
  perform app.require_portfolio_role(v_portfolio_id);
  select to_jsonb(d) into v_result from app.deposit_position(p_lease_id) d;
  return v_result;
end
$$;
