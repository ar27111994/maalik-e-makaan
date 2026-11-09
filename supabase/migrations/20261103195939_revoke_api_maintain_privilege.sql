-- ============================================================================
-- Least privilege on PostgreSQL 17: the API roles lose MAINTAIN.
--
-- PostgreSQL 17 added the MAINTAIN table privilege (VACUUM, ANALYZE, CLUSTER,
-- REINDEX, REFRESH MATERIALIZED VIEW and LOCK TABLE). The platform's default
-- privileges grant ALL on new tables in `public` to anon, authenticated and
-- service_role, which on PostgreSQL 17 includes MAINTAIN, and the foundation
-- migration revoked the older privileges by name only. The Data API cannot
-- issue these commands, but none of these roles needs them either.
-- ============================================================================

-- Future relations: revoke ALL, which also covers privileges added by future
-- PostgreSQL versions. Every table and view receives explicit grants.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;

-- Existing relations. MAINTAIN is not a privilege before PostgreSQL 17.
do $$
begin
  if current_setting('server_version_num')::integer >= 170000 then
    execute 'revoke maintain on all tables in schema public, private from anon, authenticated, service_role';
  end if;
end
$$;
