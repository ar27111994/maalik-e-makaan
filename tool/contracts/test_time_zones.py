"""Tests of the time-zone reference behind the residence and time-zone contracts.

    python3 -m unittest discover -s tool/contracts -p 'test_*.py'

The reference must read a local time a clock change skips or repeats as
PostgreSQL does (the results below were taken from PostgreSQL 16 and agree
with suite 23 on every stable zone), and the schedules bundled in mm_core
must give the same offsets as the standard library's zoneinfo.
"""

from __future__ import annotations

import random
import sys
import unittest
from unittest import mock

import generate
import time_zones as tz

# (zone, local time, the instant PostgreSQL gives, kind)
POSTGRESQL = [
    ("Europe/London", "2027-03-28T01:30:00", "2027-03-28T01:30:00Z", "gap"),
    ("Europe/London", "2027-10-31T01:30:00", "2027-10-31T01:30:00Z", "overlap"),
    ("America/New_York", "2027-03-14T02:30:00", "2027-03-14T07:30:00Z", "gap"),
    ("America/New_York", "2027-11-07T01:30:00", "2027-11-07T06:30:00Z", "overlap"),
    ("Australia/Lord_Howe", "2026-10-04T02:15:00", "2026-10-03T15:45:00Z", "gap"),
    ("Australia/Lord_Howe", "2026-04-05T01:45:00", "2026-04-04T15:15:00Z", "overlap"),
    ("Europe/Dublin", "2026-10-25T01:30:00", "2026-10-25T01:30:00Z", "overlap"),
    ("Asia/Karachi", "2026-11-12T15:15:00", "2026-11-12T10:15:00Z", "normal"),
]


def naive_schedule(zone: str) -> tz.Schedule:
    """Every change of offset found by stepping six hours at a time and bisecting."""
    found = []
    previous = tz.offset_at(zone, tz.FROM)
    for step in range(tz.FROM + 21600, tz.UNTIL, 21600):
        current = tz.offset_at(zone, step)
        if current != previous:
            low, high = step - 21600, step
            while high - low > 1:
                middle = (low + high) // 2
                if tz.offset_at(zone, middle) == current:
                    high = middle
                else:
                    low = middle
            found.append((high, current))
            previous = current
    return tz.Schedule(tz.offset_at(zone, tz.FROM), tuple(found))


class ReferenceTest(unittest.TestCase):
    def test_tzdata_is_the_pinned_release(self):
        self.assertEqual(tz.iana_version(), "2026f")

    def test_local_times_resolve_as_postgresql_does(self):
        for zone, wall, instant, kind in POSTGRESQL:
            with self.subTest(zone=zone, wall=wall):
                self.assertEqual(tz.local_to_instant(zone, wall), (tz.parse_utc(instant), kind))

    def test_the_fast_schedule_equals_a_six_hour_scan(self):
        for zone in [
            "Europe/London",
            "America/New_York",
            "Australia/Lord_Howe",
            "Africa/Casablanca",
            "Asia/Gaza",
            "America/Santiago",
            "Asia/Karachi",
        ]:
            with self.subTest(zone=zone):
                self.assertEqual(tz.schedule(zone), naive_schedule(zone))

    def test_schedules_give_zoneinfos_offsets(self):
        rng = random.Random(16)  # noqa: S311 (sample instants, not secrets)
        for zone in tz.allowed_zones():
            schedule = tz.schedule(zone)
            instants = [rng.randrange(tz.FROM, tz.UNTIL) for _ in range(40)]
            for at, _ in schedule.transitions:
                instants += [at - 1, at]
            for instant in instants:
                self.assertEqual(
                    schedule.offset_at(instant), tz.offset_at(zone, instant), (zone, instant)
                )

    def test_pakistan_is_utc_plus_five_all_year(self):
        self.assertEqual(tz.schedule(tz.PAKISTAN), tz.Schedule(18000, ()))

    def test_the_lists(self):
        self.assertEqual(len(tz.countries()), 249)
        self.assertEqual(len(tz.allowed_zones()), 418)
        self.assertEqual(tz.allowed_zones(), sorted(tz.allowed_zones()))
        self.assertEqual(tz.country_zones()["PK"], ["Asia/Karachi"])
        self.assertEqual(tz.country_zones()["BV"], [])
        self.assertEqual(tz.zone_countries()["Asia/Kuwait"], "KW")

    def test_device_links(self):
        links = tz.device_links()
        self.assertEqual(links["Asia/Calcutta"], "Asia/Kolkata")
        self.assertEqual(links["GB"], "Europe/London")
        # A stored name is offered as itself, even when tzdata.zi links it.
        self.assertEqual(tz.links()["Asia/Kuwait"], "Asia/Riyadh")
        self.assertNotIn("Asia/Kuwait", links)
        # A link to a name that is not stored is not offered.
        self.assertNotIn("UTC", links)

    def test_quiet_hours_release_at_the_first_instant_outside(self):
        london, start, end = "Europe/London", 22 * 60, 90  # 22:00 to 01:30
        # Spring: 01:30 is skipped; the clock jumps from 01:00 to 02:00.
        spring = tz.parse_utc("2027-03-28T00:50:00Z")
        self.assertEqual(tz.release_at(start, end, london, spring), spring + 600)
        # Autumn: the first 01:30 ends them, the repeated hour starts them again.
        autumn = tz.parse_utc("2027-10-31T00:20:00Z")
        self.assertEqual(tz.release_at(start, end, london, autumn), autumn + 600)
        self.assertFalse(tz.is_quiet(start, end, london, autumn + 1200))
        self.assertTrue(tz.is_quiet(start, end, london, autumn + 2700))
        # Outside them, the instant itself.
        noon = tz.parse_utc("2026-11-12T12:00:00Z")
        self.assertEqual(tz.release_at(start, end, london, noon), noon)
        # A window within the day: 13:00 in Dubai is 09:00 UTC; 14:00 is past it.
        self.assertTrue(tz.is_quiet(13 * 60, 14 * 60, "Asia/Dubai", noon - 3 * 3600))
        self.assertFalse(tz.is_quiet(13 * 60, 14 * 60, "Asia/Dubai", noon - 2 * 3600))

    def test_next_at_is_strictly_later(self):
        after = tz.parse_utc("2026-11-12T08:00:00Z")
        self.assertEqual(tz.next_at("Europe/London", 8 * 60, None, after), after + 86400)
        self.assertEqual(tz.next_at("Europe/London", 8 * 60, None, after - 1), after)
        # Monday 16 November.
        self.assertEqual(
            tz.next_at("Europe/London", 9 * 60, 1, after), tz.parse_utc("2026-11-16T09:00:00Z")
        )


