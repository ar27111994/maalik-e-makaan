-- ============================================================================
-- Documents: photos and PDFs attached to any portfolio entity, stored in the
-- private `documents` bucket under `<portfolio_id>/<entity_type>/<entity_id>/
-- <file>`. Storage RLS scopes every object to its portfolio folder; clients
-- read files only through short-lived signed URLs.
-- ============================================================================

create type public.document_kind as enum (
  'cnic_front', 'cnic_back', 'photo', 'tenancy_agreement', 'police_registration',
  'rent_registration', 'utility_bill', 'receipt', 'invoice', 'meter_photo', 'property_paper', 'other'
);

create type public.document_entity as enum (
  'property', 'unit', 'tenant', 'lease', 'payment', 'expense', 'maintenance_request',
  'utility_bill', 'meter_reading'
);

create table public.documents (
  id uuid primary key default app.uuid_generate_v7(),
  portfolio_id uuid not null references public.portfolios (id) on delete cascade,
  entity_type public.document_entity not null,
  entity_id uuid not null,
  kind public.document_kind not null default 'other',
  storage_path text not null,
  file_name text not null
    constraint documents_file_name_check
      check (char_length(btrim(file_name)) between 1 and 200 and app.is_clean_text(file_name)),
  mime_type text not null
    constraint documents_mime_type_check
      check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')),
  size_bytes integer not null
    constraint documents_size_bytes_check check (size_bytes between 1 and 10485760),
  uploaded_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint documents_storage_path_key unique (storage_path),
  constraint documents_storage_path_check check (
    storage_path = portfolio_id::text || '/' || entity_type::text || '/' || entity_id::text || '/'
      || split_part(storage_path, '/', 4)
    and split_part(storage_path, '/', 4) ~ '^[0-9a-f-]{36}\.(jpg|jpeg|png|webp|heic|pdf)$'
  )
);

comment on table public.documents is
  'Metadata of a stored file. storage_path is <portfolio>/<entity type>/<entity id>/<uuid>.<ext>.';

create index documents_entity_idx on public.documents (portfolio_id, entity_type, entity_id, created_at desc);
create index documents_uploaded_by_idx on public.documents (uploaded_by);

-- The polymorphic entity must exist in the same portfolio.
create or replace function private.before_document_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_found boolean;
begin
  execute format(
    'select exists (select 1 from public.%I where id = $1 and portfolio_id = $2)',
    case new.entity_type
      when 'property' then 'properties'
      when 'unit' then 'units'
      when 'tenant' then 'tenants'
      when 'lease' then 'leases'
      when 'payment' then 'payments'
      when 'expense' then 'expenses'
      when 'maintenance_request' then 'maintenance_requests'
      when 'utility_bill' then 'utility_bills'
      when 'meter_reading' then 'meter_readings'
    end
  ) into v_found using new.entity_id, new.portfolio_id;

  if not v_found then
    perform app.fail('document_entity_not_found');
  end if;
  return new;
end
$$;

create trigger documents_before_insert
  before insert on public.documents
  for each row execute function private.before_document_insert();

select private.apply_portfolio_policies(
  'public.documents', array['owner', 'manager', 'accountant']::public.member_role[],
  array['owner', 'manager']::public.member_role[]
);

grant select, delete on public.documents to authenticated;
grant insert (id, portfolio_id, entity_type, entity_id, kind, storage_path, file_name, mime_type, size_bytes)
  on public.documents to authenticated;
grant update (kind, file_name) on public.documents to authenticated;

-- ---------------------------------------------------------------------------
-- Storage bucket and object policies
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documents', 'documents', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Folder layout check shared by the object policies (text comparisons only,
-- so malformed paths in other buckets can never raise cast errors).
create or replace function app.document_object_portfolio(p_name text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when p_name ~ '^[0-9a-f-]{36}/(property|unit|tenant|lease|payment|expense|maintenance_request|utility_bill|meter_reading)/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|webp|heic|pdf)$'
    then split_part(p_name, '/', 1)
  end
$$;

grant execute on function app.document_object_portfolio(text) to authenticated, service_role;

create policy documents_objects_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and app.document_object_portfolio(name) = any ((select app.my_portfolio_ids())::text[])
  );

create policy documents_objects_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and app.document_object_portfolio(name) = any ((select app.my_portfolio_ids(
      array['owner', 'manager', 'accountant']::public.member_role[]))::text[])
  );

create policy documents_objects_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and app.document_object_portfolio(name) = any ((select app.my_portfolio_ids(
      array['owner', 'manager']::public.member_role[]))::text[])
  );
