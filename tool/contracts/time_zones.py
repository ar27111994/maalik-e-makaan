"""The IANA time-zone data behind the residence and time-zone contracts.

Read from the tzdata package on PyPI, pinned with its hash in
tool/requirements.txt, never from the system's zoneinfo: the vectors, the
Dart data bundled in mm_core and the lists in the database must not change
with the machine that runs the generator.

What it gives generate.py:
  * the countries of iso3166.tab and the zones of zone.tab (the names a
    person may store), with each zone's country;
  * the links of tzdata.zi (the names a device may report, such as
    Asia/Calcutta), mapped to a stored name;
  * each stored zone's UTC offsets from 2020 to 2100, as a schedule of
    transitions (FROM and UNTIL below);
  * the reference rules the Dart and SQL code are checked against: a local
    time a clock change skips or repeats is read as the later of its two
    instants (PostgreSQL's rule), and quiet hours end at the first instant
    the wall clock is outside them.

Offsets come from the standard library's zoneinfo, which reads the same
package. The TZif files are parsed here only to find the transitions they
list; after the last listed one, a zone with daylight saving follows the
rule in its footer, and that stretch is scanned a day at a time and bisected
to the second (a footer rule changes the clock twice a year, months apart).
"""

from __future__ import annotations

import bisect
import hashlib
import importlib.resources
import struct
import zoneinfo
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import cache

# The bundled offsets cover [FROM, UNTIL): 2020-01-01 to 2100-01-01, UTC.
FROM = 1577836800
UNTIL = 4102444800
DAY = 86400
# Two clock changes of one zone are never closer than this. mm_core's
# TimeZoneId.instantAt relies on it (it looks a day either side).
MIN_SPACING = 2 * DAY

PAKISTAN = "Asia/Karachi"

# Names that left zone.tab in a tzdata release, kept as stored names (the
# lists are append-only), each with the zone it now links to; and codes that
# left iso3166.tab, with their names. Empty today.
RETAINED_ZONES: dict[str, str] = {}
RETAINED_COUNTRIES: dict[str, str] = {}

# The zones the conversion vectors cover: where owners abroad live, and
# zones whose clock changes are unusual.
VECTOR_ZONES = (
    "Europe/London",
    "Europe/Dublin",
    "Europe/Berlin",
    "Europe/Paris",
    "Europe/Athens",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Phoenix",
    "America/Los_Angeles",
    "America/Toronto",
    "America/St_Johns",
    "Asia/Dubai",
    "Asia/Riyadh",
    "Asia/Qatar",
    "Asia/Kuwait",
    "Asia/Bahrain",
    "Asia/Muscat",
    "Asia/Karachi",
    "Asia/Kolkata",
    "Asia/Kathmandu",
    "Asia/Tashkent",
    "Australia/Sydney",
    "Australia/Lord_Howe",
    "Pacific/Auckland",
    "Africa/Casablanca",
)

# The vector zones whose rules have long been stable, so a PostgreSQL built
# with an older or newer tzdata agrees on them (suite 23 checks only these).
# Morocco moves its clocks around Ramadan by decree, year by year.
PG_STABLE_ZONES = frozenset(VECTOR_ZONES) - {"Africa/Casablanca"}


class MissingTzdataError(RuntimeError):
    """The pinned tzdata package is not installed."""


@dataclass(frozen=True)
class Schedule:
    """A zone's offsets in [FROM, UNTIL): the offset at FROM, then each change."""

    initial: int
    transitions: tuple[tuple[int, int], ...]

    def offset_at(self, instant: int) -> int:
        index = bisect.bisect_right(self.transitions, (instant, float("inf")))
        return self.transitions[index - 1][1] if index else self.initial


def _package():
    try:
        import tzdata
    except ImportError as error:
        raise MissingTzdataError(
            "tool/contracts/time_zones.py needs the tzdata package pinned in "
            "tool/requirements.txt: run `make bootstrap`, or "
            "`python3 -m pip install --require-hashes -r tool/requirements.txt`."
        ) from error
    zoneinfo.reset_tzpath(to=[])
    return tzdata


