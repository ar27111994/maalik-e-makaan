-- Residence, per person and per portfolio (20261112092618_residence.sql;
-- D-16). A person's declared country and time zone (profile_residences), and
-- a portfolio's owner-abroad answer and caretaker. Who may read and write
-- them is also in 03_rls_matrix; what the migration does to existing rows is
-- tool/db/upgrade/20261112092618.*.sql.
begin;
\ir _helpers.psql
select plan(86);

select tests.create_user('owner.res@example.com') as owner \gset
select tests.create_user('coowner.res@example.com') as coowner \gset
select tests.create_user('manager.res@example.com') as manager \gset
select tests.create_user('accountant.res@example.com') as accountant \gset
select tests.create_user('viewer.res@example.com') as viewer \gset
select tests.create_user('outsider.res@example.com') as outsider \gset
select tests.create_portfolio(:'owner', 'Residence A') as pa \gset
select tests.create_portfolio(:'owner', 'Residence B') as pb \gset
select tests.add_member(:'pa', :'coowner', 'owner');
select tests.add_member(:'pa', :'manager', 'manager');
select tests.add_member(:'pa', :'accountant', 'accountant');
select tests.add_member(:'pa', :'viewer', 'viewer');
select tests.add_member(:'pb', :'manager', 'manager');

-- The caretaker of a portfolio, and every audited clearing of p_user_id as its
-- caretaker (one actor per audit row).
create function tests.caretaker_clearings(p_portfolio_id uuid, p_user_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'caretaker', (select p.caretaker_user_id from public.portfolios p where p.id = p_portfolio_id),
    'since', (select p.caretaker_since from public.portfolios p where p.id = p_portfolio_id),
    'cleared_by', (
      select coalesce(jsonb_agg(a.actor_id order by a.id), '[]'::jsonb)
      from public.audit_logs a
      where a.portfolio_id = p_portfolio_id and a.table_name = 'portfolios' and a.action = 'update'
        and a.changes -> 'caretaker_user_id' = jsonb_build_array(p_user_id, null)
        and jsonb_typeof(a.changes -> 'caretaker_since' -> 0) = 'string'
        and a.changes -> 'caretaker_since' -> 1 = 'null'::jsonb
    )
  )
$$;

-- Update audit rows of a portfolio's own row.
create function tests.portfolio_updates(p_portfolio_id uuid)
returns integer
language sql
security definer
set search_path = ''
as $$
  select count(*)::integer from public.audit_logs a
  where a.portfolio_id = p_portfolio_id and a.table_name = 'portfolios' and a.action = 'update'
$$;

grant execute on all functions in schema tests to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The supported countries and time zones
-- ---------------------------------------------------------------------------

select is(cardinality(app.supported_country_codes()), 249, 'the 249 countries of iso3166.tab are supported');
select is(cardinality(app.supported_time_zones()), 418, 'the 418 zones of zone.tab are supported');
select is(
  app.supported_country_codes(),
  (select array_agg(c order by c collate "C") from (select distinct unnest(app.supported_country_codes()) c) s
   where c ~ '^[A-Z]{2}$'),
  'country codes are two upper-case letters, sorted by code point, without duplicates'
);
select is(
  app.supported_time_zones(),
  (select array_agg(z order by z collate "C") from (select distinct unnest(app.supported_time_zones()) z) s),
  'time zones are sorted by code point, without duplicates'
);
select is(
  (select array_agg(z) from unnest(app.supported_time_zones()) z
   where not exists (select 1 from pg_timezone_names n where n.name = z)),
  null,
  'the server knows every supported time zone'
);
select ok(
  'PK' = any (app.supported_country_codes()) and 'GB' = any (app.supported_country_codes())
  and 'Asia/Karachi' = any (app.supported_time_zones()) and 'Europe/London' = any (app.supported_time_zones()),
  'Pakistan and the United Kingdom, Asia/Karachi and Europe/London are supported'
);
select ok(
  (select bool_and(p.provolatile = 'i' and p.proisstrict and not p.prosecdef
                   and coalesce(p.proconfig @> array['search_path=""'], false)
                   and has_function_privilege('authenticated', p.oid, 'execute')
                   and has_function_privilege('service_role', p.oid, 'execute')
                   and not has_function_privilege('anon', p.oid, 'execute'))
   from pg_proc p
   where p.oid in ('app.is_valid_country_code(text)'::regprocedure, 'app.is_valid_time_zone(text)'::regprocedure)),
  'the rules are immutable, strict, SECURITY INVOKER, with an empty search_path, run by the writing roles'
);
select ok(
  app.is_valid_country_code(null) is null and app.is_valid_time_zone(null) is null,
  'the rules give NULL for NULL, so "not stated" passes'
);

