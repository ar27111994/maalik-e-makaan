-- ============================================================================
-- Residence, per person and per portfolio (D-16; decided by the owner on 11
-- and 12 November 2026; docs/roadmap/README.md, "Decision 1").
--
-- Per person, public.profile_residences: the country a person says they live
-- in and the time zone of their own alerts. Declared, never inferred: not
-- from a +92 number, the store country, an IP address, the app language or a
-- payment currency. Nationality and immigration status are never stored.
-- The row is readable and writable by its person only (not teammates, never
-- tenants), so it is a table of its own: profiles is readable by teammates,
-- and column grants are per role, not per row. It is never audited (the audit
-- trail is per portfolio and read by owners and managers), and it is cleared
-- when the account's deletion starts.
--
-- Per portfolio, three columns of public.portfolios:
--   owner_abroad       the answer to "Does the owner of these properties live
--                      abroad?". NULL means not yet answered. Every portfolio
--                      that exists when this migration runs is added as NULL,
--                      never a default and never filled from anyone's
--                      residence (the creator is often a caretaker or a
--                      relative); the app asks on the next open by an owner or
--                      manager. Portfolios made by app versions that do not ask
--                      are NULL too. The overseas-owner rules run only when it
--                      is true.
--   caretaker_user_id  always a member of the portfolio with the manager role
--                      (decided: the caretaker uses the app; there is no
--                      name-and-phone caretaker). Triggers keep it so for
--                      every writer, and clear it when that membership ends
--                      or stops being manager. It is independent of
--                      owner_abroad.
--   caretaker_since    when the current caretaker was named (set by trigger).
-- Every change of them is audited by portfolios_audit, with its actor. There
-- is no foreign key from the caretaker to portfolio_members: a second
-- relationship between portfolio_members and portfolios would make the
-- released app's unhinted embed portfolios!inner ambiguous (PGRST201);
-- 01_schema_security pins exactly one.
--
-- Amounts stay in rupees (no display_currency), and business time is
-- unchanged: ledger dates, due dates, police deadlines, the tax year and
-- every message to tenants stay on Pakistan time (app.today_pkt()). A
-- person's time zone serves only their own alerts, digests, quiet hours and
-- the second time of a dual time.
--
-- Lock order (account, portfolio, lease, other rows) of the new paths:
--   create_portfolio     unchanged (the account key, the new portfolio, its
--                        owner membership).
--   set_owner_abroad     the portfolio FOR NO KEY UPDATE, between two
--                        authorisations; members' key-share writes are not
--                        held up, membership changes and deletions wait.
--   set_caretaker        the portfolio FOR NO KEY UPDATE, then the
--                        caretaker's membership FOR SHARE (trigger), then the
--                        auth.users key (foreign key check).
--   membership changes   unchanged: the portfolio FOR UPDATE, the membership,
--                        then the portfolio row they already hold (trigger).
--   account deletion     unchanged, then the person's residence row last.
--   a residence UPDATE   that row only.
-- Two writers outside the app reach the portfolio row after the caretaker's
-- membership, the reverse order. A direct Auth delete of a caretaker: its
-- cascade takes the membership, then ON DELETE SET NULL of caretaker_user_id
-- (and the trigger) the portfolio. On a migrated database this is new: the
-- SET NULL of portfolios.created_by runs before the membership cascade. It
-- can deadlock with set_caretaker, update_member_role, remove_member
-- (leaving too) and the deletion of that portfolio (retried): run
-- admin_delete_account_data first. A service-role UPDATE or DELETE of the
-- caretaker's membership takes the portfolio in its trigger, and can
-- deadlock with update_member_role and remove_member: lock the portfolio
-- first (docs/operations.md; formal/tla/Membership, replay/residence.sh).
--
-- pgTAP: 01_schema_security, 03_rls_matrix and 22_residence. Existing rows:
-- tool/db/upgrade/20261112092618.*.sql.
-- ============================================================================

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- 1. Supported countries and time zones
-- ---------------------------------------------------------------------------