@cache
def iana_version() -> str:
    """The IANA release the package carries, such as 2026f."""
    return _package().IANA_VERSION


def _resource(*parts: str):
    _package()
    return importlib.resources.files("tzdata.zoneinfo").joinpath(*parts)


def _table(name: str) -> list[list[str]]:
    return [
        line.split("\t")
        for line in _resource(name).read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    ]


@cache
def countries() -> dict[str, str]:
    """iso3166.tab and the retained codes: code to English name, sorted by code."""
    found = {row[0]: row[1] for row in _table("iso3166.tab")}
    return dict(sorted({**RETAINED_COUNTRIES, **found}.items()))


@cache
def zone_tab() -> tuple[tuple[str, str], ...]:
    """zone.tab's (zone, country) rows, in the file's order."""
    return tuple((row[2], row[0]) for row in _table("zone.tab"))


@cache
def links() -> dict[str, str]:
    """tzdata.zi's links: link name to target."""
    found = {}
    for line in _resource("tzdata.zi").read_text(encoding="utf-8").splitlines():
        if line.startswith("L "):
            _, target, name = line.split(" ")
            found[name] = target
    return found


@cache
def zone_countries() -> dict[str, str]:
    """Every stored zone, sorted by code point, to its country."""
    by_zone = dict(zone_tab())
    for name, target in RETAINED_ZONES.items():
        by_zone[name] = by_zone[target]
    return dict(sorted(by_zone.items()))


def allowed_zones() -> list[str]:
    return list(zone_countries())


@cache
def country_zones() -> dict[str, list[str]]:
    """Each country, sorted by code, to its zone.tab zones in the file's order."""
    found: dict[str, list[str]] = {code: [] for code in countries()}
    for zone, country in zone_tab():
        found[country].append(zone)
    return found


@cache
def device_links() -> dict[str, str]:
    """A device's zone name that is not stored, to the stored zone it links to.

    A stored name maps to itself and is not listed, even when tzdata.zi makes
    it a link (Asia/Kuwait stays Asia/Kuwait, not Asia/Riyadh).
    """
    allowed = set(zone_countries())
    return {
        name: target
        for name, target in sorted(links().items())
        if name not in allowed and target in allowed
    }


def read_tzif(data: bytes) -> tuple[list[int], str]:
    """A TZif file (RFC 8536, version 2 or later): its transition times and footer."""
    if data[:4] != b"TZif" or data[4:5] < b"2":
        raise ValueError("not a TZif file of version 2 or later")

    def counts(at: int) -> tuple[int, ...]:
        return struct.unpack(">6l", data[at + 20 : at + 44])

    isut, isstd, leap, time, types, chars = counts(0)
    second = 44 + time * 5 + types * 6 + chars + leap * 8 + isstd + isut
    isut, isstd, leap, time, types, chars = counts(second)
    start = second + 44
    times = list(struct.unpack(f">{time}q", data[start : start + time * 8]))
    end = start + time * 9 + types * 6 + chars + leap * 12 + isstd + isut
    footer = data[end:].decode("ascii")
    if not (footer.startswith("\n") and footer.endswith("\n")):
        raise ValueError("TZif footer missing")
    return times, footer.strip("\n")


@cache
def _zone(name: str) -> zoneinfo.ZoneInfo:
    _package()
    return zoneinfo.ZoneInfo(name)


def offset_at(name: str, instant: int) -> int:
    """The reference: the zone's UTC offset in seconds at a UTC instant."""
    moment = datetime.fromtimestamp(instant, _zone(name))
    return int(moment.utcoffset().total_seconds())


def _bisect(name: str, low: int, high: int) -> int:
    """The first second in (low, high] with high's offset."""
    target = offset_at(name, high)
    while high - low > 1:
        middle = (low + high) // 2
        if offset_at(name, middle) == target:
            high = middle
        else:
            low = middle
    return high