-- ---------------------------------------------------------------------------
-- Per person: declared, never inferred
-- ---------------------------------------------------------------------------

select results_eq(
  format($$select r.residence_country, r.time_zone, r.stated_at from public.profile_residences r
           where r.user_id = %L$$, :'owner'),
  $$values (null::text, null::text, null::timestamptz)$$,
  'a new account gets one residence row, with nothing stated'
);

-- A Pakistani number, the Urdu app language and residence-looking sign-up
-- metadata, and a UK number: none of them is read as residence.
insert into auth.users (id, email, email_confirmed_at, phone, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000a0001', 'pk-number.res@example.com', now(), '+923001234567',
   '{"full_name": "Pk Number", "locale": "ur", "residence_country": "GB", "time_zone": "Europe/London"}'),
  ('00000000-0000-4000-8000-0000000a0002', 'uk-number.res@example.com', now(), '+447700900123',
   '{"full_name": "Uk Number"}');
update public.profiles set phone = '+923001234567' where id = '00000000-0000-4000-8000-0000000a0001';
update public.profiles set phone = '+447700900123' where id = '00000000-0000-4000-8000-0000000a0002';
select is(
  (select array_agg(format('%s:%s', p.locale, p.phone) order by p.email) from public.profiles p
   where p.id in ('00000000-0000-4000-8000-0000000a0001', '00000000-0000-4000-8000-0000000a0002')),
  array['ur:+923001234567', 'en:+447700900123'],
  'the profiles took the language and the phone numbers'
);
select is(
  (select count(*)::integer from public.profile_residences r
   where r.user_id in ('00000000-0000-4000-8000-0000000a0001', '00000000-0000-4000-8000-0000000a0002')
     and r.residence_country is null and r.time_zone is null and r.stated_at is null),
  2,
  'a +92 or +44 number, the app language and sign-up metadata never become a residence'
);

-- A server-side write keeps what it sets; the person's own write stamps
-- stated_at.
select tests.authenticate_as_service_role();
update public.profile_residences set stated_at = '2026-01-01 00:00:00+00' where user_id = :'owner';
select is(
  (select r.stated_at from public.profile_residences r where r.user_id = :'owner'),
  '2026-01-01 00:00:00+00'::timestamptz,
  'a service-role write keeps the stated_at it sets'
);

select tests.authenticate_as(:'owner');
update public.profile_residences set residence_country = 'GB', time_zone = 'Europe/London'
where user_id = :'owner';
select results_eq(
  $$select r.residence_country, r.time_zone, r.stated_at = now(), r.updated_at = now()
    from public.profile_residences r$$,
  $$values ('GB'::text, 'Europe/London'::text, true, true)$$,
  'a person states their country and time zone, reads them back, and stated_at is stamped'
);

select throws_ok($$update public.profile_residences set residence_country = 'gb'$$, '23514', null,
                 'the country "gb" (lower case) is refused');
select throws_ok($$update public.profile_residences set residence_country = 'UK'$$, '23514', null,
                 'the country "UK" (reserved, not ISO 3166-1) is refused');
select throws_ok($$update public.profile_residences set residence_country = 'XX'$$, '23514', null,
                 'the country "XX" (not assigned) is refused');
select throws_ok($$update public.profile_residences set residence_country = 'XK'$$, '23514', null,
                 'the country "XK" (user-assigned) is refused');
select throws_ok($$update public.profile_residences set residence_country = 'PAK'$$, '23514', null,
                 'the country "PAK" (alpha-3) is refused');
select throws_ok($$update public.profile_residences set residence_country = ' PK'$$, '23514', null,
                 'the country " PK" (leading space) is refused');
select throws_ok($$update public.profile_residences set residence_country = ''$$, '23514', null,
                 'an empty country is refused');
select throws_ok($$update public.profile_residences set time_zone = 'Europe/london'$$, '23514', null,
                 'the time zone "Europe/london" (case) is refused');
select throws_ok($$update public.profile_residences set time_zone = 'Asia/Calcutta'$$, '23514', null,
                 'the time zone "Asia/Calcutta" (a link) is refused');
