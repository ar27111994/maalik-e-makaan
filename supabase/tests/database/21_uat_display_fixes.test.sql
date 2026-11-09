-- The display faults the browser UAT found (20261109081109_uat_display_fixes.sql,
-- docs/uat.md):
--   D5  "vacant since" is the Pakistan date of the unit's creation, not the
--       UTC date, in public.unit_occupancy and in get_dashboard;
--   D6  automatic late fees carry no English note.
begin;
\ir _helpers.psql
select plan(8);

select tests.create_user('owner@example.com') as owner \gset
select tests.create_portfolio(:'owner') as pid \gset

-- ---------------------------------------------------------------------------
-- D5: a unit added at 01:30 on 9 November in Pakistan (20:30 UTC on the 8th)
-- ---------------------------------------------------------------------------

select set_config('app.today_override', '2026-11-09', true);
select tests.create_rental(:'pid') as r1 \gset
update public.units set created_at = '2026-11-08 20:30:00+00' where id = ((:'r1')::jsonb ->> 'unit_id')::uuid;

select tests.authenticate_as(:'owner');
select is(
  (select vacant_since from public.unit_occupancy where unit_id = ((:'r1')::jsonb ->> 'unit_id')::uuid),
  '2026-11-09'::date,
  'unit_occupancy: vacant since the Pakistan date it was added (9 Nov), not the UTC date (8 Nov)'
);
select public.get_dashboard(:'pid', '2026-11-09') as d \gset
select is(
  (:'d')::jsonb -> 'vacant_units' -> 0 ->> 'vacant_since',
  '2026-11-09',
  'get_dashboard: the vacant unit is vacant since 9 Nov'
);
select is(
  ((:'d')::jsonb -> 'vacant_units' -> 0 ->> 'vacant_days')::integer,
  0,
  'get_dashboard: no day of vacancy counted on the day it was added'
);
select tests.clear_authentication();

-- At 23:30 UTC on the 9th it is already the 10th in Pakistan.
update public.units set created_at = '2026-11-09 23:30:00+00' where id = ((:'r1')::jsonb ->> 'unit_id')::uuid;
select tests.authenticate_as(:'owner');
select is(
  (select vacant_since from public.unit_occupancy where unit_id = ((:'r1')::jsonb ->> 'unit_id')::uuid),
  '2026-11-10'::date,
  'unit_occupancy: 23:30 UTC on 9 Nov is 10 Nov in Pakistan'
);
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- D6: automatic late fees carry no note
-- ---------------------------------------------------------------------------

-- Rent 1,000 due on the 5th with 5 days' grace and a fixed 100 fee; on
-- 12 November October's and November's rent are past their grace.
select set_config('app.today_override', '2026-11-12', true);
select tests.create_rental(:'pid') as r2 \gset
select tests.create_lease(:'pid', :'r2', '2026-10-01', 1000,
  '{"late_fee_type": "flat", "late_fee_value": 100}') as lease \gset
select is(private.assess_late_fees(:'lease', '2026-11-12'), 2, 'two late fees are posted');
select is(
  (select count(*)::integer from public.charges
   where lease_id = :'lease' and kind = 'late_fee' and source = 'auto_late_fee' and description is null),
  2,
  'neither carries a note: the kind says "late fee" in the reader''s language'
);
select is(
  (select count(*)::integer from public.charges where description = 'Late fee'),
  0,
  'no charge carries the English note ''Late fee'''
);
select is(
  (select pg_get_functiondef('private.assess_late_fees(uuid, date)'::regprocedure) like '%''Late fee''%'),
  false,
  'assess_late_fees no longer writes the literal'
);

select * from finish();
rollback;
