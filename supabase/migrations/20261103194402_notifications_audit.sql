-- ============================================================================
-- Notifications (in-app inbox) and the audit trail.
--
-- Notifications carry a kind plus JSON params; the app renders localised
-- text (English/Urdu) from them. Generation is idempotent through
-- (user_id, dedupe_key), so the daily job can safely re-run or catch up.
--
-- The audit trail records who changed what and when for every structural and
-- financial table. Updates store only changed columns; CNICs are redacted.
-- ============================================================================

create type public.notification_kind as enum (
  'rent_due_soon', 'rent_overdue', 'lease_expiring', 'increment_due',
  'police_registration_pending', 'police_registration_overdue', 'cnic_expiring',
  'utility_bill_due', 'invitation_accepted'
);

create table public.notifications (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind public.notification_kind not null,
  params jsonb not null default '{}'::jsonb
    constraint notifications_params_check
      check (jsonb_typeof(params) = 'object' and pg_column_size(params) <= 4096),
  entity_type text constraint notifications_entity_type_check check (entity_type ~ '^[a-z_]{1,40}$'),
  entity_id uuid,
  dedupe_key text not null constraint notifications_dedupe_key_check check (char_length(dedupe_key) <= 200),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_user_dedupe_key unique (user_id, dedupe_key)
);

comment on table public.notifications is 'Per-user inbox entries rendered client-side from kind + params.';

create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index notifications_user_unread_idx on public.notifications (user_id) where read_at is null;
create index notifications_portfolio_id_idx on public.notifications (portfolio_id);

alter table public.notifications enable row level security;
create policy notifications_select_own on public.notifications
  for select to authenticated
  using (
    user_id = (select auth.uid())
    and portfolio_id = any ((select app.my_portfolio_ids())::uuid[])
  );
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy notifications_delete_own on public.notifications
  for delete to authenticated
  using (user_id = (select auth.uid()));

grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
grant select, insert, update, delete on public.notifications to service_role;

