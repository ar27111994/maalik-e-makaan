# Time

The app runs on two clocks. Business time is Pakistan's, for everyone. A person's own time zone
serves only what that person reads about their own day. This page says which is which, how the
second is computed, and how its data is kept current. The owner's decision is D-16
([roadmap, decision 1](../roadmap/README.md#decision-1-residence-per-person-and-per-portfolio-d-16)).

## Two clocks

**Pakistan time** (UTC+05:00 all year, no daylight saving since 2009) decides:

- ledger dates, due dates and late fees, billing months and "today"
  (`app.today_pkt()` in SQL; `CalendarDate.todayInPakistan` and `pakistanUtcOffset` in
  [`calendar_date.dart`](../../packages/mm_core/lib/src/time/calendar_date.dart));
- police-registration deadlines and the tax year (1 July to 30 June);
- every message to tenants, and when not to send one (the reminders' late-night and Friday-prayer
  etiquette in `reminders.dart`).

**A person's own zone** (`profile_residences.time_zone`, which the person declares; NULL is
Pakistan time) decides only:

- when their own alerts and digests go out, and their quiet hours;
- the second time an owner abroad sees beside Pakistan's: "3:15 pm in Lahore (10:15 am in London)"
  (`DualTime`).

`Residence.alertZone` gives the zone to use: the stated one when this build knows it, otherwise
Pakistan's. The app reads it through `alertZoneProvider`, which falls back to Pakistan time when
nobody is signed in or the residence is loading, unreadable or not stated. Nothing derives a zone
from a phone number, the store, an IP address, the app's language or a currency; the device's zone
may only pre-fill a suggestion (`TimeZoneId.fromDevice`).

`pakistan_time_guard_test.dart` fails if the rent, ledger or business-date files of `mm_core`
import the time-zone code.

## Stored names

A person stores an ISO 3166-1 alpha-2 country from the tz database's `iso3166.tab` and a zone name
from its `zone.tab` (249 countries and 418 zones in tzdata 2026f). Links such as `Asia/Calcutta`,
`US/Eastern` or `GB`, and `UTC` or `Etc/GMT+5`, are not stored: a device that reports one is
offered the zone it links to. A `zone.tab` name that tzdata also lists as a link is kept as it is
(`Asia/Kuwait` stays `Asia/Kuwait`, not `Asia/Riyadh`).

The database accepts exactly these names (`app.supported_country_codes()`,
`app.supported_time_zones()`, checked by `app.is_valid_country_code` and `app.is_valid_time_zone`),
and suite 23 asserts that they equal `contracts/residence_vectors.json`. The lists are
**append-only**: a new name is added by a migration that widens the list, which needs no
revalidation; a name that leaves `zone.tab` stays, listed in `RETAINED_ZONES` in
`tool/contracts/time_zones.py` with the zone it now links to. The generator refuses to drop a name
the committed vectors list.

The app reads a stored value leniently: a well-formed name it does not know (a newer build stored
it) is kept with `isKnown` false, and that person's alerts use Pakistan time. Input is strict:
`CountryCode.parse` and `TimeZoneId.parse` take only supported names.

## The rules

**Local time to an instant.** A local time a clock change skips (spring forward) or repeats (fall
back) is read as the later of its two instants. This is what PostgreSQL's
`timestamp at time zone` does, so the app and the database agree: 01:30 on the day London's clocks
go forward is 01:30 UTC (02:30 BST), and on the day they go back, the second 01:30 (01:30 UTC).
`TimeZoneId.instantAt` takes the offsets a day either side of the wall time; two candidates that
read back mean a repeated time (the later wins), none a skipped one (the offset before the change
gives the later). It relies on clock changes at least two days apart, which the generator asserts
(the closest are 6.96 days apart, in `Asia/Gaza`).

**Quiet hours** are `[start, end)` on the person's wall clock, across midnight when start is later
than end. Equal times are refused (all day or never?), and a person without quiet hours has no
`QuietHours` at all; there is no default window in `mm_core`. An alert due in quiet hours is
released at the first later instant the wall clock is outside them: usually `end`, sooner when a
clock change jumps past `end` (London 22:00 to 01:30 on the spring night: released at 01:00 UTC,
when the clock jumps from 01:00 to 02:00), and later when the clock goes back into them (on the
autumn night the repeated hour is quiet again, until the second 01:30).

**The next send time.** `TimeZoneId.nextAt` gives the first instant strictly after a moment at
which the zone's clock reads a time, on a weekday when one is given, following the rule above for
a skipped or repeated time.

**Dual time.** `DualTime.at` shows an instant in Pakistan and in the person's zone, and shows it
once when the two clocks read the same (an owner in Pakistan, or in Tashkent, also UTC+05:00).

`contracts/time_zone_vectors.json` holds the cases for every rule: offsets either side of every
clock change from 2026 to 2028 of 26 zones where owners live or whose changes are unusual (half-
and quarter-hour offsets, Lord Howe's half-hour change, Dublin's negative daylight saving,
Casablanca's changes around Ramadan), skipped and repeated local times, quiet hours, next send
times and dual times. mm_core's contract tests run all of them. Suite 23 runs the offset and
local-time rows marked `pg` against PostgreSQL; Casablanca's are Dart-only, because Morocco sets its
changes by decree year by year and two servers' tzdata may differ.

## The bundled data

`mm_core` carries its own tz data, so an owner's alert time does not depend on the phone's
database: `lib/src/time/time_zone_data.g.dart`, generated by `make contracts` from the PyPI
`tzdata` package pinned with its hash in `tool/requirements.txt` (2026.6, IANA 2026f), never from
the system's zoneinfo. It holds each zone's offsets from 2020-01-01 to 2100-01-01 UTC as 85
distinct schedules with 5,294 clock changes; before 2020 a zone keeps its 2020 offset, from 2100 its
last. `tool/contracts/time_zones.py` reads the transitions listed in each TZif file and scans the
years after them, where the file's footer rule applies, a day at a time, bisecting each change to
the second; its tests compare the result with a six-hour scan and with Python's `zoneinfo` at random
instants.

**The Pakistan tripwire.** The generator fails if `Asia/Karachi` stops being UTC+05:00 all year,
and mm_core's tests check that `TimeZoneId.pakistan` agrees with `pakistanUtcOffset` on 1 January
and 1 July of every year to 2099 and with `CalendarDate.todayInPakistan`. Should Pakistan ever
adopt daylight saving again, business time would need its own change: `app.today_pkt()`,
`pakistanUtcOffset` and the reminders' etiquette.

## Keeping it current

The procedure is in [operations](../operations.md#time-zone-data): bump `tzdata`, run
`make contracts`, add a migration first when a zone was added, then release the app. The server
keeps its own tz data (PostgreSQL's, from the Supabase image), so after each Supabase Postgres
upgrade or `tzdata` bump, run `tool/db/time_zone_skew.sql` on the hosted project: it lists every
stored zone and instant (1 January and 1 July 2026 to 2030, and each clock change from 2026 to 2028)
where the server's offset differs from the bundled one. It is not run in CI, where PostgreSQL 16
and the Supabase image each bring their own tz data. On this machine (PostgreSQL 16 with the
system's tzdata 2026e) it returns one row: `America/Havana` on 1 January 2027, because 2026f keeps
Cuba on daylight saving time from March 2026 to November 2027.