def _schedule_of_file(name: str, data: bytes) -> Schedule:
    times, footer = read_tzif(data)
    found = []
    for at in times:
        if FROM <= at < UNTIL and offset_at(name, at - 1) != offset_at(name, at):
            found.append((at, offset_at(name, at)))
    if "," in footer:
        # After the last listed transition the footer's yearly rule applies.
        start = max(FROM, (times[-1] if times else FROM) + 1)
        previous = offset_at(name, start)
        for step in range(start + DAY, UNTIL + DAY, DAY):
            current = offset_at(name, min(step, UNTIL - 1))
            if current != previous:
                at = _bisect(name, step - DAY, min(step, UNTIL - 1))
                found.append((at, current))
                previous = current
    return Schedule(offset_at(name, FROM), tuple(sorted(found)))


_SCHEDULES: dict[str, Schedule] = {}


def schedule(name: str) -> Schedule:
    """A stored zone's offsets in [FROM, UNTIL). Each distinct TZif file is read once."""
    data = _resource(*name.split("/")).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest not in _SCHEDULES:
        _SCHEDULES[digest] = _schedule_of_file(name, data)
    return _SCHEDULES[digest]


def utc(instant: int) -> str:
    return datetime.fromtimestamp(instant, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(text: str) -> int:
    return int(datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC).timestamp())


def local(name: str, instant: int) -> str:
    """The wall clock of a zone at a UTC instant, YYYY-MM-DDTHH:MM:SS."""
    return (
        datetime.fromtimestamp(instant, UTC) + timedelta(seconds=offset_at(name, instant))
    ).strftime("%Y-%m-%dT%H:%M:%S")


def wall_seconds(text: str) -> int:
    """A local YYYY-MM-DDTHH:MM:SS read as if it were UTC, in seconds."""
    return int(datetime.strptime(text, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=UTC).timestamp())


def local_to_instant(name: str, wall: str) -> tuple[int, str]:
    """The instant of a zone's local time, and whether it is normal, a gap or an overlap.

    A local time a clock change skips (gap) or repeats (overlap) is read as
    the later of its two instants, as PostgreSQL's `timestamp at time zone`
    reads it.
    """
    naive = datetime.strptime(wall, "%Y-%m-%dT%H:%M:%S")
    instants = {int(naive.replace(tzinfo=_zone(name), fold=fold).timestamp()) for fold in (0, 1)}
    later = max(instants)
    if len(instants) == 1:
        return later, "normal"
    readable = [i for i in instants if local(name, i) == wall]
    return later, "overlap" if len(readable) == 2 else "gap"


def is_quiet(start: int, end: int, name: str, instant: int) -> bool:
    """Whether the zone's wall clock at the instant is in [start, end) (minutes of the day)."""
    second = wall_seconds(local(name, instant)) % DAY
    low, high = start * 60, end * 60
    return low <= second < high if low < high else second >= low or second < high


def release_at(start: int, end: int, name: str, instant: int) -> int:
    """The first instant from `instant` at which the wall clock is outside the quiet hours.

    The reference walks whole minutes: every offset here is whole minutes and
    every clock change is on a minute, so the wall clock can only leave the
    window on one.
    """
    if not is_quiet(start, end, name, instant):
        return instant
    moment = instant - instant % 60 + 60
    while is_quiet(start, end, name, moment):
        moment += 60
    return moment


def next_at(name: str, minute: int, weekday: int | None, after: int) -> int:
    """The first instant strictly after `after` at which the zone's clock reads the
    time (a minute of the day), on the ISO weekday when one is given."""
    day = datetime.strptime(local(name, after)[:10], "%Y-%m-%d") - timedelta(days=1)
    while True:
        if weekday is None or day.isoweekday() == weekday:
            wall = (day + timedelta(minutes=minute)).strftime("%Y-%m-%dT%H:%M:%S")
            instant, _ = local_to_instant(name, wall)
            if instant > after:
                return instant
        day += timedelta(days=1)
