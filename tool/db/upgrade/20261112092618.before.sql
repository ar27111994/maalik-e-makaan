-- Rows that exist when 20261112092618_residence.sql is applied: run on a
-- database migrated up to 20261109081109_uat_display_fixes.sql. Checked by
-- 20261112092618.after.sql. The migration must add the owner-abroad answer
-- as "not yet answered" (NULL, never a default, never filled from anyone's
-- residence), name no caretaker, give every profile an empty residence row,
-- and write nothing else, not even an audit entry.
--
--   owner-res    signed up with the Urdu app and sign-up metadata that look
--                like a residence; a +92 number
--   manager-res  a +44 number; the only manager of portfolio A
--   lonely-res   no portfolio
--   A            owner and manager, with payment details
--   B            archived, owner only
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000001c0001', 'owner-res@example.com', now(),
   '{"full_name": "Owner Res", "locale": "ur", "residence_country": "GB", "time_zone": "Europe/London"}'),
  ('00000000-0000-4000-8000-0000001c0002', 'manager-res@example.com', now(), '{"full_name": "Manager Res"}'),
  ('00000000-0000-4000-8000-0000001c0003', 'lonely-res@example.com', now(), '{}');

update public.profiles set phone = '+923001234567' where id = '00000000-0000-4000-8000-0000001c0001';
update public.profiles set phone = '+447700900123' where id = '00000000-0000-4000-8000-0000001c0002';

insert into public.portfolios
  (id, name, created_by, landlord_name, raast_id, bank_account_title, bank_iban, created_at, updated_at,
   archived_at)
values
  ('00000000-0000-4000-8000-0000001d0001', 'Upgrade Residence A', '00000000-0000-4000-8000-0000001c0001',
   'Owner Res', '+923001234567', 'OWNER RES', 'PK36SCBL0000001123456702', '2026-10-01 09:00:00+00',
   '2026-10-02 09:00:00+00', null),
  ('00000000-0000-4000-8000-0000001d0002', 'Upgrade Residence B', '00000000-0000-4000-8000-0000001c0001',
   null, null, null, null, '2026-10-01 09:00:00+00', '2026-10-03 09:00:00+00', '2026-10-03 09:00:00+00');

insert into public.portfolio_members (portfolio_id, user_id, role) values
  ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001c0001', 'owner'),
  ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001c0002', 'manager'),
  ('00000000-0000-4000-8000-0000001d0002', '00000000-0000-4000-8000-0000001c0001', 'owner');

do $$
begin
  if exists (
    select 1 from pg_attribute a
    where a.attrelid = 'public.portfolios'::regclass and a.attname = 'owner_abroad' and not a.attisdropped
  ) then
    raise exception 'upgrade 20261112092618: portfolios already has owner_abroad before the migration';
  end if;
  if (select count(*) from public.audit_logs a
      where a.table_name = 'portfolios' and a.action = 'insert'
        and a.record_id in ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001d0002'))
     <> 2 then
    raise exception 'upgrade 20261112092618: expected the two portfolios'' insert audit entries';
  end if;
end
$$;
