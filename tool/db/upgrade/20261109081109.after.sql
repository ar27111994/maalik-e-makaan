-- The one-off change of 20261109081109_uat_display_fixes.sql removed the
-- note of the automatic late fees the job wrote, and nothing else (see
-- 20261109081109.before.sql for the rows).
do $$
declare
  v_got jsonb;
  v_expected constant jsonb := jsonb_build_array(
    jsonb_build_array('late_fee', '2026-10-01', false, null),
    jsonb_build_array('late_fee', '2026-11-01', true, 'Late fee'),
    jsonb_build_array('other', null, false, 'Late fee'),
    jsonb_build_array('rent', '2026-10-01', false, 'Paid late'),
    jsonb_build_array('rent', '2026-11-01', false, null)
  );
begin
  select jsonb_agg(jsonb_build_array(c.kind, c.period_month, c.voided_at is not null, c.description)
                   order by c.kind::text, c.period_month)
  into v_got
  from public.charges c
  where c.lease_id = '00000000-0000-4000-8000-0000000e0004';
  if v_got is distinct from v_expected then
    raise exception 'upgrade 20261109081109: charges are %, expected %', v_got, v_expected;
  end if;
end
$$;