select throws_ok($$update public.profile_residences set time_zone = 'UTC'$$, '23514', null,
                 'the time zone "UTC" is refused');
select throws_ok($$update public.profile_residences set time_zone = 'Etc/GMT+5'$$, '23514', null,
                 'the time zone "Etc/GMT+5" is refused');
select throws_ok(format('update public.profile_residences set time_zone = %L', E'Europe/London\n'), '23514', null,
                 'the time zone "Europe/London\n" (trailing line feed) is refused');
select throws_ok($$update public.profile_residences set time_zone = ''$$, '23514', null,
                 'an empty time zone is refused');

select lives_ok($$update public.profile_residences set residence_country = 'NO', time_zone = 'Europe/Oslo'$$,
                'Norway, Europe/Oslo is accepted');
select lives_ok($$update public.profile_residences set residence_country = 'BH', time_zone = 'Asia/Bahrain'$$,
                'Bahrain, Asia/Bahrain is accepted');
select lives_ok($$update public.profile_residences set residence_country = 'KW', time_zone = 'Asia/Kuwait'$$,
                'Kuwait, Asia/Kuwait is accepted');
select lives_ok($$update public.profile_residences set residence_country = null, time_zone = null$$,
                'nothing stated is accepted');
select lives_ok($$update public.profile_residences set residence_country = 'PK', time_zone = 'Asia/Karachi'$$,
                'Pakistan, Asia/Karachi is accepted');
update public.profile_residences set residence_country = 'GB', time_zone = 'Europe/London';

-- Business dates stay on Pakistan time whatever the person states.
update public.profile_residences set residence_country = 'KI', time_zone = 'Pacific/Kiritimati';
select is(app.today_pkt(), (now() at time zone 'Asia/Karachi')::date,
          'today is the Pakistan date for a person who states a zone of UTC+14');
select set_config('app.today_override', '2026-11-12', true);
select is(app.today_pkt(), '2026-11-12'::date, 'app.today_override still sets today');
select set_config('app.today_override', '', true);
update public.profile_residences set residence_country = 'GB', time_zone = 'Europe/London';

-- ---------------------------------------------------------------------------
-- Account deletion
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
select tests.create_user('leaver.res@example.com') as leaver \gset
select tests.authenticate_as(:'leaver');
update public.profile_residences set residence_country = 'AE', time_zone = 'Asia/Dubai';
select tests.authenticate_as_service_role();
select public.admin_delete_account_data(:'leaver');
select results_eq(
  format($$select r.residence_country, r.time_zone, r.stated_at from public.profile_residences r
           where r.user_id = %L$$, :'leaver'),
  $$values (null::text, null::text, null::timestamptz)$$,
  'the declared residence is cleared when the account''s deletion starts'
);
select tests.authenticate_as(:'leaver');
select throws_ok($$update public.profile_residences set residence_country = 'AE'$$, '22023', 'account_deleted',
                 'once deletion has started, the person can no longer state a residence');
select tests.clear_authentication();
delete from auth.users where id = :'leaver';
select is((select count(*)::integer from public.profile_residences r where r.user_id = :'leaver'), 0,
          'the residence row goes with the account');

-- ---------------------------------------------------------------------------
-- Never audited
-- ---------------------------------------------------------------------------

select is((select count(*)::integer from public.audit_logs a where a.changes::text like '%Europe/London%'), 0,
          'no audit entry holds a declared time zone');
select is(
  (select count(*)::integer from pg_trigger t
   where t.tgrelid = 'public.profile_residences'::regclass
     and t.tgfoid = 'private.audit_row_change()'::regprocedure),
  0,
  'residence rows have no audit trigger'
);

-- ---------------------------------------------------------------------------
-- create_portfolio: the answer at creation, never pre-filled
-- ---------------------------------------------------------------------------

select has_function('public', 'create_portfolio', array['text', 'uuid', 'boolean'],
                    'create_portfolio takes the owner-abroad answer');
select hasnt_function('public', 'create_portfolio', array['text', 'uuid'],
                      'the two-argument create_portfolio is gone, so no call is ambiguous');

select tests.create_user('maker.res@example.com') as maker \gset
select tests.authenticate_as(:'maker');
update public.profile_residences set residence_country = 'GB', time_zone = 'Europe/London';
select (public.create_portfolio(p_name => 'Named only')).id as p_named \gset
select (public.create_portfolio('Positional', '00000000-0000-7000-8000-0000000b0001')).id as p_positional \gset
select (public.create_portfolio(p_name => 'Abroad', p_owner_abroad => true)).id as p_true \gset
select (public.create_portfolio(p_name => 'At home', p_owner_abroad => false)).id as p_false \gset

