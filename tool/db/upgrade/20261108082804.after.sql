-- The one-off cleanup of 20261108082804_invitation_findings.sql revoked the
-- pending invitations accept_invitation would refuse, and nothing else (see
-- 20261108082804.before.sql for the rows).
do $$
declare
  v_state text;
  v_expected constant jsonb := jsonb_build_object(
    'gone-pending@example.com', 'revoked',
    'nonowner-pending@example.com', 'revoked',
    'expired-orphan@example.com', 'revoked',
    'kept-pending@example.com', 'pending',
    'other-pending@example.com', 'pending',
    'gone-accepted@example.com', 'accepted',
    'old-revoked@example.com', 'revoked 2026-11-01'
  );
  v_email text;
begin
  for v_email in select jsonb_object_keys(v_expected) loop
    select case
             when i.accepted_at is not null and i.revoked_at is null then 'accepted'
             when i.revoked_at = '2026-11-01 00:00+00' then 'revoked 2026-11-01'
             when i.revoked_at is not null then 'revoked'
             else 'pending'
           end
    into v_state
    from public.portfolio_invitations i
    where i.email = v_email;
    if v_state is distinct from v_expected ->> v_email then
      raise exception 'upgrade 20261108082804: % is %, expected %',
        v_email, coalesce(v_state, 'missing'), v_expected ->> v_email;
    end if;
  end loop;

  -- The query docs/operations.md gives for the hosted project.
  if (
    select count(*)
    from public.portfolio_invitations i
    where i.accepted_at is null and i.revoked_at is null
      and (i.invited_by is null or not exists (
        select 1 from public.portfolio_members m
        where m.portfolio_id = i.portfolio_id and m.user_id = i.invited_by and m.role = 'owner'))
  ) <> 0 then
    raise exception 'upgrade 20261108082804: a pending invitation without an owner as inviter is left';
  end if;

  if not exists (
    select 1 from public.portfolio_members
    where user_id = '00000000-0000-4000-8000-0000000a0004' and role = 'manager'
  ) then
    raise exception 'upgrade 20261108082804: the member who accepted lost their membership';
  end if;
end
$$;
