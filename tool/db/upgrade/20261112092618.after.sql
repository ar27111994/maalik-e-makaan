-- What 20261112092618_residence.sql did to the rows of
-- 20261112092618.before.sql: existing portfolios are "not yet answered" and
-- have no caretaker, every profile has an empty residence row, nothing else
-- changed and nothing was audited, and an app that does not know the
-- question still creates portfolios and can answer it.
do $$
declare
  v_got jsonb;
  v_expected constant jsonb := jsonb_build_array(
    jsonb_build_array('Upgrade Residence A', null, null, null, 'Owner Res', '+923001234567', 'OWNER RES',
                      'PK36SCBL0000001123456702', '2026-10-02T09:00:00+00:00', null),
    jsonb_build_array('Upgrade Residence B', null, null, null, null, null, null, null,
                      '2026-10-03T09:00:00+00:00', '2026-10-03T09:00:00+00:00')
  );
begin
  -- "is null" in the comparison: a default of false would fail it.
  select jsonb_agg(jsonb_build_array(
           p.name, p.owner_abroad, p.caretaker_user_id, p.caretaker_since, p.landlord_name, p.raast_id,
           p.bank_account_title, p.bank_iban, p.updated_at, p.archived_at) order by p.name)
  into v_got
  from public.portfolios p
  where p.id in ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001d0002');
  if v_got is distinct from v_expected then
    raise exception 'upgrade 20261112092618: portfolios are %, expected %', v_got, v_expected;
  end if;
  if exists (
    select 1 from public.portfolios p
    where p.id in ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001d0002')
      and (p.owner_abroad is not null or p.caretaker_user_id is not null or p.caretaker_since is not null)
  ) then
    raise exception 'upgrade 20261112092618: an existing portfolio has an answer or a caretaker';
  end if;

  if exists (
    select 1 from public.profiles p
    where (select count(*) from public.profile_residences r where r.user_id = p.id) <> 1
  ) then
    raise exception 'upgrade 20261112092618: a profile has no residence row, or several';
  end if;
  if (select count(*) from public.profile_residences r
      where r.user_id in ('00000000-0000-4000-8000-0000001c0001', '00000000-0000-4000-8000-0000001c0002',
                          '00000000-0000-4000-8000-0000001c0003')
        and r.residence_country is null and r.time_zone is null and r.stated_at is null) <> 3 then
    raise exception 'upgrade 20261112092618: a residence was inferred (phone, language or metadata)';
  end if;

  if (select count(*) from public.audit_logs a where a.table_name = 'portfolios' and a.action = 'insert'
        and a.record_id in ('00000000-0000-4000-8000-0000001d0001', '00000000-0000-4000-8000-0000001d0002'))
     <> 2
     or exists (select 1 from public.audit_logs a where a.table_name = 'portfolios' and a.action <> 'insert') then
    raise exception 'upgrade 20261112092618: the migration wrote audit entries';
  end if;

  if (select count(*) from pg_constraint c
      where c.conrelid = 'public.portfolios'::regclass and c.convalidated
        and c.conname in ('portfolios_caretaker_since_check', 'portfolios_caretaker_user_id_fkey')) <> 2 then
    raise exception 'upgrade 20261112092618: the caretaker constraints are missing or not validated';
  end if;
end
$$;

-- An app that does not know the question: its calls still work, and its new
-- portfolios are "not yet answered".
-- Signed in as owner-res, as PostgREST does (tests.authenticate_as).
do $$
begin
  perform set_config('request.jwt.claims',
                     '{"sub": "00000000-0000-4000-8000-0000001c0001", "role": "authenticated"}', true);
  perform set_config('role', 'authenticated', true);
end
$$;
do $$
begin
  if current_user <> 'authenticated' then
    raise exception 'upgrade 20261112092618: the old calls did not run as a signed-in user';
  end if;
  if (public.create_portfolio('Old app call', null)).owner_abroad is not null then
    raise exception 'upgrade 20261112092618: a positional create_portfolio call stored an answer';
  end if;
  if (public.create_portfolio(p_name => 'Old app named call', p_id => '00000000-0000-7000-8000-0000001d0003'))
       .owner_abroad is not null then
    raise exception 'upgrade 20261112092618: a named {p_name, p_id} call stored an answer';
  end if;
  if public.set_owner_abroad('00000000-0000-4000-8000-0000001d0001', true) is distinct from true then
    raise exception 'upgrade 20261112092618: the owner could not answer the question';
  end if;
end
$$;