select is(
  (select array_agg(format('%s:%s', p.name, coalesce(p.owner_abroad::text, 'null')) order by p.name)
   from public.portfolios p where p.id in (:'p_named', :'p_positional')),
  array['Named only:null', 'Positional:null'],
  'a call without the answer ({p_name}, or positional) stores it as not yet answered'
);
select is(
  (select array_agg(format('%s:%s', p.name, p.owner_abroad::text) order by p.name)
   from public.portfolios p where p.id in (:'p_true', :'p_false')),
  array['Abroad:true', 'At home:false'],
  'an answer given at creation is stored as given'
);
select is(
  (select p.owner_abroad from public.portfolios p where p.id = :'p_named'),
  null,
  'a creator who lives in the United Kingdom does not pre-fill the answer'
);
select is(
  (select format('%s:%s', r.name, coalesce(r.owner_abroad::text, 'null'))
   from public.create_portfolio('Renamed', '00000000-0000-7000-8000-0000000b0001', true) r),
  'Positional:null',
  'a replayed creation returns the stored portfolio unchanged, whatever answer it carries'
);
select is(
  (select a.changes -> 'owner_abroad' from public.audit_logs a
   where a.portfolio_id = :'p_true' and a.table_name = 'portfolios' and a.action = 'insert'),
  'true'::jsonb,
  'the creation''s audit entry records the answer'
);

-- ---------------------------------------------------------------------------
-- set_owner_abroad
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'owner');
select is(public.set_owner_abroad(:'pa', true), true, 'an owner answers the question');
select is(public.set_owner_abroad(:'pa', false), false, 'an owner changes the answer');
select results_eq(
  format($$select a.changes, a.actor_id from public.audit_logs a
           where a.portfolio_id = %L and a.table_name = 'portfolios' and a.action = 'update'
           order by a.id$$, :'pa'),
  format($$values ('{"owner_abroad": [null, true]}'::jsonb, %L::uuid),
                  ('{"owner_abroad": [true, false]}'::jsonb, %L::uuid)$$, :'owner', :'owner'),
  'each answer is audited with its actor'
);

select tests.authenticate_as(:'manager');
select is(public.set_owner_abroad(:'pb', true), true, 'a manager answers an unanswered question');
select is(public.set_owner_abroad(:'pb', true), true, 'the same answer again (a retry) returns it');
select is(tests.portfolio_updates(:'pb'), 1, 'a retry writes no audit entry');
select throws_ok(format('select public.set_owner_abroad(%L, false)', :'pb'), '22023', 'owner_abroad_answered',
                 'a manager cannot change an answer');
select is(public.set_owner_abroad(:'pb', false, p_if_unanswered => true), true,
          'a manager''s stale question returns the answer already given');
select tests.authenticate_as(:'owner');
select is(public.set_owner_abroad(:'pb', false, p_if_unanswered => true), true,
          'an owner''s stale question returns the answer already given');
select is(
  (select format('%s:%s', p.owner_abroad::text, tests.portfolio_updates(p.id)) from public.portfolios p
   where p.id = :'pb'),
  'true:1',
  'a stale question changes nothing and writes no audit entry'
);

select tests.authenticate_as(:'outsider');
select throws_ok(format('select public.set_owner_abroad(%L, null)', :'pa'), '22023', 'invalid_owner_abroad',
                 'an answer cannot be taken back to NULL (refused before authorisation)');
select throws_ok(format('select public.set_owner_abroad(%L, true, null)', :'pa'), '22023', 'invalid_owner_abroad',
                 'p_if_unanswered cannot be NULL');
select tests.authenticate_as(:'owner');
select is((select p.owner_abroad from public.portfolios p where p.id = :'pa'), false,
          'the answer stays as last given');

-- ---------------------------------------------------------------------------
-- set_caretaker
-- ---------------------------------------------------------------------------

select lives_ok(format('select public.set_caretaker(%L, %L)', :'pa', :'manager'),
                'an owner names a manager as caretaker (while the owner lives in Pakistan)');