-- Marks the caller's notifications read (all when p_ids is null).
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.notifications
  set read_at = now()
  where user_id = (select auth.uid())
    and read_at is null
    and (p_ids is null or id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end
$$;

grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

-- Creates every due notification for p_as_of. Recipients: owners & managers.
create or replace function private.generate_notifications(p_as_of date default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_as_of date := coalesce(p_as_of, app.today_pkt());
  v_rows integer;
  v_total integer := 0;
begin
  -- Rent due within 3 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select c.portfolio_id, m.user_id, 'rent_due_soon',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'property_name', p.name, 'amount', c.outstanding, 'due_date', c.due_date
         ),
         'charge', c.id, 'rent_due_soon:' || c.id
  from public.charges c
  join public.leases l on l.id = c.lease_id and l.status = 'active'
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  join public.portfolio_members m on m.portfolio_id = c.portfolio_id and m.role in ('owner', 'manager')
  where c.kind = 'rent' and c.voided_at is null and c.outstanding > 0
    and c.due_date between v_as_of and v_as_of + 3
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Rent overdue past the grace period (recent dues only, to avoid flooding
  -- a landlord who onboards months of history), and again at 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select c.portfolio_id, m.user_id, 'rent_overdue',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'property_name', p.name, 'amount', c.outstanding, 'due_date', c.due_date,
           'days_overdue', v_as_of - c.due_date
         ),
         'charge', c.id,
         case when v_as_of - c.due_date >= 30 then 'rent_overdue_30:' else 'rent_overdue:' end || c.id
  from public.charges c
  join public.leases l on l.id = c.lease_id and l.status = 'active'
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  join public.portfolio_members m on m.portfolio_id = c.portfolio_id and m.role in ('owner', 'manager')
  where c.kind = 'rent' and c.voided_at is null and c.outstanding > 0
    and v_as_of > c.due_date + l.grace_days
    and c.due_date >= v_as_of - 45
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Agreements ending within 90 and within 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id, 'lease_expiring',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'end_date', l.end_date, 'days_left', l.end_date - v_as_of
         ),
         'lease', l.id,
         'lease_expiring_' || horizon.days || ':' || l.id || ':' || l.end_date
  from public.leases l
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  cross join (values (90), (30)) as horizon (days)
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active' and l.end_date between v_as_of and v_as_of + horizon.days
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Increment due within 30 days and not yet applied for that anniversary.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id, 'increment_due',
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'anniversary', a.anniversary, 'current_rent', l.monthly_rent,
           'increment_percent', l.increment_percent
         ),
         'lease', l.id, 'increment_due:' || l.id || ':' || a.anniversary
  from public.leases l
  cross join lateral (
    select app.next_anniversary(l.start_date, v_as_of, l.increment_interval_months) as anniversary
  ) a
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active'
    and l.increment_percent > 0
    and a.anniversary <= v_as_of + 30
    and not exists (
      select 1 from public.rent_changes rc
      where rc.lease_id = l.id
        and rc.reason <> 'initial'
        and rc.effective_from >= date_trunc('month', a.anniversary)::date
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Police registration: a nudge once tenancy starts, and once overdue.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select l.portfolio_id, m.user_id,
         case when overdue then 'police_registration_overdue'::public.notification_kind
              else 'police_registration_pending'::public.notification_kind end,
         jsonb_build_object(
           'lease_id', l.id, 'tenant_name', t.full_name, 'unit_label', u.label,
           'province', p.province, 'deadline', d.deadline
         ),
         'lease', l.id,
         case when overdue then 'police_overdue:' else 'police_pending:' end || l.id
  from public.leases l
  join public.tenants t on t.id = l.tenant_id
  join public.units u on u.id = l.unit_id
  join public.properties p on p.id = u.property_id
  cross join lateral (
    select l.start_date + app.police_registration_deadline_days(p.province) as deadline
  ) d
  cross join lateral (select v_as_of > d.deadline as overdue) o
  join public.portfolio_members m on m.portfolio_id = l.portfolio_id and m.role in ('owner', 'manager')
  where l.status = 'active' and l.police_status = 'pending' and v_as_of >= l.start_date
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Tenant CNIC expiring within 30 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select distinct on (m.user_id, t.id)
         t.portfolio_id, m.user_id, 'cnic_expiring',
         jsonb_build_object('tenant_id', t.id, 'tenant_name', t.full_name, 'cnic_expiry', t.cnic_expiry),
         'tenant', t.id, 'cnic_expiring:' || t.id || ':' || t.cnic_expiry
  from public.tenants t
  join public.leases l on l.tenant_id = t.id and l.status = 'active'
  join public.portfolio_members m on m.portfolio_id = t.portfolio_id and m.role in ('owner', 'manager')
  where t.cnic_expiry between v_as_of and v_as_of + 30
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  -- Unpaid utility bills due within 2 days.
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select b.portfolio_id, m.user_id, 'utility_bill_due',
         jsonb_build_object(
           'bill_id', b.id, 'utility_type', a.type, 'property_name', p.name,
           'amount', b.amount, 'due_date', b.due_date, 'in_landlord_name', a.in_landlord_name
         ),
         'utility_bill', b.id, 'utility_due:' || b.id
  from public.utility_bills b
  join public.utility_accounts a on a.id = b.utility_account_id
  join public.properties p on p.id = a.property_id
  join public.portfolio_members m on m.portfolio_id = b.portfolio_id and m.role in ('owner', 'manager')
  where b.status = 'unpaid' and b.due_date between v_as_of and v_as_of + 2
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_rows = row_count;
  v_total := v_total + v_rows;

  return v_total;
end
$$;

-- Tells owners when someone accepts an invitation.
create or replace function private.after_invitation_accepted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (portfolio_id, user_id, kind, params, entity_type, entity_id, dedupe_key)
  select new.portfolio_id, m.user_id, 'invitation_accepted',
         jsonb_build_object('email', new.email, 'role', new.role),
         'invitation', new.id, 'invitation_accepted:' || new.id
  from public.portfolio_members m
  where m.portfolio_id = new.portfolio_id and m.role = 'owner' and m.user_id <> new.accepted_by
  on conflict (user_id, dedupe_key) do nothing;
  return null;
end
$$;

create trigger portfolio_invitations_after_accept
  after update of accepted_at on public.portfolio_invitations
  for each row
  when (old.accepted_at is null and new.accepted_at is not null)
  execute function private.after_invitation_accepted();

-- ---------------------------------------------------------------------------
-- Audit trail
-- ---------------------------------------------------------------------------

create table public.audit_logs (
  id bigint generated always as identity primary key,
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null constraint audit_logs_action_check check (action in ('insert', 'update', 'delete')),
  table_name text not null,
  record_id uuid,
  changes jsonb not null,
  created_at timestamptz not null default now()
);

comment on table public.audit_logs is
  'Append-only change history. changes = full row (insert/delete) or {column: [old, new]} (update).';

create index audit_logs_portfolio_created_idx on public.audit_logs (portfolio_id, created_at desc);
create index audit_logs_record_idx on public.audit_logs (portfolio_id, table_name, record_id);
create index audit_logs_actor_id_idx on public.audit_logs (actor_id);

create or replace function private.redact_audit(p_row jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_row is null then null
    else p_row
      || case when p_row ? 'cnic' and p_row ->> 'cnic' is not null
           then jsonb_build_object('cnic', '[redacted]') else '{}'::jsonb end
      || case when p_row ? 'verifier_hash' then jsonb_build_object('verifier_hash', '[redacted]') else '{}'::jsonb end
  end
$$;

create or replace function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_row jsonb := coalesce(v_new, v_old);
  v_portfolio_id uuid;
  v_record_id uuid;
  v_changes jsonb;
begin
  v_portfolio_id := case when tg_table_name = 'portfolios'
                         then (v_row ->> 'id')::uuid
                         else (v_row ->> 'portfolio_id')::uuid end;
  v_record_id := coalesce((v_row ->> 'id')::uuid, (v_row ->> 'user_id')::uuid);

  -- Rows removed by a cascading portfolio deletion are not audited: the
  -- portfolio (and with it the audit trail) is gone.
  if not exists (select 1 from public.portfolios p where p.id = v_portfolio_id) then
    return null;
  end if;

  if tg_op = 'UPDATE' then
    -- Diff the raw values (so a changed CNIC is still recorded as changed),
    -- then redact sensitive values in the stored diff.
    select jsonb_object_agg(
      k,
      case when k in ('cnic', 'verifier_hash')
           then '["[redacted]", "[redacted]"]'::jsonb
           else jsonb_build_array(v_old -> k, v_new -> k) end
    )
    into v_changes
    from jsonb_object_keys(v_new) as keys (k)
    where k <> 'updated_at' and (v_old -> k) is distinct from (v_new -> k);
    if v_changes is null then
      return null;
    end if;
  else
    v_changes := private.redact_audit(v_row);
  end if;

  insert into public.audit_logs (portfolio_id, actor_id, action, table_name, record_id, changes)
  values (v_portfolio_id, (select auth.uid()), lower(tg_op), tg_table_name, v_record_id, v_changes);
  return null;
end
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'portfolios', 'portfolio_members', 'properties', 'units', 'tenants', 'leases', 'rent_changes',
    'lease_occupants', 'charges', 'payments', 'deposit_refunds', 'expenses', 'utility_accounts',
    'utility_bills', 'maintenance_requests', 'cash_handovers', 'documents'
  ]
  loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function private.audit_row_change()',
      v_table || '_audit', v_table
    );
  end loop;
end
$$;

alter table public.audit_logs enable row level security;
create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (portfolio_id = any ((select app.my_portfolio_ids(array['owner', 'manager']::public.member_role[]))::uuid[]));

grant select on public.audit_logs to authenticated;
grant select on public.audit_logs to service_role;
