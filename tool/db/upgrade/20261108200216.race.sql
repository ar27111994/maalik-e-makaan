-- A write that races 20261108200216_identity_checks.sql: run in another
-- session on the rows of 20261108200216.before.sql, left uncommitted while
-- the migration starts, and committed once the migration waits for a lock.
-- The old CHECK accepts the value and the new rule refuses it ('+92300123456'
-- is a mobile one digit short), so the migration must count it and refuse to
-- run, not commit NOT VALID CHECKs that the next migration then fails to
-- validate (tool/db/upgrade_test.sh, "race check").
--
-- expect: identity checks: stored values break the new phone or CNIC rules; nothing was changed
-- expect: tenants.phone: 1.
update public.tenants set phone = '+92300123456'
where id = '00000000-0000-4000-8000-0000000f0002';