select results_eq(
  format($$select p.caretaker_user_id, p.caretaker_since from public.portfolios p where p.id = %L$$, :'pa'),
  format($$values (%L::uuid, now())$$, :'manager'),
  'the caretaker and the time they were named are stored'
);
select is(
  (select format('%s:%s', a.actor_id, (select array_agg(k order by k) from jsonb_object_keys(a.changes) k))
   from public.audit_logs a
   where a.portfolio_id = :'pa' and a.table_name = 'portfolios' and a.action = 'update'
   order by a.id desc limit 1),
  format('%s:{caretaker_since,caretaker_user_id}', :'owner'),
  'naming a caretaker is audited with both columns and its actor'
);
select ctid::text as named_ctid from public.portfolios where id = :'pa' \gset
select public.set_caretaker(:'pa', :'manager');
select is(
  (select format('%s:%s', p.ctid, tests.portfolio_updates(p.id)) from public.portfolios p where p.id = :'pa'),
  format('%s:3', :'named_ctid'),
  'naming the same caretaker again changes nothing (caretaker_since stays, no audit entry)'
);
select throws_ok(format('select public.set_caretaker(%L, %L)', :'pa', :'accountant'), '22023',
                 'caretaker_not_manager', 'an accountant cannot be the caretaker');
select throws_ok(format('select public.set_caretaker(%L, %L)', :'pa', :'viewer'), '22023',
                 'caretaker_not_manager', 'a viewer cannot be the caretaker');
select throws_ok(format('select public.set_caretaker(%L, %L)', :'pa', :'coowner'), '22023',
                 'caretaker_not_manager', 'an owner cannot be the caretaker');
select throws_ok(format('select public.set_caretaker(%L, %L)', :'pa', :'outsider'), '22023',
                 'member_not_found', 'someone outside the portfolio cannot be the caretaker');
select lives_ok(format('select public.set_caretaker(%L, null)', :'pa'), 'an owner clears the caretaker');
select results_eq(
  format($$select p.caretaker_user_id, p.caretaker_since from public.portfolios p where p.id = %L$$, :'pa'),
  $$values (null::uuid, null::timestamptz)$$,
  'clearing the caretaker clears when they were named'
);

-- Whoever writes the column, the caretaker is a manager.
select public.set_caretaker(:'pa', :'manager');
select tests.authenticate_as_service_role();
select throws_ok(format('update public.portfolios set caretaker_user_id = %L where id = %L', :'viewer', :'pa'),
                 '22023', 'caretaker_not_manager', 'the service role cannot name a viewer as caretaker');
select throws_ok(format('update public.portfolios set caretaker_user_id = %L where id = %L',
                        '00000000-0000-4000-8000-0000000a00ff', :'pa'),
                 '22023', 'caretaker_not_manager', 'nor someone who is not a member (refused before the key check)');
update public.portfolios set caretaker_since = '2000-01-01 00:00:00+00' where id = :'pa';
select results_eq(
  format($$select p.caretaker_user_id, p.caretaker_since from public.portfolios p where p.id = %L$$, :'pa'),
  format($$values (%L::uuid, now())$$, :'manager'),
  'a written caretaker_since is put back: the trigger owns it'
);
select throws_ok(format($$insert into public.portfolios (name, created_by, caretaker_user_id)
                          values ('Forged', %L, %L)$$, :'owner', :'manager'),
                 '22023', 'caretaker_not_manager', 'a new portfolio cannot start with a caretaker');

-- Switching the answer to false keeps the caretaker (a caretaker does not
-- depend on the answer).
select tests.authenticate_as(:'owner');
select public.set_caretaker(:'pb', :'manager');
select public.set_owner_abroad(:'pb', false);
select is((select p.caretaker_user_id from public.portfolios p where p.id = :'pb'), :'manager'::uuid,
          'changing the answer keeps the caretaker');

-- ---------------------------------------------------------------------------
-- The caretaker is cleared when their membership ends or stops being manager
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
select tests.create_portfolio(:'owner', 'Residence C') as pc \gset
select tests.create_user('m-demoted.res@example.com') as m_demoted \gset
select tests.create_user('m-promoted.res@example.com') as m_promoted \gset
select tests.create_user('m-removed.res@example.com') as m_removed \gset
select tests.create_user('m-leaving.res@example.com') as m_leaving \gset
select tests.create_user('m-deleted.res@example.com') as m_deleted \gset
select tests.create_user('m-auth.res@example.com') as m_auth \gset
select tests.create_user('m-kept.res@example.com') as m_kept \gset
select tests.add_member(:'pc', u, 'manager')
from unnest(array[:'m_demoted', :'m_promoted', :'m_removed', :'m_leaving', :'m_deleted', :'m_auth',
                  :'m_kept']::uuid[]) u;