-- The ISO 3166-1 alpha-2 codes of the IANA tz database's iso3166.tab and the
-- zone names of its zone.tab (tzdata 2026f; 2026e has the same names), each
-- sorted by code point. Links (Asia/Calcutta), Etc/ zones and UTC are not
-- stored: a device's link name is mapped to its zone before it is saved.
-- Append-only: a new name is added by a later migration (no stored value can
-- become invalid), and a name that leaves zone.tab stays.
create function app.supported_country_codes()
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select array[
    'AD', 'AE', 'AF', 'AG', 'AI', 'AL', 'AM', 'AO', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AW', 'AX', 'AZ',
    'BA', 'BB', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BL', 'BM', 'BN', 'BO', 'BQ', 'BR', 'BS',
    'BT', 'BV', 'BW', 'BY', 'BZ', 'CA', 'CC', 'CD', 'CF', 'CG', 'CH', 'CI', 'CK', 'CL', 'CM', 'CN',
    'CO', 'CR', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ', 'DE', 'DJ', 'DK', 'DM', 'DO', 'DZ', 'EC', 'EE',
    'EG', 'EH', 'ER', 'ES', 'ET', 'FI', 'FJ', 'FK', 'FM', 'FO', 'FR', 'GA', 'GB', 'GD', 'GE', 'GF',
    'GG', 'GH', 'GI', 'GL', 'GM', 'GN', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GU', 'GW', 'GY', 'HK', 'HM',
    'HN', 'HR', 'HT', 'HU', 'ID', 'IE', 'IL', 'IM', 'IN', 'IO', 'IQ', 'IR', 'IS', 'IT', 'JE', 'JM',
    'JO', 'JP', 'KE', 'KG', 'KH', 'KI', 'KM', 'KN', 'KP', 'KR', 'KW', 'KY', 'KZ', 'LA', 'LB', 'LC',
    'LI', 'LK', 'LR', 'LS', 'LT', 'LU', 'LV', 'LY', 'MA', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MK',
    'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MU', 'MV', 'MW', 'MX', 'MY', 'MZ', 'NA',
    'NC', 'NE', 'NF', 'NG', 'NI', 'NL', 'NO', 'NP', 'NR', 'NU', 'NZ', 'OM', 'PA', 'PE', 'PF', 'PG',
    'PH', 'PK', 'PL', 'PM', 'PN', 'PR', 'PS', 'PT', 'PW', 'PY', 'QA', 'RE', 'RO', 'RS', 'RU', 'RW',
    'SA', 'SB', 'SC', 'SD', 'SE', 'SG', 'SH', 'SI', 'SJ', 'SK', 'SL', 'SM', 'SN', 'SO', 'SR', 'SS',
    'ST', 'SV', 'SX', 'SY', 'SZ', 'TC', 'TD', 'TF', 'TG', 'TH', 'TJ', 'TK', 'TL', 'TM', 'TN', 'TO',
    'TR', 'TT', 'TV', 'TW', 'TZ', 'UA', 'UG', 'UM', 'US', 'UY', 'UZ', 'VA', 'VC', 'VE', 'VG', 'VI',
    'VN', 'VU', 'WF', 'WS', 'YE', 'YT', 'ZA', 'ZM', 'ZW'
  ]::text[]
$$;

