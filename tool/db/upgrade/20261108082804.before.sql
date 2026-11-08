-- Rows that exist when 20261108082804_invitation_findings.sql is applied
-- (F4 of formal/tla/Invitations): run on a database migrated up to
-- 20261107181820_ledger_findings.sql. Checked by 20261108082804.after.sql.
--
--   P  portfolio of the owners "gone" (deleted directly in Auth below) and
--      "kept", with the viewer "viewer";
--   Q  another portfolio of "kept".
-- Invitations (one e-mail each):
--   gone-pending@     by "gone", pending; "gone" is then deleted in Auth, so
--                     invited_by becomes NULL and, before the fix, it stays
--                     pending (asserted below)            -> revoked
--   nonowner-pending@ invited_by = "viewer", who is not an owner (as an
--                     inviter demoted while the trigger was missing)
--                                                          -> revoked
--   kept-pending@     by "kept", an owner, pending         -> stays pending
--   other-pending@    by "kept", in Q                      -> stays pending
--   gone-accepted@    by "gone", accepted before the deletion
--                                                          -> stays accepted
--   old-revoked@      by "gone", revoked on 2026-11-01     -> revoked_at kept
--   expired-orphan@   no inviter, expired but pending      -> revoked
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-4000-8000-0000000a0001', 'gone@example.com', now()),
  ('00000000-0000-4000-8000-0000000a0002', 'kept@example.com', now()),
  ('00000000-0000-4000-8000-0000000a0003', 'viewer@example.com', now()),
  ('00000000-0000-4000-8000-0000000a0004', 'gone-accepted@example.com', now());

insert into public.portfolios (id, name, created_by) values
  ('00000000-0000-4000-8000-0000000b0001', 'Upgrade P', '00000000-0000-4000-8000-0000000a0002'),
  ('00000000-0000-4000-8000-0000000b0002', 'Upgrade Q', '00000000-0000-4000-8000-0000000a0002');

insert into public.portfolio_members (portfolio_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000b0001', '00000000-0000-4000-8000-0000000a0001', 'owner'),
  ('00000000-0000-4000-8000-0000000b0001', '00000000-0000-4000-8000-0000000a0002', 'owner'),
  ('00000000-0000-4000-8000-0000000b0001', '00000000-0000-4000-8000-0000000a0003', 'viewer'),
  ('00000000-0000-4000-8000-0000000b0001', '00000000-0000-4000-8000-0000000a0004', 'manager'),
  ('00000000-0000-4000-8000-0000000b0002', '00000000-0000-4000-8000-0000000a0002', 'owner');

insert into public.portfolio_invitations
  (portfolio_id, email, role, verifier_hash, invited_by, expires_at, accepted_at, accepted_by, revoked_at)
values
  ('00000000-0000-4000-8000-0000000b0001', 'gone-pending@example.com', 'viewer', sha256('1'::bytea),
   '00000000-0000-4000-8000-0000000a0001', now() + interval '7 days', null, null, null),
  ('00000000-0000-4000-8000-0000000b0001', 'nonowner-pending@example.com', 'viewer', sha256('2'::bytea),
   '00000000-0000-4000-8000-0000000a0003', now() + interval '7 days', null, null, null),
  ('00000000-0000-4000-8000-0000000b0001', 'kept-pending@example.com', 'manager', sha256('3'::bytea),
   '00000000-0000-4000-8000-0000000a0002', now() + interval '7 days', null, null, null),
  ('00000000-0000-4000-8000-0000000b0002', 'other-pending@example.com', 'viewer', sha256('4'::bytea),
   '00000000-0000-4000-8000-0000000a0002', now() + interval '7 days', null, null, null),
  ('00000000-0000-4000-8000-0000000b0001', 'gone-accepted@example.com', 'manager', sha256('5'::bytea),
   '00000000-0000-4000-8000-0000000a0001', now() + interval '7 days', now(),
   '00000000-0000-4000-8000-0000000a0004', null),
  ('00000000-0000-4000-8000-0000000b0001', 'old-revoked@example.com', 'viewer', sha256('6'::bytea),
   '00000000-0000-4000-8000-0000000a0001', '2026-11-08 00:00+00', null, null, '2026-11-01 00:00+00'),
  ('00000000-0000-4000-8000-0000000b0001', 'expired-orphan@example.com', 'viewer', sha256('7'::bytea),
   null, '2026-11-01 00:00+00', null, null, null);

-- What GoTrue's admin delete does (dashboard, Auth admin API).
delete from auth.users where id = '00000000-0000-4000-8000-0000000a0001';

-- The state F4 left: the deleted inviter's invitation is still pending.
do $$
begin
  if not exists (
    select 1 from public.portfolio_invitations
    where email = 'gone-pending@example.com'
      and invited_by is null and accepted_at is null and revoked_at is null
  ) then
    raise exception 'fixture: the deleted inviter''s invitation is not pending before 20261108082804';
  end if;
end
$$;