class TzifTest(unittest.TestCase):
    def test_reads_transitions_and_footer(self):
        data = tz._resource("Europe", "London").read_bytes()
        times, footer = tz.read_tzif(data)
        self.assertEqual(footer, "GMT0BST,M3.5.0/1,M10.5.0")
        self.assertEqual(times, sorted(times))

    def test_refuses_other_files(self):
        with self.assertRaises(ValueError):
            tz.read_tzif(b"not a zone file")
        with self.assertRaises(ValueError):
            tz.read_tzif(b"TZif\x00" + bytes(39))
        data = tz._resource("Europe", "London").read_bytes()
        with self.assertRaises(ValueError):
            tz.read_tzif(data.rstrip(b"\n"))

    def test_missing_package_says_how_to_install_it(self):
        with (
            mock.patch.dict(sys.modules, {"tzdata": None}),
            self.assertRaises(tz.MissingTzdataError) as raised,
        ):
            tz._package()
        self.assertIn("tool/requirements.txt", str(raised.exception))


class GeneratorTest(unittest.TestCase):
    def test_the_data_passes_the_generators_assertions(self):
        generate.check_time_zone_data()

    def test_stored_names_are_append_only(self):
        current = generate.build_residence()
        generate.check_append_only(current)
        dropped = {
            **current,
            "timeZones": [*current["timeZones"], {"name": "Asia/Old", "country": "PK"}],
        }
        with self.assertRaisesRegex(ValueError, "Asia/Old"):
            generate.check_append_only(dropped)
        dropped = {**current, "countries": [*current["countries"], {"code": "AN", "zones": []}]}
        with self.assertRaisesRegex(ValueError, "AN"):
            generate.check_append_only(dropped)

    def test_the_sql_lists_match_the_migration(self):
        migration = (
            generate.ROOT / "supabase" / "migrations" / "20261112092618_residence.sql"
        ).read_text(encoding="utf-8")
        lists = generate.render_sql_lists(generate.build_residence())
        for block in lists.strip().split("\n\n"):
            self.assertIn(block.split("\n", 1)[1], migration)

    def test_the_vectors_cover_both_kinds_of_change(self):
        vectors = generate.build_time_zone_vectors()
        kinds = {v["kind"] for v in vectors["localToInstant"]}
        self.assertEqual(kinds, {"normal", "gap", "overlap"})
        self.assertTrue(any(not v["pg"] for v in vectors["offsets"]))
        london = next(v for v in vectors["dualTime"] if v["zone"] == "Europe/London")
        self.assertEqual((london["pakistan"][11:16], london["own"][11:16]), ("15:15", "10:15"))


if __name__ == "__main__":
    unittest.main()