create function app.supported_time_zones()
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select array[
    'Africa/Abidjan', 'Africa/Accra', 'Africa/Addis_Ababa', 'Africa/Algiers', 'Africa/Asmara',
    'Africa/Bamako', 'Africa/Bangui', 'Africa/Banjul', 'Africa/Bissau', 'Africa/Blantyre',
    'Africa/Brazzaville', 'Africa/Bujumbura', 'Africa/Cairo', 'Africa/Casablanca', 'Africa/Ceuta',
    'Africa/Conakry', 'Africa/Dakar', 'Africa/Dar_es_Salaam', 'Africa/Djibouti', 'Africa/Douala',
    'Africa/El_Aaiun', 'Africa/Freetown', 'Africa/Gaborone', 'Africa/Harare', 'Africa/Johannesburg',
    'Africa/Juba', 'Africa/Kampala', 'Africa/Khartoum', 'Africa/Kigali', 'Africa/Kinshasa',
    'Africa/Lagos', 'Africa/Libreville', 'Africa/Lome', 'Africa/Luanda', 'Africa/Lubumbashi',
    'Africa/Lusaka', 'Africa/Malabo', 'Africa/Maputo', 'Africa/Maseru', 'Africa/Mbabane',
    'Africa/Mogadishu', 'Africa/Monrovia', 'Africa/Nairobi', 'Africa/Ndjamena', 'Africa/Niamey',
    'Africa/Nouakchott', 'Africa/Ouagadougou', 'Africa/Porto-Novo', 'Africa/Sao_Tome',
    'Africa/Tripoli', 'Africa/Tunis', 'Africa/Windhoek', 'America/Adak', 'America/Anchorage',
    'America/Anguilla', 'America/Antigua', 'America/Araguaina', 'America/Argentina/Buenos_Aires',
    'America/Argentina/Catamarca', 'America/Argentina/Cordoba', 'America/Argentina/Jujuy',
    'America/Argentina/La_Rioja', 'America/Argentina/Mendoza', 'America/Argentina/Rio_Gallegos',
    'America/Argentina/Salta', 'America/Argentina/San_Juan', 'America/Argentina/San_Luis',
    'America/Argentina/Tucuman', 'America/Argentina/Ushuaia', 'America/Aruba', 'America/Asuncion',
    'America/Atikokan', 'America/Bahia', 'America/Bahia_Banderas', 'America/Barbados',
    'America/Belem', 'America/Belize', 'America/Blanc-Sablon', 'America/Boa_Vista',
    'America/Bogota', 'America/Boise', 'America/Cambridge_Bay', 'America/Campo_Grande',
    'America/Cancun', 'America/Caracas', 'America/Cayenne', 'America/Cayman', 'America/Chicago',
    'America/Chihuahua', 'America/Ciudad_Juarez', 'America/Costa_Rica', 'America/Coyhaique',
    'America/Creston', 'America/Cuiaba', 'America/Curacao', 'America/Danmarkshavn',
    'America/Dawson', 'America/Dawson_Creek', 'America/Denver', 'America/Detroit',
    'America/Dominica', 'America/Edmonton', 'America/Eirunepe', 'America/El_Salvador',
    'America/Fort_Nelson', 'America/Fortaleza', 'America/Glace_Bay', 'America/Goose_Bay',
    'America/Grand_Turk', 'America/Grenada', 'America/Guadeloupe', 'America/Guatemala',
    'America/Guayaquil', 'America/Guyana', 'America/Halifax', 'America/Havana',
    'America/Hermosillo', 'America/Indiana/Indianapolis', 'America/Indiana/Knox',
    'America/Indiana/Marengo', 'America/Indiana/Petersburg', 'America/Indiana/Tell_City',
    'America/Indiana/Vevay', 'America/Indiana/Vincennes', 'America/Indiana/Winamac',
    'America/Inuvik', 'America/Iqaluit', 'America/Jamaica', 'America/Juneau',
    'America/Kentucky/Louisville', 'America/Kentucky/Monticello', 'America/Kralendijk',
    'America/La_Paz', 'America/Lima', 'America/Los_Angeles', 'America/Lower_Princes',
    'America/Maceio', 'America/Managua', 'America/Manaus', 'America/Marigot', 'America/Martinique',
    'America/Matamoros', 'America/Mazatlan', 'America/Menominee', 'America/Merida',
    'America/Metlakatla', 'America/Mexico_City', 'America/Miquelon', 'America/Moncton',
    'America/Monterrey', 'America/Montevideo', 'America/Montserrat', 'America/Nassau',
    'America/New_York', 'America/Nome', 'America/Noronha', 'America/North_Dakota/Beulah',
    'America/North_Dakota/Center', 'America/North_Dakota/New_Salem', 'America/Nuuk',
    'America/Ojinaga', 'America/Panama', 'America/Paramaribo', 'America/Phoenix',
    'America/Port-au-Prince', 'America/Port_of_Spain', 'America/Porto_Velho', 'America/Puerto_Rico',
    'America/Punta_Arenas', 'America/Rankin_Inlet', 'America/Recife', 'America/Regina',
    'America/Resolute', 'America/Rio_Branco', 'America/Santarem', 'America/Santiago',
    'America/Santo_Domingo', 'America/Sao_Paulo', 'America/Scoresbysund', 'America/Sitka',
    'America/St_Barthelemy', 'America/St_Johns', 'America/St_Kitts', 'America/St_Lucia',
    'America/St_Thomas', 'America/St_Vincent', 'America/Swift_Current', 'America/Tegucigalpa',
    'America/Thule', 'America/Tijuana', 'America/Toronto', 'America/Tortola', 'America/Vancouver',
    'America/Whitehorse', 'America/Winnipeg', 'America/Yakutat', 'Antarctica/Casey',
    'Antarctica/Davis', 'Antarctica/DumontDUrville', 'Antarctica/Macquarie', 'Antarctica/Mawson',
    'Antarctica/McMurdo', 'Antarctica/Palmer', 'Antarctica/Rothera', 'Antarctica/Syowa',
    'Antarctica/Troll', 'Antarctica/Vostok', 'Arctic/Longyearbyen', 'Asia/Aden', 'Asia/Almaty',
    'Asia/Amman', 'Asia/Anadyr', 'Asia/Aqtau', 'Asia/Aqtobe', 'Asia/Ashgabat', 'Asia/Atyrau',
    'Asia/Baghdad', 'Asia/Bahrain', 'Asia/Baku', 'Asia/Bangkok', 'Asia/Barnaul', 'Asia/Beirut',
    'Asia/Bishkek', 'Asia/Brunei', 'Asia/Chita', 'Asia/Colombo', 'Asia/Damascus', 'Asia/Dhaka',
    'Asia/Dili', 'Asia/Dubai', 'Asia/Dushanbe', 'Asia/Famagusta', 'Asia/Gaza', 'Asia/Hebron',
    'Asia/Ho_Chi_Minh', 'Asia/Hong_Kong', 'Asia/Hovd', 'Asia/Irkutsk', 'Asia/Jakarta',
    'Asia/Jayapura', 'Asia/Jerusalem', 'Asia/Kabul', 'Asia/Kamchatka', 'Asia/Karachi',
    'Asia/Kathmandu', 'Asia/Khandyga', 'Asia/Kolkata', 'Asia/Krasnoyarsk', 'Asia/Kuala_Lumpur',
    'Asia/Kuching', 'Asia/Kuwait', 'Asia/Macau', 'Asia/Magadan', 'Asia/Makassar', 'Asia/Manila',
    'Asia/Muscat', 'Asia/Nicosia', 'Asia/Novokuznetsk', 'Asia/Novosibirsk', 'Asia/Omsk',
    'Asia/Oral', 'Asia/Phnom_Penh', 'Asia/Pontianak', 'Asia/Pyongyang', 'Asia/Qatar',
    'Asia/Qostanay', 'Asia/Qyzylorda', 'Asia/Riyadh', 'Asia/Sakhalin', 'Asia/Samarkand',
    'Asia/Seoul', 'Asia/Shanghai', 'Asia/Singapore', 'Asia/Srednekolymsk', 'Asia/Taipei',
    'Asia/Tashkent', 'Asia/Tbilisi', 'Asia/Tehran', 'Asia/Thimphu', 'Asia/Tokyo', 'Asia/Tomsk',
    'Asia/Ulaanbaatar', 'Asia/Urumqi', 'Asia/Ust-Nera', 'Asia/Vientiane', 'Asia/Vladivostok',
    'Asia/Yakutsk', 'Asia/Yangon', 'Asia/Yekaterinburg', 'Asia/Yerevan', 'Atlantic/Azores',
    'Atlantic/Bermuda', 'Atlantic/Canary', 'Atlantic/Cape_Verde', 'Atlantic/Faroe',
    'Atlantic/Madeira', 'Atlantic/Reykjavik', 'Atlantic/South_Georgia', 'Atlantic/St_Helena',
    'Atlantic/Stanley', 'Australia/Adelaide', 'Australia/Brisbane', 'Australia/Broken_Hill',
    'Australia/Darwin', 'Australia/Eucla', 'Australia/Hobart', 'Australia/Lindeman',
    'Australia/Lord_Howe', 'Australia/Melbourne', 'Australia/Perth', 'Australia/Sydney',
    'Europe/Amsterdam', 'Europe/Andorra', 'Europe/Astrakhan', 'Europe/Athens', 'Europe/Belgrade',
    'Europe/Berlin', 'Europe/Bratislava', 'Europe/Brussels', 'Europe/Bucharest', 'Europe/Budapest',
    'Europe/Busingen', 'Europe/Chisinau', 'Europe/Copenhagen', 'Europe/Dublin', 'Europe/Gibraltar',
    'Europe/Guernsey', 'Europe/Helsinki', 'Europe/Isle_of_Man', 'Europe/Istanbul', 'Europe/Jersey',
    'Europe/Kaliningrad', 'Europe/Kirov', 'Europe/Kyiv', 'Europe/Lisbon', 'Europe/Ljubljana',
    'Europe/London', 'Europe/Luxembourg', 'Europe/Madrid', 'Europe/Malta', 'Europe/Mariehamn',
    'Europe/Minsk', 'Europe/Monaco', 'Europe/Moscow', 'Europe/Oslo', 'Europe/Paris',
    'Europe/Podgorica', 'Europe/Prague', 'Europe/Riga', 'Europe/Rome', 'Europe/Samara',
    'Europe/San_Marino', 'Europe/Sarajevo', 'Europe/Saratov', 'Europe/Simferopol', 'Europe/Skopje',
    'Europe/Sofia', 'Europe/Stockholm', 'Europe/Tallinn', 'Europe/Tirane', 'Europe/Ulyanovsk',
    'Europe/Vaduz', 'Europe/Vatican', 'Europe/Vienna', 'Europe/Vilnius', 'Europe/Volgograd',
    'Europe/Warsaw', 'Europe/Zagreb', 'Europe/Zurich', 'Indian/Antananarivo', 'Indian/Chagos',
    'Indian/Christmas', 'Indian/Cocos', 'Indian/Comoro', 'Indian/Kerguelen', 'Indian/Mahe',
    'Indian/Maldives', 'Indian/Mauritius', 'Indian/Mayotte', 'Indian/Reunion', 'Pacific/Apia',
    'Pacific/Auckland', 'Pacific/Bougainville', 'Pacific/Chatham', 'Pacific/Chuuk',
    'Pacific/Easter', 'Pacific/Efate', 'Pacific/Fakaofo', 'Pacific/Fiji', 'Pacific/Funafuti',
    'Pacific/Galapagos', 'Pacific/Gambier', 'Pacific/Guadalcanal', 'Pacific/Guam',
    'Pacific/Honolulu', 'Pacific/Kanton', 'Pacific/Kiritimati', 'Pacific/Kosrae',
    'Pacific/Kwajalein', 'Pacific/Majuro', 'Pacific/Marquesas', 'Pacific/Midway', 'Pacific/Nauru',
    'Pacific/Niue', 'Pacific/Norfolk', 'Pacific/Noumea', 'Pacific/Pago_Pago', 'Pacific/Palau',
    'Pacific/Pitcairn', 'Pacific/Pohnpei', 'Pacific/Port_Moresby', 'Pacific/Rarotonga',
    'Pacific/Saipan', 'Pacific/Tahiti', 'Pacific/Tarawa', 'Pacific/Tongatapu', 'Pacific/Wake',
    'Pacific/Wallis'
  ]::text[]