select tests.authenticate_as(:'owner');
select is((select p.owner_abroad from public.portfolios p where p.id = :'pc'), null,
          'the portfolio below is unanswered: a caretaker does not need an answer');
select public.set_caretaker(:'pc', :'m_demoted');
select public.update_member_role(:'pc', :'m_demoted', 'viewer');
select is(tests.caretaker_clearings(:'pc', :'m_demoted'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(:'owner')),
          'demoting the caretaker clears it, audited with the owner as actor');

select public.set_caretaker(:'pc', :'m_promoted');
select public.update_member_role(:'pc', :'m_promoted', 'owner');
select is(tests.caretaker_clearings(:'pc', :'m_promoted'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(:'owner')),
          'promoting the caretaker to owner clears it');

select public.set_caretaker(:'pc', :'m_removed');
select public.remove_member(:'pc', :'m_removed');
select is(tests.caretaker_clearings(:'pc', :'m_removed'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(:'owner')),
          'removing the caretaker clears it');

select public.set_caretaker(:'pc', :'m_leaving');
select tests.authenticate_as(:'m_leaving');
select public.remove_member(:'pc', :'m_leaving');
select is(tests.caretaker_clearings(:'pc', :'m_leaving'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(:'m_leaving')),
          'a caretaker who leaves is cleared, audited with them as actor');

select tests.authenticate_as(:'owner');
select public.set_caretaker(:'pc', :'m_deleted');
select tests.authenticate_as_service_role();
select public.admin_delete_account_data(:'m_deleted');
select is(tests.caretaker_clearings(:'pc', :'m_deleted'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(null)),
          'deleting the caretaker''s account clears it (no actor: the service role)');

select tests.authenticate_as(:'owner');
select public.set_caretaker(:'pc', :'m_auth');
select tests.clear_authentication();
delete from auth.users where id = :'m_auth';
select is(tests.caretaker_clearings(:'pc', :'m_auth'),
          jsonb_build_object('caretaker', null, 'since', null, 'cleared_by', jsonb_build_array(null)),
          'deleting the caretaker directly in Auth clears it, once');

select tests.authenticate_as(:'owner');
select public.set_caretaker(:'pc', :'m_kept');
select public.update_member_role(:'pc', :'m_kept', 'manager');
select is((select p.caretaker_user_id from public.portfolios p where p.id = :'pc'), :'m_kept'::uuid,
          'a role change from manager to manager keeps the caretaker');

-- ---------------------------------------------------------------------------
-- Deleting a portfolio with a caretaker
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
select tests.create_portfolio(:'owner', 'Residence D') as pd \gset
select tests.add_member(:'pd', :'manager', 'manager');
select tests.create_user('solo.res@example.com') as solo \gset
select tests.create_portfolio(:'solo', 'Residence E') as pe \gset
select tests.add_member(:'pe', :'manager', 'manager');

select tests.authenticate_as(:'owner');
select public.set_caretaker(:'pd', :'manager');
select lives_ok(format($$select public.delete_portfolio(%L, 'Residence D')$$, :'pd'),
                'a portfolio with a caretaker can be deleted');
select tests.authenticate_as(:'solo');
select public.set_caretaker(:'pe', :'manager');
select tests.authenticate_as_service_role();
select is(public.admin_delete_account_data(:'solo') -> 'deleted_portfolio_ids', jsonb_build_array(:'pe'),
          'deleting the sole owner''s account deletes their portfolio with its caretaker');
select tests.clear_authentication();
select is((select count(*)::integer from public.portfolios p where p.id in (:'pd', :'pe')), 0,
          'both portfolios are gone');

-- ---------------------------------------------------------------------------
-- The invariant (CaretakerIsManager; docs/operations.md, health checks)
-- ---------------------------------------------------------------------------

select is_empty(
  $$select p.id from public.portfolios p
    where p.caretaker_user_id is not null
      and not exists (select 1 from public.portfolio_members m
                      where m.portfolio_id = p.id and m.user_id = p.caretaker_user_id and m.role = 'manager')$$,
  'every caretaker is a manager of their portfolio'
);
select is(
  (select count(*)::integer from public.portfolios p
   where (p.caretaker_user_id is null) <> (p.caretaker_since is null)),
  0,
  'a portfolio has caretaker_since exactly when it has a caretaker'
);

select * from finish();
rollback;
