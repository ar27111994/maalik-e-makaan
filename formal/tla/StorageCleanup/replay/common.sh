# shellcheck shell=bash
# Helpers for the S1/S2 replays (sourced). Connection settings come from
# tool/db/env.sh; DB names the disposable database; OUT is a scratch directory.

q() { psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

# A transaction as a signed-in user (RLS applies), left open for the caller.
as_user() {
  printf 'begin;\nset local "request.jwt.claims" to %s;\nset local role authenticated;\n%s\n' \
    "'{\"sub\":\"$1\",\"role\":\"authenticated\"}'" "$2"
}

# The Storage API deleting as a user: RLS applies, and it sets
# storage.allow_delete_query like the real Storage API does.
as_storage_api() {
  printf 'begin;\nset local "request.jwt.claims" to %s;\nset local role authenticated;\nset local storage.allow_delete_query = %s;\n%s\n' \
    "'{\"sub\":\"$1\",\"role\":\"authenticated\"}'" "'true'" "$2"
}

# An owner, a portfolio, a tenant and a file uploaded two days ago without a
# document row. Prints: owner portfolio tenant path
fixture() {
  local owner portfolio tenant path
  owner="$(q -c "insert into auth.users (id, email, email_confirmed_at)
                 values (gen_random_uuid(), 'fv-' || gen_random_uuid() || '@example.com', now()) returning id")"
  portfolio="$(q -c "with p as (insert into public.portfolios (name, created_by) values ('FV replay', '$owner') returning id),
                          m as (insert into public.portfolio_members (portfolio_id, user_id, role)
                                select id, '$owner', 'owner' from p)
                     select id from p")"
  tenant="$(q -c "insert into public.tenants (portfolio_id, full_name) values ('$portfolio', 'Replay tenant') returning id")"
  path="$portfolio/tenant/$tenant/$(q -c "select gen_random_uuid()").jpg"
  q -c "insert into storage.objects (bucket_id, name, created_at)
        values ('documents', '$path', now() - interval '2 days')" >/dev/null
  echo "$owner $portfolio $tenant $path"
}

attach_sql() {
  echo "insert into public.documents (portfolio_id, entity_type, entity_id, storage_path, file_name, mime_type, size_bytes)
        values ('$2', 'tenant', '$3', '$4', 'cnic.jpg', 'image/jpeg', 1000);"
}

count_rows() {
  q -c "select 'document rows for the file: ' || count(*) from public.documents where storage_path = '$1'"
  q -c "select 'storage objects for the file: ' || count(*) from storage.objects
        where bucket_id = 'documents' and name = '$1'"
}