$$;

create function app.is_valid_country_code(p_code text)
returns boolean
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select p_code = any (app.supported_country_codes())
$$;

create function app.is_valid_time_zone(p_name text)
returns boolean
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select p_name = any (app.supported_time_zones())
$$;

comment on function app.is_valid_country_code(text) is
  'A stored country of residence: exactly one of app.supported_country_codes() (ISO 3166-1 alpha-2, '
  'upper case). NULL for NULL. Append-only: widen in a new migration, never remove.';
comment on function app.is_valid_time_zone(text) is
  'A stored time zone: exactly one of app.supported_time_zones() (IANA zone.tab names). NULL for NULL. '
  'Append-only: widen in a new migration, never remove.';

grant execute on function
  app.supported_country_codes(), app.supported_time_zones(),
  app.is_valid_country_code(text), app.is_valid_time_zone(text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Per person: public.profile_residences
-- ---------------------------------------------------------------------------

create table public.profile_residences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  residence_country text
    constraint profile_residences_residence_country_check
      check (app.is_valid_country_code(residence_country)),
  time_zone text
    constraint profile_residences_time_zone_check check (app.is_valid_time_zone(time_zone)),
  stated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profile_residences is
  'Where a person says they live and the time zone of their own alerts. Declared, never inferred (not from '
  'a +92 number, the store, an IP, the app language or a currency). Readable and writable by that person '
  'only: not teammates, never tenants. No nationality or immigration status. Never audited.';
comment on column public.profile_residences.residence_country is
  'ISO 3166-1 alpha-2 as declared; NULL = not stated.';
comment on column public.profile_residences.time_zone is
  'IANA zone for the person''s own alerts, digests, quiet hours and second time; NULL = Pakistan time. '
  'Never used for ledger dates, due dates, police deadlines, the tax year or messages to tenants.';
comment on column public.profile_residences.stated_at is
  'When the person last answered (set by trigger); NULL = never answered.';

create trigger profile_residences_touch_updated_at
  before update on public.profile_residences
  for each row execute function private.touch_updated_at();

-- A person's own write (a client's statement: current_user authenticated)
-- stamps stated_at, and is refused once their account's deletion has started
-- (account_deleted). admin_delete_account_data writes this row last, so an
-- UPDATE that arrives while it runs waits for its row lock, and this trigger
-- then reads the committed deletion. Every other writer (that function, the
-- service role, the seed) keeps the values it sets. The trigger takes no
-- lock: a client UPDATE holds only this row, so there is no cycle.
create function private.before_profile_residence_client_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from private.account_deletions d where d.user_id = new.user_id) then
    perform app.fail('account_deleted');
  end if;
  new.stated_at := now();
  return new;
end
$$;

create trigger profile_residences_before_client_update
  before update on public.profile_residences
  for each row
  when (current_user = 'authenticated')
  execute function private.before_profile_residence_client_update();

-- Every profile has its row (nothing stated); clients only ever UPDATE it.
create function private.after_profile_insert_residence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profile_residences (user_id) values (new.id) on conflict (user_id) do nothing;
  return null;
end
$$;

create trigger profiles_after_insert_residence
  after insert on public.profiles
  for each row execute function private.after_profile_insert_residence();

revoke all on function
  private.before_profile_residence_client_update(), private.after_profile_insert_residence()
  from public, anon, authenticated;

-- Existing profiles: one empty row each. CREATE TRIGGER above holds SHARE ROW
-- EXCLUSIVE on profiles until commit, so no sign-up slips in between.
insert into public.profile_residences (user_id)
select p.id from public.profiles p
on conflict (user_id) do nothing;

alter table public.profile_residences enable row level security;

create policy profile_residences_select_own on public.profile_residences
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy profile_residences_update_own on public.profile_residences
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Defensive against platform defaults; stated_at is the trigger's.
revoke all on public.profile_residences from anon, authenticated;
grant select on public.profile_residences to authenticated;
grant update (residence_country, time_zone) on public.profile_residences to authenticated;
grant select, insert, update, delete on public.profile_residences to service_role;

-- ---------------------------------------------------------------------------
-- 3. Per portfolio: the owner-abroad answer and the caretaker
-- ---------------------------------------------------------------------------

alter table public.portfolios
  add column owner_abroad boolean,
  add column caretaker_user_id uuid,
  add column caretaker_since timestamptz,
  -- The columns are new and NULL in every row, so the check refuses nothing,
  -- and ADD COLUMN already holds ACCESS EXCLUSIVE on this small table.
  -- squawk-ignore constraint-missing-not-valid
  add constraint portfolios_caretaker_since_check
    check ((caretaker_user_id is null) = (caretaker_since is null)),
  -- The same: nothing to validate. SHARE ROW EXCLUSIVE on auth.users for an
  -- instant (sign-ins that update it wait; lock_timeout 5 s).
  -- squawk-ignore adding-foreign-key-constraint, constraint-missing-not-valid
  add constraint portfolios_caretaker_user_id_fkey
    foreign key (caretaker_user_id) references auth.users (id) on delete set null;

comment on column public.portfolios.owner_abroad is
  'Answer to "Does the owner of these properties live abroad?". NULL = not yet answered (every portfolio '
  'that existed before 20261112092618_residence.sql, and those made by app versions that do not ask); '
  'never a default, never filled from anyone''s residence. Overseas-owner rules run only when true.';
comment on column public.portfolios.caretaker_user_id is
  'The caretaker: always a member of this portfolio with the manager role. Cleared by '
  'portfolio_members_after_caretaker_ends when that stops being true. There is no name-and-phone caretaker.';
comment on column public.portfolios.caretaker_since is
  'When the current caretaker was named (set by trigger).';

-- Backs the foreign key (01_schema_security) and its ON DELETE SET NULL. The
-- index is empty when built, and CONCURRENTLY cannot run in the migration's
-- transaction.
-- squawk-ignore require-concurrent-index-creation
create index portfolios_caretaker_user_id_idx
  on public.portfolios (caretaker_user_id)
  where caretaker_user_id is not null;

-- Keeps the caretaker a manager of the portfolio, whoever writes the column
-- (set_caretaker, the service role, the foreign key's SET NULL), and owns
-- caretaker_since. The membership is read FOR SHARE, after the portfolio row
-- (the global order): a role change in flight is waited for and its result
-- read, so a service-role role change cannot slip a non-manager in.
create function private.before_portfolio_caretaker_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.caretaker_user_id is not distinct from old.caretaker_user_id then
    new.caretaker_since := old.caretaker_since;
    return new;
  end if;
  if new.caretaker_user_id is null then
    new.caretaker_since := null;
    return new;
  end if;
  perform 1
  from public.portfolio_members m
  where m.portfolio_id = new.id and m.user_id = new.caretaker_user_id and m.role = 'manager'
  for share;
  if not found then
    perform app.fail('caretaker_not_manager');
  end if;
  new.caretaker_since := now();
  return new;
end
$$;

create trigger portfolios_before_caretaker_change
  before insert or update of caretaker_user_id, caretaker_since on public.portfolios
  for each row execute function private.before_portfolio_caretaker_change();

-- Clears the caretaker when their membership ends or stops being manager:
-- update_member_role, remove_member (removed or leaving),
-- admin_delete_account_data, the cascade of an Auth delete. During the
-- portfolio's own deletion its row is already gone and nothing is updated.
-- The RPCs already hold the portfolio FOR UPDATE; portfolios_audit records
-- the change with the actor.
create function private.after_caretaker_membership_ends()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.role = 'manager'
     and new.portfolio_id = old.portfolio_id and new.user_id = old.user_id then
    return null;
  end if;
  update public.portfolios p
  set caretaker_user_id = null
  where p.id = old.portfolio_id and p.caretaker_user_id = old.user_id;
  return null;
end
$$;

create trigger portfolio_members_after_caretaker_ends
  after update of role, portfolio_id, user_id or delete on public.portfolio_members
  for each row
  when (old.role = 'manager')
  execute function private.after_caretaker_membership_ends();

revoke all on function
  private.before_portfolio_caretaker_change(), private.after_caretaker_membership_ends()
  from public, anon, authenticated;

-- No column grant: an owner's direct UPDATE of these columns is refused
-- (42501); the RPCs below are the only client path. Every member reads them.

-- ---------------------------------------------------------------------------
-- 4. RPCs
-- ---------------------------------------------------------------------------

-- Replaced by the three-argument form below, which every existing call (named
-- {p_name, p_id} or {p_name}, or positional) still reaches through its
-- defaults. An overload instead would make those calls ambiguous (PGRST203).
-- squawk-ignore ban-drop-function
drop function public.create_portfolio(text, uuid);

-- Creates a portfolio with the caller as owner (the body of
-- 20261105072426_membership_deletion_storage.sql, plus the answer).
-- Idempotent for a client-supplied id: the creator's offline retry gets the
-- portfolio back, unchanged, but only while the creator still belongs to it.
-- A deleted portfolio's id is refused like another user's. At most 20 owned
-- portfolios per user. p_owner_abroad is the creator's answer to "Does the
-- owner of these properties live abroad?"; NULL (no answer, or an app
-- version that does not ask) is stored as not yet answered. It is never read
-- from the creator's residence.
create function public.create_portfolio(
  p_name text,
  p_id uuid default null,
  p_owner_abroad boolean default null
)
returns public.portfolios
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_portfolio public.portfolios;
begin
  if v_uid is null then
    perform app.forbid();
  end if;
  perform private.require_active_account(v_uid);

  if p_id is not null then
    select p.* into v_portfolio from public.portfolios p where p.id = p_id;
    if found then
      if v_portfolio.created_by is distinct from v_uid or not app.has_portfolio_role(p_id, null) then
        perform app.forbid();
      end if;
      return v_portfolio;
    end if;
    -- Refused before the rate limit: probing costs the caller nothing, but
    -- tells them nothing either (the same error as another user's id).
    if exists (select 1 from private.portfolio_ids r where r.id = p_id) then
      perform app.forbid();
    end if;
  end if;

  perform private.enforce_rate_limit('create_portfolio', 10, interval '1 hour');

  if (
    select count(*) from public.portfolio_members m
    where m.user_id = v_uid and m.role = 'owner'
  ) >= 20 then
    perform app.fail('portfolio_limit_reached');
  end if;

  insert into public.portfolios (id, name, created_by, owner_abroad)
  values (coalesce(p_id, app.uuid_generate_v7()), btrim(p_name), v_uid, p_owner_abroad)
  returning * into v_portfolio;

  insert into public.portfolio_members (portfolio_id, user_id, role)
  values (v_portfolio.id, v_uid, 'owner');

  return v_portfolio;
end
$$;

revoke all on function public.create_portfolio(text, uuid, boolean) from public, anon;
grant execute on function public.create_portfolio(text, uuid, boolean) to authenticated;

-- Answers "Does the owner of these properties live abroad?" and returns the
-- stored answer. While it is unanswered, owners and managers may answer (the
-- app asks the first of them to open the portfolio); once answered, only
-- owners change it, and the same answer again changes nothing (a retry after
-- a lost response; no audit row). With p_if_unanswered (the "ask on the next
-- open" flow), an answer someone already gave is returned and kept, so a
-- second device's or a second owner's stale question never overwrites it. An
-- answer cannot be taken back to NULL. Locks: authorise, the portfolio FOR
-- NO KEY UPDATE (members' key-share writes go on; membership changes and
-- deletions, FOR UPDATE, wait), authorise again.
create function public.set_owner_abroad(
  p_portfolio_id uuid,
  p_owner_abroad boolean,
  p_if_unanswered boolean default false
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_roles constant public.member_role[] := array['owner', 'manager']::public.member_role[];
  v_current boolean;
begin
  if p_owner_abroad is null or p_if_unanswered is null then
    perform app.fail('invalid_owner_abroad');
  end if;
  perform app.require_portfolio_role(p_portfolio_id, v_roles);
  select p.owner_abroad into v_current
  from public.portfolios p
  where p.id = p_portfolio_id
  for no key update;
  perform app.require_portfolio_role(p_portfolio_id, v_roles);

  if v_current is not distinct from p_owner_abroad or (v_current is not null and p_if_unanswered) then
    return v_current;
  end if;
  if v_current is not null
     and not app.has_portfolio_role(p_portfolio_id, array['owner']::public.member_role[]) then
    perform app.fail('owner_abroad_answered');
  end if;

  update public.portfolios p set owner_abroad = p_owner_abroad where p.id = p_portfolio_id;
  return p_owner_abroad;
end
$$;

-- Names a manager of the portfolio as its caretaker, or clears it (NULL).
-- Owners only. Naming the current caretaker again changes nothing
-- (caretaker_since stays; no audit row). The trigger checks the role again,
-- for every writer. Locks: authorise, the portfolio FOR NO KEY UPDATE,
-- authorise again, then the membership FOR SHARE (trigger), then the
-- auth.users key (foreign key check).
create function public.set_caretaker(p_portfolio_id uuid, p_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_roles constant public.member_role[] := array['owner']::public.member_role[];
  v_role public.member_role;
begin
  perform app.require_portfolio_role(p_portfolio_id, v_roles);
  perform 1 from public.portfolios p where p.id = p_portfolio_id for no key update;
  perform app.require_portfolio_role(p_portfolio_id, v_roles);

  if p_user_id is not null then
    select m.role into v_role
    from public.portfolio_members m
    where m.portfolio_id = p_portfolio_id and m.user_id = p_user_id;
    if not found then
      perform app.fail('member_not_found');
    end if;
    if v_role <> 'manager' then
      perform app.fail('caretaker_not_manager');
    end if;
  end if;

  update public.portfolios p
  set caretaker_user_id = p_user_id
  where p.id = p_portfolio_id and p.caretaker_user_id is distinct from p_user_id;
end
$$;

revoke all on function
  public.set_owner_abroad(uuid, boolean, boolean), public.set_caretaker(uuid, uuid)
  from public, anon;
grant execute on function
  public.set_owner_abroad(uuid, boolean, boolean), public.set_caretaker(uuid, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Account deletion clears the declared residence
-- ---------------------------------------------------------------------------

-- The body of 20261105072426_membership_deletion_storage.sql; only the end
-- changes. CREATE OR REPLACE keeps its owner and privileges. The membership
-- deletes in its loop now also clear the person's caretaker designations on
-- the portfolios that survive (portfolio_members_after_caretaker_ends, under
-- the portfolio locks it already holds; audited with actor NULL from the
-- service role). The declared residence goes when the deletion starts; the
-- row itself goes with the profile when the Auth user is deleted.
--
-- Deletes the user's sole-owned portfolios (cascading to all their data) and
-- removes the user from every other portfolio. Returns the deleted ids.
-- First the account is frozen: its profile is locked and the deletion
-- recorded, so the user's other devices can neither create a portfolio nor
-- accept an invitation from now on. Then every portfolio the user belongs to
-- is locked, and only then is it decided which portfolios die with the
-- account: a co-owner deleting their account at the same moment waits, then
-- sees this user gone and deletes the portfolio they now own alone, instead
-- of both leaving and orphaning it. Retried like delete_portfolio.
create or replace function public.admin_delete_account_data(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_memberships uuid[];
  v_deleted uuid[];
  v_attempt integer := 0;
begin
  if p_user_id is null then
    perform app.fail('invalid_user');
  end if;

  perform 1 from public.profiles p where p.id = p_user_id for update;
  insert into private.account_deletions (user_id)
  select p_user_id
  where exists (select 1 from auth.users u where u.id = p_user_id)
  on conflict (user_id) do nothing;

  loop
    v_attempt := v_attempt + 1;
    begin
      select coalesce(array_agg(m.portfolio_id order by m.portfolio_id), '{}'::uuid[]) into v_memberships
      from public.portfolio_members m
      where m.user_id = p_user_id;
      perform private.lock_portfolios_for_deletion(v_memberships);

      select coalesce(array_agg(s.portfolio_id order by s.portfolio_id), '{}'::uuid[]) into v_deleted
      from public.admin_account_deletion_scope(p_user_id) s
      where s.portfolio_id = any (v_memberships);

      perform private.delete_locked_portfolios(v_deleted);
      delete from public.portfolio_members m
      where m.user_id = p_user_id and m.portfolio_id = any (v_memberships);
      exit;
    exception when deadlock_detected then
      if v_attempt >= 3 then
        raise;
      end if;
    end;
  end loop;

  delete from public.notifications n where n.user_id = p_user_id;
  -- The declared residence, taken last (other rows). The row is written even
  -- when nothing is stated: a filter on the values would skip a row whose
  -- person's UPDATE is still in flight (it reads the old values without
  -- waiting), and that UPDATE would then survive. Written, the row lock
  -- waits for such an UPDATE and clears what it committed, and an UPDATE
  -- that arrives later waits for this transaction and is then refused
  -- (account_deleted).
  update public.profile_residences r
  set residence_country = null, time_zone = null, stated_at = null
  where r.user_id = p_user_id;
  return jsonb_build_object('deleted_portfolio_ids', to_jsonb(v_deleted));
end
$$;
